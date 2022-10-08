
--require "DCAF.Core"
local StoryGroupIndex = {     -- used for keeping track of GROUPs, and how they are related to stories
    GroupName = nil,          -- string; name of group
    StoryGroup = nil,         -- <Storygroup>
    Group = nil,              -- <GROUP> (MOOSE object)
    Stories = {},             -- key = story name, value = { list of <Story> where group partakes }
    Storylines = {},          -- key = story name, value = { list of <Storyline> where group partakes }
    CountStories = 0,         -- integer; number of stories controlling the <GROUP>
    CountStorylines = 0,      -- integer; number of storylines controlling the <GROUP>
}

local StoryState = {
    Pending = 1,
    Running = 2,
    Done = 3
}

local StoryInfo = {           -- items in StoryDB.Info.Story
    State = StoryState.Pending,
    Name = nil,               -- unique name of storyline
    Storylines = {},          -- list of <Storyline>
    Groups = {},              -- key = group name, value = <StoryGroup>
    CountGroups = 0,          -- number of groups controlled by story
    _type = "StoryInfo"
}

local StorylineInfo = {       -- items in StoryDB.Info.Storyline
    State = StoryState.Pending,
    Name = nil,               -- unique name of storyline
    Story = nil,              -- the story where storyline is part
    Groups = {},              -- key = group name, value = <StoryGroup>
    CountGroups = 0,          -- number of groups controlled by story
    _type = "StorylineInfo"
}

local Type = {
    Story = "Story",
    Storyline = "Storyline",
}

local StoryDB = {
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
    },
    Info = {
        Story = {
            -- key = storyline name, value = <StoryInfo>
        },
        Storyline = {
            -- key = storyline name, value = <StorylineInfo>
        }
    }
}

StoryScope = {
    None = 'None',            -- no sandbox in use (completely unrestricted)
    Story = 'Story',          -- sandbox is Story (eg. one stoyline may destroy groups in other Storylines of same Story)
    Storyline = 'Storyline'   -- sandbox is Storyline (eg. storyline cannot affect state of other storylines, other than starting them)
}

function StoryScope:IsValid(s)
    return s == StoryScope.None or s == StoryScope.Story or s == StoryScope.Storyline
end

StoryConfiguration = {
    Sandbox = StoryScope.Storyline   -- <StoryScope>
}

Story = {
    Name = nil,               -- unique name of the story
    Description = nil,        -- string, Story description
    Enabled = true,           -- must be set for stories to activate
    Config = nil,             -- <StoryConfiguration> 
    _type = Type.Story,       -- type identifier (needed by StoryIndex:GetInfo)
    _timer = nil,
    _onStartedHandlers = {},  -- list of <function(<Story>)
    _onEndedHandlers = {}     -- list of <function(<Story>)
}

Storyline = {
    Name = nil,               -- unique name of the storyline (see also Storyline:FullName())
    Description = nil,        -- (optional) story line description 
    -- WasCancelled = false,     -- when set, storyline was cancelled (todo: to be implemented)
    Enabled = true,           -- must be set for story to activate
    Level = nil,              -- (DifficultyLevel) optional; when set story will only run if level is equal or higher
    StartTime = nil,          -- how long (seconds) into the mission before story begins
    Config = nil,             -- <StoryConfiguration>
    _type = Type.Storyline,   -- type identifier (needed by StoryIndex:GetInfo)

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
    StorylineName = nil,     -- identifies the srory group's controlling <Storyline>
}

StoryEventArgs = {
    Story = nil,
    Storyline = nil
}

function StoryConfiguration:New()
    return DCAF.clone(StoryConfiguration)
end


------------------------------- [ INDEXING ] -------------------------------

local function nisse_get_all_storyline_info()
    local s = ""
    for name, info in pairs(StoryDB.Info.Storyline) do
        s = DumpPretty(
            {
                _debugId = info._debugId,
                storyline = name,
                groups = DumpPretty(info.Groups)
            }) .. "\n........................................."
    end
    return s .. "------------------------------------------------"
end

function StoryDB:GetStory(name)
    return StoryDB.Stories[name]
end

function StoryDB:GetStoryInfo(name)
    return StoryDB.Info.Story[name]
end

function StoryDB:GetStoryline(name)
    return StoryDB.Storylines[name]
end

