local Weapons = {
    Guns = "Guns only",
    Heaters = "IR missiles only",
    DogFight = "Guns + IR Missiles",
    Radar = "Radar missiles",
    Realistic = "RDR + IR + Guns"
}

local Behavior = {
    SittingDuck = "Sitting duck",
    Defensive = "Defensive",
    Aggressive = "Aggressive"
}

local Distance = {
    ["80nm"] = 80,
    ["60nm"] = 60,
    ["40nm"] = 40,
    ["30nm"] = 30,
    ["20nm"] = 20,
    ["10nm"] = 10
}

DCAF.AirThreatAltitude = {
    High = { Name = "High", MSL = 35000 },
    Medium = { Name = "Medium", MSL = 18000 },
    Level = { Name = "Level", MSL = 0 },
    Popup = { Name = "Popup", MSL = 500 },
}

local _airThreatRandomization

local GroupState = {
    Group = nil,
    Options = {
        Distance = 60,
        Altitude = DCAF.AirThreatAltitude.Level,
        Weapons = Weapons.Realistic,
        Behavior = Behavior.Aggressive,
    },
    Randomization = nil,        -- #DCAF.AirThreats.Randomization
    Spawned = {
        -- list of #GROUP
    },
    BanditGroups = { -- dictionary
        -- key = display name
        -- value = #BanditGroupInfo
    },
    CountBanditGroups = 0,
    Menus = {
        Main = nil,
        Options = nil,
        Spawn = nil
    }
}

local GroupStateDict = { -- dictionary
    -- key = group name
    -- value = #GroupState
}

local BanditGroupInfo = {
    Spawner = nil,              -- #SPAWN
    Size = 0,                   -- #number (size of template)
}

local _isBuildingGroupMenus
local _airCombatGroupMenuText

DCAF.AirThreats = {
    IsStarted = false,
    IsBuildingGroupMenus = false,
    GroupMenuText = nil,
    BanditGroups = { -- dictionary
        -- key = display name
        -- value = #BanditGroupInfo
    }
}

function GroupState:New(group)
    local forGroup = getGroup(group)
    if not forGroup then
        error("GroupState:New :: cannot resolve group from: " .. DumpPretty) end

    local state = DCAF.clone(GroupState)
    state.Group = forGroup
    state.Spawned = {}
    state.Randomization = _airThreatRandomization
    state.BanditGroups = DCAF.clone(DCAF.AirThreats.BanditGroups, false, true)
    state.CountBanditGroups = dictCount(state.BanditGroups)
    GroupStateDict[forGroup.GroupName] = state
    return state
end

local function applyOptions(banditGroup, waypoint, size, state, banditDisplayName)
    -- size
    local units = banditGroup:GetUnits()
    if #units > size then
        for i = size+1, #units, 1 do
            units[i]:Destroy()
        end
    end

    banditGroup:ClearTasks()
    local task 
    if state.Options.Behavior == Behavior.Aggressive then
        if isAssignedString(banditDisplayName) then
            MessageTo(state.Group, Dump(size) .. " x " .. banditDisplayName .. " attacks " .. state.Group.GroupName)
        end
        task = banditGroup:TaskAttackGroup(state.Group)
    elseif state.Options.Behavior == Behavior.Defensive then
        if isAssignedString(banditDisplayName) then
            MessageTo(state.Group, Dump(size) .. " x " .. banditDisplayName .. " is defensive")
        end
        ROEDefensive(banditGroup)
    elseif state.Options.Behavior == Behavior.SittingDuck then
        if isAssignedString(banditDisplayName) then
            MessageTo(state.Group, Dump(size) .. " x " .. banditDisplayName .. " is sitting ducks")
        end
        ROEHoldFire(banditGroup)
        banditGroup:OptionROTNoReaction()
    else
        error("applyOptions :: unsupported behavior: " .. DumpPretty(state.Options.Behavior))
    end
    if task then
        if #task > 0 then
            waypoint.task = banditGroup:TaskCombo(task)
        else
            waypoint.task = banditGroup:TaskCombo({ task })
        end    
    end
end

