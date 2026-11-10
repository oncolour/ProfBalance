-- Controller: events, saved variables, slash commands, model building.
local addonName, ns = ...
local Core, API, UI, D = ns.Core, ns.API, ns.UI, ns.Data

local defaults = {
	shown = true,
	locked = false,
	scale = 1,
	showSecondary = true,
	announce = true,
	includeRare = false,
	pos = nil,
}

local function print_(msg)
	print("|cff7fd5ffProfBalance|r: " .. tostring(msg))
end

local function copyDefaults(db)
	for k, v in pairs(defaults) do
		if db[k] == nil then db[k] = v end
	end
	return db
end

function ns.SavePosition(f)
	local point, _, relPoint, x, y = f:GetPoint()
	if point and ns.db then ns.db.pos = { point = point, relPoint = relPoint, x = x, y = y } end
end

local function applyPosition(f)
	if ns.db and ns.db.pos then
		f:ClearAllPoints()
		f:SetPoint(ns.db.pos.point, UIParent, ns.db.pos.relPoint or ns.db.pos.point, ns.db.pos.x or 0, ns.db.pos.y or 0)
	end
	f:SetScale(ns.db and ns.db.scale or 1)
end

function ns.SetShown(flag)
	if not ns.db then return end
	ns.db.shown = flag and true or false
	local f = UI.GetFrame()
	if f then
		if flag then f:Show(); ns.Refresh() else f:Hide() end
	end
end

-- Build everything the UI needs from the live API.
function ns.BuildModel()
	local level = API.GetPlayerLevel()
	local profs = API.GetProfessions()
	local model = { level = level, profs = {}, skills = {}, suggestions = {}, recipes = ns.recipeCache or {} }
	local order = { gather = 1, craft = 2, secondary = 3 }
	table.sort(profs, function(a, b)
		if order[a.kind] ~= order[b.kind] then return order[a.kind] < order[b.kind] end
		return a.name < b.name
	end)
	for _, p in ipairs(profs) do
		if p.kind ~= "secondary" or ns.db.showSecondary then
			model.profs[#model.profs + 1] = Core.Assess(p, level)
		end
		if p.kind == "gather" then model.skills[p.key] = p.skill end
	end
	local mapID, zoneName = API.GetZone()
	if mapID then
		model.zone = { mapID = mapID, name = zoneName, report = Core.ZoneReport(mapID, model.skills, { includeRare = ns.db.includeRare }) }
	end
	for _, kind in ipairs({ "mining", "herbs" }) do
		if model.skills[kind] then
			model.suggestions[kind] = Core.SuggestZones(kind, model.skills[kind], level, { includeRare = ns.db.includeRare, limit = 3 })
		end
	end
	ns.lastModel = model
	return model
end

local pending = false
function ns.Refresh()
	if not ns.db then return end
	if pending then return end
	pending = true
	local function doIt()
		pending = false
		local ok, err = pcall(function()
			local model = ns.BuildModel()
			if ns.db.shown then UI.Refresh(model) end
			if ns.Minimap then ns.Minimap.Refresh() end
		end)
		if not ok then print_("refresh error: " .. tostring(err)) end
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.3, doIt) else doIt() end
end

local function announceLevelUp(newLevel)
	if not ns.db.announce then return end
	local profs = API.GetProfessions()
	local said = false
	for _, p in ipairs(profs) do
		if p.kind ~= "secondary" then
			local a = Core.Assess(p, newLevel)
			if a.status == "behind" or a.status == "far" or a.status == "slightly" or a.rankKey == "train" then
				print_(Core.SummaryLine(a))
				said = true
			end
		end
	end
	if not said and #profs > 0 then print_(string.format("Level %d: professions are keeping pace.", newLevel)) end
end

local function cacheRecipes()
	local r = API.CountSkillUpRecipes()
	if not r then return end
	-- Match the open trade skill to one of our professions by skill line, else by name.
	local key
	if r.skillLine and D.SkillLines[r.skillLine] then key = D.SkillLines[r.skillLine].key end
	if not key and C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
		local info = API.safe(C_TradeSkillUI.GetBaseProfessionInfo)
		local name = type(info) == "table" and info.professionName
		if type(name) == "string" then
			for _, p in ipairs(API.GetProfessions()) do
				if p.name == name then key = p.key end
			end
		end
	end
	if key then
		ns.recipeCache = ns.recipeCache or {}
		ns.recipeCache[key] = r
	end
end

