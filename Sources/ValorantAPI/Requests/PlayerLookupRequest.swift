import Foundation
import Protoquest

public enum PlayerLookupError: Error, LocalizedError {
	case invalidQuery
	case playerNotFound(gameName: String, tagLine: String)
	case noRegionFound(gameName: String, tagLine: String)
	
	public var errorDescription: String? {
		switch self {
		case .invalidQuery:
			return "Please enter both a Riot name and tag."
		case .playerNotFound(let gameName, let tagLine):
			return "Player \(gameName) #\(tagLine) could not be found."
		case .noRegionFound(let gameName, let tagLine):
			return "Player \(gameName) #\(tagLine) was found, but has no VALORANT match history in any region."
		}
	}
}

public struct PlayerLookupResult {
	public var user: User
	public var location: Location
	public var latestMatchID: Match.ID?
	
	public init(user: User, location: Location, latestMatchID: Match.ID? = nil) {
		self.user = user
		self.location = location
		self.latestMatchID = latestMatchID
	}
}

extension ValorantClient {
	/// Resolves a player's Riot ID (`gameName#tagLine`) to their ``User`` and active ``Location`` using Riot's native account aliases API and shard match-history probing.
	public func lookUpPlayer(gameName: String, tagLine: String) async throws -> (User, Location) {
		let result = try await lookUpPlayerInfo(gameName: gameName, tagLine: tagLine)
		return (result.user, result.location)
	}
	
	/// Resolves a player's Riot ID (`gameName#tagLine`) to their ``User``, active ``Location``, and most recent ``Match/ID`` (if any).
	public func lookUpPlayerInfo(gameName: String, tagLine: String) async throws -> PlayerLookupResult {
		let cleanName = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
		var cleanTag = tagLine.trimmingCharacters(in: .whitespacesAndNewlines)
		while cleanTag.hasPrefix("#") {
			cleanTag.removeFirst()
		}
		cleanTag = cleanTag.trimmingCharacters(in: .whitespacesAndNewlines)
		
		guard !cleanName.isEmpty, !cleanTag.isEmpty else {
			throw PlayerLookupError.invalidQuery
		}
		
		let matches: [PlayerAliasMatch]
		do {
			matches = try await send(PlayerLookupRequest(gameName: cleanName, tagLine: cleanTag))
		} catch APIError.resourceNotFound, APIError.badResponseCode(404, _, _) {
			throw PlayerLookupError.playerNotFound(gameName: cleanName, tagLine: cleanTag)
		}
		
		guard let match = matches.first(where: { $0.alias.active == true }) ?? matches.first else {
			throw PlayerLookupError.playerNotFound(gameName: cleanName, tagLine: cleanTag)
		}
		
		let user = User(id: match.puuid, gameName: match.alias.gameName, tagLine: match.alias.tagLine)
		
		var candidateLocations: [Location] = []
		var seenShards: Set<String> = []
		for candidate in [self.location, .europe, .northAmerica, .asiaPacific, .korea, .pbe] {
			if seenShards.insert(candidate.shard).inserted {
				candidateLocations.append(candidate)
			}
		}
		
		var firstEmptyLocation: Location?
		for candidate in candidateLocations {
			try Task.checkCancellation()
			do {
				let history = try await self.in(candidate).getMatchHistory(userID: user.id)
				if !history.isEmpty {
					return PlayerLookupResult(user: user, location: candidate, latestMatchID: history.first?.matchID)
				}
				if firstEmptyLocation == nil {
					firstEmptyLocation = candidate
				}
			} catch is CancellationError {
				throw CancellationError()
			} catch let apiError as APIError {
				if apiError.recommendsReauthentication {
					throw apiError
				}
				switch apiError {
				case .rateLimited, .scheduledDowntime:
					throw apiError
				default:
					continue
				}
			} catch let urlError as URLError {
				switch urlError.code {
				case .cancelled,
					 .notConnectedToInternet,
					 .networkConnectionLost,
					 .dataNotAllowed,
					 .internationalRoamingOff,
					 .timedOut,
					 .cannotFindHost,
					 .dnsLookupFailed:
					throw urlError
				default:
					continue
				}
			}
		}
		
		if let fallback = firstEmptyLocation {
			return PlayerLookupResult(user: user, location: fallback, latestMatchID: nil)
		}
		throw PlayerLookupError.noRegionFound(gameName: user.gameName, tagLine: user.tagLine)
	}
}

private struct PlayerLookupRequest: GetJSONRequest, ValorantRequest {
	var gameName: String
	var tagLine: String
	
	var path: String { "aliases/v1/aliases" }
	
	var urlParams: [URLParameter] {
		("gameName", gameName)
		("tagLine", tagLine)
	}
	
	func baseURL(for location: Location) -> URL {
		BaseURLs.accountAPI
	}
	
	typealias Response = [PlayerAliasMatch]
}

private struct PlayerAliasMatch: Decodable {
	var puuid: User.ID
	var alias: Alias
	
	struct Alias: Decodable {
		var gameName: String
		var tagLine: String
		var active: Bool?
		
		private enum CodingKeys: String, CodingKey {
			case gameName = "game_name"
			case tagLine = "tag_line"
			case active
		}
	}
}
