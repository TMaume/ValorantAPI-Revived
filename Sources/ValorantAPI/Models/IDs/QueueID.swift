import Foundation
import HandyOperators

public struct QueueID: SimpleRawWrapper, LosslessStringConvertible {
	/// ordered loosely by similarity, starting with competitive
	public static let knownQueues: [Self] = [
		.competitive,
		.unrated,
		.swiftplay,
		.spikeRush,
		.gauntlet,
		.teamDeathmatch,
		.knockout,
		.allRandomOneSite,
		.skirmish2v2,
		.skirmishAscension1v1,
		.skirmishAscension2v2,
		.replication,
		.escalation,
		.deathmatch,
		.retake,
		.snowballFight,
		.newMap,
		.premier,
		.custom,
	]
	
	public static let unrated = Self("unrated")
	public static let competitive = Self("competitive")
	public static let spikeRush = Self("spikerush")
	public static let deathmatch = Self("deathmatch")
	public static let escalation = Self("ggteam")
	public static let snowballFight = Self("snowball")
	public static let replication = Self("onefa")
	public static let swiftplay = Self("swiftplay")
	public static let gauntlet = Self("abilitydraftarena")
	public static let teamDeathmatch = Self("hurm")
	public static let allRandomOneSite = Self("valaram")
	public static let knockout = Self("dodgeball")
	public static let retake = Self("fortcollins")
	public static let skirmish2v2 = Self("skirmish2v2")
	public static let skirmishAscension1v1 = Self("skirmishascension1v1")
	public static let skirmishAscension2v2 = Self("skirmishascension2v2")
	/// used since Breeze to introduce new maps, display name always changing
	public static let newMap = Self("newmap")
	public static let premier = Self("premier")
	public static let custom = Self("custom")
	
	public var rawValue: String
	
	public var description: String { rawValue }
	
	public init(_ rawValue: String) {
		self.rawValue = rawValue
	}
}
