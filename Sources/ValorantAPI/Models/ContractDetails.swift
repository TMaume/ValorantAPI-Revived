import Foundation
import ErgonomicCodable

public struct ContractDetails: Equatable, Codable {
	public var contracts: [Contract]
	public var activeSpecialContract: Contract.ID?
	public var missions: [Mission]
	public var missionMetadata: MissionMetadata
	public var recruitmentProgress: [RecruitmentEventProgress]?
	// Technically this object also lists processed matches, but I don't care about those right now and they'd be a significant extra effort to add.
	
	public init(
		contracts: [Contract],
		activeSpecialContract: Contract.ID?,
		missions: [Mission],
		missionMetadata: MissionMetadata,
		recruitmentProgress: [RecruitmentEventProgress]? = nil
	) {
		self.contracts = contracts
		self.activeSpecialContract = activeSpecialContract
		self.missions = missions
		self.missionMetadata = missionMetadata
		self.recruitmentProgress = recruitmentProgress
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		contracts = try container.decode([Contract].self, forKey: .contracts)
		activeSpecialContract = try container.decodeIfPresent(Contract.ID.self, forKey: .activeSpecialContract)
		missions = try container.decode([Mission].self, forKey: .missions)
		missionMetadata = try container.decode(MissionMetadata.self, forKey: .missionMetadata)
		
		if let array = try? container.decodeIfPresent([RecruitmentEventProgress].self, forKey: .recruitmentProgress) {
			recruitmentProgress = array
		} else if let single = try? container.decodeIfPresent(RecruitmentEventProgress.self, forKey: .recruitmentProgress) {
			recruitmentProgress = [single]
		} else {
			recruitmentProgress = nil
		}
	}
	
	private enum CodingKeys: String, CodingKey {
		case contracts = "Contracts"
		case activeSpecialContract = "ActiveSpecialContract"
		case missions = "Missions"
		case missionMetadata = "MissionMetadata"
		case recruitmentProgress = "ActiveRecruitmentEventProgress"
	}
	
	public struct MissionMetadata: Equatable, Codable {
		/// `nil` when not completed
		public var hasCompletedNewPlayerExperience: Bool?
		/// The activation date for the last set of weeklies the user has completed.
		/// - Note: Can be `nil` for users that haven't completed any weeklies this act.
		public var weeklyCheckpoint: Date?
		/// When the next set of weekly missions will become available.
		public var weeklyRefillTime: Date?
		
		private enum CodingKeys: String, CodingKey {
			case hasCompletedNewPlayerExperience = "NPECompleted"
			case weeklyCheckpoint = "WeeklyCheckpoint"
			case weeklyRefillTime = "WeeklyRefillTime"
		}
	}
}

public struct Contract: Equatable, Codable, Identifiable {
	public typealias ID = ObjectID<Self, LowercaseUUID>
	public var id: ID
	
	public var progression: Progression
	public var levelReached: Int
	public var progressionTowardsNextLevel: Int
	
	public static func unprogressed(with id: ID) -> Self {
		.init(
			id: id,
			progression: .init(totalEarned: 0, highestRewardedLevel: [:]),
			levelReached: 0,
			progressionTowardsNextLevel: 0
		)
	}
	
	private enum CodingKeys: String, CodingKey {
		case id = "ContractDefinitionID"
		case progression = "ContractProgression"
		case levelReached = "ProgressionLevelReached"
		case progressionTowardsNextLevel = "ProgressionTowardsNextLevel"
	}
	
	public struct Progression: Equatable, Codable {
		public var totalEarned: Int
		@StringKeyedDictionary
		public var highestRewardedLevel: [LowercaseUUID: RewardedLevel]
		
		public init(totalEarned: Int, highestRewardedLevel: [LowercaseUUID: RewardedLevel] = [:]) {
			self.totalEarned = totalEarned
			self._highestRewardedLevel = .init(wrappedValue: highestRewardedLevel)
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			self.totalEarned = try container.decode(Int.self, forKey: .totalEarned)
			self._highestRewardedLevel = try container.decodeIfPresent(
				StringKeyedDictionary<LowercaseUUID, RewardedLevel>.self,
				forKey: .highestRewardedLevel
			) ?? .init(wrappedValue: [:])
		}
		
		private enum CodingKeys: String, CodingKey {
			case totalEarned = "TotalProgressionEarned"
			case highestRewardedLevel = "HighestRewardedLevel"
		}
		
		public struct RewardedLevel: Equatable, Codable {
			public var amount: Int
			public var version: Int
			
