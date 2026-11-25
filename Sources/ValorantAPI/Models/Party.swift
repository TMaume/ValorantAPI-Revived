import Foundation
import ErgonomicCodable

public struct Party: Identifiable, Codable {
	public typealias ID = ObjectID<Self, LowercaseUUID>
	
	public var id: ID
	public var mucName: String?
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
	
	public struct Member: Identifiable, Codable {
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
	
	public struct MatchmakingData: Codable {
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

public struct CustomGameConfigs: Codable {
	public var enabled: Bool
	public var enabledMaps: [String]
	public var enabledModes: [String]
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
		enabledMaps = try container.decodeIfPresent([String].self, forKey: .enabledMaps) ?? []
		enabledModes = try container.decodeIfPresent([String].self, forKey: .enabledModes) ?? []
	}
	
	private enum CodingKeys: String, CodingKey {
		case enabled = "Enabled"
		case enabledMaps = "EnabledMaps"
		case enabledModes = "EnabledModes"
	}
}

public extension CustomGameConfigs {
	enum ModeCategory {
		case standard
		case teamDeathmatch
		case skirmish
		case shootingRange
		
		public init(modePath: String) {
			let lower = modePath.lowercased()
			if lower.contains("hurm") {
				self = .teamDeathmatch
			} else if lower.contains("skirmish") {
				self = .skirmish
			} else if lower.contains("shootingrange") {
				self = .shootingRange
			} else {
				self = .standard
			}
		}
		
		public func accepts(mapPath: String) -> Bool {
			let lower = mapPath.lowercased()
			if lower.contains("npe") || lower.contains("tutorial") {
				return false
			}
			switch self {
			case .teamDeathmatch:
				return lower.contains("/hurm/")
			case .skirmish:
				return lower.contains("/skirmish/")
			case .shootingRange:
				return lower.contains("poveglia") || lower.contains("range")
			case .standard:
				return !lower.contains("/hurm/")
					&& !lower.contains("/skirmish/")
					&& !lower.contains("poveglia")
					&& !lower.contains("range")
					&& !lower.contains("gauntlet")
			}
		}
	}
	
	func validMaps(forMode modePath: String) -> [String] {
		let category = ModeCategory(modePath: modePath)
		return enabledMaps.filter { category.accepts(mapPath: $0) }
	}
}

public struct PartyPlayer: Codable {
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
