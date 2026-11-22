import Foundation

public struct Inventory: Codable {
	public static let starterAgents: Set<Agent.ID> = [.jett, .phoenix, .sova, .brimstone, .sage]
	public static let starterTotems: Set<Totem.ID> = [.statComFlex]
	
	public let purchasedAgents: Set<Agent.ID>
	/// includes starter agents, unlike ``purchasedAgents``
	public let agents: Set<Agent.ID>
	public let cards: Set<PlayerCard.ID>
	public let titles: Set<PlayerTitle.ID>
	public let skinLevels: Set<Weapon.Skin.Level.ID>
	public let skinChromas: Set<Weapon.Skin.Chroma.ID>
	public let sprays: Set<Spray.ID>
	public let contracts: Set<Contract.ID>
	public let buddies: [Weapon.Buddy.Level.ID: [Weapon.Buddy.Instance.ID]]
	public let totems: Set<Totem.ID>
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		purchasedAgents = try container.decode(Set<Agent.ID>.self, forKey: .purchasedAgents)
		agents = try container.decode(Set<Agent.ID>.self, forKey: .agents)
		cards = try container.decode(Set<PlayerCard.ID>.self, forKey: .cards)
		titles = try container.decode(Set<PlayerTitle.ID>.self, forKey: .titles)
		skinLevels = try container.decode(Set<Weapon.Skin.Level.ID>.self, forKey: .skinLevels)
		skinChromas = try container.decode(Set<Weapon.Skin.Chroma.ID>.self, forKey: .skinChromas)
		sprays = try container.decode(Set<Spray.ID>.self, forKey: .sprays)
		contracts = try container.decode(Set<Contract.ID>.self, forKey: .contracts)
		buddies = try container.decode([Weapon.Buddy.Level.ID: [Weapon.Buddy.Instance.ID]].self, forKey: .buddies)
		let decodedTotems = try container.decodeIfPresent(Set<Totem.ID>.self, forKey: .totems) ?? []
		totems = decodedTotems.union(Self.starterTotems).subtracting([.none])
	}
	
	init(_ raw: APIInventory) {
		let collections = Dictionary(
			uniqueKeysWithValues: raw.collectionsByType
				.map { ($0.id, $0) }
		)
		
		func collectItems<ID>(_ type: ItemType.ID) -> Set<ID>
		where ID: ObjectIDProtocol, ID.RawID == LowercaseUUID {
			Set(collections[type]?.items.lazy.map(\.id).map(ID.init(rawID:)) ?? [])
		}
		
		func collectItems<Item: InventoryItem>() -> Set<Item.ID> {
			let ids = collections[Item.typeID]?.items
				.lazy
				.map(\.id)
				.map(Item.ID.init(rawID:))
			return ids.map(Set.init) ?? []
		}
		
		purchasedAgents = collectItems(.agents)
		cards = collectItems(.cards)
		titles = collectItems(.titles)
		skinLevels = collectItems(.skinLevels)
		skinChromas = collectItems(.skinChromas)
		sprays = collectItems(.sprays)
		contracts = collectItems(.contracts)
		buddies = collections[.buddies]?.items.lazy.map(Buddy.init)
			.reduce(into: [:]) { $0[$1.level, default: []].append($1.instance) }
			?? [:]
		totems = collectItems(.totems).union(Self.starterTotems).subtracting([.none])
		
		assert(purchasedAgents.intersection(Self.starterAgents).isEmpty)
		agents = purchasedAgents.union(Self.starterAgents)
	}
	
	public func owns<Item: InventoryItem>(_ itemID: Item.ID) -> Bool {
		self[keyPath: Item.ownedItems].contains(itemID)
	}
	 
	private struct Buddy {
		var level: Weapon.Buddy.Level.ID
		var instance: Weapon.Buddy.Instance.ID
		
		init(_ item: ItemCollection.Item) {
			level = .init(rawID: item.id)
			instance = .init(rawID: item.instanceID!)
		}
	}
}

