import Foundation
import Protoquest

extension ValorantClient {
	public func getFavorites() async throws -> Favorites {
		try await send(FavoritesRequest(playerID: userID))
	}
}

private struct FavoritesRequest: GetJSONRequest, GameDataRequest {
	var playerID: Player.ID
	
	var path: String {
		"/favorites/v1/players/\(playerID)/favorites"
	}
	
	typealias Response = Favorites
}
