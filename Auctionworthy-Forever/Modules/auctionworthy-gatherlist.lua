-- On-screen gather list. Same columns as AuctionworthyWA. Click a title to collapse.
-- Snapshot still comes from auctionworthy-weakaura.lua.

local LINE_H = 14
local HEADER_H = 16
local GAP = 8
local FONT_SIZE = 12

local SECTIONS = {
	{ key = "herbs", title = "Herbs", collapse = "collapseGatherHerbs", skill = "herbalism" },
	{ key = "ores", title = "Ore", collapse = "collapseGatherOre", skill = "mining" },
	{ key = "leathers", title = "Leathers", collapse = "collapseGatherLeathers", skill = "skinning" },
}

local panel
local headers = {}
local lines = {}
local lineCount = 0
local pendingUpdate = false
local headerDrag
local FONT_FILE = "Interface\\AddOns\\Auctionworthy-Forever\\Media\\Fonts\\FiraMono-Medium.ttf"

do
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM and LSM.Register then
		LSM:Register("font", "Fira Mono Medium", FONT_FILE)
	end
end

local function ListBlocked()
	if Auctionworthy.InCombat and Auctionworthy:InCombat() then
		return true
	end
	if Auctionworthy.PlayerDead and Auctionworthy:PlayerDead() then
		return true
	end
	return false
end

local function Secret(value)
	return Auctionworthy.Secret and Auctionworthy:Secret(value)
end

local function FontPath()
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM and LSM.Fetch then
		local path = LSM:Fetch("font", "Fira Mono Medium", true)
		if type(path) == "string" and path ~= "" then
			return path
		end
	end
	return FONT_FILE
end

local function ApplyFont(fs, size, flags)
	if not fs then
		return
	end
	local path = FontPath()
	local ok = pcall(fs.SetFont, fs, path, size or FONT_SIZE, flags or "OUTLINE")
	if not ok then
		fs:SetFontObject(GameFontHighlightSmall)
	end
end

local function OptionOn(key)
	return Auctionworthy:GetOption(key) and true or false
end

local function KeepBehind()
	if not panel then
		return
	end
	panel:SetFrameStrata("BACKGROUND")
	panel:SetFrameLevel(1)
	if panel.SetFixedFrameStrata then
		pcall(panel.SetFixedFrameStrata, panel, true)
	end
end

local function CtrlDown()
	if ListBlocked() then
		return false
	end
	if not IsControlKeyDown then
		return false
	end
	local ok, down = pcall(IsControlKeyDown)
	if not ok or Secret(down) then
		return false
	end
	return down and true or false
end

local function PinTopLeft()
	if not panel or ListBlocked() then
		return
	end
	local left, top = panel:GetLeft(), panel:GetTop()
	if Secret(left) or Secret(top) then
		return
	end
	left = tonumber(left)
	top = tonumber(top)
	if not left or not top then
		return
	end
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function ApplyListPos()
	if not panel or ListBlocked() then
		return
	end
	local pos = Auctionworthy:GetOption("gatherListPos")
	panel:ClearAllPoints()
	if type(pos) == "table" then
		local x, y = tonumber(pos.x), tonumber(pos.y)
		if x and y and not Secret(x) and not Secret(y) then
			if pos.point == "TOPLEFT" then
				panel:SetPoint("TOPLEFT", UIParent, pos.relativePoint or "BOTTOMLEFT", x, y)
			else
				panel:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, x, y)
				PinTopLeft()
			end
			return
		end
	end
	panel:SetPoint("TOPLEFT", UIParent, "CENTER", -400, 200)
end

local function SaveListPos()
	if not panel or ListBlocked() then
		return
	end
	PinTopLeft()
	local left, top = panel:GetLeft(), panel:GetTop()
	if Secret(left) or Secret(top) then
		return
	end
	left = tonumber(left)
	top = tonumber(top)
	if not left or not top then
		return
	end
	Auctionworthy:SetOption("gatherListPos", {
		point = "TOPLEFT",
		relativePoint = "BOTTOMLEFT",
		x = left,
		y = top,
	})
end

