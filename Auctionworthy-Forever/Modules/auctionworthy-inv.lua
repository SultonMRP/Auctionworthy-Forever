-- Bags, bank, and guild bank. Posts to Raid, Party, or Say. Does not read chat.

local function ContainerLink(bag, slot)
	if bag == nil or slot == nil then
		return
	end
	if C_Container and C_Container.GetContainerItemLink then
		return C_Container.GetContainerItemLink(bag, slot)
	end
	if GetContainerItemLink then
		return GetContainerItemLink(bag, slot)
	end
end

local function ButtonBagAndSlot(button)
	if not button or not button.GetID then
		return
	end
	local slot = button:GetID()
	local bag
	if button.GetBagID then
		bag = button:GetBagID()
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

local function Install()
	HookClick("bag", _G.ContainerFrameItemButtonMixin, "OnModifiedClick", "ContainerFrameItemButton_OnModifiedClick", OnBagClick)
	HookClick("bank", _G.BankFrameItemButtonMixin, "OnModifiedClick", "BankFrameItemButton_OnModifiedClick", OnBankClick)
	HookClick("guildbank", _G.GuildBankItemButtonMixin, "OnModifiedClick", "GuildBankItemButton_OnModifiedClick", OnGuildBankClick)
	if not hooked.guildbank then
		HookClick("guildbank", _G.GuildBankItemButtonMixin, "OnClick", "GuildBankItemButton_OnClick", OnGuildBankClick)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("GUILDBANKFRAME_OPENED")
frame:SetScript("OnEvent", Install)
