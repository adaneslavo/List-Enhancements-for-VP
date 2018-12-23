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
local eDamage     = 1
local eStatus     = 2
local eExperience = 3
local eUpgrade    = 4
local eMovement   = 5

local m_tSortTable
local m_iSortMode = eName
local m_bSortReverse = false

local m_tExperience = {}
local m_bDeadUnit = false

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
        OnSort(m_iSortMode)
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
GameEvents.UnitPromoted.Add(OnChangeEvent)

-- main function
function UpdateDisplay()
	m_tSortTable = {}
	
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
   
	-- check for dead units
	local bCheckedAndDeadPermanent = false
	
	for id, xp in pairs(m_tExperience) do
		local bCheckedAndDead = true
		
		for unit in pPlayer:Units() do
			iUnit = unit:GetID()
			
			if iUnit == id then
				bCheckedAndDead = false
				break
			end
		end
	
		if bCheckedAndDead == true then
			m_tExperience[id] = nil
			bCheckedAndDeadPermanent = true
		end
	end
	
	-- main loop
    for unit in pPlayer:Units() do
        local instance
        local iUnit = unit:GetID()
        local iUnitType = Locale.Lookup(unit:GetNameKey())
		local iUnitName = Locale.ConvertTextKey(unit:GetName())
		local bIsMilitary = false
		local bIsCivilian = false
		local sStatistics
		
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
        m_tSortTable[tostring(instance.Root)] = sortEntry
        
        -- click callback
		instance.Button:RegisterCallback(Mouse.eLClick, OnUnitClicked)
        instance.Button:SetVoid1(unit:GetID())
        		
        -- name
		if iUnitName ~= iUnitType then
			iUnitName = string.sub(iUnitName, 1, #iUnitName - #iUnitType - 3)
		end
		
		sortEntry.Name = iUnitName
        TruncateString(instance.UnitName, 140, sortEntry.Name)
		
        if unit:MovesLeft() > 0 then
            instance.Button:SetAlpha(1.0)
        else
            instance.Button:SetAlpha(0.6)
        end
        
        instance.SelectionFrame:SetHide(not (iSelectedUnit == iUnit))
        
		-- name tooltip
		if bIsMilitary then
			local sCS = tostring(unit:GetBaseCombatStrength())
			sStatistics = sCS .. " [ICON_STRENGTH]"
			local iRCS = unit:GetBaseRangedCombatStrength()
		
			if iRCS > 0 then
				local sRCS = tostring(iRCS)
				local sRange = tostring(unit:Range())
				sStatistics = sStatistics .. "[NEWLINE]" .. sRCS .. "/" .. sRange .. " [ICON_RANGE_STRENGTH]"
			end
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
            sortEntry.Status = "TXT_KEY_LI_UNIT_STATUS_EMBARKED"
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
			
			sortEntry.Status = sStatus
			
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
			sortEntry.Status = "TXT_KEY_LI_UNIT_STATUS_HEALING"
			instance.Status:SetHide(false)
		elseif iActivityType == ActivityTypes.ACTIVITY_SENTRY then
			sortEntry.Status = "TXT_KEY_LI_UNIT_STATUS_ALERT"
			instance.Status:SetHide(false)
        elseif unit:GetFortifyTurns() > 0 then
            sortEntry.Status = "TXT_KEY_LI_UNIT_STATUS_FORTIFIED"
            instance.Status:SetHide(false)
        elseif iActivityType == ActivityTypes.ACTIVITY_SLEEP then
			sortEntry.Status = "TXT_KEY_LI_UNIT_STATUS_SLEEPING"
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
            
			sortEntry.Status = sCivilianUnitStr
            instance.Status:SetHide(false)   
    	elseif unit:IsWork() and unit:IsAutomated() then
			sortEntry.Status = "TXT_KEY_LI_UNIT_STATUS_WORKER_AUTOMATED"
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
							
							sortEntry.Status = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_TRADING", route.TurnsLeft)
							instance.Status:SetHide(false)
							instance.Status:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_TRADING_TT", route.FromCityName, route.ToCityName, sRecall))
						end
					end
				end
			else
				sortEntry.Status = "TXT_KEY_LI_UNIT_STATUS_EXPLORING"
				instance.Status:SetHide(false)
			end
		else
            sortEntry.Status = ""
            instance.Status:SetHide(true)
        end
                
        if sortEntry.Status ~= "" then
		    instance.Status:LocalizeAndSetText(sortEntry.Status)
	    else
		    instance.Status:SetText("")
	    end
	    
	    local statusY = instance.Status:GetSizeY()
	    statusY = statusY + 10
	    
		if statusY > 28 then
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
        
		sortEntry.Movement = iMovesLeft
        
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
			iUpgradeUnit = unit:GetUpgradeUnitType()
			
			iUpgradeCost = unit:UpgradePrice(iUpgradeUnit)
	        instance.Upgrade:SetText("[ICON_GOLD]")
			
			tUpgradeUnitData = GameInfo.Units[iUpgradeUnit]
						
			local sUpgradeTooltip = Locale.ConvertTextKey("TXT_KEY_LI_UNIT_STATUS_UPGRADE_TT", tUpgradeUnitData.Description, iUpgradeCost)
			sUpgradeTooltip = sUpgradeTooltip .. "[NEWLINE][NEWLINE]" .. tUpgradeUnitData.Combat .. "[ICON_STRENGTH]"
			
			if tUpgradeUnitData.RangedCombat > 0 then
				sUpgradeTooltip = sUpgradeTooltip .. "[NEWLINE]" .. tUpgradeUnitData.RangedCombat .. "/" .. tUpgradeUnitData.Range .. "[ICON_RANGE_STRENGTH]"
			end
			
			sUpgradeTooltip = sUpgradeTooltip .. "[NEWLINE]" .. Locale.ConvertTextKey(tUpgradeUnitData.Help)
			
			instance.Upgrade:SetToolTipString(sUpgradeTooltip)
			instance.UpgradeButton:RegisterCallback(Mouse.eLClick, OnUnitUpgrade)
			instance.UpgradeButton:SetVoid1(unit:GetID())
		end
		
        sortEntry.Upgrade = iUpgradeCost
        instance.Upgrade:SetHide(iUpgradeCost == 0)

		-- hp
        if bIsMilitary and GameInfo.Units[unit:GetUnitType()].Suicide == false then
			local iDamage = unit:GetDamage()
			local iMaxDamage = unit:GetMaxHitPoints()
			local iHealth = iMaxDamage - iDamage
			local iHealthTimes100 =  math.floor(100 * (iHealth/iMaxDamage) + 0.5)
			local iHealthPercent = 1 - (iDamage / iMaxDamage)
       		
			sortEntry.Damage = iHealth
			
			local sTextColour = "[COLOR:115:215:110:255]"
			
			if iHealthPercent < 1 then
				if iHealthTimes100 > 90 then
					instance.HealthBar:SetFGColor({x = 0.45, y = 0.84, z = 0.43, w = 1})
				elseif iHealthTimes100 > 75 then
					instance.HealthBar:SetFGColor({x = 0.69, y = 0.80, z = 0, w = 1})
					sTextColour = "[COLOR:175:200:0:255]"
				elseif iHealthTimes100 > 50 then
					instance.HealthBar:SetFGColor({x = 1, y = 1, z = 0, w = 1})
					sTextColour = "[COLOR_YELLOW]"
				elseif iHealthTimes100 > 25 then
					instance.HealthBar:SetFGColor({x = 1, y = 0.55, z = 0.15, w = 1})
					sTextColour = "[COLOR_YIELD_FOOD]"
				else
					instance.HealthBar:SetFGColor({x = 1, y = 0, z = 0, w = 1})
					sTextColour = "[COLOR_NEGATIVE_TEXT]"
				end
    			
				instance.HealthBarAnchor:SetHide(false)
        		instance.HealthBar:SetPercent(iHealthPercent)
			else
				instance.HealthBarAnchor:SetHide(true)
			end
			
			local sUnitNameTooltip = sStatistics .. "[NEWLINE][NEWLINE]" .. sTextColour .. iHealth .. "/" .. iMaxDamage .. " (" .. tostring(math.floor(iHealthPercent * 100)) .. "%)[ENDCOLOR][NEWLINE][NEWLINE]" .. Locale.ConvertTextKey(GameInfo.Units[unit:GetUnitType()].Help)
				
			instance.HealthBar:SetToolTipString(sUnitNameTooltip)
			instance.UnitName:SetToolTipString(sUnitNameTooltip)
		else
        	sortEntry.Damage = 0
    	end
        
		-- xp
        if bIsMilitary and GameInfo.Units[unit:GetUnitType()].Suicide == false then
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
			
			local sExperienceAndLevel = sColour .. iExperience .. ":" .. iLevel .. sColourEnd
			
			sortEntry.Experience = iExperience
            instance.Experience:SetHide(false)
  			instance.Experience:SetText(sExperienceAndLevel)
			
			if m_tExperience[iUnit] ~= sExperienceAndLevel or bCheckedAndDeadPermanent then
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
			end
			
			m_tExperience[iUnit] = sExperienceAndLevel
    	else
			sortEntry.Experience = 0
			instance.Experience:SetHide(false)
  			instance.Experience:SetText("")
		end
		
		instance.UnitStack:CalculateSize()
		instance.UnitStack:ReprocessAnchoring()
        
        sortEntry.Unit = unit
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
    
	local entryA = m_tSortTable[tostring(a)]
    local entryB = m_tSortTable[tostring(b)]
	
	local bReversedOrder = false
	
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
		if m_iSortMode == eName then
			valueA = entryA.Name
			valueB = entryB.Name
		elseif m_iSortMode == eDamage then
			valueA = entryB.Damage
			valueB = entryA.Damage
			bReversedOrder = true
		elseif m_iSortMode == eStatus then
			valueA = entryA.Status
			valueB = entryB.Status
		elseif m_iSortMode == eExperience then
			valueA = entryB.Experience
			valueB = entryA.Experience
		elseif m_iSortMode == eUpgrade then
			valueA = entryB.Upgrade
			valueB = entryA.Upgrade
		elseif m_iSortMode == eMovement then
			valueA = entryA.Movement
			valueB = entryB.Movement
			bReversedOrder = true
		end
	    
		if valueA == valueB then
			valueA = entryA.Unit:GetID()
			valueB = entryB.Unit:GetID()
		end
	    
	   
		if bReversedOrder then
			if m_bSortReverse then
				return valueA < valueB
			else
				return valueA > valueB
			end
		else
			if m_bSortReverse then
				return valueA > valueB
			else
				return valueA < valueB
			end
		end
    end
end

function OnSort(type)
    if m_iSortMode == type then
        m_bSortReverse = not m_bSortReverse
    else
        m_bSortReverse = false
    end

    m_iSortMode = type
    
	Controls.MilitaryStack:SortChildren(SortFunction)
    Controls.CivilianStack:SortChildren(SortFunction)
end

function OnSortAlternative(type)
    if type == eName then
		type = eDamage
	end
	
	if m_iSortMode == type then
        m_bSortReverse = not m_bSortReverse
    else
        m_bSortReverse = false
    end

    m_iSortMode = type
    
	Controls.MilitaryStack:SortChildren(SortFunction)
    Controls.CivilianStack:SortChildren(SortFunction)
end
Controls.SortName:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortName:RegisterCallback(Mouse.eRClick, OnSortAlternative)
Controls.SortStatus:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortExperience:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortUpgrade:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortMovement:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortName:SetVoid1(eName)
Controls.SortStatus:SetVoid1(eStatus)
Controls.SortExperience:SetVoid1(eExperience)
Controls.SortUpgrade:SetVoid1(eUpgrade)
Controls.SortMovement:SetVoid1(eMovement)
