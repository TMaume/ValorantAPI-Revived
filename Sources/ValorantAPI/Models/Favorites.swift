import Foundation

public struct Favorites: Equatable, Codable {
	public var subject: User.ID
	public var favoritedContent: [String: FavoriteEntry] {
		didSet {
			cachedItemIDs = Self.buildItemIDs(from: favoritedContent)
		}
	}
	private var cachedItemIDs: Set<LowercaseUUID>
	
	public var itemIDs: Set<LowercaseUUID> {
		cachedItemIDs
	}
	
	public func contains(_ itemID: LowercaseUUID) -> Bool {
		cachedItemIDs.contains(itemID) || favoritedContent[itemID.description] != nil
	}
	
	public init(subject: User.ID, favoritedContent: [String: FavoriteEntry] = [:]) {
		self.subject = subject
		self.favoritedContent = favoritedContent
		self.cachedItemIDs = Self.buildItemIDs(from: favoritedContent)
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.subject = try container.decode(User.ID.self, forKey: .subject)
		let content = try container.decode([String: FavoriteEntry].self, forKey: .favoritedContent)
		self.favoritedContent = content
		self.cachedItemIDs = Self.buildItemIDs(from: content)
	}
	
	public static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.subject == rhs.subject && lhs.favoritedContent == rhs.favoritedContent
	}
	
	private static func buildItemIDs(from content: [String: FavoriteEntry]) -> Set<LowercaseUUID> {
		Set(content.values.map(\.itemID))
	}
	
	private enum CodingKeys: String, CodingKey {
		case subject = "Subject"
		case favoritedContent = "FavoritedContent"
	}
	
	public struct FavoriteEntry: Equatable, Codable {
		public var id: LowercaseUUID
		public var itemID: LowercaseUUID
		
		public init(id: LowercaseUUID, itemID: LowercaseUUID) {
			self.id = id
			self.itemID = itemID
		}
		
		private enum CodingKeys: String, CodingKey {
			case id = "FavoriteID"
			case itemID = "ItemID"
		}
	}
}
