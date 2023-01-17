--require "DCAF.Core"

local ModuleName = "DCAF Narrator"

local GroupInfo = {           -- used for keeping track of a GROUP and how it relate to stories & storylines
    Name = nil,               -- string; name of <GROUP>
    Group = nil,              -- <GROUP> (MOOSE object); the GROUP template
    UnitsInfo = {},           -- { key = unit name, value = <UnitInfo> }
    Stories = {},             -- list of stories that control this group; key = story name, value = <Story> 
    Storylines = {},          -- list of storylines that control this group; key = story name, value = <Storyline>
    CountStories = 0,         -- integer; number of stories controlling the <GROUP>
    CountStorylines = 0,      -- integer; number of storylines controlling the <GROUP>
    WasActivatedBy = nil,     -- nil, <Story>, or <Storyline>
    WasDestroyedBy = nil,     -- nil, <Story>, or <Storyline>
    Spawn = nil,              -- <SPAWN> (MOOSE spawn object)
}

local GroupActivationType = { -- represents the use of a group from a Storyline
    GroupInfo = nil,          -- <GroupInfo>
}

local StoryItemGroupInfo = {  -- represents the usage of a group for a Storyline

}

local UnitInfo = {            -- used for keeping track of a GROUPs and how it relate to stories/storylines
    Name = nil,               -- string; name of <UNIT>
    Unit = nil,               -- <GROUP> (MOOSE object)
    GroupName = nil,          -- string; name of group (see UnitInfo:GetGroupInfo())
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
    Groups = {},              -- key = group name, value = <GroupInfo>
    CountGroups = 0,          -- number of groups controlled by story
    Config = nil,             -- <StoryConfiguration>
    ActiveGroups = {},        -- { key = group name (template); value = { list of GROUP (activated or spawned)} }
    _type = "StoryInfo"
}

local ActiveUnit = {
    Name = nil,               -- string; name of active unit
    Unit = nil,               -- <UNIT> (the activated/spawned MOOSE unit)
    Group = nil,              -- <GROUP> (activated or spawned)
    GroupInfo = nil,          -- <GroupInfo> template information
}

local FirstActivationType = {
    Activate = "Activate",
    Spawn = "Spawn"
}

local StoryItemGroupInfo = {  -- represents an assoiation between a Story/Storyline and a GroupInfo object
    FirstActivationType = nil,  -- <FirstActivationType>
    GroupInfo = nil,          -- <GroupInfo>
}

local StorylineInfo = {       -- items in StoryDB.Info.Storyline
    State = StoryState.Pending,
    Name = nil,               -- unique name of storyline
    Story = nil,              -- the story where storyline is part
    Groups = {},              -- key = group name, value = <GroupInfo>
    CountGroups = 0,          -- number of groups controlled by story
    Config = nil,             -- <StoryConfiguration>
    ActiveGroups = {},        -- { key = group name (template); value = { list of GROUP (activated or spawned)} }
    ActiveUnits = {},         -- { key = unit name; value = <ActiveUnit> }
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
        -- key = group name; value = <GroupInfo>
    },
    Units = {
        -- key = unit name; value = <UnitInfo>
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
    Story = Type.Story,       -- sandbox is Story (eg. one stoyline may destroy groups in other Storylines of same Story)
    Storyline = Type.Storyline  -- sandbox is Storyline (eg. storyline cannot affect state of other storylines, other than starting them)
}

function StoryScope:IsValid(s)
    return s == StoryScope.None or s == StoryScope.Story or s == StoryScope.Storyline
end

StoryConfig = {
    Scope = {
        Group = nil           -- <StoryScope>; governs the scope for the configured items ability to control/destroy groups
        -- todo this is the place to support more types of control scopes (maybe statics etc.)
    }
}

Story = {
    _type = Type.Story,       -- type identifier (needed by StoryIndex:GetInfo)
    Name = nil,               -- unique name of the story
    Description = nil,        -- string, Story description
    Enabled = true,           -- must be set for stories to activate
    Config = nil,             -- <StoryConfiguration> 
    _timer = nil,
    _onStartedHandlers = {},  -- list of <function(<Story>)
    _onEndedHandlers = {}     -- list of <function(<Story>)
}

Storyline = {
    _type = Type.Storyline,   -- type identifier (needed by StoryIndex:GetInfo)
    Name = nil,               -- unique name of the storyline (see also Storyline:FullName())
    Description = nil,        -- (optional) story line description 
    -- WasCancelled = false,  -- when set, storyline was cancelled (todo: to be implemented)
    Enabled = true,           -- must be set for story to activate
    Level = nil,              -- (DifficultyLevel) optional; when set story will only run if level is equal or higher
    StartTime = nil,          -- how long (seconds) into the mission before story begins
    StartConditionFunc = nil, -- callback function(<self>, <MissionStories>) , returns true when story should start
    EndConditionFunc = nil,   -- callback function(<self>, <MissionStories>) , returns true when story should end
    _activeGroups = {},       -- { list of GROUP (activated or spawned) }

    -- event handlers
    OnStartedFunc = nil,      -- event handler: triggered when story starts
    OnEndedFunc = nil         -- event handler: triggered when story ends
}

