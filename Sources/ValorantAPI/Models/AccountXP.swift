import Foundation

public struct AccountXP: Equatable, Codable {
	public var version: Int
	public var subject: User.ID
	public var progress: Progress
	public var history: [HistoryEntry]
	public var lastTimeGrantedFirstWin: Date?
	public var nextTimeFirstWinAvailable: Date?
	
	public init(
		version: Int = 1,
		subject: User.ID,
		progress: Progress,
		history: [HistoryEntry] = [],
		lastTimeGrantedFirstWin: Date? = nil,
		nextTimeFirstWinAvailable: Date? = nil
	) {
		self.version = version
		self.subject = subject
		self.progress = progress
		self.history = history
		self.lastTimeGrantedFirstWin = lastTimeGrantedFirstWin
		self.nextTimeFirstWinAvailable = nextTimeFirstWinAvailable
	}
	
	private enum CodingKeys: String, CodingKey {
		case version = "Version"
		case subject = "Subject"
		case progress = "Progress"
		case history = "History"
		case lastTimeGrantedFirstWin = "LastTimeGrantedFirstWin"
		case nextTimeFirstWinAvailable = "NextTimeFirstWinAvailable"
	}
	
	public struct Progress: Equatable, Codable {
		public var level: Int
		public var xp: Int
		
		public init(level: Int, xp: Int) {
			self.level = level
			self.xp = xp
		}
		
		private enum CodingKeys: String, CodingKey {
			case level = "Level"
			case xp = "XP"
		}
	}
	
	public struct HistoryEntry: Equatable, Codable, Identifiable {
		public var id: Match.ID
		public var matchStart: Date
		public var startProgress: Progress
		public var endProgress: Progress
		public var xpDelta: Int
		public var xpSources: [XPSource]
		public var xpMultipliers: [XPMultiplier]
		
		private enum CodingKeys: String, CodingKey {
			case id = "ID"
			case matchStart = "MatchStart"
			case startProgress = "StartProgress"
			case endProgress = "EndProgress"
			case xpDelta = "XPDelta"
			case xpSources = "XPSources"
			case xpMultipliers = "XPMultipliers"
		}
	}
	
	public struct XPSource: Equatable, Codable {
		public var id: String
		public var amount: Int
		
		private enum CodingKeys: String, CodingKey {
			case id = "ID"
			case amount = "Amount"
		}
	}
	
	public struct XPMultiplier: Equatable, Codable {
		public var id: String
		public var value: Double
		
		private enum CodingKeys: String, CodingKey {
			case id = "ID"
			case value = "Value"
		}
	}
}
