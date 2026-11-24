-- Bags, bank, and guild bank. Posts to Raid, Party, or Say. Does not read chat.
-- Optional green A / red V on bag and bank icons (off by default).

local function AddonLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
		return ok and loaded and true or false
	end
	if IsAddOnLoaded then
		local ok, loaded = pcall(IsAddOnLoaded, name)
		return ok and loaded and true or false
	end
	return false
end

local function ValidBagSlot(bag, slot)
	bag = tonumber(bag)
	slot = tonumber(slot)
	if bag == nil or slot == nil then
		return false
	end
	if slot < 1 or slot > 128 then
		return false
	end
	if bag < -3 or bag > 50 then
		return false
	end
	return true
end

local function ContainerLink(bag, slot)
	if not ValidBagSlot(bag, slot) then
		return
	end
	if C_Container and C_Container.GetContainerItemLink then
		local ok, link = pcall(C_Container.GetContainerItemLink, bag, slot)
		if ok then
			return link
		end
		return
	end
	if GetContainerItemLink then
		local ok, link = pcall(GetContainerItemLink, bag, slot)
		if ok then
			return link
		end
	end
end

local function ButtonBagAndSlot(button)
	if not button then
		return
	end
	local bag, slot
	if type(button.GetSlotAndBagID) == "function" then
		local ok, a, b = pcall(button.GetSlotAndBagID, button)
		if ok then
			if ValidBagSlot(b, a) then
				return b, a
			end
			if ValidBagSlot(a, b) then
				return a, b
			end
		end
	end
	if type(button.GetBag) == "function" then
		local ok, value = pcall(button.GetBag, button)
		if ok then
			bag = value
		end
	end
	if bag == nil and button.bag ~= nil then
		bag = button.bag
	end
	if bag == nil and button.GetBagID then
		local ok, value = pcall(button.GetBagID, button)
		if ok then
			bag = value
		end
	end
	if button.GetID then
		slot = button:GetID()
	end
	if bag == nil and button.GetParent then
		local parent = button:GetParent()
		if parent and parent.GetID then
			bag = parent:GetID()
		end
	end
	return bag, slot
end

local function BagLink(button)
	local bag, slot = ButtonBagAndSlot(button)
	return ContainerLink(bag, slot)
end

local function BankLink(button)
	local bag, slot = ButtonBagAndSlot(button)
	if bag == nil or bag == 0 then
		bag = BANK_CONTAINER
	end
	return ContainerLink(bag, slot)
end

local function GuildBankLink(button)
	if not button or not button.GetID or not GetGuildBankItemLink or not GetCurrentGuildBankTab then
		return
	end
	local tab = GetCurrentGuildBankTab()
	local slot = button:GetID()
	if not tab or not slot then
		return
	end
	return GetGuildBankItemLink(tab, slot)
end

local function Post(link)
	if Auctionworthy.SkipClicks and Auctionworthy:SkipClicks() then
		return
	end
	if type(link) ~= "string" or link == "" then
		return
	end
	if Auctionworthy.ReportClick then
		Auctionworthy:ClickDebug("inventory")
	end
	Auctionworthy:PostCrate(link)
end

local function OnBagClick(button, mouseButton)
	local itemButton = button
	local click = mouseButton
	if type(button) == "string" then
		click = button
		itemButton = this
	end
	if click == "RightButton" or not Auctionworthy:ModifierDown() then
		return
	end
	Post(BagLink(itemButton))
end

local function OnBankClick(button, mouseButton)
	if mouseButton == "RightButton" or not Auctionworthy:ModifierDown() then
		return
	end
	Post(BankLink(button))
end

local function OnGuildBankClick(button, mouseButton)
	if mouseButton == "RightButton" or not Auctionworthy:ModifierDown() then
		return
	end
	Post(GuildBankLink(button))
end

local GREEN = { 0, 1, 0 }
local RED = { 1, 0.15, 0.15 }
local seen = {}

local function HideTag(button)
	if not button then
		return
	end
	if button.AuctionworthyBagAV then
		button.AuctionworthyBagAV:Hide()
		button.AuctionworthyBagAV:SetText("")
	end
	if button.AuctionworthyBagAVHolder then
		button.AuctionworthyBagAVHolder:Hide()
	end
end

