-- Game Options → AddOns → Auctionworthy-Forever, with subcategories like Auctionator.

local optionsCategory
local optionChecks = {}
local optionSliders = {}

local GENERAL_CHECKS = {
	{ label = "Self check", key = "selfCheck" },
	{ label = "A/V on bag and bank icons", key = "showBagTags" },
	{ label = "Ignore ? requests", key = "ignoreQuestionRequests" },
}

local TOOLTIP_CHECKS = {
	{ label = "Show Auction Costs", key = "showAuctionCosts" },
	{ label = "Show Auction Price", key = "showAuctionPrice" },
	{ label = "Show Profit/Loss Options", key = "showProfitOptions" },
	{ label = "Show No Auction Data", key = "showNoAuctionData" },
	{ label = "Price the current stack", key = "showFullStack" },
	{ label = "Show Decision Text", key = "showDecisionText" },
	{ label = "Apply Auctionator undercut", key = "applyUndercut" },
	{ label = "Show Undercut", key = "showUndercut" },
	{ label = "Show vendor value", key = "showVendorValue" },
	{ label = "Waylaid/writ info", key = "waylaidInfo" },
}

local GATHER_CHECKS = {
	{ label = "Show gather list", key = "showGatherList" },
	{ label = "Show all gather professions in list", key = "showAllGatherProfessions" },
}

local function Secret(value)
	return Auctionworthy:Secret(value)
end

local function OptionOn(key)
	return Auctionworthy:GetOption(key) and true or false
end

local function AddChecks(parent, last, list)
	for _, checkbox in ipairs(list) do
		local n = #optionChecks + 1
		local cb = CreateFrame("CheckButton", "AuctionworthyOption" .. n, parent, "UICheckButtonTemplate")
		if last then
			cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
		else
			cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -56)
		end
		local label = _G[cb:GetName() .. "Text"]
		label:SetFontObject(GameFontHighlight)
		label:SetText(checkbox.label)
		cb.optionKey = checkbox.key
		cb:SetChecked(OptionOn(checkbox.key))
		cb:SetScript("OnClick", function(self)
			local checked = self:GetChecked()
			if Auctionworthy:Secret(checked) then
				return
			end
			Auctionworthy:SetOption(self.optionKey, checked and true or false)
			if self.optionKey == "showBagTags" and Auctionworthy.RefreshBagTags then
				Auctionworthy:RefreshBagTags()
			end
			if (self.optionKey == "showAllGatherProfessions" or self.optionKey == "showGatherList") and Auctionworthy.RefreshGatherSnapshot then
				Auctionworthy:RefreshGatherSnapshot()
			elseif self.optionKey == "showGatherList" and Auctionworthy.UpdateGatherList then
				Auctionworthy:UpdateGatherList()
			end
		end)
		optionChecks[n] = cb
		last = cb
	end
	return last
end

