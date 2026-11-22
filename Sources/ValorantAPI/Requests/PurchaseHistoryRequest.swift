import Foundation

extension ValorantClient {
	public func getPurchaseHistory() async throws -> PurchaseHistory {
		let session = await getSession()
		let cookies = session.cookies.map(\.httpCookie)
		guard !cookies.isEmpty else {
			throw PurchaseHistoryError.missingSessionCookies
		}
		
		let configuration = URLSessionConfiguration.ephemeral
		let cookieStorage = HTTPCookieStorage()
		for cookie in cookies {
			cookieStorage.setCookie(cookie)
		}
		configuration.httpCookieStorage = cookieStorage
		configuration.httpCookieAcceptPolicy = .always
		configuration.httpShouldSetCookies = true
		
		let delegate = NoRedirectDelegate()
		let urlSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
		defer { urlSession.invalidateAndCancel() }
		
		// Step 1: Exchange active Riot SSO session cookies for a Player Support authorization redirect URI.
		let authURL = URL(string: "https://auth.riotgames.com/api/v1/authorization")!
		var authRequest = URLRequest(url: authURL)
		authRequest.httpMethod = "POST"
		authRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
		authRequest.setValue(AuthClient.riotUserAgent, forHTTPHeaderField: "User-Agent")
		
		let payload: [String: String] = [
			"client_id": "player-support-zendesk",
			"nonce": "1",
			"redirect_uri": "https://login.playersupport.riotgames.com/login_callback",
			"response_type": "token id_token",
			"scope": "account openid",
		]
		authRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
		
		let (authData, authResponse) = try await urlSession.data(for: authRequest)
		if let http = authResponse as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
			throw PurchaseHistoryError.httpError(http.statusCode)
		}
		storeResponseCookies(from: authResponse, into: cookieStorage)
		
		let sso = try JSONDecoder().decode(SSOAuthResponse.self, from: authData)
		if sso.type != "response" {
			throw PurchaseHistoryError.unexpectedSSOResponse(sso.type ?? "unknown")
		}
		guard let rawRedirect = sso.response?.parameters?.uri else {
			throw PurchaseHistoryError.malformedSSOResponse
		}
		guard rawRedirect.hasPrefix("https://login.playersupport.riotgames.com/login_callback") else {
			throw PurchaseHistoryError.unexpectedRedirectTarget(rawRedirect)
		}
		let callbackURLString = rawRedirect.replacingOccurrences(of: "#", with: "?")
		guard let callbackURL = URL(string: callbackURLString) else {
			throw PurchaseHistoryError.malformedSSOResponse
		}
		
		// Step 2: Hit login_callback (stopping redirects) to capture the `sso_session` cookie.
		var callbackRequest = URLRequest(url: callbackURL)
		callbackRequest.httpMethod = "GET"
		callbackRequest.setValue(AuthClient.riotUserAgent, forHTTPHeaderField: "User-Agent")
		
		let (_, callbackResponse) = try await urlSession.data(for: callbackRequest)
		storeResponseCookies(from: callbackResponse, into: cookieStorage)
		
		let allCookies = cookieStorage.cookies ?? []
		guard allCookies.contains(where: { $0.name == "sso_session" }) else {
			throw PurchaseHistoryError.missingSSOSessionCookie
		}
		
		// Step 3: Fetch purchase history JSON from Riot Player Support.
		let historyURL = URL(string: "https://sspd.playersupport.riotgames.com/valorant_purchase_history")!
		var historyRequest = URLRequest(url: historyURL)
		historyRequest.httpMethod = "GET"
		historyRequest.setValue(AuthClient.riotUserAgent, forHTTPHeaderField: "User-Agent")
		historyRequest.setValue("application/json", forHTTPHeaderField: "Accept")
		if let ssoCookie = allCookies.first(where: { $0.name == "sso_session" }) {
			let headerFields = HTTPCookie.requestHeaderFields(with: [ssoCookie])
			for (k, v) in headerFields {
				historyRequest.setValue(v, forHTTPHeaderField: k)
			}
		}
		
		let (historyData, historyResponse) = try await urlSession.data(for: historyRequest)
		if let http = historyResponse as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
			throw PurchaseHistoryError.httpError(http.statusCode)
		}
		
		do {
			return try JSONDecoder().decode(PurchaseHistory.self, from: historyData)
		} catch {
			throw PurchaseHistoryError.decodingFailed(error.localizedDescription)
		}
	}
	
	private func storeResponseCookies(from response: URLResponse, into storage: HTTPCookieStorage) {
		guard
			let http = response as? HTTPURLResponse,
			let url = http.url,
			let fields = http.allHeaderFields as? [String: String]
		else { return }
		let parsed = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
		for cookie in parsed {
			storage.setCookie(cookie)
		}
	}
}

public enum PurchaseHistoryError: Error, LocalizedError {
	case missingSessionCookies
	case unexpectedSSOResponse(String)
	case malformedSSOResponse
	case unexpectedRedirectTarget(String)
	case missingSSOSessionCookie
	case httpError(Int)
	case decodingFailed(String)
	
	public var errorDescription: String? {
		switch self {
		case .missingSessionCookies:
			return "Your session doesn't have Riot SSO cookies. Sign out and sign back in to view purchase history."
		case .unexpectedSSOResponse(let type):
			return "Riot SSO requires fresh interactive authentication (response type: \(type))."
		case .malformedSSOResponse:
			return "Received a malformed SSO response from Riot."
		case .unexpectedRedirectTarget(let uri):
			return "Unexpected Player Support redirect target: \(uri)"
		case .missingSSOSessionCookie:
			return "Player Support login callback did not return an sso_session cookie."
		case .httpError(let status):
			return "Player Support returned HTTP \(status)."
		case .decodingFailed(let detail):
			return "Failed to decode purchase history: \(detail)"
		}
	}
}

private struct SSOAuthResponse: Decodable {
	var type: String?
	var response: Payload?
	
	struct Payload: Decodable {
		var parameters: Parameters?
	}
	
	struct Parameters: Decodable {
		var uri: String?
	}
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		willPerformHTTPRedirection response: HTTPURLResponse,
		newRequest request: URLRequest,
		completionHandler: @escaping (URLRequest?) -> Void
	) {
		completionHandler(nil)
	}
}
