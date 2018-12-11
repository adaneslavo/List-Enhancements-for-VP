include("IconSupport")
include("InstanceManager")

local sDefaultErrorTextureSheet = "CityBannerProductionImage.dds"
local vNullOffset = Vector2(0, 0)
local g_iPortraitSize = 45

local m_SortTable
local ePopulation = 0
local eName = 1
local eHappiness = 2
local eProduction = 3
local eDefense = 4
local eBorderGrowth = 5

local m_SortMode = ePopulation
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
	m_SortTable = {}
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
		m_SortTable[tostring(instance.Root)] = sortEntry
		
		-- update range strike button (if it is the active player's city)
		sortEntry.RangeAttack = ShouldShowRangeStrikeButton(city)
		
		if  sortEntry.RangeAttack then
			instance.CityRangeStrikeIcon:SetHide(false)
			instance.CityRangeStrikeAnim:SetHide(false)
		else
			instance.CityRangeStrikeIcon:SetHide(true)
			instance.CityRangeStrikeAnim:SetHide(true)
		end

		-- sort city defense
		sortEntry.Defense = math.floor(city:GetStrengthValue() / 100)
        instance.Defense:SetText(sortEntry.Defense)
        
		-- sort production
        sortEntry.Production = city:GetProductionNameKey()
        ProductionDetails(city, instance)
		
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
		local iCultureNeeded = city:GetUnhappinessFromCultureNeeded() / 100
		local iDefenseNeeded = city:GetUnhappinessFromDefenseNeeded() / 100
		local iGoldNeeded = city:GetUnhappinessFromGoldNeeded() / 100
		local iScienceYield = city:GetUnhappinessFromScienceYield() / 100
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

		-- Puppet tooltip
		if iPuppetUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_PUPPET_UNHAPPINESS", iPuppetUnhappiness)
		end

		-- Occupation tooltip
		if iOccupationUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_OCCUPATION_UNHAPPINESS", iOccupationUnhappiness)
		end

		-- Resistance tooltip
		if iResistanceUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_RESISTANCE_UNHAPPINESS", iResistanceUnhappiness)
		end
		
		-- Starving tooltip
		if iStarvingUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_STARVING_UNHAPPINESS", iStarvingUnhappiness)
		end
		
		-- Pillaged tooltip
		if iPillagedUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_PILLAGED_UNHAPPINESS", iPillagedUnhappiness)
		end
				
		-- Defense tooltip
		if iDefenseUnhappiness > 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_DEFENSE_UNHAPPINESS", iDefenseUnhappiness, iDefenseYield, iDefenseNeeded, iDefenseDeficit)
		end
		
		if iDefenseYield - iDefenseNeeded >= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_DEFENSE_UNHAPPINESS_SURPLUS", (iDefenseYield - iDefenseNeeded))
		end
		
		-- Gold tooltip
		if iGoldUnhappiness > 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_GOLD_UNHAPPINESS", iGoldUnhappiness, iGoldYield, iGoldNeeded, iGoldDeficit)
		end
		
		if iGoldYield - iGoldNeeded >= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_GOLD_UNHAPPINESS_SURPLUS", (iGoldYield - iGoldNeeded))
		end
		
		-- Connection tooltip
		if iConnectionUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_CONNECTION_UNHAPPINESS", iConnectionUnhappiness)
		end
		
		-- Minority tooltip
		if iMinorityUnhappiness ~= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_MINORITY_UNHAPPINESS", iMinorityUnhappiness)
		end
		
		-- Science tooltip
		if iScienceUnhappiness > 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_SCIENCE_UNHAPPINESS", iScienceUnhappiness, iScienceYield, iScienceNeeded, iScienceDeficit)
		end
		
		if  iScienceYield - iScienceNeeded >= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_SCIENCE_UNHAPPINESS_SURPLUS", (iScienceYield - iScienceNeeded))
		end
		
		-- Culture tooltip
		if iCultureUnhappiness > 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_UNHAPPINESS", iCultureUnhappiness, iCultureYield, iCultureNeeded, iCultureDeficit)
		end
		
		if iCultureYield - iCultureNeeded >= 0 then
			strOccupationTT = strOccupationTT .. "[NEWLINE]" .. Locale.ConvertTextKey("TXT_KEY_CULTURE_UNHAPPINESS_SURPLUS", (iCultureYield - iCultureNeeded))
		end
		
		instance.Happiness:SetToolTipString(strOccupationTT)
        
        -- Health Bar
        local iMaxCityHitPoints
        
		if city.GetMaxHitPoints ~= nil then
			iMaxCityHitPoints = city:GetMaxHitPoints()
        else
			iMaxCityHitPoints = GameDefines.MAX_CITY_HIT_POINTS
        end
        
        local iHealthPercent = 1 - (city:GetDamage() / iMaxCityHitPoints)
        
		if iHealthPercent < 1 then        	
            if iHealthPercent > 0.66 then
                instance.HealthBar:SetFGColor({x = 0, y = 1, z = 0.4, w = 1})
            elseif iHealthPercent > 0.33 then
                instance.HealthBar:SetFGColor({x = 1, y = 1, z = 0, w = 1})
            else
                instance.HealthBar:SetFGColor({x = 1, y = 0, z = 0, w = 1})
            end
           
        	instance.HealthBarAnchor:SetHide(false)
        	instance.HealthBar:SetPercent(iHealthPercent)
    	else
        	instance.HealthBarAnchor:SetHide(true)
    	end
		
		local iPopulation = city:GetPopulation()
		
		sortEntry.Population = iPopulation
        instance.Population:SetText(sortEntry.Population)

		-- Update Growth Meter
		if instance.GrowthBar then
			local iCurrentFood = city:GetFood()
			local iFoodNeeded = city:GrowthThreshold()
			local iFoodPerTurn = city:FoodDifference()
			local iCurrentFoodPlusThisTurn = iCurrentFood + iFoodPerTurn
			
			local fGrowthProgressPercent = iCurrentFood / iFoodNeeded
			local fGrowthProgressPlusThisTurnPercent = iCurrentFoodPlusThisTurn / iFoodNeeded
			
			if fGrowthProgressPlusThisTurnPercent > 1 then
				fGrowthProgressPlusThisTurnPercent = 1
			end
			
			instance.GrowthBar:SetPercent(fGrowthProgressPercent)
			instance.GrowthBarShadow:SetPercent(fGrowthProgressPlusThisTurnPercent)
		end
		
		-- Update Growth Time
		if instance.CityGrowth then
			local iCityGrowth = city:GetFoodTurnsLeft()
			
			if city:IsFoodProduction() or city:FoodDifferenceTimes100() == 0 then
				iCityGrowth = "-"
				instance.CityGrowth:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_STOPPED_GROWING_TT", sCityNameLong, iPopulation))
			elseif city:FoodDifferenceTimes100() < 0 then
				iCityGrowth = math.floor(city:GetFoodTimes100() / -city:FoodDifferenceTimes100()) + 1
				
				iCityGrowth = "[COLOR_WARNING_TEXT]" .. iCityGrowth .. "[ENDCOLOR]"
				instance.CityGrowth:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_STARVING_TT", sCityNameLong))
			else
				instance.CityGrowth:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_CITY_WILL_GROW_TT", sCityNameLong, iPopulation, iPopulation+1, iCityGrowth))
			end
			
			instance.CityGrowth:SetText(iCityGrowth)
		end
		
		-- Update Border Growth Meter
		local iCurrentCulture = city:GetJONSCultureStored()
		local iCultureNeeded = city:GetJONSCultureThreshold()
		local iCulturePerTurn = city:GetJONSCulturePerTurn()
			
		if instance.BorderGrowthBar then
			local iCurrentCulturePlusThisTurn = iCurrentCulture + iCulturePerTurn
			
			local fBorderGrowthProgressPercent = iCurrentCulture / iCultureNeeded
			local fBorderGrowthProgressPlusThisTurnPercent = iCurrentCulturePlusThisTurn / iCultureNeeded
			
			if fBorderGrowthProgressPlusThisTurnPercent > 1 then
				fBorderGrowthProgressPlusThisTurnPercent = 1
			end
			
			instance.BorderGrowthBar:SetPercent(fBorderGrowthProgressPercent)
			instance.BorderGrowthBarShadow:SetPercent(fBorderGrowthProgressPlusThisTurnPercent)
		end
		
		-- Update Border Growth Time
		if instance.BorderGrowth then
			if iCulturePerTurn > 0 then
				iBorderGrowth = tostring(math.floor((iCultureNeeded - iCurrentCulture) / iCulturePerTurn) + 1)
			else
				iBorderGrowth = "-"
			end
			
			sortEntry.BorderGrowth = iBorderGrowth
			instance.BorderGrowth:SetText(sortEntry.BorderGrowth)
		end
    end

    Controls.MainStack:CalculateSize()
    Controls.ScrollPanel:CalculateInternalSize()
    
    Controls.ScrollPanel:ReprocessAnchoring()
end

-- production meter
function ProductionDetails(city, instance)
	-- update production bar
	if instance.ProductionBar then
		local iCurrentProduction = city:GetProduction()
		local iProductionNeeded = city:GetProductionNeeded()
		local iProductionPerTurn = city:GetYieldRate(YieldTypes.YIELD_PRODUCTION)
		
		if city:IsFoodProduction() then
			iProductionPerTurn = iProductionPerTurn + city:GetYieldRate(YieldTypes.YIELD_FOOD) - city:FoodConsumption(true)
		end
		
		local iCurrentProductionPlusThisTurn = iCurrentProduction + iProductionPerTurn
		
		local fProductionProgressPercent = iCurrentProduction / iProductionNeeded
		local fProductionProgressPlusThisTurnPercent = iCurrentProductionPlusThisTurn / iProductionNeeded
		
		if fProductionProgressPlusThisTurnPercent > 1 then
			fProductionProgressPlusThisTurnPercent = 1
		end
		
		instance.ProductionBar:SetPercent(fProductionProgressPercent)
		instance.ProductionBarShadow:SetPercent(fProductionProgressPlusThisTurnPercent)	
	end	
	
	-- update production time
	if instance.BuildGrowth then
		local iBuildGrowth = "-"
		
		if city:IsProduction() and not city:IsProductionProcess() then
			if city:GetCurrentProductionDifferenceTimes100(false, false) > 0 then
				iBuildGrowth = city:GetProductionTurnsLeft()
			end
		end
		
		instance.BuildGrowth:SetText(iBuildGrowth)
	end

	-- update production name
	local sCityProductionName = city:GetProductionNameKey()
	
	if sCityProductionName == nil or string.len(sCityProductionName) == 0 then
		sCityProductionName = "TXT_KEY_PRODUCTION_NO_PRODUCTION"
	end
	
	instance.ProdImage:SetToolTipString(Locale.ConvertTextKey(sCityProductionName))


	-- update production icon
	if instance.ProdImage then
		local iUnitProduction = city:GetProductionUnit()
		local iBuildingProduction = city:GetProductionBuilding()
		local iProjectProduction = city:GetProductionProject()
		local iProcessProduction = city:GetProductionProcess()
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

    local entryA = m_SortTable[tostring(a)]
    local entryB = m_SortTable[tostring(b)]

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
		if m_SortMode == ePopulation then
			valueA = entryA.Population
			valueB = entryB.Population
		elseif m_SortMode == eName then
			valueA = entryA.CityName
			valueB = entryB.CityName
		elseif m_SortMode == eHappiness then
			valueA = entryA.Happiness
			valueB = entryB.Happiness
		elseif m_SortMode == eDefense then
			valueA = entryA.Defense
			valueB = entryB.Defense
		elseif m_SortMode == eBorderGrowth then
			valueA = entryA.BorderGrowth
			valueB = entryB.BorderGrowth
		else -- SortProduction
			valueA = entryA.Production
			valueB = entryB.Production
		end
	    
		if valueA == valueB then
			valueA = entryA.CityName
			valueB = entryB.CityName
		end

		if m_bSortReverse then
			return valueA < valueB
		else
			return valueA > valueB
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
    Controls.MainStack:SortChildren(SortFunction)
end
Controls.SortPopulation:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortCityName:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortHappiness:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortProduction:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortDefense:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortBorderGrowth:RegisterCallback(Mouse.eLClick, OnSort)
Controls.SortPopulation:SetVoid1(ePopulation)
Controls.SortCityName:SetVoid1(eName)
Controls.SortHappiness:SetVoid1(eHappiness)
Controls.SortProduction:SetVoid1(eProduction)
Controls.SortDefense:SetVoid1(eDefense)
Controls.SortBorderGrowth:SetVoid1(eBorderGrowth)

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