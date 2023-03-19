DCAF.Smoke = {
    ClassName = "DCAF.Smoke",
    Color = SMOKECOLOR.Red,
    Remaining = 1
}

DCAF.Weather = {
    Factor = 1,
}

DCAF.Precipitation = {
    None = "None",
    Light = "Light",
    Medium = "Heavy"
}

local DCAF_CSAR_State = {
    Initializing = "Initializing",      -- Group has not yet been activated
    Stopped = "Stopped",                -- Group is stopped (eg. distressed group is hiding or waiting to be rescued)
    Moving = "Moving",                  -- Group is moving
    Attracting = "Attracting",          -- Pursued group is attracting attention
    Captured = "Captured",              -- Pursued group was captured (by CarrierUnit)
    RTB = "RTB",                        -- Group is RTB (eg. distressed group was rescued but is not yet safely returned)
    Rescued = "Rescued"                 -- Pursued group was successfully rescued 
}

DCAF.CSAR = {
    Name = nil,
    DistressedGroup = nil,              -- #DCAF.CSAR.DistressedGroup
    HunterGroups = {},                  -- list of #DCAF.CSAR.HunterGroup
    -- Weather = DCAF.Weather:Static()
}

DCAF.CSAR.DistressedGroup = {
    ClassName = "DCAF.CSAR.DistressedGroup",
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
    SizeDetectionFactor = 1,               -- #number - small targets (single person, like a pilot should be lower; larger should be greater)
    Smoke = nil                            -- #DCAF.Smoke
}

DCAF.CSAR.HunterGroup = {
    ClassName = "DCAF.CSAR.HunterGroup",
    State = DCAF_CSAR_State.Initializing,
    Name = nil,             -- #string
    Template = nil,         -- #string - group template name
    Group = nil,            -- #GROUP in distress, to be rescued
    SkillFactor = 1,        -- #number (0.0 --> 1.0) : resolved by getSkillFactor()
    Coalition = nil,        -- #Coalition - (string, small letters; "red", "blue", "neutral")
    RtbLocation = nil,      -- #DCAF.Location
    BeaconDetection = nil,  -- #DCAF.CSAR.BeaconDetection
    CanCapture = true       -- #boolean - true = group can capture distressed group (eg. transport capable helicopter or ground vechicles
}

