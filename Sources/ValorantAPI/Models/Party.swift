import Foundation
import ErgonomicCodable

public struct Party: Identifiable, Codable, Equatable {
	public typealias ID = ObjectID<Self, LowercaseUUID>
	
	public var id: ID
	public var mucName: String?
	public var clientVersion: String?
	public var members: [Member]
	public var state: State
	public var accessibility: Accessibility
	public var eligibleQueues: [QueueID]?
	/// the last time this party entered the queue (even if it's not currently in a queue—check the state for that)
	public var queueEntryTime: Date
	public var matchmakingData: MatchmakingData
	public var inviteCode: String
	public var invites: [Invite]
	public var requests: [JoinRequest]
	public var customGameData: CustomGameData?
	
	public var isCustomGame: Bool {
		state == .customGameSetup || state == .customGameStarting || state == .customGame
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(ID.self, forKey: .id)
		mucName = try container.decodeIfPresent(String.self, forKey: .mucName)
		clientVersion = try container.decodeIfPresent(String.self, forKey: .clientVersion)
		members = try container.decode([Member].self, forKey: .members)
		state = try container.decode(State.self, forKey: .state)
		accessibility = try container.decode(Accessibility.self, forKey: .accessibility)
		eligibleQueues = try container.decodeIfPresent([QueueID].self, forKey: .eligibleQueues)
		queueEntryTime = try container.decode(Date.self, forKey: .queueEntryTime)
		matchmakingData = try container.decode(MatchmakingData.self, forKey: .matchmakingData)
		inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode) ?? ""
		invites = try container.decodeIfPresent([Invite].self, forKey: .invites) ?? []
		requests = try container.decodeIfPresent([JoinRequest].self, forKey: .requests) ?? []
		customGameData = try container.decodeIfPresent(CustomGameData.self, forKey: .customGameData)
	}
	
	private enum CodingKeys: String, CodingKey {
		case id = "ID"
		case mucName = "MUCName"
		case clientVersion = "ClientVersion"
		case members = "Members"
		case state = "State"
		case accessibility = "Accessibility"
		case eligibleQueues = "EligibleQueues"
		case queueEntryTime = "QueueEntryTime"
		case matchmakingData = "MatchmakingData"
		case inviteCode = "InviteCode"
		case invites = "Invites"
		case requests = "Requests"
		case customGameData = "CustomGameData"
	}
	
	public struct State: SimpleRawWrapper {
		public static let `default` = Self("DEFAULT")
		public static let inMatchmaking = Self("MATCHMAKING")
		public static let startingMatchmaking = Self("STARTING_MATCHMAKING")
		public static let customGame = Self("CUSTOM_GAME")
		public static let customGameSetup = Self("CUSTOM_GAME_SETUP")
		public static let customGameStarting = Self("CUSTOM_GAME_STARTING")
		
		public var rawValue: String
		
		public init(_ rawValue: String) {
			self.rawValue = rawValue
		}
	}
	
	public struct Member: Identifiable, Codable, Equatable {
		public var id: Player.ID
		public var identity: Player.Identity
		public var isReady: Bool
		private var _isOwner: Bool?
		public var isModerator: Bool
		public var pings: [ServerPing]
		
		public var isOwner: Bool {
			get { _isOwner == true }
			set { _isOwner = newValue }
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			id = try container.decode(Player.ID.self, forKey: .id)
			identity = try container.decode(Player.Identity.self, forKey: .identity)
			isReady = try container.decode(Bool.self, forKey: .isReady)
			_isOwner = try container.decodeIfPresent(Bool.self, forKey: ._isOwner)
			isModerator = try container.decodeIfPresent(Bool.self, forKey: .isModerator) ?? false
			pings = try container.decodeIfPresent([ServerPing].self, forKey: .pings) ?? []
		}
		
		private enum CodingKeys: String, CodingKey {
			case id = "Subject"
			case identity = "PlayerIdentity"
			case isReady = "IsReady"
			case _isOwner = "IsOwner"
			case isModerator = "IsModerator"
			case pings = "Pings"
		}
		
		public struct ServerPing: Codable, Hashable, Identifiable {
			public var id: String { serverID }
			public var ping: Int
			public var serverID: String
			
			private enum CodingKeys: String, CodingKey {
				case ping = "Ping"
				case serverID = "GamePodID"
			}
		}
	}
	
	public enum Accessibility: String, Codable {
		case open = "OPEN"
		case closed = "CLOSED"
	}
	
	public struct MatchmakingData: Codable, Equatable {
		public var queueID: QueueID
		public var preferredGamePods: [String]
		/// RR penalty for skill disparity in Competitive
		public var rrPenalty: Double // TODO: is this actually an int?
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			queueID = try container.decode(QueueID.self, forKey: .queueID)
			preferredGamePods = try container.decodeIfPresent([String].self, forKey: .preferredGamePods) ?? []
			rrPenalty = try container.decodeIfPresent(Double.self, forKey: .rrPenalty) ?? 0
		}
		
		private enum CodingKeys: String, CodingKey {
			case queueID = "QueueID"
			case preferredGamePods = "PreferredGamePods"
			case rrPenalty = "SkillDisparityRRPenalty"
		}
	}
	
	public struct Invite: Identifiable, Codable, Hashable {
		public var id: String
		public var partyID: Party.ID
		public var playerID: Player.ID
		public var invitedBy: Player.ID
		public var createdAt: Date?
		public var refreshedAt: Date?
		public var expiresIn: Int?
		
		private enum CodingKeys: String, CodingKey {
			case id = "ID"
			case partyID = "PartyID"
			case playerID = "Subject"
			case invitedBy = "InvitedBySubject"
			case createdAt = "CreatedAt"
			case refreshedAt = "RefreshedAt"
			case expiresIn = "ExpiresIn"
		}
	}
	
	public struct JoinRequest: Identifiable, Codable, Hashable {
		public var id: String
		public var partyID: Party.ID
		public var requestedBy: Player.ID
		public var playerIDs: [Player.ID]
		public var createdAt: Date?
		public var refreshedAt: Date?
		public var expiresIn: Int?
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			id = try container.decode(String.self, forKey: .id)
			partyID = try container.decode(Party.ID.self, forKey: .partyID)
			requestedBy = try container.decode(Player.ID.self, forKey: .requestedBy)
			playerIDs = try container.decodeIfPresent([Player.ID].self, forKey: .playerIDs) ?? []
			createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
			refreshedAt = try container.decodeIfPresent(Date.self, forKey: .refreshedAt)
			expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn)
		}
		
		private enum CodingKeys: String, CodingKey {
			case id = "ID"
			case partyID = "PartyID"
			case requestedBy = "RequestedBySubject"
			case playerIDs = "Subjects"
			case createdAt = "CreatedAt"
			case refreshedAt = "RefreshedAt"
			case expiresIn = "ExpiresIn"
		}
	}
	
	public struct CustomGameData: Codable, Equatable {
		public var settings: Settings
		public var membership: Membership
		public var maxPartySize: Int
		public var autobalanceEnabled: Bool
		public var autobalanceMinPlayers: Int
		
		public init(
			settings: Settings = .init(),
			membership: Membership = .init(),
			maxPartySize: Int = 10,
			autobalanceEnabled: Bool = false,
			autobalanceMinPlayers: Int = 0
		) {
			self.settings = settings
			self.membership = membership
			self.maxPartySize = maxPartySize
			self.autobalanceEnabled = autobalanceEnabled
			self.autobalanceMinPlayers = autobalanceMinPlayers
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			settings = try container.decodeIfPresent(Settings.self, forKey: .settings) ?? .init()
			membership = try container.decodeIfPresent(Membership.self, forKey: .membership) ?? .init()
			maxPartySize = try container.decodeIfPresent(Int.self, forKey: .maxPartySize) ?? 0
			autobalanceEnabled = try container.decodeIfPresent(Bool.self, forKey: .autobalanceEnabled) ?? false
			autobalanceMinPlayers = try container.decodeIfPresent(Int.self, forKey: .autobalanceMinPlayers) ?? 0
		}
		
		private enum CodingKeys: String, CodingKey {
			case settings = "Settings"
			case membership = "Membership"
			case maxPartySize = "MaxPartySize"
			case autobalanceEnabled = "AutobalanceEnabled"
			case autobalanceMinPlayers = "AutobalanceMinPlayers"
		}
		
		public struct Settings: Codable, Equatable {
			public var map: String
			public var mode: String
			public var useBots: Bool
			public var gamePod: String
			public var gameRules: GameRules?
			
			public init(
				map: String = "/Game/Maps/Ascent/Ascent",
				mode: String = "/Game/GameModes/Bomb/BombGameMode.BombGameMode_C",
				useBots: Bool = false,
				gamePod: String = "",
				gameRules: GameRules? = .init()
			) {
				self.map = map
				self.mode = mode
				self.useBots = useBots
				self.gamePod = gamePod
				self.gameRules = gameRules
			}
			
			public init(from decoder: Decoder) throws {
				let container = try decoder.container(keyedBy: CodingKeys.self)
				map = try container.decodeIfPresent(String.self, forKey: .map) ?? ""
				mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? ""
				useBots = try container.decodeIfPresent(Bool.self, forKey: .useBots) ?? false
				gamePod = try container.decodeIfPresent(String.self, forKey: .gamePod) ?? ""
				gameRules = try container.decodeIfPresent(GameRules.self, forKey: .gameRules)
			}
			
			private enum CodingKeys: String, CodingKey {
				case map = "Map"
				case mode = "Mode"
				case useBots = "UseBots"
				case gamePod = "GamePod"
				case gameRules = "GameRules"
			}
		}
		
		public struct GameRules: Codable, Equatable {
			public var allowGameModifiers: String?
			public var isOvertimeWinByTwo: String?
			public var playOutAllRounds: String?
			public var skipMatchHistory: String?
			public var tournamentMode: String?
			
			public var allowCheats: Bool {
				get { allowGameModifiers == "true" }
				set { allowGameModifiers = newValue ? "true" : "false" }
			}
			
			public var overtimeWinByTwo: Bool {
				get { isOvertimeWinByTwo == "true" }
				set { isOvertimeWinByTwo = newValue ? "true" : "false" }
			}
			
			public var playOutAllRoundsEnabled: Bool {
				get { playOutAllRounds == "true" }
				set { playOutAllRounds = newValue ? "true" : "false" }
			}
			
			public var hideMatchHistory: Bool {
				get { skipMatchHistory == "true" }
				set { skipMatchHistory = newValue ? "true" : "false" }
			}
			
			public var tournamentModeEnabled: Bool {
				get { tournamentMode == "true" }
				set { tournamentMode = newValue ? "true" : "false" }
			}
			
			public init(
				allowCheats: Bool = false,
				overtimeWinByTwo: Bool = false,
				playOutAllRounds: Bool = false,
				hideMatchHistory: Bool = false,
				tournamentMode: Bool = false
			) {
				self.allowGameModifiers = allowCheats ? "true" : "false"
				self.isOvertimeWinByTwo = overtimeWinByTwo ? "true" : "false"
				self.playOutAllRounds = playOutAllRounds ? "true" : "false"
				self.skipMatchHistory = hideMatchHistory ? "true" : "false"
				self.tournamentMode = tournamentMode ? "true" : "false"
			}
			
			public init(from decoder: Decoder) throws {
				let container = try decoder.container(keyedBy: CodingKeys.self)
				func decodeFlag(_ key: CodingKeys) -> String? {
					if let str = try? container.decodeIfPresent(String.self, forKey: key) {
						return str
					}
					if let boolVal = try? container.decodeIfPresent(Bool.self, forKey: key) {
						return boolVal ? "true" : "false"
					}
					return nil
				}
				allowGameModifiers = decodeFlag(.allowGameModifiers)
				isOvertimeWinByTwo = decodeFlag(.isOvertimeWinByTwo)
				playOutAllRounds = decodeFlag(.playOutAllRounds)
				skipMatchHistory = decodeFlag(.skipMatchHistory)
				tournamentMode = decodeFlag(.tournamentMode)
			}
			
			private enum CodingKeys: String, CodingKey {
				case allowGameModifiers = "AllowGameModifiers"
				case isOvertimeWinByTwo = "IsOvertimeWinByTwo"
				case playOutAllRounds = "PlayOutAllRounds"
				case skipMatchHistory = "SkipMatchHistory"
				case tournamentMode = "TournamentMode"
			}
		}
		
		public struct Membership: Codable, Equatable {
			public var teamOne: [TeamMember]
			public var teamTwo: [TeamMember]
			public var teamSpectate: [TeamMember]
			public var teamOneCoaches: [TeamMember]
			public var teamTwoCoaches: [TeamMember]
			
			public init(
				teamOne: [TeamMember] = [],
				teamTwo: [TeamMember] = [],
				teamSpectate: [TeamMember] = [],
				teamOneCoaches: [TeamMember] = [],
				teamTwoCoaches: [TeamMember] = []
			) {
				self.teamOne = teamOne
				self.teamTwo = teamTwo
				self.teamSpectate = teamSpectate
				self.teamOneCoaches = teamOneCoaches
				self.teamTwoCoaches = teamTwoCoaches
			}
			
			public init(from decoder: Decoder) throws {
				let container = try decoder.container(keyedBy: CodingKeys.self)
				teamOne = try container.decodeIfPresent([TeamMember].self, forKey: .teamOne) ?? []
				teamTwo = try container.decodeIfPresent([TeamMember].self, forKey: .teamTwo) ?? []
				teamSpectate = try container.decodeIfPresent([TeamMember].self, forKey: .teamSpectate) ?? []
				teamOneCoaches = try container.decodeIfPresent([TeamMember].self, forKey: .teamOneCoaches) ?? []
				teamTwoCoaches = try container.decodeIfPresent([TeamMember].self, forKey: .teamTwoCoaches) ?? []
			}
			
			public func team(for playerID: Player.ID) -> CustomGameTeam? {
				if teamOne.contains(where: { $0.subject == playerID }) { return .teamOne }
				if teamTwo.contains(where: { $0.subject == playerID }) { return .teamTwo }
				if teamSpectate.contains(where: { $0.subject == playerID }) { return .spectate }
				if teamOneCoaches.contains(where: { $0.subject == playerID }) { return .teamOneCoaches }
				if teamTwoCoaches.contains(where: { $0.subject == playerID }) { return .teamTwoCoaches }
				return nil
			}
			
			private enum CodingKeys: String, CodingKey {
				case teamOne
				case teamTwo
				case teamSpectate
				case teamOneCoaches
				case teamTwoCoaches
			}
			
			public struct TeamMember: Codable, Equatable, Hashable {
				public var subject: Player.ID
				
				public init(subject: Player.ID) {
					self.subject = subject
				}
				
				private enum CodingKeys: String, CodingKey {
					case subject = "Subject"
				}
			}
		}
	}
}