StorylineIdle = {}

StoryEventArgs = {
    Story = nil,
    Storyline = nil
}

function StoryConfig:New()
    return DCAF.clone(StoryConfig)
end

function ActiveUnit:New(unit, groupInfo)
    local au = DCAF.clone(ActiveUnit)
    au.Name = unit.UnitName
    au.Unit = unit
    au.Group = unit:GetGroup()
    au.GroupInfo = groupInfo
    return au
end

------------------------------ [ INTERNALS ] -------------------------------

local function internalError(message)
    error("[" .. ModuleName .. "] INTERNAL ERROR :: " .. message)
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

function StoryDB:GetState(item)
    return StoryDB:GetInfo(item).State
end

function StoryDB:SetState(item, state)
    StoryDB:GetInfo(item).State = state
end

function StoryDB:GetConfiguration(item)
    return StoryDB:GetInfo(item).Config
end

function StoryDB:GetGroupScope(item)
    local scope = StoryDB:GetConfiguration(item).Scope.Group
    if not scope and item._type == Type.Storyline then
        -- fall back to Story scope, if storyline is attached to story at this point ...
        local story = item:GetStory()
        if story then
            return story:GetGroupScope()
        end
    end
    return scope
end

function StoryDB:SetGroupScope(item, scope)
    local config = StoryDB:GetConfiguration(item)
    config.Scope.Group = scope
end

function StoryDB:GetGroupInfo(name)
    return StoryDB.Groups[name]
end

function StoryDB:GetGroup(name)
    local info = StoryDB.GetGroupInfo(name)
    if info then
        return info.Group
    end
end

function StoryDB:IsUnitInstanceOf(unit, templateUnit)

end

function StoryInfo:New(story)
    local info = DCAF.clone(StoryInfo)
    info.Name = story.Name
    info.Config = StoryConfig:New()
    return info
end

function StorylineInfo:New(storyline)
    local info = DCAF.clone(StorylineInfo)
    info.Name = storyline.Name
    info.Config = StoryConfig:New()
    return info
end

function GroupInfo:AssociateWith(item)
    if item._type == Type.Story then
        if self.Stories[item.Name] then
            internalError("Group " .. self.Name .. " was already associated with " .. item:ToString()) end

        self.Stories[item.Name] = item
        self.CountStories = self.CountStories + 1
    elseif item._type == Type.Storyline then
        if self.Storylines[item.Name] then
            internalError("Group " .. self.Name .. " was already associated with " .. item:ToString()) end
            
        self.Storylines[item.Name] = item
        self.CountStorylines = self.CountStorylines + 1
    else
        internalError("Cannot add group to (unsupported) item: " .. Dump(item))
    end
    return self
end

function GroupInfo:IsAssociatedWith(item)
    if item._type == Type.Story then
        return self.Stories[item.Name] ~= nil
    elseif item._type == Type.Storyline then
        return self.Storylines[item.Name] ~= nil
    else
        internalError("GroupInfo:AssociateWith :: cannot associate group '" .. self.Name .. "' with item: " .. DumpPretty(item))
    end
end

function UnitInfo:New(unit, groupInfo)
    local info = DCAF.clone(UnitInfo)
    info.Name = unit.UnitName
    info.Unit = unit
    info.GroupName = groupInfo.Name
    return info
end

function UnitInfo:GetGroupInfo() return StoryDB.Groups[self.GroupName] end

function GroupInfo:New(group)
    local info = DCAF.clone(GroupInfo)
    info.Name = group.GroupName
    info.Group = group
    local units = group:GetUnits()
    for _, unit in ipairs(units) do
        info.UnitsInfo[unit.UnitName] = UnitInfo:New(unit, info)
    end
    return info
end

function GroupInfo:RunBy(item)
    self.Spawn = self.Spawn or SPAWN:New(self.Name)
    local group = self.Spawn:Spawn()
Debug("nisse - GroupInfo:RunBy :: group.GroupName: '" .. group.GroupName .. "' :: SPAWNED")
    return StoryDB:AddActiveGroupBy(item, self, group)
-- local group = nil
--     if not self.WasActivatedBy and not self.WasDestroyedBy then
--         group = activateNow(self.Group)
-- Debug("nisse - GroupInfo:RunBy :: group.GroupName: '" .. group.GroupName .. "' :: ACTIVATED")
--         self.WasActivatedBy = item
--     else
--         group = spawnNow(self.Group)
-- Debug("nisse - GroupInfo:RunBy :: group.GroupName: '" .. group.GroupName .. "' :: SPAWNED")
--     end
--     return StoryDB:AddActiveGroupBy(item, self, group)
end

