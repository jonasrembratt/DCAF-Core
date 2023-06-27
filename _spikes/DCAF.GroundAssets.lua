local function defaultOnTaxi(unit, crew, distance)
    if distance > 50 then
        crew:Destroy()
    end
end

DCAF.AircraftGroundAssets = {
    ClassName = "DCAF.AircraftGroundAssets",
    AirplaneGroundCrewSpawn = {
        -- list of #SPAWN - templates used for dynamically spawning ground crew
    },         
    MonitorTaxiScheduleID = nil,            -- #number - set when a scheduler is running, to remove gound crew
    FuncOnTaxi = defaultOnTaxi
}

local DCAF_GroundCrewInfo = {
    ChiefDistance = 7,
    ChiefHeading = 145,                     -- #number - subtracted from UNIT's heading (typically the chief is reciprocal heading [180])
    ChiefOffset = 310,                      -- #number - subtracted from UNIT's heading (typically the chief is 12 oc from UNIT [0])
}

local DCAF_GroundCrewDB = {
    -- key   = #string - model type name (from UNIT:GetTypeName())
    -- value = #DCAF_GroundCrewInfo
}

local DCAF_ActiveGroundCrew = {
    ClassName = "DCAF_ActiveGroundCrew",
    Unit = nil,                             -- #GROUP - spawned unit (aircraft)
    ParkingCoordinate = nil,                -- #COORDINATE - Unit's original location
    CroundCrew = {
        -- list of #GROUP
    }
}

local DCAF_ActiveGroundCrews = {
    -- key   = UNIT name
    -- value = #DCAF_ActiveGroundCrew
}
local DCAF_CountActiveGroundCrews = 0

local function stopMonitoringTaxiWhenLastGroundCrewRemoved()
    Debug(DCAF.AircraftGroundAssets.ClassName .. " :: stops monitoring airplane taxi")
    DCAF.stopScheduler(DCAF.AircraftGroundAssets.MonitorTaxiScheduleID)
    DCAF.AircraftGroundAssets.MonitorTaxiScheduleID = nil
end

local function removeAirplaneGroundCrew(unit)
    local groundCrew = DCAF_ActiveGroundCrew:Get(unit)
    if groundCrew then
        groundCrew:Destroy()
    end
end

local function startMonitoringTaxi()
    if DCAF.AircraftGroundAssets.MonitorTaxiScheduleID then
        return end

    Debug(DCAF.AircraftGroundAssets.ClassName .. " :: starts monitoring airplane taxi")
    local schedulerFunc
    schedulerFunc = function()
        local count = 0
        for unitName, activeGroundCrew in pairs(DCAF_ActiveGroundCrews) do
            count = count + 1
            local coordUnit = activeGroundCrew.Unit:GetCoordinate()
            if coordUnit then -- if unit was despawned, we'll get no coordinates
                -- note: VTOL takeoffs amount to "vertical" taxi, so "taxi distance" will be either hotizontal or vertical distance...
                local taxiAltitude = math.abs(coordUnit.y - activeGroundCrew.ParkingCoordinate.y)
                local taxiDistance = math.max(taxiAltitude, activeGroundCrew.ParkingCoordinate:Get2DDistance(coordUnit))
                DCAF.AircraftGroundAssets.FuncOnTaxi(activeGroundCrew.Unit, activeGroundCrew, taxiDistance)
            else
                removeAirplaneGroundCrew(activeGroundCrew.Unit)
            end
        end
        -- stopMonitoringTaxiWhenLastGroundCrewRemoved()
    end 
    DCAF.AircraftGroundAssets.MonitorTaxiScheduleID = DCAF.startScheduler(schedulerFunc, .5)
end

local function addAirplaneGroundCrew(unit)
    if not DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn or #DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn == 0 then
        Warning(DCAF.AircraftGroundAssets.ClassName .. " :: Cannot add airplane ground crew for " .. unit.UnitName .. " :: template is not specified")
        return
    end

    local typeName = unit:GetTypeName()
    local info = DCAF_GroundCrewDB[typeName]
    if not info then
        Warning(DCAF.AircraftGroundAssets.ClassName .. " :: No ground crew information available for airplane type '" .. typeName .. "' :: IGNORES")
        return 
    end

    local groundCrew = {}
    local coordUnit = unit:GetCoordinate()
    local hdgUnit = unit:GetHeading()
    local offsetCrew = (hdgUnit + info.ChiefOffset) % 360
Debug("nisse - addAirplaneGroundCrew :: unit hdg: " .. Dump(hdgUnit) .. " :: offsetCrew: " .. Dump(offsetCrew))    
    local locCrew = coordUnit:Translate(info.ChiefDistance, offsetCrew) --:Rotate2D((hdgChief + info.ChiefHeading) % 360)
    local hdgCrew = (offsetCrew + info.ChiefHeading) % 360
    local spawn = listRandomItem(DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn)
    spawn:InitHeading(hdgCrew)
    local crew = spawn:SpawnFromCoordinate(locCrew)
    Debug(DCAF.AircraftGroundAssets.ClassName .. " :: spawns airplane ground crew: " .. crew.GroupName)
    table.insert(groundCrew, crew)

    -- todo - consider adding more ground crew

    DCAF_ActiveGroundCrew:New(unit, groundCrew)
   
