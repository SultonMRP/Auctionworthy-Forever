-- Items with no vendor sell price.
-- Same profit and loss math as a vendor item. A loss says non-vendorable.

function Auctionworthy:NonVendorVerdict(auctionPrice, vendorPrice)
	local verdict = Auctionworthy:VendorVerdict(auctionPrice, vendorPrice)
	if verdict and verdict.profit <= 0 then
		verdict.decisionText = "non-vendorable"
		verdict.chatLine = "non-vendorable: " .. Auctionworthy:FormatChatMoney(-verdict.profit) .. " loss if posted on AH"
	end
	return verdict
end