function StoryDB:AssociateGroupsWith(item, ...)
    local count = 0
    local itemInfo = StoryDB:GetInfo(item)
    if not itemInfo then
        internalError("Cannot add groups to " .. item:ToString() .. " :: item has no internal info") end

    for _, group in ipairs(arg) do
        local g = getGroup(group)
        if not g then
            error("Cannot add groups to " .. item:ToString() .. " :: group cannot be resolved from: '" .. Dump(group) .. "'") end

        local groupInfo = StoryDB.Groups[g.GroupName]
        if not groupInfo then
            groupInfo = GroupInfo:New(g)
            StoryDB.Groups[g.GroupName] = groupInfo
            for unitName, unitInfo in pairs(groupInfo.UnitsInfo) do
                StoryDB.Units[unitName] = unitInfo
            end
        end
        groupInfo:AssociateWith(item)
        itemInfo.Groups[g.GroupName] = groupInfo
        count = count+1
    end
    return count > 0, count
end

function StoryDB:FindAssociatedGroupInfo(item, group)
    local name = nil
    if isAssignedString(group) then
        name = group
    elseif isUnit(group) then
        name = name.UnitName
    end

    local groupInfo = StoryDB.Groups[name]
    if not groupInfo then
        return end

    -- we have group info; but only return <GROUP> if there's an association with the item ...
    local associatedItems = nil
    local itemInfo = StoryDB:GetInfo(item)
    if item._type == Type.Storyline then
        associatedItems = groupInfo.Storylines
    elseif item._type == Type.Stories then
        associatedItems = groupInfo.Stories
    end
    for itemName, _ in pairs(associatedItems) do
        if itemName == item.Name then
            return groupInfo
        end
    end
end

function StoryDB:FindAssociatedGroup(item, group)
    local info = self:FindAssociatedGroupInfo(item, group)
    if info then
        return info.Group 
    end
end

function StoryDB:FindAssociatedUnit(item, unit, nisse)
    local name = nil
    if isAssignedString(unit) then
        name = unit
    elseif isUnit(unit) then
        name = unit.UnitName
    else
        error("StoryDB:FindAssociatedUnit :: unexpected value for `unit`: " .. DumpPretty(unit))
    end
Debug("nisse - StoryDB:FindAssociatedUnit :: name: '" .. name .. "'")
    local groupInfo = nil
    local unitInfo = StoryDB.Units[name]
    if not unitInfo then
        -- this might be because unit was spawned (not activated). If so, the name will be <Group name>#<index> (eg. Ground-1#001-1 ir template group is "Ground-1")
        local groupName, unitIndex = DCAF.parseSpawnedUnitName(name)
        if groupName == name then
            -- not a spawned unit; give up ...
            return end
        
        groupInfo = StoryDB.Groups[groupName]
        if not groupInfo then
            if groupName == name then
                -- not an associated group; give up ...
                return 
            end
        end
        local index = 1
        local unitInfo = nil
        for _, ui in pairs(groupInfo.UnitsInfo) do
            if index == unitIndex then
                unitInfo = ui
                break
            end
            index = index + 1
        end
        if not unitInfo then
            -- WTF! this should not happen
            internalError("StoryDB:FindAssociatedUnit :: could not obtain UnitInfo for unit #" .. tostring(unitIndex) .. " of group '" .. groupName .. "'")
        end
        if unitInfo ~= nil then
            Debug("test - aaaa")
        end        
    else
        groupInfo =  unitInfo:GetGroupInfo()
    end

    if unitInfo == nil then
        Debug("test - bbbb")
    end        
    -- we have unit info; but only return the <UNIT> if it's associated with item ...
    local associatedItems = nil
    local info = StoryDB:GetInfo(item)
    if item._type == Type.Storyline then
        associatedItems = groupInfo.Storylines
    elseif item._type == Type.Stories then
        associatedItems = groupInfo.Stories
    end
        
    for itemName, _ in pairs(associatedItems) do
        if itemName == item.Name then
            return unitInfo.Unit
        end
    end
end

function StoryDB:FindActiveUnit(item, unit)
    local info = self:GetInfo(item)
    return info.ActiveUnits[unit.UnitName]
end

function StoryDB:AddActiveGroupBy(item, groupInfo, activeGroup)
    local info = self:GetInfo(item)
    local activeGroupsList = info.ActiveGroups[groupInfo.Name]
    if not activeGroupsList then
        activeGroupsList = {}
        info.ActiveGroups[groupInfo.Name] = activeGroupsList
    end
    table.insert(activeGroupsList, activeGroup)
    for _, unit in ipairs(activeGroup:GetUnits()) do
        info.ActiveUnits[unit.UnitName] = ActiveUnit:New(unit, groupInfo)
    end
-- nisse
Debug("StoryDB:AddActiveGroupBy-'" .. item.Name .. "' :: active units: " .. DumpPretty(info.ActiveUnits))

end

function StoryDB:GetActiveGroupsBy(item, groupName)
    local info = self:GetInfo(item)
    local activeGroupsDict = info.ActiveGroups
    if not isAssignedString(groupName) then
        return activeGroupsDict
    end
    return activeGroupsDict[groupName]
end

function StoryDB:RemoveActiveGroupsBy(item, groupName)
    local info = self:GetInfo(item)
    local activeGroupsDict = info.ActiveGroups
    if not isAssignedString(groupName) then
        item.ActiveGroups = {}
    else
        activeGroupsDict[groupName] = nil
    end
