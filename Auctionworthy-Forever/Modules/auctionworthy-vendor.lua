-- Items that have a vendor sell price.
-- All profit/loss is sold-listing only: undercut auction price minus vendor value
-- and the 5% cut. Deposit is refunded on a sale, so it is not in profit. Expire or
-- cancel is on the player (not shown on the deposit line).
-- A gain says Auction it. A loss says Sell to vendor.

function Auctionworthy:VendorDeposit(vendorPrice)
	vendorPrice = tonumber(vendorPrice) or 0
	return math.floor(vendorPrice * 0.6)
end

function Auctionworthy:VendorAuctionCut(auctionPrice)
	auctionPrice = tonumber(auctionPrice) or 0
	return math.floor(auctionPrice * 0.05)
end

function Auctionworthy:VendorAuctionCosts(auctionPrice, vendorPrice)
	vendorPrice = tonumber(vendorPrice) or 0
	return vendorPrice + Auctionworthy:VendorAuctionCut(auctionPrice)
end

function Auctionworthy:VendorVerdict(auctionPrice, vendorPrice)
	auctionPrice = tonumber(auctionPrice)
	if not auctionPrice then
		return
	end
	local costs = Auctionworthy:VendorAuctionCosts(auctionPrice, vendorPrice)
	local profit = auctionPrice - costs
	local deposit = Auctionworthy:VendorDeposit(vendorPrice)
	if profit > 0 then
		return {
			auctionPrice = auctionPrice,
			costs = costs,
			deposit = deposit,
			profit = profit,
			decisionText = "Auction it!",
			red = 0,
			green = 1,
			blue = 0,
			chatLine = "AH it: " .. Auctionworthy:FormatChatMoney(profit) .. " (if sold)",
		}
	end
	return {
		auctionPrice = auctionPrice,
		costs = costs,
		deposit = deposit,
		profit = profit,
		decisionText = "Sell to vendor!",
		red = 1,
		green = 0,
		blue = 0,
		chatLine = "Vendor it: " .. Auctionworthy:FormatChatMoney(-profit) .. " loss if posted on AH",
	}
end