public enum CustomGameTeam: String, CaseIterable, Codable, Hashable, Identifiable {
	case teamOne = "TeamOne"
	case teamTwo = "TeamTwo"
	case spectate = "TeamSpectate"
	case teamOneCoaches = "TeamOneCoaches"
	case teamTwoCoaches = "TeamTwoCoaches"
	
	public var id: String { rawValue }
}

public struct CustomGameConfigs: Codable, Equatable {
	public struct QueueConfig: Codable, Equatable {
		public var queueID: String
		public var enabled: Bool
		public var mode: String
		public var mapWeights: [String]
		public var mapPool: [String]
		
		public var mapPaths: [String] {
			let weighted = mapWeights.compactMap { entry -> String? in
				let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !trimmed.isEmpty else { return nil }
				if let colonIndex = trimmed.lastIndex(of: ":") {
					let weightPart = trimmed[trimmed.index(after: colonIndex)...]
						.trimmingCharacters(in: .whitespacesAndNewlines)
					if Double(weightPart) != nil {
						let prefix = trimmed[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
						return prefix.isEmpty ? nil : prefix
					}
				}
				return trimmed
			}
			if !weighted.isEmpty {
				return weighted
			}
			return mapPool.compactMap { entry in
				let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
				return trimmed.isEmpty ? nil : trimmed
			}
		}
		
		public init(
			queueID: String = "",
			enabled: Bool = false,
			mode: String = "",
			mapWeights: [String] = [],
			mapPool: [String] = []
		) {
			self.queueID = queueID
			self.enabled = enabled
			self.mode = mode
			self.mapWeights = mapWeights
			self.mapPool = mapPool
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			queueID = try container.decodeIfPresent(String.self, forKey: .queueID) ?? ""
			enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
			mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? ""
			mapWeights = try container.decodeIfPresent([String].self, forKey: .mapWeights) ?? []
			mapPool = try container.decodeIfPresent([String].self, forKey: .mapPool) ?? []
		}
		
		private enum CodingKeys: String, CodingKey {
			case queueID = "QueueID"
			case enabled = "Enabled"
			case mode = "Mode"
			case mapWeights = "MapWeights"
			case mapPool = "MapPool"
		}
	}
	
