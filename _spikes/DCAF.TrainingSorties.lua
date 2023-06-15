-- requires DCAF.TrainingRanges.lua

local DCAF_TrainingSortieTemplates = { -- dictionary 
    -- key   = #string - '<squadron>/<sortie>'
    -- value = #DCAF.TrainingSortie
}

local DCAF_EnabledTrainingSorties = { -- dictionary 
    -- key   = #string - '<squadron>/<sortie>'
    -- value = #DCAF.TrainingSortie
}

local BeginMethod = {
    Direct = "When Enabled",
    Menu = "Menu",
    InZone = "In Zone",
    AfterTime = "After Time",
    AfterTakeoff = "After Takeoff"
}

local BeginsInfo = {
    Method = nil,           -- #BeginMethod
    Value = nil             -- any - varies with method
}

local EndMethod = {
    None = "None",
    InZone = "In Zone",
    AfterTime = "After Time",
    OnDespawn = "On Despawn"
}

local EndsInfo = {
    Method = nil,           -- #BeginMethod
    Value = nil             -- any - varies with method
}

function BeginsInfo:New(method, value)
    local info = DCAF.clone(BeginsInfo)
    info.Method = method
    info.Value = value
    return info
end

function BeginsInfo.Default()
    return BeginsInfo:New(BeginMethod.Direct)
end

function EndsInfo:New(method, value)
    local info = DCAF.clone(EndsInfo)
    info.Method = method
    info.Value = value
    return info
end

function EndsInfo.Default()
    return EndsInfo:New(EndMethod.OnDespawn)
end

