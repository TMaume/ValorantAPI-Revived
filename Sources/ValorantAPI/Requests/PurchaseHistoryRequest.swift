import Foundation

extension ValorantClient {
	/// The Riot SSO cookies obtained at sign-in (e.g. `ssid`, `tdid`, `clid`), used to seed web views
	/// such as the Riot Support purchase-history flow.
	///
	/// - note: The legacy `player-support-zendesk` OAuth flow no longer works: Riot rejects it with `unauthorized_client`
	/// and `login.playersupport.riotgames.com` never answers. Riot Support now authenticates through XSSO
	/// (`xsso.riotgames.com`) and the Skye API, which requires a browser session.
	public func getSessionCookies() async -> [HTTPCookie] {
		await getSession().cookies.map(\.httpCookie)
	}
}

extension PurchaseHistory {
	/// Decodes the JSON returned by Riot Support's `sspd/valorant_purchase_history` endpoint.
	public static func decode(from data: Data) throws -> PurchaseHistory {
		try JSONDecoder().decode(PurchaseHistory.self, from: data)
	}
}
