-- /worthy vc — unlimited Trade Goods and Miscellaneous/Reagent on the open merchant.
-- Saves into AuctionworthyVendorDB / AuctionworthyVendorScan.
-- Same name is one row. If prices differ, the higher copper stays.
-- Merchant getters are not pcall'd. This client treats their returns as secrets.

local RECIPE_CLASS = LE_ITEM_CLASS_RECIPE or 9
local TRADE_GOODS_CLASS = LE_ITEM_CLASS_TRADEGOODS or 7
local MISC_CLASS = LE_ITEM_CLASS_MISCELLANEOUS or 15
local MISC_REAGENT_SUB = LE_ITEM_MISCELLANEOUS_REAGENT or 1

local RECIPE_NAME = {
	"^recipe:",
	"^pattern:",
	"^plans:",
	"^formula:",
	"^schematic:",
	"^design:",
	"^manual:",
}

local function Secret(value)
	return Auctionworthy:Secret(value)
end

local function PublicText(value)
	if Secret(value) or type(value) ~= "string" or value == "" then
		return
	end
	return value
end

local function PublicNumber(value)
	if value == nil or Secret(value) then
		return
	end
	return tonumber(value)
end

local function MerchantOpen()
	if MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() then
		return true
	end
	return (GetMerchantNumItems and GetMerchantNumItems() or 0) > 0
end

local function ItemLink(index)
	if type(GetMerchantItemLink) ~= "function" then
		return
	end
	return PublicText(GetMerchantItemLink(index))
end

local function ItemID(link, index)
	local id = Auctionworthy:ItemID(link)
	if id then
		return id
	end
	if type(GetMerchantItemID) == "function" then
		id = PublicNumber(GetMerchantItemID(index))
		if id and id > 0 then
			return id
		end
	end
end

local function ItemFacts(link, id)
	local query = link or id
	if not query or not C_Item or not C_Item.GetItemInfo then
		return
	end
	local ok, name, _, _, _, _, itemType, subType, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfo, query)
	if not ok then
		return
	end
	return PublicText(name), PublicText(itemType), PublicText(subType), PublicNumber(classID), PublicNumber(subclassID)
end

local function InstantClass(link, id)
	if C_Item and C_Item.GetItemInfoInstant then
		local ok, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, link or id)
		if ok then
			return PublicNumber(classID), PublicNumber(subclassID)
		end
	end
end

local function IsVendorMat(itemType, subType, classID, subclassID)
	if classID == TRADE_GOODS_CLASS then
		return true, "Trade Goods"
	end
	if type(itemType) == "string" and strlower(itemType) == "trade goods" then
		return true, "Trade Goods"
	end
	if classID == MISC_CLASS and subclassID == MISC_REAGENT_SUB then
		return true, "Misc Reagent"
	end
	if type(itemType) == "string" and type(subType) == "string" then
		if strlower(itemType) == "miscellaneous" and strlower(subType) == "reagent" then
			return true, "Misc Reagent"
		end
	end
	return false, "none"
end

local function IsRecipe(name, classID)
	if classID == RECIPE_CLASS then
		return true, "classID"
	end
	if type(name) ~= "string" then
		return false
	end
	local lower = strlower(name)
	for _, pattern in ipairs(RECIPE_NAME) do
		if lower:find(pattern) then
			return true, "name"
		end
	end
	return false
end

local function ExtendedCost(index)
	if type(GetMerchantItemCostInfo) ~= "function" then
		return 0
	end
	return PublicNumber(GetMerchantItemCostInfo(index)) or 0
end

local function InMaterialDB(name)
	if type(name) ~= "string" then
		return false, "no"
	end
	local key = strlower(strtrim(name))
	local mats = AuctionworthyMaterialIDs
	if type(mats) == "table" and tonumber(mats[key]) then
		return true, "MaterialIDs"
	end
	local fill = AuctionworthyFillIDs
	if type(fill) == "table" and tonumber(fill[key]) then
		return true, "FillIDs"
	end
	local vendor = AuctionworthyVendorDB
	local row = type(vendor) == "table" and vendor[key]
	if type(row) == "table" and tonumber(row.price) then
		return true, "VendorDB"
	end
	return false, "no"
end

local function MerchantInfo(index)
	if type(GetMerchantItemInfo) == "function" then
		local name, _, price, quantity, numAvailable, _, _, extendedCost = GetMerchantItemInfo(index)
		return PublicText(name), PublicNumber(price), PublicNumber(quantity), PublicNumber(numAvailable), extendedCost == true
	end
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		local info = C_MerchantFrame.GetItemInfo(index)
		if type(info) == "table" then
			local qty = PublicNumber(info.quantity or info.numItems) or 1
			return PublicText(info.name), PublicNumber(info.price or info.cost), qty, PublicNumber(info.numAvailable), info.hasExtendedCost or info.isExtendedCost
		end
	end
end

local function LuaQuote(value)
	value = tostring(value or "")
	value = value:gsub("\\", "\\\\"):gsub('"', '\\"')
	return '"' .. value .. '"'
end

local function EnsureTables()
	if type(AuctionworthyVendorDB) ~= "table" then
		AuctionworthyVendorDB = {}
	end
	if type(AuctionworthyVendorScan) ~= "table" then
		AuctionworthyVendorScan = {}
	end
end

local function VialPack(name)
	if type(name) == "string" and strlower(name):find("vial", 1, true) then
		return 5
	end
end

local function CopyRow(row)
	local copy = {
		item = row.item,
		itemid = tonumber(row.itemid),
		price = tonumber(row.price),
	}
	local pack = tonumber(row.pack)
	if pack and pack > 1 then
		copy.pack = pack
	end
	return copy
end

local function ApplySavedScan()
	EnsureTables()
	for key, row in pairs(AuctionworthyVendorScan) do
		if type(key) == "string" and type(row) == "table" then
			local price = tonumber(row.price)
			local itemid = tonumber(row.itemid)
			if price and price > 0 and itemid and itemid > 0 then
				local cur = AuctionworthyVendorDB[key]
				local curPrice = type(cur) == "table" and tonumber(cur.price) or 0
				if not cur or price > curPrice then
					local stored = {
						item = row.item or key,
						itemid = itemid,
						price = price,
					}
					local pack = tonumber(row.pack) or VialPack(row.item or key)
					if pack and pack > 1 then
						stored.pack = pack
					end
					AuctionworthyVendorDB[key] = stored
				elseif cur and not tonumber(cur.pack) then
					local pack = tonumber(row.pack) or VialPack(row.item or key)
					if pack and pack > 1 then
						cur.pack = pack
					end
				end
			end
		end
	end
end

local function StoreRow(name, itemid, price)
	EnsureTables()
	local key = strlower(strtrim(name))
	local cur = AuctionworthyVendorDB[key] or AuctionworthyVendorScan[key]
	local pack = VialPack(name)
	if type(cur) == "table" and tonumber(cur.pack) then
		pack = tonumber(cur.pack)
	end
	local row = {
		item = name,
		itemid = itemid,
		price = price,
	}
	if pack and pack > 1 then
		row.pack = pack
		if type(cur) == "table" then
			cur.pack = pack
		end
	end
	local curPrice = type(cur) == "table" and tonumber(cur.price) or 0
	if curPrice > 0 and price < curPrice then
		return "lower", curPrice
	end
	if curPrice > 0 and price == curPrice then
		return "same", curPrice
	end
	AuctionworthyVendorDB[key] = row
	AuctionworthyVendorScan[key] = CopyRow(row)
	if curPrice > 0 then
		return "higher", curPrice
	end
	return "add", 0
end

local function LuaRow(name, itemid, price)
	local key = strlower(strtrim(name))
	return string.format(
		"\t[%s] = { item = %s, itemid = %d, price = %d },",
		LuaQuote(key),
		LuaQuote(name),
		itemid,
		price
	)
end

local function ReadSlot(index)
	local name, price, _, stock, extended = MerchantInfo(index)
	local link = ItemLink(index)
	local id = ItemID(link, index)
	if not name and link then
		name = Auctionworthy:ItemName(link)
		if Secret(name) then
			name = nil
		end
	end
	local factName, itemType, subType, classID, subclassID = ItemFacts(link, id)
	if not classID then
		classID, subclassID = InstantClass(link, id)
	end
	if not name then
		name = factName
	end
	local trade, tradeHow = IsVendorMat(itemType, subType, classID, subclassID)
	local recipe, recipeHow = IsRecipe(name, classID)
	local limited = stock ~= nil and stock ~= -1
	local extra = ExtendedCost(index)
	if extra == 0 and extended then
		extra = 1
	end
	price = price or 0
	local inDB, dbHow = InMaterialDB(name)
	local keep = name and id and not limited and not recipe and extra <= 0 and trade and price > 0
	local why = "ok"
	if not name and not id then
		why = "no name/id"
	elseif limited then
		why = "limited stock=" .. tostring(stock)
	elseif recipe then
		why = "recipe " .. tostring(recipeHow)
	elseif extra > 0 then
		why = "extendedCost"
	elseif not trade then
		why = "not Trade Goods or Misc Reagent"
	elseif price <= 0 then
		why = "price 0"
	end
	return {
		name = name,
		id = id,
		price = price,
		stock = stock,
		itemType = itemType,
		subType = subType,
		classID = classID,
		subclassID = subclassID,
		trade = trade,
		tradeHow = tradeHow,
		recipe = recipe and true or false,
		limited = limited,
		extra = extra,
		inDB = inDB,
		dbHow = dbHow,
		keep = keep,
		why = why,
	}
end

local function VerboseVendorDump()
	ApplySavedScan()
	local n = GetMerchantNumItems and GetMerchantNumItems() or 0
	if Secret(n) then
		n = 0
	end
	n = tonumber(n) or 0
	local npc = PublicText(UnitName and UnitName("npc"))
	local lines = {}
	local would, skip = 0, 0
	lines[#lines + 1] = "== vendor dump (inspect only, NOT saved) =="
	lines[#lines + 1] = "merchant=" .. tostring(npc)
	lines[#lines + 1] = "numItems=" .. tostring(n)
	lines[#lines + 1] = "VCADD would take: unlimited Trade Goods or Miscellaneous/Reagent, not recipe, copper>0"
	lines[#lines + 1] = ""
	for i = 1, n do
		local s = ReadSlot(i)
		if s.keep then
			would = would + 1
		else
			skip = skip + 1
		end
		local tag = s.keep and "WOULD_ADD" or "SKIP"
		lines[#lines + 1] = string.format(
			"%s #%d %s itemid=%s price=%s stock=%s limited=%s recipe=%s extra=%s class=%s/%s type=%s/%s trade=%s alreadyInDB=%s/%s | %s",
			tag,
			i,
			tostring(s.name),
			tostring(s.id),
			tostring(s.price),
			tostring(s.stock),
			tostring(s.limited),
			tostring(s.recipe),
			tostring(s.extra),
			tostring(s.classID),
			tostring(s.subclassID),
			tostring(s.itemType),
			tostring(s.subType),
			tostring(s.trade),
			tostring(s.inDB),
			tostring(s.dbHow),
			s.why
		)
	end
	return table.concat(lines, "\n"), n, would, skip
end

local function ScanMerchant()
	ApplySavedScan()
	local n = GetMerchantNumItems and GetMerchantNumItems() or 0
	if Secret(n) then
		n = 0
	end
	n = tonumber(n) or 0
	local npc = PublicText(UnitName and UnitName("npc"))
	local added, raised, same, lowered = {}, {}, {}, {}
	local skipped = 0
	for i = 1, n do
		local s = ReadSlot(i)
		if s.keep then
			local action, oldPrice = StoreRow(s.name, s.id, s.price)
			local line = LuaRow(s.name, s.id, s.price)
			if action == "add" then
				added[#added + 1] = line
			elseif action == "higher" then
				raised[#raised + 1] = line .. " -- was " .. tostring(oldPrice)
			elseif action == "same" then
				same[#same + 1] = line
			else
				lowered[#lowered + 1] = line .. " -- kept " .. tostring(oldPrice)
			end
		else
			skipped = skipped + 1
		end
	end
	local duplicates = #same + #lowered + #raised
	local lines = {}
	lines[#lines + 1] = "-- vendor check  merchant=" .. tostring(npc)
	lines[#lines + 1] = "-- unlimited Trade Goods / Misc Reagent. duplicate names merge; higher copper wins."
	lines[#lines + 1] = "-- added " .. #added .. ", raised " .. #raised .. ", duplicates " .. duplicates .. ", skipped " .. skipped
	local function block(title, rows)
		if #rows == 0 then
			return
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- " .. title
		for _, row in ipairs(rows) do
			lines[#lines + 1] = row
		end
	end
	block("added", added)
	block("raised to higher price", raised)
	block("skipped lower price (likely discount)", lowered)
	if #added == 0 and #raised == 0 and #lowered == 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "-- no new rows (all duplicates or skipped)"
	end
	return table.concat(lines, "\n"), n, skipped, duplicates
end

local function RunVendorCheck(showDump)
	if not MerchantOpen() then
		print("|cff00ff00Auctionworthy:|r Open a vendor, then /worthy vc")
		return
	end
	local text, scanned, skipped, duplicates = ScanMerchant()
	print("|cff00ff00Auctionworthy:|r Vendor check: scanned " .. tostring(scanned) .. ", skipped " .. tostring(skipped) .. ", duplicates " .. tostring(duplicates))
	if showDump and Auctionworthy.ShowDump then
		Auctionworthy:ShowDump(text)
	end
end

function Auctionworthy:VendorCheck()
	RunVendorCheck(true)
end

function Auctionworthy:VendorCheckAdd()
	RunVendorCheck(false)
end

local original = SlashCmdList.AUCTIONWORTHY
SlashCmdList.AUCTIONWORTHY = function(msg)
	local raw = strlower(strtrim(tostring(msg or "")))
	if raw == "vc" or raw == "vendorcheck" or raw == "vendor check" then
		Auctionworthy:VendorCheck()
		return
	end
	if raw == "vcadd" then
		Auctionworthy:VendorCheckAdd()
		return
	end
	if raw == "dump" and MerchantOpen() and Auctionworthy.ShowDump then
		local text, scanned, would, skip = VerboseVendorDump()
		print("|cff00ff00Auctionworthy:|r Vendor dump (inspect only, not saved): scanned " .. tostring(scanned) .. ", would add " .. tostring(would) .. ", skip " .. tostring(skip))
		Auctionworthy:ShowDump(text)
		return
	end
	if raw == "help" then
		if original then
			original(msg)
		end
		print("  /worthy vc — scan unlimited Trade Goods and Misc Reagent; save and show dump")
		print("  /worthy vcadd — same save, chat counts only (no dump window)")
		if Auctionworthy.ShowDump then
			print("  /worthy dump — inspect vendor tags only (never saves). Else tooltip dump.")
		end
		return
	end
	if original then
		original(msg)
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", ApplySavedScan)
