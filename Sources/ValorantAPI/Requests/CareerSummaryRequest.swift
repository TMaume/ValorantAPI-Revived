import Foundation
import Protoquest

extension ValorantClient {
	public func getCareerSummary(userID: User.ID? = nil) async throws -> CareerSummary {
		try await send(CareerSummaryRequest(userID: userID ?? self.userID))
	}
	
	public func getAccountLevel() async throws -> Int {
		try await getAccountXP().progress.level
	}
	
	public func getAccountXP() async throws -> AccountXP {
		try await send(AccountXPRequest(playerID: userID))
	}
	
	public func setActRankBadgeHidden(_ hidden: Bool) async throws {
		if hidden {
			try await send(HideActRankBadgeRequest(playerID: userID, httpMethod: "POST", action: "hideactrankbadge"))
		} else {
			do {
				try await send(HideActRankBadgeRequest(playerID: userID, httpMethod: "DELETE", action: "hideactrankbadge"))
			} catch APIError.badResponseCode(404, _, _), APIError.badResponseCode(405, _, _), APIError.resourceNotFound {
				try await send(HideActRankBadgeRequest(playerID: userID, httpMethod: "POST", action: "showactrankbadge"))
			}
		}
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
	
	typealias Response = AccountXP
}

private struct HideActRankBadgeRequest: StatusCodeRequest, GameDataRequest {
	var playerID: Player.ID
	var httpMethod: String
	var action: String
	
	var path: String {
		"/mmr/v1/players/\(playerID)/\(action)"
	}
	
	func encode(to rawRequest: inout URLRequest) {}
}
