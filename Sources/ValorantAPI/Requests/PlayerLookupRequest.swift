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
		var firstFatalError: Error?
		
		func probe(_ candidate: Location) async -> ProbeOutcome {
			do {
				try Task.checkCancellation()
				let history = try await self.in(candidate).getMatchHistory(userID: user.id, count: 1)
				if !history.isEmpty {
					return .found(candidate, history.first?.matchID)
				}
				return .empty(candidate)
			} catch is CancellationError {
				return .fatal(CancellationError())
			} catch let apiError as APIError {
				if apiError.recommendsReauthentication {
					return .fatal(apiError)
				}
				switch apiError {
				case .rateLimited, .scheduledDowntime:
					return .fatal(apiError)
				default:
					return .ignored
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
					return .fatal(urlError)
				default:
					return .ignored
				}
			} catch {
				return .ignored
			}
		}
		
		if let primary = candidateLocations.first {
			switch await probe(primary) {
			case .found(let loc, let matchID):
				return PlayerLookupResult(user: user, location: loc, latestMatchID: matchID)
			case .empty(let loc):
				firstEmptyLocation = loc
			case .fatal(let error):
				if error is CancellationError || (error as? APIError)?.recommendsReauthentication == true {
					throw error
				}
				firstFatalError = error
			case .ignored:
				break
			}
		}
		
		let remaining = Array(candidateLocations.dropFirst())
		if !remaining.isEmpty {
			let result = await withTaskGroup(of: (Int, ProbeOutcome).self) { group -> (found: (Location, Match.ID?)?, emptyIndex: Int?, emptyLoc: Location?, fatal: Error?) in
				for (offset, candidate) in remaining.enumerated() {
					group.addTask {
						(offset, await probe(candidate))
					}
				}
				var bestEmptyIndex: Int?
				var bestEmptyLocation: Location?
				var fatalError: Error?
				for await (offset, outcome) in group {
					switch outcome {
					case .found(let loc, let matchID):
						group.cancelAll()
						return ((loc, matchID), nil, nil, nil)
					case .empty(let loc):
						if bestEmptyIndex == nil || offset < bestEmptyIndex! {
							bestEmptyIndex = offset
							bestEmptyLocation = loc
						}
					case .fatal(let err):
						if fatalError == nil {
							fatalError = err
						}
					case .ignored:
						break
					}
				}
				return (nil, bestEmptyIndex, bestEmptyLocation, fatalError)
			}
			if let found = result.found {
				return PlayerLookupResult(user: user, location: found.0, latestMatchID: found.1)
			}
			if firstEmptyLocation == nil, let emptyLoc = result.emptyLoc {
				firstEmptyLocation = emptyLoc
			}
			if firstFatalError == nil, let fatal = result.fatal {
				firstFatalError = fatal
			}
		}
		
		if let fallback = firstEmptyLocation {
			return PlayerLookupResult(user: user, location: fallback, latestMatchID: nil)
		}
		if let firstFatalError {
			throw firstFatalError
		}
		throw PlayerLookupError.noRegionFound(gameName: user.gameName, tagLine: user.tagLine)
	}
}

private enum ProbeOutcome {
	case found(Location, Match.ID?)
	case empty(Location)
	case fatal(Error)
	case ignored
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