end

function StoryDB:DestroyActiveGroupsBy(item, groupName)

    function destroyGroups(list)
        for _, group in ipairs(list) do
            group:Destroy()
        end
        self:RemoveActiveGroupsBy(item, groupName)
    end

    local activeGroups = self:GetActiveGroupsBy(item, groupName)
Debug("nisse - StoryDB:DestroyActiveGroupsBy :: activeGroups (A): " .. DumpPretty(activeGroups))
    if isDictionary(activeGroups) then
        for _, list in pairs(activeGroups) do
            destroyGroups(list)
        end
    elseif isList(activeGroups) then 
        destroyGroups(activeGroups)
    else
        internalError("StoryDB:DestroyActiveGroupsBy :: unexpected type for 'active groups' collection: " .. DumpPretty(activeGroups))
    end
-- nisse
local activeGroups = self:GetActiveGroupsBy(item, groupName)
Debug("nisse - StoryDB:DestroyActiveGroupsBy :: activeGroups (B): " .. DumpPretty(activeGroups))
end

function StoryDB:DestroyAllActiveGroupsBy(item)
    local info = self:GetInfo(item)
    local activeGroupsDict = info.ActiveGroups
    for name, list in pairs(activeGroupsDict) do
        self:DestroyActiveGroupsBy(item, name)
    end
end

function StoryDB:GetStorylineGroups(storyline, namedGroups)
    local storylineGroups = StoryDB:GetInfo(storyline).Groups
    if tableIsUnassigned(namedGroups) then
        return storylineGroups end

    local named = {}
    for _, name in ipairs(namedGroups) do
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

    -- associate storyline groups with story ...
    for name, info in pairs(sli.Groups) do
        if not info:IsAssociatedWith(story) then
            info:AssociateWith(story)
        end
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
    local info = StoryDB.Groups[groupName]
    if info ~= nil then
        return info.Storylines
    end
    return {}
end

function StoryDB:CountGroupStorylines(groupName)
    local info = StoryDB.Groups[groupName]
    if info ~= nil then
        return info.CountStorylines
    end
    return 0
end

function StoryDB:IsGroupExclusiveTo(groupName, item)
    local groupInfo = StoryDB:GetGroupInfo(groupName)
    if not groupInfo then
        return false, 0 end

    local countControllers = 0
    local function getOtherControllers(controllersTable)
        local oc = {}
        for name, _ in pairs(controllersTable) do
            if name ~= item.Name then
                table.insert(oc, name)
            end
        end
        return oc
    end

    local controllers = nil
    if item._type == Type.Story then
        if groupInfo.CountStories == 1 and groupInfo.Stories[item.Name] then 
            return true, 1
        end
        controllers = groupInfo.Stories
    elseif item._type == Type.Storyline then
        if groupInfo.CountStorylines == 1 and groupInfo.Storylines[item.Name] then 
            return true, 1
        end
        controllers = groupInfo.Storylines
    else
        internalError("StoryDB:IsGroupExclusiveTo :: unsupported item: " .. DumpPretty(item))
    end

    return false, groupInfo.CountStorylines, getOtherControllers(controllers)
end

function StoryDB:IsGroupExclusiveToStory(groupName, story)
    local info = StoryDB:GetGroupInfo(groupName)
    if info == nil or info.CountStories ~= 0 then 
        return false end

    return info.Stories[story.Name] ~= nil
end

function StoryDB:IsGroupExclusiveToStoryline(groupName, storyline)
    local info = StoryDB:GetGroupInfo(groupName)
    if info == nil or info.CountStorylines ~= 0 then 
        return false end

    return info.Storylines[storyline.Name] ~= nil
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

function Storyline:ToString()
    return string.format("'%s' (%s)", self.Name, self._type)
end

function Storyline:GetGroupScope()
    return StoryDB:GetGroupScope(self)
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
    if self:GetStory() then
        error("Storyline:WithGroups :: cannot initialize Storyline using ':WithGroup' after " .. Type.Storyline .." was added to " .. Type.Story ..". Please use 'Storyline:AddGroups' instead") end

    local success, count = StoryDB:AssociateGroupsWith(self, ...)
    if not success and count == 0 then
        error("Storyline:WithGroups :: no groups was specified") end

    StoryDB:SetGroupScope(self, StoryScope.Storyline)
    return self
end

function Storyline:GetState() return StoryDB:GetState(self) end
function Storyline:IsPending() return self:GetState() == StoryState.Pending end
function Storyline:IsRunning() return self:GetState() == StoryState.Running end
function Storyline:IsDone() return self:GetState() == StoryState.Done end

function Storyline:FindGroup(group)
    local groupScope = self:GetGroupScope()
    local name = nil
    if isAssignedString(group) then
        name = group
    elseif isGroup(group) then
        name = group.GroupName
    else
        error("Storyline:FindGroup :: cannot resolve group from: " .. DumpPretty(group))
    end
    if groupScope == StoryScope.Storyline then
        return StoryDB:FindAssociatedGroup(self, name)
    elseif groupScope == StoryScope.Story then
        return StoryDB:FindAssociatedGroup(self, name) or StoryDB:FindAssociatedGroup(self:GetStory(), name)
    elseif groupScope == StoryScope.None then
        return getGroup(name)
    end