function StoryDB:GetStorylineInfo(name)
    return StoryDB.Info.Storyline[name]
end

function StoryDB:GetInfo(item)
    if item._type == Type.Story then
        return StoryDB:GetStoryInfo(item.Name)
    elseif item._type == Type.Storyline then
        return StoryDB:GetStorylineInfo(item.Name)
    end
end

function StoryDB:SetState(item, state)
    StoryDB:GetInfo(item).State = state
end

function StoryDB:GetState(item)
    return StoryDB:GetInfo(item).State
end

function StoryDB:GetGroup(name)
    local index = StoryDB.Groups[name]
    if index then
        return index.StoryGroup
    end        
end

function StoryInfo:New(story)
    local info = DCAF.clone(StoryInfo)
    info.Name = story.Name
    return info
end

function StoryInfo:AddGroup(storyGroup)
    if self.Groups[storyGroup.Name] then
        error("StoryInfo:AddGroup :: group was already added: " .. storyGroup.Name) end
    
    self.Groups[storyGroup.GroupName] = storyGroup
    self.CountGroups = self.CountGroups+1
end

function StorylineInfo:New(storyline)
    local info = DCAF.clone(StorylineInfo)
    info.Name = storyline.Name
    return info
end

function StorylineInfo:AddGroup(storyGroup)
    if self.Groups[storyGroup.Name] then
        error("StorylineInfo:AddGroup :: group was already added: " .. storyGroup.Name) end

    self.Groups[storyGroup.GroupName] = storyGroup
    self.CountGroups = self.CountGroups + 1
end

function StoryGroupIndex:New(storyGroup, storyline)
    local index = DCAF.clone(StoryGroupIndex)
    index.GroupName = storyGroup.GroupName
    index.StoryGroup = storyGroup
    index.Group = storyGroup.Group

    -- add to story
    local story = storyline:GetStory()
    if story then
        index.Stories[story.Name] = story
        local info = StoryDB:GetInfo(story)
        info:AddGroup(storyGroup)
    end
    index.Storylines[storyline.Name] = storyline
    
    -- add to controlling storyline ...
    StoryDB:GetInfo(storyline):AddGroup(storyGroup)
    return index
end

function StoryGroupIndex:Update(storyGroup, storyline)
    local story = storyline:GetStory()
    if story then
        self.Stories[story.Name] = story
        local info = StoryDB:GetInfo(story)
        if not info.Groups[self.GroupName] then
            info:AddGroup(self)
        end
    end

    self.Storylines[storyline.Name] = storyline
    local info = StoryDB:GetInfo(storyline)
    if not info.Groups[self.GroupName] then
        info:AddGroup(self)
    end
    return self
end

function StoryDB:AddGroup(storyGroup, storyline)
    local index = StoryDB.Groups[storyGroup.GroupName]
    if index then
        index:Update(storyGroup, storyline)
        return
    end
    index = StoryGroupIndex:New(storyGroup, storyline)
    StoryDB.CountGroups = StoryDB.CountGroups + 1
    StoryDB.Groups[storyGroup.GroupName] = index
end

function StoryDB:GetStorylineGroups(storyline, ...)
    local storylineGroups = StoryDB:GetInfo(storyline).Groups
    if arg.n == 0 then
        return storylineGroups end

    local named = {}
    for _, name in ipairs(arg) do
        local exists = storylineGroups[name]
        if exists then
            named[name] = exists
        end
    end
    return named
end

function StoryDB:AddStoryLineToStory(storyline, story)
    local si = StoryDB:GetInfo(story)
    if not si then 
        error("Cannot find story info for '" .. storyline.Name .. "'") end

    local sli = StoryDB:GetInfo(storyline)
    if not sli then 
        error("Cannot find storyline info for '" .. storyline.Name .. "'") end

    if sli.Story ~= nil then
        error("Storyline was already added to a story ('" .. sli.Story.Name .. "')") end

    table.insert(si.Storylines, storyline)
    sli.Story = story

    -- update story groups ...
    for sgName, sg in pairs(sli.Groups) do
        local sgIndex = StoryDB.Groups[sg.GroupName]
        sgIndex:Update(sg, storyline)
    end
end

