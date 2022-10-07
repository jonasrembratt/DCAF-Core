--require "DCAF.Core"

local _allStories = {}

local StoryGroupIndex = {     -- used for keeping track of GROUPs, and how they are related to stories
    GroupName = nil,          -- string; name of group
    Group = nil,              -- <GROUP> (MOOSE object)
    Stories = {},             -- key = story name, value = { list of <Story> where group partakes }
    Storylines = {},          -- key = story name, value = { list of <Storyline> where group partakes }
    CountStories = 0,         -- integer; number of stories controlling the <GROUP>
    CountStorylines = 0,      -- integer; number of storylines controlling the <GROUP>
}

local StoryIndex = {
    CountStories = 0,         -- integer; counts number of stories 
    CountStorylines = 0,      -- integer; counts number of storylines
    CountGroups = 0,          -- integer; counts number of groups controlled by stories
    Stories = {
        -- key = Story name; value = <Story>
    },
    Storylines = {
        -- key = Storyline name; value = <Storyline>
    },
    Groups = {
        -- key = group name; value = <StoryGroupIndex>
    }
}

StorySandboxScope = {
    None = 'None',            -- no sandbox in use (completely unrestricted)
    Story = 'Story',          -- sandbox is Story (eg. one stoyline may destroy groups in other Storylines of same Story)
    Storyline = 'Storyline'   -- sandbox is Storyline (eg. storyline cannot affect state of other storylines, other than starting them)
}

StoryConfiguration = {
    Sandbox = StorySandboxScope.Storyline   -- <StorySandboxScope>
}

StoryState = {
    Pending = 1,
    Running = 2,
    Done = 3
}

Story = {
    Name = nil,               -- name of the story
    Description = nil,        -- string, Story description
    Enabled = true,           -- must be set for stories to activate
    Storylines = {},          -- list of <Storyline>
    Config = nil,             -- <StoryConfiguration>
    State = StoryState.Pending, -- story  state
    _timer = nil,
    _onStartedHandlers = {},  -- list of <function(<Story>)
    _onEndedHandlers = {}     -- list of <function(<Story>)
}

Storyline = {
    _nisse_debug = nil,
    Name = nil,               -- name of the story line (see also Storyline:FullName())
    Story = nil,              -- <Story>
    Description = nil,        -- (optional) story line description 
    State = StoryState.Pending, -- <StoryState>
    WasCancelled = false,     -- when set; storu line was cancelled
    Enabled = true,           -- must be set for story to activate
    Level = nil,              -- (DifficultyLevel) optional; when set story will only run if level is equal or higher
    StartTime = nil,          -- how long (seconds) into the mission before story begins
    Groups = {},              -- key = list of <StoryGroup>
    Config = nil,             -- <StoryConfiguration>

    StartConditionFunc = nil, -- callback function(<self>, <MissionStories>) , returns true when story should start
    EndConditionFunc = nil,   -- callback function(<self>, <MissionStories>) , returns true when story should end

    -- event handlers
    OnStartedFunc = nil,     -- event handler: triggered when story starts
    OnEndedFunc = nil        -- event handler: triggered when story ends
}

StorylineIdle = {}

local StoryGroup = {
    GroupName = nil,         -- string; name of GROUP
    Group = nil,             -- the activated/spawned group
    Storyline = nil,         -- <Storyline>
}

StoryEventArgs = {
    Story = nil,
    Storyline = nil
}

function StoryConfiguration:New()
    return routines.utils.deepCopy(StoryConfiguration)
end


------------------------------- [ INDEXING ] -------------------------------

function StoryGroupIndex:New(storyGroup)
    local index = routines.utils.deepCopy(StoryGroupIndex)
    index.GroupName = storyGroup.GroupName
    index.Group = storyGroup.Group
    index.Stories[storyGroup.Storyline.Story.Name] = storyGroup.Storyline.Story
    index.Storylines[storyGroup.Storyline.Name] = storyGroup.Storyline
    return index
end

function StoryGroupIndex:Update(storyGroup)
    self.Stories[storyGroup.Storyline.Story.Name] = storyGroup.Storyline.Story
    self.Storylines[storyGroup.Storyline.Name] = storyGroup.Storyline
end

