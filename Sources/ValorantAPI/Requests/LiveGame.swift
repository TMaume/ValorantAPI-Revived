import Foundation
import Protoquest
import HandyOperators

extension ValorantClient {
	/// Gets the live match (or pregame/agent select) a player is currently in.
	public func getLiveMatch(inPregame: Bool) async throws -> Match.ID? {
		do {
			return try await send(LivePlayerInfoRequest(
				playerID: userID, inPregame: inPregame
			)).matchID
		} catch APIError.resourceNotFound {
			return nil
		}
	}
	
	/// Gets the pregame (agent select) info for a match in that state.
	public func getLivePregameInfo(_ matchID: Match.ID) async throws -> LivePregameInfo {
		try await send(LiveMatchInfoRequest(
			matchID: matchID, inPregame: true
		))
	}
	
	/// Gets the live game info for a running match.
	public func getLiveGameInfo(_ matchID: Match.ID) async throws -> LiveGameInfo {
		try await send(LiveMatchInfoRequest(
			matchID: matchID, inPregame: false
		))
	}
	
	/// Selects or locks in an agent.
	public func pickAgent(
		_ agentID: Agent.ID, in matchID: Match.ID,
		shouldLock: Bool = false
	) async throws -> LivePregameInfo {
		try await send(PickAgentRequest(
			matchID: matchID, agentID: agentID,
			shouldLock: shouldLock
		))
	}
	
	/// Selects an agent without locking in.
	public func selectAgent(_ agentID: Agent.ID, in matchID: Match.ID) async throws -> LivePregameInfo {
		try await pickAgent(agentID, in: matchID, shouldLock: false)
	}
	
	/// Locks in an agent (ideally previously selected).
	public func lockInAgent(_ agentID: Agent.ID, in matchID: Match.ID) async throws -> LivePregameInfo {
		try await pickAgent(agentID, in: matchID, shouldLock: true)
	}
	
	/// Quits (dodges) a pregame match during agent select.
	public func quitPregameMatch(_ matchID: Match.ID) async throws {
		try await send(QuitPregameMatchRequest(matchID: matchID))
	}
	
	/// Disassociates the current player from an in-progress live game (e.g. leaving the Range or custom game).
	public func disassociateFromLiveGame(_ matchID: Match.ID) async throws {
		try await send(DisassociatePlayerRequest(playerID: userID, matchID: matchID))
	}
	
	/// Fetches the XMPP MUC password/token (and optional room JID) for pregame team chat.
	public func getPregameChatTokenResponse(for matchID: Match.ID) async throws -> MUCTokenResponse {
		try await send(PregameChatTokenRequest(matchID: matchID))
	}
	
	/// Fetches the XMPP MUC password/token for pregame team chat.
	public func getPregameChatToken(for matchID: Match.ID) async throws -> String {
		try await getPregameChatTokenResponse(for: matchID).token
	}
	
	/// Fetches the XMPP MUC password/token (and optional room JID) for core-game team chat.
	public func getCoreGameTeamChatTokenResponse(for matchID: Match.ID) async throws -> MUCTokenResponse {
		try await send(CoreGameTeamChatTokenRequest(matchID: matchID))
	}
	
	/// Fetches the XMPP MUC password/token for core-game team chat.
	public func getCoreGameTeamChatToken(for matchID: Match.ID) async throws -> String {
		try await getCoreGameTeamChatTokenResponse(for: matchID).token
	}
	
	/// Fetches the XMPP MUC password/token (and optional room JID) for core-game all chat.
	public func getCoreGameAllChatTokenResponse(for matchID: Match.ID) async throws -> MUCTokenResponse {
		try await send(CoreGameAllChatTokenRequest(matchID: matchID))
	}
	
	/// Fetches the XMPP MUC password/token for core-game all chat.
	public func getCoreGameAllChatToken(for matchID: Match.ID) async throws -> String {
		try await getCoreGameAllChatTokenResponse(for: matchID).token
	}
}

