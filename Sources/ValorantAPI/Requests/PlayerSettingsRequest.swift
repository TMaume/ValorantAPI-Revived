import Foundation
import Protoquest

extension ValorantClient {
	public func getPlayerSettings() async throws -> PlayerSettings {
		do {
			return try await send(GetPlayerSettingsRequest())
		} catch APIError.resourceNotFound {
			throw PlayerSettingsError.notFound
		} catch let APIError.badResponseCode(code, response, riotError) {
			if riotError?.errorCode == "PLAYER_PREFERENCE_NOT_FOUND" ||
				(try? response.decodeString(using: .utf8))?.contains("PLAYER_PREFERENCE_NOT_FOUND") == true {
				throw PlayerSettingsError.notFound
			}
			throw APIError.badResponseCode(code, response, riotError)
		}
	}
	
	public func savePlayerSettings(_ data: String) async throws {
		try await send(SavePlayerSettingsRequest(
			body: .init(data: data, type: "Ares.PlayerSettings", productID: "Ares")
		))
	}
}

private protocol PlayerPreferencesRequest: ValorantRequest {}

extension PlayerPreferencesRequest {
	func baseURL(for location: Location) -> URL {
		URL(string: "https://player-preferences-usw2.pp.sgp.pvp.net")!
	}
}

private struct GetPlayerSettingsRequest: GetJSONRequest, PlayerPreferencesRequest {
	var path: String {
		"/playerPref/v3/getPreference/Ares.PlayerSettings"
	}
	
	typealias Response = PlayerSettings
}

private struct SavePlayerSettingsRequest: JSONEncodingRequest, StatusCodeRequest, PlayerPreferencesRequest {
	struct Body: Encodable {
		var data: String
		var type: String
		var productID: String
		
		private enum CodingKeys: String, CodingKey {
			case data
			case type
			case productID = "productId"
		}
	}
	
	var body: Body
	var httpMethod: String { "PUT" }
	
	var path: String {
		"/playerPref/v3/savePreference"
	}
}
