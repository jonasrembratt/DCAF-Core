DCAF = {
    Trace = true,
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
function isAirbase( value ) return isClass(value, "AIRBASE") end

function getTableType(table)
    if not isTable(table) then
        return end

    for k, v in pairs(table) do
        if isString(k) then
            return "dictionary"
        elseif isNumber(k) then
            return "list"
        end
    end
end

function isList( value ) 
    local tableType = getTableType(value)
    return tableType == "list"
end

function isDictionary( value ) 
    local tableType = getTableType(value)
    return tableType == "dictionary"
end

function isAssignedString( value )
    if not isString(value) then
        return false end

    return string.len(value) > 0 
end

function DCAF.trimInstanceFromName( name, qualifierAt )
    if not isNumber(qualifierAt) then
        qualifierAt = string.find(name, "#%d")
    end
    if not qualifierAt then
        return name end

    return string.sub(name, 1, qualifierAt-1), string.sub(name, qualifierAt)
end

function DCAF.parseSpawnedUnitName(name)
    local groupName, indexer = DCAF.trimInstanceFromName(name)
    if groupName == name then
-- Debug("nisse - DCAF.parseSpawnedUnitName :: groupName: " .. groupName)    
        return name end

    -- indexer now have format: <group indexer>-<unit indexer> (eg. "001-2", for second unit of first spawned group)
    local dashAt = string.find(indexer, '-')
    if not dashAt then
-- Debug("nisse - DCAF.parseSpawnedUnitName :: groupName: " .. groupName)    
        -- should never happen, but ...
        return name end
    
    local unitIndex = string.sub(indexer, dashAt+1)
-- Debug("nisse - DCAF.parseSpawnedUnitName :: groupName: " .. groupName .. " :: indexer: " .. indexer)    
    return groupName, tonumber(unitIndex)
end

function isGroupNameInstanceOf( name, templateName )
    if name == templateName then
        return true end

    -- check for spawned pattern (eg. "Unit-1#001-1") ...
    local i = string.find(name, "#%d")
    if i then
        local test = trimInstanceFromName(name, i)
        if test == templateName then
            return true, templateName end
    end

    if i and trimInstanceFromName(name, i) == templateName then
        return true, templateName
    end
    return false
end

function isGroupInstanceOf(group, groupTemplate)
    group = getGroup(group)
    if not group then
        return error("isGroupInstanceOf :: cannot resolve group from: " .. Dump(group)) end
        
        groupTemplate = getGroup(groupTemplate)
    if not groupTemplate then
        return error("isGroupInstanceOf :: cannot resolve group template from: " .. Dump(groupTemplate)) end
            
    return isGroupNameInstanceOf(group.GroupName, groupTemplate.GroupName)
end

function isUnitNameInstanceOf(name, templateName)
    if name == templateName then
        return true end

-- Debug("isUnitNameInstanceOf :: name: " .. name .. " :: templateName: " .. templateName)        
    -- check for spawned pattern (eg. "Unit-1#001-1") ...
    local i = string.find(name, "#%d")
    if i then
        local test, instanceElement = trimInstanceFromName(name, i)
-- Debug("isUnitNameInstanceOf :: test: " .. test)        
        if test == templateName then
Debug("isUnitNameInstanceOf :: nisse")        
            -- local counterAt = string.find(instanceElement, "-")
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
    unit = getUnit(unit)
    if not unit then
        return error("isUnitInstanceOf :: cannot resolve unit from: " .. Dump(unit)) end
    
    unitTemplate = getUnit(unitTemplate)
    if not unitTemplate then
        return error("isUnitInstanceOf :: cannot resolve unit template from: " .. Dump(unitTemplate)) end

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

function Feet(feet)
    return UTILS.FeetToMeters(feet)
end

function Knots(knots)
    return UTILS.KnotsToMps(knots)
end

function Hours(seconds)
    if isNumber(seconds) then
        return seconds * 3600
    end
end

function Minutes(seconds)
    if isNumber(seconds) then
        return seconds * 60
    end
end

function NauticalMiles( nm )
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

function concatList(list, separator, itemSerializeFunc)
    if not isString(separator) then
        separator = ", "
    end
    local s = ""
    local count = 0
    for _, v in ipairs(list) do
        if count > 0 then
            s = s .. separator
        end
        if itemSerializeFunc then
            s = s .. itemSerializeFunc(v)
        else
            s = s .. v:ToString() or tostring(v)
        end
    end
    return s
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
Coalition = {
    Blue = "blue",
    Red = "red",
    Neutral = "neutral"
}

GroupType = {
    Air = "Air",
    Airplane = "Airplane",
    Helicopter = "Helicopter",
    Ship = "Ship",
    Ground = "Ground",
    Structure = "Structure",
}

function Coalition.IsValid(value)
    if isString(value) then
        return value == Coalition.Blue 
            or value == Coalition.Red
            or value == Coalition.Neutral
    elseif isList(value) then
        for _, v in ipairs(value) do
            if not Coalition.IsValid(v) then
                return false end
        end
        return true
    end
end

function GroupType.IsValid(value)
    if isString(value) then
        return value == GroupType.Air
            or value == GroupType.Airplane
            or value == GroupType.Ground
            or value == GroupType.Ship
            or value == GroupType.Structure
    elseif isList(value) then
        for _, v in ipairs(value) do
            if not GroupType.IsValid(v) then
                return false end
        end
        return true
    end
end


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

function activateNow( source )
-- nisse
if isAssignedString(source) then
    Debug("activateNow( \"" .. source .. "\"")
else
    Debug("activateNow( \"" .. source.GroupName .. "\"")
end

    local group = getGroup( source )
    if not group then
        return exitWarning("activateNow :: cannot resolve group from " .. Dump(source))
    end
    if not group:IsActive() then
        Trace("activateNow :: activates group '" .. group.GroupName .. "'")
        group:Activate()
    end
    return group
end

function spawnNow( source )
-- nisse
if isAssignedString(source) then
    Debug("spawnNow( \"" .. source .. "\"")
else
    Debug("spawnNow( \"" .. source.GroupName .. "\"")
end    
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

--- Retrieves the textual form of MOOSE's 
function CALLSIGN.Tanker:ToString(nCallsign)
    if     nCallsign == CALLSIGN.Tanker.Arco then return "Arco"
    elseif nCallsign == CALLSIGN.Tanker.Shell then return "Shell"
    elseif nCallsign == CALLSIGN.Tanker.Texaco then return "Texaco"
    end
end

function CALLSIGN.Tanker:FromString(sCallsign)
    if     sCallsign == "Arco" then return CALLSIGN.Tanker.Arco
    elseif sCallsign == "Shell" then return CALLSIGN.Tanker.Shell
    elseif sCallsign == "Texaco" then return Tanker.Texaco
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

    local zone = ZONE_GROUP:New(group.GroupName.."-escorts", group, NauticalMiles(5))
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
        maxDistance = NauticalMiles(1.5)
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

function GetCallsign(source)
    local includeUnitNumber = false
    local unit = getUnit(source)
    if unit then
        includeUnitNumber = true        
    else
        local group = getGroup(source)
        if not group then
            error("GetCallsignNameAndNumber :: cannot resolve unit or group from " .. DumpPretty(source)) end

        unit = group:GetUnit(1)
    end
    local callsign = unit:GetCallsign()
    local name
    local number
    local sNumber = string.match(callsign, "%d+")
    if sNumber then
        local numberAt = string.find(callsign, sNumber)
        name = string.sub(callsign, 1, numberAt-1)
        if not includeUnitNumber then
            return name, tonumber(sNumber) end
        
        local sUnitNumber = string.sub(callsign, numberAt)
        local dashAt = string.find(sNumber, ".-.")
        if dashAt then
            sUnitNumber = string.sub(sUnitNumber, dashAt+1)
            sUnitNumber = string.match(sUnitNumber, "%d+")
            return name, tonumber(sNumber), tonumber(sUnitNumber)
        end
    end
    return callsign
end

function GetRTBAirbaseFromRoute(group)
    local forGroup = getGroup(group)
    if not forGroup then
        error("GetRTBAirbaseFromRoute :: could not resolve group from " .. DumpPretty(group)) end

    local homeBase
    local route = forGroup:CopyRoute()
    local lastWp = route[#route]
    if lastWp.airdromeId then
        homeBase = AIRBASE:FindByID(lastWp.airdromeId)
    else
        local wp0 = route[1]
        if wp0.airdromeId then
            homeBase = AIRBASE:FindByID(wp0.airdromeId)
        else
            local coord = forGroup:GetCoordinate()
            homeBase = coord:GetClosestAirbase(Airbase.Category.AIRDROME, forGroup:GetCoalition())
        end
    end
    return homeBase
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
    deep = false,             -- boolean or number (number can control how many levels to present for 'deep')
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
    if isNumber(value) then
        value = value+1 -- ensures 1 = only show root level details, 2 = show root + second level details etc. (0 == not deep)
    end
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

        local deep = options.deep
        if isNumber(deep) then
            deep = deep > ilvl
        end
        if (not deep or not DCAF.Debug) and ilvl > 0 then
            if options.asJson then
            return "{ }" 
        end
        if tableIsUnassigned(value) then
            return "{ }"
        else
            return "{ --[[ data omitted ]] }"
        end
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
    if isNumber(options) then
        options = DumpPrettyOptions:New():Deep(options)
    elseif isTable(options) then
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
  
function GetAltitudeAsAngelsOrCherubs( value ) 
    local feet
    if isTable(value) and value.ClassName == "COORDINATE" then
        feet = UTILS.MetersToFeet( value.y )
    elseif isNumber( value ) then
        feet = UTILS.MetersToFeet( value )
    elseif isAssignedString( value ) then
        feet = UTILS.MetersToFeet( tonumber(value) )
    else
        error("GetAltitudeAsAngelsOrCherubs :: unexpected value: " .. DumpPretty(value) )
    end
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
    if isUnit(source) then
        source = source:GetTypeName() 
    elseif isTable(source) then
        -- assume event
        source = source.IniUnitTypeName
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
    if isTable(source) and source.ClassName == nil then
        -- assume route ...
        route = source
    end

    if route == nil then
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

function RouteDirectTo( controllable, waypoint )
    if (controllable == nil) then
        return exitWarning("DirectTo-? :: controllable not specified")
    end
    if (waypoint == nil) then
        return exitWarning("DirectTo-? :: steerpoint not specified")
    end

    local route = nil
    local group = getGroup( controllable )
    if ( group == nil ) then
        return exitWarning("DirectTo-? :: cannot resolve group: "..Dump(controllable))
    end
    
    route = group:CopyRoute()
    if (route == nil) then
        return exitWarning("DirectTo-" .. group.GroupName .." :: cannot resolve route from controllable: "..Dump(controllable)) end

    local wpIndex = nil
    if (isString(waypoint)) then
        local wp = FindWaypointByName( route, waypoint )
        if (wp == nil) then
            return exitWarning("DirectTo-" .. group.GroupName .." :: no waypoint found with name '"..waypoint.."'") end

        wpIndex = wp.index
    elseif (isNumber(waypoint)) then
        wpIndex = waypoint
    else
        return exitWarning("DirectTo-" .. group.GroupName .." :: cannot resolved steerpoint: "..Dump(waypoint))
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

local function resolveUnitInGroup(group, nsUnit, defaultIndex)
    local unit = nil
    if isNumber(nsUnit) then
        nsUnit = math.max(1, nsUnit)
        unit = group:GetUnit(nsUnit)
    elseif isAssignedString(nsUnit) then
        local index = tableIndexOf(group:GetUnits(), function(u) return u.UnitName == nsUnit end)
        if index then
            unit = group:GetUnit(index)
        else
            return "group '" .. group.GroupName .. " have no unit with name '" .. nsUnit .. "'"
        end
    elseif isUnit(nsUnit) then
        unit = nsUnit
    end
    if unit then
        return unit
    end
    if not isNumber(defaultIndex) then
        defaultIndex = 1
    end
    return group:GetUnit(defaultIndex)
end

-- Activates TACAN beacon for specified group
-- @param #any group A #GROUP or name of group
-- @param #number nChannel The TACAN channel (eg. 39 in 30X)
-- @param #string sModeChannel The TACAN mode ('X' or 'Y'). Optional; default = 'X'
-- @param #string sIdent The TACAN Ident (a.k.a. "callsign"). Optional
-- @param #boolean bBearing Specifies whether the beacon will provide bearing information. Optional; default = true
-- @param #boolean bAA Specifies whether the beacon is airborne. Optional; default = true for air group, otherwise false
-- @param #any nsAttachToUnit Specifies unit to attach TACAN to; either its internal index or its name. Optional; default = 1
-- @return #string A message describing the outcome (mainly intended for debugging purposes)
function CommandActivateTACAN(group, nChannel, sModeChannel, sIdent, bBearing, bAA, nsAttachToUnit)
    local forGroup = getGroup(group)
    if not forGroup then
        error("CommandActivateTACAN :: cannot resolve group from: " .. DumpPretty(group)) end
    if not isNumber(nChannel) then
        error("CommandActivateTACAN :: `nChannel` was unassigned/unexpected value: " .. DumpPretty(nChannel)) end
    if sModeChannel == nil or not isAssignedString(sModeChannel) then
        sModeChannel = "X"
    elseif sModeChannel ~= "X" and sModeChannel ~= "Y" then
        error("CommandActivateTACAN :: invalid `sModeChannel`: " .. Dump(sModeChannel)) 
    end
    local unit = resolveUnitInGroup(forGroup, nsAttachToUnit)
    if isAssignedString(unit) then
        error("CommandActivateTACAN :: " .. unit)
    end
    if not isAssignedString(sIdent) then
        sIdent = tostring(nChannel) .. sModeChannel end
    if not isBoolean(bBearing) then
        bBearing = true end

    local beacon = unit:GetBeacon()
    beacon:ActivateTACAN(nChannel, sModeChannel, sIdent, bBearing)
    local traceDetails = string.format("%d%s (%s)", nChannel, sModeChannel, sIdent or "---")
    if bAA then
        traceDetails = traceDetails .. " A-A" end
    if bBearing then
        traceDetails = traceDetails .. " with bearing information" 
    else
        traceDetails = traceDetails .. " with NO bearing information"
    end
    if unit then
        traceDetails = traceDetails .. ", attached to unit: " .. unit.UnitName end
    local message = "TACAN was set for group '" .. forGroup.GroupName .. "' :: " .. traceDetails
    Trace("CommandActivateTACAN :: " .. message)
    return message
end

--- Deactivates an active beacon for specified group
-- @param #any group A #GROUP or name of group
-- @param #number nDelay Specifies a delay (seconds) before the beacon is deactivated
-- @return #string A message describing the outcome (mainly intended for debugging purposes)
function CommandDeactivateBeacon(group, nDelay)
    local forGroup = getGroup(group)
    if not forGroup then
        error("CommandDeactivateBeacon :: cannot resolve group from: " .. DumpPretty(group)) end

    forGroup:CommandDeactivateBeacon(nDelay)

    local message = "beacon was deactivated for " .. forGroup.GroupName
    Trace("CommandDeactivateBeacon-" .. forGroup.GroupName .. " :: " .. message)
    return message
end

--- Activates ICLS beacon for specified group
-- @param #any group A #GROUP or name of group
-- @param #number nChannel The TACAN channel (eg. 39 in 30X)
-- @param #string sIdent The TACAN Ident (a.k.a. "callsign"). Optional
-- @param #number nDuration Specifies a duration for the TACAN to be active. Optional; when not set the TACAN srtays on indefinitely
-- @return #string A message describing the outcome (mainly intended for debugging purposes)
function CommandActivateICLS(group, nChannel, sIdent, nsAttachToUnit, nDuration)
    local forGroup = getGroup(group)
    if not forGroup then
        error("CommandActivateICLS :: cannot resolve group from: " .. DumpPretty(group)) end
    if not isNumber(nChannel) then
        error("CommandActivateICLS :: `nChannel` was unassigned/unexpected value: " .. DumpPretty(nChannel)) end
    local unit = resolveUnitInGroup(forGroup, nsAttachToUnit)
    if isAssignedString(unit) then
        error("CommandActivateICLS :: " .. unit)
    end
    unit:GetBeacon():ActivateICLS(nChannel, sIdent, nDuration)
    local traceDetails = string.format("%d (%s)", nChannel, sIdent or "---")
    traceDetails = traceDetails .. ", attached to unit: " .. unit.UnitName
    local message = "ICLS was set for group '" .. forGroup.GroupName .. "' :: " .. traceDetails
    Trace("CommandActivateICLS :: " .. message)
    return message
end

--- Deactivates ICLS for specified group
-- @param #any group A #GROUP or name of group
-- @param #number nDuration Specifies a nDelay before the ICLS is deactivated
-- @return #string A message describing the outcome (mainly intended for debugging purposes)
function CommandDeactivateICLS(group, nDelay)
    local forGroup = getGroup(group)
    if not forGroup then
        error("CommandDeactivateICLS :: cannot resolve group from: " .. DumpPretty(group)) end

    forGroup:CommandDeactivateICLS(nDelay)
    local message = "ICLS was deactivated group '" .. forGroup.GroupName
    Trace("CommandDeactivateICLS :: " .. message)
    return message
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

function IsAARTanker(group)
    local forGroup = getGroup(group)
    if not forGroup then
        error("IsAARTanker :: cannot resolve group from " .. DumpPretty(group)) end

    local route = forGroup:CopyRoute()
    -- check for 'Tanker' task ...
    for _, wp in ipairs(route) do
        local task = wp.task
        if task and task.id == "ComboTask" and task.params and task.params.tasks then -- todo Can task be other than 'ComboTask' here?
            for _, task in ipairs(task.params.tasks) do
                if task.id == "Tanker" then
                    return true end
            end
        end
    end
    return false
end

--------------------------------------------- [[ MISSION EVENTS ]] ---------------------------------------------

MissionEvents = { }

local _missionEventsHandlers = {
    _missionEndHandlers = {},
    _groupSpawnedHandlers = {},
    _unitSpawnedHandlers = {},
    _unitDeadHandlers = {},
    _unitDestroyedHandlers = {},
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

    local function getDCSTarget(event)
        local dcsTarget = event.target 
        if not dcsTarget and event.weapon then
            dcsTarget = event.weapon:getTarget()
        end
        return dcsTarget
    end

    local function addInitiatorAndTarget( event )
        if event.initiator ~= nil and event.IniUnit == nil then
            event.IniUnit = UNIT:Find(event.initiator)
            event.IniUnitName = event.IniUnit.UnitName
            event.IniGroup = event.IniUnit:GetGroup()
            event.IniGroupName = event.IniGroup.GroupName
            event.IniPlayerName = event.IniUnit:GetPlayerName()
        end
        local dcsTarget = getDCSTarget(event)
        if event.TgtUnit == nil and dcsTarget ~= nil then
            event.TgtUnit = UNIT:Find(dcsTarget)
            if not event.TgtUnit then
                Warning("_e:onEvent :: event: " .. Dump(event.id) .. " :: could not resolve TgtUnit from DCS object" )
                return event
            end
            event.TgtUnitName = event.TgtUnit.UnitName
            -- if DCSUnit then
            --   local UnitGroup = GROUP:FindByName( dcsTarget:getGroup():getName() )
            --   return UnitGroup
            -- end
            event.TgtGroup = event.TgtUnit:GetGroup()
-- nisse
local nisse = dcsTarget:getGroup():getName()
            if not event.TgtGroup then
Debug("_e:onEvent :: nisse: " .. DumpPrettyDeep(nisse))
                Warning("_e:onEvent :: event: " .. Dump(event.id) .. " :: could not resolve TgtGroup from UNIT:GetGroup()" )
                return event
            end            
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

    local function invokeUnitDestroyed(event)
        if event.TgtUnit then
            local rootEvent = DCAF.clone(event)
            event = {
                RootEvent = rootEvent,
                IniUnit = rootEvent.TgtUnit,
                IniUnitName = rootEvent.TgtUnitName,
                IniGroup = rootEvent.TgtGroup,
                IniGroupName = rootEvent.TgtGroupName
            }
-- Debug("invokeUnitDestroyed :: event: " .. DumpPrettyDeep(event))            
        end
        -- event.RootEventId = rootEventId
        MissionEvents:Invoke(_missionEventsHandlers._unitDestroyedHandlers, event)
    end

    if event.id == world.event.S_EVENT_DEAD then
        if event.IniUnit then
            event = addInitiatorAndTarget(event)
            if #_missionEventsHandlers._unitDeadHandlers > 0 then
                MissionEvents:Invoke( _missionEventsHandlers._unitDeadHandlers, event)
            end
            invokeUnitDestroyed(event)
        end
        return
    end

    if event.id == world.event.S_EVENT_KILL then
        -- unit was killed by other unit
        event = addInitiatorAndTarget(event)
        MissionEvents:Invoke(_missionEventsHandlers._unitKilledHandlers, event)
        invokeUnitDestroyed(event)
        return
    end

    if event.id == world.event.S_EVENT_EJECTION then
        MissionEvents:Invoke( _missionEventsHandlers._ejectionHandlers, event)
        return
    end

    if event.id == world.event.S_EVENT_CRASH then
        event = addInitiatorAndTarget(event)
        MissionEvents:Invoke( _missionEventsHandlers._unitCrashedHandlers, event)
        invokeUnitDestroyed(event)
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
--- A "collective" event to capture a unit getting destroyed, regardless of how it happened
-- @param #function fund The event handler function
-- @param #boolean Specifies whether to insert the event handler at the front, ensuring it will get invoked first
function MissionEvents:OnUnitDestroyed( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._unitDestroyedHandlers, func, nil, insertFirst) 
end
function MissionEvents:EndOnUnitDestroyed( func ) MissionEvents:RemoveListener(_missionEventsHandlers._unitDestroyedHandlers, func) end

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


---- CSTOM EVENT: FUEL STATE

local _missionEventsAircraftFielStateMonitor = {

    UnitInfo = {
        Units = {},           -- list of #UNIT; monitored units
        State = nil,          -- #number (0 - 1); the fuel state being monitored
        Func = nil            -- #function; the event handler
    },

    Timer = nil,              -- assigned by _missionEventsAircraftFielStateMonitor:Start()
    Monitored = {
        -- dictionary
        --   key   = #string (group or unit name)
        --   value = #UnitInfo
    },               
    CountMonitored = 0,           -- ¤number; no. of items in $self.Units
}

function _missionEventsAircraftFielStateMonitor:Start(key, units, fuelState, func)
    if _missionEventsAircraftFielStateMonitor.Monitored[key] then
        return errorOnDebug("MissionEvents:OnFuelState :: key was already monitored") end

    local info = DCAF.clone(_missionEventsAircraftFielStateMonitor.UnitInfo)
    info.Units = units
    info.State = fuelState
    info.Func = func
    _missionEventsAircraftFielStateMonitor.Monitored[key] = info
    _missionEventsAircraftFielStateMonitor.CountMonitored = _missionEventsAircraftFielStateMonitor.CountMonitored + 1

    if self.Timer then 
        return end

    local function monitorFuelStates()
        local triggeredKeys = {}
        for key, info in pairs(_missionEventsAircraftFielStateMonitor.Monitored) do
            for _, unit in pairs(info.Units) do
                local state = unit:GetFuel()
Debug("monitor fuel state :: unit: " .. unit.UnitName .. " :: state: " .. Dump(state))                
                if state <= info.State then
                    info.Func(unit)
                    table.insert(triggeredKeys, key)
                end
            end
        end

        -- end triggered keys ...
        for _, key in ipairs(triggeredKeys) do
            self:End(key)
        end
    end
    
    self.Timer = TIMER:New(monitorFuelStates):Start(1, 60)
end

function _missionEventsAircraftFielStateMonitor:End(key)

    if not _missionEventsAircraftFielStateMonitor.Monitored[key] then
        return errorOnDebug("MissionEvents:OnFuelState :: key was already monitored") 
    else
        Trace("MissionEvents:OnFuelState :: " .. key .. " :: ENDS")
        _missionEventsAircraftFielStateMonitor.Monitored[key] = nil
        _missionEventsAircraftFielStateMonitor.CountMonitored = _missionEventsAircraftFielStateMonitor.CountMonitored - 1
    end

    if not self.Timer or _missionEventsAircraftFielStateMonitor.CountMonitored > 0 then 
        return end

    Delay(2, function()
        self.Timer:Stop()
        self.Timer = nil
    end)
end

function MissionEvents:OnFuelState( controllable, nFuelState, func )
    if not isNumber(nFuelState) or nFuelState < 0 or nFuelState > 1 then
        error("MissionEvents:OnFuelState :: invalid/unassigned `nFuelState`: " .. DumpPretty(nFuelState)) end

    local units = {}
    local key
    local unit = getUnit(controllable)
    if not unit then
        local group = getGroup(controllable)
        if not group then 
            error("MissionEvents:OnFuelState :: could not resolve a unit or group from " .. DumpPretty(controllable)) end
        units = group:GetUnits()
        key = group.GroupName
    else
        key = unit.UnitName
        table.insert(units, unit)
    end
    Trace("MissionEvents:OnFuelState :: " .. key .. " :: state: " .. Dump(nFuelState) .. " :: BEGINS")
    _missionEventsAircraftFielStateMonitor:Start(key, units, nFuelState, func)
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
    args = nil                -- (optional) arbitrary arguments with contextual meaning
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
    OnUnitDestroyed = "OnUnitDestroyed",
    -- todo add more events ...
}

local _DCAFEvents = {
    [DCAFEvents.OnAircraftLanded] = function(func, insertFirst) MissionEvents:OnAircraftLanded(func, insertFirst) end,
    [DCAFEvents.OnGroupDiverted] = function(func, insertFirst) MissionEvents:OnGroupDiverted(func, insertFirst) end,
    [DCAFEvents.OnUnitDestroyed] = function(func, insertFirst) MissionEvents:OnUnitDestroyed(func, insertFirst) end,
    -- zone events
    [DCAFEvents.OnGroupEntersZone] = function(func, insertFirst, args) MissionEvents:OnGroupEntersZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnGroupInsideZone] = function(func, insertFirst, args) MissionEvents:OnGroupInsideZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnGroupLeftZone] = function(func, insertFirst, args) MissionEvents:OnGroupLeftZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnUnitEntersZone] = function(func, insertFirst, args) MissionEvents:OnUnitEntersZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnUnitInsideZone] = function(func, insertFirst, args) MissionEvents:OnUnitInsideZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    [DCAFEvents.OnUnitLeftZone] = function(func, insertFirst, args) MissionEvents:OnUnitLeftZone(args.Item, args.Zone, func, args.Continous, args.Filter) end,
    -- todo add more events ...
}

