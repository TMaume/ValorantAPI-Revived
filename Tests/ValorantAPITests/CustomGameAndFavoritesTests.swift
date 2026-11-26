import XCTest
@testable import ValorantAPI

final class CustomGameAndFavoritesTests: XCTestCase {
	private static let tacticalMaps = [
		"/Game/Maps/Ascent/Ascent",
		"/Game/Maps/Bonsai/Bonsai",
		"/Game/Maps/Canyon/Canyon",
		"/Game/Maps/Duality/Duality",
		"/Game/Maps/Foxtrot/Foxtrot",
		"/Game/Maps/Infinity/Infinity",
		"/Game/Maps/Jam/Jam",
		"/Game/Maps/Juliett/Juliett",
		"/Game/Maps/Pitt/Pitt",
		"/Game/Maps/Plummet/Plummet",
		"/Game/Maps/Port/Port",
		"/Game/Maps/Rook/Rook",
		"/Game/Maps/Triad/Triad",
	]
	
	private static let hurmMaps = [
		"/Game/Maps/HURM/HURM_Alley/HURM_Alley",
		"/Game/Maps/HURM/HURM_Bowl/HURM_Bowl",
		"/Game/Maps/HURM/HURM_Helix/HURM_Helix",
		"/Game/Maps/HURM/HURM_HighTide/HURM_HighTide",
		"/Game/Maps/HURM/HURM_Yard/HURM_Yard",
	]
	
	private static let skirmishMaps = [
		"/Game/Maps/Duel/Duel_1/Skirmish_A",
		"/Game/Maps/Duel/Duel_2/Skirmish_B",
		"/Game/Maps/Duel/Duel_3/Skirmish_C",
		"/Game/Maps/Duel/Duel_Platform/Skirmish_D",
		"/Game/Maps/Duel/Duel_Heady/Skirmish_E",
	]
	
	private static let gauntletMaps = [
		"/Game/Maps/AbilityDraft/AbilityDraft",
	]
	
	private static let rangeMaps = [
		"/Game/Maps/Poveglia/Range",
		"/Game/Maps/PovegliaV2/RangeV2",
	]
	
	private static let internalMaps = [
		"/Game/Maps/NPEV2/NPEV2",
	]
	
	private static let all27Maps = tacticalMaps + hurmMaps + skirmishMaps + gauntletMaps + rangeMaps + internalMaps
	
	func testCustomGameConfigsDecodingWithoutAndWithQueues() throws {
		let minimalJSON = Data("""
		{
			"Enabled": true,
			"EnabledMaps": ["/Game/Maps/Ascent/Ascent"],
			"EnabledModes": ["/Game/GameModes/Bomb/BombGameMode.BombGameMode_C"]
		}
		""".utf8)
		let minimal = try ValorantClient.responseDecoder.decode(CustomGameConfigs.self, from: minimalJSON)
		XCTAssertTrue(minimal.enabled)
		XCTAssertEqual(minimal.enabledMaps, ["/Game/Maps/Ascent/Ascent"])
		XCTAssertEqual(minimal.enabledModes, ["/Game/GameModes/Bomb/BombGameMode.BombGameMode_C"])
		XCTAssertTrue(minimal.queues.isEmpty)
		
		let withQueuesJSON = Data("""
		{
			"Enabled": true,
			"EnabledMaps": ["/Game/Maps/Ascent/Ascent", "/Game/Maps/HURM/HURM_Alley/HURM_Alley"],
			"EnabledModes": ["/Game/GameModes/Bomb/BombGameMode.BombGameMode_C"],
			"Queues": [
				{
					"QueueID": "hurm",
					"Enabled": true,
					"Mode": "/Game/GameModes/HURM/HURM.HURM_C",
					"MapWeights": [
						"/Game/Maps/HURM/HURM_Alley/HURM_Alley:1",
						"/Game/Maps/HURM/HURM_Bowl/HURM_Bowl:1.5"
					]
				}
			]
		}
		""".utf8)
		let withQueues = try ValorantClient.responseDecoder.decode(CustomGameConfigs.self, from: withQueuesJSON)
		XCTAssertEqual(withQueues.queues.count, 1)
		XCTAssertEqual(withQueues.queues[0].queueID, "hurm")
		XCTAssertEqual(withQueues.queues[0].mapPaths, [
			"/Game/Maps/HURM/HURM_Alley/HURM_Alley",
			"/Game/Maps/HURM/HURM_Bowl/HURM_Bowl",
		])
	}
	
