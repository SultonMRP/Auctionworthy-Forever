# Auctionworthy-Forever

WoW tooltip addon. Prices come from **Auctionator API v1** (read-only). Slash: `/auctionworthy` or `/worthy`.

## Layout

- `Auctionworthy.lua` — all logic (single file)
- `Auctionworthy-Forever.toc` — mainline + Camelot (`Interface: 120100, 16001`)
- `Auctionworthy-Forever_Camelot.toc` — Camelot only (`16001`)
- SavedVariables: `AuctionworthySavedOptions`, `AuctionworthyFillIDs`

Do not write `AUCTIONATOR_CONFIG` / `AUCTIONATOR_CHARACTER_CONFIG`. Copy undercut with `Auctionator.Config.Get` / `/worthy refresh`.

## Style

- Match existing Lua: tabs, `local function`, `pcall` around foreign APIs except chat send
- Guard secrets with `Secret()` (`issecretvalue`)
- Prefer item ID price lookups (`getFillAuctionPrice` / `GetAuctionPriceByItemID`) when names are flaky

## Tooltips

`updateTooltip` is the entry. Two helpers, keep them separate:

1. **`updateWaylaidCrateTooltip`** — fill-bundle costs (`Nx Item: price`). Do not change fill options or parsing to “fix” crate selling.
2. **`updateAuctionSellTooltip`** — Auction Costs / Price / Profit / Undercut / decision text, same option keys as other items (`showAuctionCosts`, `showAuctionPrice`, `showProfitOptions`, `showNoAuctionData`, `showFullStack`, `showDecisionText`, `applyUndercut`, `showUndercut`).

Empty Waylaid crates (`name` contains `Waylaid Crate`): run **both**. Fill first, then AH for the crate itself.

- Empty crates often have **vendor 0** and **BoP bindType** but are still AH’d. Skip those gates for crates; still skip if the tooltip is actually soulbound.
- Between the two blocks, one gray line: `-= empty crate auction values =-` (`AddCrateSectionDivider`). No extra blank line (it shows as a gap). Texture hairlines often fail on Camelot.

Normal items: sell helper only. Soulbound / BoP / quest / no vendor: no sell lines.

## Fill cache

`AuctionworthyFillIDs` maps lowercased ingredient names → item ID. Worthy Scan (AH, 5 min CD) indexes Auctionator scan rows into that table. Hardcoded fallbacks live in `FILL_NAME_IDS`.

## Waylaid share click

`/worthy` → **Waylaid share key**: Alt (default), Shift, or Ctrl. Saved as `options.shareModifier`.

Hold that key and click a Waylaid crate in bags or a chat item link. Two lines:

1. Crate item link.
2. `Cheapest: Nx [fill link] (price)` — lowest `qty *` Auctionator unit among fill options.

Channel: Raid, else Party, else Say.

Call `C_ChatInfo.SendChatMessage` directly in the click (fallback `SendChatMessage`). Do not `pcall` the send, and do not defer it with `C_Timer`. Forever blocks that as `ADDON_ACTION_BLOCKED`.