function _DCAFEvents:Activate(activation)
    local activator = _DCAFEvents[activation.eventName]
    if activator then
-- Debug("nisse - DCAFEvents:Activate :: activation: " .. DumpPrettyDeep(activation))
-- Debug("nisse - DCAFEvents:Activate :: activator: " .. DumpPretty(activator))
        activator(activation.func, activation.insertFirst, activation.args)

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
-- Debug("nisse - _DCAFEvents:ActivateFor :: source:" .. Dump(source) .. " :: _DCAFEvents_lateActivations: " .. DumpPrettyDeep(_DCAFEvents_lateActivations))
    local activations = _DCAFEvents_lateActivations[source]
    if not activations then
        return
    end
-- Debug("nisse - _DCAFEvents:ActivateFor :: #activations: " .. DumpPrettyDeep(#activations) .. " :: (1 expected)")
    _DCAFEvents_lateActivations[source] = nil
    for _, activation in ipairs(activations) do
        _DCAFEvents:Activate(activation)
    end
end

function DCAFEvents:PreActivate(source, eventName, func, onActivateFunc, args)
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
    activation.args = args
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

function ZoneEventType.isValid(value)
    return value == ZoneEventType.Enter 
        or value == ZoneEventType.Inside
        or value == ZoneEventType.Left
end

local ZoneEventObjectType = {
    Any = 'any',
    Group = 'group',
    Unit = 'unit'
}

-- local ObjectZoneState = { -- keeps track of all groups/units state in relation to zones
--     Outside = "outside",
--     Inside = "inside",
--     Records = {
--         -- key = group/unit name, value = {
--         --   key = zone name, value = <ZoneEventType>
--         -- }
--     }
    
-- }

-- function ObjectZoneState:Set(object, zone, state)
--     local name = nil
--     if isGroup(object) then
--         name = object.GroupName
--     else
--         name = object.UnitName
--     end
--     local record = ObjectZoneState.Records[name]
--     if not record then
--         record = {}
--         ObjectZoneState.Records[name] = state
--         record[zone.Name] = state
--         return
--     end
--     record[zone.Name] = state
-- end

-- function ObjectZoneState:Get(object, zone)
--     local name = nil
--     if isGroup(object) then
--         name = object.GroupName
--     else
--         name = object.UnitName
--     end
--     local record = ObjectZoneState.Records[name]
--     if not record then
--         return ObjectZoneState.Outside
--     end
--     local state = record[zone.Name]
--     return state or ObjectZoneState.Outside
-- end

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
    filter = nil,                    -- 
}

local ConsolidatedZoneCentricZoneEventsInfo = {
    zone = nil,                      -- the monitored zone
    zoneEvents = {},                 -- list of <ZoneEvent>
}

local ObjectCentricZoneEvents = { 
    -- list of <ZoneEvent>
}

local FilterCentricZoneEvents = { -- events with Filter (must be resolved individually)
    -- list of <ZoneEvent>
}

local ConsolidatedZoneCentricZoneEvents = { -- events with no Filter attached (can be consolidated for same zone)
    -- key = zoneName, 
    -- value = <ConsolidatedZoneCentricZoneEventsInfo>
}

local ZoneEventArgs = {
    EventType = nil,          -- <ZoneEventType>
    ZoneName = nil,           -- string
}

ZoneFilter = {
    _type = "ZoneEventArgs",
    _template = true,
    Item = nil,
    Coalitiona = nil,         -- (optional) one or more <Coalition>
    GroupTypes = nil,         -- (optional) one or more <GroupType>
    Continous = nil,
}

function ZoneFilter:Ensure()
    if not self._template then
        return self end

    local filter = DCAF.clone(ZoneFilter)
    filter._template = nil
    return filter
end

local function addTypesToZoneFilter(filter, item)
    if item == nil then
        return filter
    end
    if item:IsAirPlane() then
        filter.Type = GroupType.Airplane
    elseif item:IsHelicopter() then
        filter.Type = GroupType.Helicopter
    elseif item:IsShip() then
        filter.Type = GroupType.Ship
    elseif item:IsGround() then
        filter.Type = GroupType.Ground
    end
    return filter
end

function ZoneFilter:Group(group)
    local filter = self:Ensure()
    if group == nil then
        return filter
    end
    filter.Item = getGroup(group)
    if not filter.Item then
        error("ZoneFilter:Group :: cannot resolve group from " .. Dump(group)) end

    return addTypesToZoneFilter(filter, filter.Item)
end

function ZoneFilter:Unit(unit)
    local filter = self:Ensure()
    if unit == nil then
        return filter
    end
    filter.Item = unit
    if not filter.Item then
        error("ZoneFilter:Unit :: cannot resolve unit from " .. Dump(unit)) end

    return addTypesToZoneFilter(filter, filter.Item)
end

function ZoneFilter:Coalitions(...)
    local coalitions = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then
            if not Coalition.IsValid(v) then
                error("ZoneOptions:Coalitions :: invalid coalition: " .. Dump(v)) 
            end
            table.insert(coalitions, v)
        end
    end

    if #coalitions == 0 then
        error("ZoneFilter:Coalitions :: no coalition(s) specified") end

    local filter = self:Ensure()
    filter.Coalitions = coalitions
    return filter
end

function ZoneFilter:GroupType(type)
    if not isAssignedString(type) then
        error("ZoneFilter:GroupType :: group type was unassigned")  end
        
    if not GroupType.IsValid(type) then
        error("ZoneFilter:GroupType :: invalid group type: " .. Dump(v))  end

    local filter = self:Ensure()
    filter.GroupType = type
    filter.Item = nil
    return filter
end

function ConsolidatedZoneCentricZoneEventsInfo:New(zone, zoneName)
    local info = DCAF.clone(ConsolidatedZoneCentricZoneEventsInfo)
    info.zone = zone
    ZoneEventState._countZoneEventZones = ZoneEventState._countZoneEventZones + 1
    return info
end

function ConsolidatedZoneCentricZoneEventsInfo:Scan()
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
    if ZoneEventState._timer ~= nil and #ObjectCentricZoneEvents == 0 and #FilterCentricZoneEvents == 0 and ZoneEventState._countZoneEventZones == 0 then
        Trace("stopMonitoringZoneEventsWhenEmpty :: mission zone events monitoring stopped")
        ZoneEventState._timer:Stop()
        ZoneEventState._timer = nil
    end
end

local function startMonitorZoneEvents()

    local function monitor()

        -- object-centric zone events ...
        local removeZoneEvents = {}
        for _, zoneEvent in ipairs(ObjectCentricZoneEvents) do
            if zoneEvent:EvaluateForObject() then
                table.insert(removeZoneEvents, zoneEvent)
            end
        end
        for _, zoneEvent in ipairs(removeZoneEvents) do
            zoneEvent:Remove()
        end

        -- filter-cenric zone events ...
        removeZoneEvents = {}
        for _, zoneEvent in ipairs(FilterCentricZoneEvents) do
            if zoneEvent:EvaluateForFilter() then
                table.insert(removeZoneEvents, zoneEvent)
            end
        end
        for _, zoneEvent in ipairs(removeZoneEvents) do
            zoneEvent:Remove()
        end

        -- zone-centric zone events ...
        removeZoneEvents = {}
        for zoneName, zcEvent in pairs(ConsolidatedZoneCentricZoneEvents) do
            local groups = zcEvent:Scan()
            if #groups > 0 then
                for _, zoneEvent in ipairs(zcEvent.zoneEvents) do
                    if zoneEvent:TriggerMultipleGroups(groups) then
                        table.insert(removeZoneEvents, zoneEvent)
                    end
                end
            end
            for _, zoneEvent in ipairs(removeZoneEvents) do
                local index = tableIndexOf(zcEvent.zoneEvents, zoneEvent)
                if index < 1 then
                    error("startMonitorZoneEvents_monitor :: cannot remove zone event :: event was not found in the internal list") end
                
                table.remove(zcEvent.zoneEvents, index)
                if #zcEvent.zoneEvents == 0 then
                    ConsolidatedZoneCentricZoneEvents[zoneName] = nil
                    ZoneEventState._countZoneEventZones = ZoneEventState._countZoneEventZones - 1
                end
            end
        end
        stopMonitoringZoneEventsWhenEmpty()
    end

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

function ZoneEvent:TriggerMultipleGroups(groups)
    local event = ZoneEventArgs:New(self)
    event.IniGroups = groups
    self.func(event)
    return not self.continous or event._terminateEvent
end

function ZoneEvent:TriggerMultipleUnits(units)
    local event = ZoneEventArgs:New(self)
    event.IniUnits = units
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

local function getGrupsInZone(group, zone, filter)
    -- todo
    -- local units = group:GetUnits()
    -- for _, unit in ipairs(units) do
    --     if unit:IsInZone(zone) then
    --         return true
    --     end
    -- end
    -- return false
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

function ZoneEvent:EvaluateForFilter()
    -- 'filter perspective'; use filtered SET_GROUP or SET_UNIT to check zone event ...
    local set = nil
    if self.objectType == ZoneEventObjectType.Group then
        set  = SET_GROUP:New():FilterZones({ self.zone })
    else
        set  = SET_UNIT:New():FilterZones({ self.zone })
    end

    -- filter coalitions ...
    if self.filter.Coalitions then
        set:FilterCoalitions(self.filter.Coalitions)
    end

    -- filter group type ...
    local type = self.filter.GroupType
    if type == GroupType.Air then
        set:FilterCategoryAirplane()
        set:FilterCategoryHelicopter()
    elseif type == GroupType.Airplane then
        set:FilterCategoryAirplane()
    elseif type == GroupType.Helicopter then
        set:FilterCategoryHelicopter()
    elseif type == GroupType.Ship then
        set:FilterCategoryShip()
    elseif type == GroupType.Ground then
        set:FilterCategoryGround()
    elseif type == GroupType.Structure then
        set:FilterCategoryStructure()
    end

    -- scan and trigger events if groups/units where found ...
    set:FilterActive():FilterOnce()
    if self.objectType == ZoneEventObjectType.Group then
        local groups = {}
        set:ForEachGroupAlive(function(group) table.insert(groups, group) end)
        if #groups > 0 then
            return self:TriggerMultipleGroups(groups)
        end
    elseif self.objectType == ZoneEventObjectType.Unit then
        local units = {}
        set:ForEachUnitAlive(function(group)
            table.insert(units, group)
        end)
        if #units > 0 then
            return self:TriggerMultipleUnits(units)
        end
    end
    return false
end

function ZoneEvent:IsFiltered()
    return self.filter ~= nil
end

function ZoneEvent:Insert()
    if self.isZoneCentered then
        if self:IsFiltered() then
            self._eventList = FilterCentricZoneEvents
            table.insert(FilterCentricZoneEvents, self)
        else
            local info = ConsolidatedZoneCentricZoneEvents[self.zoneName]
            if not info then
                info = ConsolidatedZoneCentricZoneEventsInfo:New(self.zone, self.zoneName)
                ConsolidatedZoneCentricZoneEvents[self.zoneName] = info
            end
            self._eventList = FilterCentricZoneEvents
            table.insert(info.zoneEvents, self)
        end
    else
        self._eventList = ObjectCentricZoneEvents
        table.insert(ObjectCentricZoneEvents, self)
    end
-- Debug("ZoneEvent:Insert :: #FilterCentricZoneEvents: " .. Dump(#FilterCentricZoneEvents))
-- Debug("ZoneEvent:Insert :: #ObjectCentricZoneEvents: " .. Dump(#ObjectCentricZoneEvents))
-- Debug("ZoneEvent:Insert :: #ConsolidatedZoneCentricZoneEvents: " .. Dump(#ConsolidatedZoneCentricZoneEvents))
    startMonitorZoneEvents()
end
    
function ZoneEvent:Remove()
    if self._eventList then
        local index = tableIndexOf(self._eventList, self)
        if not index then
            error("ZoneEvent:Remove :: cannot find zone event")
        end
        table.remove(self._eventList, index)
    end
    -- if self.objectType ~= ZoneEventObjectType.Any then
    --     local index = tableIndexOf(ObjectCentricZoneEvents, self) obsolete
    --     if not index then
    --         error("ZoneEvent:Remove :: cannot find zone event")
    --     end
    --     table.remove(ObjectCentricZoneEvents, index)
    -- end
    stopMonitoringZoneEventsWhenEmpty()
end

function ZoneEvent:NewForZone(objectType, eventType, zone, func, continous, filter--[[ , makeZczes ]])
    local zoneEvent = DCAF.clone(ZoneEvent)
    zoneEvent.isZoneCentered = true
    zoneEvent.objectType = objectType
    if not ZoneEventType.isValid(eventType) then
        error("MonitoredZoneEvent:New :: unexpected event type: " .. Dump(eventType))
    end
    zoneEvent.eventType = eventType

    if not isAssignedString(zone) then
        error("MonitoredZoneEvent:New :: unexpected/unassigned zone: " .. Dump(zone))
    end
    zoneEvent.zone = ZONE:FindByName(zone)
    if not zoneEvent.zone then
        error("MonitoredZoneEvent:New :: unknown zone: " .. Dump(zone))
    end
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
    zoneEvent.filter = filter

    -- if makeZczes then
    --     local info = ZoneCentricZoneEvents[zoneEvent.zoneName]
    --     if not info then
    --         info = ZoneCentricZoneEventInfo:New(zoneEvent.zone)
    --         ZoneCentricZoneEvents[zoneEvent.zoneName] = info
    --     end
    --     info:AddEvent()
    -- end
    return zoneEvent
end

function ZoneEvent:NewForObject(object, objectType, eventType, zone, func, continous)
    local zoneEvent = ZoneEvent:NewForZone(objectType, eventType, zone, func, continous, nil, false)
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

function MissionEvents:OnGroupEntersZone( group, zone, func, continous, filter )
    local zoneEvent = nil
    if group == nil then
        MissionEvents:OnGroupInsideZone(group, zone, func, continous, filter)
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

function MissionEvents:OnGroupInsideZone( group, zone, func, continous, filter )
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
            continous, 
            filter)
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

---------------------------------------- NAVY ----------------------------------------

local DCAFCarriers = {
    Count = 0,
    Carriers = {
        -- dictionary
        --   key    = carrier unit name
        --   valuer = #DCAF.Carrier
    }
}

DCAF.Carrier = {
    Group = nil,              -- #GROUP (MOOSE object) - the carrier group
    Unit = nil,               -- #UNIT (MOOSE object) - the carrier unit
    DisplayName = nil,        -- #string; name to be used in menus and communication
    TACAN = nil,              -- #DCAF_TACAN; represents the carrier's TACAN (beacon)
    ICLS = nil,               -- #DCAF_ICLS; represents the carrier's ICLS system
    RecoveryTankers = {},     -- { list of #DCAF_RecoveryTankerInfo (not yet activated, gets removed when activated) }    
}

function DCAFCarriers:Add(carrier)
    -- ensure carrier was not already added ...
    local exists = DCAFCarriers[carrier.Unit.UnitName]
    if exists then
        error("DCAFCarriers:Add :: carrier was already added") end

    DCAFCarriers.Carriers[carrier.Unit.UnitName] = carrier
    DCAFCarriers.Count = DCAFCarriers.Count + 1
    return carrier
end

local DCAF_TACAN = {
    Group = nil,          -- #GROUP
    Unit = nil,           -- #UNIT
    Channel = nil,        -- #number (eg. 73, for channel 73X)     
    Mode = nil,           -- #string (eg. 'X' for channel 73X)
    Ident = nil,          -- #string (eg. 'C73')
    Beaering = true       -- #boolean; Emits bearing information when set
}

local DCAF_ICLS = {
    Group = nil,          -- #GROUP
    Unit = nil,           -- #UNIT
    Channel = nil,        -- #number (eg. 11, for channel 11)
    Ident = nil,          -- #string (eg. 'C73')
}

local DCAF_RecoveryTankerState = {
    Parked = "Parked",
    Launched = "Launched",
    RendezVous = "RendezVous",
    RTB = "RTB"
}

local DCAF_RecoveryTanker = {
    Tanker = nil,         -- #RECOVERYTANKER (MOOSE)
    Group = nil,          -- #GROUP (MOOSE)
    IsLaunched = nil,     -- #boolean; True if tanbker has been launched
    OnLaunchedFunc = nil, -- #function; invoked when tanker gets launched
    State = DCAF_RecoveryTankerState.Parked,
    GroupMenus = {
        -- dictionary
        --    key = group name
        --    value = #MENU_GROUP_COMMAND (MOOSE)
    }
}

function DCAF.Carrier:New(group, nsUnit, sDisplayName)
    local forGroup = getGroup(group)
    if not forGroup then
        error("DCAF.Carrier:New :: cannot resolve group from: " .. DumpPretty(group)) end

    local forUnit = resolveUnitInGroup(forGroup, nsUnit)
    -- todo: Ensure unit is actually a carrier!
    if isAssignedString(forUnit) then
        error("DCAF.Carrier:New :: cannot resolve unit from: " .. DumpPretty(nsUnit)) end

    if not isAssignedString(sDisplayName) then
        sDisplayName = forUnit.UnitName
    end

    local carrier = DCAF.clone(DCAF.Carrier)
    carrier.Group = forGroup
    carrier.Unit = forUnit
    carrier.DisplayName = sDisplayName
    return DCAFCarriers:Add(carrier)
end

function DCAF_TACAN:New(group, unit, nChannel, sMode, sIdent, bBearing)
    local tacan = DCAF.clone(DCAF_TACAN)
    tacan.Group = group
    tacan.Unit = unit or group:GetUnit(1)
    tacan.Channel = nChannel
    tacan.Mode = sMode
    tacan.Ident = sIdent
    if isBoolean(bBearing) then
        tacan.Bearing = bBearing end
    return tacan
end

function DCAF.Carrier:ActivateTACAN()
    if not self.TACAN then
        return end

    CommandActivateTACAN(self.Group, self.TACAN.Channel, self.TACAN.Mode, self.TACAN.Ident, self.TACAN.Beaering, false, self.Unit)
    return self
end

function DCAF.Carrier:DeactivateTACAN(nDelay)
    if not self.TACAN then
        return end
        
    if isNumber(nDelay) and nDelay > 0 then
        Delay(nDelay, function() 
            CommandDeactivateBeacon(self.Group)
        end)
    else
        CommandDeactivateBeacon(self.Group)
    end
    return self
end

function DCAF.Carrier:ActivateICLS()
    if not self.ICLS then
        return end
        
    Debug("DCAF.Carrier:ActivateICLS :: group: " .. self.Group.GroupName .. " :: unit: " .. self.Unit.UnitName .. " :: Channel: " .. tostring(self.ICLS.Channel) .. " :: Ident: " .. tostring(self.ICLS.Ident))
    CommandActivateICLS(self.Group, self.ICLS.Channel, self.ICLS.Ident, self.Unit)
    return self
end

function DCAF.Carrier:DeactivateICLS(nDelay)
    if not self.ICLS then
        return end
        
    if isNumber(nDelay) and nDelay > 0 then
        Delay(nDelay, function() 
            CommandDeactivateICLS(self.Group)
        end)
    else
        CommandDeactivateICLS(self.Group)
    end
    return self
end

local function validateTACAN(nChannel, sMode, sIdent, errorPrefix)
    if not isNumber(nChannel) then
        error(errorPrefix .. " :: `nChannel` was unassigned") end
    if nChannel < 1 or nChannel > 99 then
        error(errorPrefix .. " :: `nChannel` was outside valid range (1-99)") end
    if not isAssignedString(sMode) then
        error(errorPrefix .. " :: `sMode` was unassigned") end
    if sMode ~= 'X' and sMode ~= 'Y' then
        error(errorPrefix .. " :: `sMode` was invalid (expected: 'X' or 'Y'") end
    return nChannel, sMode, sIdent
end

local function getCarrierWithTACANChannel(nChannel, sMode)
    for name, carrier in pairs(DCAFCarriers.Carriers) do
        local tacan = carrier.TACAN
        if tacan and tacan.Channel == nChannel and tacan.Mode == sMode then
            return name, carrier
        end
    end
end

local function getCarrierWithICLSChannel(nChannel)
    for name, carrier in pairs(DCAFCarriers.Carriers) do
        local icls = carrier.ICLS
        if icls and icls.Channel == nChannel then
            return name, carrier
        end
    end
end

function DCAF.Carrier:SetTACANInactive(nChannel, sMode, sIdent, bBearing)
    nChannel, sMode, sIdent = validateTACAN(nChannel, sMode, sIdent, "DCAF.Carrier:SetTACANInactive")
    local existingCarrier = getCarrierWithTACANChannel(nChannel, sMode)
    if existingCarrier and existingCarrier ~= self then
        error("Cannot set TACAN " .. tostring(nChannel) .. sMode .. " for carrier '" .. self.DisplayName .. "'. Channel is already in use by '" .. existingCarrier .. "'") end
    if self.TACAN then
        self:DeactivateTACAN()
    end
    self.TACAN = DCAF_TACAN:New(self.Group, self.Unit, nChannel, sMode, sIdent, bBearing)
    return self
end

function DCAF.Carrier:SetTACAN(nChannel, sMode, sIdent, bBearing, nActivateDelay)
    self:SetTACANInactive(nChannel, sMode, sIdent, bBearing)
    if isNumber(nActivateDelay) and nActivateDelay > 0 then
        Delay(nActivateDelay, function()
            self:ActivateTACAN()
        end)
    else
        self:ActivateTACAN()
    end
    return self
end

function DCAF.Carrier:SetICLSInactive(nChannel, sIdent)
    if not isNumber(nChannel) then
        error("DCAF.Carrier:WithTACAN :: `nChannel` was unassigned") end
    if nChannel < 1 or nChannel > 99 then
        error("DCAF.Carrier:WithTACAN :: `nChannel` was outside valid range (1-99)") end
    local existingCarrier = getCarrierWithICLSChannel(nChannel)
    if existingCarrier and existingCarrier ~= self then
        error("Cannot set ICLS " .. tostring(nChannel) .. " for carrier '" .. self.DisplayName .. "'. Channel is already in use by '" .. existingCarrier .. "'") end
    
    if self.ICLS then
        self:DeactivateICLS()
    end
    self.ICLS = DCAF.clone(DCAF_ICLS)
    self.ICLS.Group = self.Group
    self.ICLS.Unit = self.Unit
    self.ICLS.Channel = nChannel
    self.ICLS.Ident = sIdent
    return self 
end

function DCAF.Carrier:SetICLS(nChannel, sIdent, nActivateDelay)
    self:SetICLSInactive(nChannel, sIdent)
    if isNumber(nActivateDelay) and nActivateDelay > 0 then
        Delay(nActivateDelay, function()
            self:ActivateICLS()
        end)
    else
        self:ActivateICLS()
    end
    return self
end

function DCAF.Carrier:WithRescueHelicopter(chopper)

    local rescueheli
    if isAssignedString(chopper) then
        rescueheli = RESCUEHELO:New(self.Unit, chopper)
    elseif isTable(chopper) and chopper.ClassName == "RESCUEHELO" then
        rescueheli = chopper
    end

    if not rescueheli then
        error("DCAF.Carrier:WithResuceHelicopter :: could not resolve a rescue helicopter from '" .. DumpPretty(chopper)) end

    rescueheli:Start()
    return self
end

function DCAF_RecoveryTanker:ToString(bFrequency, bTacan, bAltitude, bSpeed)
    local message = CALLSIGN.Tanker:ToString(self.Tanker.callsignname) .. " " .. tostring(self.Tanker.callsignnumber)

    local isSeparated

    local function separate()
        if isSeparated then
            message = message .. ", "
            return end

        isSeparated = true
        message = message .. " - "
    end

    if bFrequency then
        separate()
        message = message .. string.format("%.3f %s", self.Tanker.RadioFreq, self.Tanker.RadioModu)
    end
    if bTacan then
        separate()
        message = message .. tostring(self.Tanker.TACANchannel) .. self.Tanker.TACANmode
    end
    if bAltitude then
        separate()
        message = message .. GetAltitudeAsAngelsOrCherubs(self.Tanker.altitude)
    end
    if bSpeed then
        separate()
        message = message .. tostring(UTILS.MpsToKnots(self.Tanker.speed))
    end
    return message
end

function DCAF_RecoveryTanker:Launch()
    self.Tanker:Start()
    self.State = DCAF_RecoveryTankerState.Launched
end

function DCAF_RecoveryTanker:RTB()
    -- self.Tanker:_TaskRTB()
    -- todo - refresh all group's menus
    error("todo :: DCAF_RecoveryTanker:RTB")
end

function DCAF_RecoveryTanker:RendezVous(group)
    -- error("todo :: DCAF_RecoveryTanker:RendezVous")
    self.State = DCAF_RecoveryTankerState.RendezVous
    self.RendezVousGroup = group
end

local function makeRecoveryTanker(carrierUnit, tanker, nTacanChannel, sTacanMode, sTacanIdent, nRadioFreq, nAltitude, sCallsign, nCallsignNumber, nTakeOffType)
    local recoveryTanker
    if isAssignedString(tanker) then
        recoveryTanker = RECOVERYTANKER:New(carrierUnit, tanker)
        if isNumber(nTacanChannel) then
            if not isAssignedString(sTacanMode) then
                sTacanMode = 'Y'
            end
            nTacanChannel, sTacanMode, sTacanIdent = validateTACAN(nTacanChannel, sTacanMode)
            recoveryTanker:SetTACAN(37, sTacanIdent)
            recoveryTanker.TACANmode = sTacanMode
        end
        if isNumber(nRadioFreq) then
            recoveryTanker:SetRadio(nRadioFreq)
        end
        if isNumber(nAltitude) then
            recoveryTanker:SetAltitude(nAltitude)
        end
        if not isAssignedString(sCallsign) then
            sCallsign = CALLSIGN.Tanker.Arco
        end
        if not isNumber(nCallsignNumber) then
            nCallsignNumber = 1
        end
        recoveryTanker:SetCallsign(sCallsign, nCallsignNumber)
        if isNumber(nTakeOffType) then
            recoveryTanker:SetTakeoff(nTakeOffType)
        end
    elseif isTable(tanker) and tanker.ClassName == "RECOVERYTANKER" then
        recoveryTanker = tanker
    end
    if not recoveryTanker then
        error("cannot resolve recovery tanker from " .. DumpPretty(tanker)) end

    local info = DCAF.clone(DCAF_RecoveryTanker)
    info.Tanker = recoveryTanker
    return info
end

local DCAF_ArcosInfo = {
    [1] = {
        TacanChannel = 37,
        TacanMode = 'Y',
        TacanIdent = 'ACA',
        Frequency = 290,
        Altitude = 8000
    },
    [2] = {
        TacanChannel = 38,
        TacanMode = 'Y',
        TacanIdent = 'ACB',
        Frequency = 290.25,
        Altitude = 10000
    }
}

function DCAF.Carrier:WithArco1(sGroupName, nTakeOffType, bLaunchNow, nAltitudeFeet)
    if not isNumber(nAltitudeFeet) then
        nAltitudeFeet = DCAF_ArcosInfo[1].Altitude
    end
    local tanker = makeRecoveryTanker(
        self.Unit,
        sGroupName,
        DCAF_ArcosInfo[1].TacanChannel,
        DCAF_ArcosInfo[1].TacanMode,
        DCAF_ArcosInfo[1].TacanIdent,
        DCAF_ArcosInfo[1].Frequency,
        nAltitudeFeet,
        CALLSIGN.Tanker.Arco, 1, 
        nTakeOffType)
    table.insert(self.RecoveryTankers, tanker)
    if bLaunchNow then
        tanker:Launch()
    end
    return self
end

function DCAF.Carrier:WithArco2(sGroupName, nTakeOffType, bLaunchNow, nAltitudeFeet)
    if not isNumber(nAltitudeFeet) then
        nAltitudeFeet = DCAF_ArcosInfo[1].Altitude
    end
    local tanker = makeRecoveryTanker(
        self.Unit,
        sGroupName,
        DCAF_ArcosInfo[2].TacanChannel,
        DCAF_ArcosInfo[2].TacanMode,
        DCAF_ArcosInfo[2].TacanIdent,
        DCAF_ArcosInfo[2].Frequency,
        nAltitudeFeet,
        CALLSIGN.Tanker.Arco, 2, 
        nTakeOffType)
    table.insert(self.RecoveryTankers, tanker)
    if bLaunchNow then
        tanker:Launch()
    end
    return self
end

local DCAFNavyF10Menus = {
    -- dicionary
    --  key = GROUP name (player aircraft group)
    --  value 
}

local DCAFNavyUnitPlayerMenus = { -- item of #DCAFNavyF10Menus; one per player in Navy aircraft
    MainMenu = nil,               -- #MENU_GROUP    eg. "F10 >> Carriers"
    IsValid = true,               -- boolean; when set all menus are up to date; othwerise needs to be rebuilt
    CarriersMenus = {
        -- dictionary
        --  key    = carrier UNIT name
        --  value  = #DCAFNavyPlayerCarrierMenus
    }
}

local DCAFNavyPlayerCarrierMenus = {
    Carrier = nil,                -- #DCAF.Carrier
    CarrierMenu = nil,            -- #MENU_GROUP     eg. "F10 >> Carriers >> CVN-73 Washington"
    SubMenuActivateSystems = nil, -- #MENU_GROUP_COMMAND  eg. "F10 >> Carriers >> CVN-73 Washington >> Activate systems"
}

local function getTankerMenuData(tanker, group)
    if tanker.State ==  DCAF_RecoveryTankerState.Parked then
        return "Launch " .. tanker:ToString(), function()
            tanker:Launch()
            tanker:RefreshGroupMenus(group)
        end
    elseif tanker.State == DCAF_RecoveryTankerState.Launched then
        return tanker:ToString() .. " (launched)", function()
                MessageTo(group, tanker:ToString(true, true, true))
            end
        -- experimental:
--         return "Send " .. tanker:ToString() .. " to me", function()
-- Debug("nisse - getTankerMenuData / DCAF_RecoveryTankerState.Launched ==> RendezVous with " .. group.GroupName)            
--             tanker:RendezVous(group)
--             tanker:RefreshGroupMenus(group)
--             MessageTo(group, tanker:ToString() .. " is on its way")
--         end
    elseif tanker.State ==  DCAF_RecoveryTankerState.RTB then
        return "(" .. tanker:ToString() .. " is RTB)", function() 
            MessageTo(group, tanker:ToString() .. " is RTB")
        end
    elseif tanker.State ==  DCAF_RecoveryTankerState.RendezVous then
        return "(" .. tanker:ToString() .. " is rendezvousing with " .. tanker.RendezVousGroup.GroupName .. ")", function() 
            MessageTo(group, tanker:ToString() .. " is rendezvousing with " .. tanker.RendezVousGroup.GroupName)
        end
    end
end

function DCAF_RecoveryTanker:RefreshGroupMenus(group)
    local menuText, menuFunc = getTankerMenuData(self, group)
    for groupName, menu in pairs(self.GroupMenus) do
        local parentMenu = menu.ParentMenu
        menu:Remove()
        menu = MENU_GROUP_COMMAND:New(group, menuText, parentMenu, menuFunc)
    end
end

function DCAFNavyF10Menus:Build(group)

    local function buildRecoveryTankersMenu(parentMenu)
        for _, carrier in pairs(DCAFCarriers.Carriers) do
            for _, tanker in ipairs(carrier.RecoveryTankers) do
                local menuText, menuFunc = getTankerMenuData(tanker, group)
-- Debug("carrier: " .. carrier.Unit.UnitName .. " / " .. tanker.Tanker.tankergroupname)
Debug(menuText)
                local menu = MENU_GROUP_COMMAND:New(group, menuText, parentMenu, menuFunc)
                tanker.GroupMenus[group.GroupName] = menu
            end
        end
    end

    local function buildCarrierMenu(group, carrier, parentMenu)
        if carrier.TACAN or carrier.ICLS then
            MENU_GROUP_COMMAND:New(group, "Activate ICLS & TACAN", parentMenu, function()
                carrier:ActivateTACAN()
                carrier:ActivateICLS()
            end)
        end
    end

    -- remove existing menus
    local menus = DCAFNavyF10Menus[group.GroupName]
    if menus then
        menus.MainMenu:Remove()
        menus.MainMenu = nil
    else
        menus = DCAF.clone(DCAFNavyUnitPlayerMenus)
        DCAFNavyF10Menus[group.GroupName] = menus
    end


    if DCAFCarriers.Count == 0 then
        error("DCAF.Carrier:AddF10PlayerMenus :: no carriers was added")
    elseif DCAFCarriers.Count == 1 then
        -- just use a single 'Carriers' F10 menu (no individual carriers sub menus) ...
        for carrierName, carrier in pairs(DCAFCarriers.Carriers) do
            menus.MainMenu = MENU_GROUP:New(group, carrier.DisplayName)
            buildRecoveryTankersMenu(menus.MainMenu)
            buildCarrierMenu(group, carrier, menus.MainMenu)
            break
        end
    else
        -- build a 'Carriers' main menu and individual sub menus for each carrier ...
        menus.MainMenu = MENU_GROUP:New(group, "Carriers")
        buildRecoveryTankersMenu(menus.MainMenu)
        for carrierName, carrier in pairs(DCAFCarriers.Carriers) do
            local carrierMenu = MENU_GROUP:New(group, carrier.DisplayName, menus.MainMenu)
            buildCarrierMenu(group, carrier, carrierMenu)
        end
    end

end

function DCAFNavyF10Menus:Rebuild(carrier, group)
    if not group then
        -- update for all player groups
        for _, g in ipairs(DCAFNavyF10Menus) do
            DCAFNavyF10Menus:Rebuild(carrier, g)
        end
        return
    end

    local menus = DCAFNavyF10Menus[group.GroupName]
    if menus then
        DCAFNavyF10Menus:Build(carrier, group)
    end
end

-- note: This should be invoked at start of mission, before players start entering slots
function DCAF.Carrier:AddF10PlayerMenus()
    MissionEvents:OnPlayerEnteredAirplane(
        function( event )
            if not IsNavyAircraft(event.IniUnit) then
                return end
            
            if not DCAFNavyF10Menus[event.IniGroupName] then
                DCAFNavyF10Menus:Build(event.IniUnit:GetGroup())
            end
        end, true)
end

---------------------------------------- BIG (air force) TANKERS ----------------------------------------

local DCAF_Tankers = {
    [CALLSIGN.Tanker.Shell] = {
        [1] = {
            Frequency = 270,
            TACANChannel = 39,
            TACANMode = 'Y',
            TACANIdent = 'SHA',
            TrackBlock = 22,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [2] = {
            Frequency = 270.25,
            TACANChannel = 40,
            TACANMode = 'Y',
            TACANIdent = 'SHB',
            TrackBlock = 24, -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [3] = {
            Frequency = 270.5,
            TACANChannel = 41,
            TACANMode = 'Y',
            TACANIdent = 'SHC',
            TrackBlock = 26, -- x1000 feet
            TrackSpeed = 430, -- knots
        },
    },
    [CALLSIGN.Tanker.Texaco] = {
        [1] = {
            Frequency = 280,
            TACANChannel = 42,
            TACANMode = 'Y',
            TACANIdent = 'TXA',
            TrackBlock = 18, -- x1000 feet
            TrackSpeed = 350, -- knots
        },
        [2] = {
            Frequency = 280.25,
            TACANChannel = 43,
            TACANMode = 'Y',
            TACANIdent = 'TXB',
            TrackBlock = 20, -- x1000 feet
            TrackSpeed = 350, -- knots
        },
        [3] = {
            Frequency = 280.5,
            TACANChannel = 44,
            TACANMode = 'Y',
            TACANIdent = 'TXC',
            TrackBlock = 16, -- x1000 feet
            TrackSpeed = 350, -- knots
        },
    },
}

local DCAF_TankerMonitor = {
    Timer = nil,              
}

local DCAF_TrackFromWaypoint = {
    ClassName = "TRACK_FROM_WAYPOINT"
}

DCAF.Tanker = {
    Group = nil,              -- #GROUP (the tanker group)
    TACANChannel = nil,       -- #number; TACAN channel
    TACANMode = nil,          -- #string; TACAN mode
    TACANIdent = nil,         -- #string; TACAN ident
    FuelStateRtb = 0.15,      -- 
    Frequency = nil,          -- #number; radio frequency
    StartFrequency = nil,     -- #number; radio frequency tuned at start and during RTB/landing
    RTBAirbase = nil,         -- #AIRBASE; the last WP landing airbase; or starting/closest airbase otherwise
    RTBWaypoint = nil,        -- #number; first waypoint after track waypoints (set by :SetTrackFromWaypoint)
    TrackBlock = nil,         -- #number; x1000 feet
    TrackSpeed = nil,         -- #number; knots
    Track = nil,
    Events = {},              -- dictionary; key = name of event (eg. 'OnFuelState'), value = event arguments
}

function DCAF.Tanker:New(controllable, replicate)
   local group = getGroup(controllable)
    if not group then
        error("DCAF.Tanker:New :: cannot resolve group from " .. DumpPretty(controllable)) end

    local tanker = DCAF.clone(replicate or DCAF.Tanker)

    -- initiate tanker ...
    tanker.Group = group
    local callsign, callsignNumber = GetCallsign(group)

    Trace("DCAF.Tanker:New :: callsign: " .. callsign .. " " .. Dump(callsignNumber))    
    local defaults = DCAF_Tankers[CALLSIGN.Tanker:FromString(callsign)][callsignNumber]
    tanker.TACANChannel = defaults.TACANChannel
    tanker.TACANMode = defaults.TACANMode
    tanker.TACANIdent = defaults.TACANIdent
    tanker.Frequency = defaults.Frequency
    tanker.RTBAirbase = GetRTBAirbaseFromRoute(group)
    tanker.TrackBlock = defaults.TrackBlock
    tanker.TrackSpeed = defaults.TrackSpeed
    
    if tanker.Track and tanker.Track.Route then
        -- replicate route from precious tanker ...
        group:Route(tanker.Track.Route)
    end

    -- register all events (from replicate)
    for _, event in pairs(tanker.Events) do
        event.EventFunc(event.Args)
    end

    return tanker
end

function DCAF.Tanker:NewFromCallsign(callsign, callsignNumber)
    if callsign == nil then
        error("DCAF.Tanker:New :: callsign group was not specified") end

    local group 
    local groups = _DATABASE.GROUPS
    local callsignName = CALLSIGN.Tanker:ToString(callsign)
    for _, g in pairs(groups) do
        if g:IsAir() then
            local csName, csNumber = GetCallsign(g:GetUnit(1))
            if csName == callsignName and csNumber == callsignNumber then
                group = g
                break
            end
        end
    end
    if not group then
        error("DCAF.Tanker:New :: found no group with callsign " .. callsignName .. "-" .. tostring(callsignNumber)) end

    return DCAF.Tanker:New(group)
end

function HasTask(controllabe, sTaskId, wpIndex) -- todo move higher up, to more general part of the file
    local group = getGroup(controllabe)
    if not group then
        error("HasTask :: cannot resolve group from: " .. DumpPretty(controllabe)) end

    local route = group:CopyRoute()
    local function hasWpTask(wp)
        for index, task in ipairs(wp.task.params.tasks) do
            if task.id == sTaskId then 
                return index end
        end
    end

    if not wpIndex then
        for wpIndex, wp in ipairs(route) do
            if hasWpTask(wp) then 
                return wpIndex end
        end
    elseif hasWpTask(route[wpIndex]) then
        return wpIndex 
    end
end

function HasAction(controllabe, sActionId, wpIndex) -- todo move higher up, to more general part of the file
    local group = getGroup(controllabe)
    if not group then
        error("HasTask :: cannot resolve group from: " .. DumpPretty(controllabe)) end

    local route = group:CopyRoute()
    local function hasWpAction(wp)
        for index, task in ipairs(wp.task.params.tasks) do
            if task.id == "WrappedAction" and task.params.action.id == sActionId then 
                return index end
        end
    end

    if not wpIndex then
        for wpIndex, wp in ipairs(route) do
            if hasWpAction(wp) then 
                return wpIndex end
        end
    elseif hasWpAction(route[wpIndex]) then
        return wpIndex
    end
end

function HasLandingTask(controllabe) return HasAction(controllabe, "Landing") end
function HasOrbitTask(controllabe) return HasTask(controllabe, "Orbit") end
function HasTankerTask(controllabe) return HasTask(controllabe, "Tanker") end
function HasSetFrequencyTask(controllabe) return HasAction(controllabe, "SetFrequency") end
function HasActivateBeaconTask(controllabe) return HasAction(controllabe, "ActivateBeacon") end
function HasDeactivateBeaconTask(controllabe) return HasAction(controllabe, "DeactivateBeacon") end

function DCAF_TrackFromWaypoint:Execute()
    local route = self.Tanker.Group:CopyRoute()
    local startWpIndex = self.StartWpIndex
    local startWp = route[startWpIndex]
    
    local trackLength = self.Length
    local trackAltitude
    local trackHeading = self.Heading
    if not isNumber(trackLength) then
        trackLength = NauticalMiles(30)
    end
    if isNumber(self.Block) then
        trackAltitude = Feet(self.Block*1000)
        startWp.alt = trackAltitude
    end

    local startWpCoord = COORDINATE:NewFromWaypoint(startWp)
    local endWpCoord 
    if not isNumber(trackHeading) then
        if startWpIndex == #route then
            error("DCAF.Tanker:SetTrackFromWaypoint :: heading was unassigned/unexpected value and start of track was also last waypoint")
        else
            endWpCoord = COORDINATE:NewFromWaypoint(route[startWpIndex+1])
            self.RTBWaypoint = startWpIndex+2 -- note, if last WP in track was also last waypoint in route, this will point 'outside' the route
        end
    else
        endWpCoord = startWpCoord:Translate(trackLength, trackHeading, trackAltitude)
    end
    
    local function drawTrack()
        if not self.Color then
            return end

        local rgbColor 
        if self.IsTrackDrawn then
            self.Color = { 1, 0, 0 }
        end

        self.IsTrackDrawn = true
        if isTable(self.Color) then
            rgbColor = self.Color
        else
            rgbColor = {0,1,1}
        end
        local trackHeading = startWpCoord:GetAngleDegrees(startWpCoord:GetDirectionVec3(endWpCoord))
        local trackDistance = startWpCoord:Get2DDistance(endWpCoord)
        local wp1 = startWpCoord:Translate(trackDistance + NauticalMiles(7), trackHeading, trackAltitude)
        local perpHeading = (trackHeading - 90) % 360
        local wp2 = wp1:Translate(NauticalMiles(13), perpHeading, trackAltitude)
        perpHeading = (perpHeading - 90) % 360
        local wp3 = wp2:Translate(trackDistance + NauticalMiles(14), perpHeading, trackAltitude)
        perpHeading = (perpHeading - 90) % 360
        local wp4 = wp3:Translate(NauticalMiles(13), perpHeading, trackAltitude)
        wp1:MarkupToAllFreeForm({wp2, wp3, wp4}, self.Tanker.Group:GetCoalition(), rgbColor, 0.5, nil, 0, 3)
        wp4:SetHeading(trackHeading)
        if isAssignedString(self.TrackName) then
            wp4:TextToAll(self.TrackName, self.Tanker.Group:GetCoalition(), rgbColor, 0.5, nil, 0)
        end
    end
    local function hasOrbitTask() return HasTask(self.Tanker.Group, "Orbit") end                          -- todo consider elevating this func to global
    local function hasTankerTask() return HasTask(self.Tanker.Group, "Tanker") end                        -- todo consider elevating this func to global
    local function hasSetFrequencyTask() return HasAction(self.Tanker.Group, "SetFrequency") end          -- todo consider elevating this func to global
    local function hasActivateBeaconTask() return HasAction(self.Tanker.Group, "ActivateBeacon") end      -- todo consider elevating this func to global
    local function hasDeactivateBeaconTask() return HasAction(self.Tanker.Group, "DeactivateBeacon") end  -- todo consider elevating this func to global

    local function insertTask(task)                                                   -- todo consider elevating this func to global
        task.number = #startWp.task.params.tasks+1 
        table.insert(startWp.task.params.tasks, task)
    end

    local function insertAction(action, wpIndex)                                      -- todo consider elevating this func to global
        if wpIndex == nil then
            wpIndex = startWpIndex end
        local wp = route[wpIndex]
        table.insert(wp.task.params.tasks, {
            number = #wp.task.params.tasks+1,
            auto = false,
            id = "WrappedAction",
            enabled = true,
            params = { action = action },
          })
    end

    drawTrack()

    local tankerTask = hasTankerTask()
    if not tankerTask or tankerTask > startWpIndex then
        insertTask({
            auto = false,
            id = "Tanker",
            enabled = true,
            params = { },
          })
    end

    local setFrequencyTask = hasSetFrequencyTask()
    if not setFrequencyTask or setFrequencyTask > startWpIndex then
        insertAction({ 
            id = 'SetFrequency', 
            params = { 
                power = 10,
                frequency = self.Tanker.Frequency * 1000000, 
                modulation = radio.modulation.AM, 
            }, 
        })
    end

    local orbitTask = hasOrbitTask()
    if not orbitTask or orbitTask ~= startWpIndex then
        insertTask(self.Tanker.Group:TaskOrbit(startWpCoord, trackAltitude, Knots(self.Tanker.TrackSpeed), endWpCoord))
        if orbitTask ~= startWpIndex then
            Warning("DCAF.Tanker:SetTrackFromWaypoint :: there is an orbit task set to a different WP (" .. Dump(orbitTask) .. ") than the one starting the tanker track (" .. Dump(startWpIndex) .. ")") end

        self.Tanker.RTBWaypoint = startWpIndex+1 -- note, if 1st WP in track was also last waypoint in route, this will point 'outside' the route
    end

    if not hasActivateBeaconTask() then
        -- ensure TACAN gets activated _before_ the first Track WP (some weird bug in DCS otherwise may cause it to not activate)
        -- inject a new waypoint 2 nm before the tanker track, or use the previous WP if < 10nm from the tanker track
        local prevWp = route[startWpIndex-1]
        local prevWpCoord = COORDINATE:NewFromWaypoint(prevWp)
        local distance = prevWpCoord:Get2DDistance(startWpCoord)
        local tacanWp
        local tacanWpIndex
        local tacanWpSpeed = UTILS.KnotsToKmph(self.Tanker.TrackSpeed)
        if distance <= NauticalMiles(10) then
            tacanWp = prevWp
            tacanWpIndex = startWpIndex-1
        else
            local dirVec3 = prevWpCoord:GetDirectionVec3(startWpCoord)
            local heading = prevWpCoord:GetAngleDegrees(dirVec3)
            local tacanWpCoord = prevWpCoord:Translate(distance - NauticalMiles(2), heading, trackAltitude)
            local tacanWp = tacanWpCoord:WaypointAir(
                COORDINATE.WaypointAltType.BARO, 
                COORDINATE.WaypointType.TurningPoint,
                COORDINATE.WaypointAction.TurningPoint,
                tacanWpSpeed)
            table.insert(route, startWpIndex, tacanWp)
            tacanWpIndex = startWpIndex
        end

        local tacanSystem
        if self.TACANMode == "X" then
            tacanSystem = BEACON.System.TACAN_TANKER_X
          else
            tacanSystem = BEACON.System.TACAN_TANKER_Y
          end
        insertAction({
            id = "ActivateBeacon",
            params = {
                modeChannel = self.Tanker.TACANMode,
                type = BEACON.Type.TACAN,
                system = tacanSystem,
                AA = false,
                callsign = self.Tanker.TACANIdent,
                channel = self.Tanker.TACANChannel,
                bearing = true,
                frequency = UTILS.TACANToFrequency(self.Tanker.TACANChannel, self.Tanker.TACANMode),
            },
          })
          if startWpIndex == #route or startWpIndex == #route-1 then
            -- add waypoint for end of track ...
            local endWp = endWpCoord:WaypointAir(
                COORDINATE.WaypointAltType.BARO, 
                COORDINATE.WaypointType.TurningPoint,
                COORDINATE.WaypointAction.TurningPoint,
                tacanWpSpeed,
            tacanWpIndex)
            endWp.alt = trackAltitude
            table.insert(route, startWpIndex+1, endWp)
        end
    end

    self.Route = route
    self.Tanker.Group:Route(route)
end

function DCAF.Tanker:SetTrackFromWaypoint(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    if not isNumber(nStartWp) then
        error("DCAF.Tanker:SetTrackFromWaypoint :: start waypoint was unassigned/unexpected value: " .. Dump(nStartWp)) end
    if nStartWp < 1 then
        error("DCAF.Tanker:SetTrackFromWaypoint :: start waypoint must be 1 or more (was: " .. Dump(nStartWp) .. ")") end
    local route = self.Group:CopyRoute()
    nStartWp = nStartWp+1 -- this is to harmonize with WP numbers on map (1st WP on map is zero - 0)
    if nStartWp > #route then
        error("DCAF.Tanker:SetTrackFromWaypoint :: start waypoint must be within route (route is " .. Dump(#route) .. " waypoints, startWp was ".. Dump(nStartWp) .. ")") end

    self.Track = DCAF.clone(DCAF_TrackFromWaypoint)
    self.Track.Tanker = self
    self.Track.StartWpIndex = nStartWp
    self.Track.Heading = nHeading
    self.Track.Length = nLength
    self.Track.Block = nBlock
    self.Track.Color = rgbColor
    self.Track.TrackName = sTrackName
    self.Track:Execute()
    
    return self
end

local function DCAF_Tanker_OnFuelState(args)
    MissionEvents:OnFuelState(args.Tanker.Group, args.State, function() args.Func(args.Tanker) end)
end

function DCAF.Tanker:OnFuelState(state, func)
    if not isFunction(func) then
        error("DCAF.Tanker:OnFuelState :: func was unassigned/unexpected value: " .. DumpPretty(func)) end

    local args = {
        Tanker = self,
        State = state,
        Func = func
    }
    DCAF_Tanker_OnFuelState(args)
    self.Events["OnFuelState"] = { EventFunc = DCAF_Tanker_OnFuelState, Args = args }
    return self
end

function DCAF.Tanker:OnBingoState(func)
    return self:OnFuelState(0.15, func)
end

function DCAF.Tanker:Start(delay)
    if isNumber(delay) then
        Delay(delay, function()
            activateNow(self.Group)
        end)
    else
        activateNow(self.Group)
    end
    return self
end

function WaypointLandAt(airbase) -- todo Consider using MOOSE's COORDINATE:WaypointAirLanding( Speed, airbase, DCSTasks, description ) instead
    local nAirbaseID
    if isNumber(airbase) then
        nAirbaseID = airbase
        airbase = AIRBASE:FindByID(nAirbaseID)
        if not airbase then
            return errorOnDebug("WaypointLandAt :: cannot resolve airbase from id: " .. Dump(nAirbaseID)) end   
    elseif isAirbase(airbase) then
        nAirbaseID = airbase:GetID()
    else
        error("WaypointLandAt :: unexpected `airbase` value: " .. DumpPretty(airbase))
    end

    local vec2 = airbase:GetPointVec2()
    return {
            ["speed_locked"] = true,
            ["airdromeId"] = nAirbaseID,
            ["action"] = "Landing",
            ["alt_type"] = "BARO",
            ["y"] = vec2.x,
            ["x"] = vec2.y,
            ["alt"] = airbase:GetAltitude(),
            ["ETA_locked"] = false,
            ["speed"] = 138.88888888889,
            ["formation_template"] = "",
            ["type"] = "Land",
       }
end

function DCAF.Tanker:RTB()
    local route = self.Group:CopyRoute()
    local landingWp = HasLandingTask(self.Group)
    if not landingWp then 
        -- create a landing WP and divert ...
        landingWp = WaypointLandAt(self.RTBAirbase)
        table.insert(route, #route+1, landingWp)
        self.Group:Route(route)
    end

    -- leave the track to RTB ...
    self.Group:Route(RouteDirectTo(self.Group, self.RTBWaypoint))
    return self
end

function DCAF.Tanker:SpawnReplacement(funcOnSpawned, nDelay)
    local function spawnNow()
        local group = SPAWN:New(self.Group.GroupName):Spawn()
        local tanker = DCAF.Tanker:New(group, self)
        if isFunction(funcOnSpawned) then
            funcOnSpawned(group)
        end
    end

    if isNumber(nDelay) then
        Delay(nDelay, spawnNow)
    else
        return spawnNow()
    end
    return self
end

----------------------------------------------------------------------------------------------

Trace("DCAF.Core was loaded")