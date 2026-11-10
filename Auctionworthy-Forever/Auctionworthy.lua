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
	applyUndercut = true,
	showUndercut = true,
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

-- Other-addon globals / SVs may be missing (Auctionator off, or first run before Auctionator.lua exists).
local function SafeGlobal(name)
	if type(name) ~= "string" or type(_G) ~= "table" then
		return nil
	end
	local ok, value = pcall(rawget, _G, name)
	if ok then
		return value
	end
end

local function AuctionatorAddon()
	local addon = SafeGlobal("Auctionator")
	if type(addon) == "table" then
		return addon
	end
end

local function AuctionatorReady()
	local addon = AuctionatorAddon()
	return addon
		and addon.API
		and addon.API.v1
		and addon.API.v1.GetAuctionPriceByItemLink
end

local function ValidAuctionPrice(price)
	return type(price) == "number" and price > 0 and not Secret(price)
end

local function getAuctionPrice(itemLink)
	if not AuctionatorReady() or type(itemLink) ~= "string" then
		return nil
	end
	local addon = AuctionatorAddon()
	if not addon then
		return nil
	end
	local ok, price = pcall(addon.API.v1.GetAuctionPriceByItemLink, CALLER_ID, itemLink)
	if ok and ValidAuctionPrice(price) then
		return price
	end
	return nil
end

-- Read-only copies from Auctionator.lua (AUCTIONATOR_CONFIG) / per-character
-- (AUCTIONATOR_CHARACTER_CONFIG). Never write those tables or call Config.Set.
local function CopyConfigValue(value)
	local t = type(value)
	if value == nil or Secret(value) then
		return nil
	end
	if t == "number" or t == "string" or t == "boolean" then
		return value
	end
end

local function ReadSavedKey(tbl, key)
	if type(tbl) ~= "table" or type(key) ~= "string" then
		return nil
	end
	local ok, value = pcall(function()
		return tbl[key]
	end)
	if ok then
		return CopyConfigValue(value)
	end
end

local function AuctionatorConfigValue(key)
	if type(key) ~= "string" then
		return nil
	end
	local addon = AuctionatorAddon()
	if addon and addon.Config and type(addon.Config.Get) == "function" then
		local ok, value = pcall(addon.Config.Get, key)
		if ok then
			value = CopyConfigValue(value)
			if value ~= nil then
				return value
			end
		end
	end
	local fromChar = ReadSavedKey(SafeGlobal("AUCTIONATOR_CHARACTER_CONFIG"), key)
	if fromChar ~= nil then
		return fromChar
	end
	return ReadSavedKey(SafeGlobal("AUCTIONATOR_CONFIG"), key)
end

local function formatUndercutCopper(copper)
	return formatGold(math.abs(tonumber(copper) or 0))
end

-- In-memory copy only. Never written back to Auctionator.lua.
local undercutSnap = {
	loaded = false,
	source = nil,
	preference = nil,
	percentage = nil,
	staticValue = nil,
}

local function AuctionatorLuaPresent()
	return type(SafeGlobal("AUCTIONATOR_CONFIG")) == "table"
		or type(SafeGlobal("AUCTIONATOR_CHARACTER_CONFIG")) == "table"
end

local function RefreshAuctionatorConfig(announce)
	undercutSnap.loaded = false
	undercutSnap.source = nil
	undercutSnap.preference = nil
	undercutSnap.percentage = nil
	undercutSnap.staticValue = nil

	if type(SafeGlobal("AUCTIONATOR_CHARACTER_CONFIG")) == "table" then
		undercutSnap.source = "character"
	elseif type(SafeGlobal("AUCTIONATOR_CONFIG")) == "table" then
		undercutSnap.source = "account"
	elseif AuctionatorAddon() then
		undercutSnap.source = "api"
	end

	local pref = AuctionatorConfigValue("auction_sales_preference")
	local pct = tonumber(AuctionatorConfigValue("undercut_percentage"))
	local static = tonumber(AuctionatorConfigValue("undercut_static_value"))
	if pref ~= nil or pct ~= nil or static ~= nil then
		undercutSnap.loaded = true
		undercutSnap.preference = pref
		undercutSnap.percentage = pct
		undercutSnap.staticValue = static
	end

	if announce then
		local prefix = "|cff00ff00Auctionworthy-Forever:|r "
		if not AuctionatorLuaPresent() and not AuctionatorReady() then
			print(prefix .. "Auctionator.lua not loaded yet. Enable Auctionator, then /worthy refresh.")
			return undercutSnap
		end
		if not undercutSnap.loaded then
			print(prefix .. "Auctionator.lua is loaded, but undercut settings were empty.")
			return undercutSnap
		end
		local src = "account"
		if undercutSnap.source == "character" then
			src = "character profile"
		elseif undercutSnap.source == "api" then
			src = "Auctionator API"
		end
		if undercutSnap.preference == "static" then
			print(prefix .. "Refreshed (" .. src .. "). Undercut: " .. formatUndercutCopper(undercutSnap.staticValue or 0))
		elseif undercutSnap.preference == "percentage" then
			print(prefix .. "Refreshed (" .. src .. "). Undercut: " .. (undercutSnap.percentage or 0) .. "%")
		else
			print(prefix .. "Refreshed (" .. src .. ").")
		end
	end
	return undercutSnap
