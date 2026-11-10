# ProfBalance – design (2026-11-10)

## Avsikt

Oscar spelar WoW: Forever (släppt 2026-11-04) och vill veta, utan att räkna själv, om
professions-skillen hänger med levlingen så att han kan samla noder i zonen han är i och
crafta saker han faktiskt kan använda. Addonet ska ge svaret i en blick, i spelet.

Användaren valde att hoppa över frågerundan; valen nedan är mina och är markerade så.

## Mål

- Per profession: är jag i takt, efter, eller före för min level? Kan/bör jag träna nästa rank?
- I zonen jag står i: vilka noder kan jag samla, vilka ger fortfarande skill, vad saknas?
- När zonen är "grå": vart ska jag åka i stället, nära min level?
- Noll konfiguration, inga externa bibliotek, fungerar direkt vid inloggning.

## Icke-mål

- Ingen nodkarta/minimappins (GatherMate2 finns redan).
- Inga crafting-rutter eller inköpslistor (Forever Profession Master finns).
- Ingen auktionsdata.

## Anti-mål

- Får aldrig kasta Lua-fel som stör spelet: alla API-anrop är pcall-skyddade och secret
  values behandlas som saknade (Forever kör Midnight-API:ets restriktioner).
- Får inte påstå saker om Forever-specifika förändringar som inte är verifierade; sådant är
  markerat `inferred` i datan och i README.

## Begränsningar

- Klient: Forever 1.60.1 (build 70862), Interface 16001, Mainline-liknande API.
- Lua 5.1-dialekt i klienten; testerna körs under fengari (5.3) så koden håller sig till
  den gemensamma delmängden.
- Testning i klienten kan bara göras av Oscar; därför finns `/profbalance debug`.

## Beslut (mina)

- **Modell**: skill ≈ 5 × level som riktmärke för crafting/sekundära, statusband enligt README.
  Enkelt, välkänt, och alltid under det cap som levelkravet för nästa rank tillåter.
  **Ändrat 2026-11-10 på Oscars begäran**: Mining/Herbalism använder i stället ett datadrivet
  mål (viktad 80:e percentil av nodkraven i zoner för leveln, utjämnat ±2 levels), eftersom
  en jämförelse mot noddatan visade att 5 × level var för snällt vid level 10–40 och för
  strängt över 50.
- **Noddata**: återanvänder GatherMate2_Data (Forever-export från Wowhead) som redan ligger
  installerad; aggregeras till `ZoneNodes.lua` med ett Node-skript. Rare-noder och noder
  under 2 % av zonens spawns döljs som förslag.
- **Zonnamn** löses i klienten via `C_Map.GetMapInfo`; tabellen i `Data.lua` är fallback.
- **UI**: egen enkel frame med BackdropTemplate, statusbars, tooltips. Inga Ace-bibliotek.
- **Språk**: engelska i spelet (matchar klienten), svenska i README/dokument.
- **Install**: junction från repot till AddOns-mappen för snabb iteration.

## Lämnat till verifiering i spelet

- Att `GetProfessions`/`GetProfessionInfo` returnerar som på Mainline (bekräftat av andra
  Forever-addons som ForeverFishing och GatherMate2, men inte av mig i klienten).
- uiMapID 2521/2548: namn och levelspann.
- Sekundära professioners rank-trösklar (bok/quest på Forever).