function StoryDB:AddStoryline(storyline)
    if StoryDB.Storylines[storyline.Name] then
        return end

    StoryDB.Storylines[storyline.Name] = storyline
    StoryDB.CountStorylines = StoryDB.CountStorylines + 1
    StoryDB.Info.Storyline[storyline.Name] = StorylineInfo:New(storyline)
end

function StoryDB:AddStory(story)
    if StoryDB.Info.Story[story.Name] then
        error("Another story called '"..story.Name.."' was already created") end

    StoryDB.Stories[story.Name] = story
    StoryDB.CountStories = StoryDB.CountStories + 1
    StoryDB.Info.Story[story.Name] = StoryInfo:New(story)
    return story
end

function StoryDB:GetGroupStories(groupName)
    local index = StoryDB.Groups[groupName]
    if index ~= nil then
        return index.Stories
    end
    return {}
end

function StoryDB:CountGroupStories(groupName)
    local index = StoryDB.Groups[groupName]
    if index ~= nil then
        return index.CountStoryies
    end
    return 0
end

function StoryDB:GetGroupStorylines(groupName)
    local index = StoryDB.Groups[groupName]
    if index ~= nil then
        return index.Storylines
    end
    return {}
end

function StoryDB:CountGroupStorylines(groupName)
    local index = StoryDB.Groups[groupName]
    if index ~= nil then
        return index.CountStorylines
    end
    return 0
end

function StoryDB:IsGroupExclusiveToStory(groupName, story)
    local index = StoryDB.Groups[groupName]
    if index == nil or index.CountStories ~= 0 then 
        return false end

    return index.Stories[story.Name] ~= nil
end

function StoryDB:IsGroupExclusiveToStoryline(groupName, storyline)
    local index = StoryDB.Groups[groupName]
    if index == nil or index.CountStorylines ~= 0 then 
        return false end

    return index.Storylines[storyline.Name] ~= nil
end


------------------------------- [ STORY GROUP ] -------------------------------

function StoryGroup:New(groupName, storyline)
    local storyGroup = DCAF.clone(StoryGroup)
    storyGroup.Group = GROUP:FindByName(groupName)
    if not storyGroup.Group then
        error("StoryGroup:New :: group not found: " .. groupName) end

    storyGroup.GroupName = groupName
    storyGroup.StorylineName = storyline.Name
    return storyGroup
end

function Story:FindStoryline(storylineName)
    local storylines = self:GetStorylines()
    local index = tableIndexOf(self:GetStorylines(), function(sl) return sl.Name == storylineName end)
    if index then
        return storylines[index] 
    end
end

function StoryGroup:IsPending()
    local info = StoryDB:GetStorylineInfo(self.StorylineName)
    return info.State == StoryState.Pending
end

function StoryGroup:Run()
    if self:IsPending() then
        self.Group = activateNow(self.GroupName)
    else
        self.Group = spawnNow(self.GroupName)
    end
    return self
end

function StoryGroup:Destroy()
    if self.Group then
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
    local storyline = DCAF.clone(Storyline)
    storyline.Name = name
    storyline.Description = description
    StoryDB:AddStoryline(storyline)
    return storyline
end

function Storyline:NewIdle(name, description)
    local storyline = Storyline:New(name, description)
    storyline._isIdle = true
    return storyline
end

function Storyline:SandboxScope()
    return self.Config.Sandbox
end

function Storyline:FullName()
    local story = self:GetStory()
    if story ~= nil then
        return story.Name ..'/'..self.Name
    end
    return self.Name
end

function Storyline:GetStory()
    local info = StoryDB:GetInfo(self)
    if info then
        return info.Story
    end
end

function Storyline:WithDescription(description)
    if description ~= nil and not isString(description) then
        error("Storyline:WithDescription :: unexpected type for description: " .. type(description)) end

    self.StoryDescription = description
    return self
end

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
    if self:GetStory() ~= nil then
        error("Storyline:WithGroups :: cannot initialize Storyline using 'WithGroup' after Storyline was added to story. Please use 'Storyline:AddGroups' instead") end

    for _, group in ipairs(arg) do
        local storyGroup = nil
        if isString(group) then
            storyGroup = StoryGroup:New(group, self)
        end
        storyGroup.Storyline = self
        StoryDB:AddGroup(storyGroup, self)
    end
    return self
end

function Storyline:GetState() return StoryDB:GetState(self) end
function Storyline:IsPending() return self:GetState() == StoryState.Pending end
function Storyline:IsRunning() return self:GetState() == StoryState.Running end
function Storyline:IsDone() return self:GetState() == StoryState.Done end

