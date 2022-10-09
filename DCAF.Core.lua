DCAF = {
    Trace = false,
    TraceToUI = false, 
    Debug = false,
    DebugToUI = false, 
    WaypointNames = {
        RTB = '_rtb_',
        Divert = '_divert_',
    }
}

local _debugId = 0
local function get_next_debugId()
    _debugId = _debugId + 1
    return _debugId
end

local function with_debug_info(table)
    table._debugId = "debug_" .. tostring(get_next_debugId())
    return table
end

function DCAF.clone(template, deep)
    if not isBoolean(deep) then
        deep = true
    end
    local cloned = nil
    if deep then
        cloned = routines.utils.deepCopy(template)
    else
        cloned = {}
        for k, v in pairs(template) do
            cloned[k] = v
        end
    end

    -- add debug information if applicable ...
    if DCAF.Debug then
        return with_debug_info(cloned)
    end
    return cloned
end

function isString( value ) return type(value) == "string" end
function isBoolean( value ) return type(value) == "boolean" end
function isNumber( value ) return type(value) == "number" end
function isTable( value ) return type(value) == "table" end
function isFunction( value ) return type(value) == "function" end
function isClass( value, class ) return isTable(value) and value.ClassName == class end
function isUnit( value ) return isClass(value, "UNIT") end
function isGroup( value ) return isClass(value, "GROUP") end
function isZone( value ) return isClass(value, "ZONE") end

function isAssignedString( value )
    if not isString(value) then
        return false end

    return string.len(value) > 0 
end

function trimInstanceFromName( name, qualifierAt )
    if not isNumber(qualifierAt) then
        qualifierAt = string.find(name, "#%d")
    end
    if not qualifierAt then
        return name end

    return string.sub(name, 1, qualifierAt-1), string.sub(name, qualifierAt)
end

function isGroupNameInstanceOf( name, templateName )
    if name == templateName then
        return true end

Debug("isGroupNameInstanceOf :: name: " .. name .. " :: templateName: " .. templateName)        
    -- check for spawned pattern (eg. "Unit-1#001-1") ...
    local i = string.find(name, "#%d")
    if i then
        local test = trimInstanceFromName(name, i)
Debug("isGroupNameInstanceOf :: test: " .. test)        
        if test == templateName then
Debug("isGroupNameInstanceOf :: nisse")        
            return true, templateName end
    end

    if i and trimInstanceFromName(name, i) == templateName then
        return true, templateName
    end
    return false
end

function isUnitNameInstanceOf(name, templateName)
    if name == templateName then
        return true end

Debug("isUnitNameInstanceOf :: name: " .. name .. " :: templateName: " .. templateName)        
    -- check for spawned pattern (eg. "Unit-1#001-1") ...
    local i = string.find(name, "#%d")
    if i then
        local test, instanceElement = trimInstanceFromName(name, i)
Debug("isUnitNameInstanceOf :: test: " .. test)        
        if test == templateName then
Debug("isUnitNameInstanceOf :: nisse")        
            local counterAt = string.find(instanceElement, "-")
            if not counterAt then
                return false end

            local counterElement = string.sub(instanceElement, counterAt)
            return true, templateName .. counterElement
        end
    end

    if i and trimInstanceFromName(name, i) == templateName then
        return true, templateName
    end
    return false
end

function isUnitInstanceOf( unit, unitTemplate )
    if unit.UnitName == unitTemplate.UnitName then
        return true end

    return isGroupNameInstanceOf( unit:GetGroup().GroupName, unitTemplate:GetGroup().GroupName )
end

function isGroupInstanceOf( group, groupTemplate )
    return isGroupNameInstanceOf( group.GroupName, groupTemplate.GroupName )
end

function swap(a, b)
    local _ = a
    a = b
    b = _
    return a, b
end

FeetPerNauticalMile = 6076.1155
MetersPerNauticalMile = UTILS.NMToMeters(1)

function NauticalMilesToMeters( nm )
    if (not isNumber(nm)) then error("Expected 'nm' to be number") end
    return MetersPerNauticalMile * nm
end

function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function inString( s, pattern )
    return string.find(s, pattern ) ~= nil 
end

function findFirstNonWhitespace( s, start )
    local sLen = string.len(s)
    for i=start, sLen, 1 do
        local c = string.sub(s, i, i)
        if (c ~= ' ' and c ~= '\n' and c ~= '\t') then
            return i
        end
    end
    return nil
end

function tableCopyTo(source, target)
    local count = 0
    for k,v in pairs(source) do
        if target[k] == nil then
            if isTable(v) then
                target[k] = routines.utils.deepCopy(v)
            else
                target[k] = v
            end
        end
        count = count + 1
    end
    return target, count
end

function tableIndexOf( table, itemOrFunc )
    if not isTable(table) then
        error("indexOfItem :: unexpected type for table: " .. type(table)) end

    if itemOrFunc == nil then
        error("indexOfItem :: item was unassigned") end

    for index, value in ipairs(table) do
        if isFunction(itemOrFunc) and itemOrFunc(value) then
            return index
        elseif itemOrFunc == value then
            return index
        end
    end
end

function tableKeyOf( table, item )
    if not isTable(table) then
        error("indexOfItem :: unexpected type for table: " .. type(table)) end

    if item == nil then
        error("indexOfItem :: item was unassigned") end

    for key, value in pairs(table) do
        if isFunction(item) and item(value) then
            return key
        elseif item == value then
            return key
        end
    end
end

function tableFilter( table, func )
    if table == nil then
        return nil, 0 end

    if not isTable(table) then
        error("tableFilter :: table of unexpected type: " .. type(table)) end

    if func ~= nil and not isFunction(func) then
        error("tableFilter :: func must be function but is: " .. type(func)) end

    local result = {}
    local count = 0
    for k, v in pairs(table) do
        if func(k, v) then
            result[k] = v
            count = count + 1
        end
    end
    return result, count
end

local next = next 
function tableIsUnassigned(table)
    return table == nil or not next(table)
end

function TraceIgnore(message, ...)
    Trace(message .. " :: IGNORES")
    return arg
end

function exitTrace(message, ...)
    Warning(message .. " :: EXITS")
    return arg
end

function exitWarning(message, ...)
    Warning(message .. " :: EXITS")
    return arg
end

function errorOnDebug(message)
    if DCAF.Debug then
        error(message)
    else
        Error(message)
    end
end

function activateNow( source )
    local group = getGroup( source )
    if not group then
        return exitWarning("activateNow :: cannot resolve group from " .. Dump(source))
    end
    if not group:IsActive() then
        group:Activate()
    end
    return group
end

function spawnNow( source )
    local name = nil
    if isGroup(source) then
        name = source.GroupName
    elseif isString(source) then
        name = source
    else
        error("spawnNow :: source is unexpected type: " .. type(source)) end

    local group = SPAWN:New( name ):Spawn()
    activateNow( group ) -- hack. Not sure why the spawned group is not active but this fixes that
    return group
end

function Delay( seconds, userFunction, data )
    if (not isNumber(seconds)) then error("Delay :: seconds was not specified") end
    if (userFunction == nil) then error("Delay :: userFunction was not specified") end
    local timer = TIMER:New(
        function() 
            userFunction(data)
         end):Start(seconds)
end

local _missionStartTime = UTILS.SecondsOfToday()

function MissionClock( short )
    if (short == nil) then
        short = true
    end
    return UTILS.SecondsToClock(UTILS.SecondsOfToday(), short)
end

function MissionStartTime()
    return _missionStartTime end

function MissionTime()
    return UTILS.SecondsOfToday() - _missionStartTime end

function SecondsOfToday(missionTime)
    return _missionStartTime + missionTime or 0 end

function MissionClockTime( short, offset )
    if (short == nil) then
        short = true
    end
    if not isNumber(offset) then
        offset = 0
    end
    return UTILS.SecondsToClock( MissionTime() + offset, short )
end

local function log( rank, message )
end
    
function Trace( message )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    if (DCAF.Trace) then
        BASE:E("DCAF-TRC @"..timestamp.." ===> "..tostring(message))
    end
    if (DCAF.TraceToUI) then
        MESSAGE:New("DCAF-TRC: "..message):ToAll()
    end
end
  
function Debug( message )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    if (DCAF.Debug) then
        BASE:E("DCAF-DBG @"..timestamp.." ===> "..tostring(message))
    end
    if (DCAF.DebugToUI) then
        MESSAGE:New("DCAF-DBG: "..message):ToAll()
    end
end
  
function Warning( message )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    BASE:E("DCAF-WRN @"..timestamp.."===> "..tostring(message))
    if (DCAF.TraceToUI or DCAF.DebugToUI) then
        MESSAGE:New("DCAF-WRN: "..message):ToAll()
    end
end

function Error( message )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    BASE:E("DCAF-ERR @"..timestamp.."===> "..tostring(message))
    if (DCAF.TraceToUI or DCAF.DebugToUI) then
        MESSAGE:New("DCAF-ERR: "..message):ToAll()
    end
end


---------------------------- FILE SYSTEM -----------------------------

-- https://www.geeks3d.com/hacklab/20210901/how-to-check-if-a-directory-exists-in-lua-and-in-python/

files = {}

function files.gettype( path )
    local attributes = lfs.attributes( path )
    if attributes then
        return attributes.mode end
    return nil
end

function files.isdir( path )
    return files.gettype( path ) == "directory"
end

function files.isfile( path )
    return files.gettype( path ) == "file"
end

function files.exists( path )
    return file.gettype( path ) ~= nil
end

------------------------------------------------------------------
  

