-- Frame construction and rendering. Takes a model built by ProfBalance.lua.
local addonName, ns = ...
ns.UI = {}
local UI = ns.UI
local Core = ns.Core

local WIDTH, PAD, ROW_H, BAR_W = 320, 10, 26, 110
local frame, rows, zoneHeader, zoneLines, suggestLine, levelText
local lastModel

local function hex(c)
	return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
local GREEN, GRAY, RED, YELLOW, WHITE, BLUE = "|cff33dd33", "|cff8a8a8a", "|cffff5555", "|cffffd633", "|cffffffff", "|cff80c0ff"

local function kindLabel(kind)
	if kind == "mining" then return "Mining" end
	if kind == "herbs" then return "Herbalism" end
	if kind == "skinning" then return "Skinning" end
	return kind
end

local function makeFont(parent, size, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	if size then
		local f, _, flags = fs:GetFont()
		if f then fs:SetFont(f, size, flags) end
	end
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local function createRow(i)
	local r = CreateFrame("Frame", nil, frame)
	r:SetSize(WIDTH - PAD * 2, ROW_H)
	r:EnableMouse(true)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(18, 18)
	r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
	r.name = makeFont(r)
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetWidth(100)
	r.skill = makeFont(r, nil, "RIGHT")
	r.skill:SetPoint("RIGHT", r, "RIGHT", 0, 0)
	r.skill:SetWidth(52)
	r.bar = CreateFrame("StatusBar", nil, r)
	r.bar:SetSize(BAR_W, 8)
	r.bar:SetPoint("RIGHT", r.skill, "LEFT", -6, 0)
	r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	r.bar:SetMinMaxValues(0, 1)
	r.bar.bg = r.bar:CreateTexture(nil, "BACKGROUND")
	r.bar.bg:SetAllPoints(r.bar)
	r.bar.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
	r.bar.marker = r.bar:CreateTexture(nil, "OVERLAY")
	r.bar.marker:SetSize(2, 12)
	r.bar.marker:SetColorTexture(1, 1, 1, 0.9)
	r.status = makeFont(r, 9)
	r.status:SetPoint("TOPLEFT", r.bar, "BOTTOMLEFT", 0, -1)
	r.status:SetPoint("RIGHT", r.skill, "LEFT", -6, 0)
	r.status:SetJustifyH("LEFT")
	r:SetScript("OnEnter", function(self) UI.ShowTooltip(self) end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return r
end

function UI.Create()
	if frame then return frame end
	frame = CreateFrame("Frame", "ProfBalanceFrame", UIParent, "BackdropTemplate")
	frame:SetSize(WIDTH, 200)
	frame:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) if not (ns.db and ns.db.locked) then self:StartMoving() end end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if ns.SavePosition then ns.SavePosition(self) end
	end)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		frame:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
		frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	end

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -8)
	frame.title:SetText("ProfBalance")
	levelText = makeFont(frame, nil, "RIGHT")
	levelText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -9)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() if ns.SetShown then ns.SetShown(false) else frame:Hide() end end)

	rows = {}
	zoneHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	zoneHeader:SetJustifyH("LEFT")
	zoneLines = {}
	suggestLine = makeFont(frame, 10)
	suggestLine:SetWidth(WIDTH - PAD * 2)
	suggestLine:SetWordWrap(true)
	return frame
end

function UI.GetFrame() return frame end

local function zoneLine(i)
	if not zoneLines[i] then
		local fs = makeFont(frame, 10)
		fs:SetWidth(WIDTH - PAD * 2)
		fs:SetWordWrap(true)
		fs:SetSpacing(2)
		zoneLines[i] = fs
	end
	return zoneLines[i]
end

local function nodeText(n)
	if n.canGather == nil then return WHITE .. n.name .. "|r" end
	if not n.canGather then return string.format("%s%s (%d)|r", RED, n.name, n.req) end
	if n.skillUp then return GREEN .. n.name .. "|r" end
	return GRAY .. n.name .. "|r"
