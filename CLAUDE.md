# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

gMats is a WoW 3.3.5a (WotLK / Chromiecraft / AzerothCore) addon — a guild bounty board where players post material and crafting requests. Guildmates are notified via tooltips and chat alerts when they encounter wanted items.

**Target client**: WoW 3.3.5a (Interface: 30300). All Lua must use the WoW 3.3.5a API — no retail/modern API functions.

## Development

**No build step** — the addon is pure Lua loaded by the WoW client. To test:
1. Copy/symlink `gMats/` into WoW's `Interface/AddOns/` directory
2. Launch WoW client, `/reload` to pick up changes
3. `/gmat` opens the board, `/gmat status` shows addon state, `/gmat help` lists commands

There is no test framework. Verification is manual in-game with two characters in the same guild.

## Architecture

The global namespace is `gMats` (table). All modules hang off it: `gMats.Comm`, `gMats.DataModel`, `gMats.UI.*`, etc.

**Data flow**: `DataModel` (CRUD + SavedVariables) ↔ `Comm` (guild addon messages) ↔ other players. UI reads from `DataModel` and triggers `Comm` broadcasts on mutations.

**Key design decisions**:
- **Persistence**: `gMatsDB` SavedVariable (WoW saves/restores automatically). Board is `gMatsDB.board` keyed by requestID (`"PlayerName-timestamp-seq"`).
- **Sync protocol**: Addon messages over GUILD channel with prefix `"gMats"`. Opcodes: ADD, CRAFT, REMOVE, SYNCREQ, SYNCDATA, SYNCEND. Login triggers a 5-second delayed SYNCREQ; all online members respond with full board state. Merge is idempotent (tombstones win, higher timestamp wins).
- **Reverse item index**: `DataModel.itemIndex[itemID]` → list of requesters. Rebuilt on any board change. Enables O(1) tooltip and loot-alert lookups in `Tooltips.lua`.
- **Throttling**: OnUpdate-based send queue in `Comm.lua` with 0.1s spacing, burst of 10, 1/sec regen. Messages >244 bytes are chunked with `OPCODE#N/M|` headers.
- **Tombstones**: Removed requests get `removed=true, removedAt=time()`, included in syncs for 7 days, then garbage-collected.
- **ItemDB**: Static table of ~500+ common trade goods (`gMatsItemDB[itemID] = "Name"`). Searched with plain `string.find` (debounced, capped at 50 results). When adding new items, use these sources to find correct item IDs and names:
  - **Wowhead (3.3.5)**: `https://www.wowhead.com/wotlk/item=ITEMID` — authoritative for WotLK item data
  - **WoW.tools Database**: `https://wow.tools/dbc/` — raw DBC table browser
  - **classicdb.ch**: `https://classicdb.ch/?item=ITEMID` — good for Classic-era items
  - **AzerothCore wiki / DB**: the server emulator this addon targets; useful for confirming 3.3.5-specific IDs

**Load order** (from .toc): Util → ItemDB → DataModel → Comm → Tooltips → UI/MinimapButton → UI/MainWindow → UI/ItemSearch → UI/BrowseBoard → UI/PostRequestForm → Core. Core wires everything together and registers slash commands.

## Conventions

- Two request types: `"material"` (items needed) and `"craft"` (recipe + matsProvided + matsNeeded)
- Pipe `|` delimits message fields, tilde `~` delimits sub-fields (within item entries), comma `,` separates list items in serialized messages
- UI uses WoW's built-in `FauxScrollFrame` for scrollable lists and `StaticPopupDialogs` for confirmations
- All chat output goes through `SC:Print()` which prepends `[gMats]` in blue
