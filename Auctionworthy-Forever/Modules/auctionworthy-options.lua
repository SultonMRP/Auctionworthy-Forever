-- Game Options → AddOns → Auctionworthy-Forever. Same pattern as Hunter Pet Atlas.

local optionsCategory
local optionChecks = {}

local CHECKBOXES = {
	{ label = "Show Auction Costs", key = "showAuctionCosts" },
	{ label = "Show Auction Price", key = "showAuctionPrice" },
	{ label = "Show Profit/Loss Options", key = "showProfitOptions" },
	{ label = "Show No Auction Data", key = "showNoAuctionData" },
	{ label = "Price the current stack", key = "showFullStack" },
	{ label = "Show Decision Text", key = "showDecisionText" },
	{ label = "Apply Auctionator undercut", key = "applyUndercut" },
	{ label = "Show Undercut", key = "showUndercut" },
	{ label = "Show vendor value", key = "showVendorValue" },
	{ label = "Self check", key = "selfCheck" },
	{ label = "A/V on bag and bank icons", key = "showBagTags" },
	{ label = "Waylaid/writ info", key = "waylaidInfo" },
}

local function Secret(value)
	return Auctionworthy:Secret(value)
end

local function OptionOn(key)
	return Auctionworthy:GetOption(key) and true or false
end

local function EnsureOptionsPanel()
	if AuctionworthyOptionsFrame then
		return AuctionworthyOptionsFrame
	end

	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", "AuctionworthyOptionsFrame")
	frame.name = "Auctionworthy-Forever"

	local scroll = CreateFrame("ScrollFrame", "AuctionworthyOptionsScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	scroll:EnableMouseWheel(true)

	local content = CreateFrame("Frame", "AuctionworthyOptionsContent", scroll)
	content:SetSize(540, 680)
	scroll:SetScrollChild(content)

	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Auctionworthy-Forever - Options")

	local info = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	info:SetJustifyH("LEFT")
	info:SetWidth(520)
	info:SetText("Auctionator prices on tooltips. Stack option uses the count you are hovering.\nCommands: /worthy (this page), /worthy refresh, /worthy help")

	local last = info
	for i, checkbox in ipairs(CHECKBOXES) do
		local cb = CreateFrame("CheckButton", "AuctionworthyOption" .. i, content, "UICheckButtonTemplate")
		if i == 1 then
			cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", -2, -14)
		else
			cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
		end
		local label = _G[cb:GetName() .. "Text"]
		label:SetFontObject(GameFontHighlight)
		label:SetText(checkbox.label)
		cb.optionKey = checkbox.key
		cb:SetChecked(OptionOn(checkbox.key))
		cb:SetScript("OnClick", function(self)
			Auctionworthy:SetOption(self.optionKey, self:GetChecked() and true or false)
			if self.optionKey == "showBagTags" and Auctionworthy.RefreshBagTags then
				Auctionworthy:RefreshBagTags()
			end
		end)
		optionChecks[#optionChecks + 1] = cb
		last = cb
	end

	local shareLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	shareLabel:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 32, -12)
	shareLabel:SetText("Waylaid/writ share key")

	local drop = CreateFrame("Button", "AuctionworthyShareKeyButton", content, "UIPanelButtonTemplate")
	drop:SetSize(80, 22)
	drop:SetPoint("LEFT", shareLabel, "RIGHT", 12, 0)
	drop:SetText(Auctionworthy:ShareModifierLabel())

	local menu = CreateFrame("Frame", "AuctionworthyShareKeyMenu", content, template)
	menu:SetSize(80, 68)
	menu:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -2)
	menu:SetFrameLevel(content:GetFrameLevel() + 20)
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

	for i, entry in ipairs(Auctionworthy:ShareModifiers()) do
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
			Auctionworthy:SetOption("shareModifier", entry.key)
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

	local queryLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	queryLabel:SetPoint("TOPLEFT", shareLabel, "BOTTOMLEFT", 0, -16)
	queryLabel:SetText("Crate Query")

	local queryBox = CreateFrame("EditBox", "AuctionworthyCrateQueryBox", content, "InputBoxTemplate")
	queryBox:SetSize(90, 20)
	queryBox:SetPoint("LEFT", queryLabel, "RIGHT", 16, 0)
	queryBox:SetAutoFocus(false)
	queryBox:SetMaxLetters(Auctionworthy:CrateQueryMax())
	queryBox:SetFontObject(GameFontHighlight)
	queryBox:SetText(Auctionworthy:CrateQuery())
	queryBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	queryBox:SetScript("OnEnterPressed", function(self)
		self:SetText(Auctionworthy:CommitCrateQuery(self:GetText()))
		self:ClearFocus()
	end)
	queryBox:SetScript("OnEscapePressed", function(self)
		self:SetText(Auctionworthy:CrateQuery())
		self:ClearFocus()
	end)
	queryBox:SetScript("OnEditFocusLost", function(self)
		self:SetText(Auctionworthy:CommitCrateQuery(self:GetText()))
	end)

	local shareNote = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	shareNote:SetPoint("TOPLEFT", queryLabel, "BOTTOMLEFT", 0, -16)
	shareNote:SetWidth(500)
	shareNote:SetJustifyH("LEFT")
	shareNote:SetText("Share key clicks a Waylaid crate or Craftsman's Writ. Query plus one item link replies with the price. A number after the link (x10, *10, or 10) is that many.")

	local function SizeScrollContent()
		local w = scroll:GetWidth()
		if Secret(w) or type(w) ~= "number" or w < 40 then
			w = 540
		end
		content:SetWidth(w)
		info:SetWidth(math.max(200, w - 36))
		shareNote:SetWidth(math.max(200, w - 48))
		content:SetHeight(680)
	end

	scroll:SetScript("OnMouseWheel", function(self, delta)
		if Secret(delta) then
			return
		end
		local bar = _G["AuctionworthyOptionsScrollScrollBar"]
		if not bar or not bar.GetValue then
			return
		end
		local value = bar:GetValue()
		if Secret(value) then
			return
		end
		delta = tonumber(delta) or 0
		value = tonumber(value) or 0
		bar:SetValue(value - delta * 40)
	end)
	scroll:SetScript("OnSizeChanged", SizeScrollContent)

	frame:SetScript("OnShow", function()
		for _, cb in ipairs(optionChecks) do
			cb:SetChecked(OptionOn(cb.optionKey))
		end
		drop:SetText(Auctionworthy:ShareModifierLabel())
		queryBox:SetText(Auctionworthy:CrateQuery())
		SizeScrollContent()
	end)
	frame:SetScript("OnHide", function()
		menu:Hide()
	end)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		optionsCategory = Settings.RegisterCanvasLayoutCategory(frame, "Auctionworthy-Forever")
		if Settings.RegisterAddOnCategory then
			Settings.RegisterAddOnCategory(optionsCategory)
		end
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(frame)
	end

	return frame
end

function Auctionworthy:EnsureOptionsPanel()
	return EnsureOptionsPanel()
end

function Auctionworthy:OpenOptions()
	EnsureOptionsPanel()
	if optionsCategory and Settings and Settings.OpenToCategory and optionsCategory.GetID then
		local ok = pcall(Settings.OpenToCategory, optionsCategory:GetID())
		if ok then
			return
		end
	end
	if InterfaceOptionsFrame_OpenToCategory and AuctionworthyOptionsFrame then
		InterfaceOptionsFrame_OpenToCategory(AuctionworthyOptionsFrame)
		InterfaceOptionsFrame_OpenToCategory(AuctionworthyOptionsFrame)
	end
end