local function debugDump()
	local v, b, d, i = API.BuildInfo()
	print_(string.format("Client %s build %s (%s), interface %s", tostring(v), tostring(b), tostring(d), tostring(i)))
	print_("Level " .. API.GetPlayerLevel())
	local mapID, name = API.GetZone()
	print_(string.format("Zone: %s (uiMapID %s) node data: %s", tostring(name), tostring(mapID), ns.ZoneNodes[mapID or 0] and "yes" or "no"))
	local raw = { API.safe(GetProfessions) }
	print_("GetProfessions -> " .. table.concat((function() local t = {} for k, v in ipairs(raw) do t[k] = tostring(v) end return t end)(), ", "))
	for _, p in ipairs(API.GetProfessions()) do
		print_(string.format("  %s skill %d/%d line %s kind %s", p.name, p.skill, p.max, tostring(p.skillLine), p.kind))
	end
	print_("Secret-value API present: " .. tostring(issecretvalue ~= nil))
end

function ns.PrintSummary()
	local level = API.GetPlayerLevel()
	local profs = API.GetProfessions()
	if #profs == 0 then print_("no professions found") return end
	for _, p in ipairs(profs) do print_(Core.SummaryLine(Core.Assess(p, level))) end
end

local function help()
	print_("commands: /profbalance show | hide | toggle | lock | unlock | reset | scale <0.5-2> | minimap | secondary | rare | announce | summary | debug")
end

local function slash(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, arg = msg:match("^(%S*)%s*(.-)$")
	if cmd == "" or cmd == "toggle" then ns.SetShown(not ns.db.shown)
	elseif cmd == "show" then ns.SetShown(true)
	elseif cmd == "hide" then ns.SetShown(false)
	elseif cmd == "lock" then ns.db.locked = true; print_("frame locked")
	elseif cmd == "unlock" then ns.db.locked = false; print_("frame unlocked")
	elseif cmd == "reset" then
		ns.db.pos = nil; ns.db.scale = 1
		local f = UI.GetFrame()
		if f then f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 250, 0); f:SetScale(1) end
		ns.SetShown(true)
	elseif cmd == "scale" then
		local s = tonumber(arg)
		if s and s >= 0.5 and s <= 2 then ns.db.scale = s; local f = UI.GetFrame(); if f then f:SetScale(s) end else print_("scale must be 0.5-2") end
	elseif cmd == "secondary" then ns.db.showSecondary = not ns.db.showSecondary; print_("secondary professions " .. (ns.db.showSecondary and "shown" or "hidden")); ns.Refresh()
	elseif cmd == "rare" then ns.db.includeRare = not ns.db.includeRare; print_("rare nodes " .. (ns.db.includeRare and "shown" or "hidden")); ns.Refresh()
	elseif cmd == "announce" then ns.db.announce = not ns.db.announce; print_("level-up summary " .. (ns.db.announce and "on" or "off"))
	elseif cmd == "summary" then ns.PrintSummary()
	elseif cmd == "minimap" then
		local hidden = not (ns.db.minimap and ns.db.minimap.hide)
		ns.Minimap.SetHidden(hidden)
		print_("minimap button " .. (hidden and "hidden" or "shown"))
	elseif cmd == "debug" then debugDump()
	else help() end
end

function ProfBalance_OnCompartmentClick()
	ns.SetShown(not (ns.db and ns.db.shown))
end

local ev = CreateFrame("Frame", "ProfBalanceEventFrame")
local handlers = {}

function handlers.ADDON_LOADED(name)
	if name ~= addonName then return end
	ProfBalanceDB = copyDefaults(ProfBalanceDB or {})
	ns.db = ProfBalanceDB
	local f = UI.Create()
	applyPosition(f)
	if ns.db.shown then f:Show() else f:Hide() end
	pcall(ns.Minimap.Create)
	SLASH_PROFBALANCE1 = "/profbalance"
	SLASH_PROFBALANCE2 = "/pbal"
	SlashCmdList["PROFBALANCE"] = slash
end

function handlers.PLAYER_ENTERING_WORLD() ns.Refresh() end
function handlers.SKILL_LINES_CHANGED() ns.Refresh() end
function handlers.CHAT_MSG_SKILL() ns.Refresh() end
function handlers.ZONE_CHANGED_NEW_AREA() ns.Refresh() end
function handlers.ZONE_CHANGED() ns.Refresh() end
function handlers.ZONE_CHANGED_INDOORS() ns.Refresh() end
function handlers.PLAYER_LEVEL_UP(newLevel)
	ns.Refresh()
	if type(newLevel) == "number" then
		if C_Timer and C_Timer.After then C_Timer.After(1, function() announceLevelUp(newLevel) end) else announceLevelUp(newLevel) end
	end
end
function handlers.TRADE_SKILL_LIST_UPDATE() cacheRecipes(); ns.Refresh() end
function handlers.TRADE_SKILL_SHOW() cacheRecipes() end

ev:SetScript("OnEvent", function(_, event, ...)
	local h = handlers[event]
	if h then h(...) end
end)
for event in pairs(handlers) do
	-- Registering an event the client does not know throws; never let that abort loading.
	pcall(ev.RegisterEvent, ev, event)
end
