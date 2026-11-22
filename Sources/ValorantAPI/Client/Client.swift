import Foundation
import HandyOperators
import Protoquest
import Combine

public struct ValorantClient {
	private static let encodedPlatformInfo = try! JSONEncoder()
		.encode(PlatformInfo.supportedExample)
		.base64EncodedString()
	
	#if DEBUG
	/// A mocked client that's not actually signed in, for testing.
	public static let mocked = ValorantClient(session: .mocked)
	#endif
	
	/// The region/location this client makes requests in. Sessions are valid for all locations.
	public var location: Location
	/// The client version is required for many requests. A good third-party source of it would be https://valorant-api.com/v1/version
	public var clientVersion: String?
	
	/// The ID of the user owning this client's session.
	public let userID: User.ID
	
	private let clientStack: Protolayer
	private let cleanStack: Protolayer
	private let sessionHandler: SessionHandler
	private let logger = Logger()
	
	public init(
		session: APISession,
		urlSessionOverride: URLSession? = nil
	) {
		self.userID = session.userID
		self.location = session.location
		
		self.sessionHandler = .init(session: session)
		let logger = self.logger
		
		self.clientStack = Protolayer
			.urlSession(urlSessionOverride ?? .init(configuration: .ephemeral <- {
				$0.httpAdditionalHeaders = ["User-Agent": ""]
			}))
#if DEBUG
			.printExchanges()
#endif
			.readExchange { request, result in
				await logger.log(request: request, result: result)
			}
			.transformRequest { [sessionHandler] in
				$0.headers.authorization = try await sessionHandler.getAccessToken().encoded
				$0.headers.entitlementsToken = await sessionHandler.session.entitlementsToken
			}
		
		self.cleanStack = Protolayer
			.urlSession(.init(configuration: .ephemeral))
#if DEBUG
			.printExchanges()
#endif
			.readExchange { request, result in
				await logger.log(request: request, result: result)
			}
	}
	
	public func setReauthBehavior(_ behavior: ReauthBehavior) async {
		await sessionHandler.setReauthBehavior(behavior)
	}
	
	/// Calls the given callback whenever the session is updated, e.g. when it has expired and is resumed or restarted.
	public func onSessionUpdate(call handle: @escaping @MainActor (APISession) -> Void) -> AnyCancellable {
		sessionHandler.sessionSubject.sink { session in
			Task { await handle(session) }
		}
	}
	
	private func resolveClientVersion() async -> String {
		if let clientVersion, !clientVersion.isEmpty {
			return clientVersion
		}
		return await ClientVersionResolver.shared.resolve()
	}
	
	func send<R: ValorantRequest>(_ request: R) async throws -> R.Response {
		let resolvedVersion = await resolveClientVersion()
		
		let urlRequest = try request.urlRequest(for: location) <- {
			$0.headers.clientVersion = resolvedVersion
			$0.headers.clientPlatform = Self.encodedPlatformInfo
		}
		
		let response = try await clientStack.send(urlRequest)
		
		let code = response.httpMetadata!.statusCode
		guard (200..<300).contains(code) else {
			throw APIError(statusCode: code, response: response)
		}
		
		return try request.decodeResponse(from: response)
	}
	
	func sendWithPlayerPreferencesAuth<R: ValorantRequest>(_ request: R) async throws -> R.Response {
		do {
			return try await send(request)
		} catch APIError.unauthorized {
			return try await retryWithPlayerPreferencesAuth(request)
		} catch let APIError.badResponseCode(code, response, riotError) {
			guard code == 401 || code == 403 else {
				throw APIError.badResponseCode(code, response, riotError)
			}
			return try await retryWithPlayerPreferencesAuth(request)
		}
	}
	
