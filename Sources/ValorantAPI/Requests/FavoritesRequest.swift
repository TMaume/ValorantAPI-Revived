import Foundation
import Protoquest

extension ValorantClient {
	public func getFavorites() async throws -> Favorites {
		try await send(FavoritesRequest(playerID: userID))
	}
	
	public func addFavorite(_ itemID: LowercaseUUID) async throws -> Favorites {
		if let updated = try await send(AddFavoriteRequest(playerID: userID, itemID: itemID.description)) {
			return updated
		}
		return try await getFavorites()
	}
	
	public func removeFavorite(itemID: LowercaseUUID, favoriteID: LowercaseUUID? = nil) async throws -> Favorites {
		var candidates: [String] = [
			itemID.description.replacingOccurrences(of: "-", with: ""),
		]
		if let favoriteID {
			let favNoDash = favoriteID.description.replacingOccurrences(of: "-", with: "")
			if !candidates.contains(favNoDash) {
				candidates.append(favNoDash)
			}
			if !candidates.contains(favoriteID.description) {
				candidates.append(favoriteID.description)
			}
		}
		if !candidates.contains(itemID.description) {
			candidates.append(itemID.description)
		}
		
		var lastError: Error?
		for candidate in candidates {
			do {
				if let updated = try await send(DeleteFavoriteRequest(playerID: userID, targetID: candidate)) {
					return updated
				}
				return try await getFavorites()
			} catch APIError.resourceNotFound {
				lastError = APIError.resourceNotFound
				continue
			} catch let APIError.badResponseCode(code, response, riotError) where code == 404 {
				lastError = APIError.badResponseCode(code, response, riotError)
				continue
			} catch {
				throw error
			}
		}
		throw lastError ?? APIError.resourceNotFound
	}
}

private struct FavoritesRequest: GetJSONRequest, GameDataRequest {
	var playerID: Player.ID
	
	var path: String {
		"/favorites/v1/players/\(playerID)/favorites"
	}
	
	typealias Response = Favorites
}

private struct AddFavoriteRequest: JSONEncodingRequest, Encodable, GameDataRequest {
	var playerID: Player.ID
	var itemID: String
	
	var path: String {
		"/favorites/v1/players/\(playerID)/favorites"
	}
	
	private enum CodingKeys: String, CodingKey {
		case itemID = "ItemID"
	}
	
	func decodeResponse(from raw: Protoresponse) throws -> Favorites? {
		guard !raw.body.isEmpty else { return nil }
		return try? ValorantClient.responseDecoder.decode(Favorites.self, from: raw.body)
	}
}

private struct DeleteFavoriteRequest: GameDataRequest {
	var httpMethod: String { "DELETE" }
	var playerID: Player.ID
	var targetID: String
	
	var path: String {
		"/favorites/v1/players/\(playerID)/favorites/\(targetID)"
	}
	
	func encode(to rawRequest: inout URLRequest) throws {}
	
	func decodeResponse(from raw: Protoresponse) throws -> Favorites? {
		guard !raw.body.isEmpty else { return nil }
		return try? ValorantClient.responseDecoder.decode(Favorites.self, from: raw.body)
	}
}
