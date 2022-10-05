--require "DCAF.Core"

local _allStories = {}

Story = {
    Name = nil,              -- name of the story
    Enabled = true,          -- must be set for stories to activate
    Storylines = {},         -- list of <Storyline>
    _timer = nil,
}

StorylineState = {
    Pending = 1,
    Running = 2,
    Done = 3
}

Storyline = {
    Name = nil,              -- name of the story line
    Description = nil,       -- (optional) story line description 
    State = StorylineState.Pending, -- story line state
    WasCancelled = false,    -- when set; storu line was cancelled
    Enabled = true,          -- must be set for story to activate
    Level = nil,             -- (DifficultyLevel) optional; when set story will only run if level is equal or higher
    StartTime = nil,         -- how long (seconds) into the mission before story begins
    Groups = {},             -- key = list of <StoryGroup>

    StartConditionFunc = nil, -- callback function(<self>, <MissionStories>) , returns true when story should start
    EndConditionFunc = nil,   -- callback function(<self>, <MissionStories>) , returns true when story should end

    -- event handlers
    OnStartedFunc = nil,     -- event handler: triggered when story starts
    OnEndedFunc = nil        -- event handler: triggered when story ends
}

StorylineWaiting = {}

StoryGroup = {
    GroupName = nil,
    Group = nil,           -- the activated/spawned group
}

StoryEventArgs = {
    Story = nil,
    Storyline = nil
}

function StoryGroup:New(groupName)
    local sg = routines.utils.deepCopy(StoryGroup)
    sg.Group = GROUP:FindByName(groupName)
    if not sg.Group then
        error("StoryGroup:New :: group not found: " .. groupName) end

    sg.GroupName = groupName
    return sg
end

function Story:FindStoryline(storylineName)
    for _, storyline in ipairs(self.Storylines) do
        if storyline.Name == storylineName then
            return storyline
        end
    end
    return nil
end

function StoryGroup:Run(time)
    if self._storyline.State == StorylineState.Pending then
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

function Storyline:New(name, description)
    local ms = routines.utils.deepCopy(Storyline)
    ms.Name = name
    ms.Description = description
    return ms
end

function StorylineWaiting(name, description)
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
    for _, sg in ipairs(arg) do
        if isString(sg) then
            sg = StoryGroup:New(sg)
        end
        sg._storyline = self
        table.insert(self.Groups, sg)
    end
    return self
end

function Storyline:FindGroup(groupName)
    for _, sg in ipairs(self.Groups) do
        if sg.GroupName == groupName then
            return sg
        end
    end
end

function Storyline:FindUnit(unitName)
    for _, sg in ipairs(self.Groups) do
        local index = tableIndexOf(sg.Group:GetUnits(), function(unit) return unit.UnitName == unitName end)
        if index > 0 then
            return true 
        end
    end
end

function Storyline:Run(time)
    if not self.Enabled then
        return self
    end
    for _, sg in ipairs(self.Groups) do
        sg:Run(time)
    end
    self._isIdle = false
    self.State = StorylineState.Running
    if self.OnStartedFunc ~= nil then
        self.OnStartedFunc(StoryEventArgs:New(self))
    end
    return self
end

function Story:RunStoryline(storylineName)
    if not isString(storylineName) then 
        error("Story:RunStoryline :: storylineName was unassigned") end

    local storyline = self:FindStoryline(storylineName)
    if storyline and storyline.State == StorylineState.Pending then
        Trace("Story-".. self.Name .." :: starts storyline '" .. storyline.Name .. "' ...")
        storyline:Run()
    end
    return self
end

function StoryEventArgs:New(storyline)
    local args = routines.utils.deepCopy(StoryEventArgs)
    args.Story = storyline._story
    args.Storyline = storyline
    return args
end

function StoryEventArgs:FindStoryline(storylineName)
    return self.Story:FindStoryline(storylineName)
end

function StoryEventArgs:RunStoryline(storylineName)
    return self.Story:RunStoryline(storylineName)
end

function StoryEventArgs:RunStory(storyName)
    return self.Story:RunStory(storyName)
end

function Storyline:_startIfDue(time)
    if not self.Enabled or self._isIdle or (self.StartTime ~= nil and self.StartTime > time) then
        return false end
    
    if self.StartConditionFunc ~= nil and not self.StartConditionFunc(StoryEventArgs:New(self)) then
        return false end

    self:Run(time)
    return true
end