function Storyline:FindGroup(groupName)
    local info = StoryDB:GetInfo(self)
    return info[groupName]
end

function Storyline:FindUnit(unitName)
    local info = StoryDB:GetInfo(self)
    for _, storyGroup in pairs(info.Groups) do
        local key = tableKeyOf(storyGroup.Group:GetUnits(), function(unit) return unit.UnitName == unitName end)
        if key then
            return true 
        end
    end
end

function Storyline:Run()
    if not self.Enabled then
        return self end

    local storyGroups = StoryDB:GetStorylineGroups(self)
    for _, storyGroup in pairs(storyGroups) do
        storyGroup:Run()
    end
    self._isIdle = false
    StoryDB:SetState(self, StoryState.Running)
    DCAFEvents:ActivateFor(self.Name)
    if self.OnStartedFunc ~= nil then
        self.OnStartedFunc(StoryEventArgs:New(self))
    end
    return self
end

function Storyline:RunDelayed(delaySeconds, func)
    if not isNumber(delaySeconds) then
        errorOnDebug("Storyline:RunDelayed :: delaySeconds is unassigned or of unexpected value: " .. tostring(delaySeconds))
        return self
    end

    Delay(delaySeconds, function()
        self:Run()
        if isFunction(func) then
            func(self)
        end
    end)
end

-- function Storyline:Restart()
--     if self:IsPending() then
--         return self:Run()
--     end
--     -- todo Consider supporting restarting storylines
-- end

-- function Storyline:RestartDelayed(delay)
--     if self:IsPending() then
--         return self:RunDelayed(delay)
--     end
--     -- todo Consider supporting restarting storylines
-- end

function StoryEventArgs:New(storyline)
    local args = DCAF.clone(StoryEventArgs)
    args.Story = storyline:GetStory().Name
    args.Storyline = storyline.Name
    return args
end

function StoryEventArgs:FindStoryline(storylineName)
    return StoryDB:GetStory(self.Story):FindStoryline(storylineName)
end

function StoryEventArgs:RunStoryline(storylineName)
    return StoryDB:GetStory(self.Story):RunStoryline(storylineName)
end

function StoryEventArgs:RunStorylineDelayed(storylineName, delay, func)
    return StoryDB:GetStory(self.Story):RunStorylineDelayed(storylineName, delay, func)
end

function StoryEventArgs:RunStory(storyName)
    return Story:RunStory(storyName)
end

function StoryEventArgs:RunStoryDelayed(storyName, delay)
    return Story:RunStoryDelayed(storyName, delay)
end

function StoryEventArgs:EndStoryline()
    StoryDB:GetStoryline(self.Storyline):End()
end

function StoryEventArgs:EndStory()
    StoryDB:GetStory(self.Story):End()
end

function StoryEventArgs:DestroyStoryGroups(...)
    return StoryDB:GetStory(self.Storyline):DestroyGroups(...)
end

function StoryEventArgs:DestroyStorylineGroups(...)
    return StoryDB:GetStoryline(self.Storyline):DestroyGroups(...)
end

function StoryEventArgs:DestroyGroups(...)
    if arg.n == 0 then
        arg[1] = StoryScope.Storyline
        arg.n = 1
    end
    if arg.n == 1 and isString(arg[1]) and StoryScope:IsValid(arg[1]) then
        local scope = arg[1]
        if scope == StoryScope.None then
            error("StoryEventArgs:DestroyGroups :: scope cannot be '" .. scope .. "' when destroying groupes") -- todo or can it?
        elseif scope == StoryScope.Story then
            self:DestroyStoryGroups()
        elseif scope == StoryScope.Storyline then
            self:DestroyStorylineGroups()
        else
            error("StoryEventArgs:DestroyGroups :: unknown scope: '" .. scope)
        end
        return
    end
    error("todo : StoryEventArgs:DestroyGroups :: implement support for destroying named groups")
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
    StoryDB:SetState(self, StoryState.Done)
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