	private func retryWithPlayerPreferencesAuth<R: ValorantRequest>(_ request: R) async throws -> R.Response {
		let resolvedVersion = await resolveClientVersion()
		
		func makeRequest(auth: (authorization: String, entitlementsToken: String), includeEntitlements: Bool) throws -> URLRequest {
			try request.urlRequest(for: location) <- {
				$0.headers.authorization = auth.authorization
				$0.headers.entitlementsToken = includeEntitlements ? auth.entitlementsToken : nil
				$0.headers.clientVersion = resolvedVersion
				$0.headers.clientPlatform = Self.encodedPlatformInfo
				$0.setValue("application/json", forHTTPHeaderField: "Accept")
			}
		}
		
		func sendVariants(with auth: (authorization: String, entitlementsToken: String)) async throws -> Protoresponse {
			let first = try await cleanStack.send(try makeRequest(auth: auth, includeEntitlements: true))
			guard first.httpMetadata?.statusCode == 403 else {
				return first
			}
			return try await cleanStack.send(try makeRequest(auth: auth, includeEntitlements: false))
		}
		
		let webAuth: (authorization: String, entitlementsToken: String)
		do {
			webAuth = try await sessionHandler.getPlayerPreferencesAuth(client: .webUnrestricted, forceRefresh: false)
		} catch {
			throw PlayerSettingsError.reauthRequired
		}
		
		var response = try await sendVariants(with: webAuth)
		if response.httpMetadata?.statusCode == 403,
		   let riotClientAuth = try? await sessionHandler.getPlayerPreferencesAuth(client: .riotClient, forceRefresh: true) {
			response = try await sendVariants(with: riotClientAuth)
		}
		
		let code = response.httpMetadata!.statusCode
		guard (200..<300).contains(code) else {
			if code == 403 {
				throw PlayerSettingsError.reauthRequired
			}
			throw APIError(statusCode: code, response: response)
		}
		
		return try request.decodeResponse(from: response)
	}
	
	/// Returns the current session.
	public func getSession() async -> APISession {
		await sessionHandler.session
	}
	
	/// Returns a valid RSO access token string, refreshing the session if needed.
	public func getAccessToken() async throws -> String {
		try await sessionHandler.getAccessToken().token
	}
	
	/// Returns the current entitlements JWT token.
	public func getEntitlementsToken() async -> String {
		await sessionHandler.session.entitlementsToken
	}
	
	/// Fetches the Riot Player Assertion Service (PAS) JWT used to authenticate XMPP chat connections.
	public func getChatPASToken() async throws -> String {
		let accessToken = try await sessionHandler.getAccessToken()
		var request = URLRequest(url: URL(string: "https://riot-geo.pas.si.riotgames.com/pas/v1/service/chat")!)
		request.httpMethod = "GET"
		request.setValue(accessToken.encoded, forHTTPHeaderField: "Authorization")
		let response = try await Protolayer.urlSession(.shared).send(request)
		if let http = response.httpMetadata, !(200..<300).contains(http.statusCode) {
			throw APIError.badResponseCode(http.statusCode, response, nil)
		}
		guard let raw = try? response.decodeString(using: .utf8),
			  let token = Optional(raw.trimmingCharacters(in: .whitespacesAndNewlines)
				.trimmingCharacters(in: CharacterSet(charactersIn: "\""))),
			  !token.isEmpty
		else {
			throw APIError.unauthorized
		}
		return token
	}
	
	/// Returns a log containing the last few exchanges with the server.
	public func getLog() async -> ClientLog {
		await logger.log
	}
	
	/// Creates a different version of this client for making requests in ``location``.
	///
	/// This is a cheap operation; the heavyweight objects are reference types and shared with the new instance.
	/// If ``location`` is `nil`, this just returns `self`.
	public func `in`(_ location: Location?) -> Self {
		if let location {
			return self <- { $0.location = location }
		} else {
			return self
		}
	}
	
	/// what to do when a session has expired
	public enum ReauthBehavior {
		/// don't try anything, just fail
		case noReauth
		/// try to reauthenticate automatically with the stored credentials, failing & sending a non-user-initiated MFA code if that's required
		case failOnMFA
		/// try to reauthenticate automatically with the stored credentials, handling an MFA request as specified
		case full(MultifactorHandler)
	}
}

private final actor Logger {
	var log = ClientLog()
	
	func log(request: URLRequest, result: Protoresult) {
		log.logExchange(request: request, result: result)
	}
}

private final actor ClientVersionResolver {
	static let shared = ClientVersionResolver()
	private static let fallbackVersion = "release-13.10-shipping-18-5893614"
	
	private var cachedVersion: String?
	
	func resolve() async -> String {
		if let cachedVersion {
			return cachedVersion
		}
		guard let url = URL(string: "https://valorant-api.com/v1/version") else {
			return Self.fallbackVersion
		}
		do {
			let (data, _) = try await URLSession.shared.data(from: url)
			let decoded = try JSONDecoder().decode(VersionResponse.self, from: data)
			cachedVersion = decoded.data.riotClientVersion
			return decoded.data.riotClientVersion
		} catch {
			return Self.fallbackVersion
		}
	}
	
	private struct VersionResponse: Decodable {
		let data: VersionData
		struct VersionData: Decodable {
			let riotClientVersion: String
		}
	}
}
