DCAF.Weather = {
    Factor = 1,
}

DCAF.Precipitation = {
    None = "None",
    Light = "Light",
    Medium = "Heavy"
}

local CSAR_State = {
    Initializing = "Initializing",      -- Group has not yet been activated
    Stopped = "Stopped",                -- Group is stopped (eg. distressed group is hiding or waiting to be rescued)
    Moving = "Moving",                  -- Group is moving
    Attracting = "Attracting",          -- Pursued group is attracting attention
    Captured = "Captured",              -- Pursued group was captured (by CarrierUnit)
    RTB = "RTB",                        -- Group is RTB (eg. distressed group was rescued but is not yet safely returned)
    Rescued = "Rescued"                 -- Pursued group was successfully rescued 
}

local CSAR_DistressedGroupTemplates = {
    GroundTemplate = getSpawn("Downed Pilot-Ground"),
    WaterTemplate = getSpawn("Downed Pilot-Water")
}

local CSAR_Type = {
    Land = "Land",                      -- distressed group is on the ground (possibly moving)
    Water = "Water"                     -- distressed group is in a life raft, in the water
}

local CSAR_DefaultCodewords = { "Cinderella", "Pocahontas", "Ariel", "Anastasia", "Leia", "Astrid", "Fiona" }

DCAF.CSAR = {
    ClassName = "DCAF.CSAR",
    Name = nil,
    DistressedGroup = nil,              -- #DCAF.CSAR.DistressedGroup
    CaptureGroups = {},                  -- list of #DCAF.CSAR.CaptureGroup
    RescueGroups = {},                  -- list of #DCAF.CSAR.RescueGroup
    Type = CSAR_Type.Land,              -- #string - (#CSAR_Type)
    RescueMissionTemplates = {},        -- list of #DCAF.CSAR.Mission
    CaptureMissionTemplates = {},       -- list of #DCAF.CSAR.Mission
    -- Weather = DCAF.Weather:Static()
}

DCAF.CSAR.DistressedGroup = {
    ClassName = "DCAF.CSAR.DistressedGroup",
    Name = nil,         -- #string
    Template = nil,     -- #string - group template name
    Group = nil,        -- #GROUP in distress, to be rescued
    CarrierUnit = nil,  -- #UNIT set when group is picked up by a UNIT
    State = CSAR_State.Initializing,
    CanBeCatured = true,
    BeaconTenplate = nil,                  -- #string - name of GROUP used as beacon
    BeaconGroup = nil,                     -- #GROUP - assigned when beacon is active (otherwise nil)
    BeaconTimeActive = VariableValue:New(90, .3),            -- #number/#VariableValue - time (seconds) to keep beacon active, then shut it down
    BeaconTimeInactive = VariableValue:New(Minutes(5), .3),  -- #number/#VariableValue - time (seconds) to keep beacon silent between active periods
    RangeBeacon = nil,                     -- if Group detects friendly units inside of this range it will activate its TACAN (if available); nil = activates regardless of range
    RangeSmoke = NauticalMiles(8),         -- if Group detects friendly units inside of this range it will pop smoke (if available)
    RangeEnemies = NauticalMiles(10),      -- if Group detects unfriendlies inside this range it will abstain from attracting attention, regardless of nearby friendlies
    AttractAttentionTime = Minutes(30),    -- #number - distressed group will try and attract attention for this amount of time; then go back to waiting/looking again 
    Coalition = nil,                       -- #Coalition - (string, small letters; "red", "blue", "neutral") 
    SizeDetectionFactor = 1,               -- #number - small targets (single person, like a pilot should be lower; larger should be greater)
    Smoke = nil                            -- #DCAF.Smoke
}

DCAF.CSAR.Mission = {
    ClassName = "DCAF.CSAR.Mission",
    Name = nil,
    MissionGroups = {},     -- list of #DCAF.CSAR.RescueGroup or #DCAF.CSAR.CaptureGroup
    Airbases = {}           -- list of #AIRBASE
}

DCAF.CSAR.SearchGroupsTemnplate = {
    Skill = Skill.Random,
    SearchGroupTemplates = {
        -- list of #string - search group template names
    },
    StartLocations = {
        -- list of #DCAF.Location
    }
}

local CSAR_DistressBeaconTemplate = {
    ClassName = "CSAR_DistressBeaconTemplate",
    BeaconTemplate = nil,
    BeaconTimeActive = VariableValue:New(90, .3),            -- #number or #VariableValue (seconds)
    BeaconTimeInactive = VariableValue:New(Minutes(5), .3),  -- #number/#VariableValue - time (seconds) to keep beacon silent between active periods
}

local CSAR_SafeLocations = { -- dictionary
    -- key = #string (#Coalition)
    -- valiue = list of #DCAF.Location
}

local CSAR_SearchGroup = {  -- note : this template is used both for #DCAF.CSAR.CaptureGroup and #DCAF.CSAR.RescueGroup
    State = CSAR_State.Initializing,
    Name = nil,             -- #string
    Template = nil,         -- #string - group template name
    Group = nil,            -- #GROUP in distress, to be rescued
    SkillFactor = 1,        -- #number (0.0 --> 1.0) : resolved by getSkillFactor()
    Coalition = nil,        -- #Coalition - (string, small letters; "red", "blue", "neutral")
    RtbLocation = nil,      -- #DCAF.Location
    -- IsBeaconTuned = false,    -- #boolean - true - group will detect beacon as son as it comes online
    BeaconDetection = nil,  -- #DCAF.CSAR.BeaconDetection
    CanPickup = true,       -- #boolean - true = group can capture distressed group (eg. transport capable helicopter or ground vechicles
    Count = 1               -- (only applicable when created as template)
}

DCAF.CSAR.RescueGroup = {
    ClassName = "DCAF.CSAR.RescueGroup",
    -- inherites all from #CSAR_SearchGroup
}

DCAF.CSAR.CaptureGroup = { -- todo refactor :: renamed -> DCAF.CSAR.CaptureGroup
    ClassName = "DCAF.CSAR.CaptureGroup",
    -- inherites all from #CSAR_SearchGroup
}

DCAF.CSAR.BeaconDetection = {
    IsBeaconTuned = false,              -- #boolean - true - group will detect beacon as son as it comes online
    DetectionInterval = 20,             -- check for prey becaon every 'N' seconds
    RefinementInterval = Minutes(10),   -- refine beacon location precison every 'N' seconds
    Probability = .02,                  -- probability (0,1) hunter will detect prey's beacon
    ProbabilityInc = .01,               -- increase probability of beacon detection every 'N' seonds
    NextCheck = nil,                    -- next time to check whether beacon is detected
}

local CSAR_RescueResources = {
    -- list of #DCAF.CSAR.RescueResource
}

local CSAR_CaptureResources = {
    -- list of #DCAF.CSAR.CaptureResource
}

local CSAR_SearchResource = {
    Template = nil,             -- #string - eg. "RED Pursuing Heli-escort"
    Locations = nil,            -- #table of-, or #DCAF.Location - eg. Mesquite
    MaxAvailable = 999,
    MaxRange = NauticalMiles(200),   -- #number - default = 100nm
    Skill = Skill.Random,
    IsBeaconTuned = false,      -- default = false
}

DCAF.CSAR.RescueResource = {
    ClassName = "DCAF.CSAR.RescueResource",
    -- inherits rest from CSAR_SearchResource
}

DCAF.CSAR.CaptureResource = {
    ClassName = "DCAF.CSAR.CaptureResource",
    -- inherits rest from CSAR_SearchResource
}

local CSAR_Scheduler = SCHEDULER:New()
local CSAR_Scheduler_isRunning = false
local CSAR_Counter = 0

function CSAR_Scheduler:Run()
    if not CSAR_Scheduler_isRunning then
        CSAR_Scheduler_isRunning = true
        CSAR_Scheduler:Start()
    end
end

function DCAF.Weather:Static()
    if DCAF.Weather._static then
        return DCAF.Weather._static
    end
    local w = DCAF.clone(DCAF.Weather)
    Debug("nisse - DCAF.Weather :: env.mission.weather: " .. DumpPrettyDeep(env.mission.weather))
    DCAF.Weather._static = w
    return w
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                     DISTRESSED GROUP
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local function setState(dg, state)
    if state == dg.State then
        return end

    dg.State = state
if DCAF.Debug then
    MessageTo(nil, "CSAR group '" .. dg.CSAR.Name .. "' state: " .. state)
end
end

local function getSkillFactor(skill)
    local factor 
    if skill == Skill.Excellent then
        factor = 1.0
    elseif skill == Skill.High then
        factor = .75
    elseif skill == Skill.Good then
        factor = .5
    elseif skill == Skill.Average then
        factor = .3
    else
        error("getSkillFactor :: unsupported skill: " .. skill)
    end
    return factor
end

local function stopAndSpawn(dg, motivation)
    if dg:IsStopped() then
        return end

    if motivation then
        Debug(DCAF.CSAR.ClassName .. " :: " .. dg.Name .. " stopped :: " .. motivation)
    end

    local spawn = getSpawn(dg.Group.GroupName)
    dg.Group = spawn:SpawnFromCoordinate(dg._lastCoordinate)
    if not dg.Group:IsActive() then
        dg.Group:Activate()
    end
    if not dg.Group:IsAlive() then
        error("DCAF.CSAR.DistressedGroup:Wait :: cannot activate CSAR for dead group: " .. dg.Group.GroupName) end

    setState(dg, CSAR_State.Stopped)
    return dg
end

local function debug_markLocation(dg)
    -- only updates every 10 seconds
    if not DCAF.Debug or dg._lastCoordinate == dg._markCoordinate then
        return end

    local now = UTILS.SecondsOfToday()
    if dg._markTime then
        local elapsedTime = now - dg._markTime
        if dg._markTime and elapsedTime < 10 then
            return end
    end

    if dg._markID then
        dg._lastCoordinate:RemoveMark(dg._markID)
    end

    local coalition = Coalition.ToNumber(dg.Coalition)
    local color 
    if dg.CSAR.Type == CSAR_Type.Land then
        color = {0,1,0}
    else
        color = {0,0,1}
    end
    dg._markID = dg._lastCoordinate:CircleToAll(nil, coalition, color)
    dg._markTime = now
    dg._markCoordinate = dg._lastCoordinate
end

local function setCoordinate(dg, coord, time)

if dg._lastCoordinate and dg._lastCoordinate:Get2DDistance(coord) > 2000 then
    error("NISSE!") end

    dg._lastCoordinate = coord
    dg._lastCoordinateTime = time or UTILS.SecondsOfToday()

    debug_markLocation(dg)
end

local function driftOnWaves(dg, interval)
    local coord = dg._lastCoordinate
    local windDir, windSpeed = coord:GetWind(0)
    if dg.State ~= CSAR_State.Moving then
        return windDir 
    end

    windDir = (windDir - 180) % 360
    local distance = interval * windSpeed * .5
    setCoordinate(dg, coord:Translate(distance, windDir))
    return windDir
end

local function move(dg)
    if dg.State ~= CSAR_State.Moving then
        return end

    local coordTgt = dg._coordSafeLocation
    -- local coordRestore = dg._lastCoordinate
    
    local now = UTILS.SecondsOfToday()
    local elapsedTime = now - dg._lastCoordinateTime
    local distance = dg._speedMps * elapsedTime
    local coordMove = dg._lastCoordinate:Translate(distance, dg._heading)  -- dg:GetCoordinate(false)
    local distanceTgt = coordMove:Get2DDistance(coordTgt)
    if distanceTgt < 100 then
        setCoordinate(dg, coordMove)
        stopAndSpawn(dg, "reached safe location")
        dg:DeactivateBeacon()
        dg:OnTargetReached(dg._targetLocation)
        return dg
    end

    if dg._nextCoordinate then
        local distanceNext = coordMove:Get2DDistance(dg._nextCoordinate)
        if distanceNext > 50 then
            -- we're still heading to next point, just continue ...
            setCoordinate(dg, coordMove)
            return dg 
        end
    end

    -- local landAndRoads = { land.SurfaceType.LAND, land.SurfaceType.ROAD } -- todo Consider making valid land types configurable
    -- ASTAR:CreateGrid(landAndRoads, ... ?)

    local maxContinousWater = 100 -- meters
    local function isDryPath(coordEnd)
        if coordEnd:IsSurfaceTypeWater() then
