DCAF.Smoke = {
    ClassName = "DCAF.Smoke",
    Color = SMOKECOLOR.Red,
    Remaining = 1
}

local DCAF_CSAR_State = {
    Initializing = "Initializing",      -- Group has not yet been activated
    Stopped = "Stopped",                -- Group is stopped (eg. pursued group is hiding or waiting to be rescued)
    Moving = "Moving",                  -- Group is moving
    Attracting = "Attracting",          -- Pursued group is attracting attention
    Captured = "Captured",              -- Pursued group was captured (by CarrierUnit)
    RTB = "RTB",                        -- Group is RTB (eg. pursued group was rescued but is not yet safely returned)
    Rescued = "Rescued"                 -- Pursued group was successfully rescued 
}

local CSAR_Scheduler                    -- #SCHEDULER
local CSAR_Scheduler_isRunning = false

DCAF.CSAR = {}

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                     PURSUED GROUP
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.CSAR.PursuedGroup = {
    ClassName = "DCAF.CSAR.PursuedGroup",
    Name = nil,         -- #string
    Template = nil,     -- #string - group template name
    Group = nil,        -- #GROUP in distress, to be rescued
    CarrierUnit = nil,  -- #UNIT set when group is picked up by a UNIT
    State = DCAF_CSAR_State.Initializing,
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
    Smoke = nil         -- #DCAF.Smoke
}

local function setState(csar, state)
    csar.State = state
end


local function stopAndSpawn(csar)
    local spawn = getSpawn(csar.Group.GroupName)
    csar.Group = spawn:SpawnFromCoordinate(csar._lastCoordinate)
    if not csar.Group:IsActive() then
        csar.Group:Activate()
    end
    if not csar.Group:IsAlive() then
        error("DCAF.CSAR.PursuedGroup:Wait :: cannot activate CSAR for dead group: " .. csar.Group.GroupName) end

    setState(csar, DCAF_CSAR_State.Stopped)
    return csar
end

local function debug_markLocation(csar)
    -- only updates every 10 seconds
    if not DCAF.Debug or csar._lastCoordinate == csar._markCoordinate then
        return end

    local now = UTILS.SecondsOfToday()
    if csar._markTime then
        local elapsedTime = now - csar._markTime
        if csar._markTime and elapsedTime < 10 then
            return end
    end

    if csar._markID then
        csar._lastCoordinate:RemoveMark(csar._markID)
    end

    local coalition = Coalition.ToNumber(csar.Coalition)
    csar._markID = csar._lastCoordinate:CircleToAll(nil, coalition)
    csar._markTime = now
    csar._markCoordinate = csar._lastCoordinate
end

