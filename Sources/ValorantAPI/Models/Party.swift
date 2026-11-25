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
	// there's custom game data here too—handle that?
	
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
	}
	
	public struct State: SimpleRawWrapper {
		public static let `default` = Self("DEFAULT")
		public static let inMatchmaking = Self("MATCHMAKING")
		// TODO: in-game state?
		
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