end

function Storyline:FindUnit(unit, nisse)
    local groupScope = self:GetGroupScope()
    if groupScope == StoryScope.Storyline then
        return StoryDB:FindAssociatedUnit(self, unit, nisse)
    elseif groupScope == StoryScope.Story then
        return StoryDB:FindAssociatedUnit(self, unit) or StoryDB:FindAssociatedUnit(self:GetStory(), unit)
    elseif groupScope == StoryScope.None then
        return getUnit(unit)
    end
end

function Storyline:FindActiveUnit(unit)
    return StoryDB:FindActiveUnit(self, unit)
end

function Storyline:Run()
    if not self.Enabled then
        return self end

    local groupInfos = StoryDB:GetStorylineGroups(self)
    for _, groupInfo in pairs(groupInfos) do
        groupInfo:RunBy(self)
    end
    self._isIdle = false
    StoryDB:SetState(self, StoryState.Running)
-- nisse
local info = StoryDB:GetInfo(self)
Debug("Storyline:Run :: '" .. self.Name .. "'")
Debug("Storyline:Run :: info.ActiveUnits: " .. DumpPretty(info.ActiveUnits))
Debug("Storyline:Run :: info.ActiveGroups: " .. DumpPretty(info.ActiveGroups))
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

function StoryEventArgs:LaunchGroups(...)
    return StoryDB:GetStoryline(self.Storyline):LaunchGroups(...)
end

function StoryEventArgs:DestroyStoryGroups(...)
    return StoryDB:GetStory(self.Storyline):DestroyGroups(...)
end

function StoryEventArgs:DestroyStorylineGroups(...)
    return StoryDB:GetStoryline(self.Storyline):DestroyGroups(...)
end

function StoryEventArgs:DestroyGroups(...)
    local scope = nil
    local groups = nil

    groups = {}
    local n = 0
    if arg.n >= 1 and StoryScope:IsValid(arg[1]) then
        scope = arg[1]
        if arg.n > 1 then
            table.remove(arg, 1)
        end
        groups = tableCopy(arg, groups)
    else
        scope = StoryScope.Storyline
        groups = tableCopy(arg, groups)
    end
    if scope == StoryScope.None then
        error("StoryEventArgs:DestroyGroups :: scope cannot be '" .. scope .. "' when destroying groupes") -- todo or can it?
    elseif scope == StoryScope.Story then
        return StoryDB:GetStory(self.Storyline):DestroyGroups(groups)
    elseif scope == StoryScope.Storyline then
        return StoryDB:GetStoryline(self.Storyline):DestroyGroups(groups)
    else
        error("StoryEventArgs:DestroyGroups :: unknown scope: '" .. scope)
    end
end

function StoryEventArgs:IsUnitKilled()
    return self.RootEvent and self.RootEvent.id == world.event.S_EVENT_KILL
end

function StoryEventArgs:GetKillerUnit()
    if not self:IsUnitKilled() then
        return end

    return self.RootEvent.IniUnit
end

function StoryEventArgs:GetKillerGroup()
    if not self:IsUnitKilled() then
        return end

    return self.RootEvent.IniGroup
end

function StoryEventArgs:IsKillerGroup(source)
    if source == nill then
        error("StoryEventArgs:IsKillerGroup :: killer group was unspecified") end

    if not self:IsUnitKilled() then
        return false end

    if isAssignedString(source) then
        if DCAF.Debug then
            local testGroup = getGroup(source)
            if not testGroup then
                error("StoryEventArgs:IsKillerGroup :: cannot resolve group from: " .. DumpPretty(source)) end
        end
        return self.RootEvent.IniGroupName == source 
    elseif isGroup(source) then
        return self.RootEvent.IniGroupName == source.GroupName
    else
        error("StoryEventArgs:IsKillerGroup :: unexpected value for `source`: " .. DumpPretty(source))
    end
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

