# gMats — Installation & Features Guide

> A World of Warcraft 3.3.5a (WotLK) addon: a guild bounty board for material and crafting requests.

**GitHub**: https://github.com/kkuhlmann/gMats-Addon

**WoW Version**: 3.3.5a (WotLK) · **Interface**: 30300 · **Compatible with**: Chromiecraft / AzerothCore

---

## Installation

1. Download the latest release - https://github.com/kkuhlmann/gMats-Addon/releases/tag/latest.
2. Copy the inner `gMats/` folder (the one containing `gMats.toc`) into your WoW client's addon directory:
   ```
   <WoW Install>/Interface/AddOns/gMats/
   ```
3. Launch WoW (or type `/reload` if already in-game).
4. At the character select screen, click **AddOns** and confirm `gMats` is enabled.

Your folder structure should look like:
```
Interface/
  AddOns/
    gMats/
      gMats.toc
      Core.lua
      DataModel.lua
      Comm.lua
      ...
```

Open the board with `/gmat` or by clicking the minimap button.

---

## Features

### Bounty Board
The main window lists all active guild requests across three tabs: **Materials**, **Crafting**, and **My Posts**. Filter live by item name or requester.

### Material Requests
Post raw materials your character needs. Search the built-in item database (~500+ trade goods), set a quantity, and broadcast to the guild.

### Crafting Requests
Request crafting services by specifying the recipe, materials you'll provide, and materials you still need. Guildmates see exactly what's required to help.

### Item Search
Searchable dialog of common trade goods. Type to filter, click to select.

### Tooltip Integration
Hover any item to see if a guildmate needs it. gMats hooks the game tooltip and shows the requester's name, quantity needed, and request type — color-coded in purple.

### Loot Alerts
When you loot or receive an item a guildmate wants, gMats prints a chat alert (item name, who needs it, how many). Detection uses both loot messages and a bag-diff fallback scan.

### Bag Highlights
Wanted items in your bags get a purple border so you can spot them at a glance.

### Mail Integration
Open the mailbox with a request selected and gMats helps you fill it. A dialog shows what you have vs. what's needed, lets you pick quantities, then auto-composes a mail with the recipient, subject, and item attachments (including stack splitting).

### Minimap Button
Draggable minimap button for quick access. Left-click toggles the board. Tooltip shows the active request count.

### Guild Sync
Board state syncs automatically across all online guild members. On login, gMats requests the full board from online players and merges it. Removed requests use tombstones (kept 7 days) so deletes propagate reliably.

### Auto-Removal
Fulfilled requests are removed from the board automatically.

---

## Commands

All commands use `/gmat` (or `/gmats`).

| Command | Description |
|---------|-------------|
| `/gmat` | Toggle the bounty board window |
| `/gmat open` | Toggle the bounty board window |
| `/gmat status` | Show addon status (active request count, toggle states) |
| `/gmat tooltips` | Toggle tooltip notifications on/off |
| `/gmat alerts` | Toggle loot alert notifications on/off |
| `/gmat highlights` | Toggle bag item highlights on/off |
| `/gmat sync` | Force a board sync from online guild members |
| `/gmat help` | List all available commands |

---

## Settings

All settings persist across sessions in `gMatsDB.settings`.

| Setting | Default | Toggled via | Description |
|---------|---------|-------------|-------------|
| Tooltip notifications | On | `/gmat tooltips` | Show guild needs in item tooltips |
| Loot alerts | On | `/gmat alerts` | Chat notification when looting wanted items |
| Bag highlights | On | `/gmat highlights` | Purple border on wanted items in bags |
| Minimap position | 220° | Drag the button | Position of the minimap icon |

---

## Links

- **Repository**: https://github.com/kkuhlmann/gMats-Addon
- **Issues / Bug reports**: https://github.com/kkuhlmann/gMats-Addon/issues