DCAF.TrainingSortie = {
    ClassName = "DCAF.TrainingSortie",
    Group = nil,           -- #GROUP
    EnabledByPlayer = nil,          -- #string - player name
    Players = {},                   -- { key = #string (player name); value = #UNIT }
    Key = nil,                      -- #string
    Name = nil,                     -- #string
    ShortDescription = nil,         -- #string
    Ranges = nil,                   -- list of #string (names of ranges to be activated by sortie)
    ActivatedRanges = nil,          -- dictionary (key = activated range name; value = activated #DCAF.TrainingRange)
    Begins = nil,                   -- #BeginsInfo
    Ends = nil,                     -- #EndsInfo
    EnabledFunc = nil,              -- #function - triggered when GROUP enables sortie
    BeganTime = nil,                -- #number  - timestamp for when sortie began
    BeganFunc = nil,                -- #function - triggered when sortie begins
    EndedFunc = nil,                -- #function - triggered when sortie ends
    NotifyEvents = false            -- #boolean - true = players are notified when sorties being enabled/disabled
}

local function getSortieKey(ident, sortie)
    return string.lower(ident .. '/' .. sortie)
end

function DCAF.TrainingSortie:New(squadron, sortie, displayName)
    if not isAssignedString(squadron) then
        error("DCAF.Sortie:New :: `squadron` must be assigned string, but was: " .. DumpPretty(squadron)) end

    if isNumber(sortie) then
        sortie = tostring(sortie)
    end
    if not isAssignedString(sortie) then
        error("DCAF.Sortie:New :: `sortie` must be string or number, but was: " .. DumpPretty(sortie)) end
    
    local key = getSortieKey(squadron, sortie)
    sortie = DCAF.clone(DCAF.TrainingSortie)
    sortie.Key = key
    sortie.Name = displayName or key
    sortie.ShortDescription = displayName
    sortie.Begins = BeginsInfo:New(BeginMethod.Direct)
    sortie.Ends = EndsInfo:New(EndMethod.OnDespawn)
    DCAF_TrainingSortieTemplates[key] = sortie
    return sortie
end

    
function DCAF.TrainingSortie:BeginAfterTakeoff(delay)
    if delay ~= nil and not isNumber(delay) then
        error("DCAF.TrainingSortie:BeginAfterTakeoff :: `delay` must be numeric value, but was: " ..DumpPretty(delay)) end

    self.Begins = BeginsInfo:New(BeginMethod.AfterTakeoff, delay)
    return self
end

local function resolveZone(zone)
    local validZone
    if isZone(zone) then
        validZone = zone
    elseif isGroup(zone) then
        validZone = ZONE_POLYGON:New(zone.GroupName, zone)
    elseif isAssignedString(zone) then
        validZone = ZONE:FindByName(zone)
        if not validZone then
            local group = getGroup(zone)
            if group then
                validZone = ZONE_POLYGON:NewFromGroupName(zone)
            end
        end
    end
    return validZone
end

function DCAF.TrainingSortie:BeginInZone(zone)
    local validZone = resolveZone(zone)
    if not validZone then
        error("DCAF.TrainingSortie:BeginInZone :: cannot resolve `zone` from: " .. DumpPretty(zone)) end

    self.Begins = BeginsInfo:New(BeginMethod.InZone, validZone)
    return self
end

function DCAF.TrainingSortie:BeginWithF10Menu(subMenusFunc)
    self.Begins = BeginsInfo:New(BeginMethod.Menu, subMenusFunc)
    return self
end

function DCAF.EndInZone(zone)
    local validZone = resolveZone(zone)
    if not validZone then
        error("DCAF.TrainingSortie:BeginInZone :: cannot resolve `zone` from: " .. DumpPretty(zone)) end
    if not validZone then
        error("DCAF.TrainingSortie:BeginInZone :: cannot resolve `zone` from: " .. DumpPretty(zone)) end

    self.Ends = EndsInfo:New(EndMethod.InZone, validZone)
    return self
end

function DCAF.TrainingSortie:EndAfter(seconds, message)
    if not isNumber(seconds) then 
        error("DCAF.TrainingSortie:EndAfter :: `seconds` must be number, but was: " .. DumpPretty(seconds)) end

    self.Ends = EndsInfo:New(EndMethod.AfterTime, seconds)
    self.Ends.Message = message
    return self
end

--- Looks up an enabled sortie with at least one range that is in conflict with the specified sortie
local function findEnabledConflictingSortie(sortie, group)
Debug("nisse - DCAF_EnabledTrainingSorties.FindConflicting :: DCAF_EnabledTrainingSorties: " .. DumpPrettyDeep(DCAF_EnabledTrainingSorties, 2))    

    for key, enabledSortie in pairs(DCAF_EnabledTrainingSorties) do
        for _, enabledSortieName in pairs(enabledSortie.Ranges) do
            if enabledSortie.Group.GroupName ~= group.GroupName and tableIndexOf(sortie.Ranges, enabledSortieName) then
                return enabledSortie end
        end
    end
end

function DCAF.TrainingSortie:AddPlayer(playerName, unit)
    self.Players[playerName] = unit
end

function DCAF.TrainingSortie:RemovePlayer(playerName)
    self.Players[playerName] = nil
end

function DCAF.TrainingSortie:CountPlayers()
    return dictCount(self.Players)
end

function DCAF.TrainingSortie:Enable(unit, playerName)
    self:AddPlayer(playerName, unit)
Debug("nisse - DCAF.TrainingSortie:Enable :: players: " .. Dump(self:CountPlayers()))    
    local enabled = DCAF_EnabledTrainingSorties[self.Key]
    local group = unit:GetGroup()
    if enabled and enabled.Group.GroupName ~= group.GroupName then
        MessageTo(group, "Be adviced: Sortie " .. self.Name .. " was already enabled  by " .. enabled.EnabledByPlayer, 12)
        -- MessageTo(group, self.Name .. " was already enabled by " .. enabled.EnabledByPlayer, 12)
        -- MessageTo(group, "Please select a different sortie or wait until it becomes available", 12)
        return 
    end

    local conflict = findEnabledConflictingSortie(self, unit:GetGroup())
    if conflict then
        MessageTo(group, "Be adviced: Sortie (" .. conflict.Name .. ", by " .. conflict.EnabledByPlayer .. ") is ongoing and also relies on the required assets", 12)
        -- MessageTo(group, "Please be adviced select a different sortie or wait until the assets become available", 12)
        return 
    end

    DCAF_EnabledTrainingSorties[self.Key] = self
    self.Group = unit:GetGroup()
    self.EnabledByPlayer = playerName
    if isFunction(self.EnabledFunc) then
        self.EnabledFunc(self)  -- todo consider protecting with pcall and log warning with stack trace
    end

    local msg = "'" .. self.Name .. "' was enabled by '" .. playerName
    if string.find(string.lower(self.Name), 'sortie') ~= 1 then
        msg = "Sortie " .. msg
    end
    Debug(msg)
    if DCAF.TrainingSortie.NotifyEvents then
        MessageTo(unit:GetGroup(), msg, 10)
    end
-- Debug("nisse - DCAF.TrainingSortie:Enable :: self.Begins: " .. DumpPretty(self.Begins))    
    self.Begins:Execute(self)
    self.Ends:Execute(self)
end

function DCAF.TrainingSortie:Begin()
    self.BeganTime = UTILS.SecondsOfToday()
    if self.Ranges then
        for _, rangeName in ipairs(self.Ranges) do
            self.ActivatedRanges = self.ActivatedRanges or {}
            local range = DCAF.TrainingRange:Activate(rangeName)
            table.insert(self.ActivatedRanges, range)
        end
    end
    self.Ends:Execute(self)
    if isFunction(self.BeganFunc) then
        self.BeganFunc(self) -- todo consider protecting with pcall and log warning with stack trace
    end
end

function DCAF.TrainingSortie:End()
    Debug("Training sortie '" .. self.Name .. "' ended :: Key: " .. Dump(self.Key))
    DCAF_EnabledTrainingSorties[self.Key] = nil
Debug("nisse - DCAF.TrainingSortie:End :: DCAF_EnabledTrainingSorties: " .. DumpPretty(DCAF_EnabledTrainingSorties))
    if self.ActivatedRanges then
        for _, range in ipairs(self.ActivatedRanges) do
            range:Deactivate()
        end
        self.ActivatedRanges = nil
    end
    if isFunction(self.EndedFunc) then
        self.EndedFunc(self) -- todo consider protecting with pcall and log warning with stack trace
    end
end

function DCAF.TrainingSortie:ActivateRanges(...)
    for i = 1, #arg, 1 do
        self.Ranges = self.Ranges or {}
        table.insert(self.Ranges, arg[i])
    end
    return self
end

function DCAF.TrainingSortie:GetRange(name)
    for _, range in ipairs(self.ActivatedRanges) do
        if string.lower(name) == string.lower(range.Name) then
            return range
        end
    end
end

function DCAF.TrainingSortie:OnEnabled(func)
    if not isFunction(func) then
        error("DCAF.TrainingSortie:OnExecute :: `func` must be function, but was: " .. type(func)) end

    self.EnabledFunc = func
    return self
end

function DCAF.TrainingSortie:OnBegan(func)
    if not isFunction(func) then
        error("DCAF.TrainingSortie:OnBegan :: `func` must be function, but was: " .. type(func)) end

    self.BeganFunc = func
    return self
end

function DCAF.TrainingSortie:OnEnded(func)
    if not isFunction(func) then
        error("DCAF.TrainingSortie:OnEnded :: `func` must be function, but was: " .. type(func)) end

    self.EndedFunc = func
    return self
end

local function beginInZone(sortie, zone)
    MissionEvents:OnGroupEntersZone(sortie.Group, zone, function(event)
        sortie:Begin()
    end, false)
    return sortie
end

local function beginAfterTakeoff(sortie, delay)
    local _onTakeoffFunc
    local function onTakeoff(event)
Debug("nisse - beginAfterTakeoff :: event: " .. DumpPretty(event))
        if sortie.Group.GroupName == event.IniGroup.GroupName then
            if delay then
                Delay(delay, function()
                    sortie:Begin()
                end)
            else
                sortie:Begin()
            end
            MissionEvents:EndOnAircraftTakeOff(_onTakeoffFunc)
        end
    end
    _onTakeoffFunc = onTakeoff

    MissionEvents:OnAircraftTakeOff(_onTakeoffFunc)
end

local function beginFromMenu(sortie, subMenusFunc)
    if isFunction(subMenusFunc) then
        local sortiesMenu = MENU_GROUP:New(sortie.Group, sortie.Name)
        subMenusFunc(sortiesMenu, sortie)
        return sortie
    end
    local menu
    menu = MENU_GROUP_COMMAND:New(sortie.Group, "Begin " .. sortie.Name, nil, function()
        sortie:Begin()
        menu:Remove()
    end)
end

function BeginsInfo:Execute(sortie)
    if self.Method == BeginMethod.Direct then
        sortie:Begin()
    elseif self.Method == BeginMethod.InZone then
        beginInZone(sortie, self.Value)
    elseif self.Method == BeginMethod.AfterTakeoff then
        beginAfterTakeoff(sortie, self.Value)
    elseif self.Method == BeginMethod.Menu then
        beginFromMenu(sortie, self.Value)
    else
        error("BeginsInfo:Execute :: Not implemented: " .. Dump(self.Method))
    end
    -- todo support more begin methods
end

local function endWhenLastPlayerDespawns(sortie)
    local _funcDespawned
    local function funcDespawned(event)
        if event.IniGroupName == sortie.Group.GroupName then
            sortie:RemovePlayer(event.IniPlayerName)
Debug("nisse - endWhenLastPlayerDespawns_funcDespawned (aaa) :: iniGroupName: " .. event.IniGroupName .. " :: sortie.Group: " .. sortie.Group.GroupName .. " :: players left: " .. Dump(sortie:CountPlayers()))
            if sortie:CountPlayers() == 0 then
                sortie:End()
                -- MessageTo(nil, "Sortie ended: " .. sortie.Name)
                MissionEvents:EndOnPlayerLeftAirplane(_funcDespawned)
            end
--             Delay(1, function() 
-- Debug("nisse - endWhenLastPlayerDespawns_funcDespawned (bbb) :: iniGroupName: " .. event.IniGroupName .. " :: sortie.Group: " .. sortie.Group.GroupName .. " :: players left: " .. Dump(sortie.Group:GetPlayerCount()))
--                 if sortie.Group:GetPlayerCount() == 0 then
--                     sortie:End()
--                     -- MessageTo(nil, "Sortie ended: " .. sortie.Name)
--                     MissionEvents:EndOnPlayerLeftAirplane(_funcDespawned)
--                 end
--             end)
        end
    end
    _funcDespawned = funcDespawned
    MissionEvents:OnPlayerLeftAirplane(_funcDespawned)

    local _funcDestroyed
    MissionEvents:OnUnitDestroyed(function(event) 
Debug("nisse - endWhenLastPlayerDespawns_OnUnitDestroyed :: event: " .. DumpPretty(event))
        funcDespawned(event)
    end)
end

local function endSortie(sortie, message)
    sortie:End()
    if isAssignedString(message) then
        MessageTo(sortie.Group, message)
    end
end

local function endsAfter(sortie, seconds, message)
    Delay(seconds, function()
        endSortie(sortie, message)
    end)
end

local function endInZone(sortie, zone, message)
    MissionEvents:OnGroupEntersZone(sortie.Group, zone, function(event)
        endSortie(sortie, message)
    end, false)
    return sortie
end

function EndsInfo:Execute(sortie)
    -- note -  a sortie _always_ ends when last member of enabling GROUP despawns; the other methods might happen before then
    if not sortie._willEndOnLastPlayerDespawn then
Debug("nisse - EndsInfo:Execute :: set to end on despawn")        
        sortie._willEndOnLastPlayerDespawn = true
        endWhenLastPlayerDespawns(sortie)
    end
    if self.Method == EndMethod.AfterTime then
        endsAfter(sortie, self.Value, self.Message)
    elseif self.Method == EndMethod.InZone then
        endInZone(self.Value, self.Message)
    end
    -- todo support more end methods
end

MissionEvents:OnPlayerEnteredAirplane(function(event)
    local QualSortie = "sortie "
    local groupName = string.lower(event.IniGroupName)
    local sortieAt = string.find(groupName, QualSortie)
    if not sortieAt then
        return end

    local sortieTemplate = string.match(string.sub(groupName, sortieAt+string.len(QualSortie)), "%d+")
    if not sortieTemplate then
        return end

    local ident = string.sub(groupName, 1, sortieAt-1)
    local ident = trim(ident)
    local key = getSortieKey(ident, sortieTemplate)

-- Debug("nisse - MissionEvents:OnPlayerEnteredAirplane :: key: " .. Dump(key))

    sortieTemplate = DCAF_TrainingSortieTemplates[key]
-- Debug("nisse - MissionEvents:OnPlayerEnteredAirplane :: sortie: " .. DumpPretty(sortieTemplate))
    if not sortieTemplate then 
        MessageTo(event.IniGroup, "Sortie unavailable for " .. event.IniGroupName, 10)
-- Debug("nisse - MissionEvents:OnPlayerEnteredAirplane :: DCAF_TrainingSorties: " .. DumpPretty(DCAF_TrainingSortieTemplates))
        return end

    local alreadyEnabled = DCAF_EnabledTrainingSorties[key]
    if alreadyEnabled then
        if alreadyEnabled.Group.GroupName ~= event.IniGroupName then
            local msg = "Sortie '" .. alreadyEnabled.Name .. "' was already enabled by '" .. alreadyEnabled.Group.GroupName .. " (" .. alreadyEnabled.EnabledByPlayer ..")"
            MessageTo(event.IniGroup, msg, 10)
        end
    end

    local sortie = DCAF.clone(sortieTemplate)
    sortie:Enable(event.IniUnit, event.IniPlayerName)
-- Debug("nisse - MissionEvents:OnPlayerEnteredAirplane :: event: " .. DumpPretty(event) .. " :: DCAF_EnabledTrainingSorties: " .. DumpPretty(DCAF_EnabledTrainingSorties))
end)

-------------------------- DONE -----------------------------            
Debug("\\\\\\\\\\\\\\\\\\\\ DCAF.TrainingSortie.lua was loaded ///////////////////")