end

local function renderZoneKind(kind, kr, skill)
	local parts = {}
	if kind == "skinning" then
		local c = kr.canAll and GREEN or (kr.canSome and YELLOW or RED)
		return string.format("%s%s|r: beasts need %d-%d skill %s(you: %d)|r", WHITE, kindLabel(kind), kr.reqMin, kr.reqMax, c, skill)
	end
	for _, n in ipairs(kr.nodes) do parts[#parts + 1] = nodeText(n) end
	if #parts == 0 then parts[1] = GRAY .. "no nodes recorded|r" end
	return string.format("%s%s|r: %s", WHITE, kindLabel(kind), table.concat(parts, GRAY .. " · |r"))
end

local function suggestionText(model)
	local bits = {}
	for _, kind in ipairs({ "mining", "herbs" }) do
		local kr = model.zone and model.zone.report and model.zone.report.kinds[kind]
		local list = model.suggestions and model.suggestions[kind]
		-- Only nag when this zone has nothing left to give.
		if kr and not kr.anySkillUp and list and #list > 0 then
			local names = {}
			for i, s in ipairs(list) do
				if i <= 2 then
					local z = s.zone
					local range = (z and z.min) and string.format(" (%d-%d)", z.min, z.max) or ""
					names[#names + 1] = ns.API.GetZoneName(s.mapID) .. range
				end
			end
			bits[#bits + 1] = string.format("%s%s skill-ups:|r try %s", YELLOW, kindLabel(kind), table.concat(names, " or "))
		end
	end
	return table.concat(bits, "\n")
end

function UI.Refresh(model)
	if not frame then UI.Create() end
	lastModel = model
	levelText:SetText(string.format("Level %d", model.level))

	local y = -30
	local shownRows = 0
	for i, a in ipairs(model.profs) do
		local r = rows[i] or createRow(i)
		rows[i] = r
		r.assessment = a
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
		if a.icon then r.icon:SetTexture(a.icon) else r.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
		r.name:SetText(a.name)
		r.skill:SetText(string.format("%d/%d", a.skill, a.max))
		local info = Core.StatusInfo[a.status]
		r.bar:SetValue(a.progress)
		r.bar:SetStatusBarColor(info.color[1], info.color[2], info.color[3])
		r.bar.marker:ClearAllPoints()
		r.bar.marker:SetPoint("CENTER", r.bar, "LEFT", math.floor(a.targetProgress * BAR_W + 0.5), 0)
		local label = hex(info.color) .. info.label .. "|r"
		if a.diff < 0 then label = label .. GRAY .. string.format(" (%d)", a.diff) .. "|r" end
		if a.rankKey == "train" then label = YELLOW .. "! " .. a.rankText .. "|r"
		elseif a.rankKey == "level" and a.skill >= a.max then label = GRAY .. a.rankText .. "|r" end
		r.status:SetText(label)
		r:Show()
		y = y - ROW_H - 6
		shownRows = i
	end
	for i = shownRows + 1, #rows do rows[i]:Hide() end
	if shownRows == 0 then
		local r = rows[1] or createRow(1)
		rows[1] = r
		r.assessment = nil
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
		r.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		r.name:SetText("No professions found")
		r.skill:SetText("")
		r.bar:SetValue(0)
		r.status:SetText(GRAY .. "Learn one, or /profbalance debug|r")
		r:Show()
		y = y - ROW_H - 6
	end

	-- Zone section
	y = y - 4
	zoneHeader:ClearAllPoints()
	zoneHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
	local zname = model.zone and model.zone.name or "Unknown zone"
	local z = model.zone and model.zone.report and model.zone.report.zone
	if z and z.min then zname = string.format("%s (%d-%d)", zname, z.min, z.max) end
	zoneHeader:SetText(zname)
	zoneHeader:Show()
	y = y - 14

	local li = 0
	local report = model.zone and model.zone.report
	local hasGatherer = false
	for _, kind in ipairs({ "mining", "herbs", "skinning" }) do
		local skill = model.skills and model.skills[kind]
		if skill then
			hasGatherer = true
			li = li + 1
			local fs = zoneLine(li)
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
			local kr = report and report.kinds[kind]
			if kr then
				fs:SetText(renderZoneKind(kind, kr, skill))
			else
				fs:SetText(string.format("%s%s|r: %sno node data for this zone|r", WHITE, kindLabel(kind), GRAY))
			end
			fs:Show()
			y = y - math.max(12, fs:GetStringHeight() + 2) - 2
			local tip = kr and Core.ZoneTip(kr, kindLabel(kind), skill)
			if tip then
				li = li + 1
				local tfs = zoneLine(li)
				tfs:ClearAllPoints()
				tfs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 8, y)
				tfs:SetText(GRAY .. tip .. "|r")
				tfs:Show()
				y = y - math.max(12, tfs:GetStringHeight() + 2) - 4
			end
		end
	end
	if not hasGatherer then
		li = li + 1
		local fs = zoneLine(li)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
		fs:SetText(GRAY .. "No gathering profession - zone node info appears here when you learn one.|r")
		fs:Show()
		y = y - math.max(12, fs:GetStringHeight() + 2) - 2
	end
	for i = li + 1, #zoneLines do zoneLines[i]:Hide() end

	local st = suggestionText(model)
	suggestLine:ClearAllPoints()
	suggestLine:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
	if st ~= "" then
		suggestLine:SetText(st)
		suggestLine:Show()
		y = y - math.max(12, suggestLine:GetStringHeight() + 2)
	else
		suggestLine:Hide()
	end

	frame:SetHeight(math.max(80, -y + PAD + 2))
end

function UI.ShowTooltip(row)
	local a = row.assessment
	if not a or not lastModel then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(a.name, 1, 1, 1)
	GameTooltip:AddDoubleLine("Skill", string.format("%d / %d", a.skill, a.max), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine(string.format("Expected at level %d", lastModel.level), tostring(a.target), 0.8, 0.8, 0.8, 1, 1, 1)
	if a.targetSource == "data" then
		GameTooltip:AddLine(string.format("= skill to gather ~%d%% of nodes in zones for your level", math.floor(Core.DataPercentile * 100 + 0.5)), 0.6, 0.6, 0.6, true)
	else
		GameTooltip:AddLine("= 5 x level rule of thumb", 0.6, 0.6, 0.6, true)
	end
	local info = Core.StatusInfo[a.status]
	GameTooltip:AddDoubleLine("Pace", info.label .. (a.diff ~= 0 and string.format(" (%+d)", a.diff) or ""), 0.8, 0.8, 0.8, info.color[1], info.color[2], info.color[3])
	if a.rankText then GameTooltip:AddLine(a.rankText, 1, 0.85, 0.2, true) end
	local rec = lastModel.recipes and lastModel.recipes[a.key]
	if rec then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(string.format("Recipes that still skill up: %d orange, %d yellow", rec.orange, rec.yellow), 0.8, 0.8, 0.8, true)
	end
	local sug = lastModel.suggestions and lastModel.suggestions[a.key]
	if sug and #sug > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Zones with skill-ups near your level:", 1, 1, 1)
		for _, s in ipairs(sug) do
			local z = s.zone
			local range = (z and z.min) and string.format("%d-%d", z.min, z.max) or "?"
			GameTooltip:AddDoubleLine(ns.API.GetZoneName(s.mapID), string.format("%s · %d%% of nodes", range, math.floor(s.skillUpShare * 100 + 0.5)), 0.9, 0.9, 0.9, 0.7, 0.7, 0.7)
		end
	end
	if a.kind == "gather" and a.key ~= "skinning" then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Green = gives skill-ups here, gray = too easy, red = locked (req).", 0.6, 0.6, 0.6, true)
	end
	GameTooltip:Show()
end