function Storyline:End()
    if self.State ~= StorylineState.Running then
        return end

    if self._onUnitDeadFunc then
        MissionEvents:EndOnUnitDead(self._onUnitDeadFunc)
    end
    self.State = StorylineState.Done
    if self.OnEndedFunc ~= nil then
        self.OnEndedFunc(StoryEventArgs:New(self))
    end
end

function Storyline:_endOnCondition(now)
    if self.State ~= self.Running then
        return false
    end
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

function Storyline:OnAircraftLanded(aircraft, func)
    if aircraft ~= nil then
        aircraft = getUnit(aircraft)
        if aircraft then
            if not self:FindUnit(aircraft) then
                error("Storyline:OnGroupDiverted :: unit is not in storyline: " .. aircraft.UnitName) 
            end
        else
            error("Storyline:OnGroupDiverted :: cannot resolve aircraft from: " .. Dump(aircraft))
        end
    end
    if not isFunction(func) then
        error("Storyline:OnUnitLanded :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        -- only trigger for units in storyline ...
        if aircraft and aircraft.UniName ~= event.IniUnitName then
            return end
        if not self:FindGroup(event.IniGroupName) then
            return end

        MissionEvents:EndOnAircraftLanded(eventFunc)
        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    MissionEvents:OnAircraftLanded(eventFunc)
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
        -- only trigger for specified group or groups in storyline ...
        if group and group.GroupName ~= event.IniGroupName then
            return end
        if not self:FindGroup(event.IniGroupName) then
            return end

        MissionEvents:EndOnGroupDiverted(eventFunc)
        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    MissionEvents:OnGroupDiverted(eventFunc)
    return self
end

function Storyline:OnGroupEntersZone(group, zone, func, continous)

    if not isFunction(func) then
        error("Storyline:OnGroupEntersZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        -- only trigger for groups in storyline ...
        if not self:FindGroup(event.IniGroupName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    MissionEvents:OnGroupEntersZone(group, zone, func, continous)
    return self
end

function Storyline:OnGroupInsideZone(group, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnGroupInsideZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        -- only trigger for groups in storyline ...
        if not self:FindGroup(event.IniGroupName) then
            error("Storyline:OnGroupInsideZone :: group is not part of storyline '" .. self.Name .. "': " .. event.IniGroupName)
            return 
        end
        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    MissionEvents:OnGroupInsideZone(group, zone, func, continous)
    return self
end

function Storyline:OnGroupLeftZone(group, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnGroupLeftZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        -- only trigger for groups in storyline ...
        if not self:FindGroup(event.IniGroupName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    MissionEvents:OnGroupLeftZone(group, zone, func, continous)
    return self
end

function Storyline:OnUnitEntersZone(unit, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitEntersZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        -- only trigger for units in storyline ...
        if not self:FindUnit(event.IniUnitName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    MissionEvents:OnUnitEntersZone(unit, zone, func, continous)
    return self
end

function Storyline:OnUnitInsideZone(unit, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitInsideZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        -- only trigger for units in storyline ...
        if not self:FindUnit(event.IniUnitName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
    MissionEvents:OnUnitInsideZone(unit, zone, func, continous)
    return self
end

function Storyline:OnUnitLeftZone(unit, zone, func, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitLeftZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        -- only trigger for units in storyline ...
        if not self:FindGroup(event.IniUnitName) then
            return end

        event = copyTo(StoryEventArgs:New(self), event)
        func(event)
    end
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

function Story:New(name, ...)
    local story = routines.utils.deepCopy(Story)
    story.Name = name
    if not isAssignedString(name) then
        error("Story:New :: story name was unspecified") end

    for _, storyline in ipairs(arg) do
        table.insert(story.Storylines, storyline)
        storyline._story = story
    end
    table.insert(_allStories, story)
    return story
end

function Story:Complete(missionStoryName)
end

function Story:Run(interval)
    if not isNumber(interval) then
        interval = 1
    end

    local function onTimer()
        local now = MissionTime()
        if not self.Enabled then
            return end
        
        for _, storyline in ipairs(self.Storylines) do
            if storyline.State == StorylineState.Pending then
                storyline:_startIfDue(now)
            elseif storyline.State == StorylineState.Running then
                storyline:_endOnCondition(now)
            end
        end
    end

    self._timer = TIMER:New(onTimer):Start(1, interval)
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

function Story:RunStory(storyName)
    if not isAssignedString(storyName) then
        Warning("Story:RunStory :: storyName was unassigned :: IGNORES")
        return
    end

    local story = Story:FindStory(storyName)
    if not story then
        Warning("Story:RunStory :: story was not found: '" .. storyName .. "' :: IGNORES")
        return
    end
    story:Run()
    return story
end