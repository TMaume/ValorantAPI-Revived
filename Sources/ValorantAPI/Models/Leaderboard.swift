import Foundation

public struct Leaderboard: Codable {
	public var seasonID: Season.ID
	public var totalPlayers: Int
	public var tierDetails: [String: TierDetail]?
	public var players: [Entry]
	public var startIndex: Int
	public var query: String?
	public var immortalStartingPage: Int?
	public var immortalStartingIndex: Int?
	public var topTierRRThreshold: Int?
	
	private enum CodingKeys: String, CodingKey {
		case seasonID = "SeasonID"
		case totalPlayers
		case tierDetails
		case players = "Players"
		case startIndex
		case query
		case immortalStartingPage
		case immortalStartingIndex
		case topTierRRThreshold
	}
	
	public struct Entry: Codable, Identifiable {
		public var playerCardID: PlayerCard.ID?
		public var titleID: PlayerTitle.ID?
		public var isBanned: Bool?
		public var isAnonymized: Bool
		public var puuid: User.ID?
		public var gameName: String?
		public var tagLine: String?
		public var leaderboardRank: Int
		public var rankedRating: Int
		public var numberOfWins: Int
		public var competitiveTier: Int
		
		public var id: String {
			"\(leaderboardRank)-\(puuid?.description ?? gameName ?? "anon")"
		}
		
		public var fullName: String {
			if let gameName, !gameName.isEmpty {
				if let tagLine, !tagLine.isEmpty {
					return "\(gameName) #\(tagLine)"
				}
				return gameName
			}
			return "Secret Agent"
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			playerCardID = try container.decodeIfPresent(PlayerCard.ID.self, forKey: .playerCardID)
			titleID = try container.decodeIfPresent(PlayerTitle.ID.self, forKey: .titleID)
			isBanned = try container.decodeIfPresent(Bool.self, forKey: .isBanned)
			isAnonymized = try container.decodeIfPresent(Bool.self, forKey: .isAnonymized) ?? false
			if let rawPUUID = try container.decodeIfPresent(String.self, forKey: .puuid), !rawPUUID.isEmpty {
				puuid = User.ID(rawPUUID)
			} else {
				puuid = nil
			}
			gameName = try container.decodeIfPresent(String.self, forKey: .gameName)
			tagLine = try container.decodeIfPresent(String.self, forKey: .tagLine)
			leaderboardRank = try container.decode(Int.self, forKey: .leaderboardRank)
			rankedRating = try container.decode(Int.self, forKey: .rankedRating)
			numberOfWins = try container.decode(Int.self, forKey: .numberOfWins)
			competitiveTier = try container.decode(Int.self, forKey: .competitiveTier)
		}
		
		private enum CodingKeys: String, CodingKey {
			case playerCardID = "PlayerCardID"
			case titleID = "TitleID"
			case isBanned = "IsBanned"
			case isAnonymized = "IsAnonymized"
			case puuid
			case gameName
			case tagLine
			case leaderboardRank
			case rankedRating
			case numberOfWins
			case competitiveTier
		}
	}
	
	public struct TierDetail: Codable {
		public var rankedRatingThreshold: Int
		public var startingPage: Int
		public var startingIndex: Int
	}
}
