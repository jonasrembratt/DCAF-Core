local Weapons = {
    Guns = "Guns only",
    Heaters = "IR missiles only",
    DogFight = "Guns + IR Missiles",
    Radar = "Radar missiles",
    Realistic = "RDR + IR + Guns"
}

DCAF.AirBehavior = {
    Passive = "Passive",
    Defensive = "Defensive",
    Attack = "Attack",
}

local Distance = {
    ["80nm"] = 80,
    ["60nm"] = 60,
    ["40nm"] = 40,
    ["20nm"] = 20,
    ["10nm"] = 10,
    ["2nm"] = 2,
    ["1000ft"] = 0.17,
}

DCAF.AirAltitude = {
    High = { Name = "High", MSL = 35000 },
    Medium = { Name = "Medium", MSL = 18000 },
    Level = { Name = "Level", MSL = 0 },
    Popup = { Name = "Popup", MSL = 500 },
}

DCAF.AirPosition = {
    Ahead = "12 o'clock",
    Behind = "6 o'clock",
    Left = "9 o'clock",
    Right = "3 o'clock",
}

DCAF.AirAspect = {
    Hot = "Hot",
    Cold = "Cold",
    FlankingRight = "Flanking Right",
    FlankingLeft = "Flanking Left",
}

local _airThreatRandomization

local Spawners = { -- dictionary
    -- key    = templat name
    -- value  = #SPAWN
}

