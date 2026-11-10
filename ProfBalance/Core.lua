-- Pure logic. No WoW API calls here so it can run under a plain Lua interpreter.
local _, ns = ...
ns.Core = {}
local Core = ns.Core
local D = ns.Data

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end

-- Expected skill for a character level: the classic "5 x level" rule, capped at 300.
-- Nothing is expected before level 5.
function Core.TargetSkill(level)
	if not level or level < 5 then return 0 end
	return math.min(D.MaxSkill, level * 5)
end

Core.StatusOrder = { "far", "behind", "slightly", "ok", "ahead" }
Core.StatusInfo = {
	ahead    = { label = "Ahead",           color = { 0.45, 0.75, 1.0 } },
	ok       = { label = "In sync",         color = { 0.2, 0.9, 0.2 } },
	slightly = { label = "Slightly behind", color = { 1.0, 0.9, 0.2 } },
	behind   = { label = "Behind",          color = { 1.0, 0.55, 0.1 } },
	far      = { label = "Far behind",      color = { 1.0, 0.2, 0.2 } },
}

function Core.StatusFor(diff)
	if diff > 25 then return "ahead" end
	if diff >= -10 then return "ok" end
	if diff >= -40 then return "slightly" end
	if diff >= -90 then return "behind" end
	return "far"
end

-- Returns the next rank the character has not yet trained, given the current cap.
function Core.NextRank(maxSkill)
	for _, r in ipairs(D.Ranks) do
		if r.cap > (maxSkill or 0) then return r end
	end
	return nil
end

-- Advice about rank training. Returns key, text (or nil when nothing to say).
-- key: "train" (can train now), "level" (need character level), "soon" (fallback)
function Core.RankAdvice(skill, maxSkill, level)
	local nxt = Core.NextRank(maxSkill)
	if not nxt then return nil end
	local capped = skill >= maxSkill
	if skill >= nxt.trainAt then
		if level >= nxt.level then
			return "train", string.format("Train %s now (skill %d+)", nxt.name, nxt.trainAt)
		end
		if capped then
			return "level", string.format("Capped until level %d (%s)", nxt.level, nxt.name)
		end
		return "level", string.format("%s unlocks at level %d", nxt.name, nxt.level)
	end
	if capped then
		return "soon", string.format("%s at skill %d", nxt.name, nxt.trainAt)
	end
	return nil
end

-- Data-driven target for gathering: the skill needed to gather ~80% of the node spawns in
-- zones whose level band contains the character level. Zones are weighted by how close the
-- level is to the band's centre, and the result is smoothed over +-2 levels so a zone band
-- ending does not produce a cliff. Returns nil when there is no data for the kind.
Core.DataPercentile = 0.8
local dataTargetCache = {}