function StoryIndex:AddGroup(storyGroup)
    local index = StoryIndex.Groups[storyGroup.GroupName]
    if index then
        index:Update(storyGroup)
        return
    end
    index = StoryGroupIndex:New(storyGroup)
    StoryIndex.CountGroups = StoryIndex.CountGroups + 1
    StoryIndex.Groups[storyGroup.GroupName] = index
end

function StoryIndex:AddStoryline(storyline)
    StoryIndex.Storylines[storyline.Name] = storyline
    StoryIndex.CountStorylines = StoryIndex.CountStorylines + 1
    for _, storyGroup in ipairs(storyline.Groups) do
        StoryIndex:AddGroup(storyGroup)
    end
end

function StoryIndex:AddStory(story)
    StoryIndex.Stories[story.Name] = story
    StoryIndex.CountStories = StoryIndex.CountStories + 1
    for _, storyline in ipairs(story.Storylines) do
        StoryIndex:AddStoryline(storyline)
    end
end

function StoryIndex:GetGroupStories(groupName)
    local index = StoryIndex.Groups[groupName]
    if index ~= nil then
        return index.Stories
    end
    return {}
end

function StoryIndex:CountGroupStories(groupName)
    local index = StoryIndex.Groups[groupName]
    if index ~= nil then
        return index.CountStoryies
    end
    return 0
end

function StoryIndex:GetGroupStorylines(groupName)
    local index = StoryIndex.Groups[groupName]
    if index ~= nil then
        return index.Storylines
    end
    return {}
end

function StoryIndex:CountGroupStorylines(groupName)
    local index = StoryIndex.Groups[groupName]
    if index ~= nil then
        return index.CountStorylines
    end
    return 0
end

function StoryIndex:IsGroupExclusiveToStory(groupName, story)
    local index = StoryIndex.Groups[groupName]
    if index == nil or index.CountStories ~= 0 then 
        return false end

    return index.Stories[story.Name] ~= nil
end

function StoryIndex:IsGroupExclusiveToStoryline(groupName, storyline)
    local index = StoryIndex.Groups[groupName]
    if index == nil or index.CountStorylines ~= 0 then 
        return false end

    return index.Storylines[storyline.Name] ~= nil
end


------------------------------- [ STORY GROUP ] -------------------------------

function StoryGroup:New(groupName, storyline)
    local sg = routines.utils.deepCopy(StoryGroup)
    sg.Group = GROUP:FindByName(groupName)
    if not sg.Group then
        error("StoryGroup:New :: group not found: " .. groupName) end

    sg.GroupName = groupName
    sg.Storyline = storyline
    return sg
end

function Story:FindStoryline(storylineName)
    for _, storyline in ipairs(self.Storylines) do
        if storyline.Name == storylineName then
            return storyline
        end
    end
end

function StoryGroup:Run()
Debug("nisse - StoryGroup:Run :: storyline: " .. self.Storyline.Name .. " :: group: " .. self.GroupName)
    if self.Storyline:IsPending() then
        self.Group = activateNow(self.GroupName)
    else
        self.Group = spawnNow(self.GroupName)
    end
    return self
end

function StoryGroup:Destroy()
    if self.Group ~= nil then
        self.Group:Destroy()
        self.Group = nil
    end
    return self
end

function StoryGroup:Stop()
    Stop(self.Group)
    return self
end


------------------------------- [ STORYLINE ] -------------------------------

function Storyline:New(name, description)
    local ms = routines.utils.deepCopy(Storyline)
    ms.Name = name
    ms.Description = description
    return ms
end

function Storyline:SandboxScope()
    return self.Config.Sandbox
end

function Storyline:FullName()
    if self.Story ~= nil then
        return self.Story.Name ..'/'..self.Name
    end
    return self.Name
end

function StorylineIdle:New(name, description)
    local storyline = Storyline:New(name, description)
    storyline._isIdle = true
    return storyline
end

function Storyline:WithDescription(description)
    if description ~= nil and not isString(description) then
        error("Storyline:WithDescription :: unexpected type for description: " .. type(description)) end

    self.StoryDescription = description
    return self
end

-- function Storyline:WithLevel(level)
--     if not isNumber(level) then
--         Warning("Storyline:WithLevel :: unexcpeted difficulty level type: " .. type(level) .. " :: IGNORES")
--         return self
--     end
--     self.Level = level
--     return self
-- end