local function AddSlider(parent, last, spec)
	local name = spec.name
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 8, -28)
	slider:SetWidth(240)
	slider:SetMinMaxValues(spec.min, spec.max)
	slider:SetValueStep(spec.step or 1)
	if slider.SetObeyStepOnDrag then
		slider:SetObeyStepOnDrag(true)
	end
	local title = _G[name .. "Text"]
	local low = _G[name .. "Low"]
	local high = _G[name .. "High"]
	if title then
		title:SetText(spec.label)
	end
	if low then
		low:SetText(spec.low)
	end
	if high then
		high:SetText(spec.high)
	end
	slider.toSaved = spec.toSaved
	slider.fromSaved = spec.fromSaved
	slider.optionKey = spec.key
	local shown = spec.fromSaved(Auctionworthy:GetOption(spec.key))
	if type(shown) == "number" and not Secret(shown) then
		slider:SetValue(shown)
	end
	slider:SetScript("OnValueChanged", function(self, value)
		if Secret(value) then
			return
		end
		value = tonumber(value)
		if not value then
			return
		end
		Auctionworthy:SetOption(self.optionKey, self.toSaved(value))
		if Auctionworthy.ApplyGatherListLook then
			Auctionworthy:ApplyGatherListLook()
		end
	end)
	optionSliders[#optionSliders + 1] = slider
	return slider
end

local function MakeCanvas(frameName, titleText, noteText)
	local frame = CreateFrame("Frame", frameName)
	frame.name = titleText
	local scroll = CreateFrame("ScrollFrame", frameName .. "Scroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	scroll:EnableMouseWheel(true)
	local content = CreateFrame("Frame", frameName .. "Content", scroll)
	content:SetSize(540, 560)
	scroll:SetScrollChild(content)
	local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(titleText)
	local info = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	info:SetJustifyH("LEFT")
	info:SetWidth(520)
	info:SetText(noteText)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		if Secret(delta) then
			return
		end
		local bar = _G[frameName .. "ScrollScrollBar"]
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
	scroll:SetScript("OnSizeChanged", function()
		local w = scroll:GetWidth()
		if Secret(w) or type(w) ~= "number" or w < 40 then
			w = 540
		end
		content:SetWidth(w)
		info:SetWidth(math.max(200, w - 36))
	end)
	return frame, content
end

local function RegisterCategory(frame, parentCat)
	if Settings and Settings.RegisterCanvasLayoutCategory then
		if parentCat and Settings.RegisterCanvasLayoutSubcategory then
			local sub = Settings.RegisterCanvasLayoutSubcategory(parentCat, frame, frame.name)
			if Settings.RegisterAddOnCategory then
				Settings.RegisterAddOnCategory(sub)
			end
			return parentCat
		end
		local cat = Settings.RegisterCanvasLayoutCategory(frame, "Auctionworthy-Forever")
		if Settings.RegisterAddOnCategory then
			Settings.RegisterAddOnCategory(cat)
		end
		return cat
	end
	if InterfaceOptions_AddCategory then
		if parentCat then
			frame.parent = "Auctionworthy-Forever"
		end
		InterfaceOptions_AddCategory(frame)
	end
	return parentCat or true
end

local function EnsureOptionsPanel()
	if AuctionworthyOptionsFrame then
		return AuctionworthyOptionsFrame
	end

	local template = BackdropTemplateMixin and "BackdropTemplate" or nil
	local parent = MakeCanvas(
		"AuctionworthyOptionsFrame",
		"Auctionworthy-Forever",
		"Auctionator prices. /worthy  ·  /worthy refresh  ·  /worthy help\nPick a category on the left."
	)

	local general, generalContent = MakeCanvas(
		"AuctionworthyOptionsGeneral",
		"General",
		"Chat, bags, and crate share. Tooltip lines are under Tooltips."
	)
	local last = AddChecks(generalContent, nil, GENERAL_CHECKS)

	local shareLabel = generalContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	shareLabel:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 32, -12)
	shareLabel:SetText("Waylaid/writ share key")

	local drop = CreateFrame("Button", "AuctionworthyShareKeyButton", generalContent, "UIPanelButtonTemplate")
	drop:SetSize(80, 22)
	drop:SetPoint("LEFT", shareLabel, "RIGHT", 12, 0)
	drop:SetText(Auctionworthy:ShareModifierLabel())

	local menu = CreateFrame("Frame", "AuctionworthyShareKeyMenu", generalContent, template)
	menu:SetSize(80, 68)
	menu:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -2)
	menu:SetFrameLevel(generalContent:GetFrameLevel() + 20)
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

	local queryLabel = generalContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	queryLabel:SetPoint("TOPLEFT", shareLabel, "BOTTOMLEFT", 0, -16)
	queryLabel:SetText("Crate Query")

	local queryBox = CreateFrame("EditBox", "AuctionworthyCrateQueryBox", generalContent, "InputBoxTemplate")
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

	local shareNote = generalContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	shareNote:SetPoint("TOPLEFT", queryLabel, "BOTTOMLEFT", 0, -16)
	shareNote:SetWidth(500)
	shareNote:SetJustifyH("LEFT")
	shareNote:SetText("Share key clicks a Waylaid crate or Craftsman's Writ. Query plus one item link replies with the price. A number after the link (x10, *10, or 10) is that many.")

	local tooltips, tooltipContent = MakeCanvas(
		"AuctionworthyOptionsTooltips",
		"Tooltips",
		"Lines on item tips. Stack option uses the count you are hovering."
	)
	AddChecks(tooltipContent, nil, TOOLTIP_CHECKS)

	local gather, gatherContent = MakeCanvas(
		"AuctionworthyOptionsGather",
		"Gather List",
		"On-screen herb / ore / leather list. Ctrl+click a header to drag."
	)
	last = AddChecks(gatherContent, nil, GATHER_CHECKS)
	AddSlider(gatherContent, last, {
		name = "AuctionworthyGatherScale",
		label = "Scale",
		key = "gatherListScale",
		min = 50,
		max = 200,
		step = 1,
		low = "50%",
		high = "200%",
		fromSaved = function(saved)
			local n = tonumber(saved) or 1
			return n * 100
		end,
		toSaved = function(value)
			return value / 100
		end,
	})
	AddSlider(gatherContent, optionSliders[#optionSliders], {
		name = "AuctionworthyGatherAlpha",
		label = "Transparency",
		key = "gatherListAlpha",
		min = 0,
		max = 80,
		step = 1,
		low = "Solid",
		high = "Clear",
		fromSaved = function(saved)
			local n = tonumber(saved)
			if not n then
				n = 1
			end
			return (1 - n) * 100
		end,
		toSaved = function(value)
			return 1 - (value / 100)
		end,
	})

	general:SetScript("OnShow", function()
		for _, cb in ipairs(optionChecks) do
			if cb:GetParent() == generalContent then
				cb:SetChecked(OptionOn(cb.optionKey))
			end
		end
		drop:SetText(Auctionworthy:ShareModifierLabel())
		queryBox:SetText(Auctionworthy:CrateQuery())
	end)
	general:SetScript("OnHide", function()
		menu:Hide()
	end)
	tooltips:SetScript("OnShow", function()
		for _, cb in ipairs(optionChecks) do
			if cb:GetParent() == tooltipContent then
				cb:SetChecked(OptionOn(cb.optionKey))
			end
		end
	end)
	gather:SetScript("OnShow", function()
		for _, cb in ipairs(optionChecks) do
			if cb:GetParent() == gatherContent then
				cb:SetChecked(OptionOn(cb.optionKey))
			end
		end
		for _, slider in ipairs(optionSliders) do
			local shown = slider.fromSaved(Auctionworthy:GetOption(slider.optionKey))
			if type(shown) == "number" and not Secret(shown) then
				slider:SetValue(shown)
			end
		end
	end)

	optionsCategory = RegisterCategory(parent)
	RegisterCategory(general, optionsCategory)
	RegisterCategory(tooltips, optionsCategory)
	RegisterCategory(gather, optionsCategory)

	return parent
end

function Auctionworthy:EnsureOptionsPanel()
	return EnsureOptionsPanel()
end

function Auctionworthy:RefreshOptionChecks()
	for _, cb in ipairs(optionChecks) do
		cb:SetChecked(OptionOn(cb.optionKey))
	end
	for _, slider in ipairs(optionSliders) do
		local shown = slider.fromSaved(Auctionworthy:GetOption(slider.optionKey))
		if type(shown) == "number" and not Secret(shown) then
			slider:SetValue(shown)
		end
	end
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
