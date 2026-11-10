-- Auctionworthy-Forever (Auctionator API v1).
-- /auctionworthy or /worthy

local ADDON_NAME = ...
local CALLER_ID = "Auctionworthy-Forever"

local Auctionworthy = CreateFrame("Frame")
Auctionworthy:RegisterEvent("ADDON_LOADED")
Auctionworthy:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		self[event](self, ...)
	end
end)

local defaultOptions = {
	showAuctionCosts = true,
	showAuctionPrice = true,
	showProfitOptions = true,
	showNoAuctionData = true,
	showFullStack = true,
	showDecisionText = true,
}

local options = {}

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

local function LoadOptions()
	if not AuctionworthySavedOptions then
		AuctionworthySavedOptions = {}
	end
	for key, value in pairs(defaultOptions) do
		if AuctionworthySavedOptions[key] == nil then
			AuctionworthySavedOptions[key] = value
		end
	end
	options = AuctionworthySavedOptions
end

local function SaveOptions()
	AuctionworthySavedOptions = options
end

local function formatGold(value)
	value = math.floor(tonumber(value) or 0)
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		return C_CurrencyInfo.GetCoinTextureString(value)
	end
	if GetCoinTextureString then
		return GetCoinTextureString(value)
	end
	local gold = math.floor(value / 10000)
	local silver = math.floor((value % 10000) / 100)
	local copper = math.floor(value % 100)
	return gold .. "g " .. silver .. "s " .. copper .. "c"
end

local function AuctionatorReady()
	return Auctionator
		and Auctionator.API
		and Auctionator.API.v1
		and Auctionator.API.v1.GetAuctionPriceByItemLink
end

local function getAuctionPrice(itemLink)
	if not AuctionatorReady() or type(itemLink) ~= "string" then
		return nil
	end
	local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemLink, CALLER_ID, itemLink)
	if ok and type(price) == "number" and price > 0 and not Secret(price) then
		return price
	end
	return nil
end

-- Classic-style "what it costs to auction vs vendor": deposit-ish + listing overhead.
local function calculateAuctionCosts(vendorPrice)
	return math.floor(vendorPrice * 0.6) + vendorPrice + math.floor(vendorPrice * 0.05)
end

local function ItemInfo(itemLink)
	local ok, name, link, quality, ilvl, minLevel, itemType, subType, stackSize, equipLoc, texture, vendorPrice, classID, subclassID, bindType = pcall(GetItemInfo, itemLink)
	if not ok then
		return
	end
	return name, link, quality, ilvl, minLevel, itemType, subType, stackSize, equipLoc, texture, vendorPrice, classID, subclassID, bindType
end

local function isSoulboundTooltip(tooltip)
	if tooltip.IsForbidden and tooltip:IsForbidden() then
		return false
	end
	local tooltipName = tooltip.GetName and tooltip:GetName()
	if not tooltipName then
		return false
	end
	local n = tooltip.NumLines and tooltip:NumLines() or 0
	for i = 1, n do
		local line = _G[tooltipName .. "TextLeft" .. i]
		local text = line and line.GetText and line:GetText()
		if type(text) == "string" and not Secret(text) then
			if text == ITEM_SOULBOUND or text == ITEM_BIND_ON_PICKUP or text == ITEM_BIND_QUEST then
				return true
			end
		end
	end
	return false
end

local function GetLinkFromTooltip(tooltip, data)
	if data then
		if type(data.hyperlink) == "string" and not Secret(data.hyperlink) then
			return data.hyperlink
		end
		if data.guid and C_Item and C_Item.GetItemLinkByGUID then
			local ok, link = pcall(C_Item.GetItemLinkByGUID, data.guid)
			if ok and type(link) == "string" then
				return link
			end
		end
	end
	if tooltip.GetItem then
		local ok, _, link = pcall(tooltip.GetItem, tooltip)
		if ok and type(link) == "string" then
			return link
		end
	end
end

local function updateTooltip(tooltip, itemLink)
	if not tooltip or not itemLink or Secret(itemLink) then
		return
	end
	if tooltip.IsForbidden and tooltip:IsForbidden() then
		return
	end
	if tooltip.AuctionworthyAdded then
		return
	end
	if isSoulboundTooltip(tooltip) then
		return
	end

	local _, _, _, _, _, _, _, stackSize, _, _, vendorPrice, _, _, bindType = ItemInfo(itemLink)
	if Secret(vendorPrice) or Secret(stackSize) or Secret(bindType) then
		return
	end
	if bindType == 1 or bindType == 4 then
		return
	end
	if not vendorPrice or vendorPrice <= 0 then
		return
	end

	local auctionPrice = getAuctionPrice(itemLink)
	stackSize = stackSize or 1

	local isFullStack = IsShiftKeyDown() and stackSize > 1 and options.showFullStack
	local auctionCosts = calculateAuctionCosts(vendorPrice)

	if isFullStack then
		auctionCosts = auctionCosts * stackSize
		auctionPrice = auctionPrice and auctionPrice * stackSize or nil
		vendorPrice = vendorPrice * stackSize
		tooltip:AddLine("|cFFFFA500Calculations for Full Stack (" .. stackSize .. "x)|r")
	end

	if auctionPrice then
		local profit = auctionPrice - auctionCosts
		if options.showAuctionCosts then
			tooltip:AddLine("Auction Costs | " .. formatGold(auctionCosts))
		end
		if options.showAuctionPrice then
			tooltip:AddLine("Auction Price | " .. formatGold(auctionPrice))
		end
		if profit > 0 then
			if options.showProfitOptions then
				tooltip:AddLine("Profit | " .. formatGold(profit), 0, 1, 0)
			end
			if options.showDecisionText then
				if profit < auctionCosts * 0.05 or profit < 25 then
					tooltip:AddLine("Sell to Vendor!", 1, 0.65, 0)
				else
					tooltip:AddLine("Auction it!", 0, 1, 0)
				end
			end
		else
			if options.showProfitOptions then
				tooltip:AddLine("Loss | " .. formatGold(-profit), 1, 0, 0)
			end
			if options.showDecisionText then
				tooltip:AddLine("Sell to vendor!", 1, 0, 0)
			end
		end
	elseif options.showNoAuctionData then
		tooltip:AddLine("No Auction Data", 1, 0, 1)
	end

	tooltip.AuctionworthyAdded = true
	tooltip:Show()
end

local function HookCleared(tooltip)
	if not tooltip or tooltip.AuctionworthyClearedHook then
		return
	end
	tooltip.AuctionworthyClearedHook = true
	tooltip:HookScript("OnTooltipCleared", function(self)
		self.AuctionworthyAdded = nil
	end)
end

local function AttachItemTooltip(tooltip, data)
	HookCleared(tooltip)
	updateTooltip(tooltip, GetLinkFromTooltip(tooltip, data))
end

local function ContainerItemLink(bag, slot)
	if C_Container and C_Container.GetContainerItemLink then
		return C_Container.GetContainerItemLink(bag, slot)
	end
	if GetContainerItemLink then
		return GetContainerItemLink(bag, slot)
	end
end

