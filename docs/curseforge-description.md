# CurseForge project text (copy into the project page)

## Settings to pick when creating the project

- Name: ProfBalance
- Summary (short): Are your professions keeping pace with your level? Pace per profession, what you can gather in this zone, and where to go next.
- Category: Professions (secondary: Map & Minimap)
- Game: World of Warcraft, game version: WoW Forever 1.60.1 (interface 16001)
- License: GNU General Public License version 2.0 (GPLv2)
- Source: https://github.com/oncolour/ProfBalance
- Issues: https://github.com/oncolour/ProfBalance/issues

## Description

**ProfBalance** answers one question while you level in World of Warcraft: Forever:
*are my professions keeping pace with my character, and can I gather or skill up where I am right now?*

### What you get

- **One row per profession** with skill/cap, a 0-300 bar, a marker for where your level expects you to be, and a verdict: In sync, Slightly behind, Behind, Far behind or Ahead. When you can train the next rank (Journeyman / Expert / Artisan), the row tells you so.
- **A zone panel** listing the Mining and Herbalism nodes in the zone you are standing in: green gives skill-ups, gray is too easy, red is locked with the requirement in brackets. Skinning is judged against the zone's level range. A one-line tip says what unlocks next, e.g. "17 more skill unlocks Iron Deposit (125)".
- **Zone suggestions** when your current zone has nothing left to give: the two best zones near your level where nodes still give skill-ups. The row tooltip lists the top three.
- **Level-up summary** in chat for professions that lag behind (can be turned off).
- **Minimap button**: left-click toggles the window, hover shows an overview of all professions, drag to move. The icon takes the colour of your worst profession.

### How "in sync" is decided

- **Mining and Herbalism** use real node data: the target is the skill needed to gather about 80% of the node spawns in zones whose level range contains your level, weighted toward zones that fit your level best. Roughly 75 at level 20, 125 at 25, 145 at 30, 230 at 45, 275 at 60 for Mining; Herbalism runs slightly higher.
- **Everything else** uses the classic rule of thumb of 5 x level (max 300), which matches the game's own weapon skill and skinning formulas.

### Commands

`/profbalance` or `/pbal` toggles the window. Options: `lock`, `unlock`, `reset`, `scale <0.5-2>`, `minimap`, `secondary` (show Cooking / First Aid / Fishing), `rare` (include rare nodes like Black Lotus), `announce`, `summary`, `debug`.

### Notes

- Built for WoW: Forever only (Interface 16001). No libraries, no configuration needed.
- Zone node counts are derived from GatherMate2_Data (GPL v2+), which is built from Wowhead data. Node skill requirements are the game's own values.
- The two newest Forever zones in the data (Zephras Isle, Riverglades) have inferred level ranges; please report mismatches.
- Shen'dralas and Mount Hyjal have no node data yet; the zone panel will say so. They will be added when the data exists.

Source and issues on GitHub: https://github.com/oncolour/ProfBalance