local function EnsureTag(button)
	local tag = button.AuctionworthyBagAV
	if tag then
		local holder = button.AuctionworthyBagAVHolder
		if holder then
			if button.GetFrameLevel then
				holder:SetFrameLevel((button:GetFrameLevel() or 1) + 30)
			end
			holder:Show()
		end
		return tag
	end
	if Auctionworthy.SkipClicks and Auctionworthy:SkipClicks() then
		return
	end
	local holder = button.AuctionworthyBagAVHolder
	if not holder then
		holder = CreateFrame("Frame", nil, button)
		holder:SetAllPoints(button)
		button.AuctionworthyBagAVHolder = holder
	end
	if button.GetFrameLevel then
		holder:SetFrameLevel((button:GetFrameLevel() or 1) + 30)
	end
	holder:Show()
	tag = holder:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	tag:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -1)
	tag:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
	tag:SetJustifyH("LEFT")
	tag:SetDrawLayer("OVERLAY", 7)
	button.AuctionworthyBagAV = tag
	return tag
end

local function GuildBankButton(button)
	if not button then
		return false
	end
	local name = button.GetName and button:GetName()
	if type(name) == "string" and not Auctionworthy:Secret(name) and name:find("GuildBank", 1, true) then
		return true
	end
	return false
end

local function ButtonLink(button)
	if type(button.GetItemLink) == "function" then
		local ok, link = pcall(button.GetItemLink, button)
		if ok and type(link) == "string" and link ~= "" and not Auctionworthy:Secret(link) then
			return link
		end
	end
	if type(button.itemLink) == "string" and button.itemLink ~= "" and not Auctionworthy:Secret(button.itemLink) then
		return button.itemLink
	end
	if type(button.itemInfo) == "table" then
		local link = button.itemInfo.hyperlink or button.itemInfo.itemLink
		if type(link) == "string" and link ~= "" and not Auctionworthy:Secret(link) then
			return link
		end
	end
	if type(button.info) == "table" then
		local link = button.info.hyperlink or button.info.itemLink or button.info.link
		if type(link) == "string" and link ~= "" and not Auctionworthy:Secret(link) then
			return link
		end
	end
	if GuildBankButton(button) then
		return GuildBankLink(button)
	end
	local bag, slot = ButtonBagAndSlot(button)
	if not ValidBagSlot(bag, slot) then
		return
	end
	return ContainerLink(bag, slot)
end

local function CharacterSlotButton(button)
	local frame = button
	for _ = 1, 10 do
		if not frame then
			return false
		end
		local name = frame.GetName and frame:GetName()
		if type(name) == "string" and not Auctionworthy:Secret(name) then
			if name:find("PaperDoll", 1, true) or name:find("EquipmentFlyout", 1, true) then
				return true
			end
			if name:find("Inspect", 1, true) and name:find("Slot", 1, true) then
				return true
			end
			if name:find("^Character") and name:find("Slot", 1, true) then
				return true
			end
		end
		if frame == PaperDollFrame or frame == InspectFrame or frame == InspectPaperDollFrame then
			return true
		end
		if frame == EquipmentFlyoutFrame then
			return true
		end
		if not frame.GetParent then
			return false
		end
		frame = frame:GetParent()
	end
	return false
end

local function MerchantOrBuybackButton(button)
	local frame = button
	for _ = 1, 10 do
		if not frame then
			return false
		end
		local name = frame.GetName and frame:GetName()
		if type(name) == "string" and not Auctionworthy:Secret(name) then
			if name:find("Merchant", 1, true) or name:find("Buyback", 1, true) then
				return true
			end
		end
		if frame == MerchantFrame then
			return true
		end
		if not frame.GetParent then
			return false
		end
		frame = frame:GetParent()
	end
	return false
end

local function BagOrBankButton(button)
	if not button then
		return false
	end
	if MerchantOrBuybackButton(button) or CharacterSlotButton(button) then
		return false
	end
	if button.hasItem then
		return true
	end
	if type(button.GetItemLink) == "function" or type(button.itemLink) == "string" then
		return true
	end
	if type(button.GetSlotAndBagID) ~= "function" and type(button.info) ~= "table" and type(button.itemInfo) ~= "table" then
		if button.IsObjectType and button:IsObjectType("CheckButton") and type(button.GetBag) == "function" then
			return false
		end
	end
	if type(button.GetSlotAndBagID) == "function" then
		local bag, slot = ButtonBagAndSlot(button)
		if ValidBagSlot(bag, slot) then
			return true
		end
	end
	if type(button.GetBag) == "function" and button.GetID then
		local bag, slot = ButtonBagAndSlot(button)
		if ValidBagSlot(bag, slot) then
			return true
		end
	end
	if type(button.info) == "table" and (button.info.hyperlink or button.info.itemID or button.hasItem) then
		return true
	end
	local name = button.GetName and button:GetName()
	if type(name) == "string" and not Auctionworthy:Secret(name) then
		if name:find("ContainerFrame", 1, true) or name:find("BankFrame", 1, true) then
			return true
		end
		if name:find("GuildBank", 1, true) or name:find("ReagentBank", 1, true) then
			return true
		end
		if name:find("Bagnon", 1, true) or name:find("Bagnonium", 1, true) then
			return true
		end
	end
	if button.GetBagID then
		local bag, slot = ButtonBagAndSlot(button)
		return ValidBagSlot(bag, slot)
	end
	return false