function Storyline:WithStartTime(min, max)
    if not isNumber(min) then
        Warning("Storyline:WithStartTime :: unexcpeted 'min' type: " .. type(min) .. " :: IGNORES")
        return
    end
    if max == nil then
        self.StartTime = min
        return self
    end
    if not isNumber(max) then
        max = min
    end
    if max < min then
        min, max = swap(min, max)
    end
    self.StartTime = math.random(min, max)
    return self
end

function Storyline:WithStartCondition(func)
    if not isFunction(func) then
        error("Storyline:WithStartCondition :: func must be a function (was " .. type(func) .. ")")  end

    self.StartConditionFunc = func
    return self
end

function Storyline:WithEndCondition(func, onDoneFunc)
    if not isFunction(func) then
        error("Storyline:WithEndCondition :: func must be a function (was " .. type(func) .. ")") end

    self.EndConditionFunc = func
    self.OnDoneFunc = onDoneFunc
    return self
end

function Storyline:WithGroups(...)
    if self.Story ~= nil then
        error("Storyline:WithGroups :: cannot initialize Storyline using 'WithGroup' after Storyline was added to story. Please use 'Storyline:AddGroups' instead") end

    for _, group in ipairs(arg) do
        local storyGroup = nil
        if isString(group) then
            storyGroup = StoryGroup:New(group, self)
        end
        storyGroup.Storyline = self
        table.insert(self.Groups, storyGroup)
    end
    return self
end

function Storyline:IsPending() return self.State == StoryState.Pending end
function Storyline:IsRunning() return self.State == StoryState.Running end
function Storyline:IsDone() return self.State == StoryState.Done end

function Storyline:FindGroup(groupName)
    for _, sg in ipairs(self.Groups) do
        if sg.GroupName == groupName then
            return sg
        end
    end
end

function Storyline:FindUnit(unitName)
    for _, storyGroup in ipairs(self.Groups) do
        local key = tableKeyOf(storyGroup.Group:GetUnits(), 
            function(unit) 
                return unit.UnitName == unitName 
            end)
        if key then
            return true 
        end
    end
end

function Storyline:Run(delay)
    local function run()
        if not self.Enabled then
            return self end

        DCAFEvents:ActivateFor(self.Name)
        for _, storyGroup in ipairs(self.Groups) do
            storyGroup:Run(time)
        end
        self._isIdle = false
        self.State = StoryState.Running    
Debug("nisse - Storyline:Run :: self: " .. DumpPretty(self))
        if self.OnStartedFunc ~= nil then
            self.OnStartedFunc(StoryEventArgs:New(self))
        end
        return self
    end

    if isNumber(delay) then
        Delay(delay, run)
    else
        run()
    end
end

-- function Storyline:Restart(delay)
--     if self.State == StoryState.Pending then
--         return self:Run(delay)
--     end
--     -- todo Consider supporting restarting storylines
-- end

function StoryEventArgs:New(storyline)
    local args = routines.utils.deepCopy(StoryEventArgs)
    args.Story = storyline.Story
    args.Storyline = storyline
    return args
end

function StoryEventArgs:FindStoryline(storylineName)
    return self.Story:FindStoryline(storylineName)
end

function StoryEventArgs:RunStoryline(storylineName, delay)
    return self.Story:RunStoryline(storylineName, delay)
end

function StoryEventArgs:RunStory(storyName, delay)
    return self.Story:RunStory(storyName, delay)
end

function StoryEventArgs:EndStoryline()
    self.Storyline:End()
end

function StoryEventArgs:EndStory()
    self.Storyline.Story:End()
end

function StoryEventArgs:DestroyGroups(...)
    return self.Storyline:DestroyGroups(...)
end

function Storyline:_runIfDue()
    if not self.Enabled or self._isIdle or (self.StartTime ~= nil and self.StartTime > time) then
        return false end
    
    if self.StartConditionFunc ~= nil and not self.StartConditionFunc(StoryEventArgs:New(self)) then
        return false end

    self:Run()
    return true
end

function Storyline:End()
    if not self:IsRunning() then
        return end

    if self._onUnitDeadFunc then
        MissionEvents:EndOnUnitDead(self._onUnitDeadFunc)
    end
    self.State = StoryState.Done
    if self.OnEndedFunc ~= nil then
        self.OnEndedFunc(StoryEventArgs:New(self))
    end
