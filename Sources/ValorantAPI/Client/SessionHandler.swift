import Foundation
import Combine
import HandyOperators

/// provides access to a session, refreshing as needed
final actor SessionHandler {
	private(set) var session: APISession {
		didSet {
			sessionSubject.send(session)
		}
	}
	let sessionSubject = PassthroughSubject<APISession, Never>()
	var reauthBehavior: ValorantClient.ReauthBehavior = .noReauth
	
	private var isResumingSession = false
	private var waitingForSession: [CheckedContinuation<Void, Error>] = []
	private var playerPreferencesAuth: (accessToken: AccessToken, entitlementsToken: String)?
	
	init(session: APISession) {
		self.session = session
	}
	
	enum PlayerPreferencesClient {
		case webUnrestricted
		case riotClient
	}
	
	func getPlayerPreferencesAuth(
		client: PlayerPreferencesClient = .webUnrestricted,
		forceRefresh: Bool = false
	) async throws -> (authorization: String, entitlementsToken: String) {
		if !forceRefresh, let cached = playerPreferencesAuth, !cached.accessToken.hasExpired {
			return (cached.accessToken.encoded, cached.entitlementsToken)
		}
		
		var authClient = await AuthClient()
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
		
		playerPreferencesAuth = (token, entitlements)
		return (token.encoded, entitlements)
	}
	
	func getAccessToken() async throws -> AccessToken {
		if session.accessToken.hasExpired {
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
		
		return session.accessToken
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
