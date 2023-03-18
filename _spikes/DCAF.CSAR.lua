DCAF.Smoke = {
    ClassName = "DCAF.CSAR_Smoke",
    Color = SMOKECOLOR.Red,
    Remaining = 1
}

local DCAF_CSAR_State = {
    Initializing = "Initializing",      -- Group has not yet been activated
    Stopped = "Stopped",                -- Group is stopped (hiding or waiting to be rescued)
    Moving = "Moving",                  -- Group is moving toward escape goal
    Attracting = "Attracting",          -- Group is attracting attention
    Captured = "Captured",              -- Group was captured (by CarrierUnit)
    RTB = "RTB",                        -- Group was rescued but is not yet safely returned
    Rescued = "Rescued"                 -- Group was successfully rescued 
}

local CSAR_Scheduler                    -- #SCHEDULER
local CSAR_Scheduler_isRunning = false

DCAF.CSAR = {
    ClassName = "DCAF.CSAR",
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
    Smoke = nil         -- #DCAF.CSAR_Smoke
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
        error("DCAF.CSAR:Wait :: cannot activate CSAR for dead group: " .. csar.Group.GroupName) end

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

    local function tryDifferentHeading(left, coord, distance)
        local inc, minMaxHdg
        if left == true then 
            inc = -10
            minMaxHdg = mainHdg - 120
        else
            inc = 10
            minMaxHdg = mainHdg + 120
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
        -- randomly try left/right direction ...
        local left = math.random(100) < 10
        coordNext, hdgNext = tryDifferentHeading(left, coord, sprintLength)
        if not coordNext then
            coordNext, hdgNext = tryDifferentHeading(not left, coord, sprintLength)
        end
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
        -- Trace("CSAR :: " .. csar.Name .. " ::  " .. name .. " detecting...")
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

-- @smoke       :: #DCAF.CSAR_Smoke
function DCAF.Smoke:Pop(coordinate)
    if not isCoordinate(coordinate) then
        error("DCAF.Smoke:Pop :: `coordinate` must be " .. COORDINATE.ClassName .. ", but was: " .. DumpPretty(coordinate)) end

    if self.Remaining == 0 then
        return end

    coordinate:Smoke(self.Color)
    self.Remaining = self.Remaining-1
    return self
end

-- @smoke       :: #DCAF.CSAR_Smoke
function DCAF.CSAR:New(name, sDistressedTemplate, location, bCanBeCaptured, smoke)
    local group = getGroup(sDistressedTemplate)
    if not group then
        error("DCAF.CSAR:New :: cannot resolve group from: " .. DumpPretty(sDistressedTemplate)) end

    local testLocation = DCAF.Location:Resolve(location)
    if not testLocation then
        error("DCAF.CSAR:Start :: cannot resolve location from: " .. DumpPretty(location)) end

    local coord = testLocation.Coordinate
    if isZone(testLocation.Source) then
        -- randomize location within zone...
        Debug("DCAF.CSAR:New :: " .. name .. " :: starts at random location in zone " .. DumpPrettyDeep(location))
        coord = testLocation.Source:GetRandomPointVec2()
    end
    location = testLocation
    
    local csar = DCAF.clone(DCAF.CSAR)
    csar.Name = name
    csar.Template = sDistressedTemplate
    csar.Group = group
    csar.Smoke = smoke or DCAF.Smoke:New()
    csar.Coalition = Coalition.FromNumber(group:GetCoalition())
    csar._isMoving = false
    csar._lastCoordinate = coord
    csar._lastCoordinateTime = UTILS.SecondsOfToday()
Debug("nisse -  DCAF.CSAR:New :: csar: " .. DumpPretty(csar))    
    return csar
end

function DCAF.CSAR:WithBeacon(beaconTemplate, timeActive, timeInactive)
    if isAssignedString(beaconTemplate) then
        self.BeaconTemplate = beaconTemplate
        self.BeaconTimeActive = timeActive or DCAF.CSAR.BeaconTimeActive
        self.BeaconTimeInactive = timeInactive or DCAF.CSAR.BeaconTimeInactive
    end
    return self
end

function DCAF.CSAR:IsBeaconAvailable()
    if not self.BeaconTemplate or self.BeaconGroup then
        return false 
    end
    if self.BeaconNextActive then
        return UTILS.SecondsOfToday() >= self.BeaconNextActive
    end
    return true
end

function DCAF.CSAR:IsBeaconActive()
    return self.BeaconGroup
end

function DCAF.CSAR:ActivateBeacon()

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
            Debug("DCAF.CSAR:ActivateBeacon :: " .. self.Name .. " :: timeActive: " .. Dump(timeActive))
        elseif isNumber(self.BeaconTimeActive) then
            timeActive = self.BeaconTimeActive
        end
        if timeActive then
            Delay(timeActive, function()
                self:DeactivateBeacon()
                self.BeaconNextActive = getBeaconNextActiveTime()
                local timeInactive = self.BeaconNextActive - UTILS.SecondsOfToday()
                Debug("DCAF.CSAR:DeactivateBeacon :: timeInactive: " .. Dump(timeInactive) .. ":: next active time: " .. Dump(UTILS.SecondsToClock(self.BeaconNextActive)))
            end)
        end    
    end
end

function DCAF.CSAR:DeactivateBeacon()
    if self.BeaconGroup then
        self.BeaconGroup:Destroy()
        self.BeaconGroup = nil
    end
end

function DCAF.CSAR:Start()
    if self.State ~= DCAF_CSAR_State.Initializing then
        error("DCAF.CSAR:Start :: cannot activate group in distress (CSAR story already activated)") end

    if self._targetLocation then
        despawnAndMove(self)
    else
        stopAndSpawn(self)
    end
    startScheduler(self)
    return self
end

function DCAF.CSAR:GetCoordinate(update)
    if self.State ~= DCAF_CSAR_State.Moving or (isBoolean(update) and not update) then
        return self._lastCoordinate end

    local now = UTILS.SecondsOfToday()
    local elapsedTime = now - self._lastCoordinateTime
    if elapsedTime == 0 or not self._nextCoordinate then
        return self._lastCoordinate
    end

    local distance = self._speedMps * elapsedTime
Debug("nisse - DCAF.CSAR:GetCoordinate :: heading: " .. Dump(self._heading))    
    self._lastCoordinate = self._lastCoordinate:Translate(self._speedMps * elapsedTime, self._heading)
    self._lastCoordinateTime = now
    return self._lastCoordinate
end

function DCAF.CSAR:MoveTo(location, speedKmph)
    local coord
    local testLocation = DCAF.Location:Resolve(location)
    if not testLocation then
        error("DCAF.CSAR:MoveTo :: cannot resolve location: " .. DumpPretty(location)) end

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

function DCAF.CSAR:OnTargetReached(targetLocation)
    Debug("DCAF.CSAR:OnTargetReached :: '" .. self.Group.GroupName .. "'")
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

function DCAF.CSAR:PopSmoke(radius)
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

function DCAF.CSAR:OnActivateBeacon(friendlyUnit)
    self:ActivateBeacon()
end

function DCAF.CSAR:AttractAttention(friendlyUnit)
Debug("nisse - DCAF.CSAR:OnAttractAttention :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    Delay(math.random(15, 60), function()
        self:PopSmoke(30)
    end)
    setState(self, DCAF_CSAR_State.Attracting)
end 

-- @friendlyUnit       :: #UNIT - a friendly unit to try and attract attention from
function DCAF.CSAR:OnAttractAttention(friendlyUnit)
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

function DCAF.CSAR:OnFriendlyDetectedInBeaconRange(friendlyUnit)
Debug("nisse - DCAF.CSAR:OnFriendlyDetectedInSmokeRange :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    self:OnActivateBeacon(friendlyUnit)
end
    
function DCAF.CSAR:OnFriendlyDetectedInSmokeRange(friendlyUnit)
Debug("nisse - DCAF.CSAR:OnFriendlyDetectedInSmokeRange :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    self:OnAttractAttention(friendlyUnit)
end

function DCAF.CSAR:OnEnemyDetected(enemyUnit)
Debug("nisse - DCAF.CSAR:OnEnemyDetected :: " .. self.Name .. " :: enemyUnit: " .. enemyUnit.UnitName)
    -- do nothing (stay hidden)
end