-- Minimal stand-ins for the WoW API so the addon files load under plain Lua.
MOCK = {
	level = 20,
	mapID = 1413,
	-- GetProfessionInfo return values: name, icon, skill, max, numAbilities, spellOffset, skillLine, modifier
	profs = {
		[1] = { "Mining", 134708, 70, 150, 1, 0, 186, 0 },
		[2] = { "Blacksmithing", 136241, 40, 75, 1, 0, 164, 0 },
		[5] = { "Cooking", 133971, 30, 75, 1, 0, 185, 0 },
	},
	printed = {},
}

local function stub(kind)
	local o = { __kind = kind, __scripts = {}, __shown = true }
	setmetatable(o, { __index = function(t, k)
		if k == "GetHeight" or k == "GetWidth" or k == "GetStringWidth" or k == "GetStringHeight"
			or k == "GetScale" or k == "GetEffectiveScale" or k == "GetTop" or k == "GetLeft" or k == "GetBottom" or k == "GetRight" then
			return function() return 20 end
		end
		if k == "GetText" or k == "GetName" then return function() return "" end end
		if k == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 12, "" end end
		if k == "IsShown" or k == "IsVisible" then return function(self) return self.__shown end end
		if k == "Show" then return function(self) self.__shown = true end end
		if k == "Hide" then return function(self) self.__shown = false end end
		if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 12, -34 end end
		if k == "CreateTexture" or k == "CreateFontString" then return function() return stub(k) end end
		if k == "SetScript" then return function(self, ev, fn) self.__scripts[ev] = fn end end
		if k == "GetScript" then return function(self, ev) return self.__scripts[ev] end end
		if k == "RegisterEvent" then return function(self, ev) if ev == "UNKNOWN_EVENT_FOR_TEST" then error("unknown event") end end end
		return function() return nil end
	end })
	return o
end
MOCK.stub = stub

function CreateFrame(ftype, name, parent, template)
	local f = stub(ftype)
	if name then _G[name] = f end
	return f
end
UIParent = stub("UIParent")
GameTooltip = stub("GameTooltip")
Minimap = stub("Minimap")
Minimap.GetCenter = function() return 100, 100 end
Minimap.GetEffectiveScale = function() return 1 end
MOCK.cursor = { 150, 150 }
function GetCursorPosition() return MOCK.cursor[1], MOCK.cursor[2] end
GameFontNormal, GameFontNormalSmall, GameFontHighlightSmall = {}, {}, {}
SlashCmdList = {}
C_Timer = { After = function(_, fn) fn() end }
Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } }
function InCombatLockdown() return false end
function GetBuildInfo() return "1.60.1", "70862", "Nov 7 2026", 16001 end
function UnitLevel() return MOCK.level end
function GetProfessions()
	local p = MOCK.profs
	return p[1] and 1 or nil, p[2] and 2 or nil, nil, p[4] and 4 or nil, p[5] and 5 or nil, p[6] and 6 or nil
end
function GetProfessionInfo(i)
	local p = MOCK.profs[i]
	if not p then return nil end
	return p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]
end
C_Map = {
	GetBestMapForUnit = function() return MOCK.mapID end,
	GetMapInfo = function(id)
		if MOCK.subzone and id == MOCK.subzone.id then
			return { mapID = id, name = MOCK.subzone.name, mapType = 5, parentMapID = MOCK.subzone.parent }
		end
		local z = NS and NS.Data and NS.Data.Zones[id]
		return { mapID = id, name = z and z.name or ("Map " .. id), mapType = 3, parentMapID = 1414 }
	end,
}
local realPrint = print
__print = realPrint
function print(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	MOCK.printed[#MOCK.printed + 1] = table.concat(t, " ")
	if MOCK.echo then realPrint(...) end
end
