import Foundation

public struct PlayerSettings: Codable, Equatable {
	public var data: String
	public var type: String
	
	public init(data: String, type: String = "Ares.PlayerSettings") {
		self.data = data
		self.type = type
	}
}

public enum PlayerSettingsError: Error, LocalizedError {
	case notFound
	
	public var errorDescription: String? {
		switch self {
		case .notFound:
			return "No saved Valorant PC settings were found on Riot servers for this account."
		}
	}
}
