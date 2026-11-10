# Auctionworthy-Forever

WotLK Auctionworthy ported to WoW Forever. Tooltip profit vs vendor using Auctionator prices.

Install the `Auctionworthy-Forever` folder into `Interface/AddOns`. Auctionator is optional; prices stay empty until it is enabled.

`/worthy` or `/auctionworthy` opens options. Hold Shift for full-stack numbers.

Undercut is a **read-only** copy of Auctionator's account or character saved vars (`auction_sales_preference`, `undercut_percentage`, `undercut_static_value`). Worthy never writes `Auctionator.lua`.

- Static: `Undercut:` plus the gold/silver/copper coin icons
- Percentage (1% of a 10g AH price): `Undercut: 1%,` plus the same coin icons as the rest of the tooltip

`/worthy refresh` re-reads Auctionator settings without a `/reload`. Closing Auctionator's Options window does the same silently.