local function move(csar)
    if csar.State ~= DCAF_CSAR_State.Moving then
        return end

    local coordTgt = csar._targetCoordinate
    local coord = csar:GetCoordinate()
    local distanceTgt = coord:Get2DDistance(coordTgt)
    if distanceTgt < 100 then
        stopAndSpawn(csar)
        csar:DeactivateBeacon()
        csar:OnTargetReached(csar._targetLocation)
        return csar
    end

    if csar._nextCoordinate then
        local distanceNext = coord:Get2DDistance(csar._nextCoordinate)
        if distanceNext > 50 then
            return csar end
    end

    -- local landAndRoads = { land.SurfaceType.LAND, land.SurfaceType.ROAD } -- todo Consider making valid land types configurable
    -- ASTAR:CreateGrid(landAndRoads, ... ?)

    local maxContinousWater = 20 -- meters
    local function isDryPath(coordEnd)
        local interval = 5
        local continous = 0
        local hdg = coord:GetHeadingTo(coordEnd)
        local distance = coord:Get2DDistance(coordEnd)
        local coordNext = coord
        for i = 1, distance, interval do
            coordNext = coordNext:Translate(i, hdg)
            if coordNext:IsSurfaceTypeWater() then
                continous = continous + interval
                if continous >= maxContinousWater then
                    return false end
            else
                continous = 0
            end            
        end
        return true
    end

    local mainHdg = coord:GetHeadingTo(coordTgt)
    local function getDestination(distance, hdg)
        if not hdg then
            local hdgVariance = 80
            local minHdg = (mainHdg - hdgVariance*.5) % 360
            if distanceTgt < distance then
                hdg = mainHdg
            else
                hdg = (minHdg + math.random(hdgVariance)) % 360
            end
        end
        return coord:Translate(distance, hdg), hdg
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
    local coordNext, hdgNext = getDestination(sprintLength)
    if not isDryPath(coordNext) then
        if csar._followWaterHdg then
            local left = math.random(100) < 40
            coordNext, hdgNext = tryDifferentHeading(csar._followWaterHdg, left, coord, sprintLength, 60)
            if not coordNext then
                coordNext, hdgNext = tryDifferentHeading(csar._followWaterHdg, not left, coord, sprintLength, 60)
            end
        end

        -- randomly try left/right direction ...
        local left = math.random(100) < 10
        coordNext, hdgNext = tryDifferentHeading(mainHdg, left, coord, sprintLength)
        if not coordNext then
            coordNext, hdgNext = tryDifferentHeading(mainHdg, not left, coord, sprintLength)
        end
        if hdgNext then
            csar._followWaterHdg = hdgNext
        end
    else
        csar._followWaterHdg = nil
    end

    if coordNext then
        csar._nextCoordinate = coordNext
        csar._heading = hdgNext
        if DCAF.Debug then
            local color = { 1, 0, 1 }
            if csar._nextCoordinateMarkID then
                COORDINATE:RemoveMark(csar._nextCoordinateMarkID)
            end
            csar._nextCoordinateMarkID = csar._nextCoordinate:CircleToAll(400, Coalition.ToNumber(csar.Coalition), color, 1, nil, 1)
        end
        return csar
    end

    -- path is blocked by too much water; give up and wait for rescue...
    csar._isPathBlocked = true
    return stopAndSpawn(csar)
end

local function startScheduler(csar)
    -- controls behavior of distressed group, looking for friendlies/enemies, moving, hiding, attracting attention etc...
    local name = csar.Group.GroupName
    if not CSAR_Scheduler_isRunning then
        CSAR_Scheduler = SCHEDULER:New()
    end

    local function isSelf(unit)
        if csar.Group:IsAlive() and csar.Group.GroupName == unit:GetGroup().GroupName then
            return true end
        return csar.BeaconGroup and csar.BeaconGroup.GroupName == unit:GetGroup().GroupName
    end

    csar.SchedulerID = CSAR_Scheduler:Schedule(csar, function()
        local zoneEnemies = ZONE_GROUP:New(csar.Name .. "_enemies", csar.Group, csar.RangeEnemies)
        move(csar)
        local coord = csar:GetCoordinate(false)

        debug_markLocation(csar)

        -- look for enemy units...
        local setUnits = SET_UNIT:New():FilterZones({ zoneEnemies }):FilterCoalitions( GetOtherCoalitions(csar.Group) ):FilterOnce()
        local enemyDetected
        setUnits:ForEachUnit(function(enemyUnit)
            if coord:IsLOS(enemyUnit) then
                if enemyDetected then 
                    return 
                end
                -- CSAR group remains hidden
                enemyDetected = true
                csar:OnEnemyDetected(enemyUnit)
                return
            end
        end)
        if enemyDetected then
            Debug("CSAR :: " .. csar.Name .. " :: enemy detected :: " .. name .. " goes silent")
            csar:DeactivateBeacon()
            return
        end

        -- look for friendly units...
        local coalitions = { Coalition.FromNumber(csar.Group:GetCoalition()) }
        local friendlyDetected
        if csar:IsBeaconAvailable() then
            if not isNumber(csar.RangeBeacon) then
                csar:ActivateBeacon()
            else
                local zoneBeacon = ZONE_GROUP:New(csar.Name .. "_beacon", csar.Group, csar.RangeBeacon)
                setUnits = SET_UNIT:New():FilterZones({ zoneBeacon }):FilterCoalitions( coalitions ):FilterOnce()
                setUnits:ForEachUnit(function(friendlyUnit)
                    if friendlyDetected or isSelf(csar, friendlyUnit)then 
                        return end

                    if coord:IsLOS(friendlyUnit) then
                        -- CSAR group attracks attention
                        csar:OnFriendlyDetectedInBeaconRange(friendlyUnit)
                        friendlyDetected = true
                    end
                end)
            end
        end

        local zoneSmoke = ZONE_GROUP:New(csar.Name .. "_smoke", csar.Group, csar.RangeSmoke)
        setUnits = SET_UNIT:New():FilterZones({ zoneSmoke }):FilterCoalitions( coalitions ):FilterOnce()
        friendlyDetected = false
        setUnits:ForEachUnit(function(friendlyUnit)
            if friendlyDetected or isSelf(friendlyUnit) then 
                return end

            if coord:IsLOS(friendlyUnit) then
                -- CSAR group attracks attention
                csar:OnFriendlyDetectedInSmokeRange(friendlyUnit)
                friendlyDetected = true
            end
        end)

    end, { }, 1, 3)
    if not CSAR_Scheduler_isRunning then
        CSAR_Scheduler_isRunning = true
        CSAR_Scheduler:Start()
    end