			private enum CodingKeys: String, CodingKey {
				case amount = "Amount"
				case version = "Version"
			}
		}
	}
}

public extension Contract.ID {
	static let freeAgents = Self("a3dd5293-4b3d-46de-a6d7-4493f0530d9b")!
}

public struct Mission: Equatable, Codable, Identifiable {
	public typealias ID = ObjectID<Self, LowercaseUUID>
	public var id: ID
	
	@StringKeyedDictionary
	public var objectiveProgress: [Objective.ID: Int]
	public var isComplete: Bool
	public var expirationTime: Date?
	
	private enum CodingKeys: String, CodingKey {
		case id = "ID"
		case objectiveProgress = "Objectives"
		case isComplete = "Complete"
		case expirationTime = "ExpirationTime"
	}
}

public enum Objective {
	public typealias ID = ObjectID<Self, LowercaseUUID>
}

public struct AgentContractProgress: Codable {
	var counters: [Counter]
	
	private enum CodingKeys: String, CodingKey {
		case counters = "Counters"
	}
	
	struct Counter: Codable {
		var id: ObjectID<Self, LowercaseUUID>
		var value: Int
		
		private enum CodingKeys: String, CodingKey {
			case id = "ID"
			case value = "Value"
		}
	}
}

public struct DailyTicketProgress: Codable {
	public static let zero = Self(
		remainingTime: 0,
		milestones: .init(repeating: .zero, count: 4)
	)
	
	public var remainingTime: TimeInterval
	public var milestones: [Milestone]
	
	private enum CodingKeys: String, CodingKey {
		case remainingTime = "RemainingLifetimeSeconds"
		case milestones = "Milestones"
	}
	
	public struct Milestone: Codable {
		public static let zero = Self(progress: 0, wasRedeemed: false)
		
		/// 0-4
		public var progress: Int
		/// honestly i can't figure out the logic behind when this is set to true vs left as false
		public var wasRedeemed: Bool
		public var isComplete: Bool { progress >= 4 }
		
		private enum CodingKeys: String, CodingKey {
			case progress = "Progress"
			case wasRedeemed = "BonusApplied"
		}
	}
}

public struct RecruitmentEventProgress: Equatable, Codable {
	public var agentID: Agent.ID
	public var version: Int?
	public var counterID: LowercaseUUID?
	public var progressionEarned: Int
	
	public init(
		agentID: Agent.ID,
		version: Int? = nil,
		counterID: LowercaseUUID? = nil,
		progressionEarned: Int = 0
	) {
		self.agentID = agentID
		self.version = version
		self.counterID = counterID
		self.progressionEarned = progressionEarned
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		agentID = try container.decode(Agent.ID.self, forKey: .agentID)
		version = try container.decodeIfPresent(Int.self, forKey: .version)
		counterID = try container.decodeIfPresent(LowercaseUUID.self, forKey: .counterID)
		progressionEarned = try container.decodeIfPresent(Int.self, forKey: .progressionEarned) ?? 0
	}
	
	private enum CodingKeys: String, CodingKey {
		case agentID = "AgentID"
		case version = "Version"
		case counterID = "CounterID"
		case progressionEarned = "ProgressionEarned"
	}
}

public struct ActiveRecruitmentEvent: Equatable, Codable {
	public var agentID: Agent.ID
	public var counterID: LowercaseUUID?
	public var milestoneThreshold: Int
	public var startDate: Date
	public var endDate: Date
	public var isActive: Bool
	
	public init(
		agentID: Agent.ID,
		counterID: LowercaseUUID? = nil,
		milestoneThreshold: Int = 200_000,
		startDate: Date = .distantPast,
		endDate: Date = .distantFuture,
		isActive: Bool = true
	) {
		self.agentID = agentID
		self.counterID = counterID
		self.milestoneThreshold = milestoneThreshold
		self.startDate = startDate
		self.endDate = endDate
		self.isActive = isActive
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		agentID = try container.decode(Agent.ID.self, forKey: .agentID)
		counterID = try container.decodeIfPresent(LowercaseUUID.self, forKey: .counterID)
		milestoneThreshold = try container.decodeIfPresent(Int.self, forKey: .milestoneThreshold) ?? 200_000
		startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? .distantPast
		endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? .distantFuture
		isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
	}
	
	private enum CodingKeys: String, CodingKey {
		case agentID = "AgentID"
		case counterID = "CounterID"
		case milestoneThreshold = "MilestoneThreshold"
		case startDate = "StartDate"
		case endDate = "EndDate"
		case isActive = "IsActive"
	}
}
