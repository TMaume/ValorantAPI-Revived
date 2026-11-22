import Foundation
import Protoquest

extension ValorantClient {
	public func getLoadout() async throws -> Loadout {
		try await send(LoadoutRequest(playerID: userID))
	}
	
	public func updateLoadout(to loadout: Loadout) async throws -> Loadout {
		try await send(LoadoutUpdateRequest(playerID: userID, loadout: loadout))
	}
	
	struct LoadoutRequest: GetJSONRequest, GameDataRequest {
		var playerID: Player.ID
		
		var path: String {
			"/personalization/v3/players/\(playerID)/playerloadout"
		}
		
		typealias Response = Loadout
		
		func decodeResponse(from raw: Protoresponse) throws -> Loadout {
			do {
				return try raw.decodeJSON()
			} catch {
				if
					let string = try? raw.decodeString(using: .utf8),
					string.contains("00000000-0000-0000-0000-000000000000")
				{
					throw Loadout.FetchError.uninitialized(playerID)
				}
				throw error
			}
		}
	}
	
	struct LoadoutUpdateRequest: JSONJSONRequest, GameDataRequest {
		var playerID: Player.ID
		var loadout: Loadout
		
		var body: Loadout { loadout }
		var httpMethod: String { "PUT" }
		
		var path: String {
			"/personalization/v3/players/\(playerID)/playerloadout"
		}
		
		typealias Response = Loadout
	}
}

extension Loadout {
	public enum FetchError: Error, LocalizedError {
		/// Thrown for loadouts initialized to the default zeroed-out UUIDs and missing properties.
		/// If you get this, you've likely signed into the wrong account (or somehow fetched data for the wrong region).
		case uninitialized(Player.ID)
		
		public var errorDescription: String? {
			switch self {
			case .uninitialized:
				return "It looks like this account has never played Valorant in this region!"
			}
		}
	}
}

public struct Loadout: Equatable, Codable {
	public var subject: User.ID
	/// incremented every time the loadout is changed
	public var version: Int
	public var isIncognito: Bool
	public var identity: Identity
	public var guns: [Gun]
	public var expressions: [Expression]
	
	public var sprays: [EquippedSpray] {
		zip(Spray.Slot.ID.inCCWOrder, expressions).compactMap { slot, expr in
			guard let spray = expr.spray else { return nil }
			return EquippedSpray(slot: slot, spray: spray)
		}
	}
	
	public init(
		subject: User.ID,
		version: Int,
		isIncognito: Bool,
		identity: Identity,
		guns: [Gun],
		expressions: [Expression]
	) {
		self.subject = subject
		self.version = version
		self.isIncognito = isIncognito
		self.identity = identity
		self.guns = guns
		self.expressions = expressions
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		subject = try container.decode(User.ID.self, forKey: .subject)
		version = try container.decode(Int.self, forKey: .version)
		isIncognito = try container.decode(Bool.self, forKey: .isIncognito)
		identity = try container.decode(Identity.self, forKey: .identity)
		guns = try container.decode([Gun].self, forKey: .guns)
		if let active = try container.decodeIfPresent([Expression].self, forKey: .expressions) {
			expressions = active
		} else if let legacySprays = try container.decodeIfPresent([EquippedSpray].self, forKey: .legacySprays) {
			let bySlot = Dictionary(uniqueKeysWithValues: legacySprays.map { ($0.slot, $0.spray) })
			expressions = Spray.Slot.ID.inCCWOrder.compactMap { slot in
				guard let spray = bySlot[slot] else { return nil }
				return Expression(typeID: .sprays, assetID: spray.rawID)
			}
		} else {
			expressions = []
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(subject, forKey: .subject)
		try container.encode(version, forKey: .version)
		try container.encode(isIncognito, forKey: .isIncognito)
		try container.encode(identity, forKey: .identity)
		try container.encode(guns, forKey: .guns)
		try container.encode(expressions, forKey: .expressions)
	}
	
	private enum CodingKeys: String, CodingKey {
		case subject = "Subject"
		case version = "Version"
		case identity = "Identity"
		case guns = "Guns"
		case expressions = "ActiveExpressions"
		case legacySprays = "Sprays"
		case isIncognito = "Incognito"
	}
	
	public struct Gun: Equatable, Codable {
		public var id: Weapon.ID
		public var skin: Skin
		public var buddy: Buddy?
		
		public init(id: Weapon.ID, skin: Skin, buddy: Buddy? = nil) {
			self.id = id
			self.skin = skin
			self.buddy = buddy
		}
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			id = try container.decodeValue(forKey: .id)
			
			let nested = try decoder.singleValueContainer()
			skin = try nested.decode(Skin.self)
			buddy = container.allKeys.contains(.buddyID) ? try nested.decode(Buddy.self) : nil
		}
		
		public func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(id, forKey: .id)
			
			try skin.encode(to: encoder)
			try buddy?.encode(to: encoder)
		}
		
		private enum CodingKeys: String, CodingKey {
			case id = "ID"
			case buddyID = "CharmID"
		}
		
		public struct Skin: Equatable, Codable {
			public var skin: Weapon.Skin.ID
			public var level: Weapon.Skin.Level.ID
			/// can be nil for freshly-bought lvl1 skins!
			public var chroma: Weapon.Skin.Chroma.ID?
			
