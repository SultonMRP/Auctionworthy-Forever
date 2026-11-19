-- Optional. Commented out in both TOC files, so it does not load.
-- Uncomment Modules/auctionworthy-debug.lua and add AuctionworthyDebug to
-- SavedVariables to enable /worthy dump, /worthy row, and /worthy clear.

local clickDebug
local lastDump
local dumpFrame
local dumpEdit

local function Secret(value)
	return Auctionworthy:Secret(value)
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

local function LineColor(fs)
	if not fs or not fs.GetTextColor then
		return ""
	end
	local ok, r, g, b = pcall(fs.GetTextColor, fs)
	if not ok then
		return ""
	end
	r = tonumber(r) or 0
	g = tonumber(g) or 0
	b = tonumber(b) or 0
	return string.format("%.2f,%.2f,%.2f", r, g, b)
end

local function LineLinks(raw)
	if type(raw) ~= "string" then
		return ""
	end
	local bits = {}
	for kind, rest in raw:gmatch("|H([^:]+):([^|]+)|h") do
		bits[#bits + 1] = kind .. ":" .. rest
	end
	return table.concat(bits, " ")
end

local function TooltipName(tooltip)
	if tooltip and tooltip.GetName then
		local ok, name = pcall(tooltip.GetName, tooltip)
		if ok and type(name) == "string" then
			return name
		end
	end
	return "?"
end

local function TooltipItem(tooltip)
	if not tooltip or not tooltip.GetItem then
		return
	end
	local ok, name, link = pcall(tooltip.GetItem, tooltip)
	if ok and type(link) == "string" and not Secret(link) then
		return Strip(name), link, Auctionworthy:ItemID(link)
	end
end

local function TooltipSpell(tooltip)
	if not tooltip or not tooltip.GetSpell then
		return
	end
	local ok, name, rank, id = pcall(tooltip.GetSpell, tooltip)
	if not ok then
		return
	end
	if Secret(name) or Secret(rank) or Secret(id) then
		return
	end
	return name, rank, tonumber(id)
end

local function IsStopLine(plain)
	local lower = strlower(plain)
	if lower:find("^permanently") or lower:find("^requires ") then
		return true
	end
	if lower:find("^creates") or lower:find("^use:") or lower:find("charges") then
		return true
	end
	if lower:find("^spellid") or lower:find("^iconid") then
		return true
	end
	if lower:find("^no auction") or lower:find("^undercut") then
		return true
	end
	if lower:find("^auction ") or lower:find("^sell price") then
		return true
	end
	if lower:find("^itemid") or lower:find("^deposit") then
		return true
	end
	return false
end

local function IsEnchantingTitle(plain)
	return type(plain) == "string" and strlower(plain):find("^enchanting:") and true or false
end

local function CollectBlock(stripped, label)
	local out = {}
	local capture = false
	local prefix = strlower(label) .. ":"
	for _, plain in ipairs(stripped) do
		local lower = strlower(plain)
		if not capture then
			if lower:find("^" .. prefix, 1) then
				capture = true
				out[#out + 1] = strtrim(plain:sub(#label + 2))
			end
		else
			if IsStopLine(plain) or lower:find("^tools:") or lower:find("^reagents:") then
				break
			end
			if plain:find("%.") then
				break
			end
			out[#out + 1] = plain
		end
	end
	return strtrim(table.concat(out, " "))
end

local function ParseNamedCounts(blob)
	local rows = {}
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

local function BuildDump(tooltip)
	local name = TooltipName(tooltip)
	local n = tooltip and tooltip.NumLines and tooltip:NumLines() or 0
	local itemName, itemLink, itemID = TooltipItem(tooltip)
	local spellName, spellRank, spellID = TooltipSpell(tooltip)
	local rawLeft = {}
	local stripped = {}
	local lines = {}
	lines[#lines + 1] = "== Auctionworthy tooltip dump =="
	lines[#lines + 1] = "tooltip=" .. name
	lines[#lines + 1] = "numLines=" .. tostring(n)
	if itemLink then
		lines[#lines + 1] = "itemName=" .. tostring(itemName)
		lines[#lines + 1] = "itemLink=" .. itemLink
		lines[#lines + 1] = "itemID=" .. tostring(itemID)
	end
	if spellName or spellID then
		lines[#lines + 1] = "spellName=" .. tostring(spellName)
		lines[#lines + 1] = "spellRank=" .. tostring(spellRank)
		lines[#lines + 1] = "spellID=" .. tostring(spellID)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- lines --"
	for i = 1, n do
		local leftFS = _G[name .. "TextLeft" .. i]
		local rightFS = _G[name .. "TextRight" .. i]
		local left = leftFS and leftFS.GetText and leftFS:GetText()
		local right = rightFS and rightFS.GetText and rightFS:GetText()
		if type(left) == "string" and Secret(left) then
			left = "<secret>"
		end
		if type(right) == "string" and Secret(right) then
			right = "<secret>"
		end
		left = left or ""
		right = right or ""
		local plain = Strip(left)
		rawLeft[#rawLeft + 1] = left
		stripped[#stripped + 1] = plain
		lines[#lines + 1] = string.format(
			"L%d left=%s right=%s rgb=%s links=%s",
			i,
			plain,
			Strip(right),
			LineColor(leftFS),
			LineLinks(left)
		)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- stripped --"
	for i, plain in ipairs(stripped) do
		lines[#lines + 1] = i .. ": " .. plain
	end
	local title = stripped[1] or ""
	local profession, recipe = title:match("^([^:]+):%s*(.+)$")
	local tools = CollectBlock(stripped, "Tools")
	local reagents = CollectBlock(stripped, "Reagents")
	lines[#lines + 1] = ""
	lines[#lines + 1] = "-- parse try --"
	lines[#lines + 1] = "profession=" .. tostring(profession)
	lines[#lines + 1] = "recipe=" .. tostring(recipe)
	lines[#lines + 1] = "toolsRaw=" .. tools
	lines[#lines + 1] = "reagentsRaw=" .. reagents
	local toolRows = ParseNamedCounts(tools)
	for i, row in ipairs(toolRows) do
		lines[#lines + 1] = "tool" .. i .. "=" .. row.qty .. "x " .. row.name
	end
	local reagentRows = ParseNamedCounts(reagents)
	for i, row in ipairs(reagentRows) do
		lines[#lines + 1] = "reagent" .. i .. "=" .. row.qty .. "x " .. row.name
	end
	if #reagentRows == 0 then
		lines[#lines + 1] = "reagentCount=0"
	end
	return table.concat(lines, "\n"), IsEnchantingTitle(title)
end

local function EnsureFrame()
	if dumpFrame then
		return dumpFrame
	end
	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "AuctionworthyDebugFrame", UIParent, template)
	frame:SetSize(560, 420)
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
	tinsert(UISpecialFrames, "AuctionworthyDebugFrame")

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -10)
	title:SetText("Auctionworthy dump")

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	hint:SetPoint("TOP", 0, -30)
	hint:SetText("Ctrl+C copies the selected text. /worthy dump")

	local scroll = CreateFrame("ScrollFrame", "AuctionworthyDebugScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -50)
	scroll:SetPoint("BOTTOMRIGHT", -36, 44)

	local edit = CreateFrame("EditBox", "AuctionworthyDebugEdit", scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(true)
	edit:SetFontObject(GameFontHighlightSmall)
	edit:SetWidth(500)
	edit:SetMaxLetters(20000)
	edit:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(edit)

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(80, 22)
	close:SetPoint("BOTTOMRIGHT", -16, 12)
	close:SetText("Close")
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	selectAll:SetSize(90, 22)
	selectAll:SetPoint("RIGHT", close, "LEFT", -8, 0)
	selectAll:SetText("Select all")
	selectAll:SetScript("OnClick", function()
		edit:SetFocus()
		edit:HighlightText()
	end)

	dumpFrame = frame
	dumpEdit = edit
	return frame
end

local SAVED_LIMIT = 20

local function DebugStore()
	if type(AuctionworthyDebug) ~= "table" then
		AuctionworthyDebug = {}
	end
	if type(AuctionworthyDebug.rows) ~= "table" then
		AuctionworthyDebug.rows = {}
	end
	if type(AuctionworthyDebug.dumps) ~= "table" then
		AuctionworthyDebug.dumps = {}
	end
	return AuctionworthyDebug
end

local function SaveDump(kind, text)
	if type(text) ~= "string" or text == "" then
		return
	end
	local store = DebugStore()
	local bucket = kind == "row" and store.rows or store.dumps
	local entry = {
		time = date and date("%Y-%m-%d %H:%M:%S") or "",
		text = text,
	}
	table.insert(bucket, 1, entry)
	while #bucket > SAVED_LIMIT do
		table.remove(bucket)
	end
	if kind == "row" then
		store.lastRow = text
	else
		store.lastDump = text
	end
end

local function ShowDump(text, kind)
	if type(text) ~= "string" or text == "" then
		return
	end
	lastDump = text
	if kind == "row" then
		SaveDump("row", text)
		print("|cff00ff00Auctionworthy:|r Debug dump complete, please reload, and report")
		return
	end
	SaveDump(kind or "dump", text)
	EnsureFrame()
	dumpEdit:SetText(text)
	dumpFrame:Show()
	dumpEdit:SetFocus()
	dumpEdit:HighlightText()
end

function Auctionworthy:ShowDump(text)
	ShowDump(text)
end

local function ShownTooltip()
	if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
		return GameTooltip
	end
	if ItemRefTooltip and ItemRefTooltip.IsShown and ItemRefTooltip:IsShown() then
		return ItemRefTooltip
	end
end

local function DumpTooltip(tooltip)
	if not tooltip then
		return
	end
	local text, enchanting = BuildDump(tooltip)
	if enchanting then
		lastDump = text
	end
	return text, enchanting
end

local function Remember(tooltip)
	local text, enchanting = DumpTooltip(tooltip)
	if enchanting then
		lastDump = text
	end
end

local function ClickDump(tooltip)
	if not tooltip or not Auctionworthy:ModifierDown() then
		return
	end
	local text, enchanting = DumpTooltip(tooltip)
	if enchanting then
		ShowDump(text, "click")
	end
end

function Auctionworthy:ReportClick(text)
	if not clickDebug then
		return
	end
	if type(text) ~= "string" or text == "" then
		return
	end
	print("|cff00ff00Auctionworthy:|r " .. text)
end

function Auctionworthy:ToggleClickDebug()
	clickDebug = not clickDebug
	if clickDebug then
		print("|cff00ff00Auctionworthy:|r click debug on. Share-key click an Enchanting: tooltip, or /worthy dump.")
	else
		print("|cff00ff00Auctionworthy:|r click debug off.")
	end
end

function Auctionworthy:DumpShownTooltip()
	local tooltip = ShownTooltip()
	if tooltip then
		ShowDump(DumpTooltip(tooltip), "dump")
		return
	end
	if lastDump then
		ShowDump(lastDump)
		return
	end
	print("|cff00ff00Auctionworthy:|r No tooltip to dump. Hover an Enchanting: recipe, then /worthy dump.")
end

local function Watch(tooltip)
	if not tooltip then
		return
	end
	tooltip:HookScript("OnShow", function(self)
		Remember(self)
	end)
	tooltip:HookScript("OnMouseDown", function(self, button)
		if button == "RightButton" then
			return
		end
		ClickDump(self)
	end)
end

Watch(GameTooltip)
Watch(ItemRefTooltip)

if type(SetItemRef) == "function" then
	hooksecurefunc("SetItemRef", function()
		if not Auctionworthy:ModifierDown() then
			return
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				if ItemRefTooltip and ItemRefTooltip.IsShown and ItemRefTooltip:IsShown() then
					ClickDump(ItemRefTooltip)
				end
			end)
		end
	end)
end

local function RowSafe(value)
	if value == nil then
		return "nil"
	end
	if issecretvalue and issecretvalue(value) then
		return "<secret>"
	end
	local kind = type(value)
	if kind == "number" or kind == "boolean" then
		return tostring(value)
	end
	if kind ~= "string" then
		return kind
	end
	local itemID = value:match("item:(%d+)")
	if itemID then
		return "item:" .. itemID
	end
	value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	value = value:gsub("|H.-|h%[(.-)%]|h", "[%1]")
	value = value:gsub("|H.-|h(.-)|h", "%1")
	return value
end

local function RowFrameName(frame)
	if not frame then
		return "nil"
	end
	if frame.GetName then
		local ok, name = pcall(frame.GetName, frame)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	if frame.GetObjectType then
		local ok, kind = pcall(frame.GetObjectType, frame)
		if ok then
			return RowSafe(kind)
		end
	end
	return "frame"
end

local function AppendTable(lines, prefix, value, depth, seen)
	if depth > 5 then
		lines[#lines + 1] = prefix .. "<deep>"
		return
	end
	if type(value) ~= "table" or (issecretvalue and issecretvalue(value)) then
		lines[#lines + 1] = prefix .. RowSafe(value)
		return
	end
	if seen[value] then
		lines[#lines + 1] = prefix .. "<cycle>"
		return
	end
	seen[value] = true
	local names = {}
	local ok = pcall(function()
		for key in pairs(value) do
			names[#names + 1] = key
		end
	end)
	if not ok then
		lines[#lines + 1] = prefix .. "<pairs failed>"
		return
	end
	table.sort(names, function(a, b)
		return tostring(a) < tostring(b)
	end)
	if #names == 0 then
		lines[#lines + 1] = prefix .. "{}"
		return
	end
	for i = 1, #names do
		local key = names[i]
		local childOk, child = pcall(function()
			return value[key]
		end)
		local label = prefix .. tostring(key)
		if not childOk then
			lines[#lines + 1] = label .. "=<read failed>"
		elseif type(child) == "function" then
		elseif type(child) == "table" then
			lines[#lines + 1] = label .. ":"
			AppendTable(lines, prefix .. "  ", child, depth + 1, seen)
		else
			lines[#lines + 1] = label .. "=" .. RowSafe(child)
		end
	end
end

local function AppendTexture(lines, label, texture)
	if not texture or type(texture) ~= "table" then
		return
	end
	if texture.GetTextureFileID then
		local ok, fileID = pcall(texture.GetTextureFileID, texture)
		if ok then
			lines[#lines + 1] = label .. " fileID=" .. RowSafe(fileID)
		end
	end
	if texture.GetTexture then
		local ok, path = pcall(texture.GetTexture, texture)
		if ok then
			lines[#lines + 1] = label .. " texture=" .. RowSafe(path)
		end
	end
end

local function AppendItemFacts(lines, label, item)
	if item == nil or (issecretvalue and issecretvalue(item)) then
		return
	end
	lines[#lines + 1] = label .. "=" .. RowSafe(item)
	if C_Item and C_Item.GetItemInfoInstant then
		local ok, id, _, _, _, icon, classID, subClassID = pcall(C_Item.GetItemInfoInstant, item)
		if ok then
			lines[#lines + 1] = label .. " instant id=" .. RowSafe(id) .. " icon=" .. RowSafe(icon) .. " class=" .. RowSafe(classID) .. " subclass=" .. RowSafe(subClassID)
		end
	end
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, item)
		if ok then
			lines[#lines + 1] = label .. " iconByID=" .. RowSafe(icon)
		end
	end
	if C_Item and C_Item.GetItemInfo then
		local ok, name, _, _, _, _, _, _, _, _, texture = pcall(C_Item.GetItemInfo, item)
		if ok then
			lines[#lines + 1] = label .. " info name=" .. RowSafe(name) .. " texture=" .. RowSafe(texture)
		end
	end
end

local function AppendRowData(lines, data, prefix)
	if type(data) ~= "table" or (issecretvalue and issecretvalue(data)) then
		return
	end
	AppendTable(lines, prefix, data, 0, {})
	local itemKey
	pcall(function()
		itemKey = data.itemKey
	end)
	local itemID
	if type(itemKey) == "table" then
		itemID = itemKey.itemID
	end
	itemID = itemID or data.itemID
	if itemID ~= nil then
		AppendItemFacts(lines, prefix .. "item", itemID)
	end
	if data.itemLink ~= nil then
		AppendItemFacts(lines, prefix .. "link", data.itemLink)
	end
	if type(itemKey) == "table" and C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo then
		local ok, info = pcall(C_AuctionHouse.GetItemKeyInfo, itemKey)
		lines[#lines + 1] = prefix .. "GetItemKeyInfo:"
		if ok and type(info) == "table" then
			AppendTable(lines, prefix .. "  ", info, 0, {})
		else
			lines[#lines + 1] = prefix .. "  " .. RowSafe(ok and info or "err")
		end
	end
end

local function MouseFrames()
	local frames = {}
	if GetMouseFoci then
		local ok, foci = pcall(GetMouseFoci)
		if ok and type(foci) == "table" then
			for i = 1, #foci do
				frames[#frames + 1] = foci[i]
			end
		end
	end
	if #frames == 0 and GetMouseFocus then
		local ok, focus = pcall(GetMouseFocus)
		if ok and focus then
			frames[1] = focus
		end
	end
	return frames
end

local function DumpAuctionRow()
	local lines = { "----- auction row -----" }
	local frames = MouseFrames()
	if #frames == 0 then
		lines[#lines + 1] = "mouse=nothing"
	end
	local seen = {}
	for i = 1, #frames do
		local frame = frames[i]
		for _ = 1, 14 do
			if not frame or seen[frame] then
				break
			end
			seen[frame] = true
			lines[#lines + 1] = "frame=" .. RowFrameName(frame)
			AppendTexture(lines, "  icon", frame.Icon)
			AppendTexture(lines, "  texture", frame)
			if frame.GetRegions then
				local regionOk, r1, r2, r3, r4, r5, r6 = pcall(frame.GetRegions, frame)
				if regionOk then
					local regions = { r1, r2, r3, r4, r5, r6 }
					for r = 1, #regions do
						AppendTexture(lines, "  region" .. r, regions[r])
					end
				end
			end
			local data
			if frame.rowData ~= nil then
				data = frame.rowData
				lines[#lines + 1] = "source=rowData"
			elseif frame.GetElementData then
				local elementOk, element = pcall(frame.GetElementData, frame)
				if elementOk and type(element) == "table" then
					data = element
					lines[#lines + 1] = "source=elementData"
				end
			end
			AppendRowData(lines, data, "  ")
			if not frame.GetParent then
				break
			end
			local parentOk, parent = pcall(frame.GetParent, frame)
			if not parentOk then
				break
			end
			frame = parent
		end
	end
	if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
		lines[#lines + 1] = "tooltip=GameTooltip lines=" .. RowSafe(GameTooltip.NumLines and GameTooltip:NumLines())
		if GameTooltip.GetItem then
			local ok, name, link = pcall(GameTooltip.GetItem, GameTooltip)
			if ok then
				lines[#lines + 1] = "GetItem name=" .. RowSafe(name)
				AppendItemFacts(lines, "GetItem", link)
			end
		end
		if GameTooltip.GetPrimaryTooltipData then
			local ok, data = pcall(GameTooltip.GetPrimaryTooltipData, GameTooltip)
			if ok and type(data) == "table" and not (issecretvalue and issecretvalue(data)) then
				lines[#lines + 1] = "primary:"
				AppendTable(lines, "  ", data, 0, {})
				local linkOk, link = pcall(function()
					return data.hyperlink
				end)
				if linkOk then
					AppendItemFacts(lines, "hyperlink", link)
				end
				local idOk, id = pcall(function()
					return data.id
				end)
				if idOk then
					AppendItemFacts(lines, "primaryID", id)
				end
			end
		end
		local name = GameTooltip.GetName and GameTooltip:GetName()
		if type(name) == "string" then
			local count = GameTooltip.NumLines and GameTooltip:NumLines() or 0
			for i = 1, count do
				local left = _G[name .. "TextLeft" .. i]
				local text
				if left and left.GetText then
					local textOk, value = pcall(left.GetText, left)
					if textOk then
						text = value
					end
				end
				lines[#lines + 1] = "line" .. i .. "=" .. RowSafe(text)
			end
		end
	end
	return table.concat(lines, "\n")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
	DebugStore()
end)

local original = SlashCmdList.AUCTIONWORTHY
SlashCmdList.AUCTIONWORTHY = function(msg)
	local raw = strlower(strtrim(tostring(msg or "")))
	if raw == "row" then
		ShowDump(DumpAuctionRow(), "row")
		return
	end
	if raw == "clear" then
		AuctionworthyDebug = { rows = {}, dumps = {} }
		print("|cff00ff00Auctionworthy:|r AuctionworthyDebug cleared.")
		return
	end
	if raw == "dump" then
		Auctionworthy:DumpShownTooltip()
		return
	end
	if raw == "debug" then
		Auctionworthy:ToggleClickDebug()
		return
	end
	if raw == "help" then
		if original then
			original(msg)
		end
		print("  /worthy dump — copy the current tooltip")
		print("  /worthy row — hover an auction list row. Saves to AuctionworthyDebug, no window")
		print("  /worthy clear — wipe AuctionworthyDebug")
		return
	end
	if original then
		original(msg)
	end
end