-- todo - remove chief when aircraft is despawned or is 100 meters out
end

function DCAF.AircraftGroundAssets.AddAirplaneGroundCrew(...)

    local function addGroundCrew(groundCrew)
        local group = getGroup(groundCrew)
        if not group then 
            error("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: cannot resolve `ground crew` from: " .. DumpPretty(groundCrew)) end

        local spawn = getSpawn(group.GroupName)
        if not spawn then
            error("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: cannot resolve `ground crew` from: " .. DumpPretty(groundCrew)) end

        Debug("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: adds airplane ground crew: " .. group.GroupName)
        table.insert(DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn, spawn)
    end

    for i = 1, #arg, 1 do
        addGroundCrew(arg[i])
    end

    local _enteredAirplaneTimestamps = {
        -- key   = #string - player name
        -- value = #number - timestamp
    }
    MissionEvents:OnPlayerEnteredAirplane(function(event)
Debug("nisse - " .. DCAF.AircraftGroundAssets.ClassName .. "_OnPlayerEnteredAirplane :: player enters airplane: " .. Dump(event.IniUnit:GetPlayerName()))
        local unit = event.IniUnit
        if not unit:IsParked() then
            Debug(DCAF.AircraftGroundAssets.ClassName .. " :: player entered non-parked airplane :: EXITS")
            return 
        end

        Delay(1.5, function() 
Debug("nisse - " .. DCAF.AircraftGroundAssets.ClassName .. "_OnPlayerEnteredAirplane :: delayed :: adds ground crew...")
            addAirplaneGroundCrew(unit)
            startMonitoringTaxi()

            local leftAirplaneFunc
            local function onPlayerLeftAirplane(event)
                if unit.UnitName == event.IniUnitName then
                    removeAirplaneGroundCrew(unit)
                    MissionEvents:EndOnPlayerLeftAirplane(leftAirplaneFunc)
                end
            end
            leftAirplaneFunc = onPlayerLeftAirplane
            MissionEvents:OnPlayerLeftAirplane(leftAirplaneFunc)
        end)
    end)

    return DCAF.AircraftGroundAssets
end

function DCAF.AircraftGroundAssets.OnTaxi(func) -- function(unit, crew, distance) 
    if not isFunction(func) then
        error("DCAF.AircraftGroundAssets.OnTaxi :: `func` must be a function, but was: " .. type(func)) end

    DCAF.AircraftGroundAssets.FuncOnTaxi = func
    return DCAF.AircraftGroundAssets
end

function DCAF_GroundCrewInfo:New(model, chiefDistance, chiefHeading, chiefOffset)
    local info = DCAF.clone(DCAF_GroundCrewInfo)
    info.ChiefDistance = chiefDistance or DCAF_GroundCrewInfo.ChiefDistance
    info.ChiefHeading = chiefHeading or DCAF_GroundCrewInfo.ChiefHeading
    info.ChiefOffset = chiefOffset or DCAF_GroundCrewInfo.ChiefOffset
    DCAF_GroundCrewDB[model] = info
    return info
end

function DCAF_ActiveGroundCrew:New(unit, groundCrew)
    local info = DCAF.clone(DCAF_ActiveGroundCrew)
    info.Unit = unit
    info.ParkingCoordinate = unit:GetCoordinate()
    info.GroundCrew = groundCrew
    DCAF_ActiveGroundCrews[unit.UnitName] = info
    return info
end

function DCAF_ActiveGroundCrew:Get(unit)
    return DCAF_ActiveGroundCrews[unit.UnitName]
end

function DCAF_ActiveGroundCrew:Destroy()
    DCAF_ActiveGroundCrews[self.Unit.UnitName] = nil
    for _, group in ipairs(self.GroundCrew) do
        group:Destroy()
    end
    stopMonitoringTaxiWhenLastGroundCrewRemoved()
    return self
end

function DCAF_ActiveGroundCrew:Salute()
    for _, group in ipairs(self.GroundCrew) do
        group:OptionAlarmStateRed()
    end
end

function DCAF_ActiveGroundCrew:Restore()
    for _, group in ipairs(self.GroundCrew) do
        group:OptionAlarmStateGreen()
    end
end

-- DATABASE

DCAF_GroundCrewInfo:New("F-16C_50")
DCAF_GroundCrewInfo:New("FA-18C_hornet", 8.5, 150)
DCAF_GroundCrewInfo:New("AV8BNA")
DCAF_GroundCrewInfo:New("F-14A-135-GR", 10, 115, 330)
DCAF_GroundCrewInfo:New("F-14B", 10, 115, 330)
DCAF_GroundCrewInfo:New("F-15ESE", 11, 120, 320)

-- Debug("nisse - DCAF_GroundCrewDB: " .. DumpPretty(DCAF_GroundCrewDB))

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Debug("\\\\\\\\\\\\\\\\\\\\ DCAF.GroundAssets.lua was loaded ///////////////////")