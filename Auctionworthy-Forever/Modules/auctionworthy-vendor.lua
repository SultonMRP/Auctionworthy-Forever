-- Items that have a vendor sell price.
-- Profit is the undercut auction price minus the vendor value, the deposit, and the 5% cut.
-- A gain says Auction it. A loss says Sell to vendor.

function Auctionworthy:VendorAuctionCosts(vendorPrice)
	vendorPrice = tonumber(vendorPrice) or 0
	return math.floor(vendorPrice * 0.6) + vendorPrice + math.floor(vendorPrice * 0.05)
end

function Auctionworthy:VendorVerdict(auctionPrice, vendorPrice)
	auctionPrice = tonumber(auctionPrice)
	if not auctionPrice then
		return
	end
	local costs = Auctionworthy:VendorAuctionCosts(vendorPrice)
	local profit = auctionPrice - costs
	if profit > 0 then
		return {
			auctionPrice = auctionPrice,
			costs = costs,
			profit = profit,
			decisionText = "Auction it!",
			red = 0,
			green = 1,
			blue = 0,
			chatLine = "AH it: " .. Auctionworthy:FormatChatMoney(profit),
		}
	end
	return {
		auctionPrice = auctionPrice,
		costs = costs,
		profit = profit,
		decisionText = "Sell to vendor!",
		red = 1,
		green = 0,
		blue = 0,
		chatLine = "Vendor it: " .. Auctionworthy:FormatChatMoney(-profit) .. " loss if posted on AH",
	}
end