local function validateItemGroupControl(item, group, errorPrefix, action)
    -- ensure group scope is honored ...
    if group == nil then
        errorOnDebug(errorPrefix .. " :: group was unassigned") end

    group = getGroup(group)
    if group == nil then
        errorOnDebug(errorPrefix .. " :: group cannot be resolved from: " .. Dump(group)) end

    local scope = item:GetGroupScope()
    if item._type == Type.Storyline and scope == StoryScope.Storyline then
        local isExclusive, countControllers, otherControllers = StoryDB:IsGroupExclusiveTo(group.GroupName, item)
        if not isExclusive then
            local msg = nil
            if countControllers == 1 then
                msg = "group that are controlled by another storyline ('" .. otherControllers[1] .. "')"
            else
                otherControllers[2] = "Test storyline 2"
                otherControllers[3] = "Test storyline 2"
                msg = "group that are also controlled by other storylines. Groups is controlled by these storylines: \n   -" ..concatList(otherControllers, "\n   -")
            end
            errorOnDebug(errorPrefix  .. " :: " .. item._type .. " '" .. item.Name .. "' cannot " .. action .. " " .. msg .. " (see storyline's Scope.Group configuration)")  
        end
    end

    if item._type == Type.Story and scope == StoryScope.Story and not StoryDB:IsGroupExclusiveTo(group.GroupName, item:GetStory()) then
        local isExclusive, countControllers, otherControllers = StoryDB:IsGroupExclusiveTo(group.GroupName, item)
        if not isExclusive then
            local msg = nil
            if countControllers == 1 then
                msg = "group that are controlled by another story ('" .. otherControllers[1] .. "')"
            else
                msg = "group that are also controlled by other stories. Group is controlled by these stories: \n   -" ..concatList(otherControllers, "\n   -")
            end
            errorOnDebug(errorPrefix  .. " :: " .. item._type .. " '" .. item.Name .. "' cannot " .. action .. " " .. msg .. " (see story's Scope.Group configuration)")  
        end
    end

    return group
end

local function selectNamedStorylineGroups(storyline, ...)
    local namedGroups = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then
Debug("selectNamedStorylineGroups :: v : " .. DumpPretty(v))    
            local group = validateItemGroupControl(storyline, v, "Storyline:LaunchGroups", "launch")
            table.insert( namedGroups, group.GroupName)
        end
    end
    return namedGroups
end

function Storyline:LaunchGroups(...)
    -- local namedGroups = selectNamedStorylineGroups(self, ...)
    local namedGroups = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then
            local group = validateItemGroupControl(self, v, "Storyline:LaunchGroups", "launch") 
            table.insert( namedGroups, group.GroupName)
        end
    end
    local groupInfos = StoryDB:GetStorylineGroups(self, namedGroups)
    for _, groupInfo in pairs(groupInfos) do
        groupInfo:RunBy(self)
    end
    return self
end

function Storyline:DestroyGroups(...)
    -- local namedGroups = selectNamedStorylineGroups(self, ...)
    if arg == nil then
        StoryDB:DestroyAllActiveGroupsBy(self)
        return self
    end
    local namedGroups = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then
Debug("Storyline:DestroyGroups :: v: " .. DumpPretty(v))            
            local group = validateItemGroupControl(self, v, "Storyline:LaunchGroups", "launch") 
            table.insert(namedGroups, group.GroupName)
        end
    end
    for _, groupName in ipairs(namedGroups) do
        StoryDB:DestroyActiveGroupsBy(self, groupName)
    end
    return self

    -- local groups, count = tableFilter(groupsList or {}, function(key, value) return isString(value) end) obsolete
    -- if count > 0 then 
    --     for _, groupName in ipairs(groups) do
    --         StoryDB:DestroyActiveGroupsBy(self, groupName)
    --     end
    --     return self
    -- end

    -- -- no groups specified; destroy all activated by storyline ...
    -- StoryDB:DestroyActiveGroupsBy(self)
    -- return self

    -- groups = StoryDB:GetStorylineGroups(self, groups) obsolete
    -- for _, storyGroup in pairs(groups) do
    --     self:DestroyGroup(storyGroup.Group)
    -- end
    -- return self
end

function Storyline:StopGroup(group)
    group = validateItemGroupControl(self, group, "Storyline:StopGroup", "stop")
    local groupInfo = StoryDB:GetGroup(group.GroupName)
    if groupInfo then
        groupInfo:Destroy()
    else
        group:Destroy()
    end
    return self
end

function Storyline:StopGroups(groupsList)
    local groups, count = tableFilter(groupsList or {}, function(key, value) return isString(value) end)
    if count == 0 then
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

function Storyline:OnAircraftLanded(aircraft, func)
    if aircraft ~= nil then
        local testAircraft = self:FindUnit(aircraft)
        if not testAircraft then
            local testUnit = getUnit(aircraft)
            if not testUnit then
                error("Storyline:OnAircraftLanded :: cannot resolve aircraft from: " .. Dump(aircraft)) 
            else
                error("Storyline:OnAircraftLanded :: aircraft '" .. testUnit.UnitName .. "' is not in storyline '"..self:FullName() .. "'") 
            end
        end
        aircraft = testAircraft
    end
    if not isFunction(func) then
        error("Storyline:OnAircraftLanded :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified aircraft ...
        if aircraft and not self:FindActiveUnit(event.IniUnit) then
            return end
        -- if not self:FindGroup(event.IniGroupName) then
        --     return end

        -- this is a one-time event ... 
        MissionEvents:EndOnAircraftLanded(eventFunc)
        event = tableCopy(StoryEventArgs:New(self), event)
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
        if group and not self:FindGroup(event.IniGroup) then -- isGroupInstanceOf(group, event.IniGroup) then
            return end
        if not self:FindGroup(event.IniGroup) then
            return end

        MissionEvents:EndOnGroupDiverted(eventFunc)
        event = tableCopy(StoryEventArgs:New(self), event)
        func(event)
    end

    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnAircraftLanded, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnGroupDiverted(eventFunc)
            end)
        end)
    else
        MissionEvents:OnGroupDiverted(eventFunc)
        self:OnStoryEnded(function(story)
            MissionEvents:EndOnGroupDiverted(eventFunc)
        end)
    end
    return self