end

local function stopScheduler(csar)
    CSAR_Scheduler:Stop(csar.SchedulerID)
    csar.SchedulerID = nil
end

local function despawnAndMove(csar)
    if csar.Group:IsAlive() then
        csar.Group:Destroy()
    end
    setState(csar, DCAF_CSAR_State.Moving)
    startScheduler(csar)
    return move(csar)
end

-- @smoke       :: #DCAF.Smoke
function DCAF.Smoke:Pop(coordinate)
    if not isCoordinate(coordinate) then
        error("DCAF.Smoke:Pop :: `coordinate` must be " .. COORDINATE.ClassName .. ", but was: " .. DumpPretty(coordinate)) end

    if self.Remaining == 0 then
        return end

    coordinate:Smoke(self.Color)
    self.Remaining = self.Remaining-1
    return self
end

-- @sTemplate
-- @location            :: #DCAF.Location - start location for pursued group
-- @bCanBeCaptured      :: #bool
-- @smoke               :: #DCAF.Smoke
function DCAF.CSAR.PursuedGroup:New(name, sTemplate, location, bCanBeCaptured, smoke)
    local group = getGroup(sTemplate)
    if not group then
        error("DCAF.CSAR.PursuedGroup:New :: cannot resolve group from: " .. DumpPretty(sTemplate)) end

    local testLocation = DCAF.Location:Resolve(location)
    if not testLocation then
        error("DCAF.CSAR.PursuedGroup:Start :: cannot resolve location from: " .. DumpPretty(location)) end

    local coord = testLocation.Coordinate
    if isZone(testLocation.Source) then
        -- randomize location within zone...
        Debug("DCAF.CSAR.PursuedGroup:New :: " .. name .. " :: starts at random location in zone " .. DumpPrettyDeep(location))
        coord = testLocation.Source:GetRandomPointVec2()
    end
    location = testLocation
    
    local csar = DCAF.clone(DCAF.CSAR.PursuedGroup)
    csar.Name = name
    csar.Template = sTemplate
    csar.Group = group
    csar.Smoke = smoke or DCAF.Smoke:New()
    csar.Coalition = Coalition.FromNumber(group:GetCoalition())
    csar._isMoving = false
    csar._lastCoordinate = coord
    csar._lastCoordinateTime = UTILS.SecondsOfToday()
Debug("nisse -  DCAF.CSAR.PursuedGroup:New :: csar: " .. DumpPretty(csar))    
    return csar
