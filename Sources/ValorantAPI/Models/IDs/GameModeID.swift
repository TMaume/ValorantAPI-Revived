import Foundation

public enum GameMode {
	public struct ID: SimpleRawWrapper {
		public static let standard = Self("Bomb")
		public static let spikeRush = Self("QuickBomb")
		public static let deathmatch = Self("Deathmatch")
		
		public static let snowballFight = Self("SnowballFight")
		public static let escalation = Self("GunGame")
		public static let replication = Self("OneForAll")
		public static let swiftplay = Self("_Development/Swiftplay_EndOfRoundCredits")
		public static let gauntlet = Self("AbilityDraftArena")
		public static let teamDeathmatch = Self("HURM")
		public static let allRandomOneSite = Self("AROS")
		public static let knockout = Self("Dodgeball")
		public static let retake = Self("FortCollins")
		public static let skirmish = Self("Skirmish")
		public static let skirmishAscension = Self("SkirmishAscension")
		
		public static let onboarding = Self("NewPlayerExperience")
		public static let practice = Self("ShootingRange")
		
		public var rawValue: String
		
		public init(_ rawValue: String) {
			self.rawValue = rawValue
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			let decoded = try container.decode(String.self)
			// e.g. "Game/GameModes/Bomb/BombGameMode.BombGameMode_C"
			
			let pathPrefix = "/Game/GameModes/"
			let oldPathPrefix = "GameModes/" // migrate previously-decoded IDs to the new format
			let trimmed: Substring
			if decoded.hasPrefix(oldPathPrefix) {
				trimmed = decoded.dropFirst(oldPathPrefix.count)
			} else if decoded.hasPrefix(pathPrefix) {
				trimmed = decoded.dropFirst(pathPrefix.count)
			} else {
				self.init(decoded)
				return
			}
			// e.g. "Bomb/BombGameMode.BombGameMode_C"
			
			guard let lastSeparator = trimmed.lastIndex(of: "/") else {
				self.init(String(trimmed))
				return
			}
			self.init(String(trimmed.prefix(upTo: lastSeparator)))
			// e.g. "Bomb"
		}
	}
}