-- Debug("nisse - isDryPath :: pilot next coordinate in in water")
            return false 
        end
        local interval = 5
        local continous = 0
        local hdg = coordMove:GetHeadingTo(coordEnd)
        local distance = coordMove:Get2DDistance(coordEnd)
        local coordNext = coordMove
        for i = 1, distance, interval do
            coordNext = coordNext:Translate(i, hdg)
            if coordNext:IsSurfaceTypeWater() then
                continous = continous + interval
-- Debug("nisse - isDryPath :: water in path :: interval: " .. Dump(interval) .. " :: continous: " .. Dump(continous))
                if continous >= maxContinousWater then
                    return false end
            else
                continous = 0
            end            
        end
        return true
    end

    local mainHdg = coordMove:GetHeadingTo(coordTgt)
-- Debug("nisse - move :: mainHdg: " .. Dump(mainHdg))    
    local function getNext(distance, hdg)
        if not hdg then
            local hdgVariance = 80
            local minHdg = (mainHdg - hdgVariance*.5) % 360
            if distanceTgt < distance then
                hdg = mainHdg
            else
                hdg = (minHdg + math.random(hdgVariance)) % 360
            end
        end
        return coordMove:Translate(distance, hdg), hdg
    end

    local function tryDifferentHeading(mainHdg, left, coord, distance, maxHdgDeviation)
        local inc, minMaxHdg
        if not isNumber(maxHdgDeviation) then
            maxHdgDeviation = 120
        end
        if left == true then 
            inc = -10
            minMaxHdg = mainHdg - maxHdgDeviation
        else
            inc = 10
            minMaxHdg = mainHdg + maxHdgDeviation
        end
        local coordNext = coord

        for hdg = mainHdg, minMaxHdg, inc do
            hdg = hdg % 360
            coordNext = coord:Translate(distance, hdg)
            if isDryPath(coordNext) then
                return coordNext, hdg
            end
        end
    end

    local sprintLength = NauticalMiles(1)
    local coordNext, hdgNext = getNext(sprintLength)
    if not isDryPath(coordNext) then
Debug("nisse - move :: not dry path")
        if dg._followWaterHdg then
            local left = math.random(100) < 40
            coordNext, hdgNext = tryDifferentHeading(dg._followWaterHdg, left, coordMove, sprintLength, 60)
            if not coordNext then
                coordNext, hdgNext = tryDifferentHeading(dg._followWaterHdg, not left, coordMove, sprintLength, 60)
            end
        end

        -- randomly try left/right direction ...
        local left = math.random(100) < 10
        coordNext, hdgNext = tryDifferentHeading(mainHdg, left, coordMove, sprintLength)
        if not coordNext then
            coordNext, hdgNext = tryDifferentHeading(mainHdg, not left, coordMove, sprintLength)
        end
        if hdgNext then
            dg._followWaterHdg = hdgNext
        end
    else
        dg._followWaterHdg = nil
    end

    if coordNext then
        setCoordinate(dg, coordMove)
        dg._nextCoordinate = coordNext
        dg._heading = hdgNext
        if DCAF.Debug then
            local color = { 1, .5, 1 }
            if dg._nextCoordinateMarkID then
                COORDINATE:RemoveMark(dg._nextCoordinateMarkID)
            end
            dg._nextCoordinateMarkID = dg._nextCoordinate:CircleToAll(400, Coalition.ToNumber(dg.Coalition), color, 1, nil, 1)
        end
        return dg
    end

    -- path is blocked by too much water; give up and wait for rescue...
    dg._isPathBlocked = true
    -- setCoordinate(dg, coordRestore)
    return stopAndSpawn(dg, "path to safe location was blocked")
end

local function isEnemyDetectingLifeRaftByChance(dg, enemyUnit)
    if not dg:GetCoordinate(false):IsLOS(enemyUnit:GetCoordinate()) then
        return end

    local factor = getSkillFactor(enemyUnit:GetSkill()) * .6 * 100
    if math.random(100) < factor then
        return true
    end
end

local function captureWhenAble(dg, enemyUnit)
    if dg.CSAR:IsCaptureUnit(enemyUnit) then
        -- use hunter logic for this...
        return 

    elseif dg.CSAR:HasCaptureResources() then
        -- report distressed group to hunter groups...
        dg.CSAR:DirectCapableHuntersToCapture()

    -- elseif enemyUnit:IsGround() or enemyUnit:IsShip() then
        -- enemy just happened to see the life raft - what to do now?
         -- leaving this for now
    --     -- just move straight to a close enough location to capture...
    --     local speedMps = enemyUnit:GetVelocityMPS()
    end
end

local function findClosestSafeLocation(dg)
    local coord = dg._lastCoordinate
    local safeLocations = CSAR_SafeLocations[dg.Coalition]
    if not safeLocations then
        return end

    local distClosest = NauticalMiles(99999)
    local locClosest
    for _, loc in ipairs(safeLocations) do
        local distance = coord:Get2DDistance(loc.Coordinate)
        if distance < distClosest then
            distClosest = distance
            locClosest = loc
        end
    end
    return locClosest
end

local function continueOnFoot(dg, coord, heading)
    -- ensure life raft is in water...
    -- local revHeading = (heading - 180) % 360
    setCoordinate(dg, coord:Translate(-3, heading))

    stopAndSpawn(dg, "has reached shore")
    dg._liferaftName = dg.Group:GetUnits()[1].UnitName
-- Debug("nisse - continueOnFoot :: _liferaftName: " .. Dump(dg._liferaftName))
    Debug(DCAF.CSAR.ClassName .. " :: " .. dg.Name .. " has made shore")
    dg.CSAR.Type = CSAR_Type.Land
    setCoordinate(dg, coord:Translate(4, heading))

    -- todo set Ground template
    local t = CSAR_DistressedGroupTemplates.GroundTemplate
    if not t then
        Warning(DCAF.CSAR.ClassName .. " :: continueOnFoot :: no ground template specified :: EXITS")
        return 
    end

    local group = getGroup(t.Template)
    dg.Group = group
    dg.Template = t.Template

    local coordStart = dg._lastCoordinate -- coord:Translate(100, heading)
    if not coordStart:IsSurfaceTypeLand() then
        coordStart = coord:ScanSurfaceType(land.SurfaceType.LAND, heading, 200)
    end
    if not coordStart then
        stopAndSpawn(dg, "is surrounded by water")
        return 
    end

    setCoordinate(dg, coordStart)
    local locClosestSafe = findClosestSafeLocation(dg)
    if locClosestSafe then

if DCAF.Debug then        
    locClosestSafe.Coordinate:CircleToAll(9000)
end
        Debug(DCAF.CSAR.ClassName .. " :: " .. dg.Name .. " continues on land, trying to reach safety")
        dg:MoveTo(locClosestSafe)
    end 
end

local function scheduleDistressedGroup(dg) -- dg : #DCAF.CSAR.DistressedGroup
    -- controls behavior of distressed group, looking for friendlies/enemies, moving, hiding, attracting attention etc...
    if dg._schedulerID then
        return end

    local name = dg.Group.GroupName
    local function isSelf(unit)
-- Debug("nisse - scheduleDistressedGroup_isSelf :: _liferaftName: " .. Dump(dg._liferaftName))        
        if unit.UnitName == dg._liferaftName then 
            return true end
        if dg.Group:IsAlive() and dg.Group.GroupName == unit:GetGroup().GroupName then
            return true end
        return dg.BeaconGroup and dg.BeaconGroup.GroupName == unit:GetGroup().GroupName
    end

    local interval = 3

    dg._schedulerID = CSAR_Scheduler:Schedule(dg, function()

-- Debug("nisse - CSAR_Scheduler:Schedule ...")

        local lifeRaftHeading
        if dg.CSAR.Type == CSAR_Type.Land then
            move(dg)
        else
            lifeRaftHeading = driftOnWaves(dg, interval)
        end
        local coord = dg._lastCoordinate -- dg:GetCoordinate(false)

        -- look for enemy units...
        local otherCoalitions
        if not dg._otherCoalitions then
            dg._otherCoalitions = GetOtherCoalitions(dg.Group, true)
        end

        local captureCoalition = dg._otherCoalitions[1]
        local coalitions = { captureCoalition }
        table.insert(coalitions, dg.Coalition)
        local locRef = DCAF.Location.Resolve(dg._lastCoordinate)
        local closest = locRef:GetClosestUnits(NauticalMiles(20), coalitions, function(unit) return not isSelf(unit) end)
-- Debug("nisse - scheduleDistressedGroup :: closest: " .. DumpPrettyDeep(closest))
        local closestFriendly
        local closestEnemy
        local closestFriendlyDistance
        local closestEnemyDistance
        local closestInfo = closest:Get(dg.Coalition)
        if closestInfo then
            closestFriendly = closestInfo.Unit
            closestFriendlyDistance = closestInfo.Distance
        end
        closestInfo = closest:Get(captureCoalition)
        if closestInfo then
            closestEnemy = closestInfo.Unit
            closestEnemyDistance = closestInfo.Distance
        end

-- Debug("nisse - scheduleDistressedGroup :: closest hostile: " .. DumpPretty(closestEnemy) .. " :: closest friendly: " .. DumpPretty(closestFriendly))

        if closestEnemy and closestEnemyDistance < dg.RangeEnemies and coord:IsLOS(closestEnemy:GetCoordinate()) then
            local isStoppingAndHiding = true
            if closestEnemy:IsGround() and closestEnemyDistance > NauticalMiles(5) then
                -- there's a good chance a ground unit won't be detected (too far away)
                local factor = .05 * #closestEnemy:GetGroup():GetUnits() -- +5% detection chance for every unit in enemy groupp
                factor = factor * 1 / (UTILS.MetersToNM(closestEnemyDistance) / 4)
-- Debug("nisse - checks for ground unit detection :: factor: " .. Dump(factor))
                if math.random(100) > factor*100 then
                    isStoppingAndHiding = false
                end
            end

            if isStoppingAndHiding then
                if dg.State == CSAR_State.Stopped then
                    return end

                dg:DeactivateBeacon()
                dg:OnEnemyDetected(closestEnemy)
                if dg.CSAR.Type == CSAR_Type.Water and isEnemyDetectingLifeRaftByChance(dg, closestEnemy) then
                    captureWhenAble(dg, closestEnemy)
                end
                return
            end
        end

        -- no enemies detected...
-- Debug("nisse - closestFriendly: " .. DumpPretty(closestFriendly) .. " :: distance: " .. Dump(closestFriendlyDistance))
        if closestFriendly and closestFriendlyDistance < dg.RangeSmoke and coord:IsLOS(closestFriendly:GetCoordinate()) then
-- Debug("nisse - closestFriendly: " .. DumpPretty(closestFriendly.UnitName) .. " :: distance: " .. Dump(closestFriendlyDistance))
            dg:OnFriendlyDetectedInSmokeRange(closestFriendly)
            return
        end

        -- use distress beacon if available...
Debug("nisse - scheduleDistressedGroup :: IsBeaconAvailable: " .. Dump(dg:IsBeaconAvailable()))
        if dg:IsBeaconAvailable() then
            local now = UTILS.SecondsOfToday()
            if dg.BeaconNextActive == nil or now > dg.BeaconNextActive then
                dg:ActivateBeacon()
            end
        end

        -- check for land (when drifting in liferaft) ...
-- Debug("nisse - scheduleDistressedGroup :: lifeRaftHeading: " .. Dump(lifeRaftHeading))    
        if lifeRaftHeading then
            local coordLand = dg._lastCoordinate:ScanSurfaceType(land.SurfaceType.LAND, lifeRaftHeading)
            if coordLand then
                continueOnFoot(dg, coordLand, lifeRaftHeading)
            end
        end

    end, { }, interval, interval)
    CSAR_Scheduler:Run()
end

local function stopScheduler(sg)
    if not sg._schedulerID then
        return end

-- Debug("nisse - stops scheduler for " .. sg.Name .. " :: sg._schedulerID: " .. Dump(sg._schedulerID))
    CSAR_Scheduler:Stop(sg._schedulerID)
    sg._schedulerID = nil
end

local function despawnAndMove(dg)
    if dg.Group:IsAlive() then
        dg.Group:Destroy()
    end
    setState(dg, CSAR_State.Moving)
    scheduleDistressedGroup(dg)
end