function Storyline:DestroyGroup(group)
    -- todo ensure configured Sandbox Scope is honored
    
    if group == nil then
        error("Storyline:DestroyGroup :: group was unassigned") end

    group = getGroup(group)
    if group == nil then
        error("Storyline:DestroyGroup :: group cannot be resolved from: " .. Dump(group)) end

    local sandboxScope = self:SandboxScope()
    if sandboxScope == StoryScope.Story and not StoryDB:IsGroupExclusiveToStory(group.GroupName, self:GetStory()) then
        error("Storyline:DestroyGroup :: cannot destroy group that are also controlled by other stories (see sandbox configuration)") end

    if sandboxScope == StoryScope.Storyline and not StoryDB:IsGroupExclusiveToStoryline(group.GroupName, self) then
        error("Storyline:DestroyGroup :: cannot destroy group that are also controlled by other storylines (see sandbox configuration)")  end

    local sg = StoryDB:GetGroup(group.GroupName)
    if sg then
        sg:Destroy()
    else
        group:Destroy()
    end
    return self
end

function Storyline:DestroyGroups(...)
    local groups = nil
    groups = StoryDB:GetStorylineGroups(self, ...)
    for _, storyGroup in pairs(groups) do
        self:DestroyGroup(storyGroup.Group)
    end
    return self
end

function Storyline:StopGroups(...)
    local groups = arg
    if not arg then
        groups = self.Groups
    end
    for _, sg in ipairs(self.Groups) do
        sg:Stop()
    end
    return self
end

function Storyline:_addPendingDelagate(eventName, func)

end

function Storyline:OnRun(func)
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
        if not self:IsRunning() then
            return end

        -- only trigger for specified aircraft ...
        local testUnitName = event.IniGroupName 
        if aircraft and not isStorylineEventUnit(self, aircraft, event.IniUnit) then
            return end

        -- this is a one-time event ... 
        MissionEvents:EndOnAircraftLanded(eventFunc)
        event = copyTo(StoryEventArgs:New(self), event)
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
        storyline.Config = DCAF.clone(story.Config)
        if index then
            StoryDB:AddStoryline(storyline)
            StoryDB:AddStoryLineToStory(storyline, story)
        end
    end
end

function Story:New(name, ...)
    local story = DCAF.clone(Story)
    story.Name = name
    story.Config = StoryConfiguration:New()
    if not isAssignedString(name) then
        error("Story:New :: story name was unspecified") end

    if arg then
        story:WithStorylines(...)
    end
    StoryDB:AddStory(story)
    return story
end

function Story:GetStorylines()
    local info = StoryDB:GetInfo(self)
    if info then
        return info.Storylines
    end
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
        StoryDB:SetState(self, StoryState.Running)
        local now = MissionTime()
        if not self.Enabled then
            return end
        
        for _, storyline in ipairs(self:GetStorylines()) do
            if storyline:IsPending() then
                storyline:_runIfDue(now)
            elseif storyline:IsRunning() then
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

function Story:RunStoryline(storylineName, restart)
    if not isString(storylineName) then
        return errorOnDebug("Story:RunStoryline :: unexpected type for storylineName: " .. type(storylineName)) end

    local storyline = self:FindStoryline(storylineName)
    if not storyline then
        return errorOnDebug("Story:RunStoryline :: storyline '".. storylineName .. "' not found in story '" .. self.Name .. "'") end

    if storyline:IsPending() then
        storyline:Run()
    elseif restart then
        storyline:Restart()
    end
    return self
end

function Story:RunStorylineDelayed(storylineName, delay, func, restart)
    if not isString(storylineName) then
        return errorOnDebug("Story:RunStorylineDelayed :: unexpected type for storylineName: " .. type(storylineName)) end

    local storyline = self:FindStoryline(storylineName)
    if not storyline then
        return errorOnDebug("Story:RunStoryline :: storyline '".. storylineName .. "' not found in story '" .. self.Name .. "'") end

    if storyline:IsPending() then
        storyline:RunDelayed(delay, func)
    elseif restart then
        storyline:RestartDelayed(delay, func)
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
    for _, storyline in ipairs(self:GetStorylines()) do
        if storyline._onStoryEndedFunc then
            local success, err = pcall(storyline._onStoryEndedFunc(self))
            if not success then
                errorOnDebug("Story:End :: error when invoke Storyline:OnStoryEnded handler. " .. tostring(err))
            end
        end
    end
    StoryDB:SetState(self, StoryState.Done)
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

    for _, story in ipairs(StoryDB.Stories) do
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