local function spawnBandits(info, size, state, banditDisplayName, distance, altitude, offsetAngle)
    if not isNumber(offsetAngle) then
        offsetAngle = 0 
    end
    local blueHeading = state.Group:GetHeading() + offsetAngle
    if not isNumber(distance) then
        distance = NauticalMiles(state.Options.Distance)
    end
    local endCoord = state.Group:GetCoordinate()
    local startCoord = endCoord:Translate(distance, blueHeading, true)
    if not isNumber(altitude) then
        altitude = state.Group:GetAltitude()
    end
    if state.Options.Altitude.Name ~= DCAF.AirThreatAltitude.Level.Name then
        altitude = Feet(state.Options.Altitude.MSL)
    end
    startCoord:SetAltitude(altitude)

    info.Spawner:InitGroupHeading((blueHeading - 180) % 360)
    local banditGroup = info.Spawner:SpawnFromCoordinate(startCoord)
    table.insert(state.Spawned, banditGroup)
    local route = banditGroup:CopyRoute()
    local wp0 = route[1]
    local startCoord = endCoord:Translate(NauticalMiles(state.Options.Distance - 2), blueHeading, true)
    local startWP = startCoord:WaypointAir(
        COORDINATE.WaypointAltType.BARO,
        COORDINATE.WaypointType.TurningPoint,
        COORDINATE.WaypointAction.TurningPoint,
        wp0.Speed)
    local endWP = endCoord:WaypointAir(
        COORDINATE.WaypointAltType.BARO,
        COORDINATE.WaypointType.TurningPoint,
        COORDINATE.WaypointAction.TurningPoint,
        wp0.Speed)
    applyOptions(banditGroup, startWP, size, state, banditDisplayName)
    route = { startWP, endWP }
    SetRoute(banditGroup, route)
end

local _rebuildMenus
local function buildMenus(state)
    if not state.Menus.Main and isAssignedString(_airCombatGroupMenuText) then
        state.Menus.Main = MENU_GROUP:New(state.Group, _airCombatGroupMenuText)
    end

    -- Options
    if not state.Menus.Options then
        state.Menus.Options = MENU_GROUP:New(state.Group, "Options", state.Menus.Main)
    else
        state.Menus.Options:RemoveSubMenus()
    end
        -- Distance
        local distanceOptionsMenu = MENU_GROUP:New(state.Group, "Distance: " .. tostring(state.Options.Distance) .. "nm", state.Menus.Options)
        for key, value in pairs(Distance) do
            MENU_GROUP_COMMAND:New(state.Group, key, distanceOptionsMenu, function()
                state.Options.Distance = value
                _rebuildMenus(state)
            end)
        end
        -- Altitude
        local altitudeOptionsMenu = MENU_GROUP:New(state.Group, "Altitude: " .. state.Options.Altitude.Name, state.Menus.Options)
        for key, value in pairs(DCAF.AirThreatAltitude) do
            MENU_GROUP_COMMAND:New(state.Group, key, altitudeOptionsMenu, function()
                state.Options.Altitude = value
                _rebuildMenus(state)
            end)
        end
        -- Weapons
        local weaponsOptionsMenu = MENU_GROUP:New(state.Group, "Weapons: " .. state.Options.Weapons, state.Menus.Options)
        for key, value in pairs(Weapons) do
            MENU_GROUP_COMMAND:New(state.Group, value, weaponsOptionsMenu, function()
                state.Options.Weapons = value
                _rebuildMenus(state)
            end)
        end
        -- Behavior
        local behaviorOptionsMenu = MENU_GROUP:New(state.Group, "Behavior: " .. state.Options.Behavior, state.Menus.Options)
        for key, value in pairs(Behavior) do
            MENU_GROUP_COMMAND:New(state.Group, value, behaviorOptionsMenu, function()
                state.Options.Behavior = value
                _rebuildMenus(state)
            end)
        end

    -- Options End

    -- Spawn: 
    if state.Menus.Spawn then 
        return end
    
    state.Menus.Spawn = MENU_GROUP:New(state.Group, "Spawn", state.Menus.Main)
    for displayName, info in pairs(state.BanditGroups) do
        local sizeName
        local spawnGroupMenu = MENU_GROUP:New(state.Group, displayName, state.Menus.Spawn)
        for i = 1, info.Size, 1 do
            if i == 1 then
                sizeName = "Singleton"
            elseif i == 2 then
                sizeName = "Pair"
            elseif i == 3 then
                sizeName = "Threeship"
            elseif i == 4 then
                sizeName = "Fourship"
            else
                sizeName = tostring(i)
            end
            MENU_GROUP_COMMAND:New(state.Group, sizeName, spawnGroupMenu, function()
                spawnBandits(info, i, state, displayName)
            end)
        end
    end

    -- Despawn:
    MENU_GROUP_COMMAND:New(state.Group, "Despawn all", state.Menus.Main, function()
        for _, banditGroup in pairs(state.Spawned) do
            banditGroup:Destroy()
        end
        state.Spawned = {}
    end)

end
_rebuildMenus = buildMenus

