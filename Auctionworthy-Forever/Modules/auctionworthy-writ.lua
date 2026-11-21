-- Craftsman's Writ and Waylaid crate extras. Catalog is auctionworthy-wdatabase.lua
-- compiled from WaylaidCost (OptionalDeps; keep installed, disabled in-game).

local WRITS = AuctionworthyWrits or {}
local CRATE_META = AuctionworthyCrateMeta or {}
local CRATE_CASH = AuctionworthyCrateCashback or {}
local CRATE_USES = AuctionworthyCrateUses or {}

local byNeed = {}
for writID, row in pairs(WRITS) do
	local need = tonumber(row.need)
	if need then
		local list = byNeed[need]
		if not list then
			list = {}
			byNeed[need] = list
		end
		list[#list + 1] = writID
	end
end
for _, list in pairs(byNeed) do
	table.sort(list)
end

local function Secret(value)
	return Auctionworthy:Secret(value)
end

local function HasOrderLine(tooltip)
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return true
	end
	local name = tooltip.GetName and tooltip:GetName()
	if not name then
		return true
	end
	local n = tooltip.NumLines and tooltip:NumLines() or 0
	for i = 1, n do
		local fs = _G[name .. "TextLeft" .. i]
		local text = fs and fs.GetText and fs:GetText()
		if type(text) == "string" and not Secret(text) then
			local lower = strlower(text)
			if lower:find("^writ:") or lower:find("^writ need:") or lower:find("^crate:") or lower:find("^crate cashback:") then
				return true
			end
		end
	end
end

local function TooltipItemID(tooltip, data)
	if type(data) == "table" and not Secret(data) then
		local id = tonumber(data.id)
		if id and id > 0 then
			return id
		end
	end
	if tooltip and tooltip.GetItem then
		local ok, _, link = pcall(tooltip.GetItem, tooltip)
		if ok and Auctionworthy.ItemID then
			return Auctionworthy:ItemID(link)
		end
	end
end

local function AddWritCost(tooltip, row)
	local qty = tonumber(row.qty) or 1
	if qty < 1 then
		qty = 1
	end
	local cost
	if Auctionworthy.CraftReagentCost then
		cost = Auctionworthy:CraftReagentCost(row.need, qty)
	end
	local label = "Writ: " .. qty .. "x " .. (row.name or "item") .. ": "
	if cost and Auctionworthy.FormatGold then
		tooltip:AddLine(label .. Auctionworthy:FormatGold(cost), 1, 0.82, 0, true)
	elseif Auctionworthy.ShowNoAuctionData and Auctionworthy:ShowNoAuctionData() then
		tooltip:AddLine(label .. "No Auction Data", 1, 0, 1, true)
	end
	local where
	if row.npc and row.zone then
		where = row.npc .. ", " .. row.zone
	else
		where = row.zone or row.npc
	end
	if type(where) == "string" and where ~= "" then
		tooltip:AddLine("Writ: " .. where, 0.65, 0.85, 1, true)
	end
	local rep = tonumber(row.rep)
	if rep and rep > 0 then
		tooltip:AddLine("Writ: " .. tostring(rep) .. " trade rep", 0.65, 0.85, 1, true)
	end
end

local function AddWritUses(tooltip, needID)
	local list = byNeed[needID]
	if not list then
		return
	end
	for i = 1, #list do
		local row = WRITS[list[i]]
		if row and row.writ then
			tooltip:AddLine("Writ need: " .. row.writ, 1, 0.82, 0, true)
		end
	end
end

local function AddCrateCashback(tooltip, meta)
	local family = meta and meta.family
	local quality = meta and tonumber(meta.quality)
	local byQuality = family and CRATE_CASH[family]
	local copper = byQuality and quality and tonumber(byQuality[quality])
	if not copper or copper < 1 or not Auctionworthy.FormatGold then
		return
	end
	tooltip:AddLine("Crate cashback: " .. Auctionworthy:FormatGold(copper), 0.35, 1, 0.3, true)
end

local function AddCrateUses(tooltip, needID)
	local list = CRATE_USES[needID]
	if type(list) ~= "table" then
		return
	end
	for i = 1, #list do
		local meta = CRATE_META[list[i]]
		local label = meta and meta.name
		if type(label) == "string" and label ~= "" then
			tooltip:AddLine("Crate: " .. label, 1, 0.82, 0, true)
		end
	end
end

function Auctionworthy:IsWritLink(link)
	local itemID = Auctionworthy:ItemID(link)
	return itemID and WRITS[itemID] and true or false
end

function Auctionworthy:WritQueryLines(link, qty)
	local itemID = Auctionworthy:ItemID(link)
	local row = itemID and WRITS[itemID]
	if not row then
		return
	end
	qty = tonumber(qty) or 1
	if qty < 1 then
		qty = 1
	end
	local goods = (tonumber(row.qty) or 1) * qty
	if goods < 1 then
		goods = 1
	end
	local shown = row.name and ("[" .. row.name .. "]") or "[item]"
	local needLink = row.need and Auctionworthy.ItemLink and Auctionworthy:ItemLink(row.need)
	if type(needLink) == "string" and needLink:find("|H", 1, true) and not Secret(needLink) then
		shown = needLink
	end
	local cost = Auctionworthy.CraftReagentCost and Auctionworthy:CraftReagentCost(row.need, goods)
	local money = "No Auction Data"
	if cost and Auctionworthy.FormatChatMoney then
		money = Auctionworthy:FormatChatMoney(cost)
	end
	local line = "Writ: " .. goods .. "x " .. shown .. " (" .. money .. ")"
	if #line > 255 and row.name then
		line = "Writ: " .. goods .. "x [" .. row.name .. "] (" .. money .. ")"
	end
	local where
	if row.npc and row.zone then
		where = row.npc .. ", " .. row.zone
	else
		where = row.zone or row.npc
	end
	local extra
	if type(where) == "string" and where ~= "" then
		extra = "Writ: " .. where
		local rep = tonumber(row.rep)
		if rep and rep > 0 then
			extra = extra .. " (" .. tostring(rep) .. " trade rep)"
		end
	elseif tonumber(row.rep) and row.rep > 0 then
		extra = "Writ: " .. tostring(row.rep) .. " trade rep"
	end
	return line, extra
end

function Auctionworthy:UpdateWritTooltip(tooltip, data)
	if not Auctionworthy.WaylaidInfo or not Auctionworthy:WaylaidInfo() then
		return
	end
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return
	end
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
		return
	end
	if HasOrderLine(tooltip) then
		return
	end
	local itemID = TooltipItemID(tooltip, data)
	if not itemID then
		return
	end
	local row = WRITS[itemID]
	if row then
		AddWritCost(tooltip, row)
		return
	end
	local crate = CRATE_META[itemID]
	if crate then
		AddCrateCashback(tooltip, crate)
		return
	end
	AddWritUses(tooltip, itemID)
	AddCrateUses(tooltip, itemID)
end

local function Update(tooltip, data)
	Auctionworthy:UpdateWritTooltip(tooltip, data)
end

local function Watch(tooltip)
	if not tooltip or not tooltip.HookScript then
		return
	end
	tooltip:HookScript("OnShow", function(self)
		Update(self)
	end)
end

Watch(GameTooltip)
Watch(ItemRefTooltip)

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if tooltip == GameTooltip or tooltip == ItemRefTooltip then
			Update(tooltip, data)
		end
	end)
end
