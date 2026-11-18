-- Incoming whispers. Remembers who posted item links. Query plus one item link
-- whispers the cheapest fill or AH / vendor.

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:SetScript("OnEvent", function(_, _, message, sender)
	Auctionworthy:RememberPoster(message, sender)
	Auctionworthy:HandleQuestion(message, sender)
end)
