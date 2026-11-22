import Foundation
import Protoquest

extension ValorantClient {
	/// Fetches Riot's live Agent Mastery progression (`bloomline` / `Bonsais`) for the given user (or current user).
	public func getAgentMastery(userID: User.ID? = nil) async throws -> AgentMastery {
		try await send(AgentMasteryRequest(playerID: userID ?? self.userID))
	}
}

private struct AgentMasteryRequest: GetJSONRequest, GameDataRequest {
	var playerID: Player.ID
	
	var path: String {
		"/bloomline/v0/players/\(playerID)"
	}
	
	typealias Response = AgentMastery
}