local GroupState = {
    Group = nil,
    Options = nil,
    Randomization = nil,        -- #DCAF.Air.Randomization
    Categories = { -- categorized adversaries
        -- list of #DCAF.AirCategory
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

local AirGroupInfo = {
    -- Spawner = nil,              -- #SPAWN
    Name = nil,                 -- #string (adversary display name)
    TemplateName = nil,         -- #string (adversary template name)
    Size = 0,                   -- #number (size of template)
}

function AirGroupInfo:Spawner()
    return Spawners:Get(self.TemplateName)
end

local _isBuildingGroupMenus
local _groupMenusGroup                  -- when set; this group is the only one that gets menus
local _airCombatGroupMenuText

local function isSpecifiedGroupForMenus(groupName)
    return _groupMenusGroup == nil or _groupMenusGroup == groupName
end

DCAF.Air = {
    ClassName = "DCAF.Air",
    IsStarted = false,
    IsBuildingGroupMenus = false,
    GroupMenuText = nil,
    Categories = { 
        -- list of #DCAF.AirCategory
    },
    Adversaries = {
        -- list of #GroupInfo
    }
}

DCAF.AirCategory = {
    ClassName = "DCAF.AirCategory",
    Name = nil,
    Group = nil,
    Options = nil,
    Adversaries = {
        -- list of #GroupInfo
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

DCAF.Airbase = {
    ClassName = "DCAF.Airbase",
    Name = nil,
    Group = nil,
    Options = nil,
    Adversaries = {
        -- list of #GroupInfo
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

DCAF.AirOptions = {
    ClassName = "DCAF.AirOptions",
    _fallback = nil,                -- #DCAF.AirOptions
    _distance = nil,                -- #number (nautical miles)
    _position = nil,                -- #DCAF.AirPosition
    _aspect = nil,                  -- #DCAF.AirAspect
    _maxOffsetAngle = nil,          -- #number (degrees)
    _altitude = nil,                -- #DCAF.AirAltitude
    _behavior = nil,                -- #DCAF.AirBehavior
}

function Spawners:Get(sTemplateName)
    local spawner = self[sTemplateName]
    if not spawner then 
        spawner = SPAWN:New(sTemplateName)
        self[sTemplateName] = spawner
    end
    return spawner
end

function DCAF.AirOptions:New(fallback)
    local options = DCAF.clone(DCAF.AirOptions)
    options._fallback = fallback or {}
    return options
end

function DCAF.AirOptions:Default()
    local options = DCAF.AirOptions:New()
    options._distance = 60
    options._position = DCAF.AirPosition.Ahead
    options._aspect = DCAF.AirAspect.Hot
    options._maxOffsetAngle = 60
    options._altitude = DCAF.AirAltitude.Level
    options._behavior = DCAF.AirBehavior.Attack
    return options
end

function DCAF.AirOptions:Reset()
    self._distance = nil
    self._position = nil
    self._aspect = nil
    self._altitude = nil
    self._maxOffsetAngle = nil
    self._behavior = nil
    return self
end

function DCAF.AirOptions:GetDistance()
    return self._distance or self._fallback._distance or 60, self._distance == nil and self._fallback._distance ~= nil
end
function DCAF.AirOptions:SetDistance(value)
    self._distance = value
    return self
end

function DCAF.AirOptions:GetPosition()
    return self._position or self._fallback._position or DCAF.AirPosition.Ahead, self._position == nil and self._fallback._position ~= nil
end
function DCAF.AirOptions:SetPosition(value)
    self._position = value
    return self
end

function DCAF.AirOptions:GetAspect()
    return self._aspect or self._fallback._aspect or DCAF.AirAspect.Hot, self._aspect == nil and self._fallback._aspect ~= nil
end
function DCAF.AirOptions:SetAspect(value)
    self._aspect = value
    return self
end

function DCAF.AirOptions:GetMaxOffsetAngle()
    return self._maxOffsetAngle or self._fallback._maxOffsetAngle or 60, self._maxOffsetAngle == nil and self._fallback._maxOffsetAngle ~= nil
end
function DCAF.AirOptions:SetMaxOffsetAngle(value)
    self._maxOffsetAngle = value
    return self
end

function DCAF.AirOptions:GetAltitude()
    return self._altitude or self._fallback._altitude or DCAF.AirAltitude.Level, self._altitude == nil and self._fallback._altitude ~= nil
end
function DCAF.AirOptions:SetAltitude(value)
    self._altitude = value
    return self
end

function DCAF.AirOptions:GetBehavior()
    return self._behavior or self._fallback._behavior or DCAF.AirBehavior.Attack, self._behavior == nil and self._fallback._behavior ~= nil
end
function DCAF.AirOptions:SetBehavior(value)
    self._behavior = value
    return self
end


function DCAF.AirCategory:New(sCategoryName)
    if not isAssignedString(sCategoryName) then
        error("DCAF.AirCategory:New :: `sCategoryName` must be an assigned string but was: " .. DumpPretty(sCategoryName)) end
    local cat = DCAF.clone(DCAF.AirCategory)
    cat.Name = sCategoryName
    return cat
end

function DCAF.AirCategory:WithOptions(options)
    if not isClass(options, DCAF.AirOptions.ClassName) then
        error("DCAF.AirCategory:InitOptions :: expected type '"..DCAF.AirOptions.ClassName.."' but got: " .. DumpPretty(options)) end

    self.Options = options
    return self
end

function GroupState:New(group)
    local forGroup = getGroup(group)
    if not forGroup then
        error("GroupState:New :: cannot resolve group from: " .. DumpPretty) end

    local state = DCAF.clone(GroupState)
    state.Group = forGroup
    state.Options = DCAF.AirOptions:Default()
    state.SpawnedAdversaries = {}
    state.Randomization = _airThreatRandomization
    state.Adversaries = DCAF.clone(DCAF.Air.Adversaries, false, true)
    state.Categories = DCAF.clone(DCAF.Air.Categories, true, true)
    for _, category in ipairs(state.Categories) do
        category.Group = state.Group
        if category.Options == nil then
            category.Options = DCAF.AirOptions:New(state.Options)
        else
            category.Options._fallback = state.Options
        end
    end
    GroupStateDict[forGroup.GroupName] = state
    return state
end

local function applyOptions(adversaryGroup, waypoint, size, source, adversaryDisplayName)
    -- size
    local units = adversaryGroup:GetUnits()
    if #units > size then
        for i = size+1, #units, 1 do
            units[i]:Destroy()
        end
    end

    adversaryGroup:ClearTasks()
    local task 
    local behavior = source.Options:GetBehavior()
    if behavior == DCAF.AirBehavior.Attack then
        if source.Group:IsAir() then
            task = adversaryGroup:TaskAttackGroup(source.Group)
            if isAssignedString(adversaryDisplayName) then
                MessageTo(source.Group, Dump(size) .. " x " .. adversaryDisplayName .. " attacks " .. source.Group.GroupName)
            end
        else
            task = adversaryGroup:EnRouteTaskEngageTargets()
            if isAssignedString(adversaryDisplayName) then
                MessageTo(source.Group, Dump(size) .. " x " .. adversaryDisplayName .. " searches/engages in area")
            end
        end
    elseif behavior == DCAF.AirBehavior.Defensive then
        if isAssignedString(adversaryDisplayName) then
            MessageTo(source.Group, Dump(size) .. " x " .. adversaryDisplayName .. " is defensive")
        end
        ROEDefensive(adversaryGroup)
    elseif behavior == DCAF.AirBehavior.Passive then
        if isAssignedString(adversaryDisplayName) then
            MessageTo(source.Group, Dump(size) .. " x " .. adversaryDisplayName .. " is passive")
        end
        ROEHoldFire(adversaryGroup)
        adversaryGroup:OptionROTNoReaction()
    else
        error("applyOptions :: unsupported behavior: " .. DumpPretty(behavior))
    end

    local function applyToWaypoint(wp)
        if #task > 0 then
            wp.task = adversaryGroup:TaskCombo(task)
        else
            wp.task = adversaryGroup:TaskCombo({ task })
        end    
    end

    if task then
        if isTable(waypoint) then
            for _, wp in ipairs(waypoint) do
                applyToWaypoint(wp)
            end
        else
            applyToWaypoint(waypoint)
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

local function getCoordsAndheading(source, distance, position, offsetAngle, aspect)
    local behavior = source.Options:GetBehavior()
    local angle = (source.Group:GetHeading() + offsetAngle) % 360
    local groupCoord = source.Group:GetCoordinate()
    
    local spawnCoord 
    if position == DCAF.AirPosition.Ahead then
        spawnCoord = groupCoord:Translate(distance, angle, true)
    elseif position == DCAF.AirPosition.Right then
        angle = (angle + 90) % 360
    elseif position == DCAF.AirPosition.Behind then
        angle = (angle + 180) % 360
    elseif position == DCAF.AirPosition.Left then
        angle = (angle + 270) % 360
    else
        error("buildRoute_getStartCoord :: unsupported DCAF.AirPosition: " .. Dump(position))
    end
    spawnCoord =  groupCoord:Translate(distance, angle, true)

    local taskCoord
    local endCoord
    local heading 
    local routeLength = 200

    if aspect == DCAF.AirAspect.Hot then
        routeLength = distance + 20
        heading = (angle + 180) % 360
    elseif aspect == DCAF.AirAspect.Cold then
        heading = angle
    elseif aspect == DCAF.AirAspect.FlankingLeft then
        -- todo Do we need to re-route an aggressive AI here (more WPs) or will it turn towards Group?
        heading = (angle + 270) % 360
    elseif aspect == DCAF.AirAspect.FlankingRight then
        -- todo Do we need to re-route an aggressive AI here (more WPs) or will it turn towards Group?
        heading = (angle + 90) % 360
    end

    taskCoord = spawnCoord:Translate(NauticalMiles(0.2), heading, true)
    endCoord = groupCoord:Translate(NauticalMiles(routeLength), heading, true)
    return { Spawn = spawnCoord, Task = taskCoord, End = endCoord }, heading
end

local function spawnGroup(info, size, source, distance, altitude, position, offsetAngle, aspect)
    if not isNumber(offsetAngle) then
        offsetAngle = getRandomOffsetAngle(source.Options:GetMaxOffsetAngle())
    end
    if not isNumber(distance) then
        distance = NauticalMiles(source.Options:GetDistance())
    end
    if not position then
        position = source.Options:GetPosition()
    end
    if not aspect then
        aspect = source.Options:GetAspect()
    end

    -- route coordinates ...
    local coords, heading = getCoordsAndheading(source, distance, position, offsetAngle, aspect)
    local spawnCoord = coords.Spawn
    local taskCoord = coords.Task
    local endCoord = coords.End

    -- altitude ...
    if not isNumber(altitude) then
        altitude = source.Options:GetAltitude()
        local variation = 0
        if altitude.Name == DCAF.AirAltitude.High.Name then
            variation = math.random(0, 5) * 1000
            altitude = Feet(altitude.MSL - variation)
        elseif altitude.Name == DCAF.AirAltitude.Level.Name then
            local nmDistance = UTILS.MetersToNM(distance)
            if nmDistance >= 10 then
                variation = math.random(0, 4) * 1000
                if math.random(100) < 50 then
                    variation = -variation
                end
            elseif nmDistance >= 2 then
                variation = math.random(0, 4) * 1000
                if math.random(100) < 50 then
                    variation = -variation
                end
            elseif nmDistance >= 1 then
                variation = math.random(0, 500)
                if math.random(100) < 50 then
                    variation = -variation
                end
            end
            altitude = source.Group:GetAltitude() + Feet(variation)
        else
            variation = math.random(0, 5) * 1000
            if math.random(100) < 50 then
                variation = -variation
            end
            altitude = math.max(Feet(300), Feet(altitude.MSL + variation))

        end
    end
    spawnCoord:SetAltitude(altitude)

    -- spawn and set route ...
    local spawner = info:Spawner()
    spawner:InitGroupHeading(heading)
    local group = spawner:SpawnFromCoordinate(spawnCoord)
    table.insert(source.SpawnedAdversaries, group)
    local route = group:CopyRoute()
    local wp0 = route[1]

    local taskWP = taskCoord:WaypointAir(
        COORDINATE.WaypointAltType.BARO,
        COORDINATE.WaypointType.TurningPoint,
        COORDINATE.WaypointAction.TurningPoint,
        wp0.Speed)
    local endWP = endCoord:WaypointAir(
        COORDINATE.WaypointAltType.BARO,
        COORDINATE.WaypointType.TurningPoint,
        COORDINATE.WaypointAction.TurningPoint,
        wp0.Speed)
    applyOptions(group, {taskWP, endWP}, size, source, info.Name)
    route = { taskWP, endWP }
    SetRoute(group, route)
end



-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                        MENUS
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

        local function displayValue(value, suffix, isFallback)
            if isFallback then
                return '[' .. Dump(value) .. (suffix or '') .. ']'
            else
                return Dump(value) .. suffix or ''
            end
        end

        -- Reset All Options
        MENU_GROUP_COMMAND:New(source.Group, "-- RESET --", source.Menus.Options, function()
            source.Options:Reset()
            buildOptionsMenus(source, parentMenu)
        end)
        
        -- Distance
        local distance, isFallback = source.Options:GetDistance()
        local distanceOptionsMenu = MENU_GROUP:New(source.Group, "Distance: " .. displayValue(distance, 'nm', isFallback), source.Menus.Options)
        for key, value in pairs(Distance) do
            MENU_GROUP_COMMAND:New(source.Group, key, distanceOptionsMenu, function()
                source.Options:SetDistance(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Position ...
        local position, isFallback = source.Options:GetPosition()
        local positionOptionsMenu = MENU_GROUP:New(source.Group, "Position: " .. displayValue(position, '', isFallback), source.Menus.Options)
        for k, value in pairs(DCAF.AirPosition) do
            MENU_GROUP_COMMAND:New(source.Group, Dump(value), positionOptionsMenu, function()
                source.Options:SetPosition(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Aspect ...
        local aspect, isFallback = source.Options:GetAspect()
        local aspectOptionsMenu = MENU_GROUP:New(source.Group, "Aspect: " .. displayValue(aspect, '', isFallback), source.Menus.Options)
        for k, value in pairs(DCAF.AirAspect) do
            MENU_GROUP_COMMAND:New(source.Group, Dump(value), aspectOptionsMenu, function()
                source.Options:SetAspect(value)
                buildOptionsMenus(source, parentMenu)
                -- _rebuildMenus(source)
            end)
        end

        -- Max Offset Angle ...
        local maxOffsetAngle, isFallback = source.Options:GetMaxOffsetAngle()
        local maxOffsetAngleMenu = MENU_GROUP:New(source.Group, "Max offset angle: " .. displayValue(maxOffsetAngle, '°', isFallback), source.Menus.Options)
        for angle = 0, 80, 20 do
            MENU_GROUP_COMMAND:New(source.Group, Dump(angle) .. "°", maxOffsetAngleMenu, function()
                source.Options:SetMaxOffsetAngle(angle)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Altitude
        local altitude, isFallback = source.Options:GetAltitude()
        local altitudeOptionsMenu = MENU_GROUP:New(source.Group, "Altitude: " .. displayValue(source.Options:GetAltitude().Name, '', isFallback), source.Menus.Options)
        for key, value in pairs(DCAF.AirAltitude) do
            MENU_GROUP_COMMAND:New(source.Group, key, altitudeOptionsMenu, function()
                source.Options:SetAltitude(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

        -- Behavior
        local behavior, isFallback = source.Options:GetBehavior()
        local behaviorOptionsMenu = MENU_GROUP:New(source.Group, "Behavior: " .. displayValue(behavior, '', isFallback), source.Menus.Options)
        for key, value in pairs(DCAF.AirBehavior) do
            MENU_GROUP_COMMAND:New(source.Group, value, behaviorOptionsMenu, function()
                source.Options:SetBehavior(value)
                buildOptionsMenus(source, parentMenu)
            end)
        end

    end
    -- uncategorized options ...
    buildOptionsMenus(state, state.Menus.Main)

    -- Spawn: 
    if state.Menus.Spawn then 
        return end
    
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
                    spawnGroup(info, i, source)
                end)
            end
        end
    end

    -- non-categories adversaries ...
    if #state.Adversaries > 0 then
        state.Menus.Spawn = MENU_GROUP:New(state.Group, "Spawn", state.Menus.Main)
        buildSpawnMenus(state.Adversaries, state.Menus.Spawn, state)
    end

    local function despawnAll(source)
        for _, group in ipairs(source.SpawnedAdversaries) do
            group:Destroy()
        end
        source.SpawnedAdversaries = {}
    end

    -- categorised adversaries ...
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

local function onPlayerEnteredUnit(event)
    local state = GroupStateDict[event.IniGroupName]
    if state or not isSpecifiedGroupForMenus(event.IniGroupName) then 
        return end

    state = GroupState:New(event.IniGroupName)
    if _isBuildingGroupMenus then
        buildMenus(state)
    end
    if state.Randomization then
        state.Randomization:StartForGroupState(state)
    end

end

function DCAF.Air:WithGroupMenus(sMenuText, sGroup)
    _isBuildingGroupMenus = true
    _groupMenusGroup = sGroup
    _airCombatGroupMenuText = sMenuText
    return self
end

local function initGroup(object, sName, sGroup, nSize)
    -- as both #DCAF.Air object and #DCAF.AirCategory can init groups, this method allows both to do so
    local self = object
    if not isAssignedString(sName) then
        error("DCAF.Air:InitGroup :: unexpected `sName`: " .. DumpPretty(sName)) end

    if tableIndexOf(self.Adversaries, function(adversary) return adversary.Name == sName end) then
        error("DCAF.Air:InitGroup :: group was already added: " .. DumpPretty(sName)) end
    
    local adversadyGroup = getGroup(sGroup)
    if not adversadyGroup then
        error("DCAF.Air:InitGroup :: cannot resolve group from: " .. DumpPretty(sGroup)) end

    local info = DCAF.clone(AirGroupInfo)
    info.Name = sName
    info.TemplateName = adversadyGroup.GroupName
    if isNumber(nSize) then
        info.Size = math.min(4, math.max(1, math.abs(nSize))) -- max size is 4 (DCS limitation)
    else
        info.Size = #adversadyGroup:GetUnits()
    end
    table.insert(self.Adversaries, info)
    return self
end

function DCAF.Air:InitGroup(sName, sGroup, nSize) 
    return initGroup(self, sName, sGroup, nSize)
end

function DCAF.Air:InitCategory(category)
    if not isClass(category, DCAF.AirCategory.ClassName) then
        error("DCAF.Air:InitCategory :: expected class '" .. DCAF.AirCategory.ClassName .. "' but got: " .. DumpPretty(category)) end

    table.insert(self.Categories, category)
    return self
end

function DCAF.AirCategory:WithGroup(sName, sGroup, nSize)
    self._adversayIndex = (self._adversayIndex or 0) + 1
    return initGroup(self, sName, sGroup, nSize)
end

--------------------------------- RANDOMIZED AIR THREATS ---------------------------------

DCAF.Air.Randomization = {
    ClassName = "DCAF.Air.Randomization",
    -- MinInterval = 1,
    -- MaxInterval = Minutes(2),
    MinInterval = Minutes(1),
    MaxInterval = Minutes(20),
    MinSize = 1,                        -- minimum size of spawned group
    MaxSize = 4,                        -- maximum size of spawned group
    MinCount = 1,                       -- minimum number of spawned groups per event
    MaxCount = 2,                       -- maximum number of spawned groups per event
    Altitudes = {
        DCAF.AirAltitude.High,
        DCAF.AirAltitude.Medium,
        DCAF.AirAltitude.Level,
        DCAF.AirAltitude.Popup
    },
    -- MinAltitude = Feet(Altitude.Popup.MSL), obsolete
    -- MaxAltitude = Feet(Altitude.High.MSL),
    MinDistance = NauticalMiles(40),
    MaxDistance = NauticalMiles(160),
    MaxOffsetAngle = 60,
    MaxEvents = 5,
    RemainingEvents = 5,
}

function DCAF.Air.Randomization:New()
    return DCAF.clone(DCAF.Air.Randomization)
end

function DCAF.Air.Randomization:WithDistance(min, max)
    if not isNumber(min) then
        error("DCAF.Air.Randomization:WithDistance :: `min` must be a number but was: " .. DumpPretty(min)) end

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

function DCAF.Air.Randomization:WithMaxOffsetAngle(max)
    if not isNumber(max) then
        error("DCAF.Air.Randomization:WithOffsetAngle :: `max` must be a number but was: " .. DumpPretty(max)) end

    self.MaxOffsetAngle = max
    return self
end

function DCAF.Air.Randomization:WithAltitudes(...)
    if #arg == 0 then
        error("DCAF.Air.Randomization:WithAltitude :: expected at least one altitude value") end

    -- validate args
    local altitudes = {}
    for i = 1, #arg, 1 do
        local alt = arg[i]
        if not isTable(alt) or not isAssignedString(alt.Name) or not isNumber(alt.MSL) then
            error("DCAF.Air.Randomization:WithAltitude :: unexpcted altitude value #" .. Dump(i) .. ": " .. DumpPretty(alt)) end 
    end

    self.Altitudes = altitudes
    return self
end

function DCAF.Air.Randomization:GetAltitude()
    local index = math.random(1, #self.Altitudes)
    return self.Altitudes[index]
end

function DCAF.Air.Randomization:WithInterval(min, max)
    if not isNumber(min) then
        error("DCAF.Air.Randomization:WithInterval :: `min` must be a number but was: " .. DumpPretty(min)) end

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

function DCAF.Air.Randomization:WithMaxEvents(maxEvents)
    if not isNumber(maxEvents) then
        error("DCAF.Air.Randomization:WithMaxEvents :: `countEvents` must be a number but was: " .. DumpPretty(maxEvents)) end

    self.MaxEvents = maxEvents
    self.RemainingEvents = maxEvents
    return self
end

function DCAF.Air.Randomization:WithGroups(...)
    if #arg == 0 then
        error("DCAF.Air.Randomization:WithGroups :: expected at least one group") end

    -- validate
    local groups = {}
    for i = 1, #arg, 1 do
        local group = getGroup(arg[i])
        if not group then
            if isAssignedString(arg[i]) then
                group = DCAF.Air.Adversaries[arg[i]]
            end
            if not group then
                error("DCAF.Air.Randomization:WithGroups :: cannot resolve group from: " .. DumpPretty(arg[i]))  end
            table.insert(group)
        end
    end
    self.Adversaries = groups
    return self
end

function DCAF.Air.Randomization:StartForGroupState(state)
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
--Debug("nisse - air threat randomize :: next event: " .. UTILS.SecondsToClock(timeToNext + UTILS.SecondsOfToday()) )
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
            spawnGroup(info, size, state, distance, altitude, DCAF.AirPosition.Ahead, offsetAngle)
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
function DCAF.Air:WithGroupRandomization(randomization)
    if randomization == nil then
        randomization = DCAF.Air.Randomization:New()
    end
    if not isClass(randomization, "DCAF.Air.Randomization") then
        error("DCAF.Air:WithRandomization :: `randomization` is of unexpected value: " .. DumpPretty(randomization)) end

    _airThreatRandomization = randomization
    return self
end

function DCAF.Air:Start()
    if DCAF.Air.IsStarted then
        return end

    DCAF.Air.IsStarted = true
    MissionEvents:OnPlayerEnteredUnit(onPlayerEnteredUnit)
    return self
end