end

local function ButtonIsBound(button)
	local bag, slot = ButtonBagAndSlot(button)
	if not ValidBagSlot(bag, slot) then
		return false
	end
	if not (C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot) then
		return false
	end
	local ok, loc = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
	if not ok or not loc then
		return false
	end
	local okBound, flag = pcall(C_Item.IsBound, loc)
	if not okBound then
		return false
	end
	if Auctionworthy:Secret(flag) or flag then
		return true
	end
	return false
end

local function Paint(button)
	if MerchantOrBuybackButton(button) or CharacterSlotButton(button) then
		HideTag(button)
		return
	end
	if not BagOrBankButton(button) then
		return
	end
	seen[button] = true
	if not Auctionworthy.ShowBagTags or not Auctionworthy:ShowBagTags() then
		button.AuctionworthyBagDirty = nil
		HideTag(button)
		return
	end
	local link = ButtonLink(button)
	if type(link) ~= "string" or link == "" then
		button.AuctionworthyBagDirty = nil
		HideTag(button)
		return
	end
	if ButtonIsBound(button) then
		button.AuctionworthyBagDirty = nil
		HideTag(button)
		return
	end
	if Auctionworthy.ScanBusy and Auctionworthy:ScanBusy() then
		button.AuctionworthyBagDirty = true
		HideTag(button)
		return
	end
	local letter, waiting = Auctionworthy:ItemAVLetter(link)
	if waiting then
		button.AuctionworthyBagDirty = true
		return
	end
	button.AuctionworthyBagDirty = nil
	if letter == "A" then
		local tag = EnsureTag(button)
		if not tag then
			button.AuctionworthyBagDirty = true
			return
		end
		tag:SetText("A")
		tag:SetTextColor(GREEN[1], GREEN[2], GREEN[3], 1)
		tag:Show()
	elseif letter == "V" then
		local tag = EnsureTag(button)
		if not tag then
			button.AuctionworthyBagDirty = true
			return
		end
		tag:SetText("V")
		tag:SetTextColor(RED[1], RED[2], RED[3], 1)
		tag:Show()
	else
		HideTag(button)
	end
end

local function SeedButtons()
	local bags = NUM_CONTAINER_FRAMES or 13
	for i = 1, bags do
		local bag = _G["ContainerFrame" .. i]
		if type(bag) == "table" and type(bag.Items) == "table" then
			for _, button in ipairs(bag.Items) do
				if type(button) == "table" then
					seen[button] = true
				end
			end
		end
		for j = 1, 36 do
			local button = _G["ContainerFrame" .. i .. "Item" .. j]
			if button then
				seen[button] = true
			end
		end
	end
	local container = _G.ContainerFrameContainer
	if type(container) == "table" and type(container.ContainerFrames) == "table" then
		for _, bag in ipairs(container.ContainerFrames) do
			if type(bag) == "table" and type(bag.Items) == "table" then
				for _, button in ipairs(bag.Items) do
					if type(button) == "table" then
						seen[button] = true
					end
				end
			end
		end
	end
	local combined = _G.ContainerFrameCombinedBags
	if type(combined) == "table" then
		if type(combined.EnumerateValidItems) == "function" then
			for _, button in combined:EnumerateValidItems() do
				if type(button) == "table" then
					seen[button] = true
				end
			end
		elseif type(combined.Items) == "table" then
			for _, button in pairs(combined.Items) do
				if type(button) == "table" then
					seen[button] = true
				end
			end
		end
	end
	for i = 1, 28 do
		local button = _G["BankFrameItem" .. i]
		if button then
			seen[button] = true
		end
	end
	local bankFrame = _G.BankFrame
	local bankPanel = bankFrame and bankFrame.BankPanel
	if type(bankPanel) == "table" and type(bankPanel.FindItemButtonByBankTabAndContainerSlotID) == "function" then
		local maxSlots = 98
		if type(bankPanel.GetMaximumTotalSlotsPerPage) == "function" then
			local n = bankPanel:GetMaximumTotalSlotsPerPage()
			if type(n) == "number" and n > 0 then
				maxSlots = n
			end
		end
		for tab = 1, 14 do
			for slot = 1, maxSlots do
				local ok, button = pcall(bankPanel.FindItemButtonByBankTabAndContainerSlotID, bankPanel, tab, slot)
				if ok and type(button) == "table" then
					seen[button] = true
				end
			end
		end
	end
	for col = 1, 8 do
		for row = 1, 14 do
			local button = _G["GuildBankColumn" .. col .. "Button" .. row]
			if button then
				seen[button] = true
			end
		end
	end
