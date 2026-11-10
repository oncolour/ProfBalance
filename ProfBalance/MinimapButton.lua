-- Minimap button: left-click toggles the window, drag moves it around the minimap,
-- right-click prints the summary. No library dependencies.
local addonName, ns = ...
ns.Minimap = {}
local M = ns.Minimap
local Core, API = ns.Core, ns.API

local button
local EDGE = 5 -- how far outside the minimap edge the button centre sits (same as LibDBIcon)
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- Which quadrants are rounded for each minimap shape (1 = top-right, 2 = top-left, 3 = bottom-right, 4 = bottom-left).
local minimapShapes = {
	["ROUND"] = { true, true, true, true },
	["SQUARE"] = { false, false, false, false },
	["CORNER-TOPLEFT"] = { false, false, false, true },
	["CORNER-TOPRIGHT"] = { false, false, true, false },
	["CORNER-BOTTOMLEFT"] = { false, true, false, false },
	["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
	["SIDE-LEFT"] = { false, true, false, true },
	["SIDE-RIGHT"] = { true, false, true, false },
	["SIDE-TOP"] = { false, false, true, true },
	["SIDE-BOTTOM"] = { true, true, false, false },
	["TRICORNER-TOPLEFT"] = { false, true, true, true },
	["TRICORNER-TOPRIGHT"] = { true, false, true, true },
	["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
	["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function settings()
	ns.db.minimap = ns.db.minimap or {}
	if ns.db.minimap.angle == nil then ns.db.minimap.angle = 220 end
	if ns.db.minimap.hide == nil then ns.db.minimap.hide = false end
	return ns.db.minimap
end

local function updatePosition()
	if not button then return end
	local s = settings()
	local rad = math.rad(s.angle)
	local x, y, q = math.cos(rad), math.sin(rad), 1
	if x < 0 then q = q + 1 end
	if y > 0 then q = q + 2 end
	local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
	local quad = minimapShapes[shape] or minimapShapes["ROUND"]
	-- Radius follows the minimap's real size, so large or rescaled minimaps keep the button on the rim.
	local w = ((Minimap:GetWidth() or 140) / 2) + EDGE
	local h = ((Minimap:GetHeight() or 140) / 2) + EDGE
	if quad[q] then
		x, y = x * w, y * h
	else
		local diagW = math.sqrt(2 * w * w) - 10
		local diagH = math.sqrt(2 * h * h) - 10
		x = math.max(-w, math.min(x * diagW, w))
		y = math.max(-h, math.min(y * diagH, h))
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onDragUpdate(self)
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	if not (mx and my and cx and cy) then return end
	local scale = Minimap:GetEffectiveScale() or 1
	cx, cy = cx / scale, cy / scale
	settings().angle = math.deg(atan2(cy - my, cx - mx))
	updatePosition()
end

local function worstStatus(model)
	local worst
	for _, a in ipairs(model and model.profs or {}) do
		if a.kind ~= "secondary" then
			for i, s in ipairs(Core.StatusOrder) do
				if a.status == s and (not worst or i < worst) then worst = i end
			end
		end
	end
	return worst and Core.StatusOrder[worst] or nil
end

function M.ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("ProfBalance", 1, 1, 1)
	local model = ns.lastModel
	if not model then
		local ok, m = pcall(ns.BuildModel)
		if ok then model = m end
	end
	if model and #model.profs > 0 then
		for _, a in ipairs(model.profs) do
			local info = Core.StatusInfo[a.status]
			local right = info.label
			if a.rankKey == "train" then right = a.rankText end
			GameTooltip:AddDoubleLine(string.format("%s %d/%d", a.name, a.skill, a.max), right, 0.9, 0.9, 0.9, info.color[1], info.color[2], info.color[3])
		end
	else
		GameTooltip:AddLine("No professions found", 0.6, 0.6, 0.6)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: toggle window", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("Right-click: summary in chat", 0.6, 0.6, 0.6)
	GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function M.Create()
	if button then return button end
	if not Minimap then return nil end
	settings()
	button = CreateFrame("Button", "ProfBalanceMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(19, 19)
	icon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\icon_minimap")
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -5)
	-- Round off the square texture so it sits cleanly inside the tracking border.
	if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

	-- Small status dot in the lower right: coloured by the worst pace status.
	local dotBg = button:CreateTexture(nil, "OVERLAY", nil, 6)
	dotBg:SetSize(11, 11)
	dotBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	dotBg:SetVertexColor(0, 0, 0, 0.9)
	if dotBg.SetMask then dotBg:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
	dotBg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 4)
	local dot = button:CreateTexture(nil, "OVERLAY", nil, 7)
	dot:SetSize(7, 7)
	dot:SetTexture("Interface\\Buttons\\WHITE8X8")
	if dot.SetMask then dot:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
	dot:SetPoint("CENTER", dotBg, "CENTER", 0, 0)
	button.dot, button.dotBg = dot, dotBg

	button:SetScript("OnClick", function(_, btn)
		if btn == "RightButton" then
			if ns.PrintSummary then ns.PrintSummary() end
		else
			ns.SetShown(not ns.db.shown)
		end
	end)
	button:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self:SetScript("OnUpdate", onDragUpdate)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
	end)
	button:SetScript("OnEnter", M.ShowTooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	updatePosition()
	M.Refresh()
	return button
end

function M.GetButton() return button end

-- Colour the status dot by the worst pace status and apply show/hide.
function M.Refresh()
	if not button then return end
	if settings().hide then button:Hide() else button:Show() end
	updatePosition() -- the minimap may have been resized by another addon after login
	local worst = worstStatus(ns.lastModel)
	if worst then
		local c = Core.StatusInfo[worst].color
		button.dot:SetVertexColor(c[1], c[2], c[3], 1)
		button.dot:Show(); button.dotBg:Show()
	else
		button.dot:Hide(); button.dotBg:Hide()
	end
	button.worst = worst
end

function M.SetHidden(flag)
	settings().hide = flag and true or false
	M.Refresh()
end
