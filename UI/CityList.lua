include("IconSupport")
include("InstanceManager")

local sDefaultErrorTextureSheet = "CityBannerProductionImage.dds"
local vNullOffset = Vector2(0, 0)
local g_iPortraitSize = 45

local ePopulation = 0
local ePopulationGrowth = 1
local eBorderGrowth = 2
local eDefense = 3
local eName = 4
local eHealth = 5
local eHappiness = 6
local eProductionTime = 7
local eProductionName = 8
local eResourceDemand = 9

local m_tSortTable
local m_iSortMode = ePopulation
local m_bSortReverse = false

local tPediaSearchStrings = {}


-- open window
function ShowHideHandler(bIsHide)
    if not bIsHide then
        UpdateDisplay()
    end
end
ContextPtr:SetShowHideHandler(ShowHideHandler)

-- move to economic view
function OpenEcon()
	Events.SerialEventGameMessagePopup({Type = ButtonPopupTypes.BUTTONPOPUP_ECONOMIC_OVERVIEW})
end
Controls.OpenEconButton:RegisterCallback(Mouse.eLClick, OpenEcon)

-- close window
function OnClose()
    Events.OpenInfoCorner(InfoCornerID.None)
    ContextPtr:SetHide(true)
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
    if iInfoType == InfoCornerID.Cities then
        ContextPtr:SetHide(false)
    else
        ContextPtr:SetHide(true)
    end
end
Events.OpenInfoCorner.Add(OnOpenInfoCorner)

-- on change event
function OnChangeEvent()
    if ContextPtr:IsHidden() == false then
        UpdateDisplay()
    end
end
Events.SerialEventCityInfoDirty.Add(OnChangeEvent)
Events.SerialEventCitySetDamage.Add(OnChangeEvent)
Events.SerialEventCityDestroyed.Add(OnChangeEvent)
Events.SerialEventCityCaptured.Add(OnChangeEvent)
Events.SerialEventCityCreated.Add(OnChangeEvent)
Events.SpecificCityInfoDirty.Add(OnChangeEvent)
Events.GameplaySetActivePlayer.Add(OnChangeEvent)


-- determines whether or not to show the Range Strike Button
function ShouldShowRangeStrikeButton(iCity) 
	if iCity == nil then
		return false
	end
		
	return iCity:CanRangeStrikeNow()
end