--[[
Resolves a UNIT from an arbitrary source
]]--
function getUnit( source )
    if (isUnit(source)) then return source end
    if (isString(source)) then
        return UNIT:FindByName( source )
    end
end

--[[
getGroup    
    Resolves a GROUP from an arbitrary source
]]--
function getGroup( source )
    if (isGroup(source)) then 
        return source 
    end
    if (isUnit(source)) then 
        return source:GetGroup() 
    end
    if (not isString(source)) then return nil end

    local group = GROUP:FindByName( source )
    if (group ~= nil) then 
        return group 
    end
    local unit = UNIT:FindByName( source )
    if (unit ~= nil) then 
        return unit:GetGroup() 
    end
end
  
function isSameHeading( group1, group2 ) 
--Debug("isSameHeading :: g1.heading: " .. tostring(group1:GetHeading() .. " :: g2.heading: " .. tostring(group2:GetHeading())))
    return math.abs(group1:GetHeading() - group2:GetHeading()) < 5 
end

function isSameAltitude( group1, group2 ) 
    return math.abs(group1:GetAltitude() - group2:GetAltitude()) < 500 
end
function isSameCoalition( group1, group2 ) return group1:GetCoalition() == group2:GetCoalition() end
 
local function isSubjectivelySameGroup( group1, group2 )
    -- determines whether a group _appears_ to be flying together with another group 

    return group1:IsAlive() and group2:IsAlive() 
            and isSameCoalition(group1, group2)
            and isSameHeading(group1, group2) 
            and isSameAltitude(group1, group2) 
end

function IsHeadingFor( source, target, maxDistance, tolerance )
    if source == nil then 
        error("IsHeadingFor :: source not specified")
        return
    end
    if target == nil then 
        error("IsHeadingFor :: target not specified")
        return
    end
    
    local sourceCoordinate = nil
    local sourceUnit = getUnit(source)
    if sourceUnit == nil then 
        local g = getGroup(source)
        if g == nil then
            error("IsHeadingFor :: source unit could not be resolved from " .. Dump(source))
            return
        end
        sourceUnit = g:GetUnit(1)
    end
    sourceCoordinate = sourceUnit:GetCoordinate()

    local targetCoordinate = nil
    local targetUnit = getUnit(target)
    if targetUnit == nil then
        local g = getGroup(target)
        if g == nil then
            error("IsHeadingFor :: target coordinate could not be resolved from " .. Dump(target))
            return
        end
        targetCoordinate = g:GetCoordinate()
    else
        targetCoordinate = targetUnit:GetCoordinate()
    end

    if maxDistance ~= nil then
        local distance = sourceCoordinate:Get2DDistance(targetCoordinate)
        if distance > maxDistance then
            return flase end
    end
    
    if not isNumber(tolerance) then tolerance = 1 end

    local dirVec3 = sourceCoordinate:GetDirectionVec3( targetCoordinate )
    local angleRadians = sourceCoordinate:GetAngleRadians( dirVec3 )
    local bearing = UTILS.Round( UTILS.ToDegree( angleRadians ), 0 )
    local minHeading = bearing - tolerance % 360
    local maxHeading = bearing + tolerance % 360
    local heading = sourceUnit:GetHeading()
    return heading <= maxHeading and heading >= minHeading
end

local function isEscortingFromTask( escortGroup, clientGroup )
    -- determines whether a group is tasked with escorting a 'client' group ...
    -- TODO the below logic only find out if there's a task somewhere in the group's route that escorts the source group. See if we can figure out whether it's a _current_ task
    local route = escortGroup:GetTaskRoute()

    for k,wp in pairs(route) do
        local tasks = wp.task.params.tasks
        if tasks then
            for _, task in ipairs(tasks) do
                if (task.id == ENUMS.MissionTask.ESCORT and task.params.groupId == clientGroup:GetID()) then
                    return true
                end
            end
        end
    end
end

-- getEscortingGroup :: Resolves one or more GROUPs that is escorting a specified (arbitrary) source
-- @param source 

function GetEscortingGroups( source, subjectiveOnly )
    if (subjectiveOnly == nil) then
        subjectiveOnly = false
    end
    local group = getGroup(source)
    if not group then
        return exitWarning("GetEscortingGroups :: cannot resolve group from " .. Dump(source))
    end

    local zone = ZONE_GROUP:New(group.GroupName.."-escorts", group, NauticalMilesToMeters(5))
    local nearbyGroups = SET_GROUP:New()
    if (group:IsAirPlane()) then
        nearbyGroups:FilterCategoryAirplane()
    end
    if (group:IsHelicopter()) then
        nearbyGroups:FilterCategoryHelicopter()
    end
    nearbyGroups
        :FilterZones({ zone })
        :FilterCoalitions({ string.lower( group:GetCoalitionName() ) })
        :FilterActive()
        :FilterOnce()

    local escortingGroups = {}

    nearbyGroups:ForEach(
        function(g)

            if g == group or not g:IsAlive() or not isSubjectivelySameGroup( g, group ) then
                return
            end

            if subjectiveOnly or isEscortingFromTask( g, group ) then
                table.insert(escortingGroups, g)
            end
        end)

    return escortingGroups
end

function IsEscorted( source, subjectiveOnly )

    local escorts = GetEscortingGroups( source, subjectiveOnly )
    return #escorts > 0

end

function GetEscortClientGroup( source, maxDistance, resolveSubjective )

    if (maxDistance == nil) then
        maxDistance = NauticalMilesToMeters(1.5)
    end
    if (resolveSubjective == nil) then
        resolveSubjective = false
    end
    local group = getGroup(source)
    if not group then
        return exitWarning("GetEscortClientGroup :: cannot resolve group from " .. Dump(source))
    end

    local zone = ZONE_GROUP:New(group.GroupName.."-escorts", group, maxDistance)
    local nearbyGroups = SET_GROUP:New()
    if (group:IsAirPlane()) then
        nearbyGroups:FilterCategoryAirplane()
    end
    if (group:IsHelicopter()) then
        nearbyGroups:FilterCategoryHelicopter()
    end
    nearbyGroups:FilterZones({ zone }):FilterActive():FilterOnce()

    local escortedGroup = {}
    local clientGroup = nil

    nearbyGroups:ForEachGroupAlive(
        function(g)

            if clientGroup or g == group then return end -- client group was alrady resolved

            if not isSubjectivelySameGroup( group, g ) then
                return
--Debug("GetEscortClientGroup-" .. group.GroupName .. " :: is not subjectively same group: " .. g.GroupName )
            end

            if resolveSubjective or isEscortingFromTask( group, g ) then
                clientGroup = g
--Debug("GetEscortClientGroup-" .. group.GroupName .. " :: client group found: " .. tostring(clientGroup) )
                return 
            end
            -- if g == group or not isSubjectivelySameGroup( group, g ) then return end
            -- if resolveSubjective or isEscortingFromTask( group, g ) then
            --     clientGroup = g
            --     return
            -- end
        end)

--Debug("GetEscortClientGroup-" .. group.GroupName .. " :: client group returned: " .. tostring(clientGroup) )

    return clientGroup

end
  
function getControllable( source )
    local unit = getUnit(source)
    if (unit ~= nil) then 
      return unit end
    
    local group = getGroup(source)
    if (group ~= nil) then 
      return group end

    return nil
end

function getZone( source )

end

function GetOtherCoalitions( controllable, excludeNeutral )
    local group = getGroup( controllable )
    if (group == nil) then
        return exitWarning("GetOtherCoalitions :: group not found: "..Dump(controllable))
    end

    local c = group:GetCoalition()

    if excludeNeutral == nil then 
        excludeNeutral = false end

    if c == "red" or c == coalition.side.RED then
        if excludeNeutral then 
            return { "blue" } end
        return { "blue", "neutral" }
    elseif c == "blue" or c == coalition.side.BLUE then
        if excludeNeutral then 
            return { "red" } end
        return { "red", "neutral" }
    elseif c == "neutral" or c == coalition.side.NEUTRAL then
        return { "red", "blue" }
    end
end

--[[
Compares two groups and returns a numeric value to reflect their relative strength/superiority

Parameters
    a :: first group
    b :: second group

Returns
    Zero (0) if groups are considered equal in strength
    A negative value if group a is considered superior to group b
    A positive value if group b is considered superior to group a
]]--
function GetGroupSuperiority( a, b, aSize, aMissiles, bSize, bMissiles )
    local aGroup = getGroup(a)
    local bGroup = getGroup(b)
    if (aGroup == nil) then
        if (bGroup == nil) then return 0 end
        return 1
    end

    if (bGroup == nil) then
        return -1
    end

    -- todo consider more interesting ways to compare groups relative superiority/inferiority
    local aSize = aSize or aGroup:CountAliveUnits()
    local bSize = bSize or bGroup:CountAliveUnits()
    if (aSize > bSize) then return -1 end

    -- b is equal or greater in size; compare missiles loadout ...
    if aMissiles == nil then
        local _, _, _, _, countMissiles = aGroup:GetAmmunition()
        aMissiles = countMissiles
    end
    if bMissiles == nil then
        local _, _, _, _, countMissiles = bGroup:GetAmmunition()
        bMissiles = countMissiles
    end
    -- todo Would be great to check type of missiles here, depending on groups' distance from each other
    local missileRatio = (aMissiles / aSize) / (bMissiles / bSize)
