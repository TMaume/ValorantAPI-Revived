import Foundation

public struct LowercaseUUID: Hashable, Codable, LosslessStringConvertible {
	public static let stupidNullID = Self(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
	
	var uuid: UUID
	
	public var description: String {
		uuid.uuidString.lowercased()
	}
	
	public init(_ uuid: UUID) {
		self.uuid = uuid
	}
	
	public init() {
		self.init(UUID())
	}
	
	public init?(_ description: String) {
		assert(description.lowercased() == description)
		guard let uuid = UUID(uuidString: description) else { return nil }
		self.init(uuid)
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.init(try container.decode(UUID.self))
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(description)
	}
}
