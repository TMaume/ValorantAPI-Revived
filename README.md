# ValorantAPI Revived

A Swift package for accessing Valorant's client APIs, maintained in tandem with [Recon Bolt Revived](https://github.com/TMaume/Recon-Bolt-Revived).

## Background & Revival

Originally built alongside Recon Bolt, this library became unmaintained after Riot Games issued legal takedown threats in 2024, eventually breaking as Riot updated its authentication flow, headers, and endpoints.

This revived fork updates the package to work again with modern Valorant endpoints:

- **Riot WebView Auth & Cookie Refresh:** Initialize `APISession` from Riot's OAuth redirect URL and cookies (`account` + `openid` scopes) and refresh expired tokens from stored cookies.
- **API & Header Fixes:** Clear the default `URLSession` `User-Agent` to avoid Cloudflare `403` blocks, dynamically resolve the latest `riotClientVersion` from `valorant-api.com`, handle missing `HighestRewardedLevel` keys in contracts, and migrate `playerloadout` to `v3` (`ActiveExpressions`).
- **New Endpoints & Weapons:** Added `Bandit`, `Warden`, and `Outlaw` to `Weapon.ID`, plus `quitPregameMatch(_:)` for pregame dodging.
- **SwiftPM / `xtool` Compatibility:** Pinned `Protoquest` and `ErgonomicCodable` revisions for reliable resolution.

## Documentation

There is in-code documentation across requests and models, and most methods are self-explanatory once you get going. Create an `APISession` from the Riot WebView login flow (`APISession.riotLoginURL`), initialize a `ValorantClient` with it, and call its async methods to run requests.
