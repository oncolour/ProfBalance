-- Static data: node skill requirements, rank tiers, zone level ranges.
-- Skill requirements are Classic values; WoW: Forever keeps them (checked against
-- several Forever profession guides, Nov 2026). Adjust here if Blizzard changes them.
local _, ns = ...
ns.Data = {}
local D = ns.Data

-- Skill lines reported by GetProfessionInfo (7th return value)
D.SkillLines = {
	[186] = { key = "mining",      kind = "gather",    name = "Mining" },
	[182] = { key = "herbs",       kind = "gather",    name = "Herbalism" },
	[393] = { key = "skinning",    kind = "gather",    name = "Skinning" },
	[164] = { key = "blacksmith",  kind = "craft",     name = "Blacksmithing" },
	[165] = { key = "leather",     kind = "craft",     name = "Leatherworking" },
	[171] = { key = "alchemy",     kind = "craft",     name = "Alchemy" },
	[197] = { key = "tailoring",   kind = "craft",     name = "Tailoring" },
	[202] = { key = "engineering", kind = "craft",     name = "Engineering" },
	[333] = { key = "enchanting",  kind = "craft",     name = "Enchanting" },
	[185] = { key = "cooking",     kind = "secondary", name = "Cooking" },
	[129] = { key = "firstaid",    kind = "secondary", name = "First Aid" },
	[356] = { key = "fishing",     kind = "secondary", name = "Fishing" },
}

-- Rank tiers. trainAt = skill needed to learn the rank, level = character level needed.
D.Ranks = {
	{ name = "Apprentice", cap = 75 },
	{ name = "Journeyman", cap = 150, trainAt = 50,  level = 10 },
	{ name = "Expert",     cap = 225, trainAt = 125, level = 20 },
	{ name = "Artisan",    cap = 300, trainAt = 200, level = 35 },
}
D.MaxSkill = 300

-- A gathering node stops giving skill-ups roughly this far above its requirement.
D.GrayOffset = 100

-- GatherMate2 node IDs -> requirement. Ooze-covered variants share the base requirement.
D.MiningNodes = {
	[201] = { name = "Copper Vein", req = 1 },
	[202] = { name = "Tin Vein", req = 65 },
	[219] = { name = "Incendicite Mineral Vein", req = 65, rare = true },
	[204] = { name = "Silver Vein", req = 75 },
	[209] = { name = "Ooze Covered Silver Vein", req = 75 },
	[218] = { name = "Lesser Bloodstone Deposit", req = 75, rare = true },
	[203] = { name = "Iron Deposit", req = 125 },
	[220] = { name = "Indurium Mineral Vein", req = 150, rare = true },
	[205] = { name = "Gold Vein", req = 155 },
	[210] = { name = "Ooze Covered Gold Vein", req = 155 },
	[206] = { name = "Mithril Deposit", req = 175 },
	[207] = { name = "Ooze Covered Mithril Deposit", req = 175 },
	[208] = { name = "Truesilver Deposit", req = 230 },
	[211] = { name = "Ooze Covered Truesilver Deposit", req = 230 },
	[217] = { name = "Dark Iron Deposit", req = 230 },
	[214] = { name = "Small Thorium Vein", req = 245 },
	[213] = { name = "Ooze Covered Thorium Vein", req = 245 },
	[215] = { name = "Rich Thorium Vein", req = 275 },
	[212] = { name = "Ooze Covered Rich Thorium Vein", req = 275 },
	[225] = { name = "Large Obsidian Chunk", req = 305, rare = true },
	[226] = { name = "Small Obsidian Chunk", req = 305, rare = true },
}

D.HerbNodes = {
	[401] = { name = "Peacebloom", req = 1 },
	[402] = { name = "Silverleaf", req = 1 },
	[403] = { name = "Earthroot", req = 15 },
	[404] = { name = "Mageroyal", req = 50 },
	[405] = { name = "Briarthorn", req = 70 },
	[407] = { name = "Stranglekelp", req = 85 },
	[408] = { name = "Bruiseweed", req = 100 },
	[409] = { name = "Wild Steelbloom", req = 115 },
	[410] = { name = "Grave Moss", req = 120 },
	[411] = { name = "Kingsblood", req = 125 },
	[412] = { name = "Liferoot", req = 150 },
	[413] = { name = "Fadeleaf", req = 160 },
	[414] = { name = "Goldthorn", req = 170 },
	[415] = { name = "Khadgar's Whisker", req = 185 },
	[416] = { name = "Wintersbite", req = 195 },
	[417] = { name = "Firebloom", req = 205 },
	[418] = { name = "Purple Lotus", req = 210 },
	[420] = { name = "Arthas' Tears", req = 220 },
	[421] = { name = "Sungrass", req = 230 },
	[422] = { name = "Blindweed", req = 235 },
	[423] = { name = "Ghost Mushroom", req = 245 },
	[424] = { name = "Gromsblood", req = 250 },
	[425] = { name = "Golden Sansam", req = 260 },
	[426] = { name = "Dreamfoil", req = 270 },
	[427] = { name = "Mountain Silversage", req = 280 },
	[428] = { name = "Plaguebloom", req = 285 },
	[429] = { name = "Icecap", req = 290 },
	[431] = { name = "Black Lotus", req = 300, rare = true },
}

