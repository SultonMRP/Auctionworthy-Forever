-- Auctionworthy-Forever (Auctionator API v1).
-- /auctionworthy or /worthy

local ADDON_NAME = ...
local CALLER_ID = "Auctionworthy-Forever"

local Auctionworthy = CreateFrame("Frame")
_G.Auctionworthy = Auctionworthy
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
	worthyScanAt = 0,
	shareModifier = "ALT",
}

local SHARE_MODIFIERS = {
	{ key = "ALT", label = "Alt" },
	{ key = "SHIFT", label = "Shift" },
	{ key = "CTRL", label = "Ctrl" },
}

local options = {}

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

local tipState = setmetatable({}, { __mode = "k" })
local function TipState(tooltip)
	local s = tipState[tooltip]
	if not s then
		s = {}
		tipState[tooltip] = s
	end
	return s
end

local function OwnedByMinimap(tooltip)
	if not tooltip or not tooltip.GetOwner then
		return false
	end
	local frame = tooltip:GetOwner()
	for _ = 1, 10 do
		if not frame then
			return false
		end
		if frame == Minimap or frame == MinimapCluster then
			return true
		end
		local n = frame.GetName and frame:GetName()
		if type(n) == "string" and not Secret(n) and n:find("Minimap", 1, true) then
			return true
		end
		frame = frame.GetParent and frame:GetParent()
	end
	return false
end

local function RestoreItemWrap(tooltip)
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) or OwnedByMinimap(tooltip) then
		return
	end
	local name = tooltip.GetName and tooltip:GetName()
	if not name or Secret(name) then
		return
	end
	local n = tooltip.NumLines and tooltip:NumLines() or 0
	for i = 1, n do
		local fs = _G[name .. "TextLeft" .. i]
		if fs then
			fs:SetWordWrap(true)
			if fs.SetNonSpaceWrap then
				fs:SetNonSpaceWrap(true)
			end
			if fs.SetMaxLines then
				fs:SetMaxLines(8)
			end
		end
	end
end

local CRATE_QUERY_DEFAULT = "?"
local CRATE_QUERY_MAX = 16

local function StoredCrateQuery(text)
	if type(text) ~= "string" or Secret(text) then
		return nil
	end
	text = strtrim(text)
	if text == "" or text == CRATE_QUERY_DEFAULT then
		return nil
	end
	if #text > CRATE_QUERY_MAX then
		text = strtrim(text:sub(1, CRATE_QUERY_MAX))
		if text == "" or text == CRATE_QUERY_DEFAULT then
			return nil
		end
	end
	return text
end

local function CrateQueryPrefix()
	return StoredCrateQuery(options.crateQuery) or CRATE_QUERY_DEFAULT
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
	local shareOk = false
	for _, entry in ipairs(SHARE_MODIFIERS) do
		if options.shareModifier == entry.key then
			shareOk = true
			break
		end
	end
	if not shareOk then
		options.shareModifier = "ALT"
	end
	options.crateQuery = StoredCrateQuery(options.crateQuery)
end

local function ShareModifierLabel(key)
	for _, entry in ipairs(SHARE_MODIFIERS) do
		if entry.key == key then
			return entry.label
		end
	end
	return "Alt"
end

local function SaveOptions()
	AuctionworthySavedOptions = options
end

local fillIDs = {}

local function FillNameKey(name)
	if type(name) ~= "string" then
		return ""
	end
	return strlower(strtrim(name))
end

local function SameText(a, b)
	return FillNameKey(a) ~= "" and FillNameKey(a) == FillNameKey(b)
end

local function HasText(haystack, needle)
	if type(haystack) ~= "string" or type(needle) ~= "string" or needle == "" then
		return false
	end
	return strlower(haystack):find(strlower(needle), 1, true) and true or false
end

-- Database first. Saved ids are only names the database does not already have.
local function KnownFillID(name)
	local key = FillNameKey(name)
	if key == "" then
		return
	end
	local mats = AuctionworthyMaterialIDs
	local crates = AuctionworthyCrateIDs
	local id
	if type(mats) == "table" then
		id = tonumber(mats[key])
	end
	if (not id or id < 1) and type(crates) == "table" then
		id = tonumber(crates[key])
	end
	if id and id > 0 then
		return id
	end
end

local function LoadFillIDs()
	local saved = AuctionworthyFillIDs
	fillIDs = {}
	if type(saved) == "table" then
		for name, itemID in pairs(saved) do
			itemID = tonumber(itemID)
			local key = FillNameKey(name)
			if key ~= "" and itemID and itemID > 0 then
				fillIDs[key] = itemID
			end
		end
	end
	AuctionworthyFillIDs = fillIDs
end

local function ItemIDFromLink(link)
	if type(link) ~= "string" or Secret(link) then
		return nil
	end
	local id = tonumber(link:match("item:(%d+)"))
	if id and id > 0 then
		return id
	end
end

local function CacheFillID(name, itemID)
	itemID = tonumber(itemID)
	if type(name) ~= "string" or name == "" or not itemID or itemID < 1 then
		return itemID
	end
	local known = KnownFillID(name)
	if known then
		return known
	end
	fillIDs[FillNameKey(name)] = itemID
	AuctionworthyFillIDs = fillIDs
	return itemID
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