end

--------------------------------------------- [ ZONE EVENTS ] ---------------------------------------------

function Storyline:OnGroupEntersZone(zone, group, func, filter, continous)

    if not isAssignedString(zone) then
        error("Storyline:OnGroupEntersZone :: zone was not correctly specified") end
    if not isFunction(func) then
        error("Storyline:OnGroupEntersZone :: unexpected function type: " .. type(func)) end
    
    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        local function isValidGroup( eventGroup )
            if not self:FindGroup(eventGroup) then
                return false 
            end
            return true
        end
    
        local function isValidObjects()
            if event.IniGroups then
                for _, g in ipairs(event.IniGroups) do
                    if isValidGroup(g) then 
                        return true end
                end
            elseif event.IniGroup then
                return isValidGroup(event.IniGroup) 
            end
        end

        -- only trigger for specified group or groups in storyline ...
        if not isValidObjects() then
            return end

        event = tableCopy(StoryEventArgs:New(self), event)
        func(event)
    end

    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        filter = filter:Ensure():Group(group)
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnGroupEntersZone, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnGroupEntersZone(eventFunc)
            end)
        end, { Zone = zone, Filter = filter, Continous = continous or false })
    else
        MissionEvents:OnGroupEntersZone(eventFunc)
    end
    return self
end

function Storyline:OnGroupInsideZone(zone, group, func, filter, continous)
    if not isFunction(func) then
        error("Storyline:OnGroupInsideZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified group or groups in storyline ...
        -- if group and not self:FindGroup(event.IniGroup) then -- isGroupInstanceOf(group, event.IniGroup) then
        --     return end
        if not self:FindGroup(event.IniGroup) then
            return end

        event = tableCopy(StoryEventArgs:New(self), event)
        func(event)
    end

    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        filter = filter:Ensure():Group(group)
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnGroupInsideZone, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnGroupInsideZone(eventFunc)
            end)
        end, { Zone = zone, Filter = filter, Continous = continous })
    else
        MissionEvents:OnGroupInsideZone(group, zone, eventFunc, continous)
    end
    return self
end

function Storyline:OnGroupLeftZone(zone, group, func, filter, continous)
    if not isFunction(func) then
        error("Storyline:OnGroupLeftZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified group or groups in storyline ...
        -- if group and not isGroupInstanceOf(group, event.IniGroup) then
        --     return end
        if not self:FindGroup(event.IniGroup) then
            return end

        event = tableCopy(StoryEventArgs:New(self), event)
        func(event)
    end

    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        filter = filter:Ensure():Group(group)
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnGroupLeftZone, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnGroupLeftZone(eventFunc)
            end)
        end, { Zone = zone, Filter = filter, Continous = continous })
    else
        MissionEvents:OnGroupLeftZone(group, zone, eventFunc, continous)
    end
    return self
end

function Storyline:OnUnitEntersZone(zone, unit, func, filter, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitEntersZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified unit or units in storyline ...
        if unit and not isUnitInstanceOf(unit.UnitName, event.IniUnitName) then
            return end
        if not self:FindActiveUnit(event.IniUnitName) then
            return end

        event = tableCopy(StoryEventArgs:New(self), event)
        func(event)
    end

    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        filter = filter:Ensure():Unit(unit)
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnUnitEntersZone, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnUnitEntersZone(eventFunc)
            end)
        end, { Zone = zone, Filter = filter, Continous = continous })
    else
        MissionEvents:OnUnitEntersZone(unit, zone, eventFunc, continous)
    end
    return self
end

function Storyline:OnUnitInsideZone(zone, unit, func, filter, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitInsideZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified unit or units in storyline ...
        if unit and not isUnitInstanceOf(unit.UnitName, event.IniUnitName) then
            return end
        if not self:FindActiveUnit(event.IniUnitName) then
            return end

        event = tableCopy(StoryEventArgs:New(self), event)
        func(event)
    end
    
    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        filter = filter:Ensure():Unit(unit)
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnUnitInsideZone, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnUnitInsideZone(eventFunc)
            end)
        end, { Zone = zone, Filter = filter, Continous = continous })
    else
        MissionEvents:OnUnitInsideZone(unit, zone, eventFunc, continous)
    end
    return self
end

function Storyline:OnUnitLeftZone(zone, unit, func, filter, continous)
    if not isFunction(func) then
        error("Storyline:OnUnitLeftZone :: unexpected function type: " .. type(func)) end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end

        -- only trigger for specified unit or units in storyline ...
        if unit and not isUnitInstanceOf(unit.UnitName, event.IniUnitName) then
            return end
        if not self:FindActiveUnit(event.IniUnitName) then
            return end

        event = tableCopy(StoryEventArgs:New(self), event)
        func(event)
    end
        
    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        filter = filter:Ensure():Unit(unit)
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnUnitInsideZone, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnUnitInsideZone(eventFunc)
            end, { Zone = zone, Filter = filter, Continous = continous })
        end)
    else
        MissionEvents:OnUnitInsideZone(unit, zone, eventFunc, continous)
    end
    return self