end

local function UndercutSettings()
	if undercutSnap.loaded then
		return undercutSnap.preference, undercutSnap.percentage, undercutSnap.staticValue
	end
	return AuctionatorConfigValue("auction_sales_preference"),
		tonumber(AuctionatorConfigValue("undercut_percentage")),
		tonumber(AuctionatorConfigValue("undercut_static_value"))
end

-- Copper cheaper than the AH price: percent of AH, or the fixed copper value.
local function UndercutByCopper(marketUnit, stackCount)
	local pref, pct, static = UndercutSettings()
	stackCount = tonumber(stackCount) or 1
	if stackCount < 1 then
		stackCount = 1
	end
	local perItem = 0
	if pref == "static" then
		perItem = tonumber(static) or 0
	elseif pref == "percentage" and type(marketUnit) == "number" and marketUnit > 0 then
		perItem = math.floor(marketUnit * (tonumber(pct) or 0) / 100)
	else
		return 0, pref, pct, static
	end
	if perItem < 0 then
		perItem = 0
	end
	if type(marketUnit) == "number" and marketUnit > 1 then
		local maxCut = math.floor(marketUnit) - 1
		if perItem > maxCut then
			perItem = maxCut
		end
	end
	return math.floor(perItem * stackCount), pref, pct, static
end

local function ComputePosting(unitPrice)
	if type(unitPrice) ~= "number" then
		return unitPrice
	end
	local taken = UndercutByCopper(unitPrice, 1)
	local posting = math.floor(unitPrice) - (taken or 0)
	if posting < 1 then
		posting = 1
	end
	return posting
end

-- Static: Undercut 1c. Percent: Undercut 1%, 10s (AH * pct).
local function undercutLine(marketUnit, stackCount)
	local ok, line = pcall(function()
		local taken, pref, pct, static = UndercutByCopper(marketUnit, stackCount)
		if pref == "static" then
			return "Undercut: " .. formatUndercutCopper(static)
		end
		if pref == "percentage" then
			local setting = (pct or 0) .. "%"
			if type(marketUnit) == "number" and marketUnit > 0 then
				return "Undercut: " .. setting .. ", " .. formatUndercutCopper(taken or 0)
			end
			return "Undercut: " .. setting
		end
	end)
	if ok then
		return line
	end
end

local function applyUndercut(unitPrice)
	if not options.applyUndercut then
		return unitPrice
	end
	return ComputePosting(unitPrice)
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