local function formatChatMoney(value)
	value = math.floor(tonumber(value) or 0)
	if value <= 0 then
		return "0c"
	end
	local gold = math.floor(value / 10000)
	local silver = math.floor((value % 10000) / 100)
	local copper = value % 100
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = gold .. "g"
	end
	if silver > 0 then
		parts[#parts + 1] = silver .. "s"
	end
	if copper > 0 or #parts == 0 then
		parts[#parts + 1] = copper .. "c"
	end
	return table.concat(parts, " ")
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

local function getAuctionPriceByItemID(itemID)
	itemID = tonumber(itemID)
	if not AuctionatorReady() or not itemID or itemID < 1 then
		return nil
	end
	local addon = AuctionatorAddon()
	if not addon or not addon.API.v1.GetAuctionPriceByItemID then
		return nil
	end
	local ok, price = pcall(addon.API.v1.GetAuctionPriceByItemID, CALLER_ID, itemID)
	if ok and ValidAuctionPrice(price) then
		return price
	end
	local db = addon.Database and addon.Database.db
	if type(db) == "table" then
		local row = db[tostring(itemID)] or db[itemID]
		if type(row) == "table" and ValidAuctionPrice(row.m) then
			return row.m
		end
	end
	return nil
end

local function getFillAuctionPrice(link, itemID)
	itemID = tonumber(itemID)
	if not itemID and type(link) == "string" then
		itemID = tonumber(link:match("item:(%d+)"))
	end
	local price = getAuctionPriceByItemID(itemID)
	if price then
		return price
	end
	return link and getAuctionPrice(link) or nil
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
	if not (C_Item and C_Item.GetItemInfo) then
		return
	end
	local ok, name, link, quality, ilvl, minLevel, itemType, subType, stackSize, equipLoc, texture, vendorPrice, classID, subclassID, bindType = pcall(C_Item.GetItemInfo, itemLink)
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
			if SameText(text, ITEM_SOULBOUND) or SameText(text, ITEM_BIND_ON_PICKUP) or SameText(text, ITEM_BIND_QUEST) then
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
	return type(name) == "string" and strlower(name):find("waylaid crate", 1, true) and true or false
end

local function IsCrateFillStopLine(plain)
	if type(plain) ~= "string" or plain == "" then
		return false
	end
	local lower = strlower(plain)
	if lower:find("^requires ") or lower:find("^item ?level") then
		return true
	end
	if lower:find("^%d+x .+%: ") then
		return true
	end
	if lower:find("^sell price") or lower:find("^itemid") then
		return true
	end
	if ITEM_SOULBOUND and lower == strlower(ITEM_SOULBOUND) then
		return true
	end
	if ITEM_BIND_ON_PICKUP and lower == strlower(ITEM_BIND_ON_PICKUP) then
		return true
	end
	if ITEM_BIND_QUEST and lower == strlower(ITEM_BIND_QUEST) then
		return true
	end
	return false
end

local function RememberFillLink(name, link)
	if type(link) == "string" and not Secret(link) then
		CacheFillID(name, ItemIDFromLink(link))
		return link
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
	local _, link = ItemInfo(name)
	if type(link) == "string" then
		local id = tonumber(link:match("item:(%d+)"))
		if id and id > 0 then
			return id
		end
	end
end

local function CachedFillID(name)
	if type(name) ~= "string" or name == "" then
		return
	end
	local key = FillNameKey(name)
	local id = tonumber(fillIDs[key])
	if not id or id < 1 then
		return
	end
	return id
end

-- Crate item id -> fill rows. Database recipes stay out of the saved variable.
local crateFills = {}

local function DatabaseCrateRecipe(crateID)
	local recipes = AuctionworthyCrateRecipes
	crateID = tonumber(crateID)
	if not crateID or type(recipes) ~= "table" then
		return
	end
	local rows = recipes[crateID]
	if type(rows) == "table" and rows[1] then
		return rows
	end
end

local function CopyFillRows(rows)
	local clean = {}
	if type(rows) ~= "table" then
		return clean
	end
	for _, row in ipairs(rows) do
		if type(row) == "table" then
			local qty = tonumber(row.qty)
			local name = row.name
			if qty and qty > 0 and type(name) == "string" and name ~= "" then
				local itemID = tonumber(row.itemID)
				if not itemID or itemID < 1 or KnownFillID(name) then
					itemID = nil
				end
				clean[#clean + 1] = {
					qty = qty,
					name = name,
					itemID = itemID,
				}
			end
		end
	end
	return clean
end

local function PersistSavedCrateFills()
	local saved = {}
	for crateID, rows in pairs(crateFills) do
		if not DatabaseCrateRecipe(crateID) and type(rows) == "table" and #rows > 0 then
			saved[crateID] = rows
		end
	end
	AuctionworthyCrateFills = saved
end

local function LoadCrateFills()
	crateFills = {}
	local saved = AuctionworthyCrateFills
	if type(saved) == "table" then
		for key, rows in pairs(saved) do
			local crateID = tonumber(key)
			if crateID and crateID > 0 and not DatabaseCrateRecipe(crateID) then
				local clean = CopyFillRows(rows)
				if #clean > 0 then
					crateFills[crateID] = clean
				end
			end
		end
	end
	local recipes = AuctionworthyCrateRecipes
	if type(recipes) == "table" then
		for crateID, rows in pairs(recipes) do
			local clean = CopyFillRows(rows)
			if #clean > 0 then
				crateFills[tonumber(crateID)] = clean
			end
		end
	end
	PersistSavedCrateFills()
end

-- Name to item id seen in the current Worthy Scan. Not saved until the name is a crate or a fill material.
local scanItemIDs = {}

local function ScanItemID(name)
	local id = tonumber(scanItemIDs[FillNameKey(name)])
	if id and id > 0 then
		return id
	end
end

local function IsFillMaterialName(name)
	if type(name) ~= "string" or IsWaylaidCrateName(name) then
		return false
	end
	if KnownFillID(name) then
		return true
	end
	local key = FillNameKey(name)
	if key == "" then
		return false
	end
	for _, rows in pairs(crateFills) do
		if type(rows) == "table" then
			for _, row in ipairs(rows) do
				if type(row) == "table" and FillNameKey(row.name) == key then
					return true
				end
			end
		end
	end
	return false
end

local function ApplyScannedMaterials()
	local saved = 0
	for _, rows in pairs(crateFills) do
		if type(rows) == "table" then
			for _, row in ipairs(rows) do
				if type(row) == "table" then
					local id = ScanItemID(row.name)
					if KnownFillID(row.name) then
						if row.itemID then
							row.itemID = nil
						end
					elseif id then
						if not row.itemID or row.itemID < 1 then
							row.itemID = id
						end
						if fillIDs[FillNameKey(row.name)] ~= id then
							CacheFillID(row.name, id)
							saved = saved + 1
						end
					end
				end
			end
		end
	end
	PersistSavedCrateFills()
	AuctionworthyFillIDs = fillIDs
	return saved
end

local function StoreCrateBundles(link, bundles)
	local crateID = ItemIDFromLink(link)
	if not crateID or type(bundles) ~= "table" or #bundles == 0 or DatabaseCrateRecipe(crateID) then
		return
	end
	local rows = {}
	for _, bundle in ipairs(bundles) do
		local qty = tonumber(bundle.qty)
		local name = bundle.name
		if qty and qty > 0 and type(name) == "string" and name ~= "" then
			local itemID = tonumber(bundle.itemID) or ScanItemID(name) or CachedFillID(name)
			if KnownFillID(name) then
				itemID = nil
			elseif itemID and itemID > 0 then
				CacheFillID(name, itemID)
			else
				itemID = nil
			end
			rows[#rows + 1] = {
				qty = qty,
				name = name,
				itemID = itemID,
			}
		end
	end
	if #rows == 0 then
		return
	end
	crateFills[crateID] = rows
	PersistSavedCrateFills()
end

local function PruneFillIDs()
	local wanted = {}
	local function keep(name)
		if type(name) == "string" and name ~= "" then
			wanted[FillNameKey(name)] = true
		end
	end
	for _, rows in pairs(crateFills) do
		if type(rows) == "table" then
			for _, row in ipairs(rows) do
				if type(row) == "table" then
					keep(row.name)
				end
			end
		end
	end
	local before = 0
	for _ in pairs(fillIDs) do
		before = before + 1
	end
	local cleaned = {}
	for name, itemID in pairs(fillIDs) do
		if not KnownFillID(name) and (wanted[name] or (type(name) == "string" and IsWaylaidCrateName(name))) then
			cleaned[name] = itemID
		end
	end
	fillIDs = cleaned
	AuctionworthyFillIDs = fillIDs
	local after = 0
	for _ in pairs(fillIDs) do
		after = after + 1
	end
	return before - after
end

-- Drop saved names the database already covers, and drop stored ids for those fills.
local function DropDatabaseAdditions()
	local removed = 0
	local cleaned = {}
	for name, itemID in pairs(fillIDs) do
		if KnownFillID(name) then
			removed = removed + 1
		else
			cleaned[name] = itemID
		end
	end
	fillIDs = cleaned
	AuctionworthyFillIDs = fillIDs
	local stripped = false
	for _, rows in pairs(crateFills) do
		if type(rows) == "table" then
			for _, row in ipairs(rows) do
				if type(row) == "table" and KnownFillID(row.name) and row.itemID then
					row.itemID = nil
					stripped = true
				end
			end
		end
	end
	if stripped then
		PersistSavedCrateFills()
	end
	return removed
end

local function CachedCrateBundles(link)
	local crateID = ItemIDFromLink(link)
	if not crateID then
		return
	end
	local rows = crateFills[crateID]
	if type(rows) ~= "table" then
		return
	end
	local bundles = {}
	for _, row in ipairs(rows) do
		local qty = tonumber(row.qty)
		local name = row.name
		if qty and qty > 0 and type(name) == "string" and name ~= "" then
			bundles[#bundles + 1] = {
				qty = qty,
				name = name,
				itemID = tonumber(row.itemID),
			}
		end
	end
	if #bundles > 0 then
		return bundles
	end
end

local function ScanRowNameAndID(row)
	if type(row) ~= "table" then
		return
	end
	local info = row.replicateInfo or row.auctionInfo
	local name, itemID
	if type(info) == "table" then
		if type(info[1]) == "string" and not Secret(info[1]) then
			name = info[1]
		end
		itemID = tonumber(info[17])
	end
	if type(row.itemName) == "string" and not Secret(row.itemName) then
		name = name or row.itemName
	end
	if type(row.itemKey) == "table" then
		itemID = itemID or tonumber(row.itemKey.itemID)
	end
	itemID = itemID or ItemIDFromLink(row.itemLink)
	if (not name or name == "") and type(row.itemLink) == "string" then
		local itemName = ItemInfo(row.itemLink)
		if type(itemName) == "string" then
			name = itemName
		end
	end
	if (not name or name == "") and itemID then
		if C_Item and C_Item.GetItemNameByID then
			local ok, itemName = pcall(C_Item.GetItemNameByID, itemID)
			if ok and type(itemName) == "string" then
				name = itemName
			end
		end
		if (not name or name == "") then
			local itemName = ItemInfo(itemID)
			if type(itemName) == "string" then
				name = itemName
			end
		end
	end
	if type(name) == "string" then
		name = strtrim(name)
	end
	if type(name) == "string" and name ~= "" and itemID and itemID > 0 then
		return name, itemID
	end
end

local worthyScan = {
	inProgress = false,
	processing = false,
	mode = nil,
	button = nil,
	index = 0,
	total = 0,
	stored = 0,
}
local FinishWorthyScan
local RestoreDefaultScanButtons
local SetWorthyScanButtonEnabled
local WorthyPrint

local pendingCrateIDs = {}
local ReadScannedCrateFills
local fillIndexTicker
local function IndexScanData(scanData, onDone)
	if type(scanData) ~= "table" then
		return
	end
	local rows = {}
	for _, row in ipairs(scanData) do
		rows[#rows + 1] = row
	end
	if #rows == 0 then
		if onDone then
			onDone()
		end
		return
	end
	if fillIndexTicker then
		fillIndexTicker:Cancel()
		fillIndexTicker = nil
	end
	local function take(row)
		local name, itemID = ScanRowNameAndID(row)
		if name and itemID then
			scanItemIDs[FillNameKey(name)] = itemID
			if IsWaylaidCrateName(name) or IsFillMaterialName(name) then
				CacheFillID(name, itemID)
			end
			if IsWaylaidCrateName(name) then
				pendingCrateIDs[itemID] = true
				if worthyScan and worthyScan.inProgress then
					worthyScan.stored = (worthyScan.stored or 0) + 1
				end
			end
		end
	end
	if not C_Timer or not C_Timer.NewTicker then
		for _, row in ipairs(rows) do
			take(row)
		end
		AuctionworthyFillIDs = fillIDs
		if onDone then
			onDone()
		end
		return
	end
	local i = 1
	fillIndexTicker = C_Timer.NewTicker(0, function()
		local stop = math.min(i + 400, #rows)
		for j = i, stop do
			take(rows[j])
		end
		i = stop + 1
		if i > #rows then
			fillIndexTicker:Cancel()
			fillIndexTicker = nil
			AuctionworthyFillIDs = fillIDs
			if onDone then
				onDone()
			end
		end
	end)
end

local auctionatorBusy = false
local SyncScanButtons

local RememberSearchPrices
local CaptureLoadedAuctionPrices

local scanHooked
local function HookAuctionatorScan()
	if scanHooked then
		return
	end
	local addon = AuctionatorAddon()
	if not addon or not addon.EventBus or type(addon.EventBus.Register) ~= "function" then
		return
	end
	local kind = {}
	local events = {}
	local function addGroup(group)
		if not group or not group.Events then
			return
		end
		if group.Events.ScanStart then
			kind[group.Events.ScanStart] = "start"
			events[#events + 1] = group.Events.ScanStart
		end
		if group.Events.ScanProgress then
			kind[group.Events.ScanProgress] = "progress"
			events[#events + 1] = group.Events.ScanProgress
		end
		if group.Events.ScanComplete then
			kind[group.Events.ScanComplete] = "done"
			events[#events + 1] = group.Events.ScanComplete
		end
		if group.Events.ScanFailed then
			kind[group.Events.ScanFailed] = "fail"
			events[#events + 1] = group.Events.ScanFailed
		end
	end
	addGroup(addon.FullScan)
	addGroup(addon.IncrementalScan)
	local searchEnd = addon.Shopping and addon.Shopping.Tab and addon.Shopping.Tab.Events and addon.Shopping.Tab.Events.SearchEnd
	if searchEnd then
		kind[searchEnd] = "prices"
		events[#events + 1] = searchEnd
	end
	if #events == 0 then
		return
	end
	local listener = {
		ReceiveEvent = function(_, event, data)
			local what = kind[event]
			if what == "start" then
				auctionatorBusy = true
			elseif what == "progress" then
				if worthyScan.inProgress then
					local pct = math.floor((tonumber(data) or 0) * 100 + 0.5)
					SetWorthyScanButtonEnabled(false, "Scan " .. pct .. "%")
				end
				return
			elseif what == "fail" then
				auctionatorBusy = false
				if worthyScan.inProgress then
					worthyScan.inProgress = false
					worthyScan.processing = false
					worthyScan.mode = nil
					RestoreDefaultScanButtons()
					WorthyPrint("Auctionator Full Scan failed.")
					return
				end
			elseif what == "prices" then
				if RememberSearchPrices then
					RememberSearchPrices(data)
				end
			elseif what == "done" then
				auctionatorBusy = false
				if CaptureLoadedAuctionPrices then
					CaptureLoadedAuctionPrices()
				end
				if worthyScan.inProgress then
					IndexScanData(data, FinishWorthyScan)
					return
				end
				IndexScanData(data)
			end
			if SyncScanButtons then
				SyncScanButtons()
			end
		end,
	}
	local ok = pcall(addon.EventBus.Register, addon.EventBus, listener, events)
	if ok then
		scanHooked = true
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
				if SameText(itemName, name) then
					return RememberFillLink(name, link)
				end
			end
		end
	end
end

local function FillItemLink(name, itemID)
	local id = KnownFillID(name) or tonumber(itemID) or CachedFillID(name)
	if id then
		if not KnownFillID(name) then
			CacheFillID(name, id)
		end
		return ItemLinkFromID(id)
	end
	if type(name) ~= "string" or name == "" then
		return
	end
	local _, link = ItemInfo(name)
	if type(link) == "string" and not Secret(link) then
		return RememberFillLink(name, link)
	end
	id = ItemIDFromName(name) or KnownFillID(name)
	if id then
		CacheFillID(name, id)
		return ItemLinkFromID(id)
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
	local bagLink = LinkFromBags(name)
	if bagLink then
		return bagLink
	end
	id = KnownFillID(name)
	if id then
		CacheFillID(name, id)
		return ItemLinkFromID(id)
	end
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

-- Names seen in Auctionator's price database or the current full-scan rows.
-- Not saved. Only a fill material that matches one of these is written to AuctionworthyFillIDs.
local auctionNames = {}
local pendingFillNames = {}
local nameLoadTried = {}
local heldNameItems = {}
local crateTip = { tooltip = nil, link = nil }
local nameWalk = { index = 1, keys = nil, rows = nil, rowIndex = 1, running = false }
local QueueCrateTooltipRefresh

local function AuctionatorPriceDB()
	local addon = AuctionatorAddon()
	local db = addon and addon.Database and addon.Database.db
	if type(db) == "table" then
		return db
	end
end

local function AuctionatorHasItem(itemID)
	itemID = tonumber(itemID)
	local db = AuctionatorPriceDB()
	if not itemID or type(db) ~= "table" then
		return false
	end
	local row = db[tostring(itemID)] or db[itemID]
	return type(row) == "table"
end

local function RememberAuctionName(name, itemID)
	itemID = tonumber(itemID)
	if type(name) ~= "string" or not itemID or itemID < 1 or Secret(name) then
		return
	end
	name = strtrim(name)
	local key = FillNameKey(name)
	if key == "" or auctionNames[key] then
		return
	end
	auctionNames[key] = itemID
end

local function CachedItemName(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID < 1 then
		return
	end
	if C_Item and C_Item.IsItemDataCachedByID then
		local ok, cached = pcall(C_Item.IsItemDataCachedByID, itemID)
		if not ok or not cached then
			return
		end
	elseif not (C_Item and C_Item.GetItemNameByID) then
		return
	end
	if C_Item and C_Item.GetItemNameByID then
		local ok, name = pcall(C_Item.GetItemNameByID, itemID)
		if ok and type(name) == "string" and name ~= "" and not Secret(name) then
			return name
		end
	end
	if C_Item and C_Item.IsItemDataCachedByID then
		local name = ItemInfo(itemID)
		if type(name) == "string" and name ~= "" and not Secret(name) then
			return name
		end
	end
end

local function AssignFillID(name, itemID)
	itemID = tonumber(itemID)
	local key = FillNameKey(name)
	if key == "" or not itemID or itemID < 1 then
		return
	end
	if KnownFillID(name) then
		pendingFillNames[key] = nil
		return
	end
	if not AuctionatorHasItem(itemID) then
		return
	end
	local changed = fillIDs[key] ~= itemID
	CacheFillID(name, itemID)
	for _, rows in pairs(crateFills) do
		if type(rows) == "table" then
			for _, row in ipairs(rows) do
				if type(row) == "table" and FillNameKey(row.name) == key and row.itemID ~= itemID then
					row.itemID = itemID
					changed = true
				end
			end
		end
	end
	if changed then
		PersistSavedCrateFills()
		pendingFillNames[key] = nil
		if QueueCrateTooltipRefresh then
			QueueCrateTooltipRefresh()
		end
	else
		pendingFillNames[key] = nil
	end
end

local function ClaimPendingName(name, itemID)
	local key = FillNameKey(name)
	if key == "" or not pendingFillNames[key] then
		return false
	end
	local before = fillIDs[key]
	AssignFillID(pendingFillNames[key], itemID)
	return fillIDs[key] ~= before
end

local function ScanRowPlainName(row)
	if type(row) ~= "table" then
		return
	end
	local info = row.replicateInfo or row.auctionInfo
	local name, itemID
	if type(info) == "table" then
		if type(info[1]) == "string" and not Secret(info[1]) then
			name = strtrim(info[1])
		end
		itemID = tonumber(info[17])
	end
	if (not name or name == "") and type(row.itemName) == "string" and not Secret(row.itemName) then
		name = strtrim(row.itemName)
	end
	if type(row.itemKey) == "table" then
		itemID = itemID or tonumber(row.itemKey.itemID)
	end
	itemID = itemID or ItemIDFromLink(row.itemLink)
	if name and name ~= "" and itemID and itemID > 0 then
		return name, itemID
	end
end

local function EnsureNameWalkLists()
	if nameWalk.keys then
		return true
	end
	local db = AuctionatorPriceDB()
	if type(db) ~= "table" then
		return false
	end
	local keys = {}
	for key, row in pairs(db) do
		if type(row) == "table" then
			local id = tonumber(key)
			if id and id > 0 then
				keys[#keys + 1] = id
			end
		end
	end
	local rows = {}
	local frame = SafeGlobal("AuctionatorFullScanFrame")
	local data = frame and frame.scanData
	if type(data) == "table" then
		for _, row in pairs(data) do
			rows[#rows + 1] = row
		end
	end
	nameWalk.keys = keys
	nameWalk.rows = rows
	nameWalk.index = 1
	nameWalk.rowIndex = 1
	return true
end

local function StartAuctionatorNameWalk()
	if nameWalk.running or not next(pendingFillNames) then
		return
	end
	if not EnsureNameWalkLists() then
		return
	end
	if nameWalk.rowIndex > #nameWalk.rows and nameWalk.index > #nameWalk.keys then
		for key in pairs(pendingFillNames) do
			pendingFillNames[key] = nil
		end
		return
	end
	nameWalk.running = true
	local function step()
		if not next(pendingFillNames) then
			nameWalk.running = false
			return
		end
		local found = false
		local rows = nameWalk.rows
		if nameWalk.rowIndex <= #rows then
			local stop = math.min(nameWalk.rowIndex + 400, #rows)
			for i = nameWalk.rowIndex, stop do
				local name, itemID = ScanRowPlainName(rows[i])
				if name and itemID then
					RememberAuctionName(name, itemID)
					if ClaimPendingName(name, itemID) then
						found = true
					end
				end
			end
			nameWalk.rowIndex = stop + 1
		else
			local keys = nameWalk.keys
			local stop = math.min(nameWalk.index + 400, #keys)
			for i = nameWalk.index, stop do
				local itemID = keys[i]
				local name = CachedItemName(itemID)
				if name then
					RememberAuctionName(name, itemID)
					if ClaimPendingName(name, itemID) then
						found = true
					end
				end
			end
			nameWalk.index = stop + 1
			if nameWalk.index > #keys then
				for key in pairs(pendingFillNames) do
					pendingFillNames[key] = nil
				end
			end
		end
		if found and QueueCrateTooltipRefresh then
			QueueCrateTooltipRefresh()
		end
		if next(pendingFillNames) and (nameWalk.rowIndex <= #nameWalk.rows or nameWalk.index <= #nameWalk.keys) then
			if C_Timer and C_Timer.After then
				C_Timer.After(0, step)
			else
				nameWalk.running = false
			end
		else
			nameWalk.running = false
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, step)
	else
		nameWalk.running = false
	end
end

local function RequestFillName(name)
	local key = FillNameKey(name)
	if key == "" or nameLoadTried[key] or not pendingFillNames[key] then
		return
	end
	nameLoadTried[key] = true
	if not Item or not Item.CreateFromItemName then
		return
	end
	local ok, item = pcall(Item.CreateFromItemName, Item, name)
	if not ok or not item or (item.IsItemEmpty and item:IsItemEmpty()) then
		return
	end
	if not item.ContinueOnItemLoad then
		local id = item.GetItemID and tonumber(item:GetItemID())
		if id then
			AssignFillID(name, id)
		end
		return
	end
	heldNameItems[key] = item
	item:ContinueOnItemLoad(function()
		local held = heldNameItems[key]
		heldNameItems[key] = nil
		local id = held and held.GetItemID and tonumber(held:GetItemID())
		if id then
			AssignFillID(name, id)
		end
	end)
end

-- Cheapest unit price seen on the auctions currently loaded in the house.
-- Auctionator's saved price database can miss an item that is sitting on the AH.
local liveUnit = {}

local function NoteLivePrice(name, itemID, unitPrice, quiet)
	if type(name) ~= "string" then
		return false
	end
	name = StripTooltipCodes(name)
	local key = FillNameKey(name)
	if key == "" then
		return false
	end
	local changed = false
	unitPrice = tonumber(unitPrice)
	if unitPrice and unitPrice > 0 then
		unitPrice = math.floor(unitPrice)
		if not liveUnit[key] or unitPrice < liveUnit[key] then
			liveUnit[key] = unitPrice
			if pendingFillNames[key] then
				changed = true
			end
		end
	end
	itemID = tonumber(itemID)
	if itemID and itemID > 0 and pendingFillNames[key] and not KnownFillID(name) and fillIDs[key] ~= itemID then
		CacheFillID(pendingFillNames[key], itemID)
		for _, rows in pairs(crateFills) do
			if type(rows) == "table" then
				for _, row in ipairs(rows) do
					if type(row) == "table" and FillNameKey(row.name) == key then
						row.itemID = itemID
					end
				end
			end
		end
		PersistSavedCrateFills()
		changed = true
	end
	if liveUnit[key] then
		pendingFillNames[key] = nil
	end
	if changed and not quiet and QueueCrateTooltipRefresh then
		QueueCrateTooltipRefresh()
	end
	return changed
end

local function UnitFromCounts(buyout, count)
	buyout = tonumber(buyout)
	count = tonumber(count) or 1
	if not buyout or buyout <= 0 then
		return nil
	end
	if count < 1 then
		count = 1
	end
	return math.floor(buyout / count)
end

local function HarvestShoppingPrices(quiet)
	local frame = SafeGlobal("AuctionatorShoppingFrame")
	local results = frame and frame.DataProvider and frame.DataProvider.results
	if type(results) ~= "table" then
		return
	end
	for _, entry in ipairs(results) do
		if type(entry) == "table" then
			local name = entry.name
			if type(name) ~= "string" or name == "" then
				local info = entry.entries and entry.entries[1] and entry.entries[1].info
				if type(info) == "table" then
					name = info[1]
				end
			end
			if type(name) == "string" then
				name = StripTooltipCodes(name)
				local itemID = ItemIDFromLink(entry.itemLink) or ItemIDFromLink(entry.itemString)
				NoteLivePrice(name, itemID, entry.minPrice, quiet)
			end
		end
	end
end

local function ReadLoadedAuction(view, index, quiet)
	if not GetAuctionItemInfo then
		return
	end
	local ok, name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = pcall(GetAuctionItemInfo, view, index)
	if not ok or type(name) ~= "string" or name == "" or Secret(name) then
		return
	end
	if (not itemID or itemID == 0) and GetAuctionItemLink then
		local linkOK, link = pcall(GetAuctionItemLink, view, index)
		if linkOK then
			itemID = ItemIDFromLink(link)
		end
	end
	NoteLivePrice(name, itemID, UnitFromCounts(buyout, count), quiet)
end

local listWalk = { index = 0, last = -1, running = false }

local function AuctionListBounds()
	if not GetNumAuctionItems or not GetAuctionItemInfo then
		return nil
	end
	local batch = tonumber(GetNumAuctionItems("list")) or 0
	if batch < 1 then
		return nil
	end
	local ok, name = pcall(GetAuctionItemInfo, "list", 0)
	if ok and type(name) == "string" and name ~= "" then
		return 0, batch - 1
	end
	return 1, batch
end

local function HarvestLoadedAuctions(quiet, limit)
	HarvestShoppingPrices(quiet)
	local first, last = AuctionListBounds()
	if not first then
		return
	end
	local stop = last
	if limit then
		stop = math.min(last, first + limit - 1)
	end
	for index = first, stop do
		ReadLoadedAuction("list", index, quiet)
	end
	if stop < last then
		listWalk.index = stop + 1
		listWalk.last = last
	else
		listWalk.index = last + 1
		listWalk.last = last
	end
end

local function StartLoadedAuctionWalk()
	if listWalk.running or not next(pendingFillNames) then
		return
	end
	local _, last = AuctionListBounds()
	if not last or listWalk.index > last then
		return
	end
	listWalk.last = last
	listWalk.running = true
	local function step()
		if not next(pendingFillNames) or listWalk.index > listWalk.last then
			listWalk.running = false
			return
		end
		local stop = math.min(listWalk.last, listWalk.index + 400)
		for index = listWalk.index, stop do
			ReadLoadedAuction("list", index, false)
		end
		listWalk.index = stop + 1
		if next(pendingFillNames) and listWalk.index <= listWalk.last and C_Timer and C_Timer.After then
			C_Timer.After(0, step)
		else
			listWalk.running = false
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, step)
	else
		listWalk.running = false
	end
end

local function NoteUnresolvedFill(name)
	local key = FillNameKey(name)
	if key == "" or pendingFillNames[key] then
		return
	end
	local known = KnownFillID(name) or tonumber(fillIDs[key]) or auctionNames[key] or ScanItemID(name)
	if known and (getAuctionPriceByItemID(known) or AuctionatorHasItem(known)) then
		if not KnownFillID(name) and fillIDs[key] ~= known then
			AssignFillID(name, known)
		end
		return
	end
	pendingFillNames[key] = name
	RequestFillName(name)
end

local function updateWaylaidCrateTooltip(tooltip, itemLink)
	local bundles = CrateFillBundles(tooltip)
	if #bundles == 0 then
		return false
	end
	local added = false
	for _, bundle in ipairs(bundles) do
		local id = KnownFillID(bundle.name) or CachedFillID(bundle.name) or tonumber(bundle.itemID) or auctionNames[FillNameKey(bundle.name)] or ScanItemID(bundle.name)
		if id and id > 0 then
			bundle.itemID = id
		end
		local link = FillItemLink(bundle.name, bundle.itemID)
		bundle.itemID = tonumber(bundle.itemID) or ItemIDFromLink(link)
		local unit = getFillAuctionPrice(link, bundle.itemID) or liveUnit[FillNameKey(bundle.name)]
		if not unit then
			NoteUnresolvedFill(bundle.name)
			local found = KnownFillID(bundle.name) or CachedFillID(bundle.name) or auctionNames[FillNameKey(bundle.name)]
			if found and found ~= bundle.itemID then
				bundle.itemID = found
				link = FillItemLink(bundle.name, found)
				unit = getFillAuctionPrice(link, bundle.itemID)
			end
			if not unit and next(pendingFillNames) then
				HarvestLoadedAuctions(true, 500)
				unit = liveUnit[FillNameKey(bundle.name)]
				if unit then
					bundle.itemID = bundle.itemID or CachedFillID(bundle.name)
				end
			end
		end
		local label = bundle.qty .. "x " .. bundle.name .. ": "
		if unit then
			tooltip:AddLine(label .. formatGold(bundle.qty * unit), 1, 0.82, 0, true)
			added = true
		elseif options.showNoAuctionData then
			tooltip:AddLine(label .. "No Auction Data", 1, 0, 1, true)
			added = true
		end
	end
	if itemLink then
		StoreCrateBundles(itemLink, bundles)
		crateTip.tooltip = tooltip
		crateTip.link = itemLink
	end
	if next(pendingFillNames) then
		StartAuctionatorNameWalk()
		StartLoadedAuctionWalk()
	end
	return added
end

local function AddCrateSectionDivider(tooltip)
	tooltip:AddLine("-= empty crate auction values =-", 0.55, 0.55, 0.58, true)
end

local function updateAuctionSellTooltip(tooltip, itemLink, emptyCrate, afterFill)
	local _, _, _, _, _, _, _, stackSize, _, _, vendorPrice, _, _, bindType = ItemInfo(itemLink)
	if isSoulboundTooltip(tooltip) then
		return false
	end
	if not emptyCrate then
		if Secret(vendorPrice) or Secret(stackSize) or Secret(bindType) then
			return false
		end
		if bindType == 1 or bindType == 4 then
			return false
		end
		if not vendorPrice or vendorPrice <= 0 then
			return false
		end
	elseif Secret(vendorPrice) then
		vendorPrice = 0
	end
	vendorPrice = tonumber(vendorPrice) or 0

	if emptyCrate and afterFill then
		AddCrateSectionDivider(tooltip)
	end

	local marketUnit = emptyCrate and getFillAuctionPrice(itemLink, ItemIDFromLink(itemLink)) or getAuctionPrice(itemLink)
	local auctionPrice = applyUndercut(marketUnit)
	local marketPrice = marketUnit

	local function CurrentStackCount(tip)
		if not tip or not tip.GetOwner then
			return
		end
		local owner = tip:GetOwner()
		if not owner or Secret(owner) then
			return
		end
		local shown = owner.itemInfo
		if type(shown) == "table" then
			local count = shown.itemCount
			if not Secret(count) then
				count = tonumber(count)
				if count and count > 0 then
					return count
				end
			end
		end
		local slot
		if owner.GetID then
			slot = owner:GetID()
		end
		if Secret(slot) then
			return
		end
		slot = tonumber(slot)
		if not slot or slot < 1 then
			return
		end
		local ownerName
		if owner.GetName then
			ownerName = owner:GetName()
		end
		if type(ownerName) == "string" and not Secret(ownerName) and ownerName:find("GuildBank", 1, true) and GetGuildBankItemInfo and GetCurrentGuildBankTab then
			local tab = GetCurrentGuildBankTab()
			if not Secret(tab) and tab then
				local _, count = GetGuildBankItemInfo(tab, slot)
				if not Secret(count) then
					count = tonumber(count)
					if count and count > 0 then
						return count
					end
				end
			end
			return
		end
		local bag
		if owner.GetBagID then
			bag = owner:GetBagID()
		end
		if bag == nil and owner.GetParent then
			local parent = owner:GetParent()
			if parent and parent.GetID then
				bag = parent:GetID()
			end
		end
		if Secret(bag) or bag == nil then
			return
		end
		bag = tonumber(bag)
		if bag == nil then
			return
		end
		if C_Container and C_Container.GetContainerItemInfo then
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if type(info) == "table" then
				local count = info.stackCount
				if not Secret(count) then
					count = tonumber(count)
					if count and count > 0 then
						return count
					end
				end
			end
		end
		if GetContainerItemInfo then
			local _, count = GetContainerItemInfo(bag, slot)
			if not Secret(count) then
				count = tonumber(count)
				if count and count > 0 then
					return count
				end
			end
		end
	end

	local shiftDown = IsShiftKeyDown and IsShiftKeyDown()
	local stackCount = 1
	if not Secret(shiftDown) and shiftDown and options.showFullStack then
		local current = CurrentStackCount(tooltip)
		if current and current > 1 then
			stackCount = current
		end
	end
	local auctionCosts = calculateAuctionCosts(vendorPrice)
	if stackCount > 1 then
		auctionCosts = auctionCosts * stackCount
		marketPrice = marketPrice and marketPrice * stackCount or nil
		auctionPrice = auctionPrice and auctionPrice * stackCount or nil
		vendorPrice = vendorPrice * stackCount
	end

	local stackNote = ""
	if stackCount > 1 then
		stackNote = " (x" .. stackCount .. ")"
	end

	if auctionPrice then
		local profit = auctionPrice - auctionCosts
		if options.showAuctionCosts then
			tooltip:AddLine("Auction Costs: " .. formatGold(auctionCosts), 1, 0.82, 0, true)
		end
		if options.showAuctionPrice then
			tooltip:AddLine("Auction Price: " .. formatGold(auctionPrice), 1, 0.82, 0, true)
		end
		if profit > 0 then
			if options.showProfitOptions then
				tooltip:AddLine("Profit: " .. formatGold(profit) .. stackNote, 0, 1, 0, true)
			end
			if options.showDecisionText then
				tooltip:AddLine("Auction it!", 0, 1, 0, true)
			end
		else
			if options.showProfitOptions then
				tooltip:AddLine("Loss: " .. formatGold(-profit) .. stackNote, 1, 0, 0, true)
			end
			if options.showDecisionText then
				tooltip:AddLine("Sell to vendor!", 1, 0, 0, true)
			end
		end
	elseif options.showNoAuctionData then
		tooltip:AddLine("No Auction Data", 1, 0, 1, true)
	end

	if options.showUndercut then
		local line = undercutLine(marketUnit, stackCount)
		if line then
			tooltip:AddLine(line, 0.65, 0.85, 1, true)
		end
	end

	return true
end

local function GetLinkFromTooltip(tooltip, data)
	if data then
		if type(data.hyperlink) == "string" and not Secret(data.hyperlink) then
			return data.hyperlink
		end
		if data.guid and not Secret(data.guid) and C_Item and C_Item.GetItemLinkByGUID then
			local ok, link = pcall(C_Item.GetItemLinkByGUID, data.guid)
			if ok and type(link) == "string" then
				return link
			end
		end
		if not Secret(data.id) then
			local id = tonumber(data.id)
			if id and id > 0 then
				local link = ItemLinkFromID(id)
				if type(link) == "string" then
					return link
				end
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
	if tooltip and tooltip.AuctionworthySkip then
		if tooltip.AuctionworthyOnShare and (tooltip.NumLines and tooltip:NumLines() or 0) > 0 then
			tooltip.AuctionworthyOnShare()
		end
		return
	end
	if not tooltip or not itemLink or Secret(itemLink) then
		return
	end
	if tooltip.IsForbidden and tooltip:IsForbidden() then
		return
	end
	if OwnedByMinimap(tooltip) then
		return
	end
	local st = TipState(tooltip)
	if st.added or st.busy then
		return
	end

	local name = ItemInfo(itemLink)
	local title = TooltipLeftTexts(tooltip)[1]
	local emptyCrate = IsWaylaidCrateName(name) or IsWaylaidCrateName(title and StripTooltipCodes(title))
	local added = false
	if emptyCrate then
		st.busy = true
		local ok, crateAdded = pcall(updateWaylaidCrateTooltip, tooltip, itemLink)
		added = ok and crateAdded
		st.busy = nil
	end
	local ok, sellAdded = pcall(updateAuctionSellTooltip, tooltip, itemLink, emptyCrate, added)
	if added or (ok and sellAdded) then
		st.added = true
		RestoreItemWrap(tooltip)
		-- Forever: do not GameTooltip:Show from a tooltip post-call (clips Equip/Use).
	end
end

local function HookCleared(tooltip)
	if not tooltip then
		return
	end
	local st = TipState(tooltip)
	if st.clearedHook then
		return
	end
	st.clearedHook = true
	tooltip:HookScript("OnTooltipCleared", function(self)
		local flags = TipState(self)
		if flags.busy then
			return
		end
		flags.added = nil
	end)
	tooltip:HookScript("OnShow", function(self)
		if TipState(self).added then
			RestoreItemWrap(self)
		end
	end)
end

local function ShownTooltipItemID(tooltip)
	if tooltip and tooltip.GetItem then
		local ok, _, link = pcall(tooltip.GetItem, tooltip)
		if ok then
			return ItemIDFromLink(link)
		end
	end
end

QueueCrateTooltipRefresh = function()
	if crateTip.refreshQueued or not crateTip.link then
		return
	end
	crateTip.refreshQueued = true
	local function run()
		crateTip.refreshQueued = nil
		local tooltip = crateTip.tooltip
		local link = crateTip.link
		if not tooltip or not link or not tooltip.IsShown or not tooltip:IsShown() then
			return
		end
		if not tooltip.SetHyperlink or (tooltip.IsForbidden and tooltip:IsForbidden()) then
			return
		end
		local shownID = ShownTooltipItemID(tooltip)
		local wantID = ItemIDFromLink(link)
		if shownID and wantID and shownID ~= wantID then
			return
		end
		TipState(tooltip).added = nil
		pcall(tooltip.SetHyperlink, tooltip, link)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, run)
	else
		crateTip.refreshQueued = nil
	end
end

local function AttachItemTooltip(tooltip, data)
	HookCleared(tooltip)
	updateTooltip(tooltip, GetLinkFromTooltip(tooltip, data))
end

local function ContainerItemLink(bag, slot)
	if C_Container and C_Container.GetContainerItemLink then
		return C_Container.GetContainerItemLink(bag, slot)
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

local function ShareModifierDown()
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	local key = options.shareModifier
	if key == "SHIFT" then
		return IsShiftKeyDown()
	end
	if key == "CTRL" then
		return IsControlKeyDown()
	end
	return IsAltKeyDown()
end

local function ShareChannel()
	if IsInRaid and IsInRaid() then
		return "RAID"
	end
	if UnitInRaid and UnitInRaid("player") then
		return "RAID"
	end
	if GetNumRaidMembers and GetNumRaidMembers() > 0 then
		return "RAID"
	end
	if IsInGroup and IsInGroup() then
		return "PARTY"
	end
	if GetNumSubgroupMembers and GetNumSubgroupMembers() > 0 then
		return "PARTY"
	end
	if GetNumPartyMembers and GetNumPartyMembers() > 0 then
		return "PARTY"
	end
	if GetNumGroupMembers and GetNumGroupMembers() > 0 then
		return "PARTY"
	end
	return "SAY"
end

local IsLocalPlayer

local function ClickDebug(text)
	if Auctionworthy.ReportClick then
		Auctionworthy:ReportClick(text)
	end
end

-- This client does not deliver a whisper addressed to you. Show it in the whisper window anyway.
local function ShowSelfWhisper(text, who)
	local shown = false
	if type(ChatFrame_MessageEventHandler) == "function" then
		local n = NUM_CHAT_WINDOWS or 10
		for i = 1, n do
			local frame = _G["ChatFrame" .. i]
			if frame and frame.IsEventRegistered and frame:IsEventRegistered("CHAT_MSG_WHISPER") then
				local ok = pcall(ChatFrame_MessageEventHandler, frame, "CHAT_MSG_WHISPER", text, who, "", "", who, "", 0, 0, "", 0, 0, UnitGUID and UnitGUID("player"))
				if ok then
					shown = true
				end
			end
		end
	end
	if shown then
		return
	end
	local info = ChatTypeInfo and ChatTypeInfo.WHISPER
	local r, g, b = 1, 0.502, 1
	if type(info) == "table" then
		r, g, b = info.r or r, info.g or g, info.b or b
	end
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(who .. " whispers: " .. text, r, g, b)
	else
		print(who .. " whispers: " .. text)
	end
end

local function SendShareLine(text, channel, target)
	if type(text) ~= "string" or text == "" or Secret(text) then
		return
	end
	if channel == "WHISPER" and (type(target) ~= "string" or target == "" or Secret(target)) then
		return
	end
	if channel == "WHISPER" and IsLocalPlayer and IsLocalPlayer(target) then
		ClickDebug("own whisper")
		ShowSelfWhisper(text, target)
		return
	end
	ClickDebug("send " .. tostring(channel) .. " " .. tostring(target))
	-- Direct call, and not from inside pcall. This client blocks the send otherwise.
	-- Whispers go through SendChatMessage. That is the call other addons on this client use.
	if channel == "WHISPER" and SendChatMessage then
		SendChatMessage(text, "WHISPER", nil, target)
		return
	end
	if C_ChatInfo and C_ChatInfo.SendChatMessage then
		if channel == "WHISPER" then
			C_ChatInfo.SendChatMessage(text, channel, nil, target)
		else
			C_ChatInfo.SendChatMessage(text, channel)
		end
		return
	end
	if SendChatMessage then
		SendChatMessage(text, channel)
	end
end

-- Item links seen in whisper or guild. Key-click on that line whispers the sender.
local whisperedItems = {}
local guildItems = {}

local function RememberLinkedSender(store, message, sender)
	if type(message) ~= "string" or type(sender) ~= "string" then
		return
	end
	if message == "" or sender == "" or Secret(message) or Secret(sender) then
		return
	end
	local found = false
	for itemID in message:gmatch("item:(%d+)") do
		itemID = tonumber(itemID)
		if itemID and itemID > 0 then
			found = true
			store[#store + 1] = {
				itemID = itemID,
				sender = sender,
			}
		end
	end
	if not found then
		return
	end
	while #store > 40 do
		table.remove(store, 1)
	end
end

local function RememberWhisperItem(message, sender)
	RememberLinkedSender(whisperedItems, message, sender)
end

local function RememberGuildItem(message, sender)
	RememberLinkedSender(guildItems, message, sender)
end

-- Prat rewrites the visible line ([G] [26:Name]). Keep the channel and sender it already parsed.
local pratPosts = {}

local function RememberPratMessage(message)
	if type(message) ~= "table" then
		return
	end
	local channel = message.CHATGROUP or message.CHATTYPE
	if type(channel) ~= "string" or Secret(channel) then
		return
	end
	channel = strupper(channel)
	if channel ~= "GUILD" and channel ~= "WHISPER" then
		return
	end
	local sender = message.PLAYERLINK
	if type(sender) ~= "string" or sender == "" or Secret(sender) then
		sender = message.PLAYER
	end
	local body = message.MESSAGE
	if type(sender) ~= "string" or sender == "" or Secret(sender) or type(body) ~= "string" or Secret(body) then
		return
	end
	local found = false
	for itemID in body:gmatch("item:(%d+)") do
		itemID = tonumber(itemID)
		if itemID and itemID > 0 then
			found = true
			pratPosts[#pratPosts + 1] = {
				channel = channel,
				sender = sender,
				itemID = itemID,
			}
		end
	end
	if not found then
		return
	end
	while #pratPosts > 40 do
		table.remove(pratPosts, 1)
	end
end

local pratListener = {}
function pratListener:Prat_PostAddMessage(_, message)
	RememberPratMessage(message)
end

local pratHooked
local function HookPratMessages()
	if pratHooked then
		return
	end
	local prat = _G.Prat
	if not prat or type(prat.RegisterChatEvent) ~= "function" then
		return
	end
	prat.RegisterChatEvent(pratListener, "Prat_PostAddMessage")
	pratHooked = true
end

-- These stay local to this block so the file stays under Lua's 200-local limit.
local FullChatLine, ClassifyLine
do
local function LineLooksLikeChannel(line, channel)
	if type(line) ~= "string" then
		return false
	end
	if channel == "GUILD" then
		return HasText(line, ":GUILD") or HasText(line, "[G]") or HasText(line, "[Guild]")
	end
	if channel == "WHISPER" then
		if HasText(line, "[W To]") or HasText(line, ":WHISPER_INFORM") then
			return false
		end
		return HasText(line, ":WHISPER") or HasText(line, "[W From]") or HasText(line, "whispers:")
	end
	return false
end

local function PratOwner(link, line)
	local itemID = ItemIDFromLink(link)
	if not itemID then
		return
	end
	local hinted
	if LineLooksLikeChannel(line, "GUILD") then
		hinted = "GUILD"
	elseif LineLooksLikeChannel(line, "WHISPER") then
		hinted = "WHISPER"
	elseif line then
		return
	end
	for i = #pratPosts, 1, -1 do
		local row = pratPosts[i]
		if row.itemID == itemID and (not hinted or row.channel == hinted) then
			return row.sender, hinted or row.channel
		end
	end
end

local function NamesMatch(stored, hint)
	stored = strlower(stored)
	hint = strlower(hint)
	if stored == hint then
		return true
	end
	if stored:find(hint .. "-", 1, true) == 1 then
		return true
	end
	if hint:find(stored .. "-", 1, true) == 1 then
		return true
	end
	return false
end

local function RecentLinkedSender(store, link, nameHint)
	local itemID = ItemIDFromLink(link)
	if not itemID then
		return nameHint
	end
	for i = #store, 1, -1 do
		local row = store[i]
		if row.itemID == itemID and (not nameHint or NamesMatch(row.sender, nameHint)) then
			return row.sender
		end
	end
	return nameHint
end

local function RecentWhisperSender(link, nameHint)
	return RecentLinkedSender(whisperedItems, link, nameHint)
end

local function RecentGuildSender(link, nameHint)
	return RecentLinkedSender(guildItems, link, nameHint)
end

-- Forever's UnitName is the first name. Chat shows UnitFullName as "First Surname".
local function PlayerChatName()
	local short = UnitName and UnitName("player")
	if type(short) == "string" and Secret(short) then
		short = nil
	end
	if not UnitFullName then
		return short
	end
	local first, second = UnitFullName("player")
	if type(first) ~= "string" or first == "" or Secret(first) then
		return short
	end
	if type(second) ~= "string" or second == "" or Secret(second) then
		return short or first
	end
	if WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
		return first .. " " .. second
	end
	local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName and GetRealmName()
	if type(realm) == "string" and strlower((second:gsub("%s+", ""))) == strlower((realm:gsub("%s+", ""))) then
		return short or first
	end
	return first .. " " .. second
end

IsLocalPlayer = function(target)
	if type(target) ~= "string" or target == "" or Secret(target) then
		return false
	end
	local function same(name)
		return type(name) == "string" and not Secret(name) and strlower(name) == strlower(target)
	end
	if same(PlayerChatName()) then
		return true
	end
	if UnitName and same(UnitName("player")) then
		return true
	end
	return false
end

local function WhisperLineMark()
	local pattern = CHAT_WHISPER_GET
	if type(pattern) ~= "string" then
		return "whispers:"
	end
	local mark = strtrim(pattern:gsub("%%s", ""))
	if mark == "" then
		return "whispers:"
	end
	return mark
end

local function LineIsWhisper(line)
	return HasText(line, WhisperLineMark())
end

local function LineIsGuild(line)
	if type(line) ~= "string" then
		return false
	end
	if HasText(line, "|Hchannel:GUILD|h") or HasText(line, "[Guild]") or HasText(line, "[G]") then
		return true
	end
	local pattern = CHAT_GUILD_GET
	if type(pattern) ~= "string" then
		return false
	end
	local mark = strtrim(pattern:gsub("%%s", ""))
	return mark ~= "" and HasText(line, mark)
end

local function PlayerNameFromLine(line)
	if type(line) ~= "string" or Secret(line) then
		return
	end
	local data = line:match("|Hplayer:([^|]+)|h")
	if type(data) ~= "string" or data == "" or Secret(data) then
		return
	end
	local name = data:match("^(.-):%d+:") or data:match("^([^:]+)")
	if type(name) ~= "string" or name == "" or Secret(name) then
		return
	end
	return name
end

-- |Hplayer:Name:line:GUILD:|h is the channel that owns the clicked line.
local function OwnerChannel(line)
	if type(line) ~= "string" or Secret(line) then
		return
	end
	local data = line:match("|Hplayer:([^|]+)|h")
	if type(data) == "string" then
		local name, chatType = data:match("^(.-):%d+:([^:]*)")
		if type(name) == "string" and name ~= "" then
			if chatType == "" or chatType == "0" then
				chatType = nil
			end
			return name, chatType and strupper(chatType) or nil
		end
	end
	local name = PlayerNameFromLine(line)
	if LineIsGuild(line) then
		return name, "GUILD"
	end
	if LineIsWhisper(line) then
		return name, "WHISPER"
	end
	return name
end

local function MouseoverFontText(region)
	if not region or not region.GetObjectType or region:GetObjectType() ~= "FontString" then
		return
	end
	if region.IsShown then
		local shown = region:IsShown()
		if Secret(shown) or not shown then
			return
		end
	end
	if not region.IsMouseOver then
		return
	end
	local over = region:IsMouseOver()
	if Secret(over) or not over then
		return
	end
	local text = region.GetText and region:GetText()
	if type(text) ~= "string" or text == "" or Secret(text) then
		return
	end
	return text
end

local function MouseoverLineOnFrame(frame, itemID)
	if not frame or not frame.GetRegions then
		return
	end
	local fallback
	local count = frame:GetNumRegions() or 0
	for i = 1, count do
		local text = MouseoverFontText(select(i, frame:GetRegions()))
		if text then
			if itemID and text:find("item:" .. itemID, 1, true) then
				return text
			end
			fallback = text
		end
	end
	return fallback
end

local function ForEachChatFrame(callback)
	local n = NUM_CHAT_WINDOWS or 10
	for i = 1, n do
		local frame = _G["ChatFrame" .. i]
		if frame and callback(frame) then
			return true
		end
	end
end

local function MessageTextUnderMouse(frame, itemID)
	if not frame or type(frame.visibleLines) ~= "table" then
		return
	end
	local fallback
	for _, line in ipairs(frame.visibleLines) do
		local over = line.IsMouseOver and line:IsMouseOver()
		if not Secret(over) and over then
			local info = line.messageInfo
			local text = type(info) == "table" and info.message or (line.GetText and line:GetText())
			if type(text) == "string" and text ~= "" and not Secret(text) then
				if itemID and text:find("item:" .. itemID, 1, true) then
					return text
				end
				fallback = fallback or text
			end
		end
	end
	return fallback
end

local function MouseoverChatLine(preferred, link)
	local itemID = ItemIDFromLink(link)
	if preferred then
		local text = MouseoverLineOnFrame(preferred, itemID)
		if text then
			return text
		end
	end
	local found
	ForEachChatFrame(function(frame)
		if frame ~= preferred then
			local text = MouseoverLineOnFrame(frame, itemID)
			if text then
				found = text
				return true
			end
		end
	end)
	return found
end

local function MouseIsOverChatFrame()
	local hit
	ForEachChatFrame(function(frame)
		local visible = frame.IsVisible and frame:IsVisible()
		local over = frame.IsMouseOver and frame:IsMouseOver()
		if not Secret(visible) and visible and not Secret(over) and over then
			hit = frame
			return true
		end
	end)
	return hit
end

FullChatLine = function(chatFrame, link)
	local itemID = ItemIDFromLink(link)
	if chatFrame then
		local text = MessageTextUnderMouse(chatFrame, itemID)
		if text then
			return text
		end
	end
	local found
	ForEachChatFrame(function(frame)
		if frame ~= chatFrame then
			local text = MessageTextUnderMouse(frame, itemID)
			if text then
				found = text
				return true
			end
		end
	end)
	if found then
		return found
	end
	return MouseoverChatLine(chatFrame, link)
end

local function LineIsLoot(line)
	if type(line) ~= "string" or Secret(line) then
		return false
	end
	local lower = strlower(line)
	return lower:find("receive loot", 1, true) or lower:find("receives loot", 1, true)
end

local function LineIsOutgoingWhisper(line)
	return HasText(line, "[W To]") or HasText(line, ":WHISPER_INFORM")
end

local function LineIsPublic(line)
	if HasText(line, ":SAY") or HasText(line, ":PARTY") or HasText(line, ":RAID") then
		return true
	end
	if HasText(line, "[PL]") or HasText(line, "[RL]") or HasText(line, "[RW]") then
		return true
	end
	return HasText(line, "[S]") or HasText(line, "[P]") or HasText(line, "[R]")
end

-- GUILD and incoming WHISPER keep the sender. SAY, PARTY, RAID, and LOOT do not.
ClassifyLine = function(line, link)
	if LineIsOutgoingWhisper(line) then
		return "WHISPER_OUT"
	end
	if LineIsLoot(line) then
		return "LOOT"
	end
	local pratSender, pratChannel = PratOwner(link, line)
	if pratChannel == "GUILD" then
		return "GUILD", pratSender
	end
	if pratChannel == "WHISPER" then
		return "WHISPER", pratSender
	end
	local name, channel = line and OwnerChannel(line)
	if channel == "WHISPER_INFORM" then
		return "WHISPER_OUT", name
	end
	if channel == "GUILD" or LineIsGuild(line) then
		local sender = name and (RecentGuildSender(link, name) or name) or RecentGuildSender(link)
		return "GUILD", sender
	end
	if channel == "WHISPER" or LineIsWhisper(line) then
		return "WHISPER", RecentWhisperSender(link, name) or name
	end
	if channel == "SAY" or channel == "PARTY" or channel == "PARTY_LEADER" or channel == "RAID" or channel == "RAID_LEADER" or channel == "RAID_WARNING" or LineIsPublic(line) then
		return channel or "SAY"
	end
end
end

local scanTooltip
local function ScanTooltip()
	if scanTooltip then
		return scanTooltip
	end
	local ok, tip = pcall(CreateFrame, "GameTooltip", "AuctionworthyScanTooltip", UIParent, "GameTooltipTemplate")
	if not ok or not tip then
		return nil
	end
	tip.AuctionworthySkip = true
	tip:SetAlpha(0)
	if tip.EnableMouse then
		tip:EnableMouse(false)
	end
	scanTooltip = tip
	return tip
end

-- Hidden tooltip read. Classic fills lines inside SetHyperlink; modern clients
-- deliver them in the tooltip post-call, which updateTooltip forwards here.
local function WithCrateBundles(link, callback)
	local tip = ScanTooltip()
	if not tip then
		callback({})
		return
	end
	local finished = false
	local found = {}
	local function deliver(force)
		if finished then
			return
		end
		local n = tip.NumLines and tip:NumLines() or 0
		local bundles = n > 0 and CrateFillBundles(tip) or {}
		if #bundles == 0 and not force then
			return
		end
		finished = true
		tip.AuctionworthyOnShare = nil
		found = bundles
		if #found > 0 then
			StoreCrateBundles(link, found)
		end
	end
	local function finish()
		if tip.Hide then
			tip:Hide()
		end
		callback(found)
	end
	tip.AuctionworthyOnShare = function()
		deliver(false)
	end
	local itemID = ItemIDFromLink(link)
	if itemID and C_Item and C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, itemID)
	end
	tip:SetAlpha(0)
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 200, 200)
	tip:ClearLines()
	-- Chat only has the item id. Showing this tooltip is what fills in the crate list.
	tip:SetHyperlink(link)
	if tip.Show then
		tip:Show()
	end
	tip:SetAlpha(0)
	if not finished and (tip.NumLines and tip:NumLines() or 0) > 0 then
		deliver(false)
	end
	if finished then
		finish()
		return
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.45, function()
			deliver(true)
			finish()
		end)
	else
		deliver(true)
		finish()
	end
end

local loadingItems = {}
local loadToken = 0

local function WhenItemReady(link, callback)
	local done = false
	loadToken = loadToken + 1
	local token = loadToken
	local function finish()
		if done then
			return
		end
		done = true
		loadingItems[token] = nil
		callback()
	end
	if Item and Item.CreateFromItemLink then
		local ok, item = pcall(Item.CreateFromItemLink, Item, link)
		if ok and item and item.ContinueOnItemLoad then
			-- Keep the item alive. Otherwise the load callback never runs and shareBusy sticks.
			loadingItems[token] = item
			item:ContinueOnItemLoad(finish)
			if C_Timer and C_Timer.After then
				C_Timer.After(1.5, finish)
			end
			return
		end
	end
	local id = ItemIDFromLink(link)
	if not id and type(link) == "string" then
		id = tonumber(link:match("item:(%d+)"))
	end
	if id and C_Item and C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, id)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.3, finish)
	else
		finish()
	end
end

local function CheapestFillLine(bundles)
	local best
	for _, bundle in ipairs(bundles) do
		local itemLink = FillItemLink(bundle.name, bundle.itemID)
		local unit = getFillAuctionPrice(itemLink, ItemIDFromLink(itemLink) or bundle.itemID)
		if unit then
			local total = math.floor(bundle.qty * unit)
			if not best or total < best.total then
				best = {
					total = total,
					qty = bundle.qty,
					name = bundle.name,
					link = itemLink,
				}
			end
		end
	end
	if not best then
		return "Cheapest: No auction data"
	end
	local shown = best.name and ("[" .. best.name .. "]") or "[item]"
	if type(best.link) == "string" and best.link:find("|H", 1, true) and not Secret(best.link) then
		shown = best.link
	end
	local line = "Cheapest: " .. best.qty .. "x " .. shown .. " (" .. formatChatMoney(best.total) .. ")"
	if #line > 255 and best.name then
		line = "Cheapest: " .. best.qty .. "x [" .. best.name .. "] (" .. formatChatMoney(best.total) .. ")"
	end
	return line
end

-- Same profit or loss as the empty-crate tooltip, after Auctionator undercut.
local function EmptyCrateValueLine(itemLink)
	local _, _, _, _, _, _, _, _, _, _, vendorPrice = ItemInfo(itemLink)
	if Secret(vendorPrice) then
		vendorPrice = 0
	end
	vendorPrice = tonumber(vendorPrice) or 0
	local marketUnit = getFillAuctionPrice(itemLink, ItemIDFromLink(itemLink))
	local auctionPrice = applyUndercut(marketUnit)
	if not auctionPrice then
		return "Empty AH value: No Auction Data"
	end
	local profit = auctionPrice - calculateAuctionCosts(vendorPrice)
	if profit > 0 then
		return "Empty AH value: Profit: " .. formatChatMoney(profit)
	end
	return "Empty AH value: Loss: " .. formatChatMoney(-profit)
end

local function IsKnownCrateID(itemID)
	itemID = tonumber(itemID)
	if not itemID or itemID < 1 then
		return false
	end
	if DatabaseCrateRecipe(itemID) then
		return true
	end
	local crates = AuctionworthyCrateIDs
	if type(crates) ~= "table" then
		return false
	end
	for _, crateID in pairs(crates) do
		if tonumber(crateID) == itemID then
			return true
		end
	end
	return false
end

local function IsCrateLink(link)
	if type(link) ~= "string" or link == "" or Secret(link) then
		return false
	end
	local shown = link:match("|h%[(.-)%]|h")
	if IsWaylaidCrateName(shown) then
		return true
	end
	local name = ItemInfo(link)
	if Secret(name) then
		name = nil
	end
	if IsWaylaidCrateName(name) then
		return true
	end
	if IsKnownCrateID(ItemIDFromLink(link)) then
		return true
	end
	return CachedCrateBundles(link) and true or false
end

local function SellItemFacts(link)
	local name, _, _, _, _, _, _, _, _, _, vendorPrice, classID, _, bindType = ItemInfo(link)
	if Secret(name) or type(name) ~= "string" or name == "" then
		return
	end
	return true, vendorPrice, classID, bindType
end

-- Same cutoff as the item tooltip: Auction it, or sell to the vendor.
-- The second return is true when the item is not loaded yet.
local function ItemSellLine(itemLink)
	local loaded, vendorPrice, classID, bindType = SellItemFacts(itemLink)
	local pricedLink = itemLink
	if not loaded then
		local id = ItemIDFromLink(itemLink)
		local rebuilt = id and ItemLinkFromID(id)
		if type(rebuilt) == "string" and rebuilt ~= itemLink then
			local rebuiltLoaded, rebuiltVendor, rebuiltClass, rebuiltBind = SellItemFacts(rebuilt)
			if rebuiltLoaded then
				loaded, vendorPrice, classID, bindType = rebuiltLoaded, rebuiltVendor, rebuiltClass, rebuiltBind
				pricedLink = rebuilt
			end
		end
	end
	if not loaded then
		return nil, true
	end
	local blocked
	if not Secret(bindType) then
		bindType = tonumber(bindType)
		if bindType == 1 or bindType == 4 then
			blocked = true
		end
	end
	if not blocked and not Secret(classID) then
		classID = tonumber(classID)
		local questClass = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
		if classID == questClass then
			blocked = true
		end
	end
	if blocked then
		return "Can not be posted on auction house, sorry"
	end
	if Secret(vendorPrice) or Secret(bindType) then
		return "No Auction Data"
	end
	vendorPrice = tonumber(vendorPrice) or 0
	if vendorPrice <= 0 then
		return "No Auction Data"
	end
	local id = ItemIDFromLink(itemLink) or ItemIDFromLink(pricedLink)
	local marketUnit = getAuctionPrice(itemLink) or getAuctionPrice(pricedLink) or getAuctionPriceByItemID(id)
	local auctionPrice = applyUndercut(marketUnit)
	if type(auctionPrice) ~= "number" then
		return "No Auction Data"
	end
	local auctionCosts = calculateAuctionCosts(vendorPrice)
	local profit = auctionPrice - auctionCosts
	if profit > 0 then
		return "AH it: " .. formatChatMoney(profit)
	end
	return "Vendor it: " .. formatChatMoney(-profit) .. " loss if posted on AH"
end

local pendingItemSells = {}

local function DeliverItemSell(link, who)
	if Auctionworthy.ScanBusy and Auctionworthy:ScanBusy() then
		return true
	end
	local line, waiting = ItemSellLine(link)
	if waiting then
		return false
	end
	if line then
		SendShareLine(line, "WHISPER", who)
	end
	return true
end

local function FlushItemSells(itemID)
	local rows = pendingItemSells[itemID]
	if not rows then
		return
	end
	pendingItemSells[itemID] = nil
	local held = rows.item
	local again
	for i = 1, #rows do
		if rows[i] and not DeliverItemSell(rows[i].link, rows[i].who) then
			again = again or {}
			again[#again + 1] = rows[i]
		end
	end
	if again then
		again.item = held
		pendingItemSells[itemID] = again
	end
end

local function WatchItemSell(link, who)
	if DeliverItemSell(link, who) then
		return
	end
	local id = ItemIDFromLink(link)
	if not id then
		SendShareLine("No Auction Data", "WHISPER", who)
		return
	end
	local bucket = pendingItemSells[id]
	if not bucket then
		bucket = {}
		pendingItemSells[id] = bucket
	end
	bucket[#bucket + 1] = { link = link, who = who }
	if Item and Item.CreateFromItemLink then
		local ok, item = pcall(Item.CreateFromItemLink, Item, link)
		if ok and item and item.ContinueOnItemLoad then
			bucket.item = item
			item:ContinueOnItemLoad(function()
				FlushItemSells(id)
			end)
		end
	end
	if C_Item and C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, id)
	end
end

local itemSellWait = CreateFrame("Frame")
itemSellWait:SetScript("OnEvent", function(_, _, itemID)
	FlushItemSells(tonumber(itemID))
end)
if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("ITEM_DATA_LOAD_RESULT") then
	pcall(itemSellWait.RegisterEvent, itemSellWait, "ITEM_DATA_LOAD_RESULT")
end
if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("GET_ITEM_INFO_RECEIVED") then
	pcall(itemSellWait.RegisterEvent, itemSellWait, "GET_ITEM_INFO_RECEIVED")
end

local shareBusy = false
local lastShareAt = 0
local shareWhisperTo

local function ReleaseShareLater()
	if C_Timer and C_Timer.After then
		C_Timer.After(0.4, function()
			shareBusy = false
		end)
	else
		shareBusy = false
	end
end

local function ShareWaylaidLink(link, whisperTo)
	if type(link) ~= "string" or link == "" or Secret(link) or not link:find("item:", 1, true) then
		ClickDebug("share skipped: bad link")
		return
	end
	if type(whisperTo) ~= "string" or whisperTo == "" or Secret(whisperTo) then
		whisperTo = nil
	end
	local now = GetTime and GetTime() or 0
	if shareBusy or (now - lastShareAt) < 0.4 then
		-- Bag clicks hit two hooks. The second one only keeps a whisper target.
		if whisperTo then
			shareWhisperTo = whisperTo
		end
		return
	end
	lastShareAt = now
	shareWhisperTo = whisperTo

	local function shownCrateName()
		if type(link) ~= "string" or Secret(link) then
			return
		end
		local lower = strlower(link)
		local startAt, endAt = lower:find("%[waylaid crate[^%]]*%]")
		if not startAt then
			return
		end
		return link:sub(startAt + 1, endAt - 1)
	end
	local function begin(retried)
		local name, full = ItemInfo(link)
		if Secret(name) then
			name = nil
		end
		if Secret(full) then
			full = nil
		end
		if type(name) ~= "string" or name == "" then
			name = shownCrateName()
		end
		if type(name) ~= "string" or name == "" then
			if retried then
				ClickDebug("share skipped: item name not ready")
				shareBusy = false
				return
			end
			ClickDebug("share waiting for item")
			shareBusy = true
			WhenItemReady(link, function()
				shareBusy = false
				begin(true)
			end)
			return
		end
		if not IsWaylaidCrateName(name) then
			ClickDebug("share skipped: not a crate (" .. name .. ")")
			shareBusy = false
			return
		end
		shareBusy = true
		local line1 = "[" .. name .. "]"
		if type(full) == "string" and full:find("|H", 1, true) and not Secret(full) then
			line1 = full
		elseif link:find("|H", 1, true) then
			line1 = link
		end
		local function sendBundles(bundles)
			if #bundles == 0 then
				print("|cffff7f00Auctionworthy-Forever:|r Couldn't read that crate's fill list. Click it once more.")
				ReleaseShareLater()
				return
			end
			local second = CheapestFillLine(bundles)
			local target = shareWhisperTo
			if type(target) == "string" and target ~= "" and not Secret(target) then
				local reply = second
				if type(name) == "string" and name ~= "" and not Secret(name) then
					local withName = name .. ": " .. second
					if #withName <= 255 then
						reply = withName
					end
				end
				SendShareLine(reply, "WHISPER", target)
			else
				local channel = ShareChannel()
				SendShareLine(line1, channel)
				SendShareLine(second, channel)
			end
			ReleaseShareLater()
		end
		local cached = CachedCrateBundles(full or link)
		ClickDebug("share " .. name .. " cached=" .. tostring(cached ~= nil))
		if cached then
			sendBundles(cached)
			return
		end
		WithCrateBundles(full or link, sendBundles)
	end

	begin(false)
end


ReadScannedCrateFills = function()
	local ids = {}
	for itemID in pairs(pendingCrateIDs) do
		ids[#ids + 1] = itemID
	end
	pendingCrateIDs = {}
	if #ids == 0 then
		local materials = ApplyScannedMaterials()
		if materials > 0 then
			WorthyPrint("Saved " .. materials .. " crafting materials from the scan.")
		end
		return
	end
	local index = 0
	local saved = 0
	local function nextCrate()
		if shareBusy then
			if C_Timer and C_Timer.After then
				C_Timer.After(0.3, nextCrate)
			end
			return
		end
		index = index + 1
		local itemID = ids[index]
		if not itemID then
			local materials = ApplyScannedMaterials()
			if saved > 0 then
				WorthyPrint("Cached " .. saved .. " crate fill lists.")
			else
				WorthyPrint("No crate fill lists were read from that scan.")
			end
			if materials > 0 then
				WorthyPrint("Saved " .. materials .. " crafting materials from the scan.")
			end
			return
		end
		shareBusy = true
		local link = ItemLinkFromID(itemID) or ("item:" .. itemID)
		WithCrateBundles(link, function(bundles)
			if #bundles > 0 then
				saved = saved + 1
			end
			shareBusy = false
			if C_Timer and C_Timer.After then
				C_Timer.After(0.05, nextCrate)
			else
				nextCrate()
			end
		end)
	end
	nextCrate()
end


local hooked
local function InstallHooks()
	if hooked then
		return
	end
	hooked = true
	if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AttachItemTooltip)
	end
	HookLegacy()
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

WorthyPrint = function(msg)
	msg = "Worthy: " .. tostring(msg)
	if SendSystemMessage then
		SendSystemMessage(msg)
		return
	end
	if ChatFrame_DisplaySystemMessageInPrimary then
		ChatFrame_DisplaySystemMessageInPrimary(msg)
		return
	end
	local frame = DEFAULT_CHAT_FRAME or SELECTED_CHAT_FRAME
	if frame and frame.AddMessage then
		frame:AddMessage(msg)
		return
	end
	print(msg)
end

SetWorthyScanButtonEnabled = function(enabled, label)
	local btn = worthyScan.button
	if not btn then
		return
	end
	label = label or "Worthy Scan"
	btn:SetEnabled(enabled and true or false)
	btn:SetText(label)
	if label == "Worthy Scan" then
		if btn.FitToText then
			pcall(btn.FitToText, btn)
		else
			local w = btn.GetTextWidth and btn:GetTextWidth() or 80
			btn:SetWidth(math.max(90, w + 24))
		end
	end
end

local function AuctionatorScanButton()
	local parent = SafeGlobal("AuctionatorConfigFrame")
	return parent and parent.ScanButton
end

local function SetAuctionatorScanButtonEnabled(enabled)
	local btn = AuctionatorScanButton()
	if btn and btn.SetEnabled then
		pcall(btn.SetEnabled, btn, enabled and true or false)
	end
end

local function AuctionatorScanActive()
	if auctionatorBusy then
		return true
	end
	local addon = AuctionatorAddon()
	local state = addon and addon.State
	if type(state) ~= "table" then
		return false
	end
	local full = state.FullScanFrameRef
	if type(full) == "table" and full.inProgress then
		return true
	end
	local inc = state.IncrementalScanFrameRef
	if type(inc) == "table" and inc.doingFullScan then
		return true
	end
	return false
end

local WORTHY_SCAN_CD = 5 * 60

local function WorthyScanRemaining()
	local last = tonumber(options.worthyScanAt) or 0
	local left = (last + WORTHY_SCAN_CD) - time()
	if left < 0 then
		return 0
	end
	return math.floor(left)
end

local function FormatWorthyCD(sec)
	sec = tonumber(sec) or 0
	return string.format("CD %d:%02d", math.floor(sec / 60), sec % 60)
end

local worthyCdTicker
local function StopWorthyCdTicker()
	if worthyCdTicker then
		worthyCdTicker:Cancel()
		worthyCdTicker = nil
	end
end

local function StartWorthyCdTicker()
	if worthyCdTicker or not C_Timer or not C_Timer.NewTicker then
		return
	end
	worthyCdTicker = C_Timer.NewTicker(1, function()
		if worthyScan.inProgress then
			return
		end
		local left = WorthyScanRemaining()
		if left <= 0 then
			StopWorthyCdTicker()
			if SyncScanButtons then
				SyncScanButtons()
			end
			return
		end
		SetWorthyScanButtonEnabled(false, FormatWorthyCD(left))
	end)
end

local function BeginWorthyCooldown()
	options.worthyScanAt = time()
	SaveOptions()
	StartWorthyCdTicker()
end

SyncScanButtons = function()
	local us = worthyScan.inProgress
	if us then
		SetAuctionatorScanButtonEnabled(false)
		if worthyScan.button then
			worthyScan.button:SetEnabled(false)
		end
		return
	end
	SetAuctionatorScanButtonEnabled(true)
	local left = WorthyScanRemaining()
	if left > 0 then
		SetWorthyScanButtonEnabled(false, FormatWorthyCD(left))
		StartWorthyCdTicker()
	elseif AuctionatorScanActive() then
		SetWorthyScanButtonEnabled(false, "Worthy Scan")
	else
		SetWorthyScanButtonEnabled(true, "Worthy Scan")
	end
end

RestoreDefaultScanButtons = function()
	SyncScanButtons()
end

FinishWorthyScan = function()
	worthyScan.inProgress = false
	worthyScan.processing = false
	worthyScan.mode = nil
	auctionatorBusy = false
	AuctionworthyFillIDs = fillIDs
	BeginWorthyCooldown()
	RestoreDefaultScanButtons()
	WorthyPrint("Scan finished. Cached " .. tostring(worthyScan.stored) .. " Waylaid crates.")
	if ReadScannedCrateFills then
		ReadScannedCrateFills()
	end
end

local function AuctionatorScanFrame()
	local addon = AuctionatorAddon()
	local state = addon and addon.State
	if type(state) ~= "table" then
		return
	end
	local useReplicate = false
	local cfg = addon.Config
	if cfg and cfg.Get and cfg.Options and cfg.Options.REPLICATE_SCAN then
		local ok, value = pcall(cfg.Get, cfg.Options.REPLICATE_SCAN)
		useReplicate = ok and value and true
	end
	if useReplicate and state.FullScanFrameRef then
		return state.FullScanFrameRef, "replicate"
	end
	if state.IncrementalScanFrameRef then
		return state.IncrementalScanFrameRef, "summary"
	end
	return state.FullScanFrameRef, "full"
end

local function StartWorthyScan()
	if worthyScan.inProgress then
		WorthyPrint("Worthy Scan already running.")
		return
	end
	if AuctionatorScanActive() then
		WorthyPrint("Auctionator is already scanning. Wait for it to finish.")
		SyncScanButtons()
		return
	end
	local left = WorthyScanRemaining()
	if left > 0 then
		WorthyPrint("Worthy Scan is on cooldown (" .. FormatWorthyCD(left) .. ").")
		SyncScanButtons()
		return
	end
	local frame, kind = AuctionatorScanFrame()
	if type(frame) ~= "table" or type(frame.InitiateScan) ~= "function" then
		WorthyPrint("Auctionator Full Scan is not ready.")
		return
	end
	if frame.CanInitiate and not frame:CanInitiate() then
		local msg
		if frame.NextScanMessage then
			local ok, text = pcall(frame.NextScanMessage, frame)
			if ok then
				msg = text
			end
		end
		WorthyPrint(msg or "Auctionator Full Scan is on cooldown.")
		return
	end
	pendingCrateIDs = {}
	scanItemIDs = {}
	local removed = PruneFillIDs()
	if removed > 0 then
		WorthyPrint("Purged " .. removed .. " non-Waylaid names before the scan.")
	end
	worthyScan.stored = 0
	worthyScan.total = 0
	worthyScan.index = 0
	worthyScan.processing = false
	worthyScan.inProgress = true
	worthyScan.mode = kind
	SetWorthyScanButtonEnabled(false, "Scanning...")
	SyncScanButtons()
	WorthyPrint("Starting scan.")
	local ok, err = pcall(frame.InitiateScan, frame)
	if not ok then
		worthyScan.inProgress = false
		worthyScan.processing = false
		worthyScan.mode = nil
		RestoreDefaultScanButtons()
		WorthyPrint("Scan failed to start: " .. tostring(err))
	end
end

function Auctionworthy:AUCTION_HOUSE_CLOSED()
	if worthyScan.inProgress then
		WorthyPrint("Worthy Scan cancelled (AH closed).")
		worthyScan.inProgress = false
		worthyScan.processing = false
		worthyScan.mode = nil
		auctionatorBusy = false
	end
	RestoreDefaultScanButtons()
end

local function EnsureWorthyScanButton()
	if worthyScan.button and worthyScan.button.GetParent and worthyScan.button:GetParent() then
		return
	end
	local parent = SafeGlobal("AuctionatorConfigFrame")
	if type(parent) ~= "table" or not parent.SetScript then
		return
	end
	if not parent.ScanButton and not parent.OptionsButton then
		return
	end
	local btn = CreateFrame("Button", "AuctionworthyWorthyScanButton", parent, "UIPanelDynamicResizeButtonTemplate")
	if not btn then
		return
	end
	btn:SetText("Worthy Scan")
	if btn.FitToText then
		pcall(btn.FitToText, btn)
	else
		btn:SetSize(110, 22)
	end
	local anchor = parent.OptionsButton or parent.ScanButton
	btn:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -3, 0)
	btn:SetScript("OnClick", function()
		local ok, err = pcall(StartWorthyScan)
		if not ok then
			WorthyPrint("Scan failed to start: " .. tostring(err))
		end
	end)
	worthyScan.button = btn
	SyncScanButtons()
end

local configFrameHooked
local function HookWorthyScanButton()
	EnsureWorthyScanButton()
	if configFrameHooked then
		return
	end
	local parent = SafeGlobal("AuctionatorConfigFrame")
	if type(parent) == "table" and parent.HookScript then
		local ok = pcall(parent.HookScript, parent, "OnShow", EnsureWorthyScanButton)
		if ok then
			configFrameHooked = true
		end
	end
end

function Auctionworthy:AUCTION_HOUSE_SHOW()
	HookWorthyScanButton()
	if C_Timer and C_Timer.After then
		C_Timer.After(0.25, function()
			HookWorthyScanButton()
			SyncScanButtons()
		end)
		C_Timer.After(1, function()
			HookWorthyScanButton()
			SyncScanButtons()
		end)
	end
end
Auctionworthy:RegisterEvent("AUCTION_HOUSE_SHOW")
Auctionworthy:RegisterEvent("AUCTION_HOUSE_CLOSED")

function Auctionworthy:ADDON_LOADED(name)
	if name == ADDON_NAME or name == "Prat-3.0" then
		HookPratMessages()
	end
	if name == ADDON_NAME then
		LoadOptions()
		LoadFillIDs()
		LoadCrateFills()
		local dropped = DropDatabaseAdditions()
		if dropped > 0 then
			WorthyPrint("Removed " .. dropped .. " saved names already in the database.")
		end
		PruneFillIDs()
		InstallHooks()
		HookAuctionatorOptionsClose()
		HookAuctionatorScan()
		HookWorthyScanButton()
		RefreshAuctionatorConfig(false)
		return
	end
	if name == "Auctionator" then
		HookAuctionatorOptionsClose()
		HookAuctionatorScan()
		HookWorthyScanButton()
		RefreshAuctionatorConfig(false)
	end
end

function Auctionworthy:CHAT_MSG_WHISPER(message, sender)
	RememberWhisperItem(message, sender)
end
Auctionworthy:RegisterEvent("CHAT_MSG_WHISPER")

function Auctionworthy:CHAT_MSG_GUILD(message, sender)
	RememberGuildItem(message, sender)
end
Auctionworthy:RegisterEvent("CHAT_MSG_GUILD")

function Auctionworthy:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	HookPratMessages()
	HookAuctionatorOptionsClose()
	HookAuctionatorScan()
	HookWorthyScanButton()
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
	frame:SetSize(400, 480)
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
	info:SetText("Auctionator prices on tooltips. Hold Shift for the stack you are on.")

	local checkboxes = {
		{ label = "Show Auction Costs", key = "showAuctionCosts" },
		{ label = "Show Auction Price", key = "showAuctionPrice" },
		{ label = "Show Profit/Loss Options", key = "showProfitOptions" },
		{ label = "Show No Auction Data", key = "showNoAuctionData" },
		{ label = "Shift prices the current stack", key = "showFullStack" },
		{ label = "Show Decision Text", key = "showDecisionText" },
		{ label = "Apply Auctionator undercut", key = "applyUndercut" },
		{ label = "Show Undercut", key = "showUndercut" },
	}

	local yOffset = -72
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

	local shareLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	shareLabel:SetPoint("TOPLEFT", 48, yOffset - 4)
	shareLabel:SetText("Waylaid share key")

	local drop = CreateFrame("Button", "AuctionworthyShareKeyButton", frame, "UIPanelButtonTemplate")
	drop:SetSize(80, 22)
	drop:SetPoint("LEFT", shareLabel, "RIGHT", 12, 0)
	drop:SetText(ShareModifierLabel(options.shareModifier))

	local menu = CreateFrame("Frame", "AuctionworthyShareKeyMenu", frame, template)
	menu:SetSize(80, 68)
	menu:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -2)
	menu:SetFrameLevel(frame:GetFrameLevel() + 20)
	menu:EnableMouse(true)
	menu:Hide()
	if menu.SetBackdrop then
		menu:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		menu:SetBackdropColor(0, 0, 0, 1)
	end

	for i, entry in ipairs(SHARE_MODIFIERS) do
		local row = CreateFrame("Button", nil, menu)
		row:SetSize(74, 20)
		row:SetPoint("TOPLEFT", 3, -4 - (i - 1) * 20)
		local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		rowText:SetPoint("LEFT", 8, 0)
		rowText:SetText(entry.label)
		row:SetScript("OnEnter", function()
			rowText:SetTextColor(1, 0.82, 0)
		end)
		row:SetScript("OnLeave", function()
			rowText:SetTextColor(1, 1, 1)
		end)
		row:SetScript("OnClick", function()
			options.shareModifier = entry.key
			SaveOptions()
			drop:SetText(entry.label)
			menu:Hide()
		end)
	end

	drop:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
		else
			menu:Show()
		end
	end)

	local queryLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	queryLabel:SetPoint("TOPLEFT", 48, yOffset - 36)
	queryLabel:SetText("Crate Query")

	local queryBox = CreateFrame("EditBox", "AuctionworthyCrateQueryBox", frame, "InputBoxTemplate")
	queryBox:SetSize(90, 20)
	queryBox:SetPoint("LEFT", queryLabel, "RIGHT", 16, 0)
	queryBox:SetAutoFocus(false)
	queryBox:SetMaxLetters(CRATE_QUERY_MAX)
	queryBox:SetFontObject(GameFontHighlight)
	queryBox:SetText(CrateQueryPrefix())
	local function CommitCrateQuery(box)
		options.crateQuery = StoredCrateQuery(box:GetText())
		SaveOptions()
		box:SetText(CrateQueryPrefix())
	end
	queryBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	queryBox:SetScript("OnEnterPressed", function(self)
		CommitCrateQuery(self)
		self:ClearFocus()
	end)
	queryBox:SetScript("OnEscapePressed", function(self)
		self:SetText(CrateQueryPrefix())
		self:ClearFocus()
	end)
	queryBox:SetScript("OnEditFocusLost", function(self)
		CommitCrateQuery(self)
	end)

	local shareNote = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	shareNote:SetPoint("TOPLEFT", 48, yOffset - 68)
	shareNote:SetWidth(320)
	shareNote:SetJustifyH("LEFT")
	shareNote:SetText("Share key clicks a Waylaid crate. Query plus one item link replies with the price.")

	frame:SetScript("OnHide", function()
		menu:Hide()
	end)

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	closeButton:SetSize(100, 30)
	closeButton:SetPoint("BOTTOM", 0, 10)
	closeButton:SetText("Close")
	closeButton:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame:Show()
end

function Auctionworthy:ModifierDown()
	return ShareModifierDown()
end

function Auctionworthy:CrateQuery()
	return CrateQueryPrefix()
end

function Auctionworthy:ClickDebug(text)
	ClickDebug(text)
end

function Auctionworthy:PostCrate(link)
	ShareWaylaidLink(link)
end

function Auctionworthy:WhisperCrate(link, who)
	ShareWaylaidLink(link, who)
end

function Auctionworthy:ReadClick(chatFrame, link)
	local line = FullChatLine(chatFrame, link)
	if not line then
		return
	end
	return ClassifyLine(line, link)
end

function Auctionworthy:EachChatClick(handler)
	local function run(chatFrame, item)
		if not Auctionworthy:ModifierDown() then
			return
		end
		local kind, sender = Auctionworthy:ReadClick(chatFrame, item)
		handler(kind, sender, item)
	end
	if type(HandleModifiedItemClick) == "function" then
		hooksecurefunc("HandleModifiedItemClick", function(link)
			run(nil, link)
		end)
	end
	if type(ChatFrame_OnHyperlinkShow) == "function" then
		hooksecurefunc("ChatFrame_OnHyperlinkShow", function(a, b, c, d)
			local chatFrame, link, text, button
			if type(a) == "string" then
				link, text, button = a, b, c
			else
				chatFrame, link, text, button = a, b, c, d
			end
			if button == "RightButton" then
				return
			end
			run(chatFrame, text or link)
		end)
	end
end

function Auctionworthy:Secret(value)
	return Secret(value)
end

function Auctionworthy:ItemID(link)
	return ItemIDFromLink(link)
end

function Auctionworthy:ItemLink(itemID)
	return ItemLinkFromID(itemID)
end

function Auctionworthy:IsCrateName(name)
	return IsWaylaidCrateName(name) and true or false
end

function Auctionworthy:CachedBundles(link)
	return CachedCrateBundles(link)
end

function Auctionworthy:CheapestLine(bundles)
	return CheapestFillLine(bundles)
end

function Auctionworthy:EmptyValueLine(link)
	return EmptyCrateValueLine(link)
end

function Auctionworthy:IsCrateLink(link)
	return IsCrateLink(link) and true or false
end

function Auctionworthy:ItemSellLine(link)
	return ItemSellLine(link)
end

function Auctionworthy:ReplyItemSell(link, who)
	WatchItemSell(link, who)
end

function Auctionworthy:ScanBusy()
	if worthyScan.inProgress then
		return true
	end
	return AuctionatorScanActive() and true or false
end

function Auctionworthy:ItemName(link)
	local name, full = ItemInfo(link)
	if Secret(name) then
		name = nil
	end
	if Secret(full) then
		full = nil
	end
	return name, full
end

function Auctionworthy:ReadBundles(link, callback)
	WithCrateBundles(link, callback)
end

function Auctionworthy:WhenReady(link, callback)
	WhenItemReady(link, callback)
end

function Auctionworthy:WhisperLine(text, who)
	SendShareLine(text, "WHISPER", who)
end

function Auctionworthy:ShareIsBusy()
	local now = GetTime and GetTime() or 0
	return shareBusy or (now - lastShareAt) < 0.4
end

function Auctionworthy:LockShare()
	lastShareAt = GetTime and GetTime() or 0
	shareBusy = true
end

function Auctionworthy:ReleaseShare()
	ReleaseShareLater()
end

SLASH_AUCTIONWORTHY1 = "/auctionworthy"
SLASH_AUCTIONWORTHY2 = "/worthy"
SlashCmdList["AUCTIONWORTHY"] = function(msg)
	msg = strlower(strtrim(tostring(msg or "")))
	if msg == "refresh" or msg == "reload" then
		RefreshAuctionatorConfig(true)
		return
	end
	if msg == "debug" then
		if Auctionworthy.ToggleClickDebug then
			Auctionworthy:ToggleClickDebug()
		end
		return
	end
	if msg == "help" then
		print("|cff00ff00Auctionworthy-Forever:|r /worthy — options")
		print("  /worthy refresh — re-read Auctionator undercut (no /reload)")
		if Auctionworthy.ToggleClickDebug then
			print("  /worthy debug — toggle key-click debug lines for this session")
		end
		print("  Hold the share key and click a Waylaid crate in your bags, bank, or guild bank to post the cheapest fill. Key-clicks are ignored in combat.")
		print("  Say, party, raid, and loot-link clicks post to Raid, Party, or Say.")
		print("  A guild-chat crate whispers the person who posted it.")
		print("  A crate whispered to you whispers that person back.")
		print("  In guild, whisper, party, or raid, ?[crate] whispers you or that player the cheapest fill and empty-crate profit or loss.")
		print("  Worthy Scan saves each crate's fill list, so ?[crate] can answer from that cache.")
		return
	end
	openOptionsPanel()
end
