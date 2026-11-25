import Foundation
import Protoquest

extension ValorantClient {
	public func getPartyPlayer() async throws -> PartyPlayer? {
		do {
			return try await send(PlayerPartyRequest(playerID: userID))
		} catch APIError.badResponseCode(404, _, _), APIError.resourceNotFound {
			return nil
		}
	}
	
	public func getPartyID() async throws -> Party.ID? {
		try await getPartyPlayer()?.currentPartyID
	}
	
	public func getPartyInfo(for id: Party.ID) async throws -> Party {
		try await send(PartyInfoRequest(partyID: id))
	}
	
	public func getPartyInfo() async throws -> Party? {
		guard let id = try await getPartyID() else { return nil }
		return try await getPartyInfo(for: id)
	}
	
	public func setReady(to isReady: Bool, in party: Party.ID) async throws -> Party {
		try await send(SetReadyRequest(
			partyID: party, playerID: userID,
			isReady: isReady
		))
	}
	
	public func changeQueue(to queue: QueueID, in party: Party.ID) async throws -> Party {
		try await send(ChangeQueueRequest(
			partyID: party,
			queueID: queue
		))
	}
	
	public func joinMatchmaking(in party: Party.ID) async throws -> Party {
		try await send(JoinMatchmakingRequest(partyID: party))
	}
	
	public func leaveMatchmaking(in party: Party.ID) async throws -> Party {
		try await send(LeaveMatchmakingRequest(partyID: party))
	}
	
	public func setPartyAccessibility(in party: Party.ID, to accessibility: Party.Accessibility) async throws -> Party {
		try await send(SetAccessibilityRequest(partyID: party, accessibility: accessibility))
	}
	
	public func generatePartyCode(in party: Party.ID) async throws -> Party {
		try await send(GenerateCodeRequest(partyID: party))
	}
	
	public func disablePartyCode(in party: Party.ID) async throws -> Party {
		try await send(DisableCodeRequest(partyID: party))
	}
	
	public func joinPartyByCode(_ code: String) async throws -> PartyPlayer {
		try await send(JoinByCodeRequest(code: code))
	}
	
	public func setPreferredServers(in party: Party.ID, to gamePodIDs: [String]) async throws -> Party {
		try await send(PreferredServerRequest(partyID: party, gamePodIDs: gamePodIDs))
	}
	
	public func inviteToParty(name: String, tag: String, in party: Party.ID) async throws -> Party {
		try await send(InvitePlayerByDisplayNameRequest(partyID: party, name: name, tag: tag))
	}
	
	public func joinParty(_ partyID: Party.ID) async throws -> Party {
		switch try await send(JoinPartyRequest(partyID: partyID, playerID: userID)) {
		case .party(let party):
			return party
		case .player(let partyPlayer):
			return try await getPartyInfo(for: partyPlayer.currentPartyID)
		case .empty:
			return try await getPartyInfo(for: partyID)
		}
	}
	
	public func leaveParty(_ partyID: Party.ID) async throws {
		try await send(LeavePartyRequest(partyID: partyID, playerID: userID))
	}
	
	public func removePlayerFromParty(_ playerID: Player.ID) async throws {
		try await send(RemovePlayerRequest(playerID: playerID))
	}
	
	public func transferPartyOwner(to playerID: Player.ID, in party: Party.ID) async throws -> Party {
		try await send(TransferOwnerRequest(partyID: party, playerID: playerID))
	}
	
	public func declinePartyRequest(_ requestID: String, in party: Party.ID) async throws -> Party {
		try await send(DeclineRequestRequest(partyID: party, requestID: requestID))
	}
	
	public func declinePartyInvite(for partyID: Party.ID) async throws {
		try await send(DeclineInviteRequest(partyID: partyID))
	}
	
	public func startSoloExperience() async throws {
		try await send(StartSoloExperienceRequest(playerID: userID))
	}
	
	public func getPartyMUCToken(for partyID: Party.ID) async throws -> String {
		try await send(PartyMUCTokenRequest(partyID: partyID)).token
	}
}

private let pathSegmentAllowed: CharacterSet = {
	var set = CharacterSet.urlPathAllowed
	set.remove(charactersIn: "/?#")
	return set
}()

private func encodePathSegment(_ value: String) -> String {
	value.addingPercentEncoding(withAllowedCharacters: pathSegmentAllowed) ?? value
}

private struct PlayerPartyRequest: GetJSONRequest, LiveGameRequest {
	var playerID: Player.ID
	
	var path: String {
		"/parties/v1/players/\(playerID)"
	}
	
	typealias Response = PartyPlayer
}

private struct PartyInfoRequest: GetJSONRequest, LiveGameRequest {
	var partyID: Party.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)"
	}
	
	typealias Response = Party
}

private struct SetReadyRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	var playerID: Player.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/members/\(playerID)/setReady"
	}
	
	var isReady: Bool
	
	private enum CodingKeys: String, CodingKey {
		case isReady = "ready"
	}
	
	typealias Response = Party
}

