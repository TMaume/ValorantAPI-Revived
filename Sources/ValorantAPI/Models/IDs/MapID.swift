import Foundation
import HandyOperators

public struct MapID: SimpleRawWrapper {
	public static let knownMaps = knownStandardMaps + [.range]
	public static let knownStandardMaps: [Self] = [
		.split,
		.haven,
		.bind,
		.ascent,
		.icebox,
		.breeze,
		.fracture,
	]
	
	public static let split = mapID("Bonsai")
	public static let haven = mapID("Triad")
	public static let bind = mapID("Duality")
	public static let ascent = mapID("Ascent")
	public static let icebox = mapID("Port")
	public static let breeze = mapID("Foxtrot")
	public static let fracture = mapID("Canyon")
	public static let gauntlet = mapID("AbilityDraft")
	public static let range = mapID("Range", group: "Poveglia")
	public static let rangeV2 = mapID("RangeV2", group: "PovegliaV2")
	
	public var isShootingRange: Bool {
		if self == .range || self == .rangeV2 {
			return true
		}
		let lower = rawValue.lowercased()
		return lower.contains("shootingrange")
			|| lower.contains("/range")
			|| lower.contains("poveglia")
	}
	
	private static func mapID(_ key: String, group: String? = nil) -> Self {
		Self("/Game/Maps/\(group ?? key)/\(key)")
	}
	
	public var rawValue: String
	
	public init(_ rawValue: String) {
		self.rawValue = rawValue
	}
}
