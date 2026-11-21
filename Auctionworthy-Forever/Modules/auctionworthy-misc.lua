-- Odd extras. First: empty send-mail subject gets the first attachment name.

local pending = 0

local function Secret(value)
	return Auctionworthy:Secret(value)
end

local function PublicString(value)
	return Auctionworthy:PublicString(value)
end

local function Skip()
	return Auctionworthy:SkipClicks()
end

local function SubjectBox()
	return SendMailSubjectEditBox
end

local function SubjectEmpty()
	local box = SubjectBox()
	if not box or not box.GetText then
		return false
	end
	local ok, text = pcall(box.GetText, box)
	if not ok then
		return false
	end
	if Secret(text) then
		return false
	end
	if type(text) ~= "string" then
		return false
	end
	text = strtrim(text)
	return text == ""
end

local function ItemNameFromID(itemID)
	itemID = tonumber(itemID)
	if not itemID or Secret(itemID) then
		return nil
	end
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
end

local function NameFromSlot(index)
	local getter = GetSendMailItem
	if C_Mail and C_Mail.GetSendMailItem then
		getter = C_Mail.GetSendMailItem
	end
	if type(getter) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(getter, index)
	if not ok then
		return nil
	end
	local name = PublicString(a)
	if name then
		return name
	end
	return ItemNameFromID(a) or ItemNameFromID(b)
end

local function FirstAttachmentName()
	local maxSlots = ATTACHMENTS_MAX_SEND or 12
	for i = 1, maxSlots do
		local name = NameFromSlot(i)
		if name then
			return name
		end
	end
	if GetSendMailItemLink then
		for i = 1, maxSlots do
			local ok, link = pcall(GetSendMailItemLink, i)
			if ok then
				link = PublicString(link)
				if link then
					local shown = link:match("%[(.-)%]")
					shown = PublicString(shown)
					if shown then
						return shown
					end
				end
			end
		end
	end
end

local function FillSubject()
	if Skip() then
		return
	end
	if not SubjectEmpty() then
		return
	end
	local name = FirstAttachmentName()
	if not name then
		return
	end
	local box = SubjectBox()
	if not box or not box.SetText then
		return
	end
	local maxLetters = 64
	if box.GetMaxLetters then
		local ok, n = pcall(box.GetMaxLetters, box)
		if ok and not Secret(n) and type(n) == "number" and n > 0 then
			maxLetters = n
		end
	end
	if #name > maxLetters then
		name = strtrim(name:sub(1, maxLetters))
	end
	if name == "" then
		return
	end
	pcall(box.SetText, box, name)
end

local function QueueFill()
	if Skip() then
		return
	end
	if not C_Timer or not C_Timer.After then
		FillSubject()
		return
	end
	pending = pending + 1
	local token = pending
	C_Timer.After(0.5, function()
		if token ~= pending then
			return
		end
		FillSubject()
	end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_CLOSED")
frame:RegisterEvent("MAIL_SEND_INFO_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_DEAD")
frame:SetScript("OnEvent", function(_, event)
	if event == "MAIL_CLOSED" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD" then
		pending = pending + 1
		return
	end
	if event == "MAIL_SHOW" or event == "MAIL_SEND_INFO_UPDATE" then
		QueueFill()
	end
end)

if type(hooksecurefunc) == "function" and type(ClickSendMailItemButton) == "function" then
	hooksecurefunc("ClickSendMailItemButton", QueueFill)
end