-- Zone level ranges keyed by uiMapID (Classic map IDs, which Forever reuses).
-- Names are only a fallback; the live client resolves names via C_Map.GetMapInfo.
D.Zones = {
	[1411] = { name = "Durotar", min = 1, max = 10 },
	[1412] = { name = "Mulgore", min = 1, max = 10 },
	[1413] = { name = "The Barrens", min = 10, max = 25 },
	[1416] = { name = "Alterac Mountains", min = 30, max = 40 },
	[1417] = { name = "Arathi Highlands", min = 30, max = 40 },
	[1418] = { name = "Badlands", min = 35, max = 45 },
	[1419] = { name = "Blasted Lands", min = 45, max = 55 },
	[1420] = { name = "Tirisfal Glades", min = 1, max = 10 },
	[1421] = { name = "Silverpine Forest", min = 10, max = 20 },
	[1422] = { name = "Western Plaguelands", min = 51, max = 58 },
	[1423] = { name = "Eastern Plaguelands", min = 53, max = 60 },
	[1424] = { name = "Hillsbrad Foothills", min = 20, max = 30 },
	[1425] = { name = "The Hinterlands", min = 40, max = 50 },
	[1426] = { name = "Dun Morogh", min = 1, max = 10 },
	[1427] = { name = "Searing Gorge", min = 43, max = 50 },
	[1428] = { name = "Burning Steppes", min = 50, max = 58 },
	[1429] = { name = "Elwynn Forest", min = 1, max = 10 },
	[1431] = { name = "Duskwood", min = 18, max = 30 },
	[1432] = { name = "Loch Modan", min = 10, max = 20 },
	[1433] = { name = "Redridge Mountains", min = 15, max = 25 },
	[1434] = { name = "Stranglethorn Vale", min = 30, max = 45 },
	[1435] = { name = "Swamp of Sorrows", min = 35, max = 45 },
	[1436] = { name = "Westfall", min = 10, max = 20 },
	[1437] = { name = "Wetlands", min = 20, max = 30 },
	[1438] = { name = "Teldrassil", min = 1, max = 10 },
	[1439] = { name = "Darkshore", min = 10, max = 20 },
	[1440] = { name = "Ashenvale", min = 18, max = 30 },
	[1441] = { name = "Thousand Needles", min = 25, max = 35 },
	[1442] = { name = "Stonetalon Mountains", min = 15, max = 27 },
	[1443] = { name = "Desolace", min = 30, max = 40 },
	[1444] = { name = "Feralas", min = 40, max = 50 },
	[1445] = { name = "Dustwallow Marsh", min = 35, max = 45 },
	[1446] = { name = "Tanaris", min = 40, max = 50 },
	[1447] = { name = "Azshara", min = 45, max = 55 },
	[1448] = { name = "Felwood", min = 48, max = 55 },
	[1449] = { name = "Un'Goro Crater", min = 48, max = 55 },
	[1450] = { name = "Moonglade", min = 55, max = 60 },
	[1451] = { name = "Silithus", min = 55, max = 60 },
	[1452] = { name = "Winterspring", min = 55, max = 60 },
	[1453] = { name = "Stormwind City", city = true },
	[1454] = { name = "Orgrimmar", city = true },
	[1455] = { name = "Ironforge", city = true },
	[1456] = { name = "Thunder Bluff", city = true },
	[1457] = { name = "Darnassus", city = true },
	[1458] = { name = "Undercity", city = true },
	-- New Forever zones present in the Wowhead export. Identity inferred from node content
	-- (2521: copper + starter herbs = Skyborne starting isle; 2548: iron/gold + goldthorn/kingsblood
	-- = mid-30s/40s zone). The client supplies the real name at runtime; ranges from community guides.
	[2521] = { name = "Zephras Isle", min = 1, max = 12, forever = true, inferred = true },
	[2548] = { name = "Riverglades", min = 35, max = 45, forever = true, inferred = true },
}