	public var enabled: Bool
	public var enabledMaps: [String]
	public var enabledModes: [String]
	public var queues: [QueueConfig]
	
	public init(
		enabled: Bool = true,
		enabledMaps: [String] = [],
		enabledModes: [String] = [],
		queues: [QueueConfig] = []
	) {
		self.enabled = enabled
		self.enabledMaps = enabledMaps
		self.enabledModes = enabledModes
		self.queues = queues
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
		enabledMaps = try container.decodeIfPresent([String].self, forKey: .enabledMaps) ?? []
		enabledModes = try container.decodeIfPresent([String].self, forKey: .enabledModes) ?? []
		queues = try container.decodeIfPresent([QueueConfig].self, forKey: .queues) ?? []
	}
	
	private enum CodingKeys: String, CodingKey {
		case enabled = "Enabled"
		case enabledMaps = "EnabledMaps"
		case enabledModes = "EnabledModes"
		case queues = "Queues"
	}
}

public extension CustomGameConfigs {
	private static let builtInMapPathsByShortName: [String: String] = [
		"ascent": "/Game/Maps/Ascent/Ascent",
		"bonsai": "/Game/Maps/Bonsai/Bonsai",
		"canyon": "/Game/Maps/Canyon/Canyon",
		"duality": "/Game/Maps/Duality/Duality",
		"foxtrot": "/Game/Maps/Foxtrot/Foxtrot",
		"infinity": "/Game/Maps/Infinity/Infinity",
		"jam": "/Game/Maps/Jam/Jam",
		"juliett": "/Game/Maps/Juliett/Juliett",
		"pitt": "/Game/Maps/Pitt/Pitt",
		"plummet": "/Game/Maps/Plummet/Plummet",
		"port": "/Game/Maps/Port/Port",
		"rook": "/Game/Maps/Rook/Rook",
		"triad": "/Game/Maps/Triad/Triad",
		"hurm_alley": "/Game/Maps/HURM/HURM_Alley/HURM_Alley",
		"hurm_bowl": "/Game/Maps/HURM/HURM_Bowl/HURM_Bowl",
		"hurm_helix": "/Game/Maps/HURM/HURM_Helix/HURM_Helix",
		"hurm_hightide": "/Game/Maps/HURM/HURM_HighTide/HURM_HighTide",
		"hurm_yard": "/Game/Maps/HURM/HURM_Yard/HURM_Yard",
		"skirmish_a": "/Game/Maps/Duel/Duel_1/Skirmish_A",
		"skirmish_b": "/Game/Maps/Duel/Duel_2/Skirmish_B",
		"skirmish_c": "/Game/Maps/Duel/Duel_3/Skirmish_C",
		"skirmish_d": "/Game/Maps/Duel/Duel_Platform/Skirmish_D",
		"skirmish_e": "/Game/Maps/Duel/Duel_Heady/Skirmish_E",
		"abilitydraft": "/Game/Maps/AbilityDraft/AbilityDraft",
		"range": "/Game/Maps/Poveglia/Range",
		"rangev2": "/Game/Maps/PovegliaV2/RangeV2",
	]
	