public protocol InventoryItem {
	associatedtype OwnedItems: Collection<ID>
	typealias ID = ObjectID<Self, LowercaseUUID>
	
	static var ownedItems: KeyPath<Inventory, OwnedItems> { get }
	static var typeID: ItemType.ID { get }
}

extension Agent: InventoryItem {
	public static let ownedItems = \Inventory.agents
	public static let typeID = ItemType.ID.agents
}

extension PlayerCard: InventoryItem {
	public static let ownedItems = \Inventory.cards
	public static let typeID = ItemType.ID.cards
}

extension PlayerTitle: InventoryItem {
	public static let ownedItems = \Inventory.titles
	public static let typeID = ItemType.ID.titles
}

extension Weapon.Skin.Level: InventoryItem {
	public static let ownedItems = \Inventory.skinLevels
	public static let typeID = ItemType.ID.skinLevels
}

extension Weapon.Skin.Chroma: InventoryItem {
	public static let ownedItems = \Inventory.skinChromas
	public static let typeID = ItemType.ID.skinChromas
}

extension Spray: InventoryItem {
	public static let ownedItems = \Inventory.sprays
	public static let typeID = ItemType.ID.sprays
}

extension Weapon.Buddy.Level: InventoryItem {
	public static let ownedItems = \Inventory.buddies.keys
	public static let typeID = ItemType.ID.buddies
}

/// Flex / Totem cosmetic item (equippable in the expression wheel).
public enum Totem {
	public typealias ID = ObjectID<Self, LowercaseUUID>
}

extension Totem: InventoryItem {
	public static let ownedItems = \Inventory.totems
	public static let typeID = ItemType.ID.totems
}

public extension Totem.ID {
	/// Default free Flex ("STAT-COM Flex") granted to every account; omitted from Riot's entitlements endpoint.
	static let statComFlex = Self("af52b5a0-4a4c-03b2-c9d7-8187a08a2675")!
	/// Internal unequip sentinel ("None" / UnequipTotem_DataAsset), not a selectable cosmetic.
	static let none = Self("90f0a554-41b3-355b-6846-74a27aa3f7b9")!
}

/// agent, card, title, etc.
public enum ItemType {
	public typealias ID = ObjectID<Self, LowercaseUUID>
}

public extension ItemType.ID {
	static let agents = Self("01bb38e1-da47-4e6a-9b3d-945fe4655707")!
	static let cards = Self("3f296c07-64c3-494c-923b-fe692a4fa1bd")!
	static let titles = Self("de7caa6b-adf7-4588-bbd1-143831e786c6")!
	static let skinLevels = Self("e7c63390-eda7-46e0-bb7a-a6abdacd2433")!
	static let skinChromas = Self("3ad1b2b2-acdb-4524-852f-954a76ddae0a")!
	static let sprays = Self("d5f120f8-ff8c-4aac-92ea-f2b5acbe9475")!
	static let contracts = Self("f85cb6f7-33e5-4dc8-b609-ec7212301948")!
	static let buddies = Self("dd3bf334-87f3-40bd-b043-682a57a8dc3a")!
	static let totems = Self("03a572de-4234-31ed-d344-ababa488f981")!
}

struct APIInventory: Decodable {
	fileprivate var collectionsByType: [ItemCollection]
	
	private enum CodingKeys: String, CodingKey {
		case collectionsByType = "EntitlementsByTypes"
	}
}

private struct ItemCollection: Decodable {
	var id: ItemType.ID
	var items: [Item]
	
	private enum CodingKeys: String, CodingKey {
		case id = "ItemTypeID"
		case items = "Entitlements"
	}
	
	struct Item: Decodable {
		var id: LowercaseUUID
		var instanceID: LowercaseUUID?
		
		private enum CodingKeys: String, CodingKey {
			case id = "ItemID"
			case instanceID = "InstanceID"
		}
	}
}