end

function DCAF.CSAR.PursuedGroup:WithBeacon(beaconTemplate, timeActive, timeInactive)
    if isAssignedString(beaconTemplate) then
        self.BeaconTemplate = beaconTemplate
        self.BeaconTimeActive = timeActive or DCAF.CSAR.PursuedGroup.BeaconTimeActive
        self.BeaconTimeInactive = timeInactive or DCAF.CSAR.PursuedGroup.BeaconTimeInactive
    end
    return self
end

function DCAF.CSAR.PursuedGroup:IsBeaconAvailable()
    if not self.BeaconTemplate or self.BeaconGroup then
        return false 
    end
    if self.BeaconNextActive then
        return UTILS.SecondsOfToday() >= self.BeaconNextActive
    end
    return true
end

function DCAF.CSAR.PursuedGroup:IsBeaconActive()
    return self.BeaconGroup
end

function DCAF.CSAR.PursuedGroup:ActivateBeacon()

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

    if not isAssignedString(self.BeaconTemplate) or self:IsBeaconActive() then
        return self
    end

    local spawn = getSpawn(self.BeaconTemplate)
    local distance = math.random(100, 300)
    local hdg = math.random(360)
    local coord = self:GetCoordinate(false)
    coord = coord:Translate(distance, hdg)
    self.BeaconGroup = spawn:SpawnFromCoordinate(coord)
    if self.BeaconTimeActive then
        local timeActive
        if isVariableValue(self.BeaconTimeActive) then
            timeActive = self.BeaconTimeActive:GetValue()
            Debug("DCAF.CSAR.PursuedGroup:ActivateBeacon :: " .. self.Name .. " :: timeActive: " .. Dump(timeActive))
        elseif isNumber(self.BeaconTimeActive) then
            timeActive = self.BeaconTimeActive
        end
        if timeActive then
            Delay(timeActive, function()
                self:DeactivateBeacon()
                self.BeaconNextActive = getBeaconNextActiveTime()
                local timeInactive = self.BeaconNextActive - UTILS.SecondsOfToday()
                Debug("DCAF.CSAR.PursuedGroup:DeactivateBeacon :: timeInactive: " .. Dump(timeInactive) .. ":: next active time: " .. Dump(UTILS.SecondsToClock(self.BeaconNextActive)))
            end)
        end    
    end
end

function DCAF.CSAR.PursuedGroup:DeactivateBeacon()
    if self.BeaconGroup then
        self.BeaconGroup:Destroy()
        self.BeaconGroup = nil
    end
end

function DCAF.CSAR.PursuedGroup:Start()
    if self.State ~= DCAF_CSAR_State.Initializing then
        error("DCAF.CSAR.PursuedGroup:Start :: cannot activate group in distress (CSAR story already activated)") end

    if self._targetLocation then
        despawnAndMove(self)
    else
        stopAndSpawn(self)
    end
    startScheduler(self)
    return self
end

function DCAF.CSAR.PursuedGroup:GetCoordinate(update)
    if self.State ~= DCAF_CSAR_State.Moving or (isBoolean(update) and not update) then
        return self._lastCoordinate end

    local now = UTILS.SecondsOfToday()
    local elapsedTime = now - self._lastCoordinateTime
    if elapsedTime == 0 or not self._nextCoordinate then
        return self._lastCoordinate
    end

    local distance = self._speedMps * elapsedTime
    self._lastCoordinate = self._lastCoordinate:Translate(self._speedMps * elapsedTime, self._heading)
    self._lastCoordinateTime = now
    return self._lastCoordinate
end

