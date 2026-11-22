import Foundation

public struct PurchaseHistory: Codable, Equatable {
	public var account: Account
	public var ares: Ares
	
	public init(account: Account, ares: Ares) {
		self.account = account
		self.ares = ares
	}
	
	private enum CodingKeys: String, CodingKey {
		case account, ares
	}
	
	/// Riot's current Player Support API nests `ares` inside `account`; older responses had it at the top level.
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let account = try container.decodeIfPresent(Account.self, forKey: .account) ?? .init(billing: .init())
		self.account = account
		self.ares = try container.decodeIfPresent(Ares.self, forKey: .ares) ?? account.ares ?? .init()
	}
	
	public struct Account: Codable, Equatable {
		public var billing: Billing
		public var ares: Ares?
		
		public init(billing: Billing, ares: Ares? = nil) {
			self.billing = billing
			self.ares = ares
		}
		
		private enum CodingKeys: String, CodingKey {
			case billing, ares
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			self.billing = try container.decodeIfPresent(Billing.self, forKey: .billing) ?? .init()
			self.ares = try container.decodeIfPresent(Ares.self, forKey: .ares)
		}
	}
	
	public struct Billing: Codable, Equatable {
		public var paymentHistory: [PaymentHistoryEntry]
		
		public init(paymentHistory: [PaymentHistoryEntry] = []) {
			self.paymentHistory = paymentHistory
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			self.paymentHistory = try container.decodeIfPresent([PaymentHistoryEntry].self, forKey: .paymentHistory) ?? []
		}
	}
	
	public struct Ares: Codable, Equatable {
		public var walletTransactions: [WalletTransaction]
		
		public init(walletTransactions: [WalletTransaction] = []) {
			self.walletTransactions = walletTransactions
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			self.walletTransactions = try container.decodeIfPresent([WalletTransaction].self, forKey: .walletTransactions) ?? []
		}
	}
	
	public struct PaymentHistoryEntry: Codable, Equatable, Identifiable {
		public var storefrontAccountCode: String
		public var dateCreated: Date
		public var amount: Decimal
		public var currency: String
		public var paymentMethodID: String
		
		public var id: String {
			"\(dateCreated.timeIntervalSince1970)-\(amount)-\(currency)-\(paymentMethodID)-\(storefrontAccountCode)"
		}
		
		public init(
			storefrontAccountCode: String,
			dateCreated: Date,
			amount: Decimal,
			currency: String,
			paymentMethodID: String
		) {
			self.storefrontAccountCode = storefrontAccountCode
			self.dateCreated = dateCreated
			self.amount = amount
			self.currency = currency
			self.paymentMethodID = paymentMethodID
		}
		
		private enum CodingKeys: String, CodingKey {
			case storefrontAccountCode
			case dateCreatedStr
			case dateCreated
			case amount
			case currency
			case paymentMethodID = "paymentMethodId"
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			storefrontAccountCode = try container.decodeIfPresent(String.self, forKey: .storefrontAccountCode) ?? ""
			currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? ""
			paymentMethodID = try container.decodeIfPresent(String.self, forKey: .paymentMethodID) ?? ""
			
			if let str = try container.decodeIfPresent(String.self, forKey: .dateCreatedStr) {
				dateCreated = try Self.parseDate(str)
			} else if let str = try container.decodeIfPresent(String.self, forKey: .dateCreated) {
				dateCreated = try Self.parseDate(str)
			} else if let date = try container.decodeIfPresent(Date.self, forKey: .dateCreated) {
				dateCreated = date
			} else {
				throw DecodingError.keyNotFound(
					CodingKeys.dateCreatedStr,
					.init(codingPath: container.codingPath, debugDescription: "Missing payment history timestamp")
				)
			}
			
			if let decimalStr = try? container.decode(String.self, forKey: .amount) {
				guard let parsed = Decimal(string: decimalStr, locale: Locale(identifier: "en_US_POSIX")) else {
					throw DecodingError.dataCorruptedError(
						forKey: .amount,
						in: container,
						debugDescription: "Expected a decimal-formatted string for `amount`, got \(decimalStr)"
					)
				}
				amount = parsed
			} else if let decimalVal = try? container.decode(Decimal.self, forKey: .amount) {
				amount = decimalVal
			} else if let doubleVal = try? container.decode(Double.self, forKey: .amount) {
				amount = Decimal(doubleVal)
			} else {
				amount = try container.decode(Decimal.self, forKey: .amount)
			}
		}
		
		public func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(storefrontAccountCode, forKey: .storefrontAccountCode)
			try container.encode(Self.formatPlayerSupportDate(dateCreated), forKey: .dateCreatedStr)
			try container.encode("\(amount)", forKey: .amount)
			try container.encode(currency, forKey: .currency)
			try container.encode(paymentMethodID, forKey: .paymentMethodID)
		}
		
		fileprivate static func parseDate(_ string: String) throws -> Date {
			if let parsed = playerSupportDateFormatter.date(from: string) {
				return parsed
			}
			if let parsed = playerSupportShortDateFormatter.date(from: string) {
				return parsed
			}
			if let iso = iso8601Fractional.date(from: string) ?? iso8601Standard.date(from: string) {
				return iso
			}
			if let sliced = sliceDate(string) {
				return sliced
			}
			throw DecodingError.dataCorrupted(
				.init(codingPath: [], debugDescription: "Could not parse a Player Support timestamp from \(string)")
			)
		}
		
		/// Mirrors Riot's support site parsing: `YYYY-MM-DD?HH:MM:SS…` or `YYYYMMDD?HHMMSS…`.
		private static func sliceDate(_ string: String) -> Date? {
			let chars = Array(string)
			func int(_ range: Range<Int>) -> Int? {
				guard range.upperBound <= chars.count else { return nil }
				return Int(String(chars[range]))
			}
			var comps = DateComponents()
			comps.timeZone = TimeZone(secondsFromGMT: 0)
			if chars.count >= 19, chars[4] == "-" {
				comps.year = int(0..<4); comps.month = int(5..<7); comps.day = int(8..<10)
				comps.hour = int(11..<13); comps.minute = int(14..<16); comps.second = int(17..<19)
			} else if chars.count >= 15 {
				comps.year = int(0..<4); comps.month = int(4..<6); comps.day = int(6..<8)
				comps.hour = int(9..<11); comps.minute = int(11..<13); comps.second = int(13..<15)
			} else {
				return nil
			}
			guard comps.year != nil, comps.month != nil, comps.day != nil else { return nil }
			return Calendar(identifier: .gregorian).date(from: comps)
		}
		
		fileprivate static func formatPlayerSupportDate(_ date: Date) -> String {
			playerSupportDateFormatter.string(from: date)
		}
	}
	
	public struct WalletTransaction: Codable, Equatable, Identifiable {
		public var createdTime: Date
		public var deltas: [Delta]
		
		public var id: String {
			let deltaKey = deltas.map { "\($0.type.rawID):\($0.amount ?? 0)" }.joined(separator: ",")
			return "\(createdTime.timeIntervalSince1970)-\(deltaKey)"
		}
		
		public init(createdTime: Date, deltas: [Delta]) {
			self.createdTime = createdTime
			self.deltas = deltas
		}
		
		private enum CodingKeys: String, CodingKey {
			case createdTime
			case deltas
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			deltas = try container.decodeIfPresent([Delta].self, forKey: .deltas) ?? []
			if let str = try? container.decode(String.self, forKey: .createdTime) {
				createdTime = try PaymentHistoryEntry.parseDate(str)
			} else if let ms = try? container.decode(Double.self, forKey: .createdTime) {
				let seconds = ms > 10_000_000_000 ? ms / 1000.0 : ms
				createdTime = Date(timeIntervalSince1970: seconds)
			} else {
				createdTime = try container.decode(Date.self, forKey: .createdTime)
			}
		}
	}
	
	public struct Delta: Codable, Equatable {
		public var type: Currency.ID
		public var amount: Int?
		
		public init(type: Currency.ID, amount: Int?) {
			self.type = type
			self.amount = amount
		}
	}
}

private let playerSupportDateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	formatter.dateFormat = "yyyyMMdd'T'HHmmss.SSS'Z'"
	return formatter
}()

private let playerSupportShortDateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
	return formatter
}()

private let iso8601Fractional: ISO8601DateFormatter = {
	let formatter = ISO8601DateFormatter()
	formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
	return formatter
}()

private let iso8601Standard: ISO8601DateFormatter = {
	let formatter = ISO8601DateFormatter()
	formatter.formatOptions = [.withInternetDateTime]
	return formatter
}()