end

local function RefreshBagTags()
	SeedButtons()
	for button in pairs(seen) do
		Paint(button)
	end
end

local hooked = {}

local function HookClick(key, mixin, mixinFn, globalName, handler)
	if hooked[key] then
		return
	end
	if type(mixin) == "table" and type(mixin[mixinFn]) == "function" then
		hooksecurefunc(mixin, mixinFn, handler)
		hooked[key] = true
		return
	end
	if type(_G[globalName]) == "function" then
		hooksecurefunc(globalName, handler)
		hooked[key] = true
	end
end

local function InstallClicks()
	HookClick("bag", _G.ContainerFrameItemButtonMixin, "OnModifiedClick", "ContainerFrameItemButton_OnModifiedClick", OnBagClick)
	HookClick("bank", _G.BankFrameItemButtonMixin, "OnModifiedClick", "BankFrameItemButton_OnModifiedClick", OnBankClick)
	HookClick("guildbank", _G.GuildBankItemButtonMixin, "OnModifiedClick", "GuildBankItemButton_OnModifiedClick", OnGuildBankClick)
	if not hooked.guildbank then
		HookClick("guildbank", _G.GuildBankItemButtonMixin, "OnClick", "GuildBankItemButton_OnClick", OnGuildBankClick)
	end
end

local function HookPaint(key, mixin, mixinFn, globalName)
	if hooked[key] then
		return
	end
	if type(mixin) == "table" and type(mixin[mixinFn]) == "function" then
		hooksecurefunc(mixin, mixinFn, Paint)
		hooked[key] = true
		return
	end
	if type(_G[globalName]) == "function" then
		hooksecurefunc(globalName, Paint)
		hooked[key] = true
	end
end

local function HookItemUpdate(key, addon)
	if hooked[key] or type(addon) ~= "table" then
		return
	end
	local item = addon.Item
	if type(item) == "table" and type(item.Update) == "function" then
		hooksecurefunc(item, "Update", Paint)
		hooked[key] = true
	end
end

local function HookBaganator()
	if hooked.baganator then
		return
	end
	local api = _G.Baganator and _G.Baganator.API
	if type(api) ~= "table" or type(api.RegisterCornerWidget) ~= "function" then
		return
	end
	local function onInit(itemButton)
		local text = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		text.sizeFont = true
		return text
	end
	local function onUpdate(text, details)
		if not Auctionworthy.ShowBagTags or not Auctionworthy:ShowBagTags() then
			return false
		end
		if type(details) ~= "table" or type(details.itemLink) ~= "string" or details.itemLink == "" then
			return false
		end
		if Auctionworthy:Secret(details.itemLink) then
			return false
		end
		if details.isBound then
			return false
		end
		if Auctionworthy.ScanBusy and Auctionworthy:ScanBusy() then
			return nil
		end
		local letter, waiting = Auctionworthy:ItemAVLetter(details.itemLink)
		if waiting then
			return nil
		end
		if letter == "A" then
			text:SetText("A")
			text:SetTextColor(GREEN[1], GREEN[2], GREEN[3], 1)
			return true
		end
		if letter == "V" then
			text:SetText("V")
			text:SetTextColor(RED[1], RED[2], RED[3], 1)
			return true
		end
		return false
	end
	local ok = pcall(api.RegisterCornerWidget, "Auctionworthy A/V", "auctionworthy_av", onUpdate, onInit, { corner = "top_left", priority = 1 })
	if ok then
		hooked.baganator = true
	end
end

local function RefreshBaganator()
	local api = _G.Baganator and _G.Baganator.API
	if type(api) ~= "table" or type(api.RequestItemButtonsRefresh) ~= "function" then
		return
	end
	local reason
	local constants = _G.Baganator.Constants
	if type(constants) == "table" and type(constants.RefreshReason) == "table" then
		reason = { constants.RefreshReason.ItemWidgets }
	end
	pcall(api.RequestItemButtonsRefresh, reason)