local function EnsurePanel()
	if panel then
		return panel
	end
	if ListBlocked() then
		pendingUpdate = true
		return
	end
	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	panel = CreateFrame("Frame", "AuctionworthyGatherList", UIParent, template)
	panel:SetSize(480, 40)
	panel:EnableMouse(false)
	KeepBehind()
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	panel:Hide()
	ApplyListPos()
	Auctionworthy:ApplyGatherListLook()
	for i = 1, #SECTIONS do
		local spec = SECTIONS[i]
		local btn = CreateFrame("Button", nil, panel)
		btn:SetSize(480, HEADER_H)
		btn:EnableMouse(true)
		btn:RegisterForClicks("LeftButtonUp")
		local fs = btn:CreateFontString(nil, "OVERLAY")
		ApplyFont(fs, FONT_SIZE, "OUTLINE")
		fs:SetJustifyH("LEFT")
		fs:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
		fs:SetTextColor(1, 0.82, 0)
		btn.label = fs
		btn.spec = spec
		btn:SetScript("OnMouseDown", function()
			if ListBlocked() or not CtrlDown() then
				return
			end
			headerDrag = true
			panel:StartMoving()
		end)
		btn:SetScript("OnMouseUp", function()
			if not headerDrag then
				return
			end
			panel:StopMovingOrSizing()
			SaveListPos()
		end)
		btn:SetScript("OnClick", function(self)
			if headerDrag then
				headerDrag = nil
				return
			end
			if ListBlocked() then
				return
			end
			local key = self.spec.collapse
			Auctionworthy:SetOption(key, not OptionOn(key))
			if Auctionworthy.UpdateGatherList then
				Auctionworthy:UpdateGatherList()
			end
		end)
		headers[i] = btn
	end
	return panel
end

local function GetLine(i)
	local fs = lines[i]
	if fs then
		return fs
	end
	if not panel then
		return
	end
	fs = panel:CreateFontString(nil, "OVERLAY")
	ApplyFont(fs, FONT_SIZE, "OUTLINE")
	fs:SetJustifyH("LEFT")
	fs:SetTextColor(1, 1, 1)
	lines[i] = fs
	return fs
end

local function HideUnusedLines(from)
	for i = from, lineCount do
		if lines[i] then
			lines[i]:Hide()
		end
	end
end

function Auctionworthy:UpdateGatherList()
	if Auctionworthy.InCombat and Auctionworthy:InCombat() then
		pendingUpdate = true
		return
	end
	if Auctionworthy.PlayerDead and Auctionworthy:PlayerDead() then
		pendingUpdate = true
		return
	end
	if Auctionworthy:GetOption("showGatherList") == false then
		if panel then
			panel:Hide()
		end
		return
	end
	if not EnsurePanel() then
		return
	end
	KeepBehind()
	local wa = AuctionworthyWA
	if type(wa) ~= "table" then
		wa = {}
	end
	local used = 1
	local y = 0
	for i = 1, #SECTIONS do
		local spec = SECTIONS[i]
		local rows = wa[spec.key]
		if spec.key == "leathers" and (not rows or #rows == 0) then
			rows = wa.skins
		end
		local n = type(rows) == "table" and #rows or 0
		local header = headers[i]
		local showSection = OptionOn("showAllGatherProfessions") or (spec.skill and wa[spec.skill])
		if header and not showSection then
			header:Hide()
		elseif header then
			local collapsed = OptionOn(spec.collapse)
			local mark = collapsed and "►" or "▼"
			header.label:SetText(mark .. " " .. spec.title)
			header:ClearAllPoints()
			header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
			header:Show()
			y = y + HEADER_H
			if not collapsed then
				for r = 1, n do
					local row = rows[r]
					local fs = GetLine(used)
					if fs then
						fs:ClearAllPoints()
						fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
						fs:SetText(row.line or "")
						fs:Show()
						used = used + 1
						y = y + LINE_H
					end
				end
			end
			y = y + GAP
		end
	end
	HideUnusedLines(used)
	lineCount = math.max(lineCount, used - 1)
	if y < 1 then
		panel:Hide()
		return
	end
	panel:SetHeight(y)
	Auctionworthy:ApplyGatherListLook()
	panel:Show()
	PinTopLeft()
end

function Auctionworthy:ApplyGatherListLook()
	if not panel then
		return
	end
	if ListBlocked() then
		pendingUpdate = true
		return
	end
	local scale = tonumber(Auctionworthy:GetOption("gatherListScale")) or 1
	if Secret(scale) or scale < 0.5 then
		scale = 0.5
	elseif scale > 2 then
		scale = 2
	end
	local alpha = tonumber(Auctionworthy:GetOption("gatherListAlpha")) or 1
	if Secret(alpha) or alpha < 0.2 then
		alpha = 0.2
	elseif alpha > 1 then
		alpha = 1
	end
	panel:SetScale(scale)
	panel:SetAlpha(alpha)
end

local defer = CreateFrame("Frame")
defer:RegisterEvent("PLAYER_REGEN_ENABLED")
defer:RegisterEvent("PLAYER_REGEN_DISABLED")
defer:RegisterEvent("PLAYER_ALIVE")
defer:RegisterEvent("PLAYER_UNGHOST")
defer:RegisterEvent("PLAYER_DEAD")
defer:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD" then
		headerDrag = nil
		pendingUpdate = true
		if panel then
			panel:StopMovingOrSizing()
		end
		return
	end
	if not pendingUpdate then
		return
	end
	if ListBlocked() then
		return
	end
	pendingUpdate = false
	if Auctionworthy.RefreshGatherSnapshot then
		Auctionworthy:RefreshGatherSnapshot()
	elseif Auctionworthy.UpdateGatherList then
		Auctionworthy:UpdateGatherList()
	end
end)