end

function Storyline:_endOnCondition(now)

    if not self:IsRunning() then
        return false end

    if self.EndConditionFunc ~= nil and self.EndConditionFunc(StoryEventArgs:New(self)) then
        self:End()
    elseif self.CancelCondition ~= nil and self.CancelCondition(StoryEventArgs:New(self)) then
        self.WasCancelled = true
        self.End()
    end
end

function Storyline:DestroyGroups(...)
    local groups = arg
    if #arg == 0 then
        groups = self.Groups
    end

    for _, sg in ipairs(groups) do
        sg:Destroy()
    end
    return self
end

function Storyline:DestroyGroup(group)
    if group == nil then
        error("Storyline:DestroyGroup :: group was unassigned") end

    group = getGroup(group)
    if group == nil then
        error("Storyline:DestroyGroup :: group cannot be resolved from: " .. Dump(group)) end

    local sandboxScope = self:SandboxScope()
    if sandboxScope == StorySandboxScope.Story and not StoryIndex:IsGroupExclusiveToStory(group.GroupName, self.Story) then
        error("Storyline:DestroyGroup :: cannot destroy group that are also controlled by other stories (see sandbox configuration)") 
    end
    if sandboxScope == StorySandboxScope.Storyline and not StoryIndex:IsGroupExclusiveToStoryline(group.GroupName, self) then
        error("Storyline:DestroyGroup :: cannot destroy group that are also controlled by other storylines (see sandbox configuration)") 
    end

    local groups = arg
    if #arg == 0 then
        groups = self.Groups
    end

    for _, sg in ipairs(groups) do
        sg:Destroy()
    end
    return self
end

function Storyline:StopGroups(...)
    local groups = arg
    if #arg == 0 then
        groups = self.Groups
    end
    for _, sg in ipairs(self.Groups) do
        sg:Stop()
    end
    return self
end

function Storyline:_addPendingDelagate(eventName, func)

end

function Storyline:OnStarted(func)
    if not isFunction(func) then
        error("Storyline:OnStarted :: unexpected function type: " .. type(func)) end

    self.OnStartedFunc = func
    return self
end

function Storyline:OnEnded(func)
    if not isFunction(func) then
        error("Storyline:OnEnded :: unexpected function type: " .. type(func)) end

    self.OnEndedFunc = func
    return self
end

function Storyline:OnStoryEnded(func)
    if not isFunction(func) then
        error("Storyline:OnStoryEnded :: unexpected function type: " .. type(func)) end

    self._onStoryEndedFunc = func
    return self
end

--  todo For events, consider pre-registering the handler without calling MissionEvent:... until Storyline runs

local function isStorylineEventUnit(storyline, expectedUnit, eventUnit)
    if expectedUnit.UnitName == eventUnit.UnitName then
        if storyline:FindUnit(eventUnit.UnitName) then
            return true 
        else
            return false
        end
    end

    -- check whether the event unit was spawned from storyline group ...
    local isInstance, name = isUnitInstanceOf(eventUnit, expectedUnit)
    if not isInstance then
        return false end

    if storyline:FindUnit(eventUnit.UnitName) then
        return true
    else
        return false
    end
end

function Storyline:OnAircraftLanded(aircraft, func)
    if aircraft ~= nil then
        aircraft = getUnit(aircraft)
        if aircraft then
            if not self:FindUnit(aircraft.UnitName) then
                error("Storyline:OnAircraftLanded :: aircraft '" .. aircraft.UnitName .. "' is not in storyline '"..self:FullName() .. "'")
            end
        else
            error("Storyline:OnAircraftLanded :: cannot resolve aircraft from: " .. Dump(aircraft))
        end
    end
    if not isFunction(func) then
        error("Storyline:OnAircraftLanded :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
-- Debug("nisse - Storyline:OnAircraftLanded :: event: " .. DumpPretty(event))
Debug("nisse - Storyline:OnAircraftLanded :: self.State: " .. DumpPrettyDeep(self.State))
        if not self:IsRunning() then
            return end

        -- only trigger for specified aircraft ...
        local testUnitName = event.IniGroupName 
        if aircraft and not isStorylineEventUnit(self, aircraft, event.IniUnit) then
            return end

        -- this is a one-time event ... 
        MissionEvents:EndOnAircraftLanded(eventFunc)
        event = copyTo(StoryEventArgs:New(self), event)
Debug("nisse - Storyline:OnAircraftLanded :: self.State: " .. DumpPrettyDeep(self.State))
        func(event)
    end

    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnAircraftLanded, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnAircraftLanded(eventFunc)
            end)
        end)
    else
        MissionEvents:OnAircraftLanded(eventFunc)
        self:OnStoryEnded(function(story)
            MissionEvents:EndOnAircraftLanded(eventFunc)
        end)
    end
    return self