function DCAF.CSAR.DistressedGroup:NewTemplate(sTemplate, bCanBeCaptured, smoke, flares)
    local group = getGroup(sTemplate)
    if not group then 
        error("DCAF.CSAR.DistressedGroup:NewTemplate :: cannot resolve group from: " .. DumpPretty(sTemplate)) end

    local template = DCAF.clone(DCAF.CSAR.DistressedGroup)
    template.Template = sTemplate
    template.Smoke = smoke or DCAF.Smoke:New(2)
    template.Flares = flares or DCAF.Flares:New(4)
    template.Coalition = Coalition.FromNumber(group:GetCoalition())
    template.CanBeCatured = bCanBeCaptured or true
    return template
end

-- @sTemplate
-- @location            :: #DCAF.Location - start location for distressed group
-- @bCanBeCaptured      :: #bool
-- @smoke               :: #DCAF.Smoke
function DCAF.CSAR.DistressedGroup:New(name, csar, sTemplate, location, bCanBeCaptured, smoke, flares)
    local group = getGroup(sTemplate)
    if not isClass(csar, DCAF.CSAR.ClassName) then
        csar = DCAF.CSAR
    end
    if not group then
        error("DCAF.CSAR.DistressedGroup:New :: cannot resolve group from: " .. DumpPretty(sTemplate)) end

    local testLocation = DCAF.Location.Resolve(location)
    if not testLocation then
        error("DCAF.CSAR.DistressedGroup:Start :: cannot resolve location from: " .. DumpPretty(location)) end

    local coord = testLocation.Coordinate
    if isZone(testLocation.Source) then
        -- randomize location within zone...
        Debug("DCAF.CSAR.DistressedGroup:New :: " .. name .. " :: starts at random location in zone " .. testLocation.Name)
        while coord:IsSurfaceTypeWater() do
            coord = testLocation.Source:GetRandomPointVec2()
        end
    end
    if not isBoolean(bCanBeCaptured) then
        bCanBeCaptured = true
    end
    if not isClass(smoke, DCAF.Smoke.ClassName) then
        smoke = DCAF.Smoke:New()
    end
    location = testLocation
    
    local dg = DCAF.clone(DCAF.CSAR.DistressedGroup)
    dg.Name = name or csar.Name
    dg.CSAR = csar
    dg.Template = sTemplate
    dg.Group = group
    dg.Smoke = smoke or DCAF.Smoke:New(2)
    dg.Flares = flares or DCAF.Flares:New(4)
    dg.Coalition = Coalition.FromNumber(group:GetCoalition())
    dg.CanBeCatured = bCanBeCaptured
    dg._isMoving = false
    setCoordinate(dg, coord)
    return dg
end

function DCAF.CSAR.DistressedGroup:NewFromTemplate(name, csar, location)
    local t
    if location.Coordinate:IsSurfaceTypeWater() then
        t = CSAR_DistressedGroupTemplates.WaterTemplate
        if not t then
            error("DCAF.CSAR.DistressedGroup:NewFromTemplate :: no water template was specified") end
    else
        t = CSAR_DistressedGroupTemplates.GroundTemplate
        if not t then
            error("DCAF.CSAR.DistressedGroup:NewFromTemplate :: no ground template was specified") end
    end
-- Debug("nisse - DCAF.CSAR.DistressedGroup:NewFromTemplate :: template: " .. Dump(t.Template))
-- Debug("nisse - DCAF.CSAR.DistressedGroup:NewFromTemplate :: DCAF.CSAR.DistressBeaconTemplate: " .. DumpPretty(DCAF.CSAR.DistressBeaconTemplate))
    local dg = DCAF.CSAR.DistressedGroup:New(name, csar, t.Template, location, t.CanBeCatured, t.Smoke, t.Flares)
    if isClass(DCAF.CSAR.DistressBeaconTemplate, CSAR_DistressBeaconTemplate.ClassName) then
        local t = DCAF.CSAR.DistressBeaconTemplate

-- Debug("nisse - DCAF.CSAR.DistressedGroup:NewFromTemplate :: assigns beacon :: t: " .. DumpPretty(t))

        dg:WithBeacon(t.Spawn, t.BeaconTimeActive, t.BeaconTimeActive)
    end
    return dg -- DCAF.CSAR.DistressedGroup:New(name, csar, t.Template, location, t.CanBeCatured, t.Smoke, t.Flares)
end

function DCAF.CSAR.DistressedGroup:WithBeacon(spawn, timeActive, timeInactive)

-- Debug("nisse - DCAF.CSAR.DistressedGroup:WithBeacon :: spawn: " .. DumpPretty(spawn) .. " :: _debugId: " .. Dump(self._debugId))

    self.BeaconSpawn = spawn
    self.BeaconTimeActive = timeActive or DCAF.CSAR.DistressedGroup.BeaconTimeActive
    self.BeaconTimeInactive = timeInactive or DCAF.CSAR.DistressedGroup.BeaconTimeInactive
    return self
end

function DCAF.CSAR.DistressedGroup:IsBeaconAvailable()
-- Debug("nisse - DCAF.CSAR.DistressedGroup:IsBeaconAvailable " .. " :: _debugId: " .. Dump(self._debugId) .. " :: self.BeaconSpawn: " .. Dump(self.BeaconSpawn ~= nil) .. " :: self.BeaconGroup: " .. Dump(self.BeaconGroup ~= nil))
    if not self.BeaconSpawn or self:IsBeaconActive() then
        return false 
    end
    if self.BeaconNextActive then
        return UTILS.SecondsOfToday() >= self.BeaconNextActive
    end
    return true
end

function DCAF.CSAR.DistressedGroup:IsBeaconActive()
    return self.BeaconGroup
end

function DCAF.CSAR.DistressedGroup:ActivateBeacon()
    local function getBeaconNextActiveTime()
        local timeInactive
        if isVariableValue(self.BeaconTimeInactive) then
            timeInactive = self.BeaconTimeInactive:GetValue()
        elseif isNumber(self.BeaconTimeInactive) then
            timeInactive = self.BeaconTimeInactive
        else
            timeInactive = 30
        end
        return UTILS.SecondsOfToday() + timeInactive
    end

-- Debug("nisse - DCAF.CSAR.DistressedGroup:ActivateBeacon :: " .. " :: _debugId: " .. Dump(self._debugId) .. " :: self: " .. DumpPretty(self))

    if not self.BeaconSpawn or self:IsBeaconActive() then
        return self
    end

    local function getBeaconIdent()
        if self.BeaconIdent then
            return self.BeaconIdent 
        end
        self.BeaconIdent = "R" .. string.upper(GetTwoLetterCallsign(self.Name))
        return self.BeaconIdent
    end

    local function spawnAndActivateTACAN()
        local distance = math.random(100, 300)
        local hdg = math.random(360)
        local coord = self._lastCoordinate:Translate(distance, hdg)
        self.BeaconGroup = self.BeaconSpawn:SpawnFromCoordinate(coord)
        local wp = coord:WaypointGround(0)
        local ident = getBeaconIdent()
        InsertWaypointAction(
            wp, 
            ActivateBeaconAction(
                BEACON.Type.TACAN,
                self.BeaconChannel,
                UTILS.TACANToFrequency(self.BeaconChannel, self.BeaconMode), 
                self.BeaconMode, 
                ident,
                18, 
                false, 
                false))
        self.BeaconGroup:Route({ wp })
    end

    -- coord = coord:Translate(distance, hdg)
    -- local ident = getBeaconIdent(self)
    spawnAndActivateTACAN()
-- Debug("nisse - DCAF.CSAR.DistressedGroup:ActivateBeacon :: ident: " .. Dump(ident))
    -- CommandActivateTACAN(self.BeaconGroup, self.BeaconChannel, self.BeaconMode, ident)
    if self.BeaconTimeActive then
        local timeActive
        if isVariableValue(self.BeaconTimeActive) then
            timeActive = self.BeaconTimeActive:GetValue()
            Debug("DCAF.CSAR.DistressedGroup:ActivateBeacon :: " .. self.Name .. " :: timeActive: " .. Dump(timeActive))
        elseif isNumber(self.BeaconTimeActive) then
            timeActive = self.BeaconTimeActive
        end
        if timeActive then
            Delay(timeActive, function()
                self:DeactivateBeacon()
                self.BeaconNextActive = getBeaconNextActiveTime()
                local timeInactive = self.BeaconNextActive - UTILS.SecondsOfToday()
                Debug("DCAF.CSAR.DistressedGroup:DeactivateBeacon :: timeInactive: " .. Dump(timeInactive) .. ":: next active time: " .. Dump(UTILS.SecondsToClock(self.BeaconNextActive)))
            end)
        end    
    end
end

function DCAF.CSAR.DistressedGroup:DeactivateBeacon()
    if self.BeaconGroup then
        self.BeaconGroup:Destroy()
        self.BeaconGroup = nil
    end
end

function DCAF.CSAR.DistressedGroup:Start(options)
    if self.State ~= CSAR_State.Initializing then
        error("DCAF.CSAR.DistressedGroup:Start :: cannot activate group in distress (CSAR story already activated)") end

    local channel, mode = options:GetBeaconChannel()
    self.BeaconChannel = channel
    self.BeaconMode = mode

    if self.CSAR.Type == CSAR_Type.Land then
        local locClosest = findClosestSafeLocation(self)
        if locClosest then
            self:MoveTo(locClosest)
        else
            stopAndSpawn(self, "no safe area found")
        end
    else
        self:DriftWithWaves()
        despawnAndMove(self)
    end
    return self
end

function DCAF.CSAR.DistressedGroup:GetCoordinate(update, skillOrSkillFactor)
    local skillFactor = 1
    if isAssignedString(skillOrSkillFactor) then
        local skill = Skill.Validate(skillOrSkillFactor)
        if not skill then
            error("DCAF.CSAR.DistressedGroup:GetCoordinate :: `skillOrSkillFactor` must be valid #Skill (#string) or numeric (0 --> 1) skill factor") end

        skillFactor = getSkillFactor(skill)
    elseif isNumber(skillOrSkillFactor) then
        if skillOrSkillFactor < 0 or skillOrSkillFactor > 1 then
            error("DCAF.CSAR.DistressedGroup:GetCoordinate :: `skillOrSkillFactor` must be valid #Skill (#string) or numeric (0 --> 1) skill factor") end

        skillFactor = skillOrSkillFactor
    end

    local now = UTILS.SecondsOfToday()
    local elapsedTime = now - self._lastCoordinateTime
    local distance = self._speedMps * elapsedTime
if distance > 2000 then
Debug("DCAF.CSAR.DistressedGroup:GetCoordinate :: _speedMps: " .. Dump(self._speedMps) .. " :: elapsedTime: " .. Dump(elapsedTime))
end
    local function adjustPrecisionForSkillFactor()
        if skillFactor == 1 then
            self._lastCoordinate:Translate(distance, self._heading)
            -- return self._lastCoordinate
        end
        local offset = NauticalMiles(3) * (1 / skillFactor)
-- Debug("DCAF.CSAR.DistressedGroup:GetCoordinate :: offset: " .. Dump(offset))
        return self._lastCoordinate:Translate(offset, math.random(360))
    end
    
    if self.State ~= CSAR_State.Moving or (isBoolean(update) and not update) then
        return adjustPrecisionForSkillFactor() end

    if elapsedTime == 0 or not self._nextCoordinate then
        return adjustPrecisionForSkillFactor()
    end

    local coord = self._lastCoordinate:Translate(distance, self._heading)
    setCoordinate(self, self._lastCoordinate:Translate(distance, self._heading))
    self._lastCoordinate:SetAltitude(self._lastCoordinate:GetLandHeight())
    return adjustPrecisionForSkillFactor()
end

function DCAF.CSAR.DistressedGroup:MoveTo(location, speedKmph)
    local coordLocation
    local testLocation = DCAF.Location.Resolve(location)
    if not testLocation then
        error("DCAF.CSAR.DistressedGroup:MoveTo :: cannot resolve location: " .. DumpPretty(location)) end

    if not isNumber(speedKmph) then
        speedKmph = 5
    end
    self._speedMps = UTILS.KmphToMps(speedKmph)
    coordLocation = testLocation:GetCoordinate(false)

    -- todo Consider avoiding roads, urban centres, and steep hills (blocking) and maybe seek out high ground (provides good LOS)

    local coordOwn = self:GetCoordinate(false)
    self._targetLocation = testLocation
    self._coordSafeLocation = coordLocation
    despawnAndMove(self)