	private static let builtInModePathsByShortName: [String: String] = [
		"bombgamemode": "/Game/GameModes/Bomb/BombGameMode.BombGameMode_C",
		"deathmatchgamemode": "/Game/GameModes/Deathmatch/DeathmatchGameMode.DeathmatchGameMode_C",
		"gungameteamsgamemode": "/Game/GameModes/GunGame/GunGameTeamsGameMode.GunGameTeamsGameMode_C",
		"hurmgamemode": "/Game/GameModes/HURM/HURMGameMode.HURMGameMode_C",
		"quickbombgamemode": "/Game/GameModes/QuickBomb/QuickBombGameMode.QuickBombGameMode_C",
		"skirmishgamemode": "/Game/GameModes/Skirmish/SkirmishGameMode.SkirmishGameMode_C",
		"skirmishascensiongamemode": "/Game/GameModes/SkirmishAscension/SkirmishAscensionGameMode.SkirmishAscensionGameMode_C",
		"swiftplay_eorcredits_gamemode": "/Game/GameModes/_Development/Swiftplay_EndOfRoundCredits/Swiftplay_EoRCredits_GameMode.Swiftplay_EoRCredits_GameMode_C",
		"abilitydraftarenagamemode": "/Game/GameModes/AbilityDraftArena/AbilityDraftArenaGameMode.AbilityDraftArenaGameMode_C",
		"oneforall_gamemode": "/Game/GameModes/OneForAll/OneForAll_GameMode.OneForAll_GameMode_C",
		"snowballfightgamemode": "/Game/GameModes/SnowballFight/SnowballFightGameMode.SnowballFightGameMode_C",
		"shootingrangegamemode": "/Game/GameModes/ShootingRange/ShootingRangeGameMode.ShootingRangeGameMode_C",
		"aros_gamemode": "/Game/GameModes/AROS/AROS_GameMode.AROS_GameMode_C",
		"dodgeball_gamemode": "/Game/GameModes/Dodgeball/Dodgeball_GameMode.Dodgeball_GameMode_C",
		"fortcollins": "/Game/GameModes/FortCollins/FortCollins.FortCollins_C",
		"fortcollinsgamemode": "/Game/GameModes/FortCollins/FortCollinsGameMode.FortCollinsGameMode_C",
	]
	