	func testValidMapsZeroCrossModeLeakage() {
		let configs = CustomGameConfigs(
			enabled: true,
			enabledMaps: Self.all27Maps + ["/Game/Maps/ascent/ascent", "/Game/Maps/FutureMode/FutureArena"],
			enabledModes: [
				"/Game/GameModes/Bomb/BombGameMode.BombGameMode_C",
				"/Game/GameModes/QuickBomb/QuickBombGameMode.QuickBombGameMode_C",
				"/Game/GameModes/_Development/Swiftplay_EndOfRoundCredits/SwiftPlay_GameMode_PrimaryAsset",
				"/Game/GameModes/Deathmatch/DeathmatchGameMode.DeathmatchGameMode_C",
				"/Game/GameModes/GunGame/GunGameTeamsGameMode.GunGameTeamsGameMode_C",
				"/Game/GameModes/OneForAll/OneForAll_GameMode_DataAsset_Desktop",
				"/Game/GameModes/SnowballFight/SnowballFightGameMode.SnowballFightGameMode_C",
				"/Game/GameModes/AROS/AROS_GameMode.AROS_GameMode_C",
				"/Game/GameModes/FortCollins/FortCollins.FortCollins_C",
				"/Game/GameModes/Dodgeball/Dodgeball_GameMode.Dodgeball_GameMode_C",
				"/Game/GameModes/HURM/HURM.HURM_C",
				"/Game/GameModes/Skirmish/SkirmishGameMode.SkirmishGameMode_C",
				"/Game/GameModes/SkirmishAscension/SkirmishAscensionGameMode.SkirmishAscensionGameMode_C",
				"/Game/GameModes/AbilityDraftArena/AbilityDraftArenaGameMode.AbilityDraftArenaGameMode_C",
				"/Game/GameModes/ShootingRange/ShootingRangeGameMode.ShootingRangeGameMode_C",
				"/Game/GameModes/NPEV2/NPEV2_GameMode.NPEV2_GameMode_C",
				"/Game/GameModes/FutureSpecial/FutureSpecialGameMode.FutureSpecialGameMode_C",
			],
			queues: [
				.init(
					queueID: "futurespecial",
					enabled: true,
					mode: "/Game/GameModes/FutureSpecial/FutureSpecialGameMode.FutureSpecialGameMode_C",
					mapWeights: ["/Game/Maps/FutureMode/FutureArena:1"]
				),
			]
		)
		
		let nonTacticalKnown = Set((Self.hurmMaps + Self.skirmishMaps + Self.gauntletMaps + Self.rangeMaps + Self.internalMaps + ["/Game/Maps/FutureMode/FutureArena"]).map { $0.lowercased() })
		
		let standardModes = [
			"/Game/GameModes/Bomb/BombGameMode.BombGameMode_C",
			"/Game/GameModes/QuickBomb/QuickBombGameMode.QuickBombGameMode_C",
			"/Game/GameModes/_Development/Swiftplay_EndOfRoundCredits/SwiftPlay_GameMode_PrimaryAsset",
			"/Game/GameModes/Deathmatch/DeathmatchGameMode.DeathmatchGameMode_C",
			"/Game/GameModes/GunGame/GunGameTeamsGameMode.GunGameTeamsGameMode_C",
			"/Game/GameModes/OneForAll/OneForAll_GameMode_DataAsset_Desktop",
			"/Game/GameModes/SnowballFight/SnowballFightGameMode.SnowballFightGameMode_C",
			"/Game/GameModes/AROS/AROS_GameMode.AROS_GameMode_C",
			"/Game/GameModes/FortCollins/FortCollins.FortCollins_C",
			"/Game/GameModes/Dodgeball/Dodgeball_GameMode.Dodgeball_GameMode_C",
		]
		for mode in standardModes {
			XCTAssertEqual(
				Set(configs.validMaps(forMode: mode, knownNonTacticalMapPaths: nonTacticalKnown)),
				Set(Self.tacticalMaps),
				"Standard-like mode \(mode) leaked non-tactical maps"
			)
		}
		
		XCTAssertEqual(
			Set(configs.validMaps(forMode: "/Game/GameModes/HURM/HURM.HURM_C", knownNonTacticalMapPaths: nonTacticalKnown)),
			Set(Self.hurmMaps)
		)
		XCTAssertEqual(
			Set(configs.validMaps(forMode: "/Game/GameModes/Skirmish/SkirmishGameMode.SkirmishGameMode_C", knownNonTacticalMapPaths: nonTacticalKnown)),
			Set(Self.skirmishMaps)
		)
		XCTAssertEqual(
			Set(configs.validMaps(forMode: "/Game/GameModes/SkirmishAscension/SkirmishAscensionGameMode.SkirmishAscensionGameMode_C", knownNonTacticalMapPaths: nonTacticalKnown)),
			Set(Self.skirmishMaps)
		)
		XCTAssertEqual(
			Set(configs.validMaps(forMode: "/Game/GameModes/AbilityDraftArena/AbilityDraftArenaGameMode.AbilityDraftArenaGameMode_C", knownNonTacticalMapPaths: nonTacticalKnown)),
			Set(Self.gauntletMaps)
		)
		XCTAssertEqual(
			Set(configs.validMaps(forMode: "/Game/GameModes/ShootingRange/ShootingRangeGameMode.ShootingRangeGameMode_C", knownNonTacticalMapPaths: nonTacticalKnown)),
			Set(Self.rangeMaps)
		)
		XCTAssertEqual(
			configs.validMaps(forMode: "/Game/GameModes/FutureSpecial/FutureSpecialGameMode.FutureSpecialGameMode_C", knownNonTacticalMapPaths: nonTacticalKnown),
			["/Game/Maps/FutureMode/FutureArena"]
		)
		XCTAssertEqual(
			configs.validMaps(forMode: "/Game/GameModes/UnknownUnlisted/Unknown_C", knownNonTacticalMapPaths: nonTacticalKnown),
			[]
		)
		
		let selectable = configs.selectableModes()
		XCTAssertFalse(selectable.contains(where: { $0.contains("NPEV2") || $0.contains("ShootingRange") }))
		XCTAssertTrue(selectable.contains("/Game/GameModes/Bomb/BombGameMode.BombGameMode_C"))
		XCTAssertTrue(selectable.contains("/Game/GameModes/HURM/HURM.HURM_C"))
	}
	
