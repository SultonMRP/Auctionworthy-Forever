-- LibDBIcon-1.0 + LDB launcher. Button name LibDBIcon10_Auctionworthy
-- is parented to Minimap so SexyMap / MinimapButtonButton can collect it.
-- Clicks are listed on the tooltip (AtlasLoot style). No extra menu window.

local ICON_NAME = "Auctionworthy"
local GOLD_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local TT_ENTRY = "|cFFCFCFCF%s:|r %s"

local ldbPlugin

local function MinimapDB()
	local db = Auctionworthy:GetOption("minimapIcon")
	if type(db) ~= "table" then
		db = { hide = false, minimapPos = 200 }
		Auctionworthy:SetOption("minimapIcon", db)
	end
	if db.minimapPos == nil then
		db.minimapPos = 200
	end
	if db.hide == nil then
		db.hide = false
	end
	return db
end

local function ShiftDown()
	if Auctionworthy:SkipClicks() then
		return false
	end
	if not IsShiftKeyDown then
		return false
	end
	local ok, down = pcall(IsShiftKeyDown)
	if not ok or Auctionworthy:Secret(down) then
		return false
	end
	return down and true or false
end

local function ToggleGatherList()
	if Auctionworthy:SkipClicks() then
		return
	end
	local on = Auctionworthy:GetOption("showGatherList") ~= false
	Auctionworthy:SetOption("showGatherList", not on)
	if Auctionworthy.UpdateGatherList then
		Auctionworthy:UpdateGatherList()
	end
	if Auctionworthy.RefreshOptionChecks then
		Auctionworthy:RefreshOptionChecks()
	end
end

local function ToggleIgnoreQuery()
	if Auctionworthy:SkipClicks() then
		return
	end
	local ignore = not Auctionworthy:GetOption("ignoreQuestionRequests")
	Auctionworthy:SetOption("ignoreQuestionRequests", ignore)
	if Auctionworthy.RefreshOptionChecks then
		Auctionworthy:RefreshOptionChecks()
	end
	if ignore then
		print("|cffffd100Auctionworthy-Forever:|r ? Query disabled")
	else
		print("|cffffd100Auctionworthy-Forever:|r ? Query enabled")
	end
end

local function BindLDB(obj)
	obj.type = "launcher"
	obj.label = "Auctionworthy"
	obj.icon = GOLD_ICON
	obj.OnClick = function(_, button)
		if button == "RightButton" then
			if ShiftDown() then
				ToggleIgnoreQuery()
			else
				ToggleGatherList()
			end
		elseif button == "LeftButton" then
			if Auctionworthy.OpenOptions then
				Auctionworthy:OpenOptions()
			end
		end
	end
	obj.OnTooltipShow = function(tt)
		tt:AddLine("|cffffd100Auctionworthy-Forever|r")
		tt:AddLine(format(TT_ENTRY, "Left Click", "Open options"))
		tt:AddLine(format(TT_ENTRY, "Right Click", "Toggle gather list"))
		tt:AddLine(format(TT_ENTRY, "Shift + Right Click", "Ignore ? query"))
		tt:AddLine(format(TT_ENTRY, "Drag", "Move around minimap"))
	end
end

function Auctionworthy:CreateMinimapButton()
	local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	if not ldb or not icon then
		return
	end
	local obj = ldb.GetDataObjectByName and ldb:GetDataObjectByName(ICON_NAME)
	if not obj then
		obj = ldb:NewDataObject(ICON_NAME, {
			type = "launcher",
			label = "Auctionworthy",
			icon = GOLD_ICON,
		})
	end
	if not obj then
		return
	end
	BindLDB(obj)
	ldbPlugin = obj
	local db = MinimapDB()
	if icon:IsRegistered(ICON_NAME) then
		if icon.Refresh then
			icon:Refresh(ICON_NAME, db)
		end
		return
	end
	if Auctionworthy:SkipClicks() then
		return
	end
	icon:Register(ICON_NAME, obj, db)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:RegisterEvent("PLAYER_ALIVE")
boot:RegisterEvent("PLAYER_UNGHOST")
boot:SetScript("OnEvent", function()
	Auctionworthy:CreateMinimapButton()
end)