function DCAF.CSAR.PursuedGroup:MoveTo(location, speedKmph)
    local coord
    local testLocation = DCAF.Location:Resolve(location)
    if not testLocation then
        error("DCAF.CSAR.PursuedGroup:MoveTo :: cannot resolve location: " .. DumpPretty(location)) end

    coord = testLocation:GetCoordinate(false)
    if not isNumber(speedKmph) then
        speedKmph = 5
    end
    -- todo Consider roads (avoid) and steep hills (too difficult) and high terrain (provides good LOS)

    local coordOwn = self:GetCoordinate(false)
    self._targetLocation = testLocation
    self._targetCoordinate = coord
    self._speedMps = UTILS.KmphToMps(speedKmph)
    return self
end

function DCAF.CSAR.PursuedGroup:OnTargetReached(targetLocation)
    Debug("DCAF.CSAR.PursuedGroup:OnTargetReached :: '" .. self.Group.GroupName .. "'")
end

function DCAF.Smoke:New(color, remaining)
    if not isNumber(color) then
        color = SMOKECOLOR.Red
    end
    if not isNumber(remaining) then
        remaining = 1
    end
    local smoke = DCAF.clone(DCAF.Smoke)
    smoke.Color = color
    smoke.Remaining = remaining
    return smoke
end

function DCAF.CSAR.PursuedGroup:PopSmoke(radius)
    self:DeactivateBeacon()
    if self.Smoke and self.Smoke.Remaining > 0 then
        local coordinate = self:GetCoordinate(false)
        if isNumber(radius) then
            coordinate = coordinate:Translate(radius, math.random(360))
        end
        self.Smoke:Pop(coordinate)
    end
    return self
end

function DCAF.CSAR.PursuedGroup:OnActivateBeacon(friendlyUnit)
    self:ActivateBeacon()
end

function DCAF.CSAR.PursuedGroup:AttractAttention(friendlyUnit)
Debug("nisse - DCAF.CSAR.PursuedGroup:OnAttractAttention :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    Delay(math.random(15, 60), function()
        self:PopSmoke(30)
    end)
    setState(self, DCAF_CSAR_State.Attracting)
end 

-- @friendlyUnit       :: #UNIT - a friendly unit to try and attract attention from
function DCAF.CSAR.PursuedGroup:OnAttractAttention(friendlyUnit)
    stopAndSpawn(self)
    if self.State == DCAF_CSAR_State.Stopped then
        stopScheduler(self)
        self:AttractAttention(friendlyUnit)

        Delay(self.AttractAttentionTime, function() 
            if self.State == DCAF_CSAR_State.Attracting then
                despawnAndMove(self)
            end
        end)
    end
end