	func testFavoritesContainsAndSync() throws {
		let userID = User.ID("3fa8598d-066e-5bdb-998c-74c015c5dba5")!
		let favID = LowercaseUUID()
		let itemID = LowercaseUUID()
		let missingID = LowercaseUUID()
		
		let json = Data("""
		{
			"Subject": "\(userID.description)",
			"FavoritedContent": {
				"\(favID.description)": {
					"FavoriteID": "\(favID.description)",
					"ItemID": "\(itemID.description)"
				}
			}
		}
		""".utf8)
		var favorites = try ValorantClient.responseDecoder.decode(Favorites.self, from: json)
		XCTAssertTrue(favorites.contains(itemID))
		XCTAssertFalse(favorites.contains(missingID))
		XCTAssertEqual(favorites.itemIDs, [itemID])
		
		let addedID = LowercaseUUID()
		favorites.favoritedContent[addedID.description] = .init(id: addedID, itemID: addedID)
		XCTAssertTrue(favorites.contains(addedID))
		XCTAssertEqual(favorites.itemIDs, [itemID, addedID])
		
		favorites.favoritedContent.removeValue(forKey: favID.description)
		XCTAssertFalse(favorites.contains(itemID))
		XCTAssertTrue(favorites.contains(addedID))
	}
}
