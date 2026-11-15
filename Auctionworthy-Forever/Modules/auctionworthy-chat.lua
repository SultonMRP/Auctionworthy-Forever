-- Say, party, raid, and loot links. Posts to Raid, Party, or Say.
-- Crate Query plus one crate link in party or raid whispers that person the cheapest fill, then the empty crate value.
-- Any other item link whispers AH it and the profit, or Vendor it and the loss.
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
	Auctionworthy:EachChatClick(function(kind, _, link)
		if not POST[kind] then
			return
		end
		Auctionworthy:ClickDebug("chat " .. kind)
		Auctionworthy:PostCrate(link)
	end)
end

local recentQuotes = {}

local function QuestionLink(message)
	if type(message) ~= "string" or message == "" or Auctionworthy:Secret(message) then
		return
	end
	local body = strtrim(message)
	local query = Auctionworthy:CrateQuery()
	if type(query) ~= "string" or query == "" or Auctionworthy:Secret(query) then
		query = "?"
	end
	if strlower(body:sub(1, #query)) ~= strlower(query) then
		return
	end
	local rest = strtrim(body:sub(#query + 1))
	if rest == "" or Auctionworthy:Secret(rest) then
		return
	end
	local _, count = rest:gsub("|Hitem:", "")
	if count == 0 then
		_, count = rest:gsub("item:%d+", "")
	end
	if count ~= 1 then
		return
	end
	local plain = rest:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^|]*", ""):gsub("|r", "")
	plain = plain:gsub("|H.-|h", ""):gsub("|h", ""):gsub("%[.-%]", "")
	if strtrim(plain) ~= "" then
		return
	end
	local link = rest:match("(|cn[^|]*|Hitem:[^|]-|h%[.-%]|h|r)")
		or rest:match("(|c%x%x%x%x%x%x%x%x|Hitem:[^|]-|h%[.-%]|h|r)")
		or rest:match("(|Hitem:[^|]-|h%[.-%]|h)")
	if type(link) == "string" and link ~= "" and not Auctionworthy:Secret(link) then
		return link
	end
	local itemID = tonumber(rest:match("item:(%d+)"))
	if itemID and itemID > 0 then
		return "item:" .. itemID
	end
end

local function RecentlyQuoted(sender, link)
	local key = strlower(sender) .. ":" .. tostring(Auctionworthy:ItemID(link) or link)
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
	local link = QuestionLink(message)
	if not link or RecentlyQuoted(sender, link) then
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
		Auctionworthy:WhisperLine(Auctionworthy:CheapestLine(bundles), sender)
		Auctionworthy:WhisperLine(Auctionworthy:EmptyValueLine(priceLink), sender)
		return
	end
	Auctionworthy:ReplyItemSell(link, sender)
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
