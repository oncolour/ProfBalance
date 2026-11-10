local ns = NS
local Core, D = ns.Core, ns.Data

T.print("Core")

T.test("TargetSkill follows 5 x level, capped at 300, nothing before level 5", function()
	T.eq(Core.TargetSkill(1), 0)
	T.eq(Core.TargetSkill(4), 0)
	T.eq(Core.TargetSkill(5), 25)
	T.eq(Core.TargetSkill(20), 100)
	T.eq(Core.TargetSkill(60), 300)
	T.eq(Core.TargetSkill(70), 300)
end)

T.test("StatusFor bands", function()
	T.eq(Core.StatusFor(40), "ahead")
	T.eq(Core.StatusFor(0), "ok")
	T.eq(Core.StatusFor(-10), "ok")
	T.eq(Core.StatusFor(-11), "slightly")
	T.eq(Core.StatusFor(-40), "slightly")
	T.eq(Core.StatusFor(-41), "behind")
	T.eq(Core.StatusFor(-90), "behind")
	T.eq(Core.StatusFor(-91), "far")
end)

T.test("Assess at level 20", function()
	local function a(skill, max) return Core.Assess({ name = "Blacksmithing", kind = "craft", key = "blacksmith", skill = skill, max = max or 150 }, 20) end
	T.eq(a(100).status, "ok")
	T.eq(a(100).diff, 0)
	T.eq(a(70).status, "slightly")
	T.eq(a(40).status, "behind")
	T.eq(a(5).status, "far")
	T.eq(a(140).status, "ahead")
	T.near(a(150).progress, 0.5)
	T.near(a(150).targetProgress, 100 / 300)
end)

T.test("RankAdvice", function()
	local k, t = Core.RankAdvice(60, 75, 12)
	T.eq(k, "train"); T.contains(t, "Journeyman")
	k, t = Core.RankAdvice(75, 75, 8)
	T.eq(k, "level"); T.contains(t, "level 10")
	k = Core.RankAdvice(75, 300, 60)
	T.eq(k, nil)
	k, t = Core.RankAdvice(210, 225, 30)
	T.eq(k, "level"); T.contains(t, "Artisan"); T.contains(t, "35")
	k = Core.RankAdvice(210, 225, 40)
	T.eq(k, "train")
	k = Core.RankAdvice(30, 75, 40)
	T.eq(k, nil, "nothing to say far below the training threshold")
end)

T.test("Assess marks capped + trainable as urgent", function()
	local a = Core.Assess({ name = "Mining", kind = "gather", key = "mining", skill = 75, max = 75 }, 15)
	T.truthy(a.urgent)
	T.eq(a.rankKey, "train")
end)

T.test("SummaryLine", function()
	local a = Core.Assess({ name = "Blacksmithing", kind = "craft", key = "blacksmith", skill = 87, max = 150 }, 20)
	local s = Core.SummaryLine(a)
	T.contains(s, "Blacksmithing 87/150")
	T.contains(s, "13 below the 100 expected")
end)

T.test("SkinningReq classic formula", function()
	T.eq(Core.SkinningReq(5), 1)
	T.eq(Core.SkinningReq(10), 1)
	T.eq(Core.SkinningReq(15), 50)
	T.eq(Core.SkinningReq(20), 100)
	T.eq(Core.SkinningReq(30), 150)
	T.eq(Core.SkinningReq(60), 300)
end)