			public init(
				skin: Weapon.Skin.ID,
				level: Weapon.Skin.Level.ID,
				chroma: Weapon.Skin.Chroma.ID?
			) {
				self.skin = skin
				self.level = level
				self.chroma = chroma
			}
			
			private enum CodingKeys: String, CodingKey {
				case skin = "SkinID"
				case level = "SkinLevelID"
				case chroma = "ChromaID"
			}
		}
		
		public struct Buddy: Equatable, Codable {
			public var buddy: Weapon.Buddy.ID
			public var level: Weapon.Buddy.Level.ID
			public var instance: Weapon.Buddy.Instance.ID
			
			public init(
				buddy: Weapon.Buddy.ID,
				level: Weapon.Buddy.Level.ID,
				instance: Weapon.Buddy.Instance.ID
			) {
				self.buddy = buddy
				self.level = level
				self.instance = instance
			}
			
			private enum CodingKeys: String, CodingKey {
				case buddy = "CharmID"
				case level = "CharmLevelID"
				case instance = "CharmInstanceID"
			}
		}
	}
	
	public struct Expression: Equatable, Codable {
		public static let empty = Self(typeID: .sprays, assetID: .stupidNullID)
		
		public var typeID: ItemType.ID
		public var assetID: LowercaseUUID
		
		public var isEmpty: Bool {
			assetID.isPseudoNull
		}
		
		public var spray: Spray.ID? {
			typeID == .sprays && !assetID.isPseudoNull ? .init(rawID: assetID) : nil
		}
		
		public var totem: Totem.ID? {
			typeID == .totems && !assetID.isPseudoNull ? .init(rawID: assetID) : nil
		}
		
		public static func spray(_ id: Spray.ID) -> Self {
			.init(typeID: .sprays, assetID: id.rawID)
		}
		
		public static func totem(_ id: Totem.ID) -> Self {
			.init(typeID: .totems, assetID: id.rawID)
		}
		
		public init(typeID: ItemType.ID, assetID: LowercaseUUID) {
			self.typeID = typeID
			self.assetID = assetID
		}
		
		private enum CodingKeys: String, CodingKey {
			case typeID = "TypeID"
			case assetID = "AssetID"
		}
	}
	
	public struct EquippedSpray: Equatable, Codable {
		public var slot: Spray.Slot.ID
		public var spray: Spray.ID
		
		public init(slot: Spray.Slot.ID, spray: Spray.ID) {
			self.slot = slot
			self.spray = spray
		}
		
		private enum CodingKeys: String, CodingKey {
			case slot = "EquipSlotID"
			case spray = "SprayID"
		}
	}
	
	public struct Identity: Equatable, Codable {
		public var card: PlayerCard.ID
		public var title: PlayerTitle.ID
		public var levelBorder: LevelBorder.ID
		public var isLevelHidden: Bool
		
		public init(
			card: PlayerCard.ID,
			title: PlayerTitle.ID,
			levelBorder: LevelBorder.ID,
			isLevelHidden: Bool
		) {
			self.card = card
			self.title = title
			self.levelBorder = levelBorder
			self.isLevelHidden = isLevelHidden
		}
		
		private enum CodingKeys: String, CodingKey {
			case card = "PlayerCardID"
			case title = "PlayerTitleID"
			case levelBorder = "PreferredLevelBorderID"
			case isLevelHidden = "HideAccountLevel"
		}
	}
}

extension LowercaseUUID {
	public var isPseudoNull: Bool {
		self == .stupidNullID
	}
}

extension ObjectID where RawID == LowercaseUUID {
	/// player cards/titles/level borders are initially set to an all-zeroes ID rather than null for no good reason.
	public var isPseudoNull: Bool {
		rawID.isPseudoNull
	}
}

public struct UpdatableLoadout: Equatable, Codable {
	public let subject: User.ID
	public var isIncognito: Bool
	public var identity: Loadout.Identity
	public var guns: [Weapon.ID: Loadout.Gun]
	public var expressions: [Int: Loadout.Expression]
	
	public init(
		subject: User.ID,
		isIncognito: Bool,
		identity: Loadout.Identity,
		guns: [Weapon.ID: Loadout.Gun],
		expressions: [Int: Loadout.Expression]
	) {
		self.subject = subject
		self.isIncognito = isIncognito
		self.identity = identity
		self.guns = guns
		self.expressions = expressions
	}
	
	public init(_ loadout: Loadout) {
		subject = loadout.subject
		isIncognito = loadout.isIncognito
		identity = loadout.identity
		guns = .init(uniqueKeysWithValues: loadout.guns.map { ($0.id, $0) })
		expressions = Dictionary(
			uniqueKeysWithValues: loadout.expressions
				.prefix(4)
				.enumerated()
				.filter { !$0.element.isEmpty }
		)
	}
	
	public func currentWeapon(for instance: Weapon.Buddy.Instance.ID) -> Weapon.ID? {
		guns.values.first { $0.buddy?.instance == instance }?.id
	}
}

extension Loadout {
	public init(_ loadout: UpdatableLoadout) {
		subject = loadout.subject
		version = -1
		isIncognito = loadout.isIncognito
		identity = loadout.identity
		guns = .init(loadout.guns.values)
		expressions = (0..<4).map { loadout.expressions[$0] ?? .empty }
	}
}
