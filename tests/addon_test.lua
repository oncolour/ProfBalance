-- Smoke tests for the API wrapper, controller and UI under the mock.
local ns = NS
local API, Core = ns.API, ns.Core

T.print("Addon")

local ev = ProfBalanceEventFrame
local function fire(event, ...) ev.__scripts.OnEvent(ev, event, ...) end

T.test("ADDON_LOADED creates db, frame and slash commands", function()
	ProfBalanceDB = nil
	fire("ADDON_LOADED", "SomethingElse")
	T.eq(ns.db, nil)
	fire("ADDON_LOADED", "ProfBalance")
	T.truthy(ns.db)
	T.eq(ns.db.shown, true)
	T.truthy(ProfBalanceFrame)
	T.eq(type(SlashCmdList.PROFBALANCE), "function")
	T.eq(SLASH_PROFBALANCE1, "/profbalance")
end)

T.test("API.GetProfessions maps skill lines", function()
	local p = API.GetProfessions()
	T.eq(#p, 3)
	local byKey = {}
	for _, x in ipairs(p) do byKey[x.key] = x end
	T.eq(byKey.mining.kind, "gather"); T.eq(byKey.mining.skill, 70); T.eq(byKey.mining.max, 150)
	T.eq(byKey.blacksmith.kind, "craft")
	T.eq(byKey.cooking.kind, "secondary")
end)

T.test("API.GetZone returns zone id and name, climbing out of sub-maps", function()
	local id, name = API.GetZone()
	T.eq(id, 1413); T.eq(name, "The Barrens")
	MOCK.subzone = { id = 5555, name = "Wailing Caverns", parent = 1413 }
	MOCK.mapID = 5555
	id, name = API.GetZone()
	T.eq(id, 1413); T.eq(name, "The Barrens")
	MOCK.subzone = nil; MOCK.mapID = 1413
end)

T.test("BuildModel assembles everything", function()
	local m = ns.BuildModel()
	T.eq(m.level, 20)
	T.eq(#m.profs, 3)
	T.eq(m.profs[1].key, "mining", "gathering first")
	T.eq(m.skills.mining, 70)
	T.eq(m.zone.mapID, 1413)
	T.truthy(m.zone.report.kinds.mining)
	T.truthy(#m.suggestions.mining > 0)
	T.eq(m.suggestions.herbs, nil)
end)

T.test("secondary toggle hides cooking", function()
	ns.db.showSecondary = false
	local m = ns.BuildModel()
	T.eq(#m.profs, 2)
	ns.db.showSecondary = true
end)

T.test("PLAYER_ENTERING_WORLD refreshes UI without error", function()
	MOCK.printed = {}
	fire("PLAYER_ENTERING_WORLD")
	for _, line in ipairs(MOCK.printed) do T.falsy(line:find("refresh error", 1, true), line) end
	T.truthy(ns.lastModel)
end)

T.test("UI.Refresh handles no professions and unknown zone", function()
	local saved = MOCK.profs
	MOCK.profs = {}
	MOCK.mapID = 424242
	MOCK.printed = {}
	fire("SKILL_LINES_CHANGED")
	for _, line in ipairs(MOCK.printed) do T.falsy(line:find("refresh error", 1, true), line) end
	T.eq(#ns.lastModel.profs, 0)
	MOCK.profs = saved
	MOCK.mapID = 1413
end)

T.test("level-up announces professions that lag", function()
	MOCK.printed = {}
	fire("PLAYER_LEVEL_UP", 30)
	local joined = table.concat(MOCK.printed, "\n")
	T.contains(joined, "Mining 70/150")
	T.contains(joined, "Blacksmithing 40/75")
end)

T.test("slash commands run", function()
	local s = SlashCmdList.PROFBALANCE
	MOCK.printed = {}
	s("lock"); T.eq(ns.db.locked, true)
	s("unlock"); T.eq(ns.db.locked, false)
	s("scale 1.5"); T.eq(ns.db.scale, 1.5)
	s("scale 9"); T.eq(ns.db.scale, 1.5)
	s("hide"); T.eq(ns.db.shown, false)
	s("show"); T.eq(ns.db.shown, true)
	s(""); T.eq(ns.db.shown, false)
	s("toggle"); T.eq(ns.db.shown, true)
	s("rare"); T.eq(ns.db.includeRare, true); s("rare")
	s("summary")
	s("debug")
	s("help")
	local joined = table.concat(MOCK.printed, "\n")
	T.contains(joined, "interface 16001")
	T.contains(joined, "commands:")
	T.falsy(joined:find("refresh error", 1, true))
end)

T.test("tooltip renders for a row", function()
	local f = ProfBalanceFrame
	-- find a row by walking the created rows via UI internals: call ShowTooltip with a fake row
	local row = { assessment = ns.lastModel.profs[1] }
	ns.UI.ShowTooltip(row)
end)

T.test("compartment click toggles", function()
	local before = ns.db.shown
	ProfBalance_OnCompartmentClick()
	T.eq(ns.db.shown, not before)
	ProfBalance_OnCompartmentClick()
end)

T.print("Minimap button")

T.test("button is created on load and toggles the window", function()
	local b = ProfBalanceMinimapButton
	T.truthy(b, "button should exist")
	T.eq(ns.Minimap.GetButton(), b)
	T.truthy(ns.db.minimap and ns.db.minimap.angle == 220)
	local before = ns.db.shown
	b.__scripts.OnClick(b, "LeftButton")
	T.eq(ns.db.shown, not before)
	b.__scripts.OnClick(b, "LeftButton")
	T.eq(ns.db.shown, before)
end)

T.test("right-click prints the summary", function()
	MOCK.printed = {}
	ProfBalanceMinimapButton.__scripts.OnClick(ProfBalanceMinimapButton, "RightButton")
	T.contains(table.concat(MOCK.printed, "\n"), "Mining 70/150")
end)

T.test("dragging updates the stored angle", function()
	local b = ProfBalanceMinimapButton
	b.__scripts.OnDragStart(b)
	T.eq(type(b.__scripts.OnUpdate), "function")
	MOCK.cursor = { 100, 200 } -- straight up from the minimap centre
	b.__scripts.OnUpdate(b)
	T.near(ns.db.minimap.angle, 90, 0.01)
	MOCK.cursor = { 0, 100 } -- straight left
	b.__scripts.OnUpdate(b)
	T.near(ns.db.minimap.angle, 180, 0.01)
	b.__scripts.OnDragStop(b)
	T.eq(b.__scripts.OnUpdate, nil)
end)

T.test("icon tint follows the worst non-secondary status", function()
	fire("SKILL_LINES_CHANGED")
	-- level 20, mining 70 (slightly) and blacksmithing 40 (behind) -> worst is behind
	T.eq(ProfBalanceMinimapButton.worst, "behind")
end)

T.test("slash minimap hides and shows the button", function()
	local b = ProfBalanceMinimapButton
	SlashCmdList.PROFBALANCE("minimap")
	T.eq(ns.db.minimap.hide, true)
	T.eq(b.__shown, false)
	SlashCmdList.PROFBALANCE("minimap")
	T.eq(ns.db.minimap.hide, false)
	T.eq(b.__shown, true)
end)

T.test("tooltip renders without error", function()
	ns.Minimap.ShowTooltip(ProfBalanceMinimapButton)
	ns.lastModel = nil
	ns.Minimap.ShowTooltip(ProfBalanceMinimapButton)
	fire("SKILL_LINES_CHANGED")
end)

T.test("button radius follows the minimap size and shape", function()
	local b = ProfBalanceMinimapButton
	local captured
	b.SetPoint = function(_, _, _, _, x, y) captured = { x, y } end
	Minimap.GetWidth = function() return 200 end
	Minimap.GetHeight = function() return 200 end
	ns.db.minimap.angle = 0
	ns.Minimap.Refresh()
	T.near(captured[1], 105, 0.01, "round: radius = width/2 + 5")
	T.near(captured[2], 0, 0.01)
	GetMinimapShape = function() return "SQUARE" end
	ns.db.minimap.angle = 10
	ns.Minimap.Refresh()
	T.near(captured[1], 105, 0.01, "square: x clamped to the edge")
	T.near(captured[2], math.sin(math.rad(10)) * (math.sqrt(2 * 105 * 105) - 10), 0.01, "square: y follows the diagonal radius")
	GetMinimapShape = nil
	b.SetPoint = nil
end)