-- main function
function UpdateDisplay()
	m_tSortTable = {}
	tPediaSearchStrings = {}

    local pPlayer = Players[Game.GetActivePlayer()]
    
    Controls.MainStack:DestroyAllChildren()
    
    for city in pPlayer:Cities() do
        local instance = {}
        ContextPtr:BuildInstanceForControl("CityInstance", instance, Controls.MainStack)
        
        instance.Button:RegisterCallback(Mouse.eLClick, OnCityClick)
		instance.Button:RegisterCallback(Mouse.eRClick, OnCityRClick)
        instance.Button:SetVoids(city:GetX(), city:GetY())
        
		instance.CityRangeStrikeAnim:RegisterCallback(Mouse.eLClick, OnRangeAttackClick)
		instance.CityRangeStrikeAnim:SetVoids(city:GetX(), city:GetY())
		
        local sortEntry = {}
		m_tSortTable[tostring(instance.Root)] = sortEntry
		
		-- update range strike button (if it is the active player's city)
		if ShouldShowRangeStrikeButton(city) then
			instance.CityRangeStrikeIcon:SetHide(false)
			instance.CityRangeStrikeAnim:SetHide(false)
			instance.CityRangeStrikeIcon:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_LI_CITY_RANGE_ATTACK_TOOLTIP"))
		else
			instance.CityRangeStrikeIcon:SetHide(true)
			instance.CityRangeStrikeAnim:SetHide(true)
		end

		-- sort city defense
		sortEntry.Defense = math.floor(city:GetStrengthValue() / 100)
        instance.Defense:SetText(sortEntry.Defense)
        
		-- sort city name
		local sCityNameLong = city:GetName()
		
		sCityNameShort = string.sub(sCityNameLong, 1, 20)
		
		if city:IsCapital() then
			sCityNameShort = string.sub(sCityNameLong, 1, 15)
			sCityNameShort = "[ICON_CAPITAL] " .. sCityNameShort
		elseif city:IsPuppet() then
			sCityNameShort = string.sub(sCityNameLong, 1, 15)
			sCityNameShort = "[ICON_PUPPET] " .. sCityNameShort
		elseif city:IsOccupied() and not city:IsNoOccupiedUnhappiness() then
			sCityNameShort = string.sub(sCityNameLong, 1, 15)
			sCityNameShort = "[ICON_OCCUPIED] " .. sCityNameShort
		end
		
		sortEntry.CityName = sCityNameShort
        instance.CityName:SetText(sortEntry.CityName)
		
		-- production	
        ProductionDetails(city, instance, sortEntry)
		
		-- unhappiness value
		local iStarvingUnhappiness = city:GetUnhappinessFromStarving()
		local iPillagedUnhappiness = city:GetUnhappinessFromPillaged()
		local iGoldUnhappiness = city:GetUnhappinessFromGold()
		local iDefenseUnhappiness = city:GetUnhappinessFromDefense()
		local iConnectionUnhappiness = city:GetUnhappinessFromConnection()
		local iMinorityUnhappiness = city:GetUnhappinessFromMinority()
		local iScienceUnhappiness = city:GetUnhappinessFromScience()
		local iCultureUnhappiness = city:GetUnhappinessFromCulture()
		
		local iResistanceUnhappiness = 0
		local iOccupationUnhappiness = 0
		local iPuppetUnhappiness = 0
		
		if city:IsRazing() then
			iResistanceUnhappiness = (city:GetPopulation() / 2)
		elseif city:IsResistance() then
			iResistanceUnhappiness = (city:GetPopulation() / 2)
		elseif city:IsPuppet() then
			iPuppetUnhappiness = (city:GetPopulation() / GameDefines.BALANCE_HAPPINESS_PUPPET_THRESHOLD_MOD)
		elseif city:IsOccupied() and not city:IsNoOccupiedUnhappiness() then
			iOccupationUnhappiness = (city:GetPopulation() * GameDefines.UNHAPPINESS_PER_OCCUPIED_POPULATION)
		end
		
		local iTotalUnhappiness = iScienceUnhappiness + iCultureUnhappiness + iDefenseUnhappiness + iGoldUnhappiness + iConnectionUnhappiness + iPillagedUnhappiness + iStarvingUnhappiness + iMinorityUnhappiness + iOccupationUnhappiness + iResistanceUnhappiness + iPuppetUnhappiness
		
		sortEntry.Happiness = math.floor(iTotalUnhappiness)
        instance.Happiness:SetText(sortEntry.Happiness)

		-- unhappiness tooltip
		local iPuppetMod = pPlayer:GetPuppetUnhappinessMod()
		local iCultureYield = city:GetUnhappinessFromCultureYield() / 100
		local iDefenseYield = city:GetUnhappinessFromDefenseYield() / 100
		local iGoldYield = city:GetUnhappinessFromGoldYield() / 100
		local iScienceYield = city:GetUnhappinessFromScienceYield() / 100
		local iCultureNeeded = city:GetUnhappinessFromCultureNeeded() / 100
		local iDefenseNeeded = city:GetUnhappinessFromDefenseNeeded() / 100
		local iGoldNeeded = city:GetUnhappinessFromGoldNeeded() / 100
		local iScienceNeeded = city:GetUnhappinessFromScienceNeeded() / 100

		local iCultureDeficit = city:GetUnhappinessFromCultureDeficit() / 100
		local iDefenseDeficit = city:GetUnhappinessFromDefenseDeficit() / 100
		local iGoldDeficit = city:GetUnhappinessFromGoldDeficit() / 100
		local iScienceDeficit = city:GetUnhappinessFromScienceDeficit() / 100

		strOccupationTT = Locale.ConvertTextKey("TXT_KEY_EO_CITY_LOCAL_UNHAPPINESS", iTotalUnhappiness)

		if city:IsPuppet() then
			if iPuppetMod ~= 0 then
				strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_PUPPET_UNHAPPINESS_MOD", iPuppetMod)
			end
		end

		if iPuppetUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_PUPPET_UNHAPPINESS", iPuppetUnhappiness)
		end

		if iOccupationUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_OCCUPATION_UNHAPPINESS", iOccupationUnhappiness)
		end

		if iResistanceUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_RESISTANCE_UNHAPPINESS", iResistanceUnhappiness)
		end
		
		if iStarvingUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_STARVING_UNHAPPINESS", iStarvingUnhappiness)
		end
		
		if iPillagedUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_PILLAGED_UNHAPPINESS", iPillagedUnhappiness)
		end
				
		if iDefenseUnhappiness > 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_DEFENSE_UNHAPPINESS", iDefenseUnhappiness, iDefenseYield, iDefenseNeeded, iDefenseDeficit)
		end
		
		if iDefenseYield - iDefenseNeeded >= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_DEFENSE_UNHAPPINESS_SURPLUS", (iDefenseYield - iDefenseNeeded))
		end
		
		if iGoldUnhappiness > 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_GOLD_UNHAPPINESS", iGoldUnhappiness, iGoldYield, iGoldNeeded, iGoldDeficit)
		end
		
		if iGoldYield - iGoldNeeded >= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_GOLD_UNHAPPINESS_SURPLUS", (iGoldYield - iGoldNeeded))
		end
		
		if iConnectionUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_CONNECTION_UNHAPPINESS", iConnectionUnhappiness)
		end
		
		if iMinorityUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_MINORITY_UNHAPPINESS", iMinorityUnhappiness)
		end
		
		if iScienceUnhappiness > 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_SCIENCE_UNHAPPINESS", iScienceUnhappiness, iScienceYield, iScienceNeeded, iScienceDeficit)
		end
		
		if  iScienceYield - iScienceNeeded >= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_SCIENCE_UNHAPPINESS_SURPLUS", (iScienceYield - iScienceNeeded))
		end
		
		if iCultureUnhappiness > 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_UNHAPPINESS", iCultureUnhappiness, iCultureYield, iCultureNeeded, iCultureDeficit)
		end
		
		if iCultureYield - iCultureNeeded >= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_UNHAPPINESS_SURPLUS", (iCultureYield - iCultureNeeded))
		end
		
		instance.Happiness:SetToolTipString(strOccupationTT)
        
		-- city connection
		if pPlayer:IsCapitalConnectedToCity(city) then
			instance.CityConnectionIcon:SetHide(false)
			instance.CityConnectionIcon:SetAlpha(0.5);
		else
			instance.CityConnectionIcon:SetHide(true)
		end
		
        -- city health
        local iMaxCityHitPoints
        local iCityDamage = city:GetDamage()
		
		if city.GetMaxHitPoints ~= nil then
			iMaxCityHitPoints = city:GetMaxHitPoints()
        else
			iMaxCityHitPoints = GameDefines.MAX_CITY_HIT_POINTS
        end
        
        local iHealthPercent = 1 - (iCityDamage / iMaxCityHitPoints)
       	sortEntry.Health = iHealthPercent
		
		local sHealthColour = "[COLOR:0:255:100:255]"
		
		if iHealthPercent < 1 then        	
            if iHealthPercent > 0.66 then
                instance.HealthBar:SetFGColor({x = 0, y = 1, z = 0.3, w = 1})
            elseif iHealthPercent > 0.33 then
                instance.HealthBar:SetFGColor({x = 1, y = 1, z = 0, w = 1})
				sHealthColour = "[COLOR:0:255:255:0]"
            else
                instance.HealthBar:SetFGColor({x = 1, y = 0, z = 0, w = 1})
				sHealthColour = "[COLOR:0:0:255:255]"
            end
           
        	instance.HealthBarAnchor:SetHide(false)
        	instance.HealthBar:SetPercent(iHealthPercent)
		else
        	instance.HealthBarAnchor:SetHide(true)
    	end
			
			-- city income
			local iFoodIncome = city:FoodDifferenceTimes100(false) / 100
			local iProductionIncome = city:GetCurrentProductionDifferenceTimes100(false, false) / 100
			local iGoldIncome = city:GetYieldRateTimes100(YieldTypes.YIELD_GOLD) / 100
			local iScienceIncome = city:GetYieldRateTimes100(YieldTypes.YIELD_SCIENCE) / 100
			local iCultureIncome = city:GetYieldRateTimes100(YieldTypes.YIELD_CULTURE) / 100
			local iFaithIncome = city:GetYieldRateTimes100(YieldTypes.YIELD_FAITH) / 100
		
		local sCityNameTooltip = iFoodIncome .. "[ICON_FOOD][NEWLINE]" .. iProductionIncome .. "[ICON_PRODUCTION][NEWLINE]" .. iGoldIncome .. "[ICON_GOLD][NEWLINE]" .. iScienceIncome .. "[ICON_RESEARCH][NEWLINE]" .. iCultureIncome .. "[ICON_CULTURE][NEWLINE]" .. iFaithIncome .. "[ICON_PEACE][NEWLINE][NEWLINE]"
		sCityNameTooltip = sCityNameTooltip .. sHealthColour .. (iMaxCityHitPoints - iCityDamage) .. "/" .. iMaxCityHitPoints .. " (" .. math.floor(iHealthPercent * 100) .. "%)[ENDCOLOR]"
		sCityNameTooltip = sCityNameTooltip .. Locale.ConvertTextKey("TXT_KEY_LI_CITY_NAME_TOOLTIP")
		
		instance.CityName:SetToolTipString(sCityNameTooltip)
		
		-- resource demand
		local sResourceNeeded = city:GetResourceDemanded(true)
		local condition = "ID = '" .. sResourceNeeded .. "'"
		local sResourceNeededName = "zzz"
		local sResourceNeededIcon = ""
		local iWLTKDCounter = city:GetWeLoveTheKingDayCounter()
		
		for resource in GameInfo.Resources(condition) do
			if resource.ID ~= -1  and iWLTKDCounter == 0 then
				sResourceNeededIcon = resource.IconString
				sResourceNeededName = Locale.ConvertTextKey(resource.Description)
			elseif resource.ID ~= -1  and iWLTKDCounter > 0 then
				sResourceNeededIcon = iWLTKDCounter
				sResourceNeededName = ""
			end
		end
		
		instance.ResourceDemand:SetText(sResourceNeededIcon)
		instance.ResourceDemand:SetToolTipString(sResourceNeededName)
		sortEntry.ResourceDemand = sResourceNeededName
        
		-- WLTKD
		if iWLTKDCounter > 0 then
			instance.WLTKDIcon:SetHide(false)
			instance.WLTKDIcon:SetAlpha(0.5);
		else
			instance.WLTKDIcon:SetHide(true)
		end
		
       -- population
		local iPopulation = city:GetPopulation()
		
		sortEntry.Population = iPopulation
        instance.Population:SetText(sortEntry.Population)
		
		-- update growth meter
		local iFoodStored100 = city:GetFoodTimes100()
		local iFoodNeeded = city:GrowthThreshold()
		local iFoodPerTurn100 = city:FoodDifferenceTimes100(false)
		local iCurrentFoodPlusThisTurn = (iFoodStored100 + iFoodPerTurn100) / 100
		local iFoodTurnsLeft = city:GetFoodTurnsLeft()
		
		if instance.GrowthBar then
			local fGrowthProgressPercent = (iFoodStored100 / 100) / iFoodNeeded
			local fGrowthProgressPlusThisTurnPercent = iCurrentFoodPlusThisTurn / iFoodNeeded
			
			if fGrowthProgressPlusThisTurnPercent > 1 then
				fGrowthProgressPlusThisTurnPercent = 1
			end
			
			instance.GrowthBar:SetPercent(fGrowthProgressPercent)
			instance.GrowthBarShadow:SetPercent(fGrowthProgressPlusThisTurnPercent)
		end
		
		-- update growth time
		if instance.CityGrowth then
			local iCityGrowth, sCityGrowth
			
			if city:IsFoodProduction() or city:FoodDifferenceTimes100() == 0 then
				iCityGrowth = 10000
				sCityGrowth = "-"
			elseif city:FoodDifferenceTimes100() < 0 then
				iCityGrowth = math.floor(city:GetFoodTimes100() / -city:FoodDifferenceTimes100()) + 1
				sCityGrowth = "[COLOR_WARNING_TEXT]" .. iCityGrowth .. "[ENDCOLOR]"
			else
				iCityGrowth = city:GetFoodTurnsLeft()
				sCityGrowth = iCityGrowth
			end
			
			instance.CityGrowth:SetText(sCityGrowth)
			sortEntry.PopulationGrowth = iCityGrowth
		end
		
		-- food tooltip
		local sFoodTooltip = iFoodPerTurn100 / 100 .. "[ICON_FOOD] Total[NEWLINE][NEWLINE]"
		sFoodTooltip = sFoodTooltip .. "Progress towards [COLOR_POSITIVE_TEXT]" .. iPopulation + 1 .. "[ICON_CITIZEN][ENDCOLOR]"
		sFoodTooltip = sFoodTooltip .. "  " .. iFoodStored100 / 100 .. "[ICON_FOOD]/ " .. iFoodNeeded .. "[ICON_FOOD]"
		
		if iFoodPerTurn100 > 0 then
			sFoodTooltip = sFoodTooltip .. "[NEWLINE]"

			local iFoodOverflow100 = iFoodPerTurn100 * iFoodTurnsLeft + iFoodStored100 - iFoodNeeded * 100
			
			if iFoodTurnsLeft > 1 then
				sFoodTooltip = sFoodTooltip .. Locale.ConvertTextKey("TXT_KEY_STR_TURNS", iFoodTurnsLeft - 1)
					.. string.format(" %+g[ICON_FOOD]  ", (iFoodOverflow100 - iFoodPerTurn100) / 100)
			end
			
			sFoodTooltip = sFoodTooltip .. "[COLOR_POSITIVE_TEXT]" .. Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_STR_TURNS", iFoodTurnsLeft )) .. "[ENDCOLOR]"
					.. string.format(" %+g[ICON_FOOD]", iFoodOverflow100 / 100)
		end
		
		instance.GrowthBar:SetToolTipString(sFoodTooltip)
		instance.CityGrowth:SetToolTipString(sFoodTooltip)
		instance.Population:SetToolTipString(sFoodTooltip)
		
		-- update border growth meter
		local iCultureStored = city:GetJONSCultureStored()
		local iCultureNeeded = city:GetJONSCultureThreshold()
		local iCulturePerTurn = city:GetJONSCulturePerTurn()
		local iBorderGrowth
		
		if instance.BorderGrowthBar then
			local iCurrentCulturePlusThisTurn = iCultureStored + iCulturePerTurn
			
			local fBorderGrowthProgressPercent = iCultureStored / iCultureNeeded
			local fBorderGrowthProgressPlusThisTurnPercent = iCurrentCulturePlusThisTurn / iCultureNeeded
			
			if fBorderGrowthProgressPlusThisTurnPercent > 1 then
				fBorderGrowthProgressPlusThisTurnPercent = 1
			end
			
			instance.BorderGrowthBar:SetPercent(fBorderGrowthProgressPercent)
			instance.BorderGrowthBarShadow:SetPercent(fBorderGrowthProgressPlusThisTurnPercent)
		end
		
		-- update border growth time
		if instance.BorderGrowth then
			if iCulturePerTurn > 0 then
				iBorderGrowth = math.floor((iCultureNeeded - iCultureStored) / iCulturePerTurn)
			else
				iBorderGrowth = "-"
			end
			
			instance.BorderGrowth:SetText(iBorderGrowth)
			
			if iBorderGrowth == "-" then
				sortEntry.BorderGrowth = 10000
			else
				sortEntry.BorderGrowth = iBorderGrowth
			end
		end
		
		-- culture tooltip
		local sCultureTooltip = iCulturePerTurn .. "[ICON_CULTURE] Total[NEWLINE][NEWLINE]"
		sCultureTooltip = sCultureTooltip .. "Progress towards next [ICON_CULTURE_LOCAL] Border Growth[ENDCOLOR]"
		sCultureTooltip = sCultureTooltip .. "  " .. iCultureStored .. "[ICON_CULTURE]/ " .. iCultureNeeded .. "[ICON_CULTURE]"
		
		if iCulturePerTurn > 0 then
			sCultureTooltip = sCultureTooltip .. "[NEWLINE]"

			local iCultureOverflow = iCulturePerTurn * iBorderGrowth + iCultureStored - iCultureNeeded
			
			if iBorderGrowth > 1 then
				sCultureTooltip = sCultureTooltip .. Locale.ConvertTextKey("TXT_KEY_STR_TURNS", iBorderGrowth - 1)
					.. string.format(" %+g[ICON_CULTURE]  ", iCultureOverflow - iCulturePerTurn)
			end
			
			sCultureTooltip = sCultureTooltip .. "[COLOR_MAGENTA]" .. Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_STR_TURNS", iBorderGrowth)) .. "[ENDCOLOR]"
					.. string.format(" %+g[ICON_CULTURE]", iCultureOverflow)
		end
		
		instance.BorderGrowthBar:SetToolTipString(sCultureTooltip)
		instance.BorderGrowth:SetToolTipString(sCultureTooltip)
    end

    Controls.MainStack:CalculateSize()
    Controls.ScrollPanel:CalculateInternalSize()
    
    Controls.ScrollPanel:ReprocessAnchoring()
end

-- production meter
function ProductionDetails(city, instance, sortEntry)
	-- update production time
	if instance.BuildGrowth then
		local iBuildGrowth = "-"
		
		if city:IsProduction() and not city:IsProductionProcess() then
			if city:GetCurrentProductionDifferenceTimes100(false, false) > 0 then
				iBuildGrowth = city:GetProductionTurnsLeft()
			end
		end
		
		instance.BuildGrowth:SetText(iBuildGrowth)
		
		-- sort production time
        if iBuildGrowth == "-" then
			sortEntry.ProductionTime = 10000
		else
			sortEntry.ProductionTime = iBuildGrowth
		end
	end
	
	-- update production icon
	local iUnitProduction = city:GetProductionUnit()
	local iBuildingProduction = city:GetProductionBuilding()
	local iProjectProduction = city:GetProductionProject()
	local iProcessProduction = city:GetProductionProcess()
		
	if instance.ProdImage then
		local bNoProduction = false

		if iUnitProduction ~= -1 then
			local portraitOffset, portraitAtlas = UI.GetUnitPortraitIcon(iUnitProduction, city:GetOwner())
			
			if IconHookup(portraitOffset, g_iPortraitSize, portraitAtlas, instance.ProdImage) then
				instance.ProdImage:SetHide(false)
			else
				instance.ProdImage:SetHide(true)
			end
		elseif iBuildingProduction ~= -1 then
			local thisBuildingInfo = GameInfo.Buildings[iBuildingProduction]
			
			if IconHookup(thisBuildingInfo.PortraitIndex, g_iPortraitSize, thisBuildingInfo.IconAtlas, instance.ProdImage) then
				instance.ProdImage:SetHide(false)
			else
				instance.ProdImage:SetHide(true)
			end
		elseif iProjectProduction ~= -1 then
			local thisProjectInfo = GameInfo.Projects[iProjectProduction]
			
			if IconHookup(thisProjectInfo.PortraitIndex, g_iPortraitSize, thisProjectInfo.IconAtlas, instance.ProdImage) then
				instance.ProdImage:SetHide(false)
			else
				instance.ProdImage:SetHide(true)
			end
		elseif iProcessProduction ~= -1 then
			local thisProcessInfo = GameInfo.Processes[iProcessProduction]
			
			if IconHookup(thisProcessInfo.PortraitIndex, g_iPortraitSize, thisProcessInfo.IconAtlas, instance.ProdImage) then
				instance.ProdImage:SetHide(false)
			else
				instance.ProdImage:SetHide(true)
			end
		else -- really should have an error texture
			instance.ProdImage:SetHide(true)
		end
	end
	
	-- sort production name
	local sCityProductionName = city:GetProductionNameKey()
	sortEntry.ProductionName = sCityProductionName

	-- production tooltip
	local iProductionPerTurn100 = city:GetCurrentProductionDifferenceTimes100(false, false)
	local iProductionStored100 = city:GetProductionTimes100() + city:GetCurrentProductionDifferenceTimes100(false, true) - iProductionPerTurn100
	local iProductionTurnsLeft = city:GetProductionTurnsLeft()
	local iProductionNeeded = city:GetProductionNeeded()
	
	local sProductionTooltip = iProductionPerTurn100 / 100 .. "[ICON_PRODUCTION] Total[NEWLINE][NEWLINE]"
	sProductionTooltip = sProductionTooltip .. "Progress towards [COLOR_YIELD_FOOD]" .. Locale.ToUpper(sCityProductionName) .. "[ENDCOLOR]"
	sProductionTooltip = sProductionTooltip .. "  " .. iProductionStored100 / 100 .. "[ICON_PRODUCTION]/ " .. iProductionNeeded .. "[ICON_PRODUCTION]"
	
	if iProductionPerTurn100 > 0 then
		sProductionTooltip = sProductionTooltip .. "[NEWLINE]"

		local iProductionOverflow100 = iProductionPerTurn100 * iProductionTurnsLeft + iProductionStored100 - iProductionNeeded * 100
		
		if iProductionTurnsLeft > 1 then
			sProductionTooltip = sProductionTooltip .. Locale.ConvertTextKey("TXT_KEY_STR_TURNS", iProductionTurnsLeft - 1)
				.. string.format(" %+g[ICON_PRODUCTION]  ", (iProductionOverflow100 - iProductionPerTurn100) / 100)
		end
		
		sProductionTooltip = sProductionTooltip .. "[COLOR_YIELD_FOOD]" .. Locale.ToUpper(Locale.ConvertTextKey("TXT_KEY_STR_TURNS", iProductionTurnsLeft )) .. "[ENDCOLOR]"
				.. string.format(" %+g[ICON_PRODUCTION]", iProductionOverflow100 / 100)
	end
	
	instance.ProdImage:SetToolTipString(Locale.ConvertTextKey(sProductionTooltip))
	instance.ProductionBar:SetToolTipString(Locale.ConvertTextKey(sProductionTooltip))
	
	-- update production bar
	if instance.ProductionBar then
		local iProductionPerTurn = iProductionPerTurn100 / 100
		
		if city:IsFoodProduction() then
			iProductionPerTurn = iProductionPerTurn + city:GetYieldRate(YieldTypes.YIELD_FOOD) - city:FoodConsumption(true)
		end
		
		local iCurrentProductionPlusThisTurn = iProductionStored100 / 100 + iProductionPerTurn
		
		local fProductionProgressPercent = (iProductionStored100 / 100) / iProductionNeeded
		local fProductionProgressPlusThisTurnPercent = iCurrentProductionPlusThisTurn / iProductionNeeded
		
		if fProductionProgressPlusThisTurnPercent > 1 then
			fProductionProgressPlusThisTurnPercent = 1
		end
		
		instance.ProductionBar:SetPercent(fProductionProgressPercent)
		instance.ProductionBarShadow:SetPercent(fProductionProgressPlusThisTurnPercent)	
	end	
	
	-- hookup pedia and production popup to production button
	if not city:IsPuppet() then
		instance.ProdButton:RegisterCallback(Mouse.eLClick, OnProdClick)
	end
	
	tPediaSearchStrings[tostring(instance.ProdButton)] = Locale.ConvertTextKey(sCityProductionName)
	
	instance.ProdButton:RegisterCallback(Mouse.eRClick, OnProdRClick)
	instance.ProdButton:SetVoids(city:GetID(), nil)
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
		elseif  entryA == nil and entryB then
			return true
		else
			if m_bSortReverse then
				return tostring(a) > tostring(b) -- gotta do something deterministic
			else
				return tostring(a) < tostring(b) -- gotta do something deterministic
			end
        end
    else
		if m_iSortMode == ePopulation then
			valueA = entryA.Population
			valueB = entryB.Population
		elseif m_iSortMode == ePopulationGrowth then
			valueA = entryA.PopulationGrowth
			valueB = entryB.PopulationGrowth
			bReversedOrder = true
		elseif m_iSortMode == eBorderGrowth then
			valueA = entryA.BorderGrowth
			valueB = entryB.BorderGrowth
			bReversedOrder = true
		elseif m_iSortMode == eDefense then
			valueA = entryA.Defense
			valueB = entryB.Defense
		elseif m_iSortMode == eName then
			valueA = entryA.CityName
			valueB = entryB.CityName
		elseif m_iSortMode == eHealth then
			valueA = entryA.Health
			valueB = entryB.Health
			bReversedOrder = true
		elseif m_iSortMode == eHappiness then
			valueA = entryA.Happiness
			valueB = entryB.Happiness
		elseif m_iSortMode == eProductionTime then
			valueA = entryA.ProductionTime
			valueB = entryB.ProductionTime
			bReversedOrder = true
		elseif m_iSortMode == eProductionName then
			valueA = entryA.ProductionName
			valueB = entryB.ProductionName
			bReversedOrder = true
		elseif m_iSortMode == eResourceDemand then
			valueA = entryA.ResourceDemand
			valueB = entryB.ResourceDemand
			bReversedOrder = true
		end
	    
		if valueA == valueB then
			valueA = entryA.CityName
			valueB = entryB.CityName
		end

		if bReversedOrder then
			if m_bSortReverse then
				return valueA > valueB
			else
				return valueA < valueB
			end
		else
			if m_bSortReverse then
				return valueA < valueB
			else
				return valueA > valueB
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
    Controls.MainStack:SortChildren(SortFunction)
end

function OnSortAlternative(type)
    if type == ePopulation then
		type = ePopulationGrowth
	elseif type == eName then
		type = eHealth
	elseif type == eProductionTime then
		type = eProductionName
	end
	
	if m_iSortMode == type then
        m_bSortReverse = not m_bSortReverse
    else
        m_bSortReverse = false
    end

    m_iSortMode = type
    Controls.MainStack:SortChildren(SortFunction)
end
Controls.SortPopulation:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortPopulation:RegisterCallback(Mouse.eRClick, OnSortAlternative)
Controls.SortBorderGrowth:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortDefense:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortCityName:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortCityName:RegisterCallback(Mouse.eRClick, OnSortAlternative)
Controls.SortHappiness:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortProduction:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortProduction:RegisterCallback(Mouse.eRClick, OnSortAlternative)
Controls.SortResourceDemand:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortPopulation:SetVoid1(ePopulation)
Controls.SortBorderGrowth:SetVoid1(eBorderGrowth)
Controls.SortDefense:SetVoid1(eDefense)
Controls.SortCityName:SetVoid1(eName)
Controls.SortHappiness:SetVoid1(eHappiness)
Controls.SortProduction:SetVoid1(eProductionTime)
Controls.SortResourceDemand:SetVoid1(eResourceDemand)

-------------
-- actions --
-------------
-- enter the city
function OnCityClick(x, y)
    local plot = Map.GetPlot(x, y)
    
	if(plot ~= nil) then
    	UI.DoSelectCityAtPlot(plot)
	end
end

-- center on city from attack icon
function OnRangeAttackClick(x, y)
    local plot = Map.GetPlot(x, y)
    
	if plot ~= nil then
    	UI.LookAt(plot)
	end
end

-- center on city from city name
function OnCityRClick(x, y)
    local plot = Map.GetPlot(x, y)
    
	if plot ~= nil then
    	UI.LookAt(plot)
	end
end

-- enter production view
function OnProdClick(cityID, prodName)
	local popupInfo = {
			Type = ButtonPopupTypes.BUTTONPOPUP_CHOOSEPRODUCTION,
			Data1 = cityID,
			Data2 = -1,
			Data3 = -1,
			Option1 = false,
			Option2 = false
		}
	Events.SerialEventGameMessagePopup(popupInfo)
end

-- check item in civilopedia
function OnProdRClick(cityID, void2, button)
	local searchString = tPediaSearchStrings[tostring(button)]
	Events.SearchForPediaEntry(searchString)		
end