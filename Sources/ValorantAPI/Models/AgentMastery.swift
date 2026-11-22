import Foundation

public struct AgentMastery: Equatable, Codable {
	public var bonsais: [Bonsai]
	
	public init(bonsais: [Bonsai] = []) {
		self.bonsais = bonsais
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		bonsais = try container.decodeIfPresent([Bonsai].self, forKey: .bonsais) ?? []
	}
	
	private enum CodingKeys: String, CodingKey {
		case bonsais = "Bonsais"
	}
	
	public func entry(for agentID: Agent.ID) -> Bonsai? {
		bonsais.first { $0.id == agentID }
	}
	
	public struct Bonsai: Equatable, Codable, Identifiable {
		public var id: Agent.ID
		public var hypeID: LowercaseUUID?
		public var backgroundID: LowercaseUUID?
		public var clipID: LowercaseUUID?
		public var borderID: LowercaseUUID?
		public var flourish: Flourish?
		public var trackProgressList: [TrackProgress]
		
		public init(
			id: Agent.ID,
			hypeID: LowercaseUUID? = nil,
			backgroundID: LowercaseUUID? = nil,
			clipID: LowercaseUUID? = nil,
			borderID: LowercaseUUID? = nil,
			flourish: Flourish? = nil,
			trackProgressList: [TrackProgress] = []
		) {
			self.id = id
			self.hypeID = hypeID
			self.backgroundID = backgroundID
			self.clipID = clipID
			self.borderID = borderID
			self.flourish = flourish
			self.trackProgressList = trackProgressList
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			id = try container.decode(Agent.ID.self, forKey: .id)
			hypeID = try container.decodeIfPresent(LowercaseUUID.self, forKey: .hypeID)
			backgroundID = try container.decodeIfPresent(LowercaseUUID.self, forKey: .backgroundID)
			clipID = try container.decodeIfPresent(LowercaseUUID.self, forKey: .clipID)
			borderID = try container.decodeIfPresent(LowercaseUUID.self, forKey: .borderID)
			flourish = try container.decodeIfPresent(Flourish.self, forKey: .flourish)
			trackProgressList = try container.decodeIfPresent([TrackProgress].self, forKey: .trackProgressList) ?? []
		}
		
		private enum CodingKeys: String, CodingKey {
			case id = "BonsaiID"
			case hypeID = "HypeID"
			case backgroundID = "BackgroundID"
			case clipID = "ClipID"
			case borderID = "BorderID"
			case flourish = "Flourish"
			case trackProgressList = "TrackProgressList"
		}
	}
	
	public struct Flourish: Equatable, Codable {
		public var shortLevel: Int
		public var previousShortLevel: Int
		public var longLevel: Int
		public var flourishID: LowercaseUUID?
		public var points: Int
		public var pointsVersion: Int?
		
		public init(
			shortLevel: Int = 0,
			previousShortLevel: Int = 0,
			longLevel: Int = 0,
			flourishID: LowercaseUUID? = nil,
			points: Int = 0,
			pointsVersion: Int? = nil
		) {
			self.shortLevel = shortLevel
			self.previousShortLevel = previousShortLevel
			self.longLevel = longLevel
			self.flourishID = flourishID
			self.points = points
			self.pointsVersion = pointsVersion
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			shortLevel = try container.decodeIfPresent(Int.self, forKey: .shortLevel) ?? 0
			previousShortLevel = try container.decodeIfPresent(Int.self, forKey: .previousShortLevel) ?? 0
			longLevel = try container.decodeIfPresent(Int.self, forKey: .longLevel) ?? 0
			flourishID = try container.decodeIfPresent(LowercaseUUID.self, forKey: .flourishID)
			points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 0
			pointsVersion = try container.decodeIfPresent(Int.self, forKey: .pointsVersion)
		}
		
		private enum CodingKeys: String, CodingKey {
			case shortLevel = "ShortLevel"
			case previousShortLevel = "PreviousShortLevel"
			case longLevel = "LongLevel"
			case flourishID = "FlourishID"
			case points = "Points"
			case pointsVersion = "PointsVersion"
		}
	}
	
	public struct TrackProgress: Equatable, Codable {
		public var trackID: LowercaseUUID?
		public var trackLevel: Int
		
		public init(trackID: LowercaseUUID? = nil, trackLevel: Int = 0) {
			self.trackID = trackID
			self.trackLevel = trackLevel
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			trackID = try container.decodeIfPresent(LowercaseUUID.self, forKey: .trackID)
			trackLevel = try container.decodeIfPresent(Int.self, forKey: .trackLevel) ?? 0
		}
		
		private enum CodingKeys: String, CodingKey {
			case trackID = "TrackID"
			case trackLevel = "TrackLevel"
		}
	}
}
