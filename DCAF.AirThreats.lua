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

local Spawners = { -- dictionary
    -- key    = templat name
    -- value  = #SPAWN
}

local GroupState = {
    Group = nil,
    Options = {
        Distance = 60,
        MaxOffsetAngle = 60,
        Altitude = DCAF.AirThreatAltitude.Level,
        Weapons = Weapons.Realistic,
        Behavior = Behavior.Aggressive,
    },
    Randomization = nil,        -- #DCAF.AirThreats.Randomization
    Categories = { -- categorized adversaries
        -- list of #DCAF.AirThreatCategory
    },
    Adversaries = { -- non-categorized adversaries
        -- list of #AdversaryInfo
    },
    SpawnedAdversaries = {
        -- list of #GROUP
    },
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

local AdversaryInfo = {
    -- Spawner = nil,              -- #SPAWN
    Name = nil,                 -- #string (adversary display name)
    TemplateName = nil,         -- #string (adversary template name)
    Size = 0,                   -- #number (size of template)
}

function AdversaryInfo:Spawner()
    return Spawners:Get(self.TemplateName)
end

local _isBuildingGroupMenus
local _airCombatGroupMenuText

DCAF.AirThreats = {
    ClassName = "DCAF.AirThreats",
    IsStarted = false,
    IsBuildingGroupMenus = false,
    GroupMenuText = nil,
    Categories = { 
        -- list of #DCAF.AirThreatCategory
    },
    Adversaries = {
        -- list of #AdversaryInfo
    }
}

DCAF.AirThreatCategory = {
    ClassName = "DCAF.AirThreatCategory",
    Name = nil,
    Group = nil,
    Options = {
        Distance = 60,
        MaxOffsetAngle = 60,
        Altitude = DCAF.AirThreatAltitude.Level,
        Weapons = Weapons.Realistic,
        Behavior = Behavior.Aggressive,
    },
    Adversaries = {
        -- list of #BanditGroupInfo
    },
    SpawnedAdversaries = {
        -- list of #GROUP
    },
    Menus = {
        Main = nil,
        Options = nil,
        Spawn = nil
    }
}

function Spawners:Get(sTemplateName)
    local spawner = self[sTemplateName]
    if not spawner then 
        spawner = SPAWN:New(sTemplateName)
        self[sTemplateName] = spawner
    end
    return spawner
end

function DCAF.AirThreatCategory:New(sCategoryName)
    if not isAssignedString(sCategoryName) then
        error("DCAF.AirThreatCategory:New :: `sCategoryName` must be an assigned string but was: " .. DumpPretty(sCategoryName)) end
    local cat = DCAF.clone(DCAF.AirThreatCategory)
    cat.Name = sCategoryName
    return cat
end

function GroupState:New(group)
    local forGroup = getGroup(group)
    if not forGroup then
        error("GroupState:New :: cannot resolve group from: " .. DumpPretty) end

    local state = DCAF.clone(GroupState)
    state.Group = forGroup
    state.SpawnedAdversaries = {}
    state.Randomization = _airThreatRandomization
    state.Adversaries = DCAF.clone(DCAF.AirThreats.Adversaries, false, true)
    state.Categories = DCAF.clone(DCAF.AirThreats.Categories, false, true)
    for _, category in ipairs(state.Categories) do
        category.Group = state.Group
    end
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

local function getRandomOffsetAngle(maxOffsetAngle)
    if maxOffsetAngle == 0 then
        return 0
    end
    local offsetAngle = math.random(0, maxOffsetAngle)
    if offsetAngle > 0 and math.random(100) < 51 then
        offsetAngle = -offsetAngle
    end
    return offsetAngle
end

local function spawnAdversaries(info, size, source, distance, altitude, offsetAngle)
    if not isNumber(offsetAngle) then
        offsetAngle = getRandomOffsetAngle(source.Options.MaxOffsetAngle)
    end
    local angle = (source.Group:GetHeading() + offsetAngle) % 360
    if not isNumber(distance) then
        distance = NauticalMiles(source.Options.Distance)
    end
    local endCoord = source.Group:GetCoordinate()
    local startCoord = endCoord:Translate(distance, angle, true)
    if not isNumber(altitude) then
        altitude = source.Group:GetAltitude()
    end
    if source.Options.Altitude.Name ~= DCAF.AirThreatAltitude.Level.Name then
        altitude = Feet(source.Options.Altitude.MSL)
    end
    startCoord:SetAltitude(altitude)

    local spawner = info:Spawner()
    spawner:InitGroupHeading((angle - 180) % 360)
    local adversaryGroup = spawner:SpawnFromCoordinate(startCoord)
Debug("nisse - spawned group: " .. adversaryGroup.GroupName)
    table.insert(source.SpawnedAdversaries, adversaryGroup)
    local route = adversaryGroup:CopyRoute()
    local wp0 = route[1]
    local startCoord = endCoord:Translate(NauticalMiles(source.Options.Distance - 2), angle, true)
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
    applyOptions(adversaryGroup, startWP, size, source, info.Name)
    route = { startWP, endWP }
    SetRoute(adversaryGroup, route)
end

-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                        MENUS
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local _rebuildMenus
local function buildMenus(state)
    if not state.Menus.Main and isAssignedString(_airCombatGroupMenuText) then
        state.Menus.Main = MENU_GROUP:New(state.Group, _airCombatGroupMenuText)
    end

    -- Options
    local function buildOptionsMenus(source, parentMenu)
        if not source.Menus.Options then
            source.Menus.Options = MENU_GROUP:New(source.Group, "OPTIONS", parentMenu)
        else
            source.Menus.Options:RemoveSubMenus()
        end
            -- Distance
            local distanceOptionsMenu = MENU_GROUP:New(source.Group, "Distance: " .. tostring(source.Options.Distance) .. "nm", source.Menus.Options)
            for key, value in pairs(Distance) do
                MENU_GROUP_COMMAND:New(source.Group, key, distanceOptionsMenu, function()
                    source.Options.Distance = value
                    _rebuildMenus(source)
                end)
            end
            local distanceOptionsMenu = MENU_GROUP:New(source.Group, "Max offset angle: " .. Dump(source.Options.MaxOffsetAngle).."°", source.Menus.Options)
            for angle = 0, 80, 20 do
                MENU_GROUP_COMMAND:New(source.Group, Dump(angle) .. "°", distanceOptionsMenu, function()
                    source.Options.MaxOffsetAngle = angle
                    _rebuildMenus(source)
                end)
            end
            -- Altitude
            local altitudeOptionsMenu = MENU_GROUP:New(source.Group, "Altitude: " .. source.Options.Altitude.Name, source.Menus.Options)
            for key, value in pairs(DCAF.AirThreatAltitude) do
                MENU_GROUP_COMMAND:New(source.Group, key, altitudeOptionsMenu, function()
                    source.Options.Altitude = value
                    _rebuildMenus(source)
                end)
            end
            -- Weapons
            local weaponsOptionsMenu = MENU_GROUP:New(source.Group, "Weapons: " .. source.Options.Weapons, source.Menus.Options)
            for key, value in pairs(Weapons) do
                MENU_GROUP_COMMAND:New(source.Group, value, weaponsOptionsMenu, function()
                    source.Options.Weapons = value
                    _rebuildMenus(source)
                end)
            end
            -- Behavior
            local behaviorOptionsMenu = MENU_GROUP:New(source.Group, "Behavior: " .. source.Options.Behavior, source.Menus.Options)
            for key, value in pairs(Behavior) do
                MENU_GROUP_COMMAND:New(source.Group, value, behaviorOptionsMenu, function()
                    source.Options.Behavior = value
                    _rebuildMenus(source)
                end)
            end        
    end
    -- uncategorized options ...
    buildOptionsMenus(state, state.Menus.Main)

    -- Spawn: 
    if state.Menus.Spawn then 
        return end
    
    state.Menus.Spawn = MENU_GROUP:New(state.Group, "Spawn", state.Menus.Main)

    local function buildSpawnMenus(adversaries, parentMenu, source)
        local MaxAdversariesAtMenuLevel = 7
        local menuIndex = 0
        for _, info in ipairs(adversaries) do
            menuIndex = menuIndex+1
            if menuIndex > MaxAdversariesAtMenuLevel then
                -- create a 'More ...' sub menu to allow for all adversarier ...
                local clonedAdversaries = listClone(adversaries, false, menuIndex)
                local moreMenu = MENU_GROUP:New(source.Group, "More", parentMenu)
                buildSpawnMenus(clonedAdversaries, moreMenu, source)
                return
            end
            local displayName = info.Name
            local spawnMenu = MENU_GROUP:New(source.Group, displayName, parentMenu)
            for i = 1, info.Size, 1 do
                local sizeName
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
                MENU_GROUP_COMMAND:New(source.Group, sizeName, spawnMenu, function()
                    spawnAdversaries(info, i, source)
                end)
            end
        end
    end

    -- non-categories adversaries ...
    buildSpawnMenus(state.Adversaries, state.Menus.Spawn, state)

    local function despawnAll(source)
        for _, group in ipairs(source.SpawnedAdversaries) do
            group:Destroy()
        end
        source.SpawnedAdversaries = {}
    end

    -- categoried adversaries ...
    for _, category in ipairs(state.Categories) do
        local categoryMenu = MENU_GROUP:New(state.Group, category.Name, state.Menus.Main)
        buildOptionsMenus(category, categoryMenu)
        buildSpawnMenus(category.Adversaries, categoryMenu, category)
        MENU_GROUP_COMMAND:New(category.Group, "-- Despawn All --", categoryMenu, function()
            despawnAll(category)
        end)
    end

    -- Despawn:
    MENU_GROUP_COMMAND:New(state.Group, "-- Despawn All --", state.Menus.Main, function()
        despawnAll(state)
        for _, category in ipairs(state.Categories) do
            despawnAll(category)
        end
        state.SpawnedAdversaries = {}
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

local function initAdversary(object, sName, sGroup)
    -- as both #DCAF.AirThreats object and #DCAF.AirThreatCategory can init adversaries, this method allows both to do so
    local self = object
    if not isAssignedString(sName) then
        error("DCAF.AirThreats:WithBandits :: unexpected `sName`: " .. DumpPretty(sName)) end

    if tableIndexOf(self.Adversaries, function(adversary) return adversary.Name == sName end) then
        error("DCAF.AirThreats:WithBandits :: group was already added: " .. DumpPretty(sName)) end
    
    local banditGroup = getGroup(sGroup)
    if not banditGroup then
        error("DCAF.AirThreats:WithBandits :: cannot resolve group from: " .. DumpPretty(sGroup)) end

    local info = DCAF.clone(AdversaryInfo)
    info.Name = sName
    info.TemplateName = banditGroup.GroupName
    info.Size = #banditGroup:GetUnits()
    self._adversayIndex = (self._adversayIndex or 0) + 1
    table.insert(self.Adversaries, info)
    return self
end

function DCAF.AirThreats:InitAdversary(sName, sGroup) 
    return initAdversary(self, sName, sGroup)
end

function DCAF.AirThreats:InitCategory(category)
    if not isClass(category, DCAF.AirThreatCategory.ClassName) then
        error("DCAF.AirThreats:InitCategory :: expected class '" .. DCAF.AirThreatCategory.ClassName .. "' but got: " .. DumpPretty(category)) end

    table.insert(self.Categories, category)
    return self
end

function DCAF.AirThreatCategory:InitAdversary(sName, sGroup)
    self._adversayIndex = (self._adversayIndex or 0) + 1
    return initAdversary(self, sName, sGroup)
end

--------------------------------- RANDOMIZED AIR THREATS ---------------------------------

DCAF.AirThreats.Randomization = {
    ClassName = "DCAF.AirThreats.Randomization",
    -- MinInterval = 1,
    -- MaxInterval = Minutes(2),
    MinInterval = Minutes(1),
    MaxInterval = Minutes(20),
    MinSize = 1,                        -- minimum size of spawned group
    MaxSize = 4,                        -- maximum size of spawned group
    MinCount = 1,                       -- minimum number of spawned groups per event
    MaxCount = 2,                       -- maximum number of spawned groups per event
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

function DCAF.AirThreats.Randomization:WithMaxOffsetAngle(max)
    if not isNumber(max) then
        error("DCAF.AirThreats.Randomization:WithOffsetAngle :: `max` must be a number but was: " .. DumpPretty(max)) end

    self.MaxOffsetAngle = max
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
                group = DCAF.AirThreats.Adversaries[arg[i]]
            end
            if not group then
                error("DCAF.AirThreats.Randomization:WithGroups :: cannot resolve group from: " .. DumpPretty(arg[i]))  end
            table.insert(group)
        end
    end
    self.Adversaries = groups
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

        if self.RemainingEvents == 0 then
            return end

        local now = UTILS.SecondsOfToday()
        local index = math.random(1, #state.Adversaries)
        local count = math.random(self.MinCount, self.MaxCount)
        for i = 1, count, 1 do
            local distance = math.random(self.MinDistance, self.MaxDistance)
            local alt = self:GetAltitude()
            local altitude = Feet(alt.MSL)
            local size = math.random(self.MinSize, self.MaxSize)
            local info = state.Adversaries[index]
            local offsetAngle = getRandomOffsetAngle(self.MaxOffsetAngle)
            spawnAdversaries(info, size, state, distance, altitude, offsetAngle)
            index = math.random(1, #state.Adversaries)
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

--- Automatically spawns adversaries for (player) groups at random intervals as long as it is airborne
function DCAF.AirThreats:WithGroupRandomization(randomization)
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