end

function Storyline:OnUnitDestroyed(unit, func)
    if not isFunction(func) then
        error("Storyline:OnUnitDestroyed :: unexpected function type: " .. type(func)) end
    
    local unitDict = nil
    if unit ~= nil then
        local function validate(unit)
            local testUnit = self:FindUnit(unit) 
            if not testUnit then
                local exists = getUnit(unit)
                if not exists then
                    error("Storyline:OnUnitDestroyed :: cannot resolve unit from : " .. DumpPretty(unit)) 
                else
                    error("Storyline:OnUnitDestroyed :: unit is out of storyline's scope: " .. Dump(exists.UnitName))
                end
            end
            return testUnit
        end
        if isList(unit) then
            unitDict = {}
            for _, u in ipairs(unit) do
                local validUnit = validate(u)
                unitDict[validUnit.UnitName] = validUnit
            end
        else
            unit = validate(unit)
        end
    end

    local eventFunc = nil
    eventFunc = function(event)
        if not self:IsRunning() then
            return end
        
        if not event.IniUnit then
            Warning("Storyline:OnUnitDestroyed :: unit was unspecified in event :: EXITS")
            return
        end

        -- only trigger for specified unit or units in storyline ...
        if not self:FindActiveUnit(event.IniUnit, "nisse") then
            return end

        local function isApplicable()
            if unitDict then
                for k, v in pairs(unitDict) do
                    if self:FindActiveUnit(event.IniUnit) then
                        return true end
                    -- if StoryDB:IsUnitInstanceOf(event.IniUnit, v) then
                        -- return true end
                    -- if isUnitInstanceOf(event.IniUnit, v) then
                    --     return true end
                end
            else
                return isUnitInstanceOf(event.IniUnit, unit)
            end
        end

        if not isApplicable() then
            return end

        event = tableCopy(StoryEventArgs:New(self), event)
        func(event)
    end
        
    -- pre-register event if Pending; otherwise, just add it ...
    if self:IsPending() then
        DCAFEvents:PreActivate(self.Name, DCAFEvents.OnUnitDestroyed, eventFunc, function() 
            self:OnStoryEnded(function(story)
                MissionEvents:EndOnUnitDestroyed(eventFunc)
            end)
        end)
    else
        MissionEvents:OnUnitDestroyed(eventFunc)
    end
    return self
end

function Storyline:OnUnitInGroupDestroyed(group, func)
    if not isAssignedString(group) and not isGroup(group) then
        error("Storyline:OnUnitInGroupDestroyed :: group was unspecified") end

    if not isFunction(func) then
        error("Storyline:OnUnitInGroupDestroyed :: unexpected function type: " .. type(func)) end

    local testGroup = getGroup(group)
    if not testGroup then
        error("Storyline:OnUnitInGroupDestroyed :: cannot resolve group from: " .. Dump(group)) end
    if not self:FindGroup(testGroup) then
        error("Storyline:OnUnitInGroupDestroyed :: group '".. Dump(testGroup.GroupName) .."' is out of scope for storyline '" .. self.Name .. "'") end

    group = testGroup
    local units = group:GetUnits()
    return self:OnUnitDestroyed(units, func)
end


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
    story.Config = StoryConfig:New()
    if not isAssignedString(name) then
        error("Story:New :: story name was unspecified") end

    if arg then
        story:WithStorylines(...)
    end
    StoryDB:AddStory(story)
    return story
end

function Story:ToString()
    return string.format("'%s' (%s)", self.Name, self._type)
end

function Story:GetStorylines()
    local info = StoryDB:GetInfo(self)
    if info then
        return info.Storylines
    end
end

function Story:GetGroupScope()
    return StoryDB:GetGroupScope(self)
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

function Story:WithGroups(...)
    if tableIsUnassigned(arg) then
        error("Story:WithGroups :: no groups were specified") end
    
    StoryDB:AssociateGroupsWith(self, ...)
    StoryDB:SetGroupScope(self, StoryScope.Story)
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

function Story:FindStoryline(storylineName)
    local storylines = self:GetStorylines()
    local index = tableIndexOf(self:GetStorylines(), function(sl) return sl.Name == storylineName end)
    if index then
        return storylines[index] 
    end
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

function Story:FindGroup(name)
    local groupScope = self:GetGroupScope()
    if groupScope == StoryScope.Story then
        return StoryDB:FindAssociatedGroup(self, name)
    elseif groupScope == StoryScope.None then
        return getGroup(name)
    end
end

function Story:FindUnit(name)
    local groupScope = self:GetGroupScope()
    if groupScope == StoryScope.Story then
        return StoryDB:FindAssociatedUnit(self, name)
    elseif groupScope == StoryScope.None then
        return getUnit(name)
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