end

function Storyline:OnGroupDiverted(group, func)
    if group ~= nil then
        group = getGroup(group)
        if not group then
            error("Storyline:OnGroupDiverted :: cannot resolve group from: " .. Dump(group)) end

        if not self:FindGroup(group.GroupName) then
            error("Storyline:OnGroupDiverted :: group is not in storyline: " .. group.GroupName) end
    end
    if not isFunction(func) then
        error("Storyline:OnGroupDiverted :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified group or groups in storyline ...
        if group and group.GroupName ~= event.IniGroupName then
            return end
        if not self:FindGroup(event.IniGroupName) then
            return end

        MissionEvents:EndOnGroupDiverted(eventFunc)
        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    self:OnStoryEnded(function(story)
        MissionEvents:EndOnGroupDiverted(eventFunc)
    end)
    MissionEvents:OnGroupDiverted(eventFunc)
    return self
end

function Storyline:OnGroupEntersZone(group, zone, func, continous)

    if not isFunction(func) then
        error("Storyline:OnGroupEntersZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified group or groups in storyline ...
        if group and group.GroupName ~= event.IniGroupName then
            return end
        if not self:FindGroup(event.IniGroupName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    -- todo end event OnGroupEntersZone when Story ends
    MissionEvents:OnGroupEntersZone(group, zone, func, continous)
    return self
end

function Storyline:OnGroupInsideZone(group, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnGroupInsideZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified group or groups in storyline ...
        if group and group.GroupName ~= event.IniGroupName then
            return end

        if not self:FindGroup(event.IniGroupName) then
            error("Storyline:OnGroupInsideZone :: group is not part of storyline '" .. self.Name .. "': " .. event.IniGroupName)
            return 
        end
        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    -- todo end event OnGroupInsideZone when Story ends
    MissionEvents:OnGroupInsideZone(group, zone, func, continous)
    return self
end

function Storyline:OnGroupLeftZone(group, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnGroupLeftZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified group or groups in storyline ...
        if group and group.GroupName ~= event.IniGroupName then
            return end

        if not self:FindGroup(event.IniGroupName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    -- todo end event OnGroupLeftZone when Story ends
    MissionEvents:OnGroupLeftZone(group, zone, func, continous)
    return self
end

function Storyline:OnUnitEntersZone(unit, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitEntersZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified unit or units in storyline ...
        if unit and unit.UnitName ~= event.IniUnitName then
            return end

        if not self:FindUnit(event.IniUnitName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    -- todo end event OnUnitEntersZone when Story ends
    MissionEvents:OnUnitEntersZone(unit, zone, func, continous)
    return self
end

function Storyline:OnUnitInsideZone(unit, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitInsideZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified unit or units in storyline ...
        if unit and unit.UnitName ~= event.IniUnitName then
            return end

        if not self:FindUnit(event.IniUnitName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    -- todo end event OnUnitInsideZone when Story ends
    MissionEvents:OnUnitInsideZone(unit, zone, func, continous)
    return self
end

function Storyline:OnUnitLeftZone(unit, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitLeftZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified unit or units in storyline ...
        if unit and unit.UnitName ~= event.IniUnitName then
            return end

        if not self:FindGroup(event.IniUnitName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    -- todo end event OnUnitLeftZone when Story ends
    MissionEvents:OnUnitLeftZone(unit, zone, func, continous)
    return self
end

-- function Storyline:OnUnitDestroyed(func) obsolete - feltänkt
--     if not isFunction(func) then
--         error("Storyline:OnUnitDestroyed :: unexpected function type: " .. type(func)) end

--     Storyline._onUnitDeadFunc = function(event)
--         for _, sg in ipairs(self.Groups) do 
--             if sg.UnitName == event.IniUnitName then
--                 func( event, StoryEventArgs:New(self) )
--             end
--         end
--     end
--     MissionEvents:OnUnitDead(self._onUnitDeadFunc)
--     return self
-- end

------------------------------- [ STORY ] -------------------------------

local function addStorylines(story, index, ...)
    for _, storyline in ipairs(arg) do
        table.insert(story.Storylines, storyline)
        storyline.Story = story
        storyline.Config = routines.utils.deepCopy(story.Config)
        if index then
            StoryIndex:AddStoryline(storyline)
        end
    end
end

function Story:New(name, ...)
    local story = routines.utils.deepCopy(Story)
    story.Name = name
    story.Config = StoryConfiguration:New()
    if not isAssignedString(name) then
        error("Story:New :: story name was unspecified") end

    table.insert(_allStories, story)
    story:WithStorylines(...)
    return story
end

function Story:WithDescription(description)
    self.Description = description
    return self
end

function Story:WithStorylines(...)
    addStorylines(self, true, ...)
    return self
end

function Story:WithConfiguration(configuration)
    self.Config = configuration
    return self
end

function Story:Run(delay, interval)

    local function onTimer()
        self.State = StoryState.Running
        local now = MissionTime()
        if not self.Enabled then
            return end
        
        for _, storyline in ipairs(self.Storylines) do
            if storyline.State == StoryState.Pending then
                storyline:_runIfDue(now)
            elseif storyline.State == StoryState.Running then
                storyline:_endOnCondition(now)
            end
        end
    end

    if not isNumber(delay) then
        delay = 1
    end
    if not isNumber(interval) then
        interval = 1
    end
    self._timer = TIMER:New(onTimer):Start(delay, interval)
    for _, func in ipairs(self._onStartedHandlers) do
        local success, err = pcall(func(self))
        if not success then
            Error("Story:End :: error when invoken OnStarted handler. " .. tostring(err))
        end
    end
    return self
end

function Story:RunStoryline(storylineName, delay, restart)
    if not isString(storylineName) then
        errorOnDebug("Story:RunStoryline :: unexpected type for storylineName: " .. type(storylineName))
        return
    end

    local storyline = self:FindStoryline(storylineName)
    if not storyline then
        errorOnDebug("Story:RunStoryline :: storyline '".. storylineName .. "' not found in story '" .. self.Name .. "'")
        return
    end
    if storyline.State == StoryState.Pending then
        storyline:Run(delay)
    elseif restart then
        storyline:Restart(delay)
    end
    return self
end

function Story:End()
    
    -- invoke Storye:OnEnded events ...
    for _, func in ipairs(self._onEndedHandlers) do
        local success, err = pcall(func(self))
        if not success then
            errorOnDebug("Story:End :: error when invoking Story:OnEnd handler. " .. tostring(err))
        end
    end

    -- invoke Storyline:OnStoryEnded events ...
    for _, storyline in ipairs(self.Storylines) do
        if storyline._onStoryEndedFunc then
            local success, err = pcall(storyline._onStoryEndedFunc(self))
            if not success then
                errorOnDebug("Story:End :: error when invoke Storyline:OnStoryEnded handler. " .. tostring(err))
            end
        end
    end
    
    self.State = StoryState.Done
end

function Story:OnStarted(func)
    if not isFunction(func) then
        error("Story:OnStarted :: expected function but got " .. type(func)) end
    
    table.insert(self._onStartedHandlers, func)
    return self
end

function Story:OnEnded(func)
    if not isFunction(func) then
        error("Story:OnEnded :: expected function but got " .. type(func)) end
    
    table.insert(self._onEndedHandlers, func)
    return self
end

function Story:FindStory(storyName)
    if not isAssignedString(storyName) then
        Warning("Story:FindStory :: storyName was unassigned :: IGNORES")
        return nil
    end

    for _, story in ipairs(_allStories) do
        if story.Name == storyName then
            return story
        end
    end
end

function Story:RunStory(storyName, delay, interval)
    if not isAssignedString(storyName) then
        Warning("Story:RunStory :: storyName was unassigned :: IGNORES")
        return
    end

    local story = Story:FindStory(storyName)
    if not story then
        Warning("Story:RunStory :: story was not found: '" .. storyName .. "' :: IGNORES")
        return
    end
    story:Run(delay, interval)
    return story
end