local function onPlayerEnteredAirplane(event)
    local state = GroupStateDict[event.IniGroupName]
    if not state then
        state = GroupState:New(event.IniGroupName)
        if _isBuildingGroupMenus then
            buildMenus(state)
        end
        if state.Randomization then
            state.Randomization:StartForGroupState(state)
        end
    end
end

function DCAF.AirThreats:WithGroupMenus(menuText)
    _isBuildingGroupMenus = true
    _airCombatGroupMenuText = menuText
    return self
end


function DCAF.AirThreats:WithBanditGroup(sName, sGroup) 
    if not isAssignedString(sName) then
        error("DCAF.AirThreats:WithBandits :: unexpected `sName`: " .. DumpPretty(sName)) end

    if DCAF.AirThreats.BanditGroups[sName] then
        error("DCAF.AirThreats:WithBandits :: group was already added: " .. DumpPretty(sName)) end
    
    local banditGroup = getGroup(sGroup)
    if not banditGroup then
        error("DCAF.AirThreats:WithBandits :: cannot resolve group from: " .. DumpPretty(sGroup)) end

    local info = DCAF.clone(BanditGroupInfo)
    info.Size = #banditGroup:GetUnits()
    info.Spawner = SPAWN:New(banditGroup.GroupName)
    DCAF.AirThreats.BanditGroups[sName] = info
    return self
end

--------------------------------- RANDOMIZED AIR THREATS ---------------------------------

DCAF.AirThreats.Randomization = {
    ClassName = "DCAF.AirThreats.Randomization",
    MinInterval = 1,
    MaxInterval = Minutes(2),
    -- MinInterval = Minutes(1),
    -- MaxInterval = Minutes(20),
    MinSize = 1,                        -- minimum size of spawned group
    MaxSize = 4,                        -- maximum size of spawned group
    MinCount = 1,                       -- minimum number of spawned groups per event
    MaxCount = 3,                       -- maximum number of spawned groups per event
    Altitudes = {
        DCAF.AirThreatAltitude.High,
        DCAF.AirThreatAltitude.Medium,
        DCAF.AirThreatAltitude.Level,
        DCAF.AirThreatAltitude.Popup
    },
    -- MinAltitude = Feet(Altitude.Popup.MSL), obsolete
    -- MaxAltitude = Feet(Altitude.High.MSL),
    MinDistance = NauticalMiles(40),
    MaxDistance = NauticalMiles(160),
    MinOffsetAngle = 0,
    MaxOffsetAngle = 60,
    MaxEvents = 5,
    RemainingEvents = 5,
}

function DCAF.AirThreats.Randomization:New()
    return DCAF.clone(DCAF.AirThreats.Randomization)
end

function DCAF.AirThreats.Randomization:WithDistance(min, max)
    if not isNumber(min) then
        error("DCAF.AirThreats.Randomization:WithDistance :: `min` must be a number but was: " .. DumpPretty(min)) end

    self.MinDistance = min
    if isNumber(max) then
        self.MaxDistance = max
    else
        self.MaxDistance = self.MaxDistance or min
    end
    if self.MinDistance > self.MaxDistance then
        self.MinDistance, self.MaxDistance = swap(self.MinDistance, self.MaxDistance)
    end
    return self
end

function DCAF.AirThreats.Randomization:WithOffsetAngle(min, max)
    if not isNumber(min) then
        error("DCAF.AirThreats.Randomization:WithOffsetAngle :: `min` must be a number but was: " .. DumpPretty(min)) end

    self.MinOffsetAngle = min
    if isNumber(max) then
        self.MaxOffsetAngle = max
    else
        self.MaxOffsetAngle = self.MaxOffsetAngle or min
    end
    if self.MinOffsetAngle > self.MaxOffsetAngle then
        self.MinOffsetAngle, self.MaxOffsetAngle = swap(self.MinOffsetAngle, self.MaxOffsetAngle)
    end
    return self
end

function DCAF.AirThreats.Randomization:WithAltitudes(...)
    if #arg == 0 then
        error("DCAF.AirThreats.Randomization:WithAltitude :: expected at least one altitude value") end

    -- validate args
    local altitudes = {}
    for i = 1, #arg, 1 do
        local alt = arg[i]
        if not isTable(alt) or not isAssignedString(alt.Name) or not isNumber(alt.MSL) then
            error("DCAF.AirThreats.Randomization:WithAltitude :: unexpcted altitude value #" .. Dump(i) .. ": " .. DumpPretty(alt)) end 
    end

    self.Altitudes = altitudes
    return self
end