T.test("ZoneNodes: Barrens mining at skill 70", function()
	local r = Core.ZoneNodes(1413, "mining", 70)
	T.truthy(r)
	local byName = {}
	for _, n in ipairs(r.nodes) do byName[n.name] = n end
	T.truthy(byName["Copper Vein"]); T.truthy(byName["Copper Vein"].canGather); T.truthy(byName["Copper Vein"].skillUp)
	T.truthy(byName["Tin Vein"]); T.truthy(byName["Tin Vein"].canGather); T.truthy(byName["Tin Vein"].skillUp)
	T.truthy(byName["Silver Vein"]); T.falsy(byName["Silver Vein"].canGather); T.eq(byName["Silver Vein"].need, 5)
	T.falsy(r.canAll)
	T.truthy(r.anySkillUp)
	T.eq(r.nextUnlock.name, "Silver Vein")
	-- sorted by requirement
	T.eq(r.nodes[1].name, "Copper Vein")
	T.eq(r.nodes[#r.nodes].name, "Silver Vein")
end)

T.test("ZoneNodes: starter zone turns gray at high skill", function()
	local r = Core.ZoneNodes(1411, "mining", 150)
	T.truthy(r.canAll)
	T.falsy(r.anySkillUp)
end)

T.test("ZoneNodes: no skill gives plain listing", function()
	local r = Core.ZoneNodes(1413, "herbs", nil)
	T.truthy(r and #r.nodes > 0)
	T.eq(r.nodes[1].canGather, nil)
end)

T.test("ZoneNodes: unknown zone or kind returns nil", function()
	T.eq(Core.ZoneNodes(999999, "mining", 10), nil)
	T.eq(Core.ZoneNodes(1413, "fishing", 10), nil)
end)

T.test("ZoneNodes: rare nodes hidden unless includeRare", function()
	local found
	for mapID, z in pairs(ns.ZoneNodes) do
		if z.herbs and z.herbs[431] then found = mapID break end
	end
	T.truthy(found, "expected Black Lotus somewhere in the data")
	local function has(r) for _, n in ipairs(r.nodes) do if n.id == 431 then return true end end return false end
	T.falsy(has(Core.ZoneNodes(found, "herbs", 300)))
	T.truthy(has(Core.ZoneNodes(found, "herbs", 300, { includeRare = true })))
end)

T.test("ZoneReport includes skinning from zone level range", function()
	local r = Core.ZoneReport(1413, { mining = 70, skinning = 60 })
	T.truthy(r.kinds.mining)
	T.eq(r.kinds.herbs, nil)
	T.truthy(r.kinds.skinning)
	T.eq(r.kinds.skinning.reqMax, Core.SkinningReq(25))
	T.falsy(r.kinds.skinning.canAll)
	T.truthy(r.kinds.skinning.canSome)
	T.eq(r.kinds.skinning.need, 125 - 60)
end)

T.test("SuggestZones prefers zones near the level with skill-ups", function()
	local s = Core.SuggestZones("mining", 70, 20, { limit = 3 })
	T.truthy(#s > 0)
	for _, z in ipairs(s) do
		T.truthy(z.skillUpShare > 0)
		T.truthy(z.zone and not z.zone.city)
	end
	T.truthy(s[1].dist <= 10, "top suggestion should be near level 20, got dist " .. tostring(s[1].dist))
end)

T.test("SuggestZones returns nothing at max skill in gray-only data", function()
	local s = Core.SuggestZones("mining", 400, 60)
	T.eq(#s, 0)
end)

T.test("ZoneTip wording", function()
	local r = Core.ZoneNodes(1413, "mining", 70)
	T.contains(Core.ZoneTip(r, "Mining", 70), "5 more skill unlocks Silver Vein (75)")
	r = Core.ZoneNodes(1411, "mining", 150)
	T.contains(Core.ZoneTip(r, "Mining", 150), "gray")
	r = Core.ZoneNodes(1413, "mining", 90)
	T.contains(Core.ZoneTip(r, "Mining", 90), "gather everything")
	r = Core.ZoneNodes(1446, "mining", 10)
	T.contains(Core.ZoneTip(r, "Mining", 10), "nothing here is gatherable")
	local sk = Core.ZoneReport(1413, { skinning = 200 }).kinds.skinning
	T.contains(Core.ZoneTip(sk, "Skinning", 200), "skin everything")
end)

T.print("Data")

T.test("every node id in ZoneNodes has a definition", function()
	local missing = {}
	for mapID, z in pairs(ns.ZoneNodes) do
		for id in pairs(z.mining or {}) do if not D.MiningNodes[id] then missing[#missing + 1] = "mining " .. id .. " in " .. mapID end end
		for id in pairs(z.herbs or {}) do if not D.HerbNodes[id] then missing[#missing + 1] = "herb " .. id .. " in " .. mapID end end
	end
	T.eq(#missing, 0, table.concat(missing, "; "))
end)

T.test("every zone with nodes has a zone entry", function()
	local missing = {}
	for mapID in pairs(ns.ZoneNodes) do if not D.Zones[mapID] then missing[#missing + 1] = tostring(mapID) end end
	T.eq(#missing, 0, "zones without entry: " .. table.concat(missing, ", "))
end)

T.test("ranks are increasing and consistent", function()
	local prev = 0
	for _, r in ipairs(D.Ranks) do
		T.truthy(r.cap > prev)
		if r.trainAt then T.truthy(r.trainAt < r.cap) end
		prev = r.cap
	end
	T.eq(prev, D.MaxSkill)
end)

T.print("Data-driven target")

T.test("DataTarget: plausible values and monotonic", function()
	T.eq(Core.DataTarget("mining", 3), 0)
	T.eq(Core.DataTarget("fishing", 30), nil)
	local prev = 0
	for L = 5, 60 do
		local m = Core.DataTarget("mining", L)
		T.truthy(m, "mining target at " .. L)
		T.truthy(m >= prev, "mining target should not drop at level " .. L)
		T.truthy(m <= 300)
		prev = m
	end
	local m20 = Core.DataTarget("mining", 20)
	T.truthy(m20 >= 65 and m20 <= 125, "mining at 20 was " .. m20)
	local h24 = Core.DataTarget("herbs", 24)
	T.truthy(h24 >= 100 and h24 <= 150, "herbs at 24 was " .. h24)
	T.truthy(Core.DataTarget("herbs", 60) >= 280)
	T.truthy(Core.DataTarget("mining", 60) >= 270)
end)

T.test("TargetFor picks data for gathering, rule for crafting", function()
	local t, src = Core.TargetFor({ key = "mining" }, 24)
	T.eq(src, "data"); T.eq(t, Core.DataTarget("mining", 24))
	t, src = Core.TargetFor({ key = "blacksmith" }, 24)
	T.eq(src, "rule"); T.eq(t, 120)
	t, src = Core.TargetFor({ key = "skinning" }, 24)
	T.eq(src, "rule")
end)

T.test("Assess carries targetSource", function()
	local a = Core.Assess({ name = "Mining", kind = "gather", key = "mining", skill = 108, max = 150 }, 24)
	T.eq(a.targetSource, "data")
	T.eq(a.diff, 108 - Core.DataTarget("mining", 24))
	a = Core.Assess({ name = "Blacksmithing", kind = "craft", key = "blacksmith", skill = 93, max = 150 }, 24)
	T.eq(a.targetSource, "rule")
	T.eq(a.target, 120)
end)