if DCAF.Debug then        
Debug("nisse - DCAF.CSAR.DistressedGroup:MoveTo :: self._coordSafeLocation: " .. DumpPretty(self._coordSafeLocation))
    self._coordSafeLocation:CircleToAll(9000)
end    
    return self
end

function DCAF.CSAR.DistressedGroup:DriftWithWaves(interval)
    local coord = self._lastCoordinate -- self:GetCoordinate(true)
    local windDir, windSpeed = coord:GetWind(0)
    if not isNumber(interval) then
        interval = 2
    end
    local speed
    windDir = (windDir - 180) % 360
    local isDrifting = true
    if windSpeed == 0 then
        Debug("CSAR :: " ..self.Name.. " :: life raft will remain stationary (no wind)")
        isDrifting = false
        self._speedMps = 0
    else
        self._speedMps = windSpeed * .5
    end
end

function DCAF.CSAR.DistressedGroup:OnTargetReached(targetLocation)
    Debug("DCAF.CSAR.DistressedGroup:OnTargetReached :: '" .. self.Group.GroupName .. "'")
end

function DCAF.CSAR.DistressedGroup:UseSignal(radius)
    self:DeactivateBeacon()
    local coord = self._lastCoordinate

    local function shootFlares()
        if not self.Flares or self.Flares.Remaining < 1 then
            return end        

        local i = 10
        local flare

        local function _flare()
            self.Flares:Shoot(coord)
            if self.Flares.Remaining == 0 or not self:IsAttractingAttention() then
                return end

            Delay(math.random(50, 180), function() 
                flare()
            end)
        end
        flare = _flare
        flare()
    end

    local function popSmoke()
        if not self.Smoke or self.Smoke.Remaining < 1 then
            return end

        local coordinate = self._lastCoordinate
        if isNumber(radius) then
            coordinate = coordinate:Translate(radius, math.random(360))
        end
        self.Smoke:Pop(coordinate)
    end

    local sunPosition = coord:SunPosition()
    setState(self, CSAR_State.Attracting)
Debug("nisse - DCAF.CSAR.DistressedGroup:UseSignal :: sunPosition: " .. Dump(sunPosition))
    if sunPosition < 5 then
        shootFlares()
    end
    if sunPosition > 0 then
        popSmoke()
    end
    return self
end

function DCAF.CSAR.DistressedGroup:OnActivateBeacon(friendlyUnit)
    self:ActivateBeacon()
end

