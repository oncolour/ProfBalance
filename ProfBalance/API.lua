-- Thin, defensive wrapper around the WoW API. Everything is pcall-guarded and
-- secret values (Midnight/Forever) are treated as missing.
local _, ns = ...
ns.API = {}
local API = ns.API
local D = ns.Data

local function isSecret(v)
	return issecretvalue and issecretvalue(v)
end

local function num(v)
	if type(v) == "number" and not isSecret(v) then return v end
	return nil
end

local function str(v)
	if type(v) == "string" and not isSecret(v) then return v end
	return nil
end

local function safe(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d, e, f, g, h
end
API.safe = safe

function API.GetPlayerLevel()
	return num(safe(UnitLevel, "player")) or 1
end

-- Returns a list of { index, name, icon, skill, max, skillLine, key, kind }
function API.GetProfessions()
	local list = {}
	if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return list end
	-- GetProfessions returns up to 6 slots with holes (prof1, prof2, archaeology, fishing, cooking, first aid),
	-- so iterate by position instead of ipairs, which would stop at the first empty slot.
	local indices = { safe(GetProfessions) }
	for i = 1, 8 do
		local index = indices[i]
		if type(index) == "number" then
			local name, icon, skill, max, _, _, skillLine, modifier = safe(GetProfessionInfo, index)
			name, skill, max, skillLine = str(name), num(skill), num(max), num(skillLine)
			if name and skill and max then
				local def = skillLine and D.SkillLines[skillLine]
				list[#list + 1] = {
					index = index, name = name, icon = icon, skill = skill, max = max,
					skillLine = skillLine, modifier = num(modifier) or 0,
					key = def and def.key or ("line" .. tostring(skillLine or index)),
					kind = def and def.kind or "craft",
				}
			end
		end
	end
	return list
end

-- Walk up from the player's current map to the enclosing zone-level map.
function API.GetZone()
	if not C_Map then return nil end
	local mapID = num(safe(C_Map.GetBestMapForUnit, "player"))
	if not mapID then return nil end
	local zoneType = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
	local info = safe(C_Map.GetMapInfo, mapID)
	local guard = 0
	while info and info.mapType and info.mapType > zoneType and info.parentMapID and guard < 6 do
		local parent = safe(C_Map.GetMapInfo, info.parentMapID)
		if not parent then break end
		-- Prefer a parent we have node data for; otherwise keep climbing to zone type.
		mapID, info = info.parentMapID, parent
		if ns.ZoneNodes[mapID] then break end
		guard = guard + 1
	end
	return mapID, (info and str(info.name)) or API.GetZoneName(mapID)
end

function API.GetZoneName(mapID)
	if C_Map then
		local info = safe(C_Map.GetMapInfo, mapID)
		local n = info and str(info.name)
		if n then return n end
	end
	local z = D.Zones[mapID]
	return (z and z.name) or ("Zone " .. tostring(mapID))
end

-- Best effort: count recipes that still give skill-ups in the currently open trade skill.
function API.CountSkillUpRecipes()
	if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo) then return nil end
	local ids = safe(C_TradeSkillUI.GetAllRecipeIDs)
	if type(ids) ~= "table" then return nil end
	local orange, yellow, learned = 0, 0, 0
	for _, id in ipairs(ids) do
		local info = safe(C_TradeSkillUI.GetRecipeInfo, id)
		if type(info) == "table" and info.learned then
			learned = learned + 1
			local rd = num(info.relativeDifficulty)
			if rd == 0 then orange = orange + 1 elseif rd == 1 then yellow = yellow + 1 end
		end
	end
	local line
	if C_TradeSkillUI.GetBaseProfessionInfo then
		local pi = safe(C_TradeSkillUI.GetBaseProfessionInfo)
		if type(pi) == "table" then line = num(pi.professionID) or num(pi.skillLine) end
	end
	return { orange = orange, yellow = yellow, learned = learned, skillLine = line }
end

function API.BuildInfo()
	local v, b, d, i = safe(GetBuildInfo)
	return str(v), str(b) or tostring(b), str(d), num(i)
end
