local function defaultOnTaxi(unit, crew, distance)
    if distance > 50 then
        crew:Destroy()
    end
end

DCAF.AircraftGroundAssets = {
    AirplaneGroundCrewSpawn = nil,          -- #GROUP - template used for dynamically spawning ground crew
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

local function startMonitoringTaxi()
    if DCAF.AircraftGroundAssets.MonitorTaxiScheduleID then
        return end

    local schedulerFunc
    schedulerFunc = function()
        local count = 0
        for unitName, activeGroundCrew in pairs(DCAF_ActiveGroundCrews) do
            count = count + 1
            local coordUnit = activeGroundCrew.Unit:GetCoordinate()
            if coordUnit then -- if unit was despawned, we'll get no coordinates
                -- note: VTOL takeoffs amount to "vertical" taxi, so "taxi distance" wil be either hotizontal or vertical distance...
                local taxiAltitude = math.abs(coordUnit.y - activeGroundCrew.ParkingCoordinate.y)
                local taxiDistance = math.max(taxiAltitude, activeGroundCrew.ParkingCoordinate:Get2DDistance(coordUnit))
                DCAF.AircraftGroundAssets.FuncOnTaxi(activeGroundCrew.Unit, activeGroundCrew, taxiDistance)
            end
        end
        if count == 0 then
            DCAF.stopScheduler(DCAF.AircraftGroundAssets.MonitorTaxiScheduleID)
            DCAF.AircraftGroundAssets.MonitorTaxiScheduleID = nil
        end
    end 
    DCAF.AircraftGroundAssets.MonitorTaxiScheduleID = DCAF.startScheduler(schedulerFunc, .5)
end

local function removeAirplaneGroundCrew(unit)
    local groundCrew = DCAF_ActiveGroundCrew:Get(unit)
    if groundCrew then
        groundCrew:Destroy()
    end
end

local function addAirplaneGroundCrew(unit)
    if not DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn then
        Warning("DCAF.AircraftGroundAssets :: Cannot add airplane ground crew for " .. unit.UnitName .. " :: template is not specified")
        return
    end

    local typeName = unit:GetTypeName()
    local info = DCAF_GroundCrewDB[typeName]
    if not info then
        Warning("DCAF.AircraftGroundAssets :: No ground crew information available for airplane type '" .. typeName .. "' :: IGNORES")
        return 
    end

    local groundCrew = {}
    local coordUnit = unit:GetCoordinate()
    local hdgUnit = unit:GetHeading()
    local offsetChief = (hdgUnit + info.ChiefOffset) % 360
    local locChief = coordUnit:Translate(info.ChiefDistance, offsetChief) --:Rotate2D((hdgChief + info.ChiefHeading) % 360)
    local hdgChief = (offsetChief + info.ChiefHeading) % 360
    DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn:InitHeading(hdgChief)
    local chief = DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn:SpawnFromCoordinate(locChief)
    table.insert(groundCrew, chief)

    -- todo - consider adding more ground crew

    DCAF_ActiveGroundCrew:New(unit, groundCrew)
   
-- todo - remove chief when aircraft is despawned or is 100 meters out
end

function DCAF.AircraftGroundAssets.AddAirplaneGroundCrew(groundCrew)
    if DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn then 
        Warning("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: airplane ground crew was already added")
        return 
    end

    local group = getGroup(groundCrew)
    if not group then 
        error("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: cannot resolve `groundCrew` from: " .. DumpPretty(groundCrew)) end

    local spawn = getSpawn(group.GroupName)
    if not spawn then
        error("DCAF.AircraftGroundAssets.AddAirplaneGroundCrew :: cannot resolve `groundCrew` from: " .. DumpPretty(groundCrew)) end

    DCAF.AircraftGroundAssets.AirplaneGroundCrewSpawn = spawn

    local _enteredAirplaneTimestamps = {
        -- key   = #string - player name
        -- value = #number - timestamp
    }
    MissionEvents:OnPlayerEnteredAirplane(function(event)
        local unit = event.IniUnit
        if not unit:IsParked() then
            return end

        addAirplaneGroundCrew(unit)

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
    startMonitoringTaxi()
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
DCAF_GroundCrewInfo:New("AV8BNA") --, 8.5, 150)

-- Debug("nisse - DCAF_GroundCrewDB: " .. DumpPretty(DCAF_GroundCrewDB))

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Debug("\\\\\\\\\\\\\\\\\\\\ DCAF.GroundAssets.lua was loaded ///////////////////")