local function rawDataTarget(kind, level)
	local defs = (kind == "mining" and D.MiningNodes) or (kind == "herbs" and D.HerbNodes)
	if not defs then return nil end
	local items, total = {}, 0
	for mapID, z in pairs(ns.ZoneNodes) do
		local zone = D.Zones[mapID]
		if zone and zone.min and not zone.city and level >= zone.min and level <= zone.max then
			local centre, half = (zone.min + zone.max) / 2, (zone.max - zone.min) / 2 + 1
			local w = math.max(0.1, 1 - math.abs(level - centre) / half)
			for id, c in pairs(z[kind] or {}) do
				local def = defs[id]
				if def and not def.rare then
					items[#items + 1] = { req = def.req, w = c * w }
					total = total + c * w
				end
			end
		end
	end
	if total == 0 then return nil end
	table.sort(items, function(a, b) return a.req < b.req end)
	local acc = 0
	for _, it in ipairs(items) do
		acc = acc + it.w
		if acc >= total * Core.DataPercentile then return it.req end
	end
	return items[#items].req
end

function Core.DataTarget(kind, level)
	if not level or level < 5 then return (kind == "mining" or kind == "herbs") and 0 or nil end
	local key = kind .. ":" .. level
	if dataTargetCache[key] ~= nil then return dataTargetCache[key] or nil end
	local sum, n = 0, 0
	for L = math.max(1, level - 2), math.min(60, level + 2) do
		local v = rawDataTarget(kind, L)
		if v then sum, n = sum + v, n + 1 end
	end
	local result = n > 0 and math.floor(sum / n + 0.5) or nil
	-- never ask for more than the 300 cap, nor more than the level allows via rank gates
	if result then result = math.min(result, D.MaxSkill) end
	dataTargetCache[key] = result or false
	return result
end

-- Target for a profession: node data for Mining/Herbalism, the 5 x level rule otherwise.
-- Returns target, source ("data" or "rule").
function Core.TargetFor(prof, level)
	if prof.key == "mining" or prof.key == "herbs" then
		local t = Core.DataTarget(prof.key, level)
		if t then return t, "data" end
	end
	return Core.TargetSkill(level), "rule"
end

-- prof = { skill=, max=, kind=, name=, key=, icon= }. Returns an assessment table.
function Core.Assess(prof, level)
	local target, targetSource = Core.TargetFor(prof, level)
	local diff = prof.skill - target
	local status = Core.StatusFor(diff)
	local rankKey, rankText = Core.RankAdvice(prof.skill, prof.max, level)
	local a = {
		name = prof.name, kind = prof.kind, key = prof.key, icon = prof.icon,
		skill = prof.skill, max = prof.max, target = target, targetSource = targetSource, diff = diff,
		status = status, rankKey = rankKey, rankText = rankText,
		progress = clamp(prof.skill / D.MaxSkill, 0, 1),
		targetProgress = clamp(target / D.MaxSkill, 0, 1),
	}
	-- Capped and able to train is more urgent than the pace label.
	if rankKey == "train" and prof.skill >= prof.max then a.urgent = true end
	return a
end

function Core.SummaryLine(a)
	local info = Core.StatusInfo[a.status]
	local s = string.format("%s %d/%d: %s", a.name, a.skill, a.max, info.label)
	if a.diff < 0 then
		s = s .. string.format(" (%d below the %d expected at this level)", -a.diff, a.target)
	elseif a.diff > 0 then
		s = s .. string.format(" (+%d over the %d expected)", a.diff, a.target)
	end
	if a.rankText then s = s .. " - " .. a.rankText end
	return s
end

-- Skinning requirement for a mob level (Classic formula).
function Core.SkinningReq(mobLevel)
	if mobLevel <= 10 then return 1 end
	if mobLevel <= 20 then return (mobLevel - 10) * 10 end
	return mobLevel * 5
end

local function nodeTable(kind)
	if kind == "mining" then return D.MiningNodes end
	if kind == "herbs" then return D.HerbNodes end
	return nil
end

-- Builds the node list of one gathering kind in one zone, judged against a skill.
-- opts.includeRare: list rare nodes too. opts.minShare: hide nodes below this spawn share (default 2%).
function Core.ZoneNodes(mapID, kind, skill, opts)
	opts = opts or {}
	local zone = ns.ZoneNodes[mapID]
	local defs = nodeTable(kind)
	if not zone or not defs then return nil end
	local counts = zone[kind]
	if not counts then return nil end
	local total = 0
	for _, c in pairs(counts) do total = total + c end
	if total == 0 then return nil end
	local minShare = opts.minShare or 0.02
	local nodes = {}
	for id, c in pairs(counts) do
		local def = defs[id]
		if def then
			local share = c / total
			local hidden = (def.rare and not opts.includeRare) or (share < minShare and c < 5)
			if not hidden then
				local n = { id = id, name = def.name, req = def.req, count = c, share = share, rare = def.rare }
				if skill then
					n.canGather = skill >= def.req
					n.skillUp = n.canGather and skill < def.req + D.GrayOffset
					n.need = n.canGather and 0 or (def.req - skill)
				end
				nodes[#nodes + 1] = n
			end
		end
	end
	table.sort(nodes, function(a, b) if a.req ~= b.req then return a.req < b.req end return a.name < b.name end)
	local r = { kind = kind, nodes = nodes, total = total }
	if skill then
		r.canAll, r.anySkillUp, r.gatherShare, r.skillUpShare = true, false, 0, 0
		for _, n in ipairs(nodes) do
			if not n.canGather then r.canAll = false end
			if n.canGather then r.gatherShare = r.gatherShare + n.share end
			if n.skillUp then r.anySkillUp = true; r.skillUpShare = r.skillUpShare + n.share end
			if not n.canGather and (not r.nextUnlock or n.req < r.nextUnlock.req) then r.nextUnlock = n end
		end
	end
	return r
end

-- Full report for a zone. skills = { mining=number|nil, herbs=number|nil, skinning=number|nil }
function Core.ZoneReport(mapID, skills, opts)
	local zone = D.Zones[mapID]
	local report = { mapID = mapID, zone = zone, kinds = {} }
	for _, kind in ipairs({ "mining", "herbs" }) do
		if skills[kind] then
			report.kinds[kind] = Core.ZoneNodes(mapID, kind, skills[kind], opts)
		end
	end
	if skills.skinning and zone and zone.max then
		local req = Core.SkinningReq(zone.max)
		local reqMin = Core.SkinningReq(zone.min or zone.max)
		report.kinds.skinning = {
			kind = "skinning", reqMin = reqMin, reqMax = req,
			canAll = skills.skinning >= req,
			canSome = skills.skinning >= reqMin,
			need = math.max(0, req - skills.skinning),
			anySkillUp = skills.skinning < req + D.GrayOffset,
		}
	end
	return report
end

-- Distance from a level to a zone's level band (0 when inside).
local function levelDistance(zone, level)
	if not zone or not zone.min then return 15 end -- unknown range: mild penalty
	if level < zone.min then return zone.min - level end
	if level > zone.max then return level - zone.max end
	return 0
end

-- Suggest zones where this gathering kind still gives skill-ups, biased to the character level.
function Core.SuggestZones(kind, skill, level, opts)
	opts = opts or {}
	local limit = opts.limit or 3
	local out = {}
	for mapID in pairs(ns.ZoneNodes) do
		local zone = D.Zones[mapID]
		if not (zone and zone.city) then
			local r = Core.ZoneNodes(mapID, kind, skill, opts)
			if r and r.skillUpShare > 0 then
				local dist = levelDistance(zone, level)
				local score = r.skillUpShare * 100 - dist * 4
				if dist > 12 then score = score - 25 end
				out[#out + 1] = { mapID = mapID, zone = zone, score = score, skillUpShare = r.skillUpShare, gatherShare = r.gatherShare, dist = dist, total = r.total }
			end
		end
	end
	table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.mapID < b.mapID end)
	local top = {}
	for i = 1, math.min(limit, #out) do top[i] = out[i] end
	return top
end

-- One-line human tip for a zone report entry.
function Core.ZoneTip(kindReport, kindLabel, skill)
	if not kindReport then return nil end
	if kindReport.kind == "skinning" then
		if kindReport.canAll then return string.format("%s: you can skin everything here (needs up to %d)", kindLabel, kindReport.reqMax) end
		if kindReport.canSome then return string.format("%s: high-level beasts here need %d (you have %d)", kindLabel, kindReport.reqMax, skill) end
		return string.format("%s: beasts here need %d+ (you have %d)", kindLabel, kindReport.reqMin, skill)
	end
	if #kindReport.nodes == 0 then return string.format("%s: nothing to gather in this zone", kindLabel) end
	if kindReport.canAll and not kindReport.anySkillUp then
		return string.format("%s: everything here is gray - no skill-ups left, move on", kindLabel)
	end
	if kindReport.canAll then return string.format("%s: you can gather everything here", kindLabel) end
	local nu = kindReport.nextUnlock
	if kindReport.gatherShare == 0 then
		return string.format("%s: nothing here is gatherable yet - need %d for %s", kindLabel, nu.req, nu.name)
	end
	return string.format("%s: %d more skill unlocks %s (%d)", kindLabel, nu.need, nu.name, nu.req)
end