DCAF.CSAR.BeaconDetection = {
    DetectionInterval = 20,             -- check for prey becaon every 'N' seconds
    RefinementInterval = Minutes(10),   -- refine beacon location precison every 'N' seconds
    Probability = .02,                  -- probability (0,1) hunter will detect prey's beacon
    ProbabilityInc = .01,               -- increase probability of beacon detection every 'N' seonds
    NextCheck = nil,                    -- next time to check whether beacon is detected
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

function DCAF.CSAR:New(name, distressedGroup, csar)
    CSAR_Counter = CSAR_Counter+1
    if not isAssignedString(name) then
        name = "CSAR-" .. tostring(CSAR_Counter)
    end
    local dg = DCAF.clone(DCAF.CSAR)
    dg.Name = name
    dg.Weather = DCAF.Weather:Static()
    dg.DistressedGroup = distressedGroup
    if not isClass(csar, DCAF.CSAR.ClassName) then
        dg.CSAR = DCAF.CSAR:Default(name)
    end
    dg.CSAR.DistressedGroup = dg
    return dg
end

function DCAF.CSAR:NewEmpty(name)
    CSAR_Counter = CSAR_Counter+1
    if not isAssignedString(name) then
        name = "CSAR-" .. tostring(CSAR_Counter)
    end

    local csar = DCAF.clone(DCAF.CSAR)
    csar.Name = name
    return csar
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

local function setState(csar, state)
    csar.State = state
if DCAF.Debug then
    MessageTo(nil, "Distressed group state: " .. state)
end
end

local function getSkillFactor(skill)
    local factor 
    if skill == Skill.Excellent then
        factor = 1.0
    elseif skill == Skill.Good then
        factor = .75
    elseif skill == Skill.High then
        factor = .5
    elseif skill == Skill.Average then
        factor = .3
    else
        error("getSkillFactor :: unsupported skill: " .. skill)
    end
    return factor
end

local function stopAndSpawn(csar)
    local spawn = getSpawn(csar.Group.GroupName)
    csar.Group = spawn:SpawnFromCoordinate(csar._lastCoordinate)
    if not csar.Group:IsActive() then
        csar.Group:Activate()
    end
    if not csar.Group:IsAlive() then
        error("DCAF.CSAR.DistressedGroup:Wait :: cannot activate CSAR for dead group: " .. csar.Group.GroupName) end

    setState(csar, DCAF_CSAR_State.Stopped)
    return csar
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
    dg._markID = dg._lastCoordinate:CircleToAll(nil, coalition)
    dg._markTime = now
    dg._markCoordinate = dg._lastCoordinate
end

local function move(dg)
    if dg.State ~= DCAF_CSAR_State.Moving then
        return end

    local coordTgt = dg._targetCoordinate
    local coord = dg:GetCoordinate()
    local distanceTgt = coord:Get2DDistance(coordTgt)
    if distanceTgt < 100 then
        stopAndSpawn(dg)
        dg:DeactivateBeacon()
        dg:OnTargetReached(dg._targetLocation)
        return dg
    end

    if dg._nextCoordinate then
        local distanceNext = coord:Get2DDistance(dg._nextCoordinate)
        if distanceNext > 50 then
            return dg end
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
        if dg._followWaterHdg then
            local left = math.random(100) < 40
            coordNext, hdgNext = tryDifferentHeading(dg._followWaterHdg, left, coord, sprintLength, 60)
            if not coordNext then
                coordNext, hdgNext = tryDifferentHeading(dg._followWaterHdg, not left, coord, sprintLength, 60)
            end
        end

        -- randomly try left/right direction ...
        local left = math.random(100) < 10
        coordNext, hdgNext = tryDifferentHeading(mainHdg, left, coord, sprintLength)
        if not coordNext then
            coordNext, hdgNext = tryDifferentHeading(mainHdg, not left, coord, sprintLength)
        end
        if hdgNext then
            dg._followWaterHdg = hdgNext
        end
    else
        dg._followWaterHdg = nil
    end

    if coordNext then
        dg._nextCoordinate = coordNext
        dg._heading = hdgNext
        if DCAF.Debug then
            local color = { 1, 0, 1 }
            if dg._nextCoordinateMarkID then
                COORDINATE:RemoveMark(dg._nextCoordinateMarkID)
            end
            dg._nextCoordinateMarkID = dg._nextCoordinate:CircleToAll(400, Coalition.ToNumber(dg.Coalition), color, 1, nil, 1)
        end
        return dg
    end

    -- path is blocked by too much water; give up and wait for rescue...
    dg._isPathBlocked = true
    return stopAndSpawn(dg)
end

local function runDistressedGroupScheduler(dg) -- dg : #DCAF.CSAR.DistressedGroup
    -- controls behavior of distressed group, looking for friendlies/enemies, moving, hiding, attracting attention etc...
    local name = dg.Group.GroupName
    local function isSelf(unit)
        if dg.Group:IsAlive() and dg.Group.GroupName == unit:GetGroup().GroupName then
            return true end
        return dg.BeaconGroup and dg.BeaconGroup.GroupName == unit:GetGroup().GroupName
    end

    dg.SchedulerID = CSAR_Scheduler:Schedule(dg, function()
        local zoneEnemies = ZONE_GROUP:New(dg.Name .. "_enemies", dg.Group, dg.RangeEnemies)
        move(dg)
        local coord = dg:GetCoordinate(false)

        debug_markLocation(dg)

        -- look for enemy units...
        local otherCoalitions
        if not dg._otherCoalitions then
            dg._otherCoalitions = GetOtherCoalitions(dg.Group)
        end
        local enemies = {}
        local friendlies = {}
        local closestEnemy
        local closestEnemyDistance = NauticalMiles(100)
        local closestFriendly
        local closestFriendlyDistance = NauticalMiles(100)
        local setUnits = dg._lastCoordinate:ScanUnits(dg.RangeEnemies) --  SET_UNIT:New():FilterZones({ zoneEnemies }):FilterCoalitions( dg._otherCoalitions ):FilterOnce()
        local function isEnemy(unit)
            local coalition = unit:GetCoalition()
            for _, c in ipairs(dg._otherCoalitions) do
                if c == coalition then
                    return coalition
                end
            end
        end
        setUnits:ForEachUnit(function(unit)
            local unitCoalition = unit:GetCoalition()
            if unitCoalition == coalition.side.NEUTRAL then
                return end

            if unitCoalition == dg.Group:GetCoalition() then
                table.insert(friendlies, unit)
                return
            end
            local distance = dg._lastCoordinate:Get2DDistance(unit:GetCoordinate())
            if distance < closestEnemyDistance then
                closestEnemyDistance = distance
                closestEnemy = unit
            end
            table.insert(enemies, unit)
        end)

        if closestEnemy and coord:IsLOS(closestEnemy:GetCoordinate()) then
            if dg.State == DCAF_CSAR_State.Stopped then
                return end
            dg:DeactivateBeacon()
            dg:OnEnemyDetected(closestEnemy)
            return
        end

        -- no enemies detected...
        if closestFriendly and coord:IsLOS(closestFriendly:GetCoordinate()) then
            if closestFriendlyDistance <= dg.RangeSmoke then
                dg:OnAttractAttention()
                return
            end
        end

        -- use distress beacon if available...
        if not dg:IsBeaconAvailable() then
            return end

        local now = UTILS.SecondsOfToday()
        if dg.BeaconNextActive == nil or now > dg.BeaconNextActive then
            dg:ActivateBeacon()
        end
    end, { }, 1, 3)
    CSAR_Scheduler:Run()
end

local function stopDistressedGroupScheduler(dg)
    CSAR_Scheduler:Stop(dg.SchedulerID)
    dg.SchedulerID = nil
end

local function despawnAndMove(dg)
    if dg.Group:IsAlive() then
        dg.Group:Destroy()
    end
    setState(dg, DCAF_CSAR_State.Moving)
    runDistressedGroupScheduler(dg)
    return move(dg)
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
-- @location            :: #DCAF.Location - start location for distressed group
-- @bCanBeCaptured      :: #bool
-- @smoke               :: #DCAF.Smoke
function DCAF.CSAR.DistressedGroup:New(name, csar, sTemplate, location, bCanBeCaptured, smoke)
    local group = getGroup(sTemplate)
    if not isClass(csar, DCAF.CSAR.ClassName) then
        csar = DCAF.CSAR        
    end
    if not group then
        error("DCAF.CSAR.DistressedGroup:New :: cannot resolve group from: " .. DumpPretty(sTemplate)) end

    local testLocation = DCAF.Location:Resolve(location)
    if not testLocation then
        error("DCAF.CSAR.DistressedGroup:Start :: cannot resolve location from: " .. DumpPretty(location)) end

    local coord = testLocation.Coordinate
    if isZone(testLocation.Source) then
        -- randomize location within zone...
        Debug("DCAF.CSAR.DistressedGroup:New :: " .. name .. " :: starts at random location in zone " .. DumpPrettyDeep(location))
        coord = testLocation.Source:GetRandomPointVec2()
    end
    location = testLocation
    
    local dg = DCAF.clone(DCAF.CSAR.DistressedGroup)
    dg.Name = name
    dg.CSAR = csar
    dg.Template = sTemplate
    dg.Group = group
    dg.Smoke = smoke or DCAF.Smoke:New()
    dg.Coalition = Coalition.FromNumber(group:GetCoalition())
    dg._isMoving = false
    dg._lastCoordinate = coord
    dg._lastCoordinateTime = UTILS.SecondsOfToday()
Debug("nisse -  DCAF.CSAR.DistressedGroup:New :: csar: " .. DumpPretty(dg))    
    return dg
end

function DCAF.CSAR.DistressedGroup:WithBeacon(beaconTemplate, timeActive, timeInactive)
    if isAssignedString(beaconTemplate) then
        self.BeaconTemplate = beaconTemplate
        self.BeaconTimeActive = timeActive or DCAF.CSAR.DistressedGroup.BeaconTimeActive
        self.BeaconTimeInactive = timeInactive or DCAF.CSAR.DistressedGroup.BeaconTimeInactive
    end
    return self
end

function DCAF.CSAR.DistressedGroup:IsBeaconAvailable()
    if not self.BeaconTemplate or self.BeaconGroup then
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

function DCAF.CSAR.DistressedGroup:Start()
    if self.State ~= DCAF_CSAR_State.Initializing then
        error("DCAF.CSAR.DistressedGroup:Start :: cannot activate group in distress (CSAR story already activated)") end

    if self._targetLocation then
        despawnAndMove(self)
    else
        stopAndSpawn(self)
    end
    runDistressedGroupScheduler(self)
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

    local function adjustPrecisionForSkillFactor()
        if skillFactor == 1 then
            return self._lastCoordinate
        end
        local offset = NauticalMiles(3) * (1 / skillFactor)
Debug("DCAF.CSAR.DistressedGroup:GetCoordinate :: offset: " .. Dump(offset))        
        return self._lastCoordinate:Translate(offset, math.random(360))
    end
    
    if self.State ~= DCAF_CSAR_State.Moving or (isBoolean(update) and not update) then
        return adjustPrecisionForSkillFactor() end

    local now = UTILS.SecondsOfToday()
    local elapsedTime = now - self._lastCoordinateTime
    if elapsedTime == 0 or not self._nextCoordinate then
        return adjustPrecisionForSkillFactor()
    end

    local distance = self._speedMps * elapsedTime
    self._lastCoordinate = self._lastCoordinate:Translate(self._speedMps * elapsedTime, self._heading)
    self._lastCoordinate:SetAltitude(self._lastCoordinate:GetLandHeight())
    self._lastCoordinateTime = now
    return adjustPrecisionForSkillFactor()
end

function DCAF.CSAR.DistressedGroup:MoveTo(location, speedKmph)
    local coord
    local testLocation = DCAF.Location:Resolve(location)
    if not testLocation then
        error("DCAF.CSAR.DistressedGroup:MoveTo :: cannot resolve location: " .. DumpPretty(location)) end

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

function DCAF.CSAR.DistressedGroup:OnTargetReached(targetLocation)
    Debug("DCAF.CSAR.DistressedGroup:OnTargetReached :: '" .. self.Group.GroupName .. "'")
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

function DCAF.CSAR.DistressedGroup:PopSmoke(radius)
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

function DCAF.CSAR.DistressedGroup:OnActivateBeacon(friendlyUnit)
    self:ActivateBeacon()
end

function DCAF.CSAR.DistressedGroup:AttractAttention(friendlyUnit)
Debug("nisse - DCAF.CSAR.DistressedGroup:OnAttractAttention :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    Delay(math.random(15, 60), function()
        self:PopSmoke(30)
    end)
    setState(self, DCAF_CSAR_State.Attracting)
end 

-- @friendlyUnit       :: #UNIT - a friendly unit to try and attract attention from
function DCAF.CSAR.DistressedGroup:OnAttractAttention(friendlyUnit)
    stopAndSpawn(self)
    if self.State == DCAF_CSAR_State.Stopped then
        stopDistressedGroupScheduler(self)
        self:AttractAttention(friendlyUnit)

        Delay(self.AttractAttentionTime, function() 
            if self.State == DCAF_CSAR_State.Attracting then
                despawnAndMove(self)
            end
        end)
    end
end

function DCAF.CSAR.DistressedGroup:OnFriendlyDetectedInBeaconRange(friendlyUnit)
Debug("nisse - DCAF.CSAR.DistressedGroup:OnFriendlyDetectedInSmokeRange :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    self:OnActivateBeacon(friendlyUnit)
end
    
function DCAF.CSAR.DistressedGroup:OnFriendlyDetectedInSmokeRange(friendlyUnit)
Debug("nisse - DCAF.CSAR.DistressedGroup:OnFriendlyDetectedInSmokeRange :: " .. self.Name .. " :: friendlyUnit: " .. friendlyUnit.UnitName)
    self:OnAttractAttention(friendlyUnit)
end

function DCAF.CSAR.DistressedGroup:OnEnemyDetected(enemyUnit)
Debug("nisse - DCAF.CSAR.DistressedGroup:OnEnemyDetected :: " .. self.Name .. " :: enemyUnit: " .. enemyUnit.UnitName)
    -- do nothing (stay hidden)
    stopAndSpawn(self)
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

--- Creates and initialises a new #DCAF.CSAR.HunterGroup
-- @name            :: #string : internal name of pursuing group
-- @sTemplate       :: #string : name of pursuing group template (late activated)
-- @distressedGroup :: #DCAF.CSAR.DistressedGroup : this is what the pursuer is trying to locate and capture
-- @startLocation   :: (optional) #DCAF.Location : name of pursuing group template (late activated) :: default = random location just outside of search area
-- @skill           :: (optional) #Skill : used to control precision in search effort :: default = spawned #GROUP skill (set from Mission Editor)
function DCAF.CSAR.HunterGroup:New(name, sTemplate, distressedGroup, startLocation, skill)
    local group = getGroup(sTemplate)
    if not group then
        error("DCAF.CSAR.HunterGroup:New :: cannot resolve group from: " .. DumpPretty(sTemplate)) end

    if not isClass(distressedGroup, DCAF.CSAR.DistressedGroup.ClassName) then
        error("DCAF.CSAR.HunterGroup:New :: `prey` must be #" .. DCAF.CSAR.DistressedGroup.ClassName ..", but was: " .. DumpPretty(distressedGroup)) end

    if startLocation then
        local testLocation = DCAF.Location:Resolve(startLocation)
        if not testLocation then
            error("DCAF.CSAR.HunterGroup:Start :: cannot resolve location from: " .. DumpPretty(startLocation)) end

        local coord = testLocation.Coordinate
        if testLocation:IsZone() then
            -- randomize location within zone...
            Debug("DCAF.CSAR.HunterGroup:New :: " .. name .. " :: starts at random location in zone " .. DumpPrettyDeep(startLocation))
            coord = testLocation.Source:GetRandomPointVec2()
        end
        startLocation = testLocation
    end
    skill = Skill.Validate(skill)
    if not skill then
        skill = group:GetSkill()
    end
    
    local hunter = DCAF.clone(DCAF.CSAR.HunterGroup)
    hunter.Name = name
    hunter.Template = sTemplate
    hunter.Group = group
    hunter.Coalition = Coalition.FromNumber(group:GetCoalition())
    hunter.Skill = skill
    hunter.SkillFactor = getSkillFactor(skill)
Debug("nisse - hunter.SkillFactor :: hunter.SkillFactor: " .. Dump(hunter.SkillFactor))
    hunter.StartLocation = startLocation
    hunter.Prey = distressedGroup
    hunter.CSAR = distressedGroup.CSAR
    hunter.BeaconDetection = DCAF.CSAR.BeaconDetection:New(UTILS.SecondsOfToday(), hunter.SkillFactor)
    hunter.DetectedBeaconCoordinate = nil
    if startLocation and startLocation:IsAirbase() then
       hunter.RtbAirbase = startLocation.Source     
    end
    table.insert(hunter.CSAR.HunterGroups, hunter)
Debug("nisse -  DCAF.CSAR.HunterGroup:New :: hunter: " .. DumpPretty(hunter))
    return hunter
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

local function debug_drawSearchArea(hunter, patternCenter, radius)
    if not DCAF.Debug then return end
    if hunter._debugSearchZoneMarkID then
        patternCenter:RemoveMark(hunter._debugSearchZoneMarkID)
    end
    hunter._debugSearchZoneMarkID = patternCenter:CircleToAll(radius)
end

local function tryDetectDistressBeaconCoordinate(hunter)
    local now = UTILS.SecondsOfToday()
    if hunter.DetectedBeaconCoordinate then
        if now < hunter.BeaconDetection.NextCheck or not hunter.Prey:IsBeaconActive() then
            return hunter.DistressBeaconCoordinate end

        -- beacon is active; increase precision of beacon location over time ...
        hunter.BeaconDetection.SkillFactor = math.min(1, hunter.BeaconDetection.SkillFactor + .05)    
        hunter.DetectedBeaconCoordinate = hunter.Prey:GetCoordinate(false, hunter.BeaconDetection.SkillFactor)
        hunter.BeaconDetection.NextCheck = now + hunter.BeaconDetection.RefinementInterval
    end

    if not hunter.Prey:IsBeaconActive() then
        return end

    if not hunter.BeaconDetection then 
        hunter.BeaconDetection = DCAF.CSAR.BeaconDetection:New(now, hunter.SkillFactor)
    end
    -- check beacon every 'N' seconds...
    if now < hunter.BeaconDetection.NextCheck then
        return end

    local probability = hunter.BeaconDetection.Probability * hunter.SkillFactor * 100
    local time = UTILS.SecondsToClock(now)
    hunter.BeaconDetection.Probability = hunter.BeaconDetection.Probability + hunter.BeaconDetection.ProbabilityInc
    hunter.BeaconDetection.NextCheck = now + hunter.BeaconDetection.DetectionInterval
    local rnd = math.random(100)
Debug("tryDetectDistressBeaconCoordinate :: time: " .. time .. " :: probability: " .. Dump(probability) .. " :: rnd: " .. Dump(rnd))
    if rnd > probability then
        return end

    -- beacon was detected...
    hunter.DetectedBeaconCoordinate = hunter.Prey:GetCoordinate(false, hunter.BeaconDetection.SkillFactor)
    return hunter.Prey:GetCoordinate(false, hunter.Skill)
end

local function testRtbCriteria(hunter, waypoints)
    if hunter.BingoFuelState == nil then
        return waypoints end

    for _, wp in ipairs(waypoints) do
        InsertWaypointCallback(wp, function() 
            local fuelState = hunter.Group:GetFuel()
Debug("nisse - testRtbCriteria :: fuelState: " .. Dump(fuelState))            
            if fuelState <= hunter.BingoFuelState then
                RTBNow(hunter.Group, hunter.RtbLocation.Source)
            end
        end)
    end
    return waypoints
end

local function debug_drawHunterCircle(hunter, radius, color)
    if not DCAF.Debug then
        return end

    local coord = hunter.Group:GetCoordinate()
    if hunter._debugHunterCircleMarkID then
Debug("debug_drawHunterCircle :: (removes mark)")
        coord:RemoveMark(hunter._debugHunterCircleMarkID)
    end
Debug("debug_drawHunterCircle :: radius: " .. Dump(radius) .. " :: coalition: " .. Dump(hunter.Coalition))
    hunter._debugHunterCircleMarkID = coord:CircleToAll(radius, Coalition.ToNumber(hunter.Coalition), color, 1, nil, 1)
end


local function scheduleHunterDetection(hunter) -- p : #DCAF.CSAR.HunterGroup
    -- controls behavior of distressed group, looking for friendlies/enemies, moving, hiding, attracting attention etc...
    local name = hunter.Group.GroupName

    hunter.SchedulerID = CSAR_Scheduler:Schedule(hunter, function()
-- Debug("runHunterDetectionScheduler...")        
        local now = UTILS.SecondsOfToday()

        if not hunter.BeaconDetection or now > hunter.BeaconDetection.NextCheck then
            -- try locate prey's beacon (if active)...
            local beacon = tryDetectDistressBeaconCoordinate(hunter)
            if beacon then
                -- beacon found :: refine search pattern for visual detection...
                local initialHdg = hunter.Group:GetCoordinate():HeadingTo(beacon)
                local searchPattern
                local searchRadius = NauticalMiles(5)
                Debug("DCAF.CSAR.HunterGroup :: hunter '" .. hunter.Group.GroupName ..  "' detected distress beacon :: refines search pattern for visual acquisition")
                if hunter.Group:IsAir() then
                    searchPattern = getAirSearchStarPattern(beacon, initialHdg, searchRadius, hunter.Altitude, hunter.AltitudeType)
                else
                    error("todo - ground group seach pattern after beacon detection")
                end
                hunter.Group:Route(testRtbCriteria(hunter, searchPattern))
                debug_drawSearchArea(hunter, beacon, searchRadius)
            end
        end

        -- try visually acquire prey...
        local coordPreyActual = hunter.Prey:GetCoordinate(false, 1)
        local coordOwn = hunter.Group:GetCoordinate()
        if not hunter.Group:GetCoordinate():IsLOS(coordPreyActual) then
            -- prey is obscured
            return end

        -- we have LOS to prey. Take other factors into accound for actual visual detection...
        -- local revSkillFactor = 1 / hunter.SkillFactor
        local maxVisualDistance = (NauticalMiles(2) * hunter.Prey.SizeDetectionFactor) * hunter.SkillFactor -- todo Make max distance configurable
-- Debug("runHunterDetectionScheduler :: maxVisualDistance: " .. Dump(maxVisualDistance))
        local actualDistance = coordOwn:Get2DDistance(coordPreyActual)
        if actualDistance > maxVisualDistance then
            return end

        local distanceFactor = actualDistance / maxVisualDistance
        maxVisualDistance = maxVisualDistance * distanceFactor

        -- debug_drawHunterCircle(maxVisualDistance)

        if math.random() > distanceFactor then
            return end

        if math.random() > hunter.SkillFactor then
            return end

        -- todo Weather (rain/fog reduces probability of detection)

        -- prey was visually acquired - start capture...
        Debug("nisse - CSAR :: hunter " .. hunter.Name .. " has spotted " .. hunter.Prey.Group.GroupName .. "!")
        CSAR_Scheduler:Stop(hunter._schedulerID)
        hunter.CSAR:DirectCapableHuntersToCapture()

    end, {}, 1, 3)

    CSAR_Scheduler:Run()
end

local function getSearchPatternCenterAndRadius(hunter)
    local minDistance
    local maxDistance
    local radius
    if hunter.Skill == Skill.Excellent then
        minDistance = 0
        maxDistance = 5
        radius = NauticalMiles(10)
    elseif hunter.Skill == Skill.High then
        minDistance = 5
        maxDistance = 15
        radius = NauticalMiles(15)
    elseif hunter.Skill == Skill.Good then
        minDistance = 8
        maxDistance = 20
        radius = NauticalMiles(20)
    elseif hunter.Skill == Skill.Average then
        minDistance = 12
        maxDistance = 30
        radius = NauticalMiles(30)
    else
        error("getSearchPatternRadius :: unsupported skill: '" .. hunter.Skill .. "'")
    end
    local offset = math.random(minDistance, maxDistance)
    local coordCenter = hunter.Prey:GetCoordinate():Translate(NauticalMiles(offset), math.random(360))
    return coordCenter, radius
end

local function startPursuingAir(hunter)
    local coord0
    local wp0
    local initialHdg
    local spawn = getSpawn(hunter.Template)
    local patternCenter  , radius = getSearchPatternCenterAndRadius(hunter)
    spawn:InitSkill(hunter.Skill)
    local group
    if not hunter.StartLocation then
        -- spawn at random location 1 nm outside search pattern...
        local randomAngle = math.random(360)
        local coord0 = patternCenter:Translate(radius + NauticalMiles(1), math.random(360))
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    elseif hunter.StartLocation:IsAirbase() then
        local coordAirbase = hunter.StartLocation:GetCoordinate()
        coord0 = hunter.StartLocation:GetCoordinate()
        initialHdg = coord0:HeadingTo(patternCenter)
        group = spawn:SpawnAtAirbase(hunter.StartLocation.Source, SPAWN.Takeoff.Hot)
    elseif hunter.StartLocation:IsZone() then
        coord0 = hunter.StartLocation.Source:GetRandomPointVec2()
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    else
        local randomAngle = math.random(360)
        coord0 = hunter.Prey:GetCoordinate():Translate(radius, randomAngle)
        initialHdg = coord0:HeadingTo(patternCenter)
        spawn:InitHeading(initialHdg)
        group = spawn:SpawnFromCoordinate(coord0)
    end

    local _expandAgain
    local function expandSearchPatternWhenSearchComplete(searchPattern)
        local lastWP = searchPattern[#searchPattern]
        InsertWaypointCallback(lastWP, function() 
            Debug("DCAF.CSAR.HunterGroup :: last search waypoint reached :: expands search area")
            radius = radius + NauticalMiles(5)
            initialHdg = COORDINATE_FromWaypoint(lastWP):HeadingTo(patternCenter)
            local searchPattern = getAirSearchStarPattern(patternCenter, initialHdg, radius, hunter.Altitude, hunter.AltitudeType, hunter.Speed)
            _expandAgain(searchPattern)
            if hunter.BingoFuelState then
                testRtbCriteria(hunter, searchPattern)
            end
            group:Route(searchPattern)
            debug_drawSearchArea(hunter, patternCenter, radius)
        end)
    end
    _expandAgain = expandSearchPatternWhenSearchComplete

    local searchPattern = getAirSearchStarPattern(patternCenter, initialHdg, radius, hunter.Altitude, hunter.AltitudeType, hunter.Speed)
    local lastWP = searchPattern[#searchPattern]
    expandSearchPatternWhenSearchComplete(searchPattern)
    group:Route(searchPattern)
    debug_drawSearchArea(hunter, patternCenter, radius)
    if hunter.BingoFuelState then
        testRtbCriteria(hunter, searchPattern)
    end

    scheduleHunterDetection(hunter)

    return group
end

function DCAF.CSAR.HunterGroup:Start(speed, alt, altType)
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
        error("DCAF.CSAR.HunterGroup:Start :: invalid group type (expected helicopter, airplane or ground group): " .. self.Template)
    end
end

function DCAF.CSAR.HunterGroup:WithRTB(rtbLocation, bingoFuelState)
    local testLocation = DCAF.Location:Resolve(rtbLocation)
    if not testLocation then
        error("DCAF.CSAR.HunterGroup:WithRTB :: cannot resolve `rtbLocation` from: " .. DumpPretty(rtbLocation)) end

    if self.Group:IsAirPlane() and not rtbLocation:IsAirbase() then
        error("DCAF.CSAR.HunterGroup:WithRTB :: `rtbLocation` must be airbase") 
    end
    rtbLocation = testLocation
    if not isNumber(bingoFuelState) then
        bingoFuelState = .20
    end
    self.RtbLocation = rtbLocation
    self.BingoFuelState = bingoFuelState
    return self
end

local function landAndCapture(hunter)
    local coord = hunter.Prey:GetCoordinate(false, 1):Translate(40, math.random(360))
    local landWP = coord:WaypointAirFlyOverPoint(hunter.AltitudeType, hunter.Speed)
    local setPrey = SET_GROUP:New()
    setPrey:AddGroup(hunter.Prey.Group)
    InsertWaypointTask(landWP, hunter.Group:TaskEmbarking(coord, setPrey, math.random(120)))
    coord = coord:Translate(50, math.random(360))
    local takeOffWP = coord:WaypointAirFlyOverPoint(hunter.AltitudeType, hunter.Speed)
    local waypoints = { landWP, takeOffWP }
    InsertWaypointCallback(landWP, function() 
        if hunter.Prey.CarrierUnit then
            return end

        hunter.Prey.Group:Destroy()
        local hunterUnits = hunter.Group:GetUnits()
        hunter.Prey.CarrierUnit = listRandomItem(hunterUnits)
        Debug("CSAR :: '" .. hunter.Prey.Group.GroupName .. "' was captured by '" .. hunter.Prey.CarrierUnit.UnitName .. "'")
        hunter.CSAR:RTBHunters()
    end)
    hunter.Group:Route(waypoints)
end

function DCAF.CSAR:DirectCapableHuntersToCapture()
    local function orbitPrey(hunter)
        -- establish circling pattern over prey
Debug("DCAF.CSAR :: hunter '" .. hunter.Group.GroupName .. "' is orbiting over '" .. hunter.Prey.Group.GroupName .. "'")
        local coordPrey = hunter.Prey:GetCoordinate(false, 1)
        local speed
        if hunter.Group:IsHelicopter() then
            speed = 50
        else
            speed = hunter.Speed * .6
        end
        local orbitTask = hunter.Group:TaskOrbitCircleAtVec2(coordPrey:GetVec2(), hunter.Altitude, speed)
        local wp0 = hunter.Group:GetCoordinate():WaypointAirTurningPoint(hunter.AltitudeType, hunter.Speed)
        local wp1 = coordPrey:WaypointAirTurningPoint(hunter.AltitudeType, speed, { orbitTask })
        local waypoints = testRtbCriteria(hunter, { wp1 } )
        hunter.Group:Route(waypoints)
    end

    local countCapturing = 0
    local maxCountCapturing = math.random(#self.HunterGroups)

    local function capturePrey(hunter)
 Debug("nisse - DCAF.CSAR:DirectCapableHuntersToCapture :: hunter: " .. DumpPretty(hunter.Group.GroupName .. " is capturing..."))
        if hunter.Group:IsHelicopter() then
            countCapturing = countCapturing+1
            landAndCapture(hunter)
        elseif hunter.Group:IsGround() then
            countCapturing = countCapturing+1
            approachAndCapture()
        end
    end

    local function canCapture(hunter)
        if hunter.Group:IsHelicopter() or hunter:IsGround() then
            return hunter.CanCapture and countCapturing < maxCountCapturing
        else
            return false
        end
    end

    for _, hunter in ipairs(self.HunterGroups) do
        if canCapture(hunter) then
            capturePrey(hunter)
        else
            orbitPrey(hunter)
        end
    end
end

function DCAF.CSAR.HunterGroup:RTBNow(rtbLocation)
    rtbLocation = rtbLocation or self.RtbLocation
Debug("nisse - DCAF.CSAR:RTBHunters :: rtbLocation: " .. rtbLocation.Name)

    if rtbLocation then
        RTBNow(self.Group, rtbLocation.Source)
    end
end

function DCAF.CSAR:RTBHunters()
    for _, hunter in ipairs(self.HunterGroups) do
Debug("nisse - DCAF.CSAR:RTBHunters :: hunter: " .. hunter.Group.GroupName)
        hunter:RTBNow()
    end
end