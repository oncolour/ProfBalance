# ProfBalance – design (2026-11-10)

## Intent

Oscar plays WoW: Forever (released 2026-11-04) and wants to know, without doing the maths,
whether profession skill keeps up with levelling, so he can gather nodes in the zone he is in
and craft things he can actually use. The addon should give that answer at a glance, in game.

The user chose to skip the question round; the choices below are mine and are marked as such.

## Goals

- Per profession: am I in step, behind, or ahead for my level? Can or should I train the next rank?
- In the zone I am standing in: which nodes can I gather, which still give skill, what is missing?
- When the zone is "gray": where should I go instead, close to my level?
- Zero configuration, no external libraries, works right after login.

## Non-goals

- No node map or minimap pins (GatherMate2 already does this).
- No crafting routes or shopping lists (Forever Profession Master does this).
- No auction house data.

## Anti-goals

- Must never throw Lua errors that disturb play: every API call is pcall-guarded and secret
  values are treated as missing (Forever runs the Midnight API restrictions).
- Must not claim Forever-specific changes that are unverified; such data is marked `inferred`
  in the tables and in the README.

## Constraints

- Client: Forever 1.60.1 (build 70862), Interface 16001, Mainline-like API.
- Lua 5.1 dialect in the client; tests run under fengari (5.3), so the code sticks to the
  common subset.
- Testing in the client can only be done by Oscar; hence `/profbalance debug`.

## Decisions (mine)

- **Model**: skill ≈ 5 × level as the target for crafting and secondary professions, verdict
  bands as in the README. Simple, well known, and always below the cap the next rank's level
  requirement allows. **Changed 2026-11-10 at Oscar's request**: Mining/Herbalism use a
  data-driven target instead (weighted 80th percentile of node requirements in zones for the
  level, smoothed ±2 levels), because a comparison against the node data showed 5 × level was
  too lenient at levels 10–40 and too strict above 50.
- **Node data**: reuses GatherMate2_Data (Forever export from Wowhead) already installed on
  the machine; aggregated into `ZoneNodes.lua` by a Node script. Rare nodes and nodes below 2%
  of a zone's spawns are hidden from suggestions.
- **Zone names** are resolved in the client via `C_Map.GetMapInfo`; the table in `Data.lua`
  is a fallback.
- **UI**: own simple frame with BackdropTemplate, status bars, tooltips. No Ace libraries.
  Own minimap button without LibDBIcon; radius follows the minimap's real size.
- **Language**: English in game and in the repository.
- **Install**: junction from the repo into the AddOns folder for fast iteration.
- **Licence**: GPL v2 or later, because the zone table derives from GPL v2+ data.

## Left for verification in game

- That `GetProfessions`/`GetProfessionInfo` return as on Mainline (confirmed by other Forever
  addons such as ForeverFishing and GatherMate2, and by Oscar's debug output on 2026-11-10).
- uiMapID 2521/2548: name and level range.
- Rank thresholds of the secondary professions (book/quest on Forever).