end

local function InstallTags()
	HookPaint("settex", nil, nil, "SetItemButtonTexture")
	HookPaint("setcount", nil, nil, "SetItemButtonCount")
	local bagMixin = _G.ContainerFrameItemButtonMixin
	if type(bagMixin) == "table" then
		if type(bagMixin.UpdateItem) == "function" then
			HookPaint("bagupdate", bagMixin, "UpdateItem")
		elseif type(bagMixin.Update) == "function" then
			HookPaint("bagupdate", bagMixin, "Update")
		end
	end
	local bankMixin = _G.BankFrameItemButtonMixin
	if type(bankMixin) == "table" and type(bankMixin.Update) == "function" then
		HookPaint("bankupdate", bankMixin, "Update")
	end
	if AddonLoaded("Bagnon") then
		HookItemUpdate("bagnon", _G.Bagnon)
	end
	if AddonLoaded("Bagnonium") then
		HookItemUpdate("bagnonium", _G.Bagnonium)
	end
	if AddonLoaded("BagBrother") then
		HookItemUpdate("bagbrother", _G.BagBrother)
	end
	if AddonLoaded("Baganator") then
		HookBaganator()
	end
	local combined = _G.ContainerFrameCombinedBags
	if type(combined) == "table" then
		if type(combined.UpdateItems) == "function" and not hooked.combinedItems then
			hooksecurefunc(combined, "UpdateItems", function()
				if Auctionworthy.ShowBagTags and Auctionworthy:ShowBagTags() then
					RefreshBagTags()
				end
			end)
			hooked.combinedItems = true
		end
		if type(combined.UpdateItemLayout) == "function" and not hooked.combinedLayout then
			hooksecurefunc(combined, "UpdateItemLayout", function()
				if Auctionworthy.ShowBagTags and Auctionworthy:ShowBagTags() then
					RefreshBagTags()
				end
			end)
			hooked.combinedLayout = true
		end
	end
	local containerMixin = _G.ContainerFrameMixin
	if type(containerMixin) == "table" and type(containerMixin.UpdateItems) == "function" and not hooked.frameitems then
		hooksecurefunc(containerMixin, "UpdateItems", function()
			if Auctionworthy.ShowBagTags and Auctionworthy:ShowBagTags() then
				RefreshBagTags()
			end
		end)
		hooked.frameitems = true
	end
	if type(_G.OpenBag) == "function" and not hooked.openbag then
		hooksecurefunc("OpenBag", function()
			if Auctionworthy.ShowBagTags and Auctionworthy:ShowBagTags() then
				RefreshBagTags()
			end
		end)
		hooked.openbag = true
	end
	if type(_G.OpenAllBags) == "function" and not hooked.openall then
		hooksecurefunc("OpenAllBags", function()
			if Auctionworthy.ShowBagTags and Auctionworthy:ShowBagTags() then
				RefreshBagTags()
			end
		end)
		hooked.openall = true
	end
end

local function Install()
	InstallClicks()
	InstallTags()
end

function Auctionworthy:RefreshBagTags()
	RefreshBagTags()
	RefreshBaganator()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("GUILDBANKFRAME_OPENED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("PLAYERBANKSLOTS_CHANGED") then
	pcall(frame.RegisterEvent, frame, "PLAYERBANKSLOTS_CHANGED")
end
if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid("GUILDBANKBAGSLOTS_CHANGED") then
	pcall(frame.RegisterEvent, frame, "GUILDBANKBAGSLOTS_CHANGED")
end
frame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == "Bagnon" or name == "Bagnonium" or name == "BagBrother" or name == "Baganator" or name == "MyBags" then
			InstallTags()
		end
		return
	end
	if event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "GUILDBANKBAGSLOTS_CHANGED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
		if Auctionworthy.ShowBagTags and Auctionworthy:ShowBagTags() then
			RefreshBagTags()
			RefreshBaganator()
		end
		return
	end
	Install()
	if Auctionworthy.ShowBagTags and Auctionworthy:ShowBagTags() then
		RefreshBagTags()
		RefreshBaganator()
	end
end)

if C_Timer and C_Timer.NewTicker then
	C_Timer.NewTicker(0.5, function()
		if not Auctionworthy.ShowBagTags or not Auctionworthy:ShowBagTags() then
			return
		end
		if Auctionworthy.ScanBusy and Auctionworthy:ScanBusy() then
			return
		end
		for button in pairs(seen) do
			if button.AuctionworthyBagDirty then
				Paint(button)
			end
		end
	end)
end
