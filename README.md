# ProfBalance – håller dina professions i takt med din level (WoW: Forever)

Ett litet addon för World of Warcraft: Forever som svarar på frågan
*"ligger mina professions i balans med min level?"* och *"kan jag samla/skilla upp här jag står?"*

## Vad det visar

En liten flyttbar ruta med:

- **En rad per profession**: ikon, skill/cap, en stapel 0–300 med ett vitt streck för
  var du *borde* ligga på din level, och en status: *In sync*, *Slightly behind*, *Behind*,
  *Far behind* eller *Ahead*. När du kan träna nästa rank (Journeyman/Expert/Artisan)
  byts statusen mot en gul uppmaning.
- **Zonsektion**: för Mining/Herbalism listas zonens noder i färg:
  grönt = ger skill-ups här, grått = för lätt (gråa), rött = låst (krav inom parentes).
  Skinning bedöms mot zonens levelspann. Under varje rad en kort tipsrad, t.ex.
  "5 more skill unlocks Silver Vein (75)" eller "everything here is gray – move on".
- **Zonförslag**: när zonen inte ger några skill-ups längre föreslås 1–2 zoner nära din
  level där noderna fortfarande ger skill. Tooltip på raden visar topp 3.
- **Level-up-rapport i chatten** för professions som släpar efter (kan stängas av).
- **Minimap-knapp**: vänsterklick togglar rutan, högerklick skriver sammanfattningen i
  chatten, dra för att flytta den runt minimappen. Ikonen färgas efter den profession som
  släpar mest. Döljs med `/profbalance minimap`.

### Modellen

**Mining och Herbalism** har ett datadrivet riktmärke: den skill som krävs för att kunna samla
~80 % av nodspawnsen i zoner vars levelspann innehåller din level. Zoner nära din level väger
mer, och värdet jämnas ut över ±2 levels. Kurvan blir ungefär 40 vid level 10, 75 vid 20,
125 vid 25, 145 vid 30, 230 vid 45 och 275 vid 60 för Mining; Herbalism ligger något högre
(t.ex. 107 vid 20, 148 vid 30, 290 vid 60).

**Övriga professions** använder tumregeln **skill ≈ 5 × level** (max 300, inget krav före level 5),
som bygger på spelets egna formler (vapenskill och skinning-krav är 5 × level) och på att
craftad utrustning grovt kräver level ≈ skill / 5.

Avvikelsen från riktmärket ger statusen: ≥ −10 in sync, −11…−40 slightly behind, −41…−90 behind,
under det far behind, över +25 ahead. Tooltipen på raden visar vilket riktmärke som används. Rank-trösklar: Journeyman skill 50/level 10, Expert 125/20,
Artisan 200/35. En nod ger skill-ups tills du ligger ~100 över dess krav.

Noddata per zon kommer från GatherMate2:s Forever-export från Wowhead (v2026-10-17),
aggregerad till antal spawns per nodtyp och zon (`ProfBalance/ZoneNodes.lua`). Zonnamn
hämtas live via `C_Map`. Två nya Forever-zoner (uiMapID 2521/2548) är identifierade
som Zephras Isle respektive Riverglades utifrån nodinnehållet – verifiera i spelet.

## Kommandon

```
/profbalance            växla rutan (även /pbal)
/profbalance lock|unlock
/profbalance reset      återställ position och skala
/profbalance scale 1.2
/profbalance minimap    visa/dölj minimap-knappen
/profbalance secondary  visa/dölj Cooking, First Aid, Fishing
/profbalance rare       visa även sällsynta noder (Black Lotus m.fl.)
/profbalance announce   level-up-rapport av/på
/profbalance summary    skriv ut läget i chatten
/profbalance debug      klientversion, zon-id, råa profession-värden
```

Addonet finns också i addon-menyn vid minimappen (addon compartment).

## Installation / utveckling

```
npm install            # engångs, hämtar fengari för testerna
npm test               # kör testsviten headless (ingen WoW-klient behövs)
node tools/install.js  # skapar en junction i _forever_/Interface/AddOns/ProfBalance
node tools/install.js --copy    # kopiera i stället för att länka
node tools/install.js --remove  # avinstallera
npm run build:zones    # bygg om ZoneNodes.lua från GatherMate2_Data när den uppdateras
```

Efter installation: `/reload` i spelet, eller starta om klienten om addonet är nytt.

## Att verifiera i spelet (ej möjligt headless)

- `/profbalance debug` ska visa interface 16001, dina professions med skill-line-id och
  att zonen har noddata.
- Att `GetProfessionInfo` ger rätt cap (75/150/225/300) på Forever.
- Namn och levelspann för Zephras Isle/Riverglades (uiMapID 2521/2548).
- Rank-trösklarna för Cooking/First Aid/Fishing (bok/quest på Forever).

## Licens och källor

ProfBalance är fri programvara under **GNU GPL v2 eller senare** (se `LICENSE`).
Zontabellen `ProfBalance/ZoneNodes.lua` är ett aggregat (antal spawns per nodtyp och zon)
härlett ur **GatherMate2_Data** av kagaro, Xinhuan, Spinx och Marrtin (GPL v2+), som i sin
tur bygger på data från **Wowhead**. Skriptet som gör härledningen ligger i `tools/`.
Skillkrav för noder och ranker är spelets egna värden, kontrollerade mot community-guider.

## Release

```
node tools/package.js          # bygger dist/ProfBalance-<version>.zip för manuell uppladdning
git tag v0.1.0 && git push --tags   # GitHub Actions bygger samma zip och skapar en release
```

Uppladdning till CurseForge görs via deras webb (fil + text från `docs/curseforge-description.md`).

## Struktur

```
ProfBalance/
  ProfBalance.toc   Interface 16001, AllowLoadGameType camelot
  Data.lua          skill-lines, ranker, nodkrav, zoners levelspann
  ZoneNodes.lua     genererad: nodantal per zon
  Core.lua          ren logik (testbar utan WoW)
  API.lua           pcall-skyddad WoW-API-wrapper, hanterar secret values
  UI.lua            rutan och tooltips
  ProfBalance.lua   events, SavedVariables, slash-kommandon
tests/              fengari-baserad testsvit med WoW-mock
tools/              install.js, build_zone_nodes.js
```