-- Debug("GetGroupSuperiority-"..aGroup.GroupName.." / "..bGroup.GroupName.." :: " .. string.format("size: %d / %d :: missiles: %d / %d", aSize, bSize, aMissiles, bMissiles)) -- nisse
-- Debug("GetGroupSuperiority-"..aGroup.GroupName.." / "..bGroup.GroupName.." :: missileRatio: "..tostring(missileRatio)) -- nisse
    if (aSize < bSize) then 
        if missileRatio > 2 then
            -- A is smaller than B but a is strongly superior in armament ...
            return -1
        end
        if (missileRatio > 1.5) then
            -- A is smaller than B but a is slightly superior in armament ...
            return 0
        end
        return 1 
    end
    return 0
end

NoMessage = "_none_"

DebugAudioMessageToAll = false -- set to true to debug audio messages

--local ignoreMessagingGroups = {}
--[[ 
Sends a simple message to groups, clients or lists of groups or clients
]]--
function MessageTo( recipient, message, duration )
    -- if (recipient == nil) then
    --     return exitWarning("MessageTo :: Recipient name not specified")
    -- end
    if (message == nil) then
        return exitWarning("MessageTo :: Message was not specified")
    end
    duration = duration or 5

    if (isString(recipient)) then
        local unit = getUnit(recipient)
        if unit ~= nil then
            MessageTo(unit, message, duration)
            return
        end
        local group = getGroup(recipient)
        if (group ~= nil) then
            MessageTo(group, message, duration)
            return
        end
        return exitWarning("MessageTo-?"..recipient.." :: Group could not be resolved")
    end

    if (string.match(message, ".\.ogg") or string.match(message, ".\.wav")) then
        local audio = USERSOUND:New(message)
        if recipient == nil or DebugAudioMessageToAll then
            Trace("MessageTo (audio) :: (all) " .. recipient.GroupName .. " :: '" .. message .. "'")
            audio:ToAll()
        elseif isGroup(recipient) then
            Trace("MessageTo (audio) :: group " .. recipient.GroupName .. " :: '" .. message .. "'")
            audio:ToGroup(recipient)
        elseif isUnit(recipient) then
            Trace("MessageTo (audio) :: unit " .. recipient:GetName() .." :: '" .. message .. "'")
            audio:ToUnit(recipient)
        end
        return
    end
    
    local msg = MESSAGE:New(message, duration)
    if recipient == nil then
        Trace("MessageTo :: (all) :: '" .. message .."'")
        msg:ToAll()
        return
    elseif isGroup(recipient) then
        Trace("MessageTo :: group " .. recipient.GroupName .. " :: '" .. message .."'")
        msg:ToGroup(recipient)
        return
    elseif isUnit(recipient) then
        Trace("MessageTo :: unit " .. recipient:GetName() .. " :: '" .. message .. "'")
        msg:ToUnit(recipient)
        return
    end
    for k, v in pairs(recipient) do
        MessageTo( v, message, duration )
    end
    return
end

local function SendMessageToClient( recipient )
    local unit = CLIENT:FindByName( recipient )
    if (unit ~= nil) then
        Trace("MessageTo-"..recipient.." :: "..message)
        MESSAGE:New(message, duration):ToClient(unit)
        return
    end

    if (pcall(SendMessageToClient(recipient))) then 
        return end

    Warning("MessageTo-"..recipient.." :: Recipient not found")
end

function SetFlag( name, value, menuKey )
    value = value or true
    trigger.action.setUserFlag(name, value)
    Trace("SetFlag-"..name.." :: "..tostring(value))
end

function GetFlag( name )
    return trigger.misc.getUserFlag( name )
end

function GetUnitFromGroupName( groupName, unitNumber )

    unitNumber = unitNumber or 1
    local group = GROUP:FindByName( groupName )
    if (group == nil) then return nil end
    return group.GetUnit( unitNumber )
  
  end
  
  function EstimatedDistance( feet )
    if (not isNumber(feet)) then error( "<feet> must be a number" ) end
  
    local f = nil
    if (feet < 10) then return feet end
    if (feet < 100) then 
      -- nearest 10 ...
      return UTILS.Round(feet / 10) * 10 
  
    elseif (feet < 1000) then f = 100
    elseif (feet < 10000) then f = 1000
    elseif (feet < 100000) then f = 10000
    elseif (feet < 1000000) then f = 100000 end
    local calc = feet / f + 1
    calc = UTILS.Round(calc * 2, 0) / 2 - 1
    return calc * f
  end
  
  local function mkIndent( count )
    local s = ""
    for i=count,0,-1 do
      s = s.." "
    end
    return s
  end
  
  function Dump(value)
    if type(value) ~= 'table' then
        return tostring(value)
    end
  
    local s = "{ "
    for k,v in pairs(value) do
       if type(k) ~= 'number' then k = '"'..k..'"' end
       s = s .. '['..k..'] = ' .. Dump(v) .. ','
    end
    return s .. '} '
  end
  
  --[[
Parameters
    value :: (arbitrary) Value to be serialised and formatted
    options :: (object)
    {
        asJson :: (bool; default = false) Set to serialize as JSON instead of lua (makes it easier to use with many online JSON analysis tools)
        indentSize :: (int; default = 2) Specifies indentation size (no. of spaces)
        deep :: (bool; default=false) Specifies whether to dump the object with recursive information or "shallow" (just first level of graph)
    }
  ]]--
DumpPrettyOptions = {
    asJson = false,
    indentSize = 2,
    deep = false,
    includeFunctions = false
}

function DumpPrettyOptions:New()
    return routines.utils.deepCopy(DumpPrettyOptions)
end

function DumpPrettyOptions:JSON( value )
    self.asJson = value or true
    return self
end

function DumpPrettyOptions:IndentWize( value )
    self.indentSize = value or 2
    return self
end

function DumpPrettyOptions:Deep( value )
    self.deep = value or true
    return self
end

function DumpPrettyOptions:IncludeFunctions( value )
    self.includeFunctions = value or true
    return self
end

function DumpPretty(value, options)
  
    options = options or DumpPrettyOptions
    local idtSize = options.indentSize or DumpPrettyOptions.indentSize
    local asJson = options.asJson or DumpPrettyOptions.asJson
   
    local function dumpRecursive(value, ilvl)
    if type(value) ~= 'table' then
        if (isString(value)) then
          return '"' .. tostring(value) .. '"'
        end
        return tostring(value)
      end

      if ((not options.deep or not DCAF.Debug) and ilvl > 0) then
        if (options.asJson) then
            return "{ }" 
        end
        return "{ --[[ data omitted ]] }"
      end
  
      local s = '{\n'
      local indent = mkIndent(ilvl * idtSize)
      for k,v in pairs(value) do
        if (options.includeFunctions or type(v) ~= "function") then
            if (asJson) then
                s = s .. indent..'"'..k..'"'..' : '
            else
                if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. indent.. '['..k..'] = '
                end
                s = s .. dumpRecursive(v, ilvl+1, idtSize) .. ',\n'
            end
        end
        return s .. mkIndent((ilvl-1) * idtSize) .. '}'
    end
  
    return dumpRecursive(value, 0)
end
  
function DumpPrettyJson(value, options)
    options = (options or DumpPrettyOptions:New()):AsJson()
    return DumpPretty(value, options)
end

function DumpPrettyDeep(value, options)
    if isTable(options) then
        options = options:Deep()
    else
        options = DumpPrettyOptions:New():Deep()
    end
    return DumpPretty(value, options)
end
  
function DistanceToStringA2A( meters, estimated )
    if (not isNumber(meters)) then error( "<meters> must be a number" ) end
    local feet = UTILS.MetersToFeet( meters )
    if (feet < FeetPerNauticalMile / 2) then
        if (estimated or false) then
        feet = EstimatedDistance( feet )
        end
        return tostring( math.modf(feet) ) .. " feet"
    end
    local nm = UTILS.Round( feet / FeetPerNauticalMile, 1)
    if (estimated) then
        -- round nm to nearest 0.5
        nm = UTILS.Round(nm * 2) / 2
    end
    if (nm < 2) then 
        return tostring( nm ) .. " mile"
    end
        return tostring( nm ) .. " miles"
end
  
function GetAltitudeAsAngelsOrCherubs( coordinate ) 
    -- controllable = getControllable( controllable )
    -- if (controllable == nil) then error( "Could not resolve controllable from " .. Dump(controllable) ) end
    -- local coordinate = controllable:GetCoordinate()
    local feet = UTILS.MetersToFeet( coordinate.y )
    if (feet >= 1000) then
        local angels = feet / 1000
        return "angels " .. tostring(UTILS.Round( angels, 0 ))
    end

    local cherubs = feet / 100
    return "cherubs " .. tostring(UTILS.Round( cherubs, 0 ))
end

