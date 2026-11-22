import Foundation
import Protoquest

extension ValorantClient {
	public func getCareerSummary(userID: User.ID? = nil) async throws -> CareerSummary {
		try await send(CareerSummaryRequest(userID: userID ?? self.userID))
	}
	
	public func getAccountLevel() async throws -> Int {
		try await send(AccountXPRequest(playerID: userID)).progress.level
	}
}

private struct CareerSummaryRequest: GetJSONRequest, GameDataRequest {
	var userID: Player.ID
	
	var path: String {
		"/mmr/v1/players/\(userID)"
	}
	
	typealias Response = CareerSummary
}

private struct AccountXPRequest: GetJSONRequest, GameDataRequest {
	var playerID: Player.ID
	
	var path: String {
		"/account-xp/v1/players/\(playerID)"
	}
	
	struct Response: Decodable {
		var progress: Progress
		
		struct Progress: Decodable {
			var level: Int
			
			private enum CodingKeys: String, CodingKey {
				case level = "Level"
			}
		}
		
		private enum CodingKeys: String, CodingKey {
			case progress = "Progress"
		}
	}
}
