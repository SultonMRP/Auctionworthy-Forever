-- Party, raid, say, yell, loot, and numbered channels (Trade, General).
-- Key-click an item link whispers the person on that line.
-- Crates get the cheapest fill. Writs get requested-goods cost. Any other item gets AH / vendor values.
-- Query replies (? plus one item link) are party and raid only.

local posted = {}
local lastKey
local lastAt = 0
local hooked

function Auctionworthy:RememberPoster(message, sender)
	if not Auctionworthy:PublicString(message) or not Auctionworthy:PublicString(sender) then
		return
	end
	local found = false
	for itemID in message:gmatch("item:(%d+)") do
		itemID = tonumber(itemID)
		if itemID and itemID > 0 then
			found = true
			posted[#posted + 1] = { itemID = itemID, sender = sender }
		end
	end
	if not found then
		return
	end
	while #posted > 40 do
		table.remove(posted, 1)
	end
end

local function LastPoster(link)
	local itemID = Auctionworthy:ItemID(link)
	if not itemID then
		return
	end
	for i = #posted, 1, -1 do
		if posted[i].itemID == itemID then
			return posted[i].sender
		end
	end
end

local function WhisperOwner(link, who)
	if not Auctionworthy:PublicString(who) then
		return
	end
	local now = GetTime and GetTime() or 0
	local key = strlower(who) .. ":" .. tostring(Auctionworthy:ItemID(link) or link)
	if lastKey == key and (now - lastAt) < 0.25 then
		return
	end
	lastKey = key
	lastAt = now
	if Auctionworthy.ReportClick then
		Auctionworthy:ClickDebug("chat " .. who)
	end
	if Auctionworthy:IsCrateLink(link) or (Auctionworthy.IsWritLink and Auctionworthy:IsWritLink(link)) then
		Auctionworthy:WhisperCrate(link, who)
		return
	end
	Auctionworthy:ReplyItemSell(link, who)
end

local function OnClick(chatFrame, item)
	if Auctionworthy.SkipClicks and Auctionworthy:SkipClicks() then
		return
	end
	if not Auctionworthy:ModifierDown() then
		return
	end
	if not chatFrame and not Auctionworthy:MouseOverChat() then
		return
	end
	local kind, sender = Auctionworthy:ReadClick(chatFrame, item)
	if kind == "WHISPER_OUT" then
		return
	end
	sender = sender or LastPoster(item)
	if not Auctionworthy:PublicString(sender) then
		return
	end
	if Auctionworthy.PreferListedLink then
		item = Auctionworthy:PreferListedLink(item, ItemRefTooltip)
	end
	WhisperOwner(item, sender)
end

local function FromHyperlink(chatFrame, link, text, button)
	if button == "RightButton" then
		return
	end
	if type(link) == "string" and not link:find("item:", 1, true) then
		if type(text) ~= "string" or not text:find("item:", 1, true) then
			return
		end
	end
	OnClick(chatFrame, text or link)
end

local function Install()
	if hooked then
		return
	end
	hooked = true
	if type(HandleModifiedItemClick) == "function" then
		hooksecurefunc("HandleModifiedItemClick", function(link)
			OnClick(nil, link)
		end)
	end
	if type(ChatFrame_OnHyperlinkShow) == "function" then
		hooksecurefunc("ChatFrame_OnHyperlinkShow", function(a, b, c, d)
			if type(a) == "string" then
				FromHyperlink(nil, a, b, c)
			else
				FromHyperlink(a, b, c, d)
			end
		end)
	end
	local mixin = _G.ChatFrameMixin
	if type(mixin) == "table" and type(mixin.OnHyperlinkShow) == "function" then
		hooksecurefunc(mixin, "OnHyperlinkShow", function(self, link, text, button)
			FromHyperlink(self, link, text, button)
		end)
	end
	if type(SetItemRef) == "function" then
		hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
			FromHyperlink(chatFrame, link, text, button)
		end)
	end
	if type(ChatEdit_InsertLink) == "function" then
		local replacing
		hooksecurefunc("ChatEdit_InsertLink", function(link)
			if replacing or type(link) ~= "string" or not Auctionworthy.PreferListedLink then
				return
			end
			if Auctionworthy.MouseOverChat and Auctionworthy:MouseOverChat() then
				return
			end
			local fixed = Auctionworthy:PreferListedLink(link, GameTooltip)
			if type(fixed) ~= "string" or fixed == "" or fixed == link then
				return
			end
			local edit = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
			if not edit or not edit.GetText or not edit.SetText then
				edit = ChatFrame1EditBox
			end
			if not edit or not edit.GetText or not edit.SetText then
				return
			end
			local body = edit:GetText()
			if type(body) ~= "string" then
				return
			end
			local at = body:find(link, 1, true)
			if not at then
				return
			end
			replacing = true
			edit:SetText(body:sub(1, at - 1) .. fixed .. body:sub(at + #link))
			replacing = false
		end)
	end
end

local QUERY = {
	CHAT_MSG_PARTY = true,
	CHAT_MSG_PARTY_LEADER = true,
	CHAT_MSG_RAID = true,
	CHAT_MSG_RAID_LEADER = true,
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("CHAT_MSG_CHANNEL")
events:RegisterEvent("CHAT_MSG_LOOT")
events:RegisterEvent("CHAT_MSG_SAY")
events:RegisterEvent("CHAT_MSG_YELL")
events:RegisterEvent("CHAT_MSG_PARTY")
events:RegisterEvent("CHAT_MSG_PARTY_LEADER")
events:RegisterEvent("CHAT_MSG_RAID")
events:RegisterEvent("CHAT_MSG_RAID_LEADER")
events:RegisterEvent("CHAT_MSG_RAID_WARNING")
events:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
events:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
events:SetScript("OnEvent", function(_, event, message, sender)
	if event == "PLAYER_LOGIN" then
		Install()
		return
	end
	if event == "CHAT_MSG_LOOT" then
		local who = Auctionworthy:LineLooter(message)
		if Auctionworthy:PublicString(who) then
			Auctionworthy:RememberPoster(message, who)
		end
		return
	end
	if QUERY[event] then
		Auctionworthy:HandleQuestion(message, sender)
	end
	Auctionworthy:RememberPoster(message, sender)
end)

Install()
