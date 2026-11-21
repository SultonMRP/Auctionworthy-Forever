-- Items that have a vendor sell price.
-- Auction costs are the 5% cut only. Profit is what a sold listing pays
-- (undercut price minus that cut). Deposit is refunded on a sale, so it is
-- not in profit. Expire or cancel is on the player (not shown on the deposit line).
-- Auction it only when that profit is strictly more than vendor. Equal or less
-- says Sell to vendor (Auctionator's "more gold at a vendor" warning).
-- GetItemInfo can return a 1c stub on items vendors reject (enchanting mats).
-- Those are treated as no vendor price so they do not leak into costs or profit.

local function TradeGoodsClass()
	if Enum and Enum.ItemClass then
		return Enum.ItemClass.Tradegoods or Enum.ItemClass.TradeGoods or 7
	end
	return LE_ITEM_CLASS_TRADEGOODS or 7
end

local function EnchantingSubclass()
	if Enum and Enum.ItemTradeskillSubclass and Enum.ItemTradeskillSubclass.Enchanting then
		return Enum.ItemTradeskillSubclass.Enchanting
	end
end

function Auctionworthy:VendorRejectsItem(classID, subclassID, itemType, subType)
	if type(subType) == "string" and not Auctionworthy:Secret(subType) and strlower(subType) == "enchanting" then
		return true
	end
	if type(itemType) == "string" and not Auctionworthy:Secret(itemType) and strlower(itemType) == "enchanting" then
		return true
	end
	classID = tonumber(classID)
	subclassID = tonumber(subclassID)
	if not classID or not subclassID then
		return false
	end
	if classID ~= TradeGoodsClass() then
		return false
	end
	local enchanting = EnchantingSubclass()
	if enchanting then
		return subclassID == enchanting
	end
	return subclassID == 11
end

function Auctionworthy:VendorSellPrice(vendorPrice, classID, subclassID, itemType, subType)
	if Auctionworthy:Secret(vendorPrice) then
		return 0
	end
	vendorPrice = tonumber(vendorPrice) or 0
	if vendorPrice <= 0 then
		return 0
	end
	if Auctionworthy:VendorRejectsItem(classID, subclassID, itemType, subType) then
		return 0
	end
	return vendorPrice
end

function Auctionworthy:VendorDeposit(vendorPrice)
	vendorPrice = tonumber(vendorPrice) or 0
	return math.floor(vendorPrice * 0.6)
end

function Auctionworthy:VendorAuctionCut(auctionPrice)
	auctionPrice = tonumber(auctionPrice) or 0
	return math.floor(auctionPrice * 0.05)
end

function Auctionworthy:VendorAuctionCosts(auctionPrice)
	return Auctionworthy:VendorAuctionCut(auctionPrice)
end

function Auctionworthy:VendorVerdict(auctionPrice, vendorPrice)
	auctionPrice = tonumber(auctionPrice)
	if not auctionPrice then
		return
	end
	vendorPrice = tonumber(vendorPrice) or 0
	local costs = Auctionworthy:VendorAuctionCosts(auctionPrice)
	local profit = auctionPrice - costs
	local deposit = Auctionworthy:VendorDeposit(vendorPrice)
	local beatsVendor = profit > vendorPrice
	if vendorPrice <= 0 then
		beatsVendor = profit > 0
	end
	if beatsVendor then
		local note = vendorPrice > 0 and " (above vendor)" or ""
		return {
			auctionPrice = auctionPrice,
			costs = costs,
			deposit = deposit,
			profit = profit,
			vendorPrice = vendorPrice,
			beatsVendor = true,
			decisionText = "Auction it!",
			red = 0,
			green = 1,
			blue = 0,
			chatLine = "AH it: " .. Auctionworthy:FormatChatMoney(profit) .. note,
		}
	end
	local chatLine
	if vendorPrice > 0 and profit > 0 then
		local below = vendorPrice - profit
		chatLine = "Vendor it: AH " .. Auctionworthy:FormatChatMoney(profit) .. " (" .. Auctionworthy:FormatChatMoney(below) .. " below vendor)"
	else
		chatLine = "Vendor it: " .. Auctionworthy:FormatChatMoney(-profit) .. " loss if posted on AH"
	end
	return {
		auctionPrice = auctionPrice,
		costs = costs,
		deposit = deposit,
		profit = profit,
		vendorPrice = vendorPrice,
		beatsVendor = false,
		decisionText = "Sell to vendor!",
		red = 1,
		green = 0,
		blue = 0,
		chatLine = chatLine,
	}
end
