import Foundation

public struct Favorites: Equatable, Codable {
	public var subject: User.ID
	public var favoritedContent: [String: FavoriteEntry]
	
	public var itemIDs: Set<LowercaseUUID> {
		Set(favoritedContent.values.map(\.itemID))
	}
	
	public func contains(_ itemID: LowercaseUUID) -> Bool {
		favoritedContent[itemID.description] != nil || itemIDs.contains(itemID)
	}
	
	public init(subject: User.ID, favoritedContent: [String: FavoriteEntry] = [:]) {
		self.subject = subject
		self.favoritedContent = favoritedContent
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
