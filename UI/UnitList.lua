include("InstanceManager")
include("SupportFunctions")

	-- game speed
	local bXPScaling = true -- default VP

	for t in GameInfo.CustomModOptions{Name="BALANCE_CORE_SCALING_XP"} do 
		bXPScaling = (t.Value == 1) 
	end

	-- acquire game speed modifier
	local fGameSpeedModifier = 1.0 -- it is float, so use 'f' at begining

	if bXPScaling then 
		fGameSpeedModifier = GameInfo.GameSpeeds[ Game.GetGameSpeedType() ].TrainPercent / 100 
	end
			
local m_MilitaryIM = InstanceManager:new("UnitInstance", "Root", Controls.MilitaryStack)
local m_CivilianIM = InstanceManager:new("UnitInstance", "Root", Controls.CivilianStack)

local eName       = 0
local eStatus     = 1
local eExperience = 2
local eDamage     = 3
local eUpgrade    = 4
local eMovement   = 5

local m_SortTable
local m_SortMode = eName
local m_bSortReverse = false


-- open window
function ShowHideHandler(bIsHide)
    if not bIsHide then
        UpdateDisplay()
    end
end
ContextPtr:SetShowHideHandler(ShowHideHandler)

-- close window
function OnClose()
    ContextPtr:SetHide(true)
    Events.OpenInfoCorner(InfoCornerID.None)
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose)

-- escape button
function InputHandler(uiMsg, wParam, lParam)
	if uiMsg == KeyEvents.KeyDown then
		if wParam == Keys.VK_ESCAPE then --or wParam == Keys.VK_RETURN then
			OnClose()
			return true
		end
    end
end
ContextPtr:SetInputHandler(InputHandler)

-- on opening functions
function OnOpenInfoCorner(iInfoType)
    if iInfoType == InfoCornerID.Units then
        ContextPtr:SetHide(false)
        OnSort(m_SortMode)
    else
        ContextPtr:SetHide(true)
    end
end
Events.OpenInfoCorner.Add(OnOpenInfoCorner)

-- move to overview
function OpenOverview()
	Events.SerialEventGameMessagePopup({Type = ButtonPopupTypes.BUTTONPOPUP_MILITARY_OVERVIEW})
end
Controls.OpenOverviewButton:RegisterCallback(Mouse.eLClick, OpenOverview)

-- on change event
function OnChangeEvent()
    if ContextPtr:IsHidden() == false then
        UpdateDisplay()
    end
end
Events.SerialEventUnitDestroyed.Add(OnChangeEvent)
Events.SerialEventUnitSetDamage.Add(OnChangeEvent)
Events.UnitStateChangeDetected.Add(OnChangeEvent)
Events.SerialEventUnitCreated.Add(OnChangeEvent)
Events.UnitSelectionChanged.Add(OnChangeEvent)
Events.UnitActionChanged.Add(OnChangeEvent)
Events.UnitFlagUpdated.Add(OnChangeEvent)
Events.UnitGarrison.Add(OnChangeEvent)
Events.UnitEmbark.Add(OnChangeEvent)
Events.SerialEventUnitMoveToHexes.Add(OnChangeEvent)
Events.SerialEventUnitMove.Add(OnChangeEvent)
Events.SerialEventUnitTeleportedToHex.Add(OnChangeEvent)
Events.GameplaySetActivePlayer.Add(OnChangeEvent)