function DCAF.AirThreats.Randomization:GetAltitude()
    local index = math.random(1, #self.Altitudes)
    return self.Altitudes[index]
end

function DCAF.AirThreats.Randomization:WithInterval(min, max)
    if not isNumber(min) then
        error("DCAF.AirThreats.Randomization:WithInterval :: `min` must be a number but was: " .. DumpPretty(min)) end

    self.MinInterval = min
    if isNumber(max) then
        self.MaxInterval = min
    else
        self.MaxInterval = self.MaxInterval or min
    end
    if self.MinInterval > self.MaxInterval then
        self.MinInterval, self.MaxInterval = swap(self.MinInterval, self.MaxInterval)
    end
    return self
end

function DCAF.AirThreats.Randomization:WithMaxEvents(maxEvents)
    if not isNumber(maxEvents) then
        error("DCAF.AirThreats.Randomization:WithMaxEvents :: `countEvents` must be a number but was: " .. DumpPretty(maxEvents)) end

    self.MaxEvents = maxEvents
    self.RemainingEvents = maxEvents
    return self
end

function DCAF.AirThreats.Randomization:WithGroups(...)
    if #arg == 0 then
        error("DCAF.AirThreats.Randomization:WithGroups :: expected at least one group") end

    -- validate
    local groups = {}
    for i = 1, #arg, 1 do
        local group = getGroup(arg[i])
        if not group then
            if isAssignedString(arg[i]) then
                group = DCAF.AirThreats.BanditGroups[arg[i]]
            end
            if not group then
                error("DCAF.AirThreats.Randomization:WithGroups :: cannot resolve group from: " .. DumpPretty(arg[i]))  end
            table.insert(group)
        end
    end
    self.BanditGroups = groups
    return self
end

function DCAF.AirThreats.Randomization:StartForGroupState(state)
    local function stopTimer()
        Delay(2, function() 
            if self.Timer and self.Timer:IsRunning() then
                self.Timer:Stop()
                self.Timer = nil
            end
        end)
    end

    local function getNextEventTime()
        local timeToNext = math.random(self.MinInterval, self.MaxInterval)
Debug("nisse - air threat randomize :: next event: " .. UTILS.SecondsToClock(timeToNext + UTILS.SecondsOfToday()) )
        return timeToNext
    end

    local randomizeFunc
    local function randomize()
        local units = state.Group:GetUnits()
        if not state.Group:IsAlive() or units == nil or #units == 0 then
            return end

        if not state.Group:InAir() then
            -- we only spawn random threats if group is airborne
            if now >= self.NextEventTime then
                self.Timer = TIMER:New(randomizeFunc):Start(getNextEventTime())
            end
            return
        end

        local now = UTILS.SecondsOfToday()
        local key = dictRandomKey(state.BanditGroups, state.CountBanditGroups)
        if not key or self.RemainingEvents == 0 then
            return end

        local count = math.random(self.MinCount, self.MaxCount)
        for i = 1, count, 1 do
            local distance = math.random(self.MinDistance, self.MaxDistance)
            local alt = self:GetAltitude()
            local altitude = Feet(alt.MSL)
            local size = math.random(self.MinSize, self.MaxSize)
            local info = state.BanditGroups[key]
            local offsetAngle = math.random(self.MinOffsetAngle, self.MaxOffsetAngle)
            if offsetAngle > 0 and math.random(100) < 50 then
                offsetAngle = -offsetAngle
            end
            spawnBandits(info, size, state, key, distance, altitude, offsetAngle)
            key = dictRandomKey(state.BanditGroups, state.CountBanditGroups)
        end
        self.RemainingEvents = self.RemainingEvents-1             
        if self.RemainingEvents == 0 then
            return 
        else
            self.Timer = TIMER:New(randomizeFunc):Start(getNextEventTime())
        end
    end
    randomizeFunc = randomize

    if self.Timer then
        stopTimer()
    end
    self.Timer = TIMER:New(randomizeFunc):Start(getNextEventTime())
    return self

end

function DCAF.AirThreats:WithRandomization(randomization)
    if randomization == nil then
        randomization = DCAF.AirThreats.Randomization:New()
    end
    if not isClass(randomization, "DCAF.AirThreats.Randomization") then
        error("DCAF.AirThreats:WithRandomization :: `randomization` is of unexpected value: " .. DumpPretty(randomization)) end

    _airThreatRandomization = randomization
    return self
end

function DCAF.AirThreats:Start()
    if DCAF.AirThreats.IsStarted then
        return end

    DCAF.AirThreats.IsStarted = true
    _airCombatGroupMenuText = menuText
    MissionEvents:OnPlayerEnteredAirplane(onPlayerEnteredAirplane)
    return self
end

