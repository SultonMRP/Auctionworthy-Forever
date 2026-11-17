-- Say, party, raid, and your own loot links. Posts to Raid, Party, or Say.
-- Someone else's loot link whispers that player the cheapest fill.
-- Crate Query plus one crate link in party or raid whispers that person the cheapest fill, then the empty crate value.
-- Any other item link whispers AH it and the profit, Vendor it and the loss, or non-vendorable when it has no sell price.
-- Query plus an item link whispers the price. A number after the link (x10, *10, or 10) is that many.
-- Guild and incoming whispers are other modules.

local POST = {
	SAY = true,
	PARTY = true,
	PARTY_LEADER = true,
	RAID = true,
	RAID_LEADER = true,
	RAID_WARNING = true,
	LOOT = true,
}

local installed
local function Install()
	if installed then
		return
	end
	installed = true
	Auctionworthy:EachChatClick(function(kind, sender, link)
		if not POST[kind] then
			return
		end
		if kind == "LOOT" and type(sender) == "string" and sender ~= "" then
			Auctionworthy:ClickDebug("loot " .. sender)
			Auctionworthy:WhisperCrate(link, sender)
			return
		end
		Auctionworthy:ClickDebug("chat " .. kind)
		Auctionworthy:PostCrate(link)
	end)
end

local recentQuotes = {}

local function RecentlyQuoted(sender, link, qty)
	local key = strlower(sender) .. ":" .. tostring(Auctionworthy:ItemID(link) or link) .. ":" .. tostring(qty or 1)
	local now = GetTime and GetTime() or 0
	local last = recentQuotes[key]
	if last and (now - last) < 2 then
		return true
	end
	recentQuotes[key] = now
	return false
end

local function ReplyToQuestion(message, sender)
	if type(sender) ~= "string" or sender == "" or Auctionworthy:Secret(sender) then
		return
	end
	local link, qty = Auctionworthy:QuestionLink(message)
	if not link or RecentlyQuoted(sender, link, qty) then
		return
	end
	if Auctionworthy:ScanBusy() then
		return
	end
	if Auctionworthy:IsCrateLink(link) then
		local bundles = Auctionworthy:CachedBundles(link)
		if not bundles then
			return
		end
		local crateID = Auctionworthy:ItemID(link)
		local priceLink = (crateID and Auctionworthy:ItemLink(crateID)) or link
		Auctionworthy:WhisperLine(Auctionworthy:CheapestLine(bundles, qty), sender)
		Auctionworthy:WhisperLine(Auctionworthy:EmptyValueLine(priceLink, qty), sender)
		return
	end
	Auctionworthy:ReplyItemSell(link, sender, qty)
end

local question = CreateFrame("Frame")
question:SetScript("OnEvent", function(_, _, message, sender)
	ReplyToQuestion(message, sender)
end)
question:RegisterEvent("CHAT_MSG_PARTY")
question:RegisterEvent("CHAT_MSG_PARTY_LEADER")
question:RegisterEvent("CHAT_MSG_RAID")
question:RegisterEvent("CHAT_MSG_RAID_LEADER")

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", Install)
