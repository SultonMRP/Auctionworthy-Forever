-- Chat recipe tooltips: reagent parse -> Auctionator To Craft math -> Total Cost.

local function Secret(value)
	return Auctionworthy:Secret(value)
end

local PROFESSION_TITLES = {
	["alchemy:"] = true,
	["blacksmithing:"] = true,
	["cooking:"] = true,
	["enchanting:"] = true,
	["engineering:"] = true,
	["first aid:"] = true,
	["leatherworking:"] = true,
	["mining:"] = true,
	["poisons:"] = true,
	["tailoring:"] = true,
}

function Auctionworthy:IsProfessionRecipeTitle(plain)
	if type(plain) ~= "string" or plain == "" then
		return
	end
	local t = strlower(plain)
	local colon = t:find(":", 1, true)
	if not colon then
		return
	end
	return PROFESSION_TITLES[t:sub(1, colon)] and true or false
end

local function Strip(text)
	if type(text) ~= "string" then
		return ""
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("|H.-|h%[(.-)%]|h", "%1")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("|n", " ")
	text = text:gsub("%s+", " ")
	return strtrim(text)
end

local function LeftLines(tooltip)
	local texts = {}
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return texts
	end
	local name = tooltip.GetName and tooltip:GetName()
	if not name then
		return texts
	end
	local n = tooltip.NumLines and tooltip:NumLines() or 0
	for i = 1, n do
		local fs = _G[name .. "TextLeft" .. i]
		local text = fs and fs.GetText and fs:GetText()
		if type(text) == "string" and not Secret(text) and text ~= "" then
			texts[#texts + 1] = Strip(text)
		end
	end
	return texts
end

local function IsStopLine(plain)
	local lower = strlower(plain)
	if lower:find("^permanently") or lower:find("^requires ") then
		return true
	end
	if lower:find("^creates") or lower:find("^use:") then
		return true
	end
	if lower:find("charges") then
		return true
	end
	if lower:find("^spellid") or lower:find("^iconid") then
		return true
	end
	if lower:find("^no auction") or lower:find("^undercut") then
		return true
	end
	if lower:find("^auction ") or lower:find("^sell price") or lower:find("^deposit") then
		return true
	end
	if lower:find("^total cost") or lower:find("^itemid") then
		return true
	end
	if lower:find("^tools:") then
		return true
	end
	return false
end

local function IsReagentWrap(plain)
	if IsStopLine(plain) or plain:find("%.") then
		return false
	end
	return plain:find(",") or plain:find("%(%d+%)") and true or false
end

local function CutFlavor(blob)
	if type(blob) ~= "string" then
		return ""
	end
	blob = blob:gsub("%s+[Cc]reates%s+.*$", "")
	blob = blob:gsub("%s+[Uu]se:%s*.*$", "")
	blob = blob:gsub("%s+[Pp]ermanently%s+.*$", "")
	return strtrim(blob:gsub(",%s*$", ""))
end

local RECIPE_ITEM_PREFIXES = {
	"pattern: ", "plans: ", "schematic: ", "recipe: ",
	"formula: ", "manual: ", "design: ", "technique: ",
}

local function IsRecipeItemTitle(plain)
	if type(plain) ~= "string" then
		return false
	end
	local lower = strlower(plain)
	for i = 1, #RECIPE_ITEM_PREFIXES do
		local prefix = RECIPE_ITEM_PREFIXES[i]
		if lower:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function ReagentBlob(lines)
	local parts = {}
	local capture = false
	for _, plain in ipairs(lines) do
		local lower = strlower(plain)
		if not capture then
			if lower:find("^reagents:") then
				capture = true
				parts[#parts + 1] = strtrim(plain:sub(10))
			end
		else
			if not IsReagentWrap(plain) then
				break
			end
			parts[#parts + 1] = plain
		end
	end
	local blob = CutFlavor(strtrim(table.concat(parts, " ")))
	if blob ~= "" then
		return blob
	end
	for _, plain in ipairs(lines) do
		if IsReagentWrap(plain) then
			return CutFlavor(plain)
		end
	end
	return ""
end

local function ParseReagents(blob)
	local rows = {}
	blob = CutFlavor(blob)
	if type(blob) ~= "string" or blob == "" then
		return rows
	end
	for chunk in blob:gmatch("[^,]+") do
		chunk = strtrim(chunk)
		if chunk ~= "" then
			local name, qty = chunk:match("^(.-)%s*%((%d+)%)%s*$")
			if name then
				rows[#rows + 1] = { name = strtrim(name), qty = tonumber(qty) or 1 }
			else
				rows[#rows + 1] = { name = chunk, qty = 1 }
			end
		end
	end
	return rows
end

local function HasTotalCost(lines)
	for _, plain in ipairs(lines) do
		if strlower(plain):find("^total cost:") then
			return true
		end
	end
	return false
end

function Auctionworthy:TooltipSpellID(tooltip)
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return
	end
	if tooltip.GetSpell then
		local ok, name, rank, id = pcall(tooltip.GetSpell, tooltip)
		if ok then
			if not Secret(id) then
				id = tonumber(id)
			else
				id = nil
			end
			if (not id or id < 1) and not Secret(rank) then
				id = tonumber(rank)
			end
			if id and id > 0 then
				return id
			end
		end
	end
	if tooltip.GetPrimaryTooltipData then
		local dataOk, data = pcall(tooltip.GetPrimaryTooltipData, tooltip)
		if dataOk and type(data) == "table" and not Secret(data) and type(data.lines) == "table" then
			for _, line in pairs(data.lines) do
				if type(line) == "table" and not Secret(line) and not Secret(line.spellID) then
					local sid = tonumber(line.spellID)
					if sid and sid > 0 then
						return sid
					end
				end
			end
		end
	end
	local tipName = tooltip.GetName and tooltip:GetName()
	if not tipName then
		return
	end
	local n = tooltip.NumLines and tooltip:NumLines() or 0
	for i = 1, n do
		local fs = _G[tipName .. "TextLeft" .. i]
		local text = fs and fs.GetText and fs:GetText()
		if type(text) == "string" and not Secret(text) and text ~= "" then
			local sid = text:match("[Ss]pell[Ii][Dd]:?%s*(%d+)")
			sid = tonumber(sid)
			if sid and sid > 0 then
				return sid
			end
		end
	end
end

function Auctionworthy:UpdateProfessionRecipeTooltip(tooltip, titlePrefix)
	if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then
		return
	end
	if Auctionworthy.SkipClicks and Auctionworthy:SkipClicks() then
		return
	end
	local lines = LeftLines(tooltip)
	local title = lines[1]
	if type(title) ~= "string" then
		return
	end
	local lower = strlower(title)
	if type(titlePrefix) == "string" and titlePrefix ~= "" then
		if not lower:find("^" .. strlower(titlePrefix) .. ":") then
			return
		end
	elseif not Auctionworthy:IsProfessionRecipeTitle(title) and not IsRecipeItemTitle(title) then
		return
	end
	if HasTotalCost(lines) then
		return
	end
	local reagents = ParseReagents(ReagentBlob(lines))
	local spellID = Auctionworthy:TooltipSpellID(tooltip)
	local atlas = spellID and Auctionworthy.AtlasReagents and Auctionworthy:AtlasReagents(spellID)
	if #reagents == 0 then
		if not atlas then
			return
		end
		reagents = atlas
	elseif atlas and #atlas == #reagents then
		for i, row in ipairs(reagents) do
			if not row.id and atlas[i] and atlas[i].id then
				row.id = atlas[i].id
			end
			if row.name and row.id and Auctionworthy.RememberMaterial then
				Auctionworthy:RememberMaterial(row.name, row.id)
			end
		end
	end
	local total = 0
	for _, row in ipairs(reagents) do
		local id = row.id
		if not id and row.name and Auctionworthy.MaterialItemID then
			id = Auctionworthy:MaterialItemID(row.name)
		end
		local cost
		if id and Auctionworthy.CraftReagentCost then
			cost = Auctionworthy:CraftReagentCost(id, row.qty)
		end
		if not cost then
			if Auctionworthy:ShowNoAuctionData() then
				tooltip:AddLine("Total Cost: No Auction Data", 1, 0, 1, true)
			end
			return
		end
		total = total + cost
	end
	tooltip:AddLine("Total Cost: " .. Auctionworthy:FormatGold(total), 1, 0.82, 0, true)
end

local function Update(tooltip)
	Auctionworthy:UpdateProfessionRecipeTooltip(tooltip)
end

local function Watch(tooltip)
	if not tooltip then
		return
	end
	tooltip:HookScript("OnShow", function(self)
		Update(self)
	end)
	if tooltip.SetSpellByID then
		hooksecurefunc(tooltip, "SetSpellByID", function(self)
			Update(self)
		end)
	end
	if tooltip.SetSpell then
		hooksecurefunc(tooltip, "SetSpell", function(self)
			Update(self)
		end)
	end
	if tooltip.SetHyperlink then
		hooksecurefunc(tooltip, "SetHyperlink", function(self)
			Update(self)
		end)
	end
end

Watch(GameTooltip)
Watch(ItemRefTooltip)

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	if Enum.TooltipDataType.Spell then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, Update)
	end
	if Enum.TooltipDataType.Item then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Update)
	end
end
