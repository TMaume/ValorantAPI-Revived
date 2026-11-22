import Foundation
import Protoquest

extension ValorantClient {
	public func getLeaderboard(
		region: String? = nil,
		queueID: QueueID = .competitive,
		seasonID: Season.ID,
		startIndex: Int = 0,
		size: Int = 100,
		query: String? = nil
	) async throws -> Leaderboard {
		try await send(LeaderboardRequest(
			region: region ?? location.region,
			queueID: queueID,
			seasonID: seasonID,
			startIndex: startIndex,
			size: size,
			query: query
		))
	}
}

private struct LeaderboardRequest: GetJSONRequest, GameDataRequest {
	var region: String
	var queueID: QueueID
	var seasonID: Season.ID
	var startIndex: Int
	var size: Int
	var query: String?
	
	var path: String {
		"/mmr/v1/leaderboards/affinity/\(region)/queue/\(queueID)/season/\(seasonID)"
	}
	
	var urlParams: [URLParameter] {
		("startIndex", startIndex)
		("size", size)
		query.flatMap { $0.isEmpty ? nil : ("query", $0) }
	}
	
	typealias Response = Leaderboard
}