local function HookLegacy()
	local function hook(tooltip, method, getLink)
		if not tooltip or not tooltip[method] then
			return
		end
		hooksecurefunc(tooltip, method, function(self, ...)
			HookCleared(self)
			local ok, link = pcall(getLink, ...)
			if ok then
				updateTooltip(self, link)
			end
		end)
	end

	hook(GameTooltip, "SetBagItem", ContainerItemLink)
	hook(GameTooltip, "SetInventoryItem", GetInventoryItemLink)
	hook(GameTooltip, "SetMerchantItem", GetMerchantItemLink)
	hook(GameTooltip, "SetBuybackItem", GetBuybackItemLink)
	hook(GameTooltip, "SetLootItem", GetLootSlotLink)
	hook(GameTooltip, "SetLootRollItem", GetLootRollItemLink)
	hook(GameTooltip, "SetQuestItem", GetQuestItemLink)
	hook(GameTooltip, "SetQuestLogItem", GetQuestLogItemLink)
	hook(GameTooltip, "SetInboxItem", GetInboxItemLink)
	hook(GameTooltip, "SetTradePlayerItem", GetTradePlayerItemLink)
	hook(GameTooltip, "SetTradeTargetItem", GetTradeTargetItemLink)
	hook(GameTooltip, "SetGuildBankItem", GetGuildBankItemLink)
	hook(GameTooltip, "SetHyperlink", function(itemString)
		local _, link = ItemInfo(itemString)
		return link or itemString
	end)
	if ItemRefTooltip then
		hook(ItemRefTooltip, "SetHyperlink", function(itemString)
			local _, link = ItemInfo(itemString)
			return link or itemString
		end)
	end
end

local hooked
local function InstallHooks()
	if hooked then
		return
	end
	hooked = true
	if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AttachItemTooltip)
	else
		HookLegacy()
	end
end

StaticPopupDialogs["AUCTIONWORTHY_MISSING_AUCTIONATOR"] = StaticPopupDialogs["AUCTIONWORTHY_MISSING_AUCTIONATOR"] or {
	text = "Auctionator is required for Auctionworthy-Forever. Install Auctionator and /reload.",
	button1 = OKAY or "Okay",
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function Auctionworthy:ADDON_LOADED(name)
	if name ~= ADDON_NAME then
		return
	end
	LoadOptions()
	InstallHooks()
	if not AuctionatorReady() then
		StaticPopup_Show("AUCTIONWORTHY_MISSING_AUCTIONATOR")
	end
end

local function openOptionsPanel()
	if AuctionworthyOptionsFrame then
		AuctionworthyOptionsFrame:Show()
		return
	end

	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "AuctionworthyOptionsFrame", UIParent, template)
	frame:SetSize(400, 350)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		frame:SetBackdropColor(0, 0, 0, 1)
	end
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	tinsert(UISpecialFrames, "AuctionworthyOptionsFrame")

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -10)
	title:SetText("Auctionworthy-Forever Settings")

	local info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	info:SetPoint("TOPLEFT", 20, -40)
	info:SetJustifyH("LEFT")
	info:SetWidth(360)
	info:SetText("Tooltip lines from Auctionator prices. Shift shows a full stack when that option is on.")

	local checkboxes = {
		{ label = "Show Auction Costs", key = "showAuctionCosts" },
		{ label = "Show Auction Price", key = "showAuctionPrice" },
		{ label = "Show Profit/Loss Options", key = "showProfitOptions" },
		{ label = "Show No Auction Data", key = "showNoAuctionData" },
		{ label = "Show Full Stack Calculations", key = "showFullStack" },
		{ label = "Show Decision Text", key = "showDecisionText" },
	}

	local yOffset = -100
	for i, checkbox in ipairs(checkboxes) do
		local cb = CreateFrame("CheckButton", "AuctionworthyOption" .. i, frame, "UICheckButtonTemplate")
		cb:SetPoint("TOPLEFT", 20, yOffset)
		local label = _G[cb:GetName() .. "Text"]
		label:SetFontObject(GameFontHighlight)
		label:SetText(checkbox.label)
		cb:SetChecked(options[checkbox.key] and true or false)
		cb:SetScript("OnClick", function(self)
			options[checkbox.key] = self:GetChecked() and true or false
			SaveOptions()
		end)
		yOffset = yOffset - 30
	end

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	closeButton:SetSize(100, 30)
	closeButton:SetPoint("BOTTOM", 0, 10)
	closeButton:SetText("Close")
	closeButton:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame:Show()
end

SLASH_AUCTIONWORTHY1 = "/auctionworthy"
SLASH_AUCTIONWORTHY2 = "/worthy"
SlashCmdList["AUCTIONWORTHY"] = openOptionsPanel
