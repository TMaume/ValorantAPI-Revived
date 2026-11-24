import Foundation
import Combine
import HandyOperators
import Protoquest

/// provides access to a session, refreshing as needed
final actor SessionHandler {
	private struct CachedPASToken {
		let token: String
		let expiration: Date
		let accessToken: String
	}
	
	private(set) var session: APISession {
		didSet {
			sessionSubject.send(session)
		}
	}
	let sessionSubject = PassthroughSubject<APISession, Never>()
	var reauthBehavior: ValorantClient.ReauthBehavior = .noReauth
	
	private var isResumingSession = false
	private var waitingForSession: [CheckedContinuation<Void, Error>] = []
	private var playerPreferencesAuth: (client: PlayerPreferencesClient, accessToken: AccessToken, entitlementsToken: String)?
	private var inFlightPlayerPreferencesAuth: [PlayerPreferencesClient: Task<(authorization: String, entitlementsToken: String), Error>] = [:]
	private var cachedChatPASToken: CachedPASToken?
	private var inFlightChatPASToken: Task<String, Error>?
	
	init(session: APISession) {
		self.session = session
	}
	
	enum PlayerPreferencesClient: Hashable {
		case webUnrestricted
		case riotClient
	}
	
	func getPlayerPreferencesAuth(
		client: PlayerPreferencesClient = .webUnrestricted,
		forceRefresh: Bool = false
	) async throws -> (authorization: String, entitlementsToken: String) {
		if !forceRefresh, let cached = playerPreferencesAuth, cached.client == client, !cached.accessToken.hasExpired {
			return (cached.accessToken.encoded, cached.entitlementsToken)
		}
		if let existing = inFlightPlayerPreferencesAuth[client] {
			let result = try await existing.value
			try Task.checkCancellation()
			return result
		}
		
		let task = Task<(authorization: String, entitlementsToken: String), Error> {
			try await self.fetchPlayerPreferencesAuth(client: client)
		}
		inFlightPlayerPreferencesAuth[client] = task
		let result = try await task.value
		try Task.checkCancellation()
		return result
	}
	
	private func fetchPlayerPreferencesAuth(
		client: PlayerPreferencesClient
	) async throws -> (authorization: String, entitlementsToken: String) {
		defer { inFlightPlayerPreferencesAuth[client] = nil }
		
		var authClient = await AuthClient()
		defer { authClient.invalidate() }
		authClient.setCookies(session.cookies.map(\.httpCookie))
		
		let token: AccessToken
		switch client {
		case .webUnrestricted:
			if let webToken = try? await authClient.getAccessTokenFromCookies() {
				token = webToken
			} else {
				token = try await authClient.getRiotClientAccessTokenFromCookies()
			}
		case .riotClient:
			token = try await authClient.getRiotClientAccessTokenFromCookies()
		}
		
		authClient.accessToken = token
		let entitlements = try await authClient.getEntitlementsToken()
		let updatedCookies = authClient.cookies()
		if !updatedCookies.isEmpty {
			session.cookies = updatedCookies.map(Cookie.init)
		}
		
		playerPreferencesAuth = (client, token, entitlements)
		return (token.encoded, entitlements)
	}
	
	func getAccessToken() async throws -> AccessToken {
		if session.accessToken.hasExpired {
			try await waitOrRefreshSession()
		}
		
		return session.accessToken
	}
	
	func getAuthCredentials() async throws -> (accessToken: AccessToken, entitlementsToken: String) {
		let token = try await getAccessToken()
		return (token, session.entitlementsToken)
	}
	
	func forceRefreshAccessToken(ifMatching failedToken: String) async throws -> AccessToken {
		if session.accessToken.token == failedToken || session.accessToken.hasExpired {
			try await waitOrRefreshSession()
		}
		return session.accessToken
	}
	
	func invalidateChatPASToken() {
		cachedChatPASToken = nil
	}
	
	func getChatPASToken(using cleanStack: Protolayer, forceRefresh: Bool = false) async throws -> String {
		if forceRefresh {
			cachedChatPASToken = nil
		}
		
		let currentToken = try await getAccessToken()
		if !forceRefresh,
		   let cached = cachedChatPASToken,
		   cached.accessToken == currentToken.token,
		   Date().addingTimeInterval(60) < cached.expiration {
			return cached.token
		}
		
		if let existing = inFlightChatPASToken {
			let result = try await existing.value
			try Task.checkCancellation()
			return result
		}
		
		let task = Task<String, Error> {
			try await self.fetchChatPASToken(using: cleanStack)
		}
		inFlightChatPASToken = task
		let result = try await task.value
		try Task.checkCancellation()
		return result
	}
	
	private func fetchChatPASToken(using cleanStack: Protolayer) async throws -> String {
		defer { inFlightChatPASToken = nil }
		
		let maxRateLimitRetries = 2
		var rateLimitAttempt = 0
		var didRefreshToken = false
		
		while true {
			try Task.checkCancellation()
			let accessToken = try await getAccessToken()
			var request = URLRequest(url: URL(string: "https://riot-geo.pas.si.riotgames.com/pas/v1/service/chat")!)
			request.httpMethod = "GET"
			request.setValue(accessToken.encoded, forHTTPHeaderField: "Authorization")
			
			let response = try await cleanStack.send(request)
			let code = response.httpMetadata?.statusCode ?? 0
			if !(200..<300).contains(code) {
				let apiError = APIError(statusCode: code, response: response)
				switch apiError {
				case .rateLimited(let retryAfter):
					if rateLimitAttempt < maxRateLimitRetries, (retryAfter ?? 0) <= 10 {
						rateLimitAttempt += 1
						let delay: TimeInterval
						if let retryAfter {
							delay = min(max(Double(retryAfter), 0.5), 10.0) + Double.random(in: 0.05...0.35)
						} else {
							delay = (rateLimitAttempt == 1 ? 1.5 : 3.5) + Double.random(in: 0.1...0.5)
						}
						try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
						continue
					}
					throw apiError
				case .unauthorized, .tokenFailure:
					if !didRefreshToken {
						didRefreshToken = true
						_ = try await forceRefreshAccessToken(ifMatching: accessToken.token)
						continue
					}
					throw apiError
				default:
					throw apiError
				}
			}
			
			guard let raw = try? response.decodeString(using: .utf8) else {
				throw APIError.unauthorized
			}
			let token = raw
				.trimmingCharacters(in: .whitespacesAndNewlines)
				.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
			guard !token.isEmpty else {
				throw APIError.unauthorized
			}
			
			let expiration = Self.jwtExpirationDate(for: token)
			cachedChatPASToken = CachedPASToken(
				token: token,
				expiration: expiration,
				accessToken: accessToken.token
			)
			return token
		}
	}
	
	private static func jwtExpirationDate(for jwt: String) -> Date {
		let segments = jwt.split(separator: ".")
		guard segments.count >= 2 else { return Date().addingTimeInterval(300) }
		var payload = String(segments[1])
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")
		while payload.count % 4 != 0 {
			payload.append("=")
		}
		guard let data = Data(base64Encoded: payload),
		      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			return Date().addingTimeInterval(300)
		}
		if let exp = json["exp"] as? Double {
			return Date(timeIntervalSince1970: exp)
		}
		if let exp = json["exp"] as? Int {
			return Date(timeIntervalSince1970: TimeInterval(exp))
		}
		return Date().addingTimeInterval(300)
	}
	
	private func waitOrRefreshSession() async throws {
		let id = UUID()
		if isResumingSession {
			print(id, "waiting for resumption…")
			try await withCheckedThrowingContinuation {
				waitingForSession.append($0)
			}
			print(id, "waiting complete!")
		} else {
			print(id, "resuming session")
			try await refreshAccessToken()
			print(id, "session resumed!")
		}
	}
	
	func markExpired() {
		session.hasExpired = true
	}
	
	func setReauthBehavior(_ behavior: ValorantClient.ReauthBehavior) async {
		self.reauthBehavior = behavior
	}
	
	private func multifactorHandler() -> MultifactorHandler? {
		switch reauthBehavior {
		case .noReauth:
			return nil
		case .failOnMFA:
			return { _ in
				throw APIError.sessionExpired(mfaRequired: true)
			}
		case .full(let multifactorHandler):
			return multifactorHandler
		}
	}
	
	private func refreshAccessToken() async throws {
		assert(!isResumingSession)
		isResumingSession = true
		defer {
			isResumingSession = false
			waitingForSession = []
		}
		
		do {
			do {
				session = try await session <- {
					try await $0.refreshAccessToken(multifactorHandler: multifactorHandler())
				}
				session.hasExpired = false
				cachedChatPASToken = nil
				playerPreferencesAuth = nil
				
				waitingForSession.forEach { $0.resume() }
			} catch {
				waitingForSession.forEach { $0.resume(throwing: error) }
				throw error
			}
		} catch APIError.sessionExpired(let mfaRequired) {
			session.hasExpired = true
			throw APIError.sessionExpired(mfaRequired: mfaRequired)
		} catch {
			throw APIError.sessionResumptionFailure(error)
		}
	}
}