-- GetRelativeLocation :: Produces information to represent the subjective, relative, location between two locations
-- @param sourceCoordinate :: The subject location
-- @param targetLocation :: The 'other' location
-- @returns object :: 
--    {
--      Bearing :: The bearing from source to target
--      Distance :: The distance between source and target
--      TextDistance :: Textual distance between source and target
--      TextPosition :: Textual (o'clock) position of target, relative to source
--      TextLevel :: Textual, relative (high, level or low), vertical position of target relative to source
--      TextAngels :: Textual altitude in angels or sherubs
--      ToString() :: function; Returns standardized textual relative location, including all of the above
--    }
function GetRelativeLocation( source, target )
    local sourceGroup = getGroup(source)
    if not sourceGroup then
        return exitWarning("GetRelativeLocation :: cannot resolve source group from " .. Dump(source))
    end
    local targetGroup = getGroup(target)
    if not targetGroup then
        return exitWarning("GetRelativeLocation :: cannot resolve target group from " .. Dump(target))
    end

    local sourceCoordinate = sourceGroup:GetCoordinate()
    local targetCoordinate = targetGroup:GetCoordinate()

    -- bearing
    local dirVec3 = sourceCoordinate:GetDirectionVec3( targetCoordinate )
    local angleRadians = sourceCoordinate:GetAngleRadians( dirVec3 )
    local bearing = UTILS.Round( UTILS.ToDegree( angleRadians ), 0 )

    --  o'clock position
    local heading = sourceGroup:GetUnit(1):GetHeading()
    local sPosition = GetClockPosition( heading, bearing )

    -- distance
    local distance = sourceCoordinate:Get2DDistance(targetCoordinate)
    local sDistance = DistanceToStringA2A( distance, true )

    -- level position
    local sLevelPos = GetLevelPosition( sourceCoordinate, targetCoordinate )
    
    -- angels
    local sAngels = GetAltitudeAsAngelsOrCherubs( targetCoordinate )

    return {
        Bearing = bearing,
        Distance = distance,
        TextDistance = sDistance,
        TextPosition = sPosition,
        TextLevel = sLevelPos,
        TextAngels = sAngels,
        ToString = function()
            return string.format( "%s %s for %s, %s", sPosition, sLevelPos, sDistance, sAngels )
        end
    }
end
 
local _numbers = {
    [1] = "one",
    [2] = "two",
    [3] = "two",
    [4] = "three",
    [5] = "four",
    [6] = "five",
    [7] = "six",
    [8] = "eight",
    [9] = "nine",
    [10] = "ten",
    [11] = "eleven",
    [12] = "twelve"
}
  
function GetClockPosition( heading, bearing )
    local pos = UTILS.Round(((-heading + bearing) % 360) / 30, 0)
    if (pos == 0) then pos = 12 end
    return tostring(_numbers[pos]) .. " o'clock"
end
  
function GetLevelPosition( coord1, coord2 )
    local vDiff = coord1.y - coord2.y -- vertical difference
    local lDiff = math.max(math.abs(coord1.x - coord2.x), math.abs(coord1.z - coord2.z)) -- lateral distance
    local angle = math.deg(math.atan(vDiff / lDiff))
  
    if (math.abs(angle) <= 15) then
      return "level"
    end
  
    if (angle < 0) then
      return "high"
    end
  
    return "low"
end

function GetMSL( controllable )
    local group = getGroup( controllable )
    if (group == nil) then
        return exitWarning("GetMSL :: cannot resolve group from "..Dump(controllable), false)
    end 

    return UTILS.MetersToFeet( group:GetCoordinate().y )
end

function GetFlightLevel( controllable )
    local msl = GetMSL(controllable)
    return UTILS.Round(msl / 100, 0)
end

function GetAGL( controllable )
    local group = getGroup( controllable )
    if (group == nil) then
        return exitWarning("GetAGL :: cannot resolve group from "..Dump(controllable), false)
    end 

    local coord = group:GetCoordinate()
    return coord.y - coord:GetLandHeight()
end

function IsGroupAirborne( controllable, tolerance )
    tolerance = tolerance or 10
    local agl = GetAGL(controllable)
    return agl > tolerance
end

local _navyAircrafts = {
    ["FA-18C_hornet"] = 1,
    ["F-14A-135-GR"] = 2,
    ["AV8BNA"] = 3,
    ["SH-60B"] = 4
}

function IsNavyAircraft( source )
    if isTable(source) then
        -- assume event
        source = source.IniTypeName
        if not source then
            return false end
    end
    if isString(source) then
        return _navyAircrafts[source] ~= nil end

    return false
end

--------------------------------------------- [[ ROUTING ]] ---------------------------------------------


--[[
Gets the index of a named waypoint and returns a table containing it and its internal route index

Parameters
  source :: An arbitrary source. This can be a route, group, unit, or the name of group/unit
  name :: The name of the waypoint to look for

Returns
  On success, an object; otherwise nil
  (object)
  {
    waypoint :: The requested waypoint object
    index :: The waypoints internal route index0
  }
]]--
function FindWaypointByName( source, name )
    local route = nil
    if (isTable(source) and source.ClassName == nil) then
        -- assume route ...
        route = source
    end

    if (route == nil) then
        -- try get route from group ...
        local group = getGroup( source )
        if ( group ~= nil ) then 
        route = group:CopyRoute()
        else
        return nil end
    end

    for k,v in pairs(route) do
        if (v["name"] == name) then
        return { data = v, index = k }
        end
    end
    return nil
end

function RouteDirectTo( controllable, steerpoint )
    if (controllable == nil) then
        return exitWarning("DirectTo-? :: controllable not specified")
    end
    if (steerpoint == nil) then
        return exitWarning("DirectTo-? :: steerpoint not specified")
    end

    local route = nil
    local group = getGroup( controllable )
    if ( group == nil ) then
        return exitWarning("DirectTo-? :: cannot resolve group: "..Dump(controllable))
    end
    
    route = group:CopyRoute()
    if (route == nil) then
        return exitWarning("DirectTo-" .. group.GroupName .." :: cannot resolve route from controllable: "..Dump(controllable))
    end

    local wpIndex = nil
    if (isString(steerpoint)) then
        local wp = FindWaypointByName( route, steerpoint )
        if (wp == nil) then
            return exitWarning("DirectTo-" .. group.GroupName .." :: no waypoint found with name '"..steerpoint.."'")
        end
        wpIndex = wp.index
    elseif (isNumber(steerpoint)) then
        wpIndex = steerpoint
    else
        return exitWarning("DirectTo-" .. group.GroupName .." :: cannot resolved steerpoint: "..Dump(steerpoint))
    end

    local directToRoute = {}
    for i=wpIndex,#route,1 do
        table.insert(directToRoute, route[i])
    end

    return directToRoute

end

function SetRoute( controllable, route )
    if (controllable == nil) then
        return exitWarning("SetRoute-? :: controllable not specified")
    end
    if (not isTable(route)) then
        return exitWarning("SetRoute-? :: invalid route (not a table)")
    end
    local group = getGroup(controllable)
    if (group == nil) then
        return exitWarning("SetRoute-? :: group not found: "..Dump(controllable))
    end
    group:Route( route )
    Trace("SetRoute-"..group.GroupName.." :: group route was set :: DONE")
end

local function calcGroupOffset( group1, group2 )

    local coord1 = group1:GetCoordinate()
    local coord2 = group2:GetCoordinate()
    return {
        x = coord1.x-coord2.x,
        y = coord1.y-coord2.y,
        z = coord1.z-coord2.z
    }

end

FollowOffsetLimits = {
    -- longitudinal offset limits
    xMin = 200,
    xMax = 1000,

    -- vertical offset limits
    yMin = 0,
    yMax = 100,

    -- latitudinal offset limits
    zMin = -30,
    zMax = -1000 
}

function FollowOffsetLimits:New()
    return routines.utils.deepCopy(FollowOffsetLimits)
end

function FollowOffsetLimits:Normalize( vec3 )

    if (math.abs(vec3.x) < math.abs(self.xMin)) then
        if (vec3.x < 0) then
            vec3.x = -self.xMin
        else
            vec3.x = math.abs(self.xMin)
        end
    elseif (math.abs(vec3.x) > math.abs(self.xMax)) then
        if (vec3.x < 0) then
            vec3.x = -self.xMax
        else
            vec3.x = math.abs(self.xMax)
        end
    end

    if (math.abs(vec3.y) < math.abs(self.yMin)) then
        if (vec3.y < 0) then
            vec3.y = -self.yMin
        else
            vec3.y = math.abs(self.yMin)
        end
    elseif (math.abs(vec3.y) > math.abs(self.yMax)) then
        if (vec3.y < 0) then
            vec3.y = -self.yMax
        else
            vec3.y = math.abs(self.yMax)
        end
    end

    if (math.abs(vec3.z) < math.abs(self.zMin)) then
        vec3.z = self.zMin
    elseif (math.abs(vec3.z) > math.abs(self.zMax)) then
        vec3.z = self.xMax
    end

    return vec3
end

--[[
Follow
  Simplifies forcing a group to follow another group to a specified waypoint

Parameters
  follower :: (arbitrary) Specifies the group to be tasked with following the leader group
  leader :: (arbitrary) Specifies the group to be followed
  offset :: (Vec3) When set (individual elements can be set to force separation in that dimension) the follower will take a position, relative to the leader, offset by this value
  lastWaypoint :: (integer; default=last waypoint) When specifed the follower will stop following the leader when this waypont is reached
]]--
function TaskFollow( follower, leader, offsetLimits, lastWaypoint )

    if (follower == nil) then
        return exitWarning("Follow-? :: Follower was not specified")
    end
    local followerGrp = getGroup(follower)
    if (followerGrp == nil) then
        return exitWarning("Follow-? :: Cannot find follower: "..Dump(follower))
    end

    if (leader == nil) then
        return exitWarning("Follow-? :: Leader was not specified")
    end
    local leaderGrp = getGroup(leader)
    if (leaderGrp == nil) then
        return exitWarning("Follow-? :: Cannot find leader: "..Dump(leader))
    end

    if (lastWaypoint == nil) then
        local route = leaderGrp:CopyRoute()
        lastWaypoint = #route
    end

    local off = calcGroupOffset(leaderGrp, followerGrp)

--Debug( "TaskFollow :: off: " .. DumpPretty( off ) )    

    if offsetLimits then
        off = offsetLimits:Normalize(off)
--Debug( "TaskFollow :: normalized off: " .. DumpPretty( off ) )    
    end

    local task = followerGrp:TaskFollow( leaderGrp, off, lastWaypoint)
    followerGrp:SetTask( task )
    Trace("FollowGroup-"..followerGrp.GroupName.." ::  Group is now following "..leaderGrp.GroupName.." to WP #"..tostring(lastWaypoint))

end

function GetRTBWaypoint( group ) 
    -- TODO consider returning -true- if last WP in route is landing WP
    return FindWaypointByName( group, DCAF.WaypointNames.RTB ) ~= nil
end

function CanRTB( group ) 
    return GetDivertWaypoint( group ) ~= nil
end

function RTB( controllable, steerpointName )

    local steerpointName = steerpointName or DCAF.WaypointNames.RTB
    local route = RouteDirectTo(controllable, steerpointName)
    return SetRoute( controllable, route )

end

function GetDivertWaypoint( group ) 
    return FindWaypointByName( group, DCAF.WaypointNames.Divert ) ~= nil
end

function CanDivert( group ) 
    return GetDivertWaypoint( group ) ~= nil
end

local _onDivertFunc = nil

function Divert( controllable, steerpointName )
    local steerpointName = steerpointName or DCAF.WaypointNames.Divert
    local divertRoute = RouteDirectTo(controllable, steerpointName)
    local route = SetRoute( controllable, divertRoute )
    if _onDivertFunc then
        _onDivertFunc( controllable, divertRoute )
    end
    return route
end

function GotoWaypoint( controllable, from, to, offset)
    local group = nil
    if not controllable then
        return exitWarning("GotoWaypoint :: missing controllable")
    else
        group = getGroup(controllable)
        if not group then
            return exitWarning("GotoWaypoint :: cannot resolve group from "..Dump(controllable))
        end
    end
    if not from then
        return exitWarning("GotoWaypoint :: missing 'from'")
    elseif not isNumber(from) then
        return exitWarning("GotoWaypoint :: 'from' is not a number")
    end
    if not to then
        return exitWarning("GotoWaypoint :: missing 'to'")
    elseif not isNumber(to) then
        return exitWarning("GotoWaypoint :: 'to' is not a number")
    end
    if isNumber(offset) then
        from = from + offset
        to = to + offset
    end
    Trace("GotoWaypoint-" .. group.GroupName .. " :: goes direct from waypoint " .. tostring(from) .. " --> " .. tostring(to))
    local dcsCommand = {
        id = 'SwitchWaypoint',
        params = {
          fromWaypointIndex = from,
          goToWaypointIndex = to,
        },
    }
    if not group:IsAir() then
        dcsCommand.id = "GoToWaypoint"
    end
    group:SetCommand( dcsCommand )
    -- group:SetCommand(group:CommandSwitchWayPoint( from, to ))
end

function LandHere( controllable, category, coalition )

    local group = getGroup( controllable )
    if (group == nil) then
        return exitWarning("LandHere-? :: group not found: "..Dump(controllable))
    end

    category = category or Airbase.Category.AIRDROME

    local ab = group:GetCoordinate():GetClosestAirbase2( category, coalition )
    if (ab == nil) then
        return exitWarning("LandHere-"..group.GroupName.." :: no near airbase found")
    end

    local abCoord = ab:GetCoordinate()
    local landHere = {
        ["airdromeId"] = ab.AirdromeID,
        ["action"] = "Landing",
        ["alt_type"] = "BARO",
        ["y"] = abCoord.y,
        ["x"] = abCoord.x,
        ["alt"] = ab:GetAltitude(),
        ["type"] = "Land",
    }
    group:Route( { landHere } )
    Trace("LandHere-"..group.GroupName.." :: is tasked with landing at airbase ("..ab.AirbaseName..") :: DONE")
    return ab

end

function ROEHoldFire( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEHoldFire-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:OptionROEHoldFire()
            Trace("ROEHoldFire"..group.GroupName.." :: holds fire")
        end
    end
end

function ROEReturnFire( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEReturnFire-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:OptionROEReturnFire()
            Trace("ROEReturnFire"..group.GroupName.." :: holds fire unless fired upon")
        end
    end
end

function ROTEvadeFire( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROTEvadeFire-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            Trace("ROTEvadeFire-"..group.GroupName.." :: evades fire")
            group:OptionROTEvadeFire()
        end
    end
end

function ROEOpenFire( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEOpenFire-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:OptionAlarmStateRed()
            Trace("ROEOpenFire-"..group.GroupName.." :: is alarm state RED")
            group:OptionROEOpenFire()
            Trace("ROEOpenFire-"..group.GroupName.." :: can open fire at designated targets")
        end 
    end
end

function ROEOpenFireWeaponFree( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEOpenFireWeaponFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:OptionAlarmStateRed()
            Trace("ROEOpenFireWeaponFree-"..group.GroupName.." :: is alarm state RED")
            group:OptionROEOpenFireWeaponFree()
            Trace("ROEOpenFireWeaponFree-"..group.GroupName.." :: can open fire at designated targets, or targets of opportunity")
        end 
    end
end

function ROEWeaponFree( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEWeaponsFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            if (group:IsShip()) then
                ROEOpenFireWeaponFree( group )
                return
            end
            group:OptionAlarmStateAuto()
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is alarm state AUTO")
            group:OptionROEWeaponFree()
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is weapons free")
        end
    end
end

function ROEDefensive( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEWeaponsFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            ROTEvadeFire( controllable )
            group:OptionAlarmStateRed()
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is alarm state RED")
            ROEHoldFire( group )
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is weapons free")
        end
    end
end

function ROEAggressive( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEWeaponsFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            ROTEvadeFire( controllable )
            group:OptionAlarmStateRed()
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is alarm state RED")
            ROEWeaponFree( group )
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is weapons free")
        end
    end
end

function SetAIOn( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("SetAIOn-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            Trace("SetAIOn-"..group.GroupName.." :: sets AI=ON :: DONE")
            group:SetAIOn()
        end
    end
end

function SetAIOff( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("SetAIOff-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            Trace("SetAIOff-"..group.GroupName.." :: sets AI=OFF :: DONE")
            group:SetAIOff()
        end
    end
end

function Stop( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("Stop-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            if group:IsAir() and group:InAir() then
                Trace("Stop-"..group.GroupName.." :: lands at nearest aeorodrome :: DONE")
                LandHere(group)
            else
                Trace("Stop-"..group.GroupName.." :: sets AI=OFF :: DONE")
                group:SetAIOff()
            end
        end
    end
end

function Resume( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("Resume-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            group:SetAIOn()
        end
    end
end

function TaskAttackGroup( attacker, target )

    local ag = getGroup(attacker)
    if (ag == nil) then
        return exitWarning("TaskAttackGroup-? :: cannot resolve attacker group "..Dump(attacker))
    end
    local tg = getGroup(target)
    if (tg == nil) then
        return exitWarning("TaskAttackGroup-? :: cannot resolve target group "..Dump(tg))
    end

    if (ag:OptionROEOpenFirePossible()) then
        ROEOpenFire(ag)
    end
    ag:SetTask(ag:TaskAttackGroup(tg))
    Trace("TaskAttackGroup-"..ag.GroupName.." :: attacks group "..tg.GroupName..":: DONE")

end

--------------------------------------------- [[ MISSION EVENTS ]] ---------------------------------------------

MissionEvents = { }

local _missionEventsHandlers = {
    _missionEndHandlers = {},
    _groupSpawnedHandlers = {},
    _unitSpawnedHandlers = {},
    _unitDeadHandlers = {},
    _unitKilledHandlers = {},
    _unitCrashedHandlers = {},
    _playerEnteredUnitHandlers = {},
    _playerLeftUnitHandlers = {},
    _ejectionHandlers = {},
    _groupDivertedHandlers = {},
    _weaponFiredHandlers = {},
    _shootingStartHandlers = {},
    _shootingStopHandlers = {},
    _unitHitHandlers = {},
    _aircraftLandedHandlers = {},
    _unitEnteredZone = {},
    _unitInsideZone = {},
    _unitLeftZone = {},
}


local isMissionEventsListenerRegistered = false
local _e = {}

function MissionEvents:Invoke(handlers, data)
    for _, handler in ipairs(handlers) do
        handler( data )
    end
end

function _e:onEvent( event )
local deep = DumpPrettyOptions:New():Deep() -- nisse
--Debug("_e:onEvent-? :: event: " .. DumpPretty(event)) -- nisse

    if event.id == world.event.S_EVENT_MISSION_END then
        MissionEvents:Invoke( _missionEventsHandlers._missionEndHandlers, event )
        return
    end

    local function getTarget(event)
        local dcsTarget = event.target 
        if not dcsTarget and event.weapon then
            dcsTarget = event.weapon:getTarget()
        end
    end

    local function addInitiatorAndTarget( event )
        if event.initiator ~= nil and event.IniUnit == nil then
            event.IniUnit = UNIT:Find(event.initiator)
            event.IniUnitName = event.IniUnit.UnitName
            event.IniGroup = event.IniUnit:GetGroup()
            event.IniGroupName = event.IniGroup.GroupName
        end
        local dcsTarget = event.target or getTarget(event)
        if event.TgtUnit == nil and dcsTarget ~= nil then
            event.TgtUnit = UNIT:Find(dcsTarget)
            event.TgtUnitName = event.TgtUnit.UnitName
            event.TgtGroup = event.TgtUnit:GetGroup()
            event.TgtGroupName = event.TgtGroup.GroupName
        end
        return event
    end

    local function addPlace( event )
        if event.place == nil or event.Place ~= nil then
            return event
        end
        event.Place = AIRBASE:Find( event.place )
        event.PlaceName = event.Place:GetName()
        return event
    end

    -- if (event.id == EVENTS.Birth) then obsolete
    --     if event.IniGroup and #_missionEventsHandlers._groupSpawnedHandlers > 0 then
    --         MissionEvents:Invoke( _missionEventsHandlers._groupSpawnedHandlers, event )
    --     end
    --     if event.IniUnit then
    --         if #_missionEventsHandlers._unitSpawnedHandlers > 0 then
    --             MissionEvents:Invoke( _missionEventsHandlers._unitSpawnedHandlers, event )
    --         end
    --         if  event.IniPlayerName then
    --             MissionEvents:Invoke( _missionEventsHandlers._playerEnteredUnitHandlers, event )
    --         end
    --     end
    --     return
    -- end

    if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then --  event
        if not event.initiator then
            return end -- weird!

        local unit = UNIT:Find(event.initiator)
        if not unit then 
            return end -- weird!

        MissionEvents:Invoke( _missionEventsHandlers._playerEnteredUnitHandlers, {
            time = MissionTime(),
            IniPlayerName = unit:GetPlayerName(),
            IniUnit = unit,
            IniUnitName = unit.UnitName,
            IniGroupName = unit:GetGroup().GroupName,
            IniUnitTypeName = unit:GetTypeName(),
            IniCategoryName = unit:GetCategoryName(),
            IniCategory = unit:GetCategory()
        })
    end

    if event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
        MissionEvents:Invoke( _missionEventsHandlers._playerLeftUnitHandlers, event )
    end

    if event.id == world.event.S_EVENT_DEAD then
        if event.IniUnit and #_missionEventsHandlers._unitDeadHandlers > 0 then
            MissionEvents:Invoke( _missionEventsHandlers._unitDeadHandlers, {
                IniUnit = event.IniUnit,
                IniUnitName = event.IniUnit.UnitName,
                IniGroup = event.IniGroup,
                IniGroupName = event.IniUnit.GroupName,
                IniPlayerName = event.IniUnit:GetPlayerName()
            })
        end
        return
    end

    if event.id == world.event.S_EVENT_KILL then
        if #_missionEventsHandlers._unitKilledHandlers > 0 then
            MissionEvents:Invoke( _missionEventsHandlers._unitKilledHandlers, {
                IniUnit = UNIT:Find(event.initiator),
                TgtUnit = UNIT:Find(event.target)
            })
        end
        if #_missionEventsHandlers._unitDeadHandlers > 0 then
            local unit = UNIT:Find(event.target)
            local group = unit:GetGroup()
            _e:onEvent({
                id = world.event.S_EVENT_DEAD,
                IniUnit = unit,
                IniUnitName = unit:GetName(),
                IniGroup = group,
                IniGroupName = group.GroupName,
                IniPlayerName = unit:GetPlayerName()
            })
        end
        return
    end

    if event.id == world.event.S_EVENT_EJECTION then
        MissionEvents:Invoke( _missionEventsHandlers._ejectionHandlers, event)
        return
    end

    if event.id == world.event.S_EVENT_CRASH then
        MissionEvents:Invoke( _missionEventsHandlers._unitCrashedHandlers, event)
        return
    end

    if event.id == world.event.S_EVENT_SHOT then
        if #_missionEventsHandlers._weaponFiredHandlers > 0 then
            local dcsTarget = event.target 
            if not dcsTarget and event.weapon then
                dcsTarget = event.weapon:getTarget()
            end
            MissionEvents:Invoke( _missionEventsHandlers._weaponFiredHandlers, addInitiatorAndTarget(event))
        end
        return
    end
        
    if event.id == world.event.S_EVENT_SHOOTING_START then
        MissionEvents:Invoke( _missionEventsHandlers._shootingStartHandlers, addInitiatorAndTarget(event))
        return
    end

    if event.id == world.event.S_EVENT_SHOOTING_END then
        MissionEvents:Invoke( _missionEventsHandlers._shootingStopHandlers, addInitiatorAndTarget(event))
        return
    end
        
    if event.id == world.event.S_EVENT_HIT then
        MissionEvents:Invoke( _missionEventsHandlers._unitHitHandlers, event)
        return
    end

    if event.id == world.event.S_EVENT_LAND then
        addInitiatorAndTarget(addPlace(event))
-- Debug("nisse - #_missionEventsHandlers._aircraftLandedHandlers: " .. tostring(#_missionEventsHandlers._aircraftLandedHandlers))
        MissionEvents:Invoke(_missionEventsHandlers._aircraftLandedHandlers, addInitiatorAndTarget(addPlace(event)))
        return
    end

end

function MissionEvents:AddListener(listeners, func, predicateFunc, insertFirst )
    if insertFirst == nil then
        insertFirst = false
    end
    if insertFirst then
        table.insert(listeners, 1, func)
    else
        table.insert(listeners, func)
    end
    if isMissionEventsListenerRegistered then
        return 
    end
    isMissionEventsListenerRegistered = true
    world.addEventHandler(_e)
end

function MissionEvents:RemoveListener(listeners, func)
    local idx = 0
    for i, f in ipairs(listeners) do
        if func == f then
            idx = i
        end
    end
    if idx > 0 then
        table.remove(listeners, idx)
    end
end

function MissionEvents:OnMissionEnd( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._missionEndHandlers, func, nil, insertFirst) end

function MissionEvents:OnGroupSpawned( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._groupSpawnedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnGroupSpawned( func ) MissionEvents:RemoveListener(_missionEventsHandlers._groupSpawnedHandlers, func) end

function MissionEvents:OnUnitSpawned( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitSpawnedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitSpawned( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitSpawnedHandlers, func) end

function MissionEvents:OnUnitDead( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitDeadHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitDead( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitDeadHandlers, func) end

function MissionEvents:OnUnitKilled( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitKilledHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitKilled( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitKilledHandlers, func) end

function MissionEvents:OnUnitCrashed( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitCrashedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitCrashed( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitCrashedHandlers, func) end

function MissionEvents:OnPlayerEnteredUnit( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._playerEnteredUnitHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnPlayerEnteredUnit( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerEnteredUnitHandlers, func) end

function MissionEvents:OnPlayerLeftUnit( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._playerLeftUnitHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnPlayerLeftUnit( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerLeftUnitHandlers, func) end

function MissionEvents:OnEjection( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._ejectionHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnEjection( func ) MissionEvents:RemoveListener(_missionEventsHandlers._ejectionHandlers, func) end

function MissionEvents:OnWeaponFired( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._weaponFiredHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnWeaponFired( func ) MissionEvents:RemoveListener(_missionEventsHandlers._weaponFiredHandlers, func) end

function MissionEvents:OnShootingStart( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._shootingStartHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnShootingStart( func ) MissionEvents:RemoveListener(_missionEventsHandlers._shootingStartHandlers, func) end

function MissionEvents:OnShootingStop( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._shootingStopHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnShootingStop( func ) MissionEvents:RemoveListener(_missionEventsHandlers._shootingStopHandlers, func) end

function MissionEvents:OnUnitHit( func, insertFirst ) MissionEvents:AddListener(_missionEventsHandlers._unitHitHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitHit( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitHitHandlers, func) end

function MissionEvents:OnAircraftLanded( func, insertFirst ) 
    MissionEvents:AddListener(_missionEventsHandlers._aircraftLandedHandlers, func, nil, insertFirst) 
-- Debug("core - MissionEvents:OnAircraftLanded :: func: " .. tostring(func) .. " ::  registered :: #_aircraftLandedHandlers: " .. tostring(#_missionEventsHandlers._aircraftLandedHandlers))    
end
function MissionEvents:EndOnAircraftLanded( func ) MissionEvents:RemoveListener(_missionEventsHandlers._aircraftLandedHandlers, func) end


--- CUSTOM EVENTS
function MissionEvents:OnPlayerEnteredAirplane( func, insertFirst ) 
    MissionEvents:AddListener(_missionEventsHandlers._playerEnteredUnitHandlers, 
        function( event )
            if event.IniUnit:IsAirPlane() then
                func( event )
            end
        end,
        nil,
        insertFirst) 
end
function MissionEvents:EndOnPlayerEnteredAirplane( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerEnteredUnitHandlers, func) end

function MissionEvents:OnPlayerLeftAirplane( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._playerLeftUnitHandlers, 
        function( event )
            if event.IniUnit:IsAirPlane() then
                func( event )
            end
        end,
        nil,
        insertFirst) 
end
function MissionEvents:EndOnPlayerLeftAirplane( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerLeftUnitHandlers, func) end

function MissionEvents:OnPlayerEnteredHelicopter( func, insertFirst ) 
    MissionEvents:AddListener(_missionEventsHandlers._playerEnteredUnitHandlers, 
        function( event )
            if (event.IniUnit:IsHelicopter()) then
                func( event )
            end
        end,
        nil,
        insertFirst)
end
function MissionEvents:EndOnPlayerEnteredHelicopter( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerEnteredUnitHandlers, func) end

function MissionEvents:OnPlayerLeftHelicopter( func, insertFirst ) 
    MissionEvents:AddListener(_missionEventsHandlers._playerLeftUnitHandlers, 
        function( event )
            if (event.IniUnit:IsHelicopter()) then
                func( event )
            end
        end,
        nil,
        insertFirst)
end
function MissionEvents:EndOnPlayerLeftHelicopter( func ) MissionEvents:RemoveListener(_missionEventsHandlers._playerLeftUnitHandlers, func) end

function MissionEvents:OnGroupDiverted( func, insertFirst ) 
    MissionEvents:AddListener(_missionEventsHandlers._groupDivertedHandlers, 
        func,
        nil,
        insertFirst) 
end
function MissionEvents:EndOnGroupDiverted( func ) MissionEvents:RemoveListener(_missionEventsHandlers._groupDivertedHandlers, func) end


_onDivertFunc = function( controllable, route ) -- called by Divert()
    MissionEvents:Invoke(_missionEventsHandlers._groupDivertedHandlers, { Controllable = controllable, Route = route })
end

------------------------------- [ EVENT PRE-REGISTRATION /LATE ACTIVATION ] -------------------------------
--[[ 
    This api allows Storylines to accept delegates and postpone their registration 
    until the Storyline runs
 ]]

 local DCAFEventActivation = {  -- use to pre-register event handler, to be activated when Storyline runs
    eventName = nil,         -- string (name of MissionEvents:OnXXX function )
    func = nil,              -- event handler function
    notifyFunc = nil,        -- (optional) callback handler, for notifying the event was activated
    insertFirst = nil,       -- boolean; passed to event delegate registration (see StorylineEventDelegate:ActivateFor)
}

local _DCAFEvents_lateActivations = {} -- { key = storyline name, value = { -- list of <DCAFEventActivation> } }

DCAFEvents = {
    OnAircraftLanded = "OnAircraftLanded",
    OnGroupDiverted = "OnGroupDiverted",
    OnGroupEntersZone = "OnGroupEntersZone",
    OnGroupInsideZone = "OnGroupInsideZone",
    OnGroupLeftZone = "OnGroupLeftZone",
    OnUnitEntersZone = "OnUnitEntersZone",
    OnUnitInsideZone = "OnUnitInsideZone",
    OnUnitLeftZone = "OnUnitLeftZone",
    -- todo add more events ...
}

local _DCAFEvents = {
    [DCAFEvents.OnAircraftLanded] = function(func, insertFirst) MissionEvents:OnAircraftLanded(func, insertFirst) end,
    [DCAFEvents.OnGroupDiverted] = function(func, insertFirst) MissionEvents:OnGroupDiverted(func, insertFirst) end,
    [DCAFEvents.OnGroupEntersZone] = function(func, insertFirst) MissionEvents:OnGroupEntersZone(func, insertFirst) end,
    [DCAFEvents.OnGroupInsideZone] = function(func, insertFirst) MissionEvents:OnGroupInsideZone(func, insertFirst) end,
    [DCAFEvents.OnGroupLeftZone] = function(func, insertFirst) MissionEvents:OnGroupLeftZone(func, insertFirst) end,
    [DCAFEvents.OnUnitEntersZone] = function(func, insertFirst) MissionEvents:OnUnitEntersZone(func, insertFirst) end,
    [DCAFEvents.OnUnitInsideZone] = function(func, insertFirst) MissionEvents:OnUnitInsideZone(func, insertFirst) end,
    [DCAFEvents.OnUnitLeftZone] = function(func, insertFirst) MissionEvents:OnUnitLeftZone(func, insertFirst) end,
    -- todo add more events ...
}

function _DCAFEvents:Activate(activation)
    local activator = _DCAFEvents[activation.eventName]
    if activator then
-- Debug("nisse - DCAFEvents:Activate :: activator: " .. DumpPretty(activator))
        activator(activation.func, activation.insertFirst)

        -- notify event activation, if callback func is registered ...
        if activation.notifyFunc then
            activation.notifyFunc({
                EventName = activation.eventName,
                Func = activation.func,
                InsertFirst = activation.insertFirst
            })
        end
    else
        error("DCAFEvents:Activate :: cannot activate delegate for event '" .. activation.eventName .. " :: event is not supported")
    end
end

function _DCAFEvents:ActivateFor(source)
--Debug("nisse - _DCAFEvents:ActivateFor :: source:" .. Dump(source) .. " :: _DCAFEvents_lateActivations: " .. DumpPrettyDeep(_DCAFEvents_lateActivations))
    local activations = _DCAFEvents_lateActivations[source]
    if not activations then
        return
    end
--Debug("nisse - _DCAFEvents:ActivateFor :: #activations: " .. DumpPrettyDeep(#activations) .. " :: (1 expected)")
    _DCAFEvents_lateActivations[source] = nil
    for _, activation in ipairs(activations) do
        _DCAFEvents:Activate(activation)
    end
end

function DCAFEvents:PreActivate(source, eventName, func, onActivateFunc)
    if source == nil then
        error("DCAFEvents:LateActivate :: unassigned source") end

    if not isAssignedString(eventName) then
        error("DCAFEvents:LateActivate :: unsupported eventName value: " .. Dump(eventName)) end

    if not DCAFEvents[eventName] then
        error("DCAFEvents:LateActivate :: unsupported event: " .. Dump(eventName)) end

    local activation = routines.utils.deepCopy(DCAFEventActivation)
    activation.eventName = eventName
    activation.func = func
    activation.onActivateFunc = onActivateFunc
    local activations = _DCAFEvents_lateActivations[source]
    if not activations then
        activations = {}
        _DCAFEvents_lateActivations[source] = activations
    end
    table.insert(activations, activation)
end

function DCAFEvents:ActivateFor(source) _DCAFEvents:ActivateFor(source) end

--------------------------------------------- [[ ZONE EVENTS ]] ---------------------------------------------

local ZoneEventState = {
    Outside = 1,
    Inside = 2,
    Left = 3,
    _countZoneEventZones = 0,        -- no. of 'zone centric' zone events (as opposed to 'object centric')
    _timer = nil,
}

local ZoneEventStrategy = {
    Named = 'named',
    Any = 'any'
}

local ZoneEventType = {
    Enter = 'enter',
    Inside = 'inside',
    Left = 'left'
}

local ZoneEventObjectType = {
    Any = 'any',
    Group = 'group',
    Unit = 'unit'
}

local ZoneEvent = {
    objectName = nil,                -- string; name of group / unit (nil if objectType = 'any')
    objectType = nil,                -- <ZoneEventObjectType>
    object = nil,                    -- UNIT or GROUP
    eventType = nil,                 -- <MonitoredZoneEventType>
    zoneName = nil,                  -- string; name of zone
    zone = nil,                      -- ZONE
    func = nil,                      -- function to be invoked when event triggers
    state = ZoneEventState.Outside,  -- <MonitoredZoneEventState>
    isZoneCentered = false,          -- when set, the ZoneEvent:EvaluateForZone() functon is invoked; otherwise ZoneEvent:EvaluateForObject()
    continous = false,               -- when set, the event is not automatically removed when triggered
}

local ZoneCentricZoneEventInfo = {
    zone = nil,                      -- the monitored zone
    zoneEvents = {},                 -- list of <ZoneEvent>
}

local ObjectCentricZoneEvents = { 
    -- list of <MonitoredZoneEvent>
}

local ZoneCentricZoneEvents = {
    -- key = zoneName, 
    -- value = <ZoneCentricZoneEventInfo>
}

local ZoneEventArgs = {
    EventType = nil,                 -- <ZoneEventType>
    ZoneName = nil,                  -- string
}

function ZoneCentricZoneEventInfo:New(zone, zoneName)
    local info = routines.utils.deepCopy(ZoneCentricZoneEventInfo)
    info.zone = zone
    ZoneCentricZoneEvents[zoneName] = info
    ZoneEventState._countZoneEventZones = ZoneEventState._countZoneEventZones + 1
    return info
end

function ZoneCentricZoneEventInfo:Scan()
    local setGroup = SET_GROUP:New():FilterZones({ self.zone }):FilterActive():FilterOnce()
    local groups = {}
    setGroup:ForEachGroup(
        function(g)
            table.insert(groups, g)
        end
    )
    return groups
end

function ZoneEventArgs:New(zoneEvent)
    local args = routines.utils.deepCopy(ZoneEventArgs)
    args.EventType = zoneEvent.eventType
    args.ZoneName = zoneEvent.zoneName
    return args
end

function ZoneEventArgs:End()
    self._terminateEvent = true
    return self
end

local function stopMonitoringZoneEventsWhenEmpty()
    if ZoneEventState._timer ~= nil and #ObjectCentricZoneEvents == 0 and ZoneEventState._countZoneEventZones == 0 then
        Trace("stopMonitoringZoneEventsWhenEmpty :: mission zone events monitoring stopped")
        ZoneEventState._timer:Stop()
        ZoneEventState._timer = nil
    end
end

local function startMonitorZoneEvents()
    local function monitor()

        -- zone object events ...
        local removeZoneObjectEvents = {}
        for _, zoneEvent in ipairs(ObjectCentricZoneEvents) do
            if zoneEvent:EvaluateForObject() then
                table.insert(removeZoneObjectEvents, zoneEvent)
            end
        end
        for _, zoneEvent in ipairs(removeZoneObjectEvents) do
            zoneEvent:Remove()
        end

        -- zone 'all objects' events ...
        local removeZoneEvents = {}
        for zoneName, zesg in pairs(ZoneCentricZoneEvents) do
            local groups = zesg:Scan()
            if #groups > 0 then
                for _, zoneEvent in ipairs(zesg.zoneEvents) do
                    if zoneEvent:EvaluateForZone(zesg) then
                        table.insert(removeZoneEvents, zoneEvent)
                    end
                end
            end
            for _, zoneEvent in ipairs(removeZoneEvents) do
                local index = tableIndexOf(zesg.zoneEvents, zoneEvent)
                if index < 1 then
                    error("startMonitorZoneEvents_monitor :: cannot remove zone event :: event was not found in the internal ZESG") end
                
                table.remove(zesg.zoneEvents, index)
                if #zesg.zoneEvents == 0 then
                    ZoneCentricZoneEvents[zoneName] = nil
                    ZoneEventState._countZoneEventZones = ZoneEventState._countZoneEventZones - 1
                end
            end
        end
        stopMonitoringZoneEventsWhenEmpty()
    end
    -- todo consider monitoring zones for 'any' object
    if not ZoneEventState._timer then
        ZoneEventState._timer = TIMER:New(monitor):Start(1, 1)
    end
end

function ZoneEvent:Trigger(object, objectName)
    local event = ZoneEventArgs:New(self)
    if isGroup(object) then
        event.IniGroup = self.object
        event.IniGroupName = event.IniGroup.GroupName
    elseif isUnit(object) then
        event.IniUnit = self.object
        event.IniUnitName = self.object.UnitName
        event.IniGroup = self.object:GetGroup()
        event.IniGroupName = event.IniGroup.GroupName
    end
    self.func(event)
    return not self.continous or event._terminateEvent
end

function ZoneEvent:TriggerMultiple(groups)
    local event = ZoneEventArgs:New(self)
    event.IniGroups = groups
    self.func(event)
    return not self.continous or event._terminateEvent
end

local function isAnyGroupUnitInZone(group, zone)
    local units = group:GetUnits()
    for _, unit in ipairs(units) do
        if unit:IsInZone(zone) then
            return true
        end
    end
    return false
end

function ZoneEvent:EvaluateForZone(groups)
    -- 'zone perspective'; use <zone> to check event ...
    return self:TriggerMultiple(groups)
end

function ZoneEvent:EvaluateForObject()
    -- 'named object perspective'; use <object> to check zone event ...
    -- entered zone ....
    if self.eventType == ZoneEventType.Enter then
        if self.objectType == 'group' then
            if isAnyGroupUnitInZone(self.object, self.zone) then
                return self:Trigger(self.object, self.objectName) 
            end
        elseif self.object:IsInZone(self.zone) then
            return self:Trigger(self.object, self.objectName) 
        end
        return false
    end

    -- left zone ...
    if self.eventType == ZoneEventType.Left then
        local isInZone = nil
        if self.objectType == ZoneEventObjectType.Group then
            isInZone = isAnyGroupUnitInZone(self.object, self.zone)
        else
            isInZone = self.object:IsInZone(self.zone)
        end
        if isInZone then
            self.state = ZoneEventState.Inside
            return false
        elseif self.state == ZoneEventState.Inside then
            return self:Trigger(self.object, self.objectName) 
        end
        return false
    end

    -- inside zone ...
    if self.eventType == ZoneEventType.Inside then
        if self.objectType == ZoneEventObjectType.Group then
            if isAnyGroupUnitInZone(self.object, self.zone) then
                return self:Trigger(self.object, self.objectName) 
            end
        elseif self.object:IsInZone(self.zone) then
            return self:Trigger(self.object, self.objectName) 
        end
    end
    return false
end

function ZoneEvent:Insert()
    if self.isZoneCentered then
        local info = ZoneCentricZoneEvents[self.zoneName]
        if not info then
            info = ZoneCentricZoneEventInfo:New(self.zone, self.zoneName)
        end
        table.insert(info.zoneEvents, self)
    else
        table.insert(ObjectCentricZoneEvents, self)
    end
    startMonitorZoneEvents()
end
    
function ZoneEvent:Remove()
    if self.objectType ~= ZoneEventObjectType.Any then
        local index = tableIndexOf(ObjectCentricZoneEvents, self)
        if index < 1 then
            error("ZoneEvent:Remove :: cannot find zone event")
        end
        table.remove(ObjectCentricZoneEvents, index)
    end
    stopMonitoringZoneEventsWhenEmpty()
end

function ZoneEvent:NewForZone(objectType, eventType, zone, func, continous, makeZest)
    local zoneEvent = routines.utils.deepCopy(ZoneEvent)
    zoneEvent.isZoneCentered = true
    zoneEvent.objectType = objectType
    if eventType ~= 'enter' and eventType ~= 'inside' and eventType ~= 'left' then
        error("MonitoredZoneEvent:New :: unexpected event type: " .. Dump(eventType))
    end
    zoneEvent.eventType = eventType

    if not isAssignedString(zone) then
        error("MonitoredZoneEvent:New :: unexpected/unassigned zone: " .. Dump(zone))
    end
    zoneEvent.zone = ZONE:FindByName(zone)
    zoneEvent.zoneName = zone

    if not isFunction(func) then
        error("MonitoredZoneEvent:New :: unexpected/unassigned callack function: " .. Dump(func))
    end
    zoneEvent.func = func

    if eventType == ZoneEventType.Inside and not isBoolean(continous) then
        continous = true
    end
    if not isBoolean(continous) then
        continous = false
    end
    zoneEvent.continous = continous

    if makeZest then
        local info = ZoneCentricZoneEvents[zoneEvent.zoneName]
        if not info then
            info = ZoneCentricZoneEventInfo:New(zoneEvent.zone)
            ZoneCentricZoneEvents[zoneEvent.zoneName] = info
        end
        info:AddEvent()
    end
    return zoneEvent
end

function ZoneEvent:NewForObject(object, objectType, eventType, zone, func, continous)
    local zoneEvent = ZoneEvent:NewForZone(eventType, zone, func, continous, false)
    zoneEvent.isZoneCentered = false
    if objectType == 'unit' then
        zoneEvent.object = getUnit(object)
        if not zoneEvent.object then
            error("MonitoredZoneEvent:New :: cannot resolve UNIT from " .. Dump(object))
        end
    elseif objectType == 'group' then
        zoneEvent.object = getGroup(object)
        if not zoneEvent.object then
            error("MonitoredZoneEvent:New :: cannot resolve GROUP from " .. Dump(object))
        end
    elseif objectType ~= ZoneEventStrategy.Any then
        error("MonitoredZoneEvent:New :: cannot resolve object from " .. Dump(object))
    end
    zoneEvent.objectType = objectType

    if eventType == ZoneEventType.Inside and not isBoolean(continous) then
        continous = true
    end
    if not isBoolean(continous) then
        continous = false
    end
    zoneEvent.continous = continous
    return zoneEvent
end

function MissionEvents:OnUnitEntersZone( unit, zone, func, continous )
    if unit == nil then
        error("MissionEvents:OnUnitEntersZone :: unit was unassigned") end

    local zoneEvent = ZoneEvent:NewForObject(
        unit, 
        ZoneEventObjectType.Unit, 
        ZoneEventType.Enter, 
        zone, 
        func,
        continous)
    zoneEvent:Insert()
end
function MissionEvents:EndOnUnitEntersZone( func ) 
    -- todo Implement MissionEvents:EndOnUnitEntersZone
end

function MissionEvents:OnUnitInsideZone( unit, zone, func, continous )
    if unit == nil then
        error("MissionEvents:OnUnitInsideZone :: unit was unassigned") end

    if not isBoolean(continous) then
        continous = true
    end
    local zoneEvent = ZoneEvent:NewForObject(
        unit, 
        ZoneEventObjectType.Unit, 
        ZoneEventType.Inside, 
        zone, 
        func,
        continous)
    zoneEvent:Insert()
end
function MissionEvents:EndOnUnitInsideZone( func ) 
    -- todo Implement MissionEvents:EndOnUnitInsideZone
end

function MissionEvents:OnUnitLeftZone( unit, zone, func, continous )
    if unit == nil then
        error("MissionEvents:OnUnitLeftZone :: unit was unassigned") end

    local zoneEvent = ZoneEvent:NewForObject(
        unit, 
        ZoneEventObjectType.Unit, 
        ZoneEventType.Left, 
        zone, 
        func,
        continous)
    zoneEvent:Insert()
end
function MissionEvents:EndOnUnitLeftZone( func ) 
    -- todo Implement MissionEvents:EndOnUnitLeftZone
end

function MissionEvents:OnGroupEntersZone( group, zone, func, continous )
    if group == nil then
        MissionEvents:OnGroupInsideZone( nil, zone, func )
    else
        local zoneEvent = ZoneEvent:NewForObject(
            group, 
            ZoneEventObjectType.Group, 
            ZoneEventType.Enter, 
            zone, 
            func,
            continous)
        zoneEvent:Insert()
    end
end
function MissionEvents:EndOnGroupEntersZone( func ) 
    -- todo Implement MissionEvents:EndOnGroupEntersZone
end

function MissionEvents:OnGroupInsideZone( group, zone, func, continous )
    if not isBoolean(continous) then
        continous = true
    end
    local zoneEvent = nil
    if group ~= nil then
        zoneEvent = ZoneEvent:NewForObject(
            group, 
            ZoneEventObjectType.Group, 
            ZoneEventType.Inside, 
            zone, 
            func,
            continous)
    else
        zoneEvent = ZoneEvent:NewForZone(
            ZoneEventObjectType.Group, 
            ZoneEventType.Inside, 
            zone, 
            func,
            continous)
    end
    zoneEvent:Insert()
end
function MissionEvents:EndOnGroupInsideZone( func ) 
    -- todo Implement MissionEvents:EndOnGroupInsideZone
end

function MissionEvents:OnGroupLeftZone( group, zone, func, continous )
    if group == nil then
        error("MissionEvents:OnGroupLeftZone :: group was unassigned") end

    local zoneEvent = ZoneEvent:NewForObject(
        group, 
        ZoneEventObjectType.Group, 
        ZoneEventType.Left, 
        zone, 
        func,
        continous)
    zoneEvent:Insert()
end
function MissionEvents:EndOnGroupLeftZone( func ) 
    -- todo Implement MissionEvents:EndOnGroupLeftZone
end


Trace("DCAF.Core was loaded")