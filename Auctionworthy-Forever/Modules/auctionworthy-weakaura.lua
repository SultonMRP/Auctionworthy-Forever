-- Read-only gather snapshot for ForeverAuras. Bags only. Herbs / ore / skin by profession.
-- AuctionworthyWA.itemahprice(itemID) and .itemprofit(itemID) return copper strings.

-- id + English name. Forever GetItemNameByID is often empty; names are the fallback.
local HERB_ITEMS = {
	{2447, "Peacebloom"}, {765, "Silverleaf"}, {2449, "Earthroot"}, {785, "Mageroyal"},
	{2450, "Briarthorn"}, {3820, "Stranglekelp"}, {2453, "Bruiseweed"}, {3355, "Wild Steelbloom"},
	{3369, "Grave Moss"}, {3356, "Kingsblood"}, {3357, "Liferoot"}, {3818, "Fadeleaf"},
	{3821, "Goldthorn"}, {3358, "Khadgar's Whisker"}, {3819, "Wintersbite"}, {4625, "Firebloom"},
	{8831, "Purple Lotus"}, {8836, "Arthas' Tears"}, {8838, "Sungrass"}, {8839, "Blindweed"},
	{8845, "Ghost Mushroom"}, {8846, "Gromsblood"}, {13464, "Golden Sansam"}, {13463, "Dreamfoil"},
	{13465, "Mountain Silversage"}, {13466, "Plaguebloom"}, {13467, "Icecap"}, {13468, "Black Lotus"},
	{249399, "Frilled Lichen"}, {249424, "Rosecap"}, {249274, "Stranglevine"},
	{248823, "Marefoil"}, {248821, "Demonsage"}, {248822, "Death Lotus"},
}

local ORE_ITEMS = {
	{2770, "Copper Ore"}, {2771, "Tin Ore"}, {2775, "Silver Ore"}, {2772, "Iron Ore"},
	{2776, "Gold Ore"}, {3858, "Mithril Ore"}, {7911, "Truesilver Ore"}, {10620, "Thorium Ore"},
	{11370, "Dark Iron Ore"}, {18562, "Elementium Ore"},
	{249391, "Pyrite"}, {249425, "Bauxite"}, {249426, "Pitchblende"},
	{248815, "Heavy Thorium Ore"}, {248819, "Fel Crystal"}, {248820, "Torbernite"},
}

-- Raw skins (not cured hides, not Enchanted Leather).
local SKIN_ITEMS = {
	{2934, "Ruined Leather Scraps"}, {2318, "Light Leather"}, {2319, "Medium Leather"},
	{4234, "Heavy Leather"}, {4304, "Thick Leather"}, {8170, "Rugged Leather"},
	{783, "Light Hide"}, {4232, "Medium Hide"}, {4235, "Heavy Hide"},
	{8169, "Thick Hide"}, {8171, "Rugged Hide"},
	{6470, "Deviate Scale"}, {6471, "Perfect Deviate Scale"}, {5785, "Thick Murloc Scale"},
	{8154, "Scorpid Scale"}, {15408, "Heavy Scorpid Scale"}, {8167, "Turtle Scale"},
	{15416, "Black Dragonscale"}, {15415, "Blue Dragonscale"}, {15412, "Green Dragonscale"},
	{15414, "Red Dragonscale"}, {8165, "Worn Dragonscale"}, {15410, "Scale of Onyxia"},
	{15417, "Devilsaur Leather"}, {17012, "Core Leather"}, {15423, "Chimera Leather"},
	{15422, "Frostsaber Leather"}, {15419, "Warbear Leather"},
	{249427, "Pristine Leather"}, {249428, "Pristine Hide"}, {249429, "Pristine Scale"},
	{248825, "Fel Leather"}, {248824, "Fel Hide"},
}

local SKILL_HERBALISM = 182
local SKILL_MINING = 186
local SKILL_SKINNING = 393
local SPELL_HERBALISM = 2366
local SPELL_MINING = 2575
local SPELL_SKINNING = 8613

local data = {
	herbalism = false,
	mining = false,
	skinning = false,
	text = "",
	items = {},
	herbs = {},
	ores = {},
	skins = {},
	leathers = {},
}

AuctionworthyWA = setmetatable({}, {
	__index = data,
	__newindex = function() end,
	__metatable = false,
})

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

local function PublicNumber(value)
	value = tonumber(value)
	if not value or Secret(value) then
		return nil
	end
	return value
end

local function PublicString(value)
	if Secret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function HasSpell(spellID)
	if type(IsPlayerSpell) == "function" then
		local ok, known = pcall(IsPlayerSpell, spellID)
		if ok and not Secret(known) and known then
			return true
		end
	end
	if type(IsSpellKnown) == "function" then
		local ok, known = pcall(IsSpellKnown, spellID)
		if ok and not Secret(known) and known then
			return true
		end
	end
	return false
end

local function SkillLineFromProfession(index)
	if not index or type(GetProfessionInfo) ~= "function" then
		return nil, nil
	end
	local ok, name, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, index)
	if not ok then
		return nil, nil
	end
	return PublicNumber(skillLine), PublicString(name)
end

local function NameLooksLike(name, needle)
	if not name then
		return false
	end
	return string.lower(name) == needle
end

local function PlayerHasGathering()
	local herbalism = HasSpell(SPELL_HERBALISM)
	local mining = HasSpell(SPELL_MINING)
	local skinning = HasSpell(SPELL_SKINNING)
	if type(GetProfessions) == "function" then
		local ok, a, b, c, d, e = pcall(GetProfessions)
		if ok then
			local list = { a, b, c, d, e }
			for i = 1, #list do
				local skillLine, name = SkillLineFromProfession(list[i])
				if skillLine == SKILL_HERBALISM or NameLooksLike(name, "herbalism") then
					herbalism = true
				elseif skillLine == SKILL_MINING or NameLooksLike(name, "mining") then
					mining = true
				elseif skillLine == SKILL_SKINNING or NameLooksLike(name, "skinning") then
					skinning = true
				end
			end
		end
	end
	return herbalism, mining, skinning
end

local function ItemCount(itemID)
	if C_Item and C_Item.GetItemCount then
		local ok, count = pcall(C_Item.GetItemCount, itemID, false)
		count = PublicNumber(count)
		if ok and count and count > 0 then
			return count
		end
	end
	if type(GetItemCount) == "function" then
		local ok, count = pcall(GetItemCount, itemID, false)
		count = PublicNumber(count)
		if ok and count and count > 0 then
			return count
		end
	end
	return 0
end

local function ItemName(itemID, fallback)
	if C_Item and C_Item.GetItemNameByID then
		local ok, name = pcall(C_Item.GetItemNameByID, itemID)
		if ok then
			name = PublicString(name)
			if name then
				return name
			end
		end
	end
	if C_Item and C_Item.GetItemInfo then
		local ok, name = pcall(C_Item.GetItemInfo, itemID)
		if ok then
			name = PublicString(name)
			if name then
				return name
			end
		end
	end
	if type(GetItemInfo) == "function" then
		local ok, name = pcall(GetItemInfo, itemID)
		if ok then
			name = PublicString(name)
			if name then
				return name
			end
		end
		ok, name = pcall(GetItemInfo, "item:" .. itemID)
		if ok then
			name = PublicString(name)
			if name then
				return name
			end
		end
	end
	return fallback or ("item:" .. itemID)
end

local function ItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
		if ok then
			icon = PublicNumber(icon)
			if icon then
				return icon
			end
		end
	end
	if type(GetItemIcon) == "function" then
		local ok, icon = pcall(GetItemIcon, itemID)
		if ok then
			icon = PublicNumber(icon)
			if icon then
				return icon
			end
		end
	end
	return 134400
end

local function PostingUnit(itemID)
	if Auctionworthy and Auctionworthy.PostingPriceByItemID then
		local ok, price = pcall(Auctionworthy.PostingPriceByItemID, Auctionworthy, itemID)
		if ok then
			return PublicNumber(price)
		end
	end
	if Auctionworthy and Auctionworthy.GetAuctionPriceByItemID then
		local ok, price = pcall(Auctionworthy.GetAuctionPriceByItemID, Auctionworthy, itemID)
		if ok then
			return PublicNumber(price)
		end
	end
end

local function VendorUnit(itemID)
	if not (C_Item and C_Item.GetItemInfo) then
		return 0
	end
	local ok, _, _, _, _, _, itemType, subType, _, _, _, vendorPrice, classID, subclassID = pcall(C_Item.GetItemInfo, itemID)
	if not ok then
		return 0
	end
	vendorPrice = PublicNumber(vendorPrice) or 0
	if Auctionworthy and Auctionworthy.VendorSellPrice then
		local vok, sell = pcall(Auctionworthy.VendorSellPrice, Auctionworthy, vendorPrice, classID, subclassID, itemType, subType)
		if vok then
			return PublicNumber(sell) or 0
		end
	end
	return vendorPrice
end

local function StackVerdict(posting, vendor, count)
	if not posting or not Auctionworthy then
		return
	end
	local auction = posting * count
	local vendorStack = (vendor or 0) * count
	local fn
	if vendorStack > 0 then
		fn = Auctionworthy.VendorVerdict
	else
		fn = Auctionworthy.NonVendorVerdict
	end
	if not fn then
		return
	end
	local ok, verdict = pcall(fn, Auctionworthy, auction, vendorStack)
	if ok then
		return verdict
	end
end

-- ForeverAuras: AuctionworthyWA.itemahprice(itemID) / itemprofit(itemID)
-- Copper strings. 1s = "100". No AH listing = "-0" (tonumber-safe).
local NONE = "-0"

local function ItemArg(a, b)
	if type(a) == "table" then
		a = b
	end
	return PublicNumber(a)
end

local function CopperReply(value)
	value = PublicNumber(value)
	if not value then
		return NONE
	end
	value = math.floor(value)
	if value == 0 then
		return "0"
	end
	return tostring(value)
end

function data.itemahprice(a, b)
	local itemID = ItemArg(a, b)
	if not itemID then
		return NONE
	end
	local unit = PostingUnit(itemID)
	if not unit then
		return NONE
	end
	return CopperReply(unit)
end

function data.itemprofit(a, b)
	local itemID = ItemArg(a, b)
	if not itemID then
		return NONE
	end
	local unit = PostingUnit(itemID)
	if not unit then
		return NONE
	end
	local vendor = VendorUnit(itemID) or 0
	local verdict = StackVerdict(unit, vendor, 1)
	local net = verdict and PublicNumber(verdict.profit)
	if not net then
		net = unit - math.floor(unit * 0.05)
	end
	local vendorCopper = (verdict and PublicNumber(verdict.vendorPrice)) or vendor
	if not vendorCopper then
		vendorCopper = 0
	end
	return CopperReply(net - vendorCopper)
end

local function MoneyText(copper)
	if not copper then
		return "no price"
	end
	if Auctionworthy and Auctionworthy.FormatChatMoney then
		local ok, text = pcall(Auctionworthy.FormatChatMoney, Auctionworthy, copper)
		if ok then
			text = PublicString(text)
			if text then
				return text
			end
		end
	end
	local value = math.floor(tonumber(copper) or 0)
	if value <= 0 then
		return "0c"
	end
	local gold = math.floor(value / 10000)
	local silver = math.floor((value % 10000) / 100)
	local cop = value % 100
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = gold .. "g"
	end
	if silver > 0 then
		parts[#parts + 1] = silver .. "s"
	end
	if cop > 0 or #parts == 0 then
		parts[#parts + 1] = cop .. "c"
	end
	return table.concat(parts, " ")
end

local function PadRight(s, width)
	s = s or ""
	local extra = width - #s
	if extra > 0 then
		return s .. string.rep(" ", extra)
	end
	return s
end

local function ColumnWidths(...)
	local maxLeft = 0
	local maxAh = 0
	for n = 1, select("#", ...) do
		local rows = select(n, ...)
		for i = 1, #rows do
			local left = string.format("%s (%d)", rows[i].name, rows[i].count)
			local ah = MoneyText(rows[i].total)
			if #left > maxLeft then
				maxLeft = #left
			end
			if #ah > maxAh then
				maxAh = #ah
			end
		end
	end
	return maxLeft, maxAh
end

local function AlignRows(rows, maxLeft, maxAh)
	for i = 1, #rows do
		local r = rows[i]
		local left = PadRight(string.format("%s (%d)", r.name, r.count), maxLeft)
		local ah = PadRight(MoneyText(r.total), maxAh)
		if r.profit then
			r.line = string.format("|T%d:16:16:0:0|t %s  %s (%s)", r.icon, left, ah, MoneyText(r.profit))
		else
			r.line = string.format("|T%d:16:16:0:0|t %s  %s", r.icon, left, ah)
		end
	end
end

local function Collect(items)
	local rows = {}
	for i = 1, #items do
		local itemID = items[i][1]
		local fallback = items[i][2]
		local count = ItemCount(itemID)
		if count > 0 then
			local unit = PostingUnit(itemID)
			local ah, profit
			if unit then
				local verdict = StackVerdict(unit, VendorUnit(itemID), count)
				ah = (verdict and PublicNumber(verdict.auctionPrice)) or (unit * count)
				profit = verdict and PublicNumber(verdict.profit)
				if not (verdict and verdict.beatsVendor and profit and profit > 0) then
					profit = nil
				end
			end
			rows[#rows + 1] = {
				id = itemID,
				name = ItemName(itemID, fallback),
				icon = ItemIcon(itemID),
				count = count,
				unit = unit,
				total = ah,
				profit = profit,
			}
		end
	end
	table.sort(rows, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)
	return rows
end

local function AppendGroup(lines, title, rows)
	if #rows == 0 then
		return
	end
	if #lines > 0 then
		lines[#lines + 1] = ""
	end
	lines[#lines + 1] = title
	for i = 1, #rows do
		lines[#lines + 1] = rows[i].line
	end
end

local function FireAura(text)
	local seen = {}
	local function try(ns)
		if type(ns) == "table" and type(ns.ScanEvents) == "function" and not seen[ns] then
			seen[ns] = true
			pcall(ns.ScanEvents, "AUCTIONWORTHY_GATHER", text)
		end
	end
	try(_G.ForeverAuras)
	try(_G.EverAuras)
	try(_G.WeakAuras)
end

local lastText

local function ShowAllProfessions()
	return Auctionworthy and Auctionworthy.GetOption and Auctionworthy:GetOption("showAllGatherProfessions") and true or false
end

local function Refresh()
	local herbalism, mining, skinning = PlayerHasGathering()
	local showAll = ShowAllProfessions()
	local herbs = (showAll or herbalism) and Collect(HERB_ITEMS) or {}
	local ores = (showAll or mining) and Collect(ORE_ITEMS) or {}
	local skins = (showAll or skinning) and Collect(SKIN_ITEMS) or {}
	local items = {}
	for i = 1, #herbs do
		items[#items + 1] = herbs[i]
	end
	for i = 1, #ores do
		items[#items + 1] = ores[i]
	end
	for i = 1, #skins do
		items[#items + 1] = skins[i]
	end
	local maxLeft, maxAh = ColumnWidths(herbs, ores, skins)
	AlignRows(herbs, maxLeft, maxAh)
	AlignRows(ores, maxLeft, maxAh)
	AlignRows(skins, maxLeft, maxAh)
	local lines = {}
	AppendGroup(lines, "Herbs", herbs)
	AppendGroup(lines, "Ore", ores)
	AppendGroup(lines, "Leathers", skins)
	local text = table.concat(lines, "\n")
	data.herbalism = herbalism
	data.mining = mining
	data.skinning = skinning
	data.herbs = herbs
	data.ores = ores
	data.skins = skins
	data.leathers = skins
	data.items = items
	data.text = text
	if text ~= lastText then
		lastText = text
		FireAura(text)
	end
	if Auctionworthy.UpdateGatherList then
		Auctionworthy:UpdateGatherList()
	end
end

function Auctionworthy:RefreshGatherSnapshot()
	Refresh()
end

local pending
local function QueueRefresh()
	if pending then
		return
	end
	pending = true
	C_Timer.After(0.15, function()
		pending = false
		Refresh()
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		Refresh()
	else
		QueueRefresh()
	end
end)