private struct ChangeQueueRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/queue"
	}
	
	var queueID: QueueID
	
	private enum CodingKeys: String, CodingKey {
		case queueID = "queueID"
	}
	
	typealias Response = Party
}

private struct JoinMatchmakingRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/matchmaking/join"
	}
	
	private enum CodingKeys: CodingKey {}
	
	typealias Response = Party
}

private struct LeaveMatchmakingRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/matchmaking/leave"
	}
	
	private enum CodingKeys: CodingKey {}
	
	typealias Response = Party
}

private struct SetAccessibilityRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	var accessibility: Party.Accessibility
	
	var path: String {
		"/parties/v1/parties/\(partyID)/accessibility"
	}
	
	private enum CodingKeys: String, CodingKey {
		case accessibility
	}
	
	typealias Response = Party
}

private struct GenerateCodeRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/invitecode"
	}
	
	private enum CodingKeys: CodingKey {}
	
	typealias Response = Party
}

private struct DisableCodeRequest: GetJSONRequest, LiveGameRequest {
	var httpMethod: String { "DELETE" }
	var partyID: Party.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/invitecode"
	}
	
	typealias Response = Party
}

private struct JoinByCodeRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var code: String
	
	var path: String {
		"/parties/v1/players/joinbycode/\(encodePathSegment(code))"
	}
	
	private enum CodingKeys: CodingKey {}
	
	typealias Response = PartyPlayer
}

private struct PreferredServerRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	var gamePodIDs: [String]
	
	var path: String {
		"/parties/v1/parties/\(partyID)/preferredgamepods"
	}
	
	private enum CodingKeys: String, CodingKey {
		case gamePodIDs = "GamePodIDS"
	}
	
	typealias Response = Party
}

private struct InvitePlayerByDisplayNameRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	var name: String
	var tag: String
	
	var path: String {
		"/parties/v1/parties/\(partyID)/invites/name/\(encodePathSegment(name))/tag/\(encodePathSegment(tag))"
	}
	
	private enum CodingKeys: CodingKey {}
	
	typealias Response = Party
}

private struct JoinPartyRequest: JSONEncodingRequest, Encodable, LiveGameRequest {
	enum Response {
		case party(Party)
		case player(PartyPlayer)
		case empty
	}
	
	var partyID: Party.ID
	var playerID: Player.ID
	
	var path: String {
		"/parties/v1/players/\(playerID)/joinparty/\(partyID)"
	}
	
	private enum CodingKeys: CodingKey {}
	
	func decodeResponse(from raw: Protoresponse) throws -> Response {
		let data = raw.body
		if data.isEmpty {
			return .empty
		}
		if let party = try? ValorantClient.responseDecoder.decode(Party.self, from: data) {
			return .party(party)
		}
		if let player = try? ValorantClient.responseDecoder.decode(PartyPlayer.self, from: data) {
			return .player(player)
		}
		return .empty
	}
}

private struct LeavePartyRequest: JSONEncodingRequest, Encodable, StatusCodeRequest, LiveGameRequest {
	var partyID: Party.ID
	var playerID: Player.ID
	
	var path: String {
		"/parties/v1/players/\(playerID)/leaveparty/\(partyID)"
	}
	
	private enum CodingKeys: CodingKey {}
}

private struct RemovePlayerRequest: StatusCodeRequest, LiveGameRequest {
	var httpMethod: String { "DELETE" }
	var playerID: Player.ID
	
	var path: String {
		"/parties/v1/players/\(playerID)"
	}
	
	func encode(to rawRequest: inout URLRequest) {}
}

private struct TransferOwnerRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	var playerID: Player.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/members/\(playerID)/owner"
	}
	
	private enum CodingKeys: CodingKey {}
	
	typealias Response = Party
}

private struct DeclineRequestRequest: JSONJSONRequest, Encodable, LiveGameRequest {
	var partyID: Party.ID
	var requestID: String
	
	var path: String {
		"/parties/v1/parties/\(partyID)/request/\(encodePathSegment(requestID))/decline"
	}
	
	private enum CodingKeys: CodingKey {}
	
	typealias Response = Party
}

private struct DeclineInviteRequest: JSONEncodingRequest, Encodable, StatusCodeRequest, LiveGameRequest {
	var partyID: Party.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/invites/decline"
	}
	
	private enum CodingKeys: CodingKey {}
}

private struct StartSoloExperienceRequest: JSONEncodingRequest, Encodable, StatusCodeRequest, LiveGameRequest {
	var playerID: Player.ID
	
	var path: String {
		"/parties/v1/players/\(playerID)/startsoloexperience"
	}
	
	private enum CodingKeys: CodingKey {}
}

private struct PartyMUCTokenRequest: GetJSONRequest, LiveGameRequest {
	var partyID: Party.ID
	
	var path: String {
		"/parties/v1/parties/\(partyID)/muctoken"
	}
	
	typealias Response = MUCTokenResponse
}