function DCAF.CSAR.PursuedGroup:OnFriendlyDetectedInBeaconRange(friendlyUnit)
Debug("nisse - DCAF.CSAR.PursuedGroup:OnFriendlyDetectedInSmokeRange :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    self:OnActivateBeacon(friendlyUnit)
end
    
function DCAF.CSAR.PursuedGroup:OnFriendlyDetectedInSmokeRange(friendlyUnit)
Debug("nisse - DCAF.CSAR.PursuedGroup:OnFriendlyDetectedInSmokeRange :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    self:OnAttractAttention(friendlyUnit)
end

function DCAF.CSAR.PursuedGroup:OnEnemyDetected(enemyUnit)
Debug("nisse - DCAF.CSAR.PursuedGroup:OnEnemyDetected :: " .. self.Name .. " :: enemyUnit: " .. enemyUnit.UnitName)
    -- do nothing (stay hidden)
end

-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                     PURSUING GROUP
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.CSAR.PursuingGroup = {
    ClassName = "DCAF.CSAR.PursuingGroup",
    Name = nil,         -- #string
    Template = nil,     -- #string - group template name
    Group = nil,        -- #GROUP in distress, to be rescued
    State = DCAF_CSAR_State.Initializing,
    Coalition = nil,    -- #Coalition - (string, small letters; "red", "blue", "neutral")
    RtbAirbase = nil    -- #AIRBASE 
}


function DCAF.CSAR.PursuingGroup:New(name, sTemplate, pursued, startLocation, skill)
    local group = getGroup(sTemplate)
    if not group then
        error("DCAF.CSAR.PursuingGroup:New :: cannot resolve group from: " .. DumpPretty(sTemplate)) end

    if not isClass(pursued, DCAF.CSAR.PursuedGroup.ClassName) then
        error("DCAF.CSAR.PursuingGroup:New :: `pursued` must be #" .. DCAF.CSAR.PursuedGroup.ClassName ..", but was: " .. DumpPretty(pursued)) end

    if startLocation then
        local testLocation = DCAF.Location:Resolve(startLocation)
        if not testLocation then
            error("DCAF.CSAR.PursuingGroup:Start :: cannot resolve location from: " .. DumpPretty(startLocation)) end

        local coord = testLocation.Coordinate
        if testLocation:IsZone() then
            -- randomize location within zone...
            Debug("DCAF.CSAR.PursuingGroup:New :: " .. name .. " :: starts at random location in zone " .. DumpPrettyDeep(startLocation))
            coord = testLocation.Source:GetRandomPointVec2()
        end
        startLocation = testLocation
    end
    skill = Skill.Validate(skill)
    if not skill then
        skill = group:GetSkill()
    end
    
    local pg = DCAF.clone(DCAF.CSAR.PursuingGroup)
    pg.Name = name
    pg.Template = sTemplate
    pg.Group = group
    pg.Coalition = Coalition.FromNumber(group:GetCoalition())
    pg.Skill = skill
    pg.StartLocation = startLocation
    pg.PursuedGroup = pursued
    pg.DetectedBeacon = nil
    if startLocation and startLocation:IsAirbase() then
       pg.RtbAirbase = startLocation.Source     
    end
Debug("nisse -  DCAF.CSAR.PursuingGroup:New :: pg: " .. DumpPretty(pg))
    return pg
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

local function getSearchPatternCenterAndRadius(pg)
    local minDistance
    local maxDistance
    local radius
    if pg.Skill == Skill.Excellent then
        minDistance = 0
        maxDistance = 5
        radius = NauticalMiles(10)
    elseif pg.Skill == Skill.High then
        minDistance = 5
        maxDistance = 15
        radius = NauticalMiles(15)
    elseif pg.Skill == Skill.Good then
        minDistance = 8
        maxDistance = 20
        radius = NauticalMiles(20)
    elseif pg.Skill == Skill.Average then
        minDistance = 12
        maxDistance = 30
        radius = NauticalMiles(30)
    else
        error("getSearchPatternRadius :: unsupported skill: '" .. pg.Skill .. "'")
    end
    local offset = math.random(minDistance, maxDistance)
    local coordCenter = pg.PursuedGroup:GetCoordinate():Translate(NauticalMiles(offset), math.random(360))
    return coordCenter, radius
end

local function testRtbCriteria(pg, waypoints)
    if pg.BingoFuelState == nil then
        return end

    for _, wp in ipairs(waypoints) do
        InsertWaypointCallback(wp, function() 
            local fuelState = pg.Group:GetFuel()
Debug("nisse - testRtbCriteria :: fuelState: " .. Dump(fuelState))            
            if fuelState <= pg.BingoFuelState then
                RTBNow(pg.Group, pg.RtbLocation.Source)
            end
        end)
    end
end

local function startPursuingAir(pg)
    local coord0
    local wp0
    local initialHdg
    local spawn = getSpawn(pg.Template)
    local patternCenter, radius = getSearchPatternCenterAndRadius(pg)
    spawn:InitSkill(pg.Skill)
    local group
    if not pg.StartLocation then
        -- spawn at random location 1 nm outside search pattern...
        local randomAngle = math.random(360)
        local coord0 = patternCenter:Translate(radius + NauticalMiles(1), math.random(360))
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    elseif pg.StartLocation:IsAirbase() then
        local coordAirbase = pg.StartLocation:GetCoordinate()
        coord0 = pg.StartLocation:GetCoordinate()
        initialHdg = coord0:HeadingTo(patternCenter)
        group = spawn:SpawnAtAirbase(pg.StartLocation.Source, SPAWN.Takeoff.Hot)
    elseif pg.StartLocation:IsZone() then
        coord0 = pg.StartLocation.Source:GetRandomPointVec2()
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    else
        local randomAngle = math.random(360)
        coord0 = pg.PursuedGroup:GetCoordinate():Translate(radius, randomAngle)
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    end

    local function debug_drawSearchArea(patternCenter)
        if not DCAF.Debug then return end
        if pg._debugSearchZoneMarkID then
            patternCenter:RemoveMark(pg._debugSearchZoneMarkID)
        end
        pg._debugSearchZoneMarkID = patternCenter:CircleToAll(radius)
    end

    local _expandAgain
    local function expandSearchPatternWhenSearchComplete(searchPattern)
        local lastWP = searchPattern[#searchPattern]
        InsertWaypointCallback(lastWP, function() 
            Debug("DCAF.CSAR.PursuingGroup :: last search waypoint reached :: expands search area")
            radius = radius + NauticalMiles(5)
            initialHdg = COORDINATE_FromWaypoint(lastWP):HeadingTo(patternCenter)
            local searchPattern = getAirSearchStarPattern(patternCenter, initialHdg, radius, pg.Altitude, pg.AltitudeType, pg.Speed)
            _expandAgain(searchPattern)
            if pg.BingoFuelState then
                testRtbCriteria(pg, searchPattern)
            end
            group:Route(searchPattern)
            debug_drawSearchArea(patternCenter)
        end)
    end
    _expandAgain = expandSearchPatternWhenSearchComplete

    local searchPattern = getAirSearchStarPattern(patternCenter, initialHdg, radius, pg.Altitude, pg.AltitudeType, pg.Speed)
    local lastWP = searchPattern[#searchPattern]
    expandSearchPatternWhenSearchComplete(searchPattern)
    group:Route(searchPattern)
    debug_drawSearchArea(patternCenter)
    if pg.BingoFuelState then
        testRtbCriteria(pg, searchPattern)
    end
    return group
end

function DCAF.CSAR.PursuingGroup:Start(speed, alt, altType)
    if not isNumber(alt) then
        if self.Group:IsHelicopter() then
            alt = Feet(math.random(300, 800))
        elseif self.Group:IsAirPlane() then
            alt = Feet(math.random(600, 1200))
        end
    end
    if not isAssignedString(altType) then
        if self.Group:IsHelicopter() then
            altType = COORDINATE.WaypointAltType.RADIO
        elseif self.Group:IsAirPlane() then
            altType = COORDINATE.WaypointAltType.BARO
        end
    end
    self.Altitude = alt
    self.AltitudeType = altType
    if self.Group:IsAir() then
        self.Group = startPursuingAir(self)
        return self
    elseif self.Group:IsGround() then
        return startPursuingGround(self)
    else
        error("DCAF.CSAR.PursuingGroup:Start :: invalid group type (expected helicopter, airplane or ground group): " .. self.Template)
    end
end

function DCAF.CSAR.PursuingGroup:WithRTB(rtbLocation, bingoFuelState)
    local testLocation = DCAF.Location:Resolve(rtbLocation)
    if not testLocation then
        error("DCAF.CSAR.PursuingGroup:WithRTB :: cannot resolve `rtbLocation` from: " .. DumpPretty(rtbLocation)) end

    if self.Group:IsAirPlane() and not rtbLocation:IsAirbase() then
        error("DCAF.CSAR.PursuingGroup:WithRTB :: `rtbLocation` must be airbase") 
    end
    rtbLocation = testLocation
    if not isNumber(bingoFuelState) then
        bingoFuelState = .20
    end
    self.RtbLocation = rtbLocation
    self.BingoFuelState = bingoFuelState
    return self
end