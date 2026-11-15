-- Corner letters on the Auctionator Selling bag icons.
-- Green A: auction it. Red V: vendor it. The quality border is left alone.
-- Does not edit Auctionator. Skips price lookups while a scan is running.

local GREEN = { 0, 1, 0 }
local RED = { 1, 0.15, 0.15 }

local seen = {}
local hooked

local function HideMark(button)
	if button.AuctionworthyMark then
		button.AuctionworthyMark:Hide()
	end
end

local function EnsureMark(button)
	local mark = button.AuctionworthyMark
	if mark then
		return mark
	end
	mark = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	mark:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -1)
	mark:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
	mark:SetJustifyH("LEFT")
	button.AuctionworthyMark = mark
	return mark
end

local function ShowMark(button, letter, color)
	local mark = EnsureMark(button)
	mark:SetText(letter)
	mark:SetTextColor(color[1], color[2], color[3], 1)
	mark:Show()
end

local function Paint(button, info)
	seen[button] = true
	if type(info) ~= "table" then
		button.AuctionworthyDirty = nil
		HideMark(button)
		return
	end
	local link = info.itemLink
	if type(link) ~= "string" or link == "" or Auctionworthy:Secret(link) then
		button.AuctionworthyDirty = nil
		HideMark(button)
		return
	end
	if Auctionworthy:ScanBusy() then
		button.AuctionworthyDirty = true
		HideMark(button)
		return
	end
	local line = Auctionworthy:ItemSellLine(link)
	button.AuctionworthyDirty = nil
	if type(line) == "string" and line:sub(1, 6) == "AH it:" then
		ShowMark(button, "A", GREEN)
	elseif type(line) == "string" and line:sub(1, 10) == "Vendor it:" then
		ShowMark(button, "V", RED)
	else
		HideMark(button)
	end
end

local function RefreshDirty()
	if Auctionworthy:ScanBusy() then
		return
	end
	for button in pairs(seen) do
		if button.AuctionworthyDirty and button.itemInfo then
			Paint(button, button.itemInfo)
		end
	end
end

local function Hook()
	if hooked then
		return
	end
	local mixin = _G.AuctionatorGroupsViewItemMixin
	if type(mixin) ~= "table" or type(mixin.SetItemInfo) ~= "function" then
		return
	end
	hooked = true
	hooksecurefunc(mixin, "SetItemInfo", Paint)
end

local ticker = C_Timer.NewTicker(0.5, RefreshDirty)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name ~= "Auctionator" then
		return
	end
	Hook()
end)

-- Keep the ticker referenced so it is not collected.
frame.ticker = ticker