function DCAF.CSAR.DistressedGroup:AttractAttention(friendlyUnit)
Debug("nisse - DCAF.CSAR.DistressedGroup:OnAttractAttention :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    if self._isDelayedAttractAttention then
        return end

    self._isDelayedAttractAttention = true
    Delay(math.random(15, 60), function()
        self:UseSignal(30)
    end)
end 

-- @friendlyUnit       :: #UNIT - a friendly unit to try and attract attention from
function DCAF.CSAR.DistressedGroup:OnAttractAttention(friendlyUnit)
    stopAndSpawn(self, "is attracting attention")
    if self.State == CSAR_State.Stopped then
        stopScheduler(self)
        self:AttractAttention(friendlyUnit)

        Delay(self.AttractAttentionTime, function() 
            if self.State == CSAR_State.Attracting then
                despawnAndMove(self)
            end
        end)
    end
end

function DCAF.CSAR.DistressedGroup:Pickup(sg)
    local searchUnits = sg.Group:GetUnits()
    self.CarrierUnit = listRandomItem(searchUnits)
    if isClass(sg, DCAF.CSAR.RescueGroup.ClassName) then
        setState(self, CSAR_State.Rescued)
        self:OnRescued(sg)
    else
        setState(self, CSAR_State.Captured)
        self:OnCaptured(sg)
    end
end

function DCAF.CSAR.DistressedGroup:OnRescued(rescueGroup)
    Debug(self.Name .. " was rescued by " .. rescueGroup.Name)
end

function DCAF.CSAR.DistressedGroup:OnCaptured(captureGroup)
    Debug(self.Name .. " was captured by " .. captureGroup.Name)
end

function DCAF.CSAR.DistressedGroup:IsStopped()
    return self.State == CSAR_State.Stopped
end

function DCAF.CSAR.DistressedGroup:IsAttractingAttention()
    return self.State == CSAR_State.Attracting
end

function DCAF.CSAR.DistressedGroup:OnFriendlyDetectedInBeaconRange(friendlyUnit)
Debug("nisse - DCAF.CSAR.DistressedGroup:OnFriendlyDetectedInSmokeRange :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    self:OnActivateBeacon(friendlyUnit)
end
    
function DCAF.CSAR.DistressedGroup:OnFriendlyDetectedInSmokeRange(friendlyUnit)
Debug("nisse - DCAF.CSAR.DistressedGroup:OnFriendlyDetectedInSmokeRange :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    if self:IsAttractingAttention() then
        return end 

    self:OnAttractAttention(friendlyUnit)
end

function DCAF.CSAR.DistressedGroup:OnEnemyDetected(enemyUnit)
    if self.CSAR.Type == CSAR_Type.Land then
Debug("nisse - DCAF.CSAR.DistressedGroup:OnEnemyDetected :: " .. self.Name .. " :: enemyUnit: " .. enemyUnit.UnitName)
        -- do nothing (stay hidden)
        stopAndSpawn(self, "enemy detected - hiding :: enemy unit: " .. enemyUnit.UnitName)
    end
end

local function newSearchGroup(template, name, sTemplate, distressedGroup, startLocation, skill)
    local className = template.ClassName
    local group = getGroup(sTemplate)
    if not group then
        error(className .. ":New :: cannot resolve group from: " .. DumpPretty(sTemplate)) end

    if distressedGroup ~= nil and not isClass(distressedGroup, DCAF.CSAR.DistressedGroup.ClassName) then
        error(className .. ":New :: `distressedGroup` must be #" .. DCAF.CSAR.DistressedGroup.ClassName ..", but was: " .. DumpPretty(distressedGroup)) end

    if startLocation then
        local testLocation = DCAF.Location.Resolve(startLocation)
        if not testLocation then
            error(className .. ":Start :: cannot resolve location from: " .. DumpPretty(startLocation)) end

        local coord = testLocation.Coordinate
        if testLocation:IsZone() then
            -- randomize location within zone...
            Debug(className .. ":New :: " .. name .. " :: starts at random location in zone " .. startLocation.Name)
            coord = testLocation.Source:GetRandomPointVec2()
        end
        startLocation = testLocation
    end
    skill = Skill.Validate(skill)
    if not skill then
        skill = group:GetSkill()
    end
    
    local sg = DCAF.clone(template)
    sg = tableCopy(CSAR_SearchGroup, sg)
    sg.Name = name
    sg.ClassName = template.ClassName
    sg.Template = sTemplate
    sg.Group = group
    sg.Coalition = Coalition.FromNumber(group:GetCoalition())
    sg.Skill = skill
    sg.SkillFactor = getSkillFactor(skill)
-- Debug("nisse - hunter.SkillFactor :: hunter.SkillFactor: " .. Dump(sg.SkillFactor))
    sg.StartLocation = startLocation
    sg.DistressedGroup = distressedGroup
    if distressedGroup then
        sg.CSAR = distressedGroup.CSAR
    end
    sg.BeaconDetection = DCAF.CSAR.BeaconDetection:New(UTILS.SecondsOfToday(), sg.SkillFactor)
    sg.DetectedBeaconCoordinate = nil
    if startLocation and startLocation:IsAirbase() then
       sg.RtbAirbase = startLocation.Source     
    end
    return sg
end

local function withCapabilities(sg, bCanPickup, bInfraredSensor, bIsBeaconTuned)
    if isBoolean(bCanPickup) then
        sg.CanPickup = bCanPickup
    else
        error(sg.ClassName .. ":WithCapabilities :: `bCanPickup` must be boolean (true/false), but was: " .. DumpPretty(bCanPickup)) 
    end
    
    if isBoolean(bInfraredSensor) then
        sg.InfraredSensor = bInfraredSensor
    end
    if isBoolean(bIsBeaconTuned) then
        sg.BeaconDetection.IsBeaconTuned = bIsBeaconTuned
    end
    return sg
end

local function getAirSearchStarPattern(coordCenter, initialHdg, radius, altitude, altType, speed, angle, count)
    if not isNumber(count) then
        count = 5
    else
        count = math.max(2, count)
    end
    if not isNumber(angle) then
        angle = (360 / count) * 2
    end
    local coordNext = coordCenter:Translate(radius, initialHdg)
    local waypoints = {
        coordNext:WaypointAirTurningPoint(altType, speed)
    }
    local angleNext = (initialHdg + angle) % 360
    for i = 1, count, 1 do
        coordNext = coordCenter:Translate(radius, angleNext)
        table.insert(waypoints, coordNext:WaypointAirTurningPoint(altType, speed))
        angleNext = (angleNext + angle) % 360
    end
    return waypoints
end

local function debug_drawSearchArea(sg, patternCenter, radius)
    if not DCAF.Debug then return end
    if sg._debugSearchZoneMarkID then
        patternCenter:RemoveMark(sg._debugSearchZoneMarkID)
    end
    sg._debugSearchZoneMarkID = patternCenter:CircleToAll(radius)
end

local function tryDetectDistressBeaconCoordinate(sg)
    local now = UTILS.SecondsOfToday()
    if sg.DetectedBeaconCoordinate then
        if now < sg.BeaconDetection.NextCheck or not sg.DistressedGroup:IsBeaconActive() then
            return sg.DistressBeaconCoordinate end

        -- beacon is active; increase precision of beacon location over time ...
        sg.BeaconDetection.SkillFactor = math.min(1, sg.BeaconDetection.SkillFactor + .05)    
        sg.DetectedBeaconCoordinate = sg.DistressedGroup:GetCoordinate(false, sg.BeaconDetection.SkillFactor)
        sg.BeaconDetection.NextCheck = now + sg.BeaconDetection.RefinementInterval
    end

    if not sg.DistressedGroup:IsBeaconActive() then
        return end

    if not sg.BeaconDetection then 
        sg.BeaconDetection = DCAF.CSAR.BeaconDetection:New(now, sg.SkillFactor)
    end
    -- check beacon every 'N' seconds...
    if now < sg.BeaconDetection.NextCheck then
        return end

    local probability 
    if sg.BeaconDetection.IsBeaconTuned then
        probability = .95 * sg.SkillFactor * 100
    else
        probability = sg.BeaconDetection.Probability * sg.SkillFactor * 100
    end
    local time = UTILS.SecondsToClock(now)
    sg.BeaconDetection.Probability = sg.BeaconDetection.Probability + sg.BeaconDetection.ProbabilityInc
    sg.BeaconDetection.NextCheck = now + sg.BeaconDetection.DetectionInterval
    local rnd = math.random(100)
-- Debug("tryDetectDistressBeaconCoordinate :: time: " .. time .. " :: IsBeaconTuned: " .. Dump(sg.BeaconDetection.IsBeaconTuned) .. " probability: " .. Dump(probability) .. " :: rnd: " .. Dump(rnd))
    if rnd > probability then
        return end

    -- beacon was detected...
    sg.DetectedBeaconCoordinate = sg.DistressedGroup:GetCoordinate(false, sg.BeaconDetection.SkillFactor)
    return sg.DistressedGroup:GetCoordinate(false, sg.Skill)
end

local function testRtbCriteria(sg, waypoints)
    if sg.BingoFuelState == nil then
        return waypoints end

    for _, wp in ipairs(waypoints) do
        InsertWaypointCallback(wp, function() 
            local fuelState = sg.Group:GetFuel()
Debug("nisse - testRtbCriteria :: fuelState: " .. Dump(fuelState))            
            if fuelState <= sg.BingoFuelState then
                RTBNow(sg.Group, sg.RtbLocation.Source)
            end
        end)
    end
    return waypoints
end

local function debug_drawSearchCircle(sg, radius, color)
    if not DCAF.Debug then
        return end

    local coord = sg.Group:GetCoordinate()
    if sg._debugCaptureCircleMarkID then
-- Debug("debug_drawHunterCircle :: (removes mark)")
        coord:RemoveMark(sg._debugCaptureCircleMarkID)
    end
-- Debug("debug_drawHunterCircle :: radius: " .. Dump(radius) .. " :: coalition: " .. Dump(sg.Coalition))
    sg._debugCaptureCircleMarkID = coord:CircleToAll(radius, Coalition.ToNumber(sg.Coalition), color, 1, nil, 1)
end


local function scheduleSearchGroupDetection(sg) -- sg : #DCAF.CSAR.CaptureGroup or #DCAF.CSAR.RescueGroup
    -- controls behavior of distressed group, looking for friendlies/enemies, moving, hiding, attracting attention etc...
    local name = sg.Group.GroupName

    sg._schedulerID = CSAR_Scheduler:Schedule(sg, function()
-- Debug("nisse - scheduleSearchGroupDetection :: " .. name .. " :: sg._schedulerID: " .. Dump(sg._schedulerID))
        local now = UTILS.SecondsOfToday()

        if not sg.BeaconDetection or now > sg.BeaconDetection.NextCheck then
            -- try locate prey's beacon (if active)...
            local beacon = tryDetectDistressBeaconCoordinate(sg)
            if beacon then
                -- beacon found :: refine search pattern for visual detection...
                local initialHdg = sg.Group:GetCoordinate():HeadingTo(beacon)
                local searchPattern
                local searchRadius = NauticalMiles(5)
                Debug("DCAF.CSAR.CaptureGroup :: hunter '" .. sg.Group.GroupName ..  "' detected distress beacon :: refines search pattern for visual acquisition")
                if sg.Group:IsAir() then
                    searchPattern = getAirSearchStarPattern(beacon, initialHdg, searchRadius, sg.Altitude, sg.AltitudeType)
                else
                    error("todo - ground group seach pattern after beacon detection")
                end
                sg.Group:Route(testRtbCriteria(sg, searchPattern))
                debug_drawSearchArea(sg, beacon, searchRadius)
            end
        end

        -- try visually acquire prey...
        local coordDistressedGroupActual = sg.DistressedGroup._lastCoordinate -- :GetCoordinate(false, 1)
        local coordOwn = sg.Group:GetCoordinate()
        if not sg.Group:GetCoordinate():IsLOS(coordDistressedGroupActual) then
-- Debug("nisse - scheduleSearchGroupDetection :: " .. name .. " (obscured)")
            -- prey is obscured
            return end

        -- we have LOS to prey. Take other factors into accound for actual visual detection...
        -- local revSkillFactor = 1 / hunter.SkillFactor
        local maxVisualDistance
        local attractionFactor = 1
        if sg.DistressedGroup:IsAttractingAttention() then
            maxVisualDistance = NauticalMiles(12)
            attractionFactor = 1.5
        else
            maxVisualDistance = NauticalMiles(2)
        end
        maxVisualDistance = maxVisualDistance * sg.DistressedGroup.SizeDetectionFactor * sg.SkillFactor -- todo Make max distance configurable
        local actualDistance = coordOwn:Get2DDistance(coordDistressedGroupActual)
-- Debug("nisse - scheduleSearchGroupDetection :: " .. name .. "  :: maxVisualDistance: " .. Dump(maxVisualDistance) .. " :: actualDistance: " .. Dump(actualDistance) .. " :: attractionFactor: " .. Dump(attractionFactor) .. " :: dg.State: " .. Dump(sg.DistressedGroup.State))
        if actualDistance > maxVisualDistance then
            return end

        local distanceFactor = actualDistance / maxVisualDistance
        maxVisualDistance = maxVisualDistance * distanceFactor

        -- debug_drawHunterCircle(maxVisualDistance)

        -- if math.random() > distanceFactor then
        --     return end
        local rnd = math.random()
-- Debug("nisse -scheduleSearchGroupDetection :: sg.SkillFactor * attractionFactor: " .. Dump(sg.SkillFactor * attractionFactor) .. " :: rnd: " .. Dump(rnd))
        if rnd > sg.SkillFactor * attractionFactor then
            return end

        -- todo Weather (rain/fog reduces probability of detection)

        -- prey was visually acquired - start capture...
-- Debug("nisse - CSAR :: " .. name .. " :: sg._schedulerID: " .. Dump(sg._schedulerID))
-- CSAR_Scheduler:Stop(sg._schedulerID)
        if isClass(sg, DCAF.CSAR.CaptureGroup.ClassName) then
-- Debug("nisse - CSAR :: hunter " .. sg.Name .. " has spotted " .. sg.DistressedGroup.Group.GroupName .. "!")
            sg.CSAR:DirectCapableHuntersToCapture() 
        elseif isClass(sg, DCAF.CSAR.RescueGroup.ClassName) then
-- Debug("nisse - CSAR :: rescuer " .. sg.Name .. " has spotted " .. sg.DistressedGroup.Group.GroupName .. "!")
            sg.CSAR:DirectCapableRescuersToPickup()
        end

    end, {}, 1, 3)
    CSAR_Scheduler:Run()
end

local function getSearchPatternCenterAndRadius(sg)
    local minDistance
    local maxDistance
    local radius
    if sg.Skill == Skill.Excellent then
        minDistance = 0
        maxDistance = 5
        radius = NauticalMiles(10)
    elseif sg.Skill == Skill.High then
        minDistance = 5
        maxDistance = 15
        radius = NauticalMiles(15)
    elseif sg.Skill == Skill.Good then
        minDistance = 8
        maxDistance = 20
        radius = NauticalMiles(20)
    elseif sg.Skill == Skill.Average then
        minDistance = 12
        maxDistance = 30
        radius = NauticalMiles(30)
    else
        error("getSearchPatternRadius :: unsupported skill: '" .. sg.Skill .. "'")
    end
    local offset = math.random(minDistance, maxDistance)
    local coordCenter = sg.DistressedGroup:GetCoordinate():Translate(NauticalMiles(offset), math.random(360))
    return coordCenter, radius
end

local function startSearchAir(sg)
    local coord0
    local wp0
    local initialHdg
    local spawn = getSpawn(sg.Template)
    local patternCenter  , radius = getSearchPatternCenterAndRadius(sg)
    spawn:InitSkill(sg.Skill)
    local group
    if not sg.StartLocation then
        -- spawn at random location 1 nm outside search pattern...
        local randomAngle = math.random(360)
        local coord0 = patternCenter:Translate(radius + NauticalMiles(1), math.random(360))
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    elseif sg.StartLocation:IsAirbase() then
        local coordAirbase = sg.StartLocation:GetCoordinate()
        coord0 = sg.StartLocation:GetCoordinate()
        initialHdg = coord0:HeadingTo(patternCenter)
        group = spawn:SpawnAtAirbase(sg.StartLocation.Source, SPAWN.Takeoff.Hot)
    elseif sg.StartLocation:IsZone() then
        coord0 = sg.StartLocation.Source:GetRandomPointVec2()
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    else
        local randomAngle = math.random(360)
        coord0 = sg.DistressedGroup:GetCoordinate():Translate(radius, randomAngle)
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    end

    local _expandAgain
    local function expandSearchPatternWhenSearchComplete(searchPattern)
        local lastWP = searchPattern[#searchPattern]
        InsertWaypointCallback(lastWP, function() 
            Debug("DCAF.CSAR.CaptureGroup :: last search waypoint reached :: expands search area")
            radius = radius + NauticalMiles(5)
            initialHdg = COORDINATE_FromWaypoint(lastWP):HeadingTo(patternCenter)
            local searchPattern = getAirSearchStarPattern(patternCenter, initialHdg, radius, sg.Altitude, sg.AltitudeType, sg.Speed)
            _expandAgain(searchPattern)
            if sg.BingoFuelState then
                testRtbCriteria(sg, searchPattern)
            end
            group:Route(searchPattern)
            debug_drawSearchArea(sg, patternCenter, radius)
        end)
    end
    _expandAgain = expandSearchPatternWhenSearchComplete

    local searchPattern = getAirSearchStarPattern(patternCenter, initialHdg, radius, sg.Altitude, sg.AltitudeType, sg.Speed)
    local lastWP = searchPattern[#searchPattern]
    expandSearchPatternWhenSearchComplete(searchPattern)
    group:Route(searchPattern)
    debug_drawSearchArea(sg, patternCenter, radius)
    if sg.BingoFuelState then
        testRtbCriteria(sg, searchPattern)
    end

    scheduleSearchGroupDetection(sg)

    return group
end

local function startSearch(sg, speed, alt, altType)
    if not isNumber(alt) then
        if sg.Group:IsHelicopter() then
            alt = Feet(math.random(300, 800))
        elseif sg.Group:IsAirPlane() then
            alt = Feet(math.random(600, 1200))
        end
    end
    if not isAssignedString(altType) then
        if sg.Group:IsHelicopter() then
            altType = COORDINATE.WaypointAltType.RADIO
        elseif sg.Group:IsAirPlane() then
            altType = COORDINATE.WaypointAltType.BARO
        end
    end
    sg.Altitude = alt
    sg.AltitudeType = altType
    if sg.Group:IsAir() then
        sg.Group = startSearchAir(sg)
        return sg
    elseif sg.Group:IsGround() then
        return startSearchGround(sg)
    else
        error(sg.ClassName ..  ":Start :: invalid group type (expected helicopter, airplane or ground group): " .. sg.Template)
    end
end

local function withRTB(sg, rtbLocation, bingoFuelState)
    local testLocation = DCAF.Location.Resolve(rtbLocation)
    if not testLocation then
        error(sg.ClassName .. ":WithRTB :: cannot resolve `rtbLocation` from: " .. DumpPretty(rtbLocation)) end

    if sg.Group:IsAirPlane() and not rtbLocation:IsAirbase() then
        error(sg.ClassName .. "::WithRTB :: `rtbLocation` must be airbase") 
    end
    rtbLocation = testLocation
    if not isNumber(bingoFuelState) then
        bingoFuelState = .20
    end
    sg.RtbLocation = rtbLocation
    sg.BingoFuelState = bingoFuelState
    return sg
end

local function hoverAndPickup(sg)
    sg.DistressedGroup:Pickup(sg)
    local coord = sg.DistressedGroup._lastCoordinate
    local hdg = coord:HeadingTo(sg.Group:GetCoordinate())
    local coordIngress = coord:Translate(300, (hdg-45) % 360)
    coordIngress:SetAltitude(10, true)
    local wpIngress = coordIngress:WaypointAirFlyOverPoint(sg.AltitudeType, sg.Speed)
    local coordHover = coord:Translate(300, (hdg+45) % 360)--:Translate(300, (hdg-90) % 360)
    coordHover:SetAltitude(10, true)
    local wpHover1 = coordHover:WaypointAirFlyOverPoint(sg.AltitudeType, 1)
    -- coordHover = coord:Translate(0, 0)
    -- coordHover:SetAltitude(10, true)
    -- local wpHover2 = coordHover:WaypointAirFlyOverPoint(sg.AltitudeType, 1)
-- Debug("hoverAndPickup :: wpHover1: " .. DumpPretty(wpHover1) .. " :: wpHover2: " .. DumpPretty(wpHover2))
    local coordProceed = coord:Translate(150, math.random(360))
    local wpDummy = coordProceed:WaypointAirFlyOverPoint(sg.AltitudeType, sg.Speed)
    InsertWaypointCallback(wpHover1, function()
-- Debug("landAndPickup :: wpHover1 function...")   
            Delay(180, function()
-- Debug("landAndPickup :: wpHover1 :: RTB:ing...")
                if isClass(sg, DCAF.CSAR.CaptureGroup.ClassName) then
                    sg.CSAR:RTBHunters()
                elseif isClass(sg, DCAF.CSAR.RescueGroup.ClassName) then
                    sg.CSAR:RTBRescuers()
                end
            end)
        end)
    local waypoints = { wpIngress, wpHover1, wpDummy }
    sg.Group:Route(waypoints)
end

local function landAndPickup(sg)
    sg.DistressedGroup:Pickup(sg)
    local coord = sg.DistressedGroup._lastCoordinate:Translate(40, math.random(360))
    local wpLand = coord:WaypointAirFlyOverPoint(sg.AltitudeType, sg.Speed)
    local setDG = SET_GROUP:New()
    setDG:AddGroup(sg.DistressedGroup.Group)
    InsertWaypointTask(wpLand, sg.Group:TaskEmbarking(coord, setDG, math.random(120)))
    coord = coord:Translate(50, math.random(360))
    local wpTakeOff = coord:WaypointAirFlyOverPoint(sg.AltitudeType, sg.Speed)
    local wpRTB
    if sg.RtbLocation then
-- Debug("landAndPickup :: sg.RtbLocation...")        
        local hdgRTB = coord:GetHeadingTo(sg.RtbLocation)
        local coordRTB = coord:Translate(NauticalMiles(.5), hdgRTB)
        wpRTB = coordRTB:WaypointAirFlyOverPoint(sg.AltitudeType, sg.Speed)
        InsertWaypointCallback(wpRTB, function()
-- Debug("landAndPickup :: rtbWP function...")        
            if isClass(sg, DCAF.CSAR.CaptureGroup.ClassName) then
                sg.CSAR:RTBHunters()
            elseif isClass(sg, DCAF.CSAR.RescueGroup.ClassName) then
                sg.CSAR:RTBRescuers()
            end
        end)
    end
    local waypoints = { wpLand, wpTakeOff, wpRTB }
    InsertWaypointCallback(wpTakeOff, function() 
Debug("landAndPickup :: takeOffWP function...")
        Delay(180, function()
            sg.DistressedGroup.Group:Destroy()
        end)
    end)
    sg.Group:Route(waypoints)
end

local function rtbNow(sg, rtbLocation)
    rtbLocation = rtbLocation or sg.RtbLocation
Debug("nisse - rtbNow :: rtbLocation: " .. DumpPretty(rtbLocation.Source))
    local coord = sg.Group:GetCoordinate()
    local coordRTB = rtbLocation:GetCoordinate()
    local hdg = coord:HeadingTo(coordRTB)
    local distanceToRtbLocation = coord:Get2DDistance(coordRTB) - NauticalMiles(10)
    local distanceEgress = math.min(NauticalMiles(10), coord:Get2DDistance(coordRTB))
    local coordEgress = coord:Translate(distanceEgress, hdg)
    local wpEgress = coordEgress:WaypointAirTurningPoint(sg.AltitudeType)
    wpEgress.speed = Knots(100)
    wpEgress.name = "RTB"
    local coordClimb = coordEgress:Translate(NauticalMiles(5), hdg)
    coordClimb:SetAltitude(Feet(2000), false)
    local wpClimb = coordClimb:WaypointAirTurningPoint(sg.AltitudeType)
    wpClimb.speed = Knots(100)
    wpClimb.name = "CLIMB"
    local wpDummy = coordClimb:Translate(NauticalMiles(5), hdg):WaypointAirTurningPoint(sg.AltitudeType)
    wpDummy.speed = Knots(100)
    wpDummy.name = "..."
    local waypoints = { wpEgress, wpClimb, wpDummy }

Debug("nisse - rtbNow :: waypoints: " .. DumpPrettyDeep(waypoints, 3))

    if rtbLocation then
        InsertWaypointCallback(wpEgress, function()
-- Debug("nisse - DCAF.CSAR:RTBHunters :: rtbLocation: " .. rtbLocation.Name)
            RTBNow(sg.Group, rtbLocation.Source)
        end)
    end

    sg.Group:Route(waypoints)
    return sg
end

local function directCapableGroupsToPickup(groups)
    local function orbitPrey(sg)
        -- establish circling pattern over prey
Debug("DCAF.CSAR :: '" .. sg.Group.GroupName .. "' is orbiting over '" .. sg.DistressedGroup.Group.GroupName .. "'")
        local coordDG = sg.DistressedGroup._lastCoordinate -- :GetCoordinate(false, 1)
        local speed
        if sg.Group:IsHelicopter() then
            speed = 50
        else
            speed = sg.Speed * .6
        end
        local orbitTask = sg.Group:TaskOrbitCircleAtVec2(coordDG:GetVec2(), sg.Altitude, speed)
        local wp0 = sg.Group:GetCoordinate():WaypointAirTurningPoint(sg.AltitudeType, sg.Speed)
        local wp1 = coordDG:WaypointAirTurningPoint(sg.AltitudeType, speed, { orbitTask })
        local waypoints = testRtbCriteria(sg, { wp1 } )
        sg.Group:Route(waypoints)
    end

    local countPickups = 0
    local maxCountPickups = math.random(#groups)

    local function pickup(sg)
 Debug("nisse - DCAF.CSAR:DirectCapableHuntersToCapture :: SG: " .. DumpPretty(sg.Group.GroupName .. " is picking up..."))
        if sg.Group:IsHelicopter() then
            countPickups = countPickups+1
            if sg.CSAR.Type == CSAR_Type.Land then
                landAndPickup(sg)
            elseif sg.CSAR.Type == CSAR_Type.Water then
Debug("... hovering over liferaft")
                hoverAndPickup(sg)
            else
                error("directCapableGroupsToPickup :: unsupported CSAR type: " .. DumpPretty(sg.CSAR.Type))
            end
        elseif sg.Group:IsGround() then
            countPickups = countPickups+1
            approachAndPickup(sg)
        end
    end

    local function canPickup(sg)
        if sg.Group:IsHelicopter() or sg:IsGround() then
            return sg.CanPickup and countPickups < maxCountPickups
        else
            return false
        end
    end

    for _, sg in ipairs(groups) do
Debug("nisse - directCapableGroupsToPickup :: DCAF.CSAR :: '" .. sg.Group.GroupName .. "' :: CanPickup: " .. Dump(sg.CanPickup))
        stopScheduler(sg)
        if canPickup(sg) then
            pickup(sg)
        else
            orbitPrey(sg)
        end
    end
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                     HUNTER GROUP
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function DCAF.CSAR.BeaconDetection:New(nextCheck, skillFactor) -- todo make parameters configurable
    local bd = DCAF.clone(DCAF.CSAR.BeaconDetection)
    bd.NextCheck = nextCheck or UTILS.SecondsOfToday()
    bd.SkillFactor = skillFactor
    bd.ProbabilityInc = skillFactor * DCAF.CSAR.BeaconDetection.ProbabilityInc
    return bd
end

--- Creates and initialises a new #DCAF.CSAR.CaptureGroup
-- @name            :: #string : internal name of pursuing group
-- @sTemplate       :: #string : name of pursuing group template (late activated)
-- @distressedGroup :: #DCAF.CSAR.DistressedGroup : this is what the pursuer is trying to locate and capture
-- @startLocation   :: (optional) #DCAF.Location : name of pursuing group template (late activated) :: default = random location just outside of search area
-- @skill           :: (optional) #Skill : used to control precision in search effort :: default = spawned #GROUP skill (set from Mission Editor)
function DCAF.CSAR.CaptureGroup:New(csar, sTemplate, distressedGroup, startLocation, skill)
    if isAssignedString(csar) then
        -- created as template, signature: (sTemplate, nCount)
        local nCount = sTemplate
        if nCount ~= nil and not isNumber(nCount) then
            error("DCAF.CSAR.RescueGroup:New :: second argument must be number ('nCount') when creating as template")
        end
        local sTemplate = csar
        local rg = newSearchGroup(DCAF.CSAR.CaptureGroup, nil, sTemplate, nil, nil, skill)
        rg.Count = nCount
        return rg
    end

    if not isClass(csar, DCAF.CSAR.ClassName) then
        error("DCAF.CSAR.CaptureGroup:New :: `csar` must be #" .. DCAF.CSAR.ClassName .. ", but was: " .. DumpPretty(csar)) end

    local rg = newSearchGroup(DCAF.CSAR.CaptureGroup, csar.Name, sTemplate, csar.DistressedGroup, startLocation, skill)
    table.insert(csar.CaptureGroups, rg)
    rg = withCapabilities(rg, true, false, true)
Debug("nisse - DCAF.CSAR.CaptureGroup:New :: rg: " .. DumpPretty(rg))
    return rg
end

function DCAF.CSAR.CaptureGroup:NewFromTemplate(csar, captureGroupTemplate, distressedGroup, startLocation)
    local t = captureGroupTemplate
    return DCAF.CSAR.CaptureGroup:New(csar, t.Template, startLocation, t.Skill)
end

function DCAF.CSAR.CaptureGroup:WithCapabilities(bCanPickup, bInfraredSensor, bIsBeaconTuned)
    return withCapabilities(self, bCanPickup, bInfraredSensor, bIsBeaconTuned)
end

function DCAF.CSAR.CaptureGroup:Start(speed, alt, altType)
    startSearch(self, speed, alt, altType)
end

function DCAF.CSAR.CaptureGroup:WithRTB(rtbLocation, bingoFuelState)
    return withRTB(self, rtbLocation, bingoFuelState)
end

function DCAF.CSAR.CaptureGroup:RTBNow(rtbLocation)
    return rtbNow(self, rtbLocation)
end

function DCAF.CSAR.CaptureGroup:IsHunterUnit(unit)
    return unit:GetGroup().GroupName == self.Group.GroupName
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                     RESCUE GROUP
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--- Creates and initialises a new #DCAF.CSAR.RescueGroup
-- @sTemplate       :: #string : name of rescue group template (late activated)
-- @startLocation   :: (optional) #DCAF.Location : name of rescue group template (late activated) :: default = random location just outside of search area
-- @skill           :: (optional) #Skill : used to control precision in search effort :: default = spawned #GROUP skill (set from Mission Editor)
function DCAF.CSAR.RescueGroup:New(csar, sTemplate, startLocation, skill)
    if isAssignedString(csar) then
        -- created as template, signature: (sTemplate, nCount)
        local nCount = sTemplate
        if nCount ~= nil and not isNumber(nCount) then
            error("DCAF.CSAR.RescueGroup:New :: second argument must be number ('nCount') when creating as template")
        end
        local sTemplate = csar
        local rg = newSearchGroup(DCAF.CSAR.RescueGroup, nil, sTemplate, nil, nil, skill)
        rg.Count = nCount
        return rg
    end

    if not isClass(csar, DCAF.CSAR.ClassName) then
        error("DCAF.CSAR.RescueGroup:New :: `csar` must be #" .. DCAF.CSAR.ClassName .. ", but was: " .. DumpPretty(csar)) end

    local rg = newSearchGroup(DCAF.CSAR.RescueGroup, csar.Name, sTemplate, csar.DistressedGroup, startLocation, skill)
    table.insert(csar.RescueGroups, rg)
    rg = withCapabilities(rg, true, false, true)
Debug("nisse - DCAF.CSAR.RescueGroup:New :: rg: " .. DumpPretty(rg))
    return rg
end

function DCAF.CSAR.RescueGroup:NewFromTemplate(csar, rescueGroupTemplate, startLocation)
    local t = rescueGroupTemplate
    return DCAF.CSAR.RescueGroup:New(csar, t.Template, startLocation, t.Skill)
end

function DCAF.CSAR.RescueGroup:WithCapabilities(bCanPickup, bInfraredSensor, bIsBeaconTuned)
    return withCapabilities(self, bCanPickup, bInfraredSensor, bIsBeaconTuned)
end

function DCAF.CSAR.RescueGroup:Start(speed, alt, altType)
    startSearch(self, speed, alt, altType)
end

function DCAF.CSAR.RescueGroup:WithRTB(rtbLocation, bingoFuelState)
    return withRTB(self, rtbLocation, bingoFuelState)
end

function DCAF.CSAR.RescueGroup:RTBNow(rtbLocation)
    return rtbNow(self, rtbLocation)
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                     DCAS (general)
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local CSAR_Ongoing = {
    -- list of #DCAF.CSAR
}

DCAF.CSAR.Options = {
    ClassName = "DCAF.CSAR.Options",
    NotifyScope = nil,          -- #GROUP (, group name,) or #Coalition
    BeaconChannels = { "17Y", "27Y", "37Y", "47Y", "57Y", "67Y", "77Y" },
    Codewords = CSAR_DefaultCodewords,
    DelayRescueMission = -1,    -- #number or #VariableValue - time before a rescue mission launches (-1 = not started automatically)
    DelayCaptureMission = VariableValue:New(Minutes(10), .5), -- #number or #VariableValue - time before capture mission launches (not started if DistressedGroupTemplate.CanBeCatured is false)
    AutoSpawnRescueResources = true
}

function DCAF.CSAR:New(startLocation, name, distressedGroupTemplate, bCanBeCaptured, smoke, flares)
    CSAR_Counter = CSAR_Counter+1
    if not isAssignedString(name) then
        name = self:GetNextRandomCodeword()
    end
    local csar = DCAF.clone(DCAF.CSAR)
    csar.Weather = DCAF.Weather:Static()
    if startLocation.Coordinate:IsSurfaceTypeWater() then
        csar.Type = CSAR_Type.Water
    else
        csar.Type = CSAR_Type.Land
    end
    if not distressedGroupTemplate then
        csar.DistressedGroup = DCAF.CSAR.DistressedGroup:NewFromTemplate(name, csar, startLocation)
    else
        csar.DistressedGroup = DCAF.CSAR.DistressedGroup:New(name, csar, distressedGroupTemplate, startLocation, bCanBeCaptured, smoke, flares)
    end
    table.insert(CSAR_Ongoing, csar)
    return csar
end

-- @options :: #DCAF.CSAR.Options
function DCAF.CSAR:Start(options)
    self.Options = options or DCAF.CSAR.Options:New()
    if not self.Name then
-- Debug("nisse - DCAF.CSAR:Start :: self.Options.Codewords: " .. DumpPrettyDeep(self.Options.Codewords))

        self.Name = self:GetNextRandomCodeword()
    end
    local dg = self.DistressedGroup
    -- if not dg.BeaconTemplate and self.DistressBeaconTemplate then
    --     local t = self.DistressBeaconTemplate
    --     dg:WithBeacon(t.BeaconTemplate, t.BeaconTimeActive, t.BeaconTimeInactive)
    -- end
    self.DistressedGroup:Start(options)
    self:TriggerRescueMissions(options)
    self:TriggerCaptureMissions(options)
    Debug("DCAF.CSAR:Start :: " .. self.Type .. " type CSAR started :: name: " .. self.Name)
end

function DCAF.CSAR.Options:New(notifyScope, codewords, beaconChannels)
    local options = DCAF.clone(DCAF.CSAR.Options)
    options.NotifyScope = notifyScope
    if codewords then
        options:WithCodewords(codewords)
    end
    if isListOfAssignedStrings(beaconChannels) then
        options.BeaconChannels = beaconChannels
    end
    return options
end

-- @codewords : #string (name of theme), #DCAF.CodewordTheme, or #list of #strings (codewords)
function DCAF.CSAR.Options:WithCodewords(codewords, singleUse)
    if not isBoolean(singleUse) then
        singleUse = true
    end
    if not codewords then
        if DCAF.Codewords then
            self.Codewords = DCAF.Codewords:RandomTheme(DCAF.CodewordType.Person, singleUse)
        else
            self.Codewords = DCAF.CodewordTheme:New("(default)", CSAR_DefaultCodewords)
        end
    elseif isAssignedString(codewords) then
-- Debug("DCAF.CSAR.Options:WithCodewords :: codewords: " .. codewords)
        if not DCAF.Codewords then
            error("DCAF.Codewords was not enabled. Please enable DCAF.Codewords before specifyting a codewords theme") end

        local codewordsList = DCAF.Codewords[codewords]
-- Debug("DCAF.CSAR.Options:WithCodewords :: codewordsTheme: " .. DumpPrettyDeep(codewordsTheme))
        if not codewordsList then
            Warning("Codeword theme '" .. codewordsList .. "' was not found :: reverting to default coderword theme")
            codewordsList = CSAR_DefaultCodewords
        end
        self.Codewords = DCAF.CodewordTheme:New(codewords, codewordsList, true)
    elseif isClass(codewords, DCAF.CodewordTheme.ClassName) then
        self.Codewords = codewords
    else
        error("DCAF.CSAR.Options:WithCodewords :: unexpected `codewords`: " .. DumpPretty(codewords))
    end
-- Debug("DCAF.CSAR.Options:WithCodewords :: codewords: " .. DumpPrettyDeep(self.Codewords, 2))
    return self
end

function DCAF.CSAR.Options:WithAutoSpawnRescueResources(value)
    if not isBoolean(value) then
        value = DCAF.CSAR.Options.AutoSpawnRescueResources
    end
    self.AutoSpawnRescueResources = value
end

function DCAF.CSAR.Options:GetBeaconChannel()
    local next = DCAF.CSAR.Options._nextBeaconChannel
    if not next then
        next = 0
    end
    next = next+1
    if next > #DCAF.CSAR.Options.BeaconChannels then
        next = 1
    end
    DCAF.CSAR.Options._nextBeaconChannel = next
    return ParseTACANChannelAndMode(DCAF.CSAR.Options.BeaconChannels[next])
end

local CSAR_EjectedPilots = { -- dictionary
     -- key = #UNIT.UnitName
     -- value = #number (of ejected pilots from same unit)
}

function CSAR_EjectedPilots:GetCoordinateAndRange(unitName)
    local coord = CSAR_EjectedPilots[unitName]
    if not coord then
        CSAR_EjectedPilots[unitName] = coord
    end
end

local function getEstimatedPilotLandingLocation(coordRef, coalition)
Debug("nisse - getEstimatedPilotLandingCoordinates :: coalition: " .. DumpPretty(coalition))

    local locRef = DCAF.Location:New(coordRef)
    local marginStart = NauticalMiles(5) -- todo Consider using wind to affect landing margin and direction 
    local marginAssumed = NauticalMiles(30)
    local coalitions = GetOtherCoalitions(coalition)
    local captureCoalition = coalitions[1]
    local rescueCoalition = Coalition.Resolve(coalition)
    table.insert(coalitions, rescueCoalition)
    local closest = locRef:GetClosestUnits(marginAssumed, coalitions)

    local function calcErrorMargin(forCoalition)
        local factor = 1
        local closest = closest:Get(forCoalition)
        if closest then
            factor = 1 / getSkillFactor(closest.Unit:GetSkill()) * .5 * closest.Distance / marginAssumed
        end
        return marginAssumed * factor
    end

    local coordStart = locRef:Translate(math.random(marginStart), math.random(360))

    local function isAcceptableStartLocation(loc)
        if loc.Coordinate:IsSurfaceTypeWater() and not CSAR_DistressedGroupTemplates.WaterTemplate then
            -- there is no water template for water CSAR
            return end
        
        return true    
    end

    local coordActual = coordStart.Coordinate
    local retryLocation = 10
    while retryLocation > 0 and not isAcceptableStartLocation(coordStart) do
        coordStart = locRef:Translate(math.random(marginStart), math.random(360))
    end

    local marginRescueAssumed = calcErrorMargin(rescueCoalition)
    local coordRescue = locRef:Translate(math.random(marginRescueAssumed), math.random(360))
    local marginCaptureAssumed = calcErrorMargin(captureCoalition)
    local coordCapture = locRef:Translate(math.random(marginCaptureAssumed), math.random(360))
    return coordStart, coordRescue, coordCapture
end

local function simulateEjectedPilotLanding(coordRef, funcOnLanded)
    local alt = coordRef.y
    local vSpeed = 5 -- m/s vertical speed
    local coord = coordRef
    local schedulId
    local interval = 5
    local scheduleObj = {}
    schedulId = CSAR_Scheduler:Schedule(scheduleObj, function() 
        local windDir, windSpeed = coord:GetWind(alt)
        windDir = (windDir - 180) % 360
        coord = coord:Translate(windSpeed*interval, windDir)
        alt = alt - vSpeed*interval
        if alt <= coord:GetLandHeight() then
            CSAR_Scheduler:Stop(schedulId)
            scheduleObj = nil
            funcOnLanded(coord)
        end
    end, { }, interval, interval)
    CSAR_Scheduler:Run()
end

function DCAF.CSAR.NewOnPilotEjects(options, funcOnCreated)
Debug("nisse - DCAF.CSAR:NewOnPilotEjects :: options.Codewords: " .. DumpPrettyDeep(options.Codewords))

    if not isClass(options, DCAF.CSAR.Options.ClassName) then
        options = DCAF.CSAR.Options:New()
    end

    local unitsHit = { -- dictionary
        -- key = #UNIT name
        -- value  = { Coordinate = #COORDINATE, Coalition = #number }
    }

    MissionEvents:OnUnitHit(function(event) 
        unitsHit[event.TgtUnitName] = { 
            Coordinate = event.TgtUnit:GetCoordinate(), 
            Coalition = event.TgtUnit:GetCoalition()
        }
    end)


    MissionEvents:OnEjection(function(event) 

-- Debug("DCAF.CSAR:NewOnPilotEjects_OnEjection :: event: " .. DumpPrettyDeep(event))

        local unit = event.IniUnit
        local group = unit:GetGroup()

        local count = CSAR_EjectedPilots[unit.UnitName]
        if count then
            -- we won't generate multiple CSAR missions for multiple ejections from same unit :: IGNORE
            CSAR_EjectedPilots[unit.UnitName] = count+1
            return 
        end
        CSAR_EjectedPilots[unit.UnitName] = 1

        local hit = unitsHit[event.IniUnitName]
        local coordRef = hit.Coordinate
        local coalition = Coalition.Resolve(hit.Coalition)
        if not coordRef then
            Warning("DCAF.CSAR:NewOnPilotEjects :: no coordinate found for UNIT: '" .. event.IniUnitName .. "' :: EXITS")
            return
        end
        simulateEjectedPilotLanding(coordRef, function(coordLanding) 
            local _, locRescue, locCapture = getEstimatedPilotLandingLocation(coordRef, coalition)
            options.RescueEstimateLocation = locRescue
            options.CaptureEstimateLocation = locCapture

Debug("nisse - OnEjection :: coordRescue: " .. Dump(locRescue ~= nil) .. " :: coordCapture: " .. Dump(locCapture ~= nil))            

            local locStart = DCAF.Location:New(coordLanding)
            local csar = DCAF.CSAR:New(locStart)
            local start = true
            if isFunction(funcOnCreated) then
                start = funcOnCreated(csar) or true
            end

            if start then
                csar:Start(options)
            end
        end)
    end)
    return self
end

function DCAF.CSAR:GetNextRandomCodeword(singleUse)
-- Debug("nisse - DCAF.CSAR:GetNextRandomCodeword :: Codewords: " .. DumpPretty(self.Options.Codewords))
    if DCAF.Codewords and isClass(self.Options.Codewords, DCAF.CodewordTheme.ClassName) then
        return self.Options.Codewords:GetNextRandom()
    elseif isList(self.Options.Codewords) then
        local name, index = listRandomItem(self.Options.Codewords)
        table.remove(self.Options.Codewords, index)
        return name
    end
    if not self.Options.Codewords then
        CSAR_Counter = CSAR_Counter + 1
        return "CSAR-" .. CSAR_Counter
    end
    if isList(self.Codewords) then
        local codeword, index = listRandomItem(self.Codewords)
        if not isBoolean(singleUse) then
            singleUse = true
        end
        if singleUse then 
            table.remove(self.Codewords, index) 
        end
        return codeword
    end
end

local function getClosestMission(locEstimate, tMissions)
    local distanceMin = NauticalMiles(999)
    local airbaseMin = nil
    local mission
    for _, rmt in ipairs(tMissions) do
        for _, ab in ipairs(rmt.Airbases) do
            local distance = ab:GetCoordinate():Get2DDistance(locEstimate:GetCoordinate())
            if distance < distanceMin then
                airbaseMin = ab
                distanceMin = distance
                mission = rmt
            end
        end
    end
    return mission, airbaseMin
end

function DCAF.CSAR:TriggerRescueMissions(options)
    if not options.AutoSpawnRescueResources then
        return end

    local msn, airbase = getClosestMission(options.RescueEstimateLocation, self.RescueMissionTemplates)
    if not msn then
        Warning("DCAF.CSAR:TriggerRescueMissions :: " .. self.Name .." :: could not resolve a suitable rescue mission")
        return
    end
    local locStart = DCAF.Location:New(airbase)
    for _, missionGroupTemplate in ipairs(msn.MissionGroups) do
        local count
        if isNumber(missionGroupTemplate.Count) then
            count = missionGroupTemplate.Count
        else
            count = 1
        end
Debug("DCAF.CSAR:TriggerRescueMissions :: missionGroupTemplate: " .. DumpPretty(missionGroupTemplate) .. " :: counr: " .. Dump(count))
        for i = 1, count, 1 do
            local rg = DCAF.CSAR.RescueGroup:NewFromTemplate(self, missionGroupTemplate, locStart)
                                            :WithRTB(locStart)
                                            :Start(Knots(300))    
            end
    end


    -- DCAF.CSAR.RescueGroup:New(self,  "BLUE Rescue Blackhawk") --, Nellis)
--                      :WithRTB(Nellis)
--                      :Start(Knots(300))

    --  options.RescueEstimateLocation = locRescue
    -- options.CaptureAssumedLocation = locCapture


-- DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Blackhawk", distressed) --, Nellis)
--                      :WithRTB(Nellis)
--                      :Start(Knots(300))
-- DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Apache", distressed) --, Nellis)
--                      :WithRTB(Nellis)
--                      :WithCapabilities(false) -- cannot pickup unit (Apaches can't transport)
--                      :Start(Knots(300))
-- DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Apache", distressed) --, Nellis)
--                      :WithRTB(Nellis)
--                      :WithCapabilities(false) -- cannot pickup unit (Apaches can't transport)
--                      :Start(Knots(300))        
end

function DCAF.CSAR:TriggerCaptureMissions(options)
    -- TODO
end


function DCAF.CSAR:DirectCapableHuntersToCapture()
    directCapableGroupsToPickup(self.CaptureGroups)
end

function DCAF.CSAR:DirectCapableRescuersToPickup()
    directCapableGroupsToPickup(self.RescueGroups)
end

function DCAF.CSAR:RTBHunters()
    for _, hunter in ipairs(self.CaptureGroups) do
Debug("nisse - DCAF.CSAR:RTBHunters :: hunter: " .. hunter.Group.GroupName)
        hunter:RTBNow()
    end
end

function DCAF.CSAR:RTBRescuers()
    for _, rescuer in ipairs(self.RescueGroups) do
Debug("nisse - DCAF.CSAR:RTBRescuers :: rescuer: " .. rescuer.Group.GroupName)
        rescuer:RTBNow()
    end
end

function DCAF.CSAR:IsCaptureUnit(enemyUnit)
    for _, cg in ipairs(self.CaptureGroups) do
        if cg:IsCaptureUNit(enemyUnit) then
            return true
        end
    end
end

function DCAF.CSAR:HasCaptureResources()
    return #self.CaptureGroups > 0
end

-- DCAF.CSAR:UseRandomCodewords()

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                     CSAR RESOURCES
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function DCAF.CSAR.AddResource(resource)
    if isClass(resource, DCAF.CSAR.RescueResource.ClassName) then
        table.insert(CSAR_RescueResources, resource)
    elseif isClass(resource, DCAF.CSAR.CaptureResource.ClassName) then
        table.insert(CSAR_CaptureResources, resource)
    else
        error("DCAF.CSAR:AddResource :: resource must be either #" .. DCAF.CSAR.RescueResource.ClassName .. " or " .. DCAF.CSAR.CaptureResource.ClassName .. ", but was: " .. DumpPretty(resource)) 
    end
end

local CSAR_DistressBeaconTemplates = {
    -- list of #CSAR_DistressBeaconTemplate
}

function CSAR_DistressBeaconTemplate:New(template, timeActive, timeInactive)
    local spawn = getSpawn(template)
    if not spawn then
        error("CSAR_DistressBeaconTemplate:New :: cannot resolve beacon template from: " .. DumpPretty(template)) end

    if not isNumber(timeActive) and not isClass(timeActive, VariableValue.ClassName) then
        timeActive = CSAR_DistressBeaconTemplate.BeaconTimeActive
    end
    if not isNumber(timeInactive) and not isClass(timeInactive, VariableValue.ClassName) then
        timeInactive = CSAR_DistressBeaconTemplate.BeaconTimeInactive
    end
    local template = DCAF.clone(CSAR_DistressBeaconTemplate)
    template.Spawn = spawn
    template.BeaconTimeActive = timeActive
    template.BeaconTimeInactive = timeInactive
    return template
end

function DCAF.CSAR:InitSafeLocations(coalition, ...)
    local c = Coalition.Resolve(coalition)
    if not c then 
        error("DCAF.CSAR:InitSafeLocations :: cannot resolve coalition from: " .. DumpPretty(coalition)) end

    local safeLocations = CSAR_SafeLocations[c]
    if not safeLocations then
        safeLocations = {}
        CSAR_SafeLocations[c] = safeLocations
    end
    for i = 1, #arg, 1 do
        local i = arg[i]
        local loc = DCAF.Location:Resolve(i)
        if isClass(i, DCAF.Location.ClassName) then
            table.insert(safeLocations, i)
        else
            error("DCAF.CSAR:InitSafeLocations :: cannot resolved location #" .. Dump(i) .. ": " .. DumpPretty(i))
        end
    end

end

function DCAF.CSAR:InitDistressedGroup(groundTemplate, waterTemplate)
-- Debug("nisse - DCAF.CSAR:InitDistressedGroup :: groundTemplate: " .. DumpPrettyDeep(groundTemplate) .. " :: waterTemplate: " .. DumpPrettyDeep(waterTemplate))

    if isClass(groundTemplate, DCAF.CSAR.DistressedGroup.ClassName) then
        CSAR_DistressedGroupTemplates.GroundTemplate = groundTemplate
    elseif isAssignedString(groundTemplate) then
        CSAR_DistressedGroupTemplates.GroundTemplate = DCAF.CSAR.DistressedGroup:NewTemplate(groundTemplate)
    end
    if isClass(waterTemplate, DCAF.CSAR.DistressedGroup.ClassName) then
        CSAR_DistressedGroupTemplates.WaterTemplate = waterTemplate
    elseif isAssignedString(waterTemplate) then
        CSAR_DistressedGroupTemplates.WaterTemplate = DCAF.CSAR.DistressedGroup:NewTemplate(waterTemplate)
    end
-- Debug("nisse - DCAF.CSAR:InitDistressedGroup :: CSAR_DistressedGroupTemplates: " .. DumpPrettyDeep(CSAR_DistressedGroupTemplates))    
end

function DCAF.CSAR:InitDistressBeacon(beaconTemplate, timeActive, timeInactive)
    DCAF.CSAR.DistressBeaconTemplate = CSAR_DistressBeaconTemplate:New(beaconTemplate, timeActive, timeInactive)
    return DCAF.CSAR
end

local function initMissions(missionTable, ...)
    local count = 0
    for i = 1, #arg, 1 do
        local mission = arg[i]
        if not isClass(mission, DCAF.CSAR.Mission.ClassName) then
            error("DCAF.CSAR.Mission:New :: arg[" .. Dump(i) .. "] is not a #" .. DCAF.CSAR.Mission.ClassName) end

        table.insert(missionTable, mission)
        count = count+1
    end
    if count == 0 then
        error("DCAF.CSAR.Mission:New :: expected at least one #" .. DCAF.CSAR.Mission.ClassName) end
end

function DCAF.CSAR:InitRescueMissions(...)
    initMissions(self.RescueMissionTemplates, ...)
    return self
end

function DCAF.CSAR:InitCaptureMissions(...)
    initMissions(self.CaptureMissionTemplates, ...)
    return self
end

-- @arg : one ore more #DCAF.CSAR.RescueGroup / #DCAF.CSAR.CaptureGroup
function DCAF.CSAR.Mission:New(name, ...)
    local mission = DCAF.clone(DCAF.CSAR.Mission)
    mission.Name  = name
    local isRescueGroup
    local count = 0
    for i = 1, #arg, 1 do
        local mg = arg[i]
        if not isClass(mg, DCAF.CSAR.RescueGroup.ClassName) and not isClass(mg, DCAF.CSAR.CaptureGroup.ClassName) then
            error("DCAF.CSAR.Mission:New :: arg[" .. Dump(i) .. "] is neither #" .. DCAF.CSAR.RescueGroup.ClassName .. " nor #" .. DCAF.CSAR.CaptureGroup.ClassName) end

        if isRescueGroup == nil then
            isRescueGroup = isClass(mg, DCAF.CSAR.RescueGroup.ClassName)
        end
        if isRescueGroup and isClass(mg, DCAF.CSAR.CaptureGroup.ClassName) then
            error("DCAF.CSAR.Mission:New :: arg[" .. Dump(i) .. "] is a " .. DCAF.CSAR.CaptureGroup.ClassName .. " :: mixing rescue/hunter groups is not allowed") 
        elseif not isRescueGroup and isClass(mg, DCAF.CSAR.RescueGroup.ClassName) then
            error("DCAF.CSAR.Mission:New :: arg[" .. Dump(i) .. "] is a " .. DCAF.CSAR.RescueGroup.ClassName .. " :: mixing rescue/hunter groups is not allowed") 
        end
        table.insert(mission.MissionGroups, mg)
        count = count+1
    end
    if count == 0 then
        error("DCAF.CSAR.Mission:New :: expected at least one #" .. DCAF.CSAR.RescueGroup.ClassName .. " or #" .. DCAF.CSAR.CaptureGroup.ClassName) end

    return mission
end

-- @arg : #strings (airbase names) or #AIRBASEs
function DCAF.CSAR.Mission:AddAirbases(tAirbases)
    local count = 0
    -- if #arg == 0 then
    --     error("DCAF.CSAR.Mission:AddAirbases :: expected at least one #AIRBASE") end

    for i, item in ipairs(tAirbases) do
Debug("nisse - item: " .. Dump(item.ClassName))

        local airbase
        if isAssignedString(item) then
            airbase = AIRBASE:FindByName(item) 
            if not airbase then
                error("DCAF.CSAR.Mission:AddAirbases :: cannot find AIRBASE for arg[" .. Dump(i) .. "]") end

        elseif isClass(item, AIRBASE.ClassName) then
            airbase = item
        end
        if not airbase then
            error("DCAF.CSAR.Mission:AddAirbases :: arg[" .. Dump(i) .. "] is neither #string (airbase name) nor #" .. AIRBASE.ClassName)  end

        table.insert(self.Airbases, item)
        count = count+1
    end
    if count == 0 then
        error("DCAF.CSAR.Mission:AddAirbases :: expected at least one #string (airbase name) or #" .. AIRBASE.ClassName) end

    -- if isList(arg[1]) then
    --     addAirbasesToMission(self, arg[1])
    -- else
    --     addAirbasesToMission(self, {...})
    -- end
    return self
end

local function newSearchResource(resource, sTemplate, locations, maxAvailable, maxRange, skill, isBeaconTuned)
    local spawn = getSpawn(sTemplate)
    if not spawn then 
        error(resource.ClassName .. ":New :: cannot resolve group from: " .. DumpPretty(sTemplate)) end

    local listLocations
    if not isList(locations) then
        local testLocation = DCAF.Location.Resolve(locations)
        if not testLocation then
            error(resource.ClassName .. ":New :: cannot resolve location from: " .. locations) end

        listLocations = { testLocation }
    else
        listLocations = {}
        for i, location in ipairs(locations) do
            local testLocation = DCAF.Location.Resolve(location)
            if not testLocation then
                error(resource.ClassName .. ":New :: cannot resolve locations[" .. Dump(i) .. "]: " .. locations) end

            table.insert(listLocations, testLocation)
        end
    end
    resource.TemplateName = sTemplate
    resource.Spawn = spawn
    resource.Locations = listLocations
    if not isNumber(maxAvailable) then
        resource.MaxAvailable = CSAR_SearchResource.MaxAvailable
    end
    if not isNumber(maxRange) then
        resource.MaxRange = CSAR_SearchResource.MaxRange
    end
    local testSkill = Skill.Validate(skill)
    if not testSkill then 
        skill = Skill.Validate(Skill.Random)
    end
    resource.Skill = skill
    if not isBoolean(isBeaconTuned) then
        resource.IsBeaconTuned = CSAR_SearchResource.IsBeaconTuned
    end
    return resource
end

function DCAF.CSAR.RescueResource:New(sTemplate, locations, maxAvailable, maxRange, skill, isBeaconTuned)
    if not isBoolean(isBeaconTuned) then
        isBeaconTuned = true end

    return newSearchResource(DCAF.clone(DCAF.CSAR.RescueResource), sTemplate, locations, maxAvailable, maxRange, skill, isBeaconTuned)
end

function DCAF.CSAR.CaptureResource:New(sTemplate, locations, maxAvailable, maxRange, skill, isBeaconTuned)
    if not isBoolean(isBeaconTuned) then
        isBeaconTuned = true end

    return newSearchResource(DCAF.clone(DCAF.CSAR.CaptureResource), sTemplate, locations, maxAvailable, maxRange, skill, isBeaconTuned)
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                     CSAR F10 MENUS
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local CSAR_Menu = {
    BlueCoalitionMenu = nil, -- #MENU_COALIITON
    GroupMenus = {  -- dictionary
        -- key   = name of group
        -- value = #MENU_GROUP
    }
}

function DCAF.CSAR:BuildF10CoalitionMenus(parentMenu, forCoalition)
    -- add 'CSAR' menu when distressed group is created
    -- start CSAR mission
end