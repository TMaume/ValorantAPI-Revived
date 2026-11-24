import Foundation
import Protoquest
import Collections

public struct ClientLog {
	public static let maxLoggedBodyBytes = 64 * 1024
	
	public let maxCount: Int
	public private(set) var exchanges: Deque<Exchange> = []
	
	public init(maxCount: Int = 50) {
		self.maxCount = maxCount
	}
	
	public mutating func logExchange(request: URLRequest, result: Protoresult) {
		var loggedRequest = request
		if let body = loggedRequest.httpBody, body.count > Self.maxLoggedBodyBytes {
			loggedRequest.httpBody = Self.cappedBody(body)
		}
		
		let loggedResult: Protoresult
		if case .success(var response) = result, response.body.count > Self.maxLoggedBodyBytes {
			response.body = Self.cappedBody(response.body)
			loggedResult = .success(response)
		} else {
			loggedResult = result
		}
		
		let exchange = Exchange(request: loggedRequest, result: loggedResult)
		guard !exchange.wasCancelled else { return }
		
		if exchanges.count >= maxCount {
			exchanges.removeFirst()
		}
		exchanges.append(exchange)
	}
	
	private static func cappedBody(_ data: Data) -> Data {
		guard data.count > maxLoggedBodyBytes else { return data }
		var truncated = Data(data.prefix(maxLoggedBodyBytes))
		let suffix = Data("\n… [truncated, original size: \(data.count) bytes]".utf8)
		truncated.append(suffix)
		return truncated
	}
	
	public struct Exchange: Identifiable {
		public var id = ObjectID<Self, UUID>(rawID: .init())
		public var time = Date.now
		public var request: URLRequest
		public var result: Protoresult
		
		public var statusCode: Int? {
			try? result.get().httpMetadata?.statusCode
		}
		
		var wasCancelled: Bool {
			// hide cancellation errors
			guard
				case .failure(let error) = result,
				let urlError = error as? URLError,
				urlError.code == .cancelled
			else { return false }
			return true
		}
	}
}