local function StripTooltipCodes(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("|H.-|h%[(.-)%]|h", "%1")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("|n", " ")
	text = text:gsub("%s+", " ")
	return strtrim(text)
end

local function TooltipLeftTexts(tooltip)
	local texts = {}
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return texts
	end
	local tooltipName = tooltip.GetName and tooltip:GetName()
	if not tooltipName then
		return texts
	end
	local n = tooltip.NumLines and tooltip:NumLines() or 0
	for i = 1, n do
		local line = _G[tooltipName .. "TextLeft" .. i]
		local text = line and line.GetText and line:GetText()
		if type(text) == "string" and text ~= "" and not Secret(text) then
			texts[#texts + 1] = text
		end
	end
	return texts
end

local function IsWaylaidCrateName(name)
	return type(name) == "string" and name:find("Waylaid Crate", 1, true) and true or false
end

local function IsCrateFillStopLine(plain)
	if plain == "" then
		return false
	end
	if plain:find("^Requires ") or plain:find("^Item ?[Ll]evel") then
		return true
	end
	if plain:find("^Sell Price") or plain:find("^ItemID") then
		return true
	end
	if ITEM_SOULBOUND and plain == ITEM_SOULBOUND then
		return true
	end
	if ITEM_BIND_ON_PICKUP and plain == ITEM_BIND_ON_PICKUP then
		return true
	end
	if ITEM_BIND_QUEST and plain == ITEM_BIND_QUEST then
		return true
	end
	return false
end

local fillLinkCache = {}

local function RememberFillLink(name, link)
	if type(name) == "string" and type(link) == "string" and not Secret(link) then
		fillLinkCache[strlower(name)] = link
	end
	return link
end

local function ItemLinkFromID(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID < 1 then
		return nil
	end
	local _, link = ItemInfo(itemID)
	if type(link) == "string" and not Secret(link) then
		return link
	end
	return "item:" .. itemID
end

local function ItemIDFromName(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	if C_Item and C_Item.GetItemInfoInstant then
		local ok, id = pcall(C_Item.GetItemInfoInstant, name)
		id = tonumber(id)
		if ok and id and id > 0 then
			return id
		end
	end
	if GetItemInfoInstant then
		local ok, id = pcall(GetItemInfoInstant, name)
		id = tonumber(id)
		if ok and id and id > 0 then
			return id
		end
	end
	local _, link = ItemInfo(name)
	if type(link) == "string" then
		local id = tonumber(link:match("item:(%d+)"))
		if id and id > 0 then
			return id
		end
	end
end

local function ItemNameByID(itemID)
	if C_Item and C_Item.GetItemNameByID then
		local ok, itemName = pcall(C_Item.GetItemNameByID, itemID)
		if ok and type(itemName) == "string" and itemName ~= "" and not Secret(itemName) then
			return itemName
		end
	end
	local itemName = ItemInfo(itemID)
	if type(itemName) == "string" and itemName ~= "" then
		return itemName
	end
end

local function AuctionatorPriceDB()
	local addon = AuctionatorAddon()
	if addon and addon.Database and type(addon.Database.db) == "table" then
		return addon.Database.db
	end
end

local function FillMissingLinksFromAuctionator(missing)
	if not missing or not next(missing) then
		return
	end
	local db = AuctionatorPriceDB()
	if type(db) ~= "table" then
		return
	end
	local left = 0
	for _ in pairs(missing) do
		left = left + 1
	end
	for dbKey in pairs(db) do
		local id = tonumber(dbKey)
		if id then
			local itemName = ItemNameByID(id)
			if type(itemName) == "string" then
				local bundle = missing[strlower(itemName)]
				if bundle then
					bundle.link = RememberFillLink(bundle.name, ItemLinkFromID(id))
					missing[strlower(itemName)] = nil
					left = left - 1
					if left <= 0 then
						return
					end
				end
			end
		end
	end
end

local function LinkFromBags(name)
	local getSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
	local getLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
	if not getSlots or not getLink then
		return
	end
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, lastBag do
		local slots = getSlots(bag) or 0
		for slot = 1, slots do
			local ok, link = pcall(getLink, bag, slot)
			if ok and type(link) == "string" and not Secret(link) then
				local itemName = ItemInfo(link)
				if itemName == name then
					return RememberFillLink(name, link)
				end
			end
		end
	end
end

local function FillItemLink(name, itemID)
	if type(name) == "string" and fillLinkCache[strlower(name)] then
		return fillLinkCache[strlower(name)]
	end
	if itemID then
		local link = ItemLinkFromID(itemID)
		if link then
			return RememberFillLink(name, link)
		end
	end
	if type(name) ~= "string" or name == "" then
		return
	end
	local _, link = ItemInfo(name)
	if type(link) == "string" and not Secret(link) then
		return RememberFillLink(name, link)
	end
	local id = ItemIDFromName(name)
	if id then
		link = ItemLinkFromID(id)
		if link then
			return RememberFillLink(name, link)
		end
	end
	if Item and Item.CreateFromItemName then
		local ok, item = pcall(Item.CreateFromItemName, Item, name)
		if ok and item and not (item.IsItemEmpty and item:IsItemEmpty()) then
			if item.GetItemLink then
				local itemLink = item:GetItemLink()
				if type(itemLink) == "string" and not Secret(itemLink) then
					return RememberFillLink(name, itemLink)
				end
			end
			if item.GetItemID then
				link = ItemLinkFromID(item:GetItemID())
				if link then
					return RememberFillLink(name, link)
				end
			end
		end
	end
	return LinkFromBags(name)
end

local function ParseCrateFillBundles(blob)
	local bundles = {}
	if type(blob) ~= "string" or blob == "" then
		return bundles
	end
	local s = blob
	local listAt = s:lower():find("following list:")
	if listAt then
		s = s:sub(listAt):gsub("^[Ff]ollowing [Ll]ist:%s*", "")
	end
	for qty, name in s:gmatch("(%d+)%s*[xX]?%s+([^%d]+)") do
		name = strtrim(name:gsub("%s+%-%s*$", ""))
		qty = tonumber(qty)
		if qty and qty > 0 and name ~= "" and not name:lower():find("fill the crate", 1, true) then
			bundles[#bundles + 1] = {
				qty = qty,
				name = name,
			}
		end
	end
	return bundles
end

local function CrateFillBundles(tooltip)
	local parts = {}
	local capture = false
	local ids = {}
	for _, raw in ipairs(TooltipLeftTexts(tooltip)) do
		local plain = StripTooltipCodes(raw)
		if not capture then
			local lower = plain:lower()
			if lower:find("fill the crate", 1, true) or lower:find("following list", 1, true) then
				capture = true
				parts[#parts + 1] = plain
			end
		elseif IsCrateFillStopLine(plain) then
			break
		else
			parts[#parts + 1] = plain
		end
		if capture then
			for id in raw:gmatch("|Hitem:(%d+)") do
				id = tonumber(id)
				if id and id > 0 then
					ids[#ids + 1] = id
				end
			end
		end
	end
	local bundles = ParseCrateFillBundles(table.concat(parts, " "))
	if #ids == #bundles then
		for i, bundle in ipairs(bundles) do
			bundle.itemID = ids[i] or bundle.itemID
		end
	end
	return bundles
end

local function updateWaylaidCrateTooltip(tooltip)
	local bundles = CrateFillBundles(tooltip)
	if #bundles == 0 then
		return false
	end
	local added = false
	local missing = {}
	for _, bundle in ipairs(bundles) do
		bundle.link = FillItemLink(bundle.name, bundle.itemID)
		if not bundle.link then
			missing[strlower(bundle.name)] = bundle
		end
	end
	FillMissingLinksFromAuctionator(missing)
	for _, bundle in ipairs(bundles) do
		local unit = bundle.link and getAuctionPrice(bundle.link) or nil
		local label = bundle.qty .. "x " .. bundle.name .. ": "
		if unit then
			tooltip:AddLine(label .. formatGold(bundle.qty * unit))
			added = true
		elseif options.showNoAuctionData then
			tooltip:AddLine(label .. "No Auction Data", 1, 0, 1)
			added = true
		end
	end
	return added
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

	local name, _, _, _, _, _, _, stackSize, _, _, vendorPrice, _, _, bindType = ItemInfo(itemLink)
	local title = TooltipLeftTexts(tooltip)[1]
	if IsWaylaidCrateName(name) or IsWaylaidCrateName(title and StripTooltipCodes(title)) then
		if updateWaylaidCrateTooltip(tooltip) then
			tooltip.AuctionworthyAdded = true
			tooltip:Show()
		end
		return
	end

	if isSoulboundTooltip(tooltip) then
		return
	end

	if Secret(vendorPrice) or Secret(stackSize) or Secret(bindType) then
		return
	end
	if bindType == 1 or bindType == 4 then
		return
	end
	if not vendorPrice or vendorPrice <= 0 then
		return
	end

	local marketUnit = getAuctionPrice(itemLink)
	local auctionPrice = applyUndercut(marketUnit)
	local marketPrice = marketUnit
	stackSize = stackSize or 1

	local isFullStack = IsShiftKeyDown() and stackSize > 1 and options.showFullStack
	local auctionCosts = calculateAuctionCosts(vendorPrice)
	local stackMult = 1

	if isFullStack then
		stackMult = stackSize
		auctionCosts = auctionCosts * stackSize
		marketPrice = marketPrice and marketPrice * stackSize or nil
		auctionPrice = auctionPrice and auctionPrice * stackSize or nil
		vendorPrice = vendorPrice * stackSize
		tooltip:AddLine("|cFFFFA500Calculations for Full Stack (" .. stackSize .. "x)|r")
	end

	if auctionPrice then
		local profit = auctionPrice - auctionCosts
		if options.showAuctionCosts then
			tooltip:AddLine("Auction Costs: " .. formatGold(auctionCosts))
		end
		if options.showAuctionPrice then
			tooltip:AddLine("Auction Price: " .. formatGold(auctionPrice))
		end
		if profit > 0 then
			if options.showProfitOptions then
				tooltip:AddLine("Profit: " .. formatGold(profit), 0, 1, 0)
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
				tooltip:AddLine("Loss: " .. formatGold(-profit), 1, 0, 0)
			end
			if options.showDecisionText then
				tooltip:AddLine("Sell to vendor!", 1, 0, 0)
			end
		end
	elseif options.showNoAuctionData then
		tooltip:AddLine("No Auction Data", 1, 0, 1)
	end

	if options.showUndercut then
		local line = undercutLine(marketUnit, stackMult)
		if line then
			tooltip:AddLine(line, 0.65, 0.85, 1)
		end
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

local hookedOptionsFrames = {}
local lastOptionsRefresh = 0

local function OnAuctionatorOptionsClosed()
	local function run()
		local now = GetTime and GetTime() or 0
		if now - lastOptionsRefresh < 0.25 then
			return
		end
		lastOptionsRefresh = now
		-- After Auctionator's own OnHide Save() so we copy the new undercut.
		RefreshAuctionatorConfig(false)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		run()
	end
end

local function HookAuctionatorOptionsClose()
	local names = {
		"SettingsPanel",
		"InterfaceOptionsFrame",
		"AuctionatorConfigSellingAllItemsFrame",
		"AuctionatorConfigSellingFrame",
	}
	for _, name in ipairs(names) do
		if not hookedOptionsFrames[name] then
			local frame = SafeGlobal(name)
			if type(frame) == "table" and frame.HookScript then
				local ok = pcall(frame.HookScript, frame, "OnHide", OnAuctionatorOptionsClosed)
				if ok then
					hookedOptionsFrames[name] = true
				end
			end
		end
	end
end

function Auctionworthy:ADDON_LOADED(name)
	if name == ADDON_NAME then
		LoadOptions()
		InstallHooks()
		HookAuctionatorOptionsClose()
		RefreshAuctionatorConfig(false)
		return
	end
	if name == "Auctionator" then
		HookAuctionatorOptionsClose()
		RefreshAuctionatorConfig(false)
	end
end

function Auctionworthy:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	HookAuctionatorOptionsClose()
	RefreshAuctionatorConfig(false)
	if not AuctionatorReady() then
		print("|cffff7f00Auctionworthy-Forever:|r Auctionator is off. Prices stay empty until you enable it. /worthy refresh after it loads.")
	end
end
Auctionworthy:RegisterEvent("PLAYER_ENTERING_WORLD")

local function openOptionsPanel()
	if AuctionworthyOptionsFrame then
		AuctionworthyOptionsFrame:Show()
		return
	end

	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "AuctionworthyOptionsFrame", UIParent, template)
	frame:SetSize(400, 410)
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
	info:SetText("Tooltip lines from Auctionator prices. Shift shows a full stack when that option is on. /worthy refresh re-reads Auctionator settings.")

	local checkboxes = {
		{ label = "Show Auction Costs", key = "showAuctionCosts" },
		{ label = "Show Auction Price", key = "showAuctionPrice" },
		{ label = "Show Profit/Loss Options", key = "showProfitOptions" },
		{ label = "Show No Auction Data", key = "showNoAuctionData" },
		{ label = "Show Full Stack Calculations", key = "showFullStack" },
		{ label = "Show Decision Text", key = "showDecisionText" },
		{ label = "Apply Auctionator undercut", key = "applyUndercut" },
		{ label = "Show Undercut", key = "showUndercut" },
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
SlashCmdList["AUCTIONWORTHY"] = function(msg)
	msg = strlower(strtrim(tostring(msg or "")))
	if msg == "refresh" or msg == "reload" then
		RefreshAuctionatorConfig(true)
		return
	end
	if msg == "help" then
		print("|cff00ff00Auctionworthy-Forever:|r /worthy — options")
		print("  /worthy refresh — re-read Auctionator undercut (no /reload)")
		return
	end
	openOptionsPanel()
end