public struct MUCTokenResponse: Codable {
	public var token: String
	public var room: String?
	
	public init(token: String, room: String? = nil) {
		self.token = token
		self.room = room
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		if let uppercase = try container.decodeIfPresent(String.self, forKey: .token) {
			self.token = uppercase
		} else {
			self.token = try container.decodeIfPresent(String.self, forKey: .lowercaseToken) ?? ""
		}
		if let uppercaseRoom = try container.decodeIfPresent(String.self, forKey: .room) {
			self.room = uppercaseRoom
		} else {
			self.room = try container.decodeIfPresent(String.self, forKey: .lowercaseRoom)
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(token, forKey: .token)
		try container.encodeIfPresent(room, forKey: .room)
	}
	
	private enum CodingKeys: String, CodingKey {
		case token = "Token"
		case lowercaseToken = "token"
		case room = "Room"
		case lowercaseRoom = "room"
	}
}

private struct LivePlayerInfoRequest: GetJSONRequest, LiveGameRequest {
	var playerID: Player.ID
	var inPregame: Bool
	
	var path: String {
		"/\(inPregame ? "pregame" : "core-game")/v1/players/\(playerID)"
	}
	
	struct Response: Decodable {
		var matchID: Match.ID
		
		private enum CodingKeys: String, CodingKey {
			case matchID = "MatchID"
		}
	}
}

private struct LiveMatchInfoRequest<Response: Decodable>: GetJSONRequest, LiveGameRequest {
	var matchID: Match.ID
	var inPregame: Bool
	
	var path: String {
		"/\(inPregame ? "pregame" : "core-game")/v1/matches/\(matchID)"
	}
}

private struct PickAgentRequest: GetJSONRequest, LiveGameRequest {
	var httpMethod: String { "POST" }
	
	var matchID: Match.ID
	var agentID: Agent.ID
	var shouldLock: Bool
	
	var inPregame: Bool { true }
	
	var path: String {
		"/pregame/v1/matches/\(matchID)/\(shouldLock ? "lock" : "select")/\(agentID)"
	}
	
	typealias Response = LivePregameInfo
}

private struct QuitPregameMatchRequest: StatusCodeRequest, LiveGameRequest {
	var httpMethod: String { "POST" }
	
	var matchID: Match.ID
	
	var path: String {
		"/pregame/v1/matches/\(matchID)/quit"
	}
	
	func encode(to rawRequest: inout URLRequest) {}
}

private struct DisassociatePlayerRequest: StatusCodeRequest, LiveGameRequest {
	var httpMethod: String { "POST" }
	
	var playerID: Player.ID
	var matchID: Match.ID
	
	var path: String {
		"/core-game/v1/players/\(playerID)/disassociate/\(matchID)"
	}
	
	func encode(to rawRequest: inout URLRequest) {}
}

private struct PregameChatTokenRequest: GetJSONRequest, LiveGameRequest {
	var matchID: Match.ID
	var path: String { "/pregame/v1/matches/\(matchID)/chattoken" }
	typealias Response = MUCTokenResponse
}

private struct CoreGameTeamChatTokenRequest: GetJSONRequest, LiveGameRequest {
	var matchID: Match.ID
	var path: String { "/core-game/v1/matches/\(matchID)/teamchatmuctoken" }
	typealias Response = MUCTokenResponse
}

private struct CoreGameAllChatTokenRequest: GetJSONRequest, LiveGameRequest {
	var matchID: Match.ID
	var path: String { "/core-game/v1/matches/\(matchID)/allchatmuctoken" }
	typealias Response = MUCTokenResponse
}

/// marks requests as needing a different base URL
protocol LiveGameRequest: ValorantRequest {}

extension LiveGameRequest {
	func baseURL(for location: Location) -> URL {
		BaseURLs.liveGameAPI(location: location)
	}
}