	private static func extractShortName(from pathOrName: String) -> String {
		let trimmed = pathOrName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return "" }
		let afterSlash = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
		if let dotIndex = afterSlash.firstIndex(of: ".") {
			return String(afterSlash[..<dotIndex])
		}
		return afterSlash
	}
	
	static func mapShortName(from mapPathOrName: String) -> String {
		extractShortName(from: mapPathOrName)
	}
	
	static func modeShortName(from modePathOrName: String) -> String {
		extractShortName(from: modePathOrName)
	}
	
	static func canonicalMapPath(
		for mapPathOrName: String,
		knownMapPathsByShortName: [String: String] = [:]
	) -> String {
		let trimmed = mapPathOrName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return "" }
		let short = mapShortName(from: trimmed)
		let lower = short.lowercased()
		if trimmed.lowercased().hasPrefix("/game/") {
			return knownMapPathsByShortName[lower] ?? knownMapPathsByShortName[short] ?? trimmed
		}
		if let known = knownMapPathsByShortName[lower] ?? knownMapPathsByShortName[short] {
			return known
		}
		if let builtIn = builtInMapPathsByShortName[lower] {
			return builtIn
		}
		if lower.hasPrefix("hurm_") {
			return "/Game/Maps/HURM/\(short)/\(short)"
		}
		return "/Game/Maps/\(short)/\(short)"
	}
	
	static func canonicalModePath(
		for modePathOrName: String,
		knownModeFoldersByShortName: [String: String] = [:]
	) -> String {
		let trimmed = modePathOrName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return "" }
		if trimmed.lowercased().hasPrefix("/game/") {
			return trimmed
		}
		let short = modeShortName(from: trimmed)
		let lower = short.lowercased()
		if let builtIn = builtInModePathsByShortName[lower] {
			return builtIn
		}
		if let folder = knownModeFoldersByShortName[lower] ?? knownModeFoldersByShortName[short] {
			return "/Game/GameModes/\(folder)/\(short).\(short)_C"
		}
		let folder: String = {
			for suffix in ["_GameMode", "GameMode"] {
				if short.count > suffix.count,
				   short.lowercased().hasSuffix(suffix.lowercased()) {
					let stripped = String(short.dropLast(suffix.count))
					if !stripped.isEmpty {
						return stripped
					}
				}
			}
			return short
		}()
		return "/Game/GameModes/\(folder)/\(short).\(short)_C"
	}
	
	enum ModeCategory: Equatable {
		case standard
		case teamDeathmatch
		case skirmish
		case gauntlet
		case shootingRange
		case unknown(String)
		
		public init(modePath: String) {
			let lower = modePath.lowercased()
			if lower.isEmpty {
				self = .standard
			} else if lower.contains("hurm") {
				self = .teamDeathmatch
			} else if lower.contains("skirmish") {
				self = .skirmish
			} else if lower.contains("abilitydraft") || lower.contains("gauntlet") {
				self = .gauntlet
			} else if lower.contains("shootingrange") {
				self = .shootingRange
			} else if lower.contains("bomb")
				|| lower.contains("swiftplay")
				|| lower.contains("deathmatch")
				|| lower.contains("gungame")
				|| lower.contains("oneforall")
				|| lower.contains("snowball")
				|| lower.contains("aros")
				|| lower.contains("fortcollins")
				|| lower.contains("dodgeball") {
				self = .standard
			} else {
				self = .unknown(modePath)
			}
		}
		
		public static func isInternalOrTutorialMap(_ mapPath: String) -> Bool {
			let lower = mapPath.lowercased()
			let shortLower = CustomGameConfigs.mapShortName(from: mapPath).lowercased()
			return lower.contains("/npe")
				|| shortLower.hasPrefix("npe")
				|| lower.contains("newplayerexperience")
				|| lower.contains("tutorial")
				|| lower.contains("/menu")
				|| shortLower == "menu"
				|| lower.contains("/init")
				|| shortLower == "init"
		}
		
		public func accepts(mapPath: String) -> Bool {
			guard !Self.isInternalOrTutorialMap(mapPath) else { return false }
			let lower = mapPath.lowercased()
			let shortLower = CustomGameConfigs.mapShortName(from: mapPath).lowercased()
			let isHURM = lower.contains("/hurm/") || shortLower.hasPrefix("hurm_") || shortLower == "hurm"
			let isSkirmish = lower.contains("/duel/") || lower.contains("skirmish") || shortLower.hasPrefix("duel_")
			let isGauntlet = lower.contains("/abilitydraft/") || shortLower.contains("abilitydraft") || lower.contains("gauntlet")
			let isRange = lower.contains("poveglia") || lower.contains("/range") || shortLower == "range" || shortLower.hasPrefix("rangev")
			switch self {
			case .teamDeathmatch:
				return isHURM
			case .skirmish:
				return isSkirmish
			case .gauntlet:
				return isGauntlet
			case .shootingRange:
				return isRange
			case .standard:
				return !isHURM && !isSkirmish && !isGauntlet && !isRange
			case .unknown:
				return false
			}
		}
	}
	
	func validMaps(
		forMode modePath: String,
		knownNonTacticalMapPaths: Set<String> = [],
		knownMapPathsByShortName: [String: String] = [:]
	) -> [String] {
		let nonTacticalShortNamesLower = Set(
			knownNonTacticalMapPaths.map { Self.mapShortName(from: $0).lowercased() }
		)
		var seenShortLower = Set<String>()
		let deduplicatedMaps: [(canonical: String, shortLower: String)] = enabledMaps.compactMap { path in
			let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { return nil }
			let shortLower = Self.mapShortName(from: trimmed).lowercased()
			guard !shortLower.isEmpty, seenShortLower.insert(shortLower).inserted else { return nil }
			let canonical = Self.canonicalMapPath(for: trimmed, knownMapPathsByShortName: knownMapPathsByShortName)
			return (canonical, shortLower)
		}
		
		let category = ModeCategory(modePath: modePath)
		let targetModeShort = Self.modeShortName(from: modePath)
		let queueMapShortNamesLower = Set(
			queues
				.filter {
					let queueModeShort = Self.modeShortName(from: $0.mode)
					return !queueModeShort.isEmpty && queueModeShort.caseInsensitiveCompare(targetModeShort) == .orderedSame
				}
				.flatMap(\.mapPaths)
				.map { Self.mapShortName(from: $0).lowercased() }
		)
		
		switch category {
		case .teamDeathmatch, .skirmish, .gauntlet, .shootingRange:
			return deduplicatedMaps.compactMap { entry in
				guard !ModeCategory.isInternalOrTutorialMap(entry.canonical) else { return nil }
				return (category.accepts(mapPath: entry.canonical) || queueMapShortNamesLower.contains(entry.shortLower))
					? entry.canonical
					: nil
			}
		case .standard:
			var standardQueueMapsLower = Set<String>()
			var specialQueueMapsLower = Set<String>()
			for queue in queues where !queue.mode.isEmpty {
				let queueCategory = ModeCategory(modePath: queue.mode)
				for mapPath in queue.mapPaths {
					let shortLower = Self.mapShortName(from: mapPath).lowercased()
					guard !shortLower.isEmpty else { continue }
					if queueCategory == .standard {
						standardQueueMapsLower.insert(shortLower)
					} else {
						specialQueueMapsLower.insert(shortLower)
					}
				}
			}
			let otherSpecialQueueMapsLower = specialQueueMapsLower.subtracting(standardQueueMapsLower)
			return deduplicatedMaps.compactMap { entry in
				guard category.accepts(mapPath: entry.canonical),
					  !nonTacticalShortNamesLower.contains(entry.shortLower),
					  !otherSpecialQueueMapsLower.contains(entry.shortLower)
				else {
					return nil
				}
				return entry.canonical
			}
		case .unknown:
			guard !queueMapShortNamesLower.isEmpty else { return [] }
			return deduplicatedMaps.compactMap { entry in
				guard !ModeCategory.isInternalOrTutorialMap(entry.canonical),
					  queueMapShortNamesLower.contains(entry.shortLower)
				else {
					return nil
				}
				return entry.canonical
			}
		}
	}
	
	func selectableModes(knownModeFoldersByShortName: [String: String] = [:]) -> [String] {
		var seenShortLower = Set<String>()
		return enabledModes.compactMap { path in
			let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { return nil }
			let lower = trimmed.lowercased()
			let shortLower = Self.modeShortName(from: trimmed).lowercased()
			guard !shortLower.isEmpty,
				  !lower.contains("newplayerexperience"),
				  !lower.contains("/npe"),
				  !shortLower.hasPrefix("npe"),
				  !lower.contains("onboarding"),
				  !lower.contains("exampleplayertestbot"),
				  !lower.contains("bottrainingmatch"),
				  !lower.contains("shootingrange")
			else {
				return nil
			}
			guard seenShortLower.insert(shortLower).inserted else { return nil }
			return Self.canonicalModePath(for: trimmed, knownModeFoldersByShortName: knownModeFoldersByShortName)
		}
	}
}

public struct PartyPlayer: Codable, Equatable {
	public var subject: Player.ID
	public var currentPartyID: Party.ID
	public var requests: [Party.JoinRequest]
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		subject = try container.decode(Player.ID.self, forKey: .subject)
		currentPartyID = try container.decode(Party.ID.self, forKey: .currentPartyID)
		requests = try container.decodeIfPresent([Party.JoinRequest].self, forKey: .requests) ?? []
	}
	
	private enum CodingKeys: String, CodingKey {
		case subject = "Subject"
		case currentPartyID = "CurrentPartyID"
		case requests = "Requests"
	}
}