-- main function
function UpdateDisplay()
    m_SortTable = {}

    local pPlayer = Players[Game.GetActivePlayer()]
    
    local bFoundMilitary = false
    local bFoundCivilian = false
    local pSelectedUnit = UI:GetHeadSelectedUnit()
    local iSelectedUnit = -1
    
	if pSelectedUnit ~= nil then
        iSelectedUnit = pSelectedUnit:GetID()
    end
    
    m_MilitaryIM:ResetInstances()
    m_CivilianIM:ResetInstances()
   
    for unit in pPlayer:Units() do
        local instance
        local iUnit = unit:GetID()
        local iUnitType = Locale.Lookup(unit:GetNameKey())
		local iUnitName = Locale.ConvertTextKey(unit:GetName())
		local bIsMilitary = false
		local bIsCivilian = false
    
        -- category
		if unit:IsCombatUnit() or unit:GetDomainType() == DomainTypes.DOMAIN_AIR then
            instance = m_MilitaryIM:GetInstance()
            bFoundMilitary = true
			bIsMilitary = true
        else
            instance = m_CivilianIM:GetInstance()
            bFoundCivilian = true
			bIsCivilian = true
        end
        
        local sortEntry = {}
        m_SortTable[tostring(instance.Root)] = sortEntry
        
        -- click callback
		instance.Button:RegisterCallback(Mouse.eLClick, OnUnitClicked)
        instance.Button:SetVoid1(unit:GetID())
        		
        -- name
		if iUnitName ~= iUnitType then
			iUnitName = string.sub(iUnitName, 1, #iUnitName - #iUnitType - 3)
		end
		
		sortEntry.name = iUnitName
        TruncateString(instance.UnitName, 220, sortEntry.name)
		
        if unit:MovesLeft() > 0 then
            instance.Button:SetAlpha(1.0)
        else
            instance.Button:SetAlpha(0.6)
        end
        
        instance.SelectionFrame:SetHide(not (iSelectedUnit == iUnit))
        
		-- name tooltip
		
		if bIsMilitary then
			local sCS = tostring(unit:GetBaseCombatStrength())
			local sStatistics = sCS .. " [ICON_STRENGTH]"
			local iRCS = unit:GetBaseRangedCombatStrength()
		
			if iRCS > 0 then
				local sRCS = tostring(iRCS)
				local sRange = tostring(unit:Range())
				sStatistics = sStatistics .. "[NEWLINE]" .. sRCS .. "/" .. sRange .. " [ICON_RANGE_STRENGTH]"
			end
				
			instance.UnitName:SetToolTipString(sStatistics)
		elseif bIsCivilian then
			local condition = "ID = '" .. unit:GetUnitType() .. "'"
			
			for civilian in GameInfo.Units(condition) do
				if civilian.SpreadReligion and unit:GetSpreadsLeft() > 0 then
					instance.UnitName:SetToolTipString(tostring(unit:GetSpreadsLeft()) .. GameInfo.Religions[unit:GetReligion()].IconString)
				end
			end		
		end

		-- status field
        local sStatus = ""
		local iBuildType = unit:GetBuildType()
        local iActivityType = unit:GetActivityType()
		local isInCitadel = unit:GetPlot():GetImprovementType() == GameInfoTypes.IMPROVEMENT_CITADEL
		local isInFort = unit:GetPlot():GetImprovementType() == GameInfoTypes.IMPROVEMENT_FORT
		
		instance.Status:SetToolTipString(nil)
        
		if unit:IsEmbarked() then
            sortEntry.status = "TXT_KEY_LI_UNIT_STATUS_EMBARKED"
            instance.Status:SetHide(false)
       elseif unit:IsGarrisoned() or isInFort or isInCitadel then
			if unit:IsGarrisoned() then
				sStatus = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_IN_CITY")
			elseif isInFort then
				sStatus = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_IN_FORT")
			else
				sStatus = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_IN_CITADEL")
			end
						
			instance.Status:SetHide(false)

			if iActivityType == ActivityTypes.ACTIVITY_HEAL then
				sStatus = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_HEALING") .. " in " .. sStatus
			elseif iActivityType == ActivityTypes.ACTIVITY_SENTRY then
				sStatus = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_ALERT") .. " from " .. sStatus
			elseif unit:GetFortifyTurns() > 0 then
				sStatus = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_FORTIFIED") .. " in " .. sStatus
			else
				sStatus = "In " .. sStatus
			end
			
			sortEntry.status = sStatus
			
			local sPlace = ""
			local sCity = unit:GetPlot():GetWorkingCity():GetName()
			
			if unit:IsGarrisoned() then
				sPlace = "Garrisoned in " .. sCity
			elseif isInFort then
				sPlace = "Garrisoned in Fort near " .. sCity
			else
				sPlace = "Garrisoned in Citadel near " .. sCity
			end
			
			instance.Status:SetToolTipString(sPlace)
        elseif iActivityType == ActivityTypes.ACTIVITY_HEAL then
			sortEntry.status = "TXT_KEY_LI_UNIT_STATUS_HEALING"
			instance.Status:SetHide(false)
		elseif iActivityType == ActivityTypes.ACTIVITY_SENTRY then
			sortEntry.status = "TXT_KEY_LI_UNIT_STATUS_ALERT"
			instance.Status:SetHide(false)
        elseif unit:GetFortifyTurns() > 0 then
            sortEntry.status = "TXT_KEY_LI_UNIT_STATUS_FORTIFIED"
            instance.Status:SetHide(false)
        elseif iActivityType == ActivityTypes.ACTIVITY_SLEEP then
			sortEntry.status = "TXT_KEY_LI_UNIT_STATUS_SLEEPING"
			instance.Status:SetHide(false)
		elseif iBuildType ~= -1 then -- this is a worker who is actively building something
    		local sThisBuild = GameInfo.Builds[iBuildType]
    		local sCivilianUnitStr = ""

			local skip = {}
			local bStart = true

			for word in string.gmatch(Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_BUILD_SKIP_WORDS"), "[^%s]+") do 
			   skip[word] = true
			end

			for word in string.gmatch(Locale.ConvertTextKey(sThisBuild.Description), "[^%s]+") do 
				if not (bStart and skip[word]) then
					sCivilianUnitStr = sCivilianUnitStr .. " " .. word 
					bStart = false
				end
			end
			
    		local iTurnsLeft = unit:GetPlot():GetBuildTurnsLeft(iBuildType, 0, 0)	
    		
			if iTurnsLeft < 4000 and iTurnsLeft > 0 then
    			sCivilianUnitStr = sCivilianUnitStr.." ("..tostring(iTurnsLeft)..") "
    		end
            
			sortEntry.status = sCivilianUnitStr
            instance.Status:SetHide(false)   
    	elseif unit:IsWork() and unit:IsAutomated() then
			sortEntry.status = "TXT_KEY_LI_UNIT_STATUS_WORKER_AUTOMATED"
			instance.Status:SetHide(false)
		elseif unit:IsAutomated() then
			if unit.IsTrade ~= nil and unit:IsTrade() then
				if Game.GetTradeRoute then
					local iRoute = unit:GetTradeRouteIndex()
					
					if iRoute ~= -1 then
						local route = Game.GetTradeRoute(iRoute)
						
						if route then
							local sRecall = ""
							
							if unit:IsRecalledTrader() then
								if route.MovingForward then
									sRecall = Locale.Lookup("TXT_KEY_LI_UNIT_STATUS_RECALLING_TT")
								else
									sRecall = Locale.Lookup("TXT_KEY_LI_UNIT_STATUS_RECALLED_TT")
								end
							end
							
							sortEntry.status = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_TRADING", route.TurnsLeft)
							instance.Status:SetHide(false)
							instance.Status:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_TRADING_TT", route.FromCityName, route.ToCityName, sRecall))
						end
					end
				end
			else
				sortEntry.status = "TXT_KEY_LI_UNIT_STATUS_EXPLORING"
				instance.Status:SetHide(false)
			end
		else
            sortEntry.status = ""
            instance.Status:SetHide(true)
        end
                
        if sortEntry.status ~= "" then
		    instance.Status:LocalizeAndSetText(sortEntry.status)
	    else
		    instance.Status:SetText("")
	    end
	    
	    local statusY = instance.Status:GetSizeY()
	    statusY = statusY + 10
	    
		if statusY > 24 then
		   instance.ExperienceBox:SetSizeY(statusY) 
		   instance.StatusBox:SetSizeY(statusY) 
		   instance.SelectionFrame:SetSizeY(statusY)
		   instance.Root:SetSizeY(statusY)
		   instance.SelectHL:SetSizeY(statusY)
		   instance.SelectAnim:SetSizeY(statusY)
        end

		-- moves
	    local iMovesDenominator = GameDefines["MOVE_DENOMINATOR"]
	    local iMovesLeft = unit:MovesLeft() / iMovesDenominator
	    local iMaxMoves = unit:MaxMoves() / iMovesDenominator
        
		sortEntry.movement = iMovesLeft
        
        if iMovesLeft == iMaxMoves then
            instance.MovementPip:SetTextureOffsetVal(0, 0)
        elseif iMovesLeft == 0 then
            instance.MovementPip:SetTextureOffsetVal(0, 96)
        else
            instance.MovementPip:SetTextureOffsetVal(0, 32)
        end  
        
		-- upgrade
		local iUpgradeCost = 0
		
		if unit:CanUpgradeRightNow() then
			iUpgradeCost = unit:UpgradePrice(unit:GetUpgradeUnitType())
	        instance.Upgrade:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_UPGRADE_TT", GameInfo.Units[unit:GetUpgradeUnitType()].Description, iUpgradeCost))
			instance.Upgrade:SetText("[ICON_GOLD]")
			instance.UpgradeButton:RegisterCallback(Mouse.eLClick, OnUnitUpgrade)
			instance.UpgradeButton:SetVoid1(unit:GetID())
		end
		
        sortEntry.upgrade = iUpgradeCost
        instance.Upgrade:SetHide(iUpgradeCost == 0)

		-- hp
        if unit:IsCombatUnit() or (unit:GetDomainType() == DomainTypes.DOMAIN_AIR and GameInfo.Units[unit:GetUnitType()].Suicide == false) then
			local damage = unit:GetDamage()
			local iMaxDamage = unit:GetMaxHitPoints()
			local iHealth = iMaxDamage - damage
			local iHealthTimes100 =  math.floor(100 * (iHealth/iMaxDamage) + 0.5)
		
			if iHealthTimes100 > 90 then
			  sTextColour = "[COLOR:115:215:110:255]"
			elseif iHealthTimes100 > 75 then
			  sTextColour = "[COLOR:175:175:0:255]"
			elseif iHealthTimes100 > 50 then
			  sTextColour = "[COLOR_YELLOW]"
			elseif iHealthTimes100 > 25 then
			  sTextColour = "[COLOR_YIELD_FOOD]"
			else
			  sTextColour = "[COLOR_NEGATIVE_TEXT]"
			end

			sortEntry.damage = iHealth
			instance.Damage:SetHide(false)
  			instance.Damage:SetText(string.format("%s%i[ENDCOLOR]", sTextColour, iHealth))

			instance.Damage:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_UPANEL_SET_HITPOINTS_TT",(iMaxDamage-damage), iMaxDamage))
    	else
            sortEntry.damage = 0
            instance.Damage:SetHide(true)
  			instance.Damage:SetText("")
        end
        
        -- xp
        if unit:IsCombatUnit() or (unit:GetDomainType() == DomainTypes.DOMAIN_AIR and GameInfo.Units[unit:GetUnitType()].Suicide == false) then
            local iExperience = unit:GetExperience()
            local iNeededExperience = unit:ExperienceNeeded()
			local iLevel = unit:GetLevel()
			local sColour = ""
			local sColourEnd = ""
			
			if iExperience >= iNeededExperience then
				sColour = "[COLOR:115:215:110:255]"
				sColourEnd = "[ENDCOLOR]"
			elseif ((iExperience - iNeededExperience) / (iLevel * math.floor(10 * fGameSpeedModifier))) + 1 >= 0.75 then
				sColour = "[COLOR_YELLOW]"
				sColourEnd = "[ENDCOLOR]"
			end
			
			local sExperienceAndLevel = sColour .. tostring(iExperience) .. ":" .. tostring(iLevel) .. sColourEnd
			
			sortEntry.iExperience = iExperience
            instance.Experience:SetHide(false)
  			instance.Experience:SetText(sExperienceAndLevel)

			-- MOD - if we have support for XP times 100, show that in the tooltip instead
			if unit.GetExperienceTimes100 then
				iExperience = iExperience * 100
				iNeededExperience = iNeededExperience * 100
			end			
			
			-- promotion list
			local sPromotions = ""
			
			for promotion in GameInfo.UnitPromotions() do
				if unit:IsHasPromotion(promotion.ID) then
					if sPromotions == "" then
						sPromotions = Locale.ConvertTextKey(promotion.Description)
					else
						sPromotions = sPromotions .. "[NEWLINE]" .. Locale.ConvertTextKey(promotion.Description)
					end
				end
			end
			
			instance.Experience:SetToolTipString(sPromotions)
    	else
			sortEntry.iExperience = 0
			instance.Experience:SetHide(false)
  			instance.Experience:SetText("")
		end
        
		instance.UnitStack:CalculateSize()
		instance.UnitStack:ReprocessAnchoring()
        
        sortEntry.unit = unit
    end


    if bFoundMilitary and bFoundCivilian then
        Controls.CivilianSeperator:SetHide(false)
    else
        Controls.CivilianSeperator:SetHide(true)
    end
     
    Controls.MilitaryStack:SortChildren(SortFunction)
    Controls.CivilianStack:SortChildren(SortFunction)
    
    Controls.MilitaryStack:CalculateSize()
    Controls.MilitaryStack:ReprocessAnchoring()
    Controls.CivilianStack:CalculateSize()
    Controls.CivilianStack:ReprocessAnchoring()
    
    Controls.MainStack:CalculateSize()
    Controls.MainStack:ReprocessAnchoring()
    Controls.ScrollPanel:CalculateInternalSize()
    
    Controls.ScrollPanel:ReprocessAnchoring()
end

-------------
-- actions --
-------------
-- center scren on unit
function OnUnitClicked(unitID)
    local pSelectedUnit = UI:GetHeadSelectedUnit()
    
	if pSelectedUnit ~= nil and pSelectedUnit:GetID() == unitID then
        UI.LookAtSelectionPlot(0)
    else
        Events.SerialEventUnitFlagSelected(Game:GetActivePlayer(), unitID)
		UI.LookAt(Players[Game.GetActivePlayer()]:GetUnitByID(unitID):GetPlot(), 0)
    end
end

-- upgrade unit
function OnUnitUpgrade(unitID)
	local pUnit = Players[Game.GetActivePlayer()]:GetUnitByID(unitID)
	
	Events.SerialEventUnitFlagSelected(Game.GetActivePlayer(), unitID)
	UI.LookAt(pUnit:GetPlot(), 0)
	
	if pUnit.Upgrade then
		pUnit:Upgrade()
	end
end

-------------
-- sorting --
-------------
-- sorting function
function SortFunction(a, b)
    local valueA, valueB
    local entryA = m_SortTable[tostring(a)]
    local entryB = m_SortTable[tostring(b)]
	
    if entryA == nil or entryB == nil then 
		if entryA and entryB == nil then
			return false
		elseif entryA == nil and entryB then
			return true
		else
			if m_bSortReverse then
				return tostring(a) > tostring(b) -- gotta do something deterministic
			else
				return tostring(a) < tostring(b) -- gotta do something deterministic
			end
        end
    else
		if m_SortMode == eName then
			valueA = entryA.name
			valueB = entryB.name
		elseif m_SortMode == eStatus then
			valueA = entryA.status
			valueB = entryB.status
		elseif m_SortMode == eDamage then
			valueA = entryB.damage
			valueB = entryA.damage
		elseif m_SortMode == eExperience then
			valueA = entryB.iExperience
			valueB = entryA.iExperience
		elseif m_SortMode == eUpgrade then
			valueA = entryB.upgrade
			valueB = entryA.upgrade
		else -- movement
			valueA = entryA.movement
			valueB = entryB.movement
		end
	    
		if valueA == valueB then
			valueA = entryA.unit:GetID()
			valueB = entryB.unit:GetID()
		end
	    
	   
		if m_bSortReverse then
			return valueA > valueB
		else
			return valueA < valueB
		end
    end
end

function OnSort(type)
    if m_SortMode == type then
        m_bSortReverse = not m_bSortReverse
    else
        m_bSortReverse = false
    end

    m_SortMode = type
    
	Controls.MilitaryStack:SortChildren(SortFunction)
    Controls.CivilianStack:SortChildren(SortFunction)
end

Controls.SortName:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortStatus:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortDamage:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortExperience:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortUpgrade:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortMovement:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortName:SetVoid1(eName)
Controls.SortStatus:SetVoid1(eStatus)
Controls.SortDamage:SetVoid1(eDamage)
Controls.SortExperience:SetVoid1(eExperience)
Controls.SortUpgrade:SetVoid1(eUpgrade)
Controls.SortMovement:SetVoid1(eMovement)
