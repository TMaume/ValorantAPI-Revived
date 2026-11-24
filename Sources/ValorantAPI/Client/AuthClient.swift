import Foundation
import Protoquest
import HandyOperators

struct AuthClient {
	let baseURL = BaseURLs.authAPI
	let urlSession: URLSession
	var accessToken: AccessToken?
	
	init(urlSessionOverride: URLSession? = nil) async {
		self.urlSession = urlSessionOverride ?? .init(configuration: .ephemeral)
	}
	
	func cookies() -> [HTTPCookie] {
		urlSession.configuration.httpCookieStorage!.cookies ?? []
	}
	
	func setCookies(_ cookies: [HTTPCookie]) {
		cookies.forEach(urlSession.configuration.httpCookieStorage!.setCookie(_:))
	}
	
	func clearCookies() {
		urlSession.configuration.httpCookieStorage!.removeCookies(since: .distantPast)
	}
	
	func addHeaders(to rawRequest: inout URLRequest) async {
		rawRequest.headers.authorization = accessToken?.encoded
	}
	
	func send<R: AuthRequest>(_ request: R) async throws -> R.Response {
		let urlRequest = try URLRequest(url: request.url(relativeTo: BaseURLs.authAPI)) <- {
			try request.configure(&$0)
			$0.headers.authorization = accessToken?.encoded
			$0.setValue(Self.riotUserAgent, forHTTPHeaderField: "User-Agent")
		}
		
		let response = try await Protolayer.urlSession(urlSession)
			.send(urlRequest)
		
		return try request.decodeResponse(from: response)
	}
	
	static let riotUserAgent = "RiotClient/43.0.1.4195386.4190634 rso-auth (Windows; 10;;Professional, x64)"
}

protocol AuthRequest: Request {}

extension JSONEncodingRequest where Self: AuthRequest {
	var encoderOverride: JSONEncoder? { makeRequestEncoder() }
}

extension JSONDecodingRequest where Self: AuthRequest {
	var decoderOverride: JSONDecoder? { makeResponseDecoder() }
	
	func decodeResponse(from raw: Protoresponse) throws -> Response {
		do {
			return try raw.decodeJSON(using: makeResponseDecoder())
		} catch {
			if raw.httpMetadata!.statusCode == 403 {
				throw AuthDecodingError.accessDenied
			} else {
				throw error
			}
		}
	}
}

private func makeRequestEncoder() -> JSONEncoder {
	JSONEncoder() <- {
		$0.keyEncodingStrategy = .convertToSnakeCase
	}
}

private func makeResponseDecoder() -> JSONDecoder {
	JSONDecoder() <- {
		$0.keyDecodingStrategy = .convertFromSnakeCase
	}
}

private enum AuthDecodingError: Error, LocalizedError {
	case accessDenied
	
	var errorDescription: String? {
		"The authentication servers could not be reached! Are you using a VPN or cellular data?"
	}
}
