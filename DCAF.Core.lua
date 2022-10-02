DCAFCore = {
    Trace = false,
    TraceToUI = false, 
    Debug = false,
    DebugToUI = false, 
    WaypointNames = {
        RTB = '_rtb_',
        Divert = '_divert_',
    }
}

function isString( value ) return type(value) == "string" end
function isBoolean( value ) return type(value) == "boolean" end
function isNumber( value ) return type(value) == "number" end
function isTable( value ) return type(value) == "table" end
function isFunction( value ) return type(value) == "function" end
function isClass( value, class ) return isTable(value) and value.ClassName == class end
function isUnit( value ) return isClass(value, "UNIT") end
function isGroup( value ) return isClass(value, "GROUP") end
function isZone( value ) return isClass(value, "ZONE") end

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
    if (DCAFCore.Trace) then
        BASE:E("DCAF-TRC @"..timestamp.." ===> "..tostring(message))
    end
    if (DCAFCore.TraceToUI) then
      MESSAGE:New("DCAF-TRC: "..message):ToAll()
    end
end
  
function Debug( message )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    if (DCAFCore.Debug) then
        BASE:E("DCAF-DBG @"..timestamp.." ===> "..tostring(message))
    end
    if (DCAFCore.DebugToUI) then
      MESSAGE:New("DCAF-DBG: "..message):ToAll()
    end
end
  
function Warning( message )
    local timestamp = UTILS.SecondsToClock( UTILS.SecondsOfToday() )
    BASE:E("DCAF-WRN @"..timestamp.."===> "..tostring(message))
    if (DCAFCore.TraceToUI or DCAFCore.DebugToUI) then
      MESSAGE:New("DCAF-WRN: "..message):ToAll()
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
    return nil
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
    return nil
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

    -- local nisse_targetName = nil
    local targetCoordinate = nil
    local targetUnit = getUnit(target)
    if targetUnit == nil then
        local g = getGroup(target)
        if g == nil then
            error("IsHeadingFor :: target coordinate could not be resolved from " .. Dump(target))
            return
        end
        -- nisse_targetName = g.GroupName
        targetCoordinate = g:GetCoordinate()
    else
        -- nisse_targetName = targetUnit:GetName()
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
        Warning("GetEscortingGroups :: cannot resolve group from " .. Dump(source) .. " :: EXITS")
        return
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
        Warning("GetEscortClientGroup :: cannot resolve group from " .. Dump(source) .. " :: EXITS")
        return
    end

--Debug("GetEscortClientGroup-" .. group.GroupName .. "..." )

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
        Warning("GetOtherCoalitions :: group not found: "..Dump(controllable).." :: EXITS")
        return
    end

    local c = group:GetCoalition()

    if excludeNeutral == nil then 
        excludeNeutral = false end

--Debug("GetOtherCoalitions :: coalition: " .. tostring(c)) -- nisse

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
Debug("GetGroupSuperiority-"..aGroup.GroupName.." / "..bGroup.GroupName.." :: " .. string.format("size: %d / %d :: missiles: %d / %d", aSize, bSize, aMissiles, bMissiles)) -- nisse
Debug("GetGroupSuperiority-"..aGroup.GroupName.." / "..bGroup.GroupName.." :: missileRatio: "..tostring(missileRatio)) -- nisse
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
    if (recipient == nil) then
        Warning("MessageTo :: Recipient name not specified :: EXITS")
        return
    end
    if (message == nil) then
        Warning("MessageTo :: Message was not specified :: EXITS")
        return
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
        Warning("MessageTo-?"..recipient.." :: Group could not be resolved :: EXITS")
        return
    end

    if isTable(recipient) then
        if (string.match(message, ".\.ogg") or string.match(message, ".\.wav")) then
            local audio = USERSOUND:New(message)
            if DebugAudioMessageToAll then
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
        if isGroup(recipient) then
            Trace("MessageTo :: group " .. recipient.GroupName .. " :: '" .. message .."'")
            msg:ToGroup(recipient)
            return
        elseif isUnit(recipient) then
            Trace("MessageTo :: unit " .. recipient:GetName() .. " :: '" .. message .. "'")
            msg:ToUnit(recipient)
            return
        end
        -- if (recipient.ClassName == "CLIENT") then obsolete?
        --     if (string.match(message, ".\.ogg") or string.match(message, ".\.wav")) then
        --         USERSOUND:New(message):ToGroup(recipient)
        --         Trace("MessageTo (sound) :: Group "..recipient.GroupName.." :: '"..message.."'")
        --         return
        --     end
        --     MESSAGE:New(message, duration):ToClient(recipient)
        --     Trace("MessageTo :: Client "..recipient:GetName().." :: "..message.."'")
        --     return
        -- end
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

function DumpPrettyOptions:AsJson( value )
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

      if (not options.deep and ilvl > 0) then
        if (options.asJson) then
            return "{ }" 
        end
        return "{ --[[ data omitted ]]-- }"
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
        Warning("GetRelativeLocation :: cannot resolve source group from " .. Dump(source) .. " :: EXITS")
        return nil
    end
    local targetGroup = getGroup(target)
    if not targetGroup then
        Warning("GetRelativeLocation :: cannot resolve target group from " .. Dump(target) .. " :: EXITS")
        return nil
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
        Warning("GetMSL :: cannot resolve group from "..Dump(controllable).." :: EXITS")
        return false
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
        Warning("GetAGL :: cannot resolve group from "..Dump(controllable).." :: EXITS")
        return false
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
        Warning("DirectTo-? :: controllable not specified :: EXITS")
        return
    end
    if (steerpoint == nil) then
        Warning("DirectTo-? :: steerpoint not specified :: EXITS")
        return
    end

    local route = nil
    local group = getGroup( controllable )
    if ( group == nil ) then
        Warning("DirectTo-? :: cannot resolve group: "..Dump(controllable).." :: EXITS")
        return
    end
    
    route = group:CopyRoute()
    if (route == nil) then
        Warning("DirectTo-" .. group.GroupName .." :: cannot resolve route from controllable: "..Dump(controllable).." :: EXITS")
        return
    end

    local wpIndex = nil
    if (isString(steerpoint)) then
        local wp = FindWaypointByName( route, steerpoint )
        if (wp == nil) then
            Warning("DirectTo-" .. group.GroupName .." :: no waypoint found with name '"..steerpoint.."' :: EXITS")
        return
        end
        wpIndex = wp.index
    elseif (isNumber(steerpoint)) then
        wpIndex = steerpoint
    else
        Warning("DirectTo-" .. group.GroupName .." :: cannot resolved steerpoint: "..Dump(steerpoint).." :: EXITS")
        return
    end

    local directToRoute = {}
    for i=wpIndex,#route,1 do
        table.insert(directToRoute, route[i])
    end

    return directToRoute

end

function SetRoute( controllable, route )

    if (controllable == nil) then
        Warning("SetRoute-? :: controllable not specified :: EXITS")
        return
    end
    if (not isTable(route)) then
        Warning("SetRoute-? :: invalid route (not a table) :: EXITS")
        return
    end
    local group = getGroup(controllable)
    if (group == nil) then
        Warning("SetRoute-? :: group not found: "..Dump(controllable).." :: EXITS")
        return
    end

    group:Route( route )
    Trace("SetRoute-"..group.GroupName.." :: group route was set :: DONE")
--[[
    local taskRoute = group:TaskRoute( route )

    Debug("SetRoute (nisse) :: taskRoute: " .. DumpPretty(taskRoute, DumpPrettyOptions:New():Deep()))

    group:SetTask( taskRoute )
    Trace("SetRoute-"..group.GroupName.." :: group route was set :: DONE")
]]--    
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
        Trace("Follow-? :: Follower was not specified :: EXITS")
        return
    end
    local followerGrp = getGroup(follower)
    if (followerGrp == nil) then
        Trace("Follow-? :: Cannot find follower: "..Dump(follower).." :: EXITS")
        return
    end

    if (leader == nil) then
        Trace("Follow-? :: Leader was not specified :: EXITS")
        return
    end
    local leaderGrp = getGroup(leader)
    if (leaderGrp == nil) then
        Trace("Follow-? :: Cannot find leader: "..Dump(leader).." :: EXITS")
        return
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
    return FindWaypointByName( group, DCAFCore.WaypointNames.RTB ) ~= nil
end

function CanRTB( group ) 
    return GetDivertWaypoint( group ) ~= nil
end

function RTB( controllable, steerpointName )

    local steerpointName = steerpointName or DCAFCore.WaypointNames.RTB
    local route = RouteDirectTo(controllable, steerpointName)
    return SetRoute( controllable, route )

end

function GetDivertWaypoint( group ) 
    return FindWaypointByName( group, DCAFCore.WaypointNames.Divert ) ~= nil
end

function CanDivert( group ) 
    return GetDivertWaypoint( group ) ~= nil
end

local _onDivertFunc = nil

function Divert( controllable, steerpointName )
    local steerpointName = steerpointName or DCAFCore.WaypointNames.Divert
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
        Warning("GotoWaypoint :: missing controllable :: EXITS")
        return
    else
        group = getGroup(controllable)
        if not group then
            Warning("GotoWaypoint :: cannot resolve group from "..Dump(controllable).." :: EXITS")
            return
        end
    end
    if not from then
        Warning("GotoWaypoint :: missing 'from' :: EXITS")
        return
    elseif not isNumber(from) then
        Warning("GotoWaypoint :: 'from' is not a number :: EXITS")
        return
    end
    if not to then
        Warning("GotoWaypoint :: missing 'to' :: EXITS")
        return
    elseif not isNumber(to) then
        Warning("GotoWaypoint :: 'to' is not a number :: EXITS")
        return
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
        Trace("LandHere-? :: group not found: "..Dump(controllable).." :: EXITS")
        return
    end

    category = category or Airbase.Category.AIRDROME

    local ab = group:GetCoordinate():GetClosestAirbase2( category, coalition )
    if (ab == nil) then
        Trace("LandHere-"..group.GroupName.." :: no near airbase found :: EXITS")
        return
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

function TaskAttackGroup( attacker, target )

    local ag = getGroup(attacker)
    if (ag == nil) then
        Warning("TaskAttackGroup-? :: cannot resolve attacker group "..Dump(attacker) .." :: EXITS")
    end
    local tg = getGroup(target)
    if (tg == nil) then
        Warning("TaskAttackGroup-? :: cannot resolve target group "..Dump(tg) .." :: EXITS")
    end

    if (ag:OptionROEOpenFirePossible()) then
        ROEOpenFire(ag)
    end
    ag:SetTask(ag:TaskAttackGroup(tg))
    Trace("TaskAttackGroup-"..ag.GroupName.." :: attacks group "..tg.GroupName..":: DONE")

end

--------------------------------------------- [[ MISSION EVENTS ]] ---------------------------------------------

MissionEvents = {
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

    local function getTarget(event)
        local dcsTarget = event.target 
        if not dcsTarget and event.weapon then
            dcsTarget = event.weapon:getTarget()
        end
    end

    local function addInitiatorAndTarget( event )
        if event.initiator ~= nil and event.IniUnit == nil then
            event.IniUnit = UNIT:Find(event.initiator)
            event.IniUnitName = event.IniUnit:GetName()
            event.IniGroup = event.IniUnit:GetGroup()
            event.IniGroupName = event.IniGroup.GroupName
        end
        local dcsTarget = event.target or getTarget(event)
        if event.TgtUnit == nil and dcsTarget ~= nil then
            event.TgtUnit = UNIT:Find(dcsTarget)
            event.TgtUnitName = event.TgtUnit:GetName()
            event.TgtGroup = event.TgtUnit:GetGroup()
            event.TgtGroupName = event.TgtGroup.GroupName
        end
        return event
    end

    if (event.id == EVENTS.Birth) then
        if event.IniGroup and #MissionEvents._groupSpawnedHandlers > 0 then
            MissionEvents:Invoke( MissionEvents._groupSpawnedHandlers, event )
        end
        if event.IniUnit then
            if #MissionEvents._unitSpawnedHandlers > 0 then
                MissionEvents:Invoke( MissionEvents._unitSpawnedHandlers, event )
            end
            if  event.IniPlayerName then
                MissionEvents:Invoke( MissionEvents._playerEnteredUnitHandlers, event )
            end
        end
        return
    end

    --[[
        note I can't figure out how to get to the player with this event: {
            ["id"] = 20,
            ["time"] = 0,
            ["initiator"] = { 
                ["id_"] = 16812544, 
            },
        })
    -- if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then --  event
    --     Debug("nisse - world.event.S_EVENT_PLAYER_ENTER_UNIT :: event: " .. DumpPretty(event, deep))
    -- end
    ]]--

    if event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
--        Debug("nisse - world.event.S_EVENT_PLAYER_LEAVE_UNIT :: event: " .. DumpPretty(event, deep))
        MissionEvents:Invoke( MissionEvents._playerLeftUnitHandlers, event )
    end

    if event.id == world.event.S_EVENT_DEAD then
        if event.IniUnit and #MissionEvents._unitDeadHandlers > 0 then
            MissionEvents:Invoke( MissionEvents._unitDeadHandlers, {
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
        if #MissionEvents._unitKilledHandlers > 0 then
            MissionEvents:Invoke( MissionEvents._unitKilledHandlers, {
                IniUnit = UNIT:Find(event.initiator),
                TgtUnit = UNIT:Find(event.target)
            })
        end
        if #MissionEvents._unitDeadHandlers > 0 then
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
        if #MissionEvents._ejectionHandlers > 0 then
            MissionEvents:Invoke( MissionEvents._ejectionHandlers, event)
        end
        return
    end

    if event.id == world.event.S_EVENT_CRASH then
        if #MissionEvents._unitCrashedHandlers > 0 then
            MissionEvents:Invoke( MissionEvents._unitCrashedHandlers, event)
        end
--         if #MissionEvents._unitDeadHandlers > 0 then
--             event.id = world.event.S_EVENT_DEAD
--             event.IniUnit = UNIT:Find(event.initiator)
--             event.IniPlayerName = event.IniUnit:GetPlayerName()
-- Debug("nisse - S_EVENT_CRASH >> S_EVENT_DEAD :: event: " .. DumpPretty(event))
--             _e:onEvent(event)
--         end
        return
    end

    if event.id == world.event.S_EVENT_SHOT then
        if (#MissionEvents._weaponFiredHandlers > 0) then
            local dcsTarget = event.target 
            if not dcsTarget and event.weapon then
                dcsTarget = event.weapon:getTarget()
            end
            MissionEvents:Invoke( MissionEvents._weaponFiredHandlers, addInitiatorAndTarget(event))
        end
        return
    end
        
    if (event.id == world.event.S_EVENT_SHOOTING_START) then
        if (#MissionEvents._shootingStartHandlers > 0) then
            MissionEvents:Invoke( MissionEvents._shootingStartHandlers, addInitiatorAndTarget(event))
        end
        return
    end

    if (event.id == world.event.S_EVENT_SHOOTING_END) then
        if (#MissionEvents._shootingStopHandlers > 0) then
            MissionEvents:Invoke( MissionEvents._shootingStopHandlers, addInitiatorAndTarget(event))
        end
        return
    end
        
    if (event.id == world.event.S_EVENT_HIT) then
--Debug("_e:onEvent-S_EVENT_HIT :: event: " .. DumpPretty(event, deep))
        if (#MissionEvents._unitHitHandlers > 0) then
            MissionEvents:Invoke( MissionEvents._unitHitHandlers, event)
        end
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
    if (isMissionEventsListenerRegistered) then
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

function MissionEvents:OnGroupSpawned( func, insertFirst ) MissionEvents:AddListener(MissionEvents._groupSpawnedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnGroupSpawned( func ) MissionEvents:RemoveListener(MissionEvents._groupSpawnedHandlers, func) end

function MissionEvents:OnUnitSpawned( func, insertFirst ) MissionEvents:AddListener(MissionEvents._unitSpawnedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitSpawned( func ) MissionEvents:RemoveListener(MissionEvents._unitSpawnedHandlers, func) end

function MissionEvents:OnUnitDead( func, insertFirst ) MissionEvents:AddListener(MissionEvents._unitDeadHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitDead( func ) MissionEvents:RemoveListener(MissionEvents._unitDeadHandlers, func) end

function MissionEvents:OnUnitKilled( func, insertFirst ) MissionEvents:AddListener(MissionEvents._unitKilledHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitKilled( func ) MissionEvents:RemoveListener(MissionEvents._unitKilledHandlers, func) end

function MissionEvents:OnUnitCrashed( func, insertFirst ) MissionEvents:AddListener(MissionEvents._unitCrashedHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitCrashed( func ) MissionEvents:RemoveListener(MissionEvents._unitCrashedHandlers, func) end

function MissionEvents:OnPlayerEnteredUnit( func, insertFirst ) MissionEvents:AddListener(MissionEvents._playerEnteredUnitHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnPlayerEnteredUnit( func ) MissionEvents:RemoveListener(MissionEvents._playerEnteredUnitHandlers, func) end

function MissionEvents:OnPlayerLeftUnit( func, insertFirst ) MissionEvents:AddListener(MissionEvents._playerLeftUnitHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnPlayerLeftUnit( func ) MissionEvents:RemoveListener(MissionEvents._playerLeftUnitHandlers, func) end

function MissionEvents:OnEjection( func, insertFirst ) MissionEvents:AddListener(MissionEvents._ejectionHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnEjection( func ) MissionEvents:RemoveListener(MissionEvents._ejectionHandlers, func) end

function MissionEvents:OnWeaponFired( func, insertFirst ) MissionEvents:AddListener(MissionEvents._weaponFiredHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnWeaponFired( func ) MissionEvents:RemoveListener(MissionEvents._weaponFiredHandlers, func) end

function MissionEvents:OnShootingStart( func, insertFirst ) MissionEvents:AddListener(MissionEvents._shootingStartHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnShootingStart( func ) MissionEvents:RemoveListener(MissionEvents._shootingStartHandlers, func) end

function MissionEvents:OnShootingStop( func, insertFirst ) MissionEvents:AddListener(MissionEvents._shootingStopHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnShootingStop( func ) MissionEvents:RemoveListener(MissionEvents._shootingStopHandlers, func) end

function MissionEvents:OnUnitHit( func, insertFirst ) MissionEvents:AddListener(MissionEvents._unitHitHandlers, func, nil, insertFirst) end
function MissionEvents:EndOnUnitHit( func ) MissionEvents:RemoveListener(MissionEvents._unitHitHandlers, func) end


--- CUSTOM EVENTS
function MissionEvents:OnPlayerEnteredAirplane( func, insertFirst ) 
    MissionEvents:AddListener(MissionEvents._playerEnteredUnitHandlers, 
        function( event )
            if event.IniUnit:IsAirPlane() then
                func( event )
            end
        end,
        nil,
        insertFirst) 
end
function MissionEvents:EndOnPlayerEnteredAirplane( func ) MissionEvents:RemoveListener(MissionEvents._playerEnteredUnitHandlers, func) end

function MissionEvents:OnPlayerLeftAirplane( func, insertFirst )
    MissionEvents:AddListener(MissionEvents._playerLeftUnitHandlers, 
        function( event )
            if event.IniUnit:IsAirPlane() then
                func( event )
            end
        end,
        nil,
        insertFirst) 
end
function MissionEvents:EndOnPlayerLeftAirplane( func ) MissionEvents:RemoveListener(MissionEvents._playerLeftUnitHandlers, func) end

function MissionEvents:OnPlayerEnteredHelicopter( func, insertFirst ) 
    MissionEvents:AddListener(MissionEvents._playerEnteredUnitHandlers, 
        function( event )
            if (event.IniUnit:IsHelicopter()) then
                func( event )
            end
        end,
        nil,
        insertFirst)
end
function MissionEvents:EndOnPlayerEnteredHelicopter( func ) MissionEvents:RemoveListener(MissionEvents._playerEnteredUnitHandlers, func) end

function MissionEvents:OnPlayerLeftHelicopter( func, insertFirst ) 
    MissionEvents:AddListener(MissionEvents._playerLeftUnitHandlers, 
        function( event )
            if (event.IniUnit:IsHelicopter()) then
                func( event )
            end
        end,
        nil,
        insertFirst)
end
function MissionEvents:EndOnPlayerLeftHelicopter( func ) MissionEvents:RemoveListener(MissionEvents._playerLeftUnitHandlers, func) end

function MissionEvents:OnGroupDiverted( func, insertFirst ) 
    MissionEvents:AddListener(MissionEvents._groupDivertedHandlers, 
        func,
        nil,
        insertFirst) 
end
function MissionEvents:EndOnGroupDiverted( func ) MissionEvents:RemoveListener(MissionEvents._groupDivertedHandlers, func) end


_onDivertFunc = function( controllable, route ) -- called by Divert()
    MissionEvents:Invoke(MissionEvents._groupDivertedHandlers, { Controllable = controllable, Route = route })
end

--------------------------------------------- [[ TRIGGER ZONES ]] ---------------------------------------------

TRIGGER_ZONE_EVENT_TYPE = {
    Enters = 1,
    Inside = 2,
    Left = 3,
}

TriggerZoneOptions = {
    Interval = 4,
    Coalitions = nil,
    IncludeZoneNamePattern = nil,
    ExcludeZoneNamePattern = nil
}

function TriggerZoneOptions:New()
    return routines.utils.deepCopy(TriggerZoneOptions)
end


function TriggerZoneOptions:WithIncludeZoneNames( pattern )
    if (type(pattern) ~= "string") then error("Zone name pattern must be string") end
    if (ExcludeZoneNamePattern ~= nil) then error("ExcludeZoneNamePattern was already set. Use one or the other, not both") end
    self.IncludeZoneNamePattern = pattern
    return self
end

function TriggerZoneOptions:WithExcludedZoneNames( pattern )
    if (type(pattern) ~= "string") then error("Zone name pattern must be string") end
    if (IncludeZoneNamePattern ~= nil) then error("IncludeZoneNamePattern was already set. Use one or the other, not both") end
    self.ExcludeZoneNamePattern = pattern
    return self
end

function TriggerZoneOptions:WithCoalitions( coalitions )
    if (coalitions == nil) then error("Coalitions must be assigned") end
    if (type(coalitions) == string) then coalitions = { coalitions } end
    self.Coalitions = coalitions
    return self
end

local _triggerZoneUnitHandlers = {
    isMonitoring = false,
    unitEnters = {},
    unitInside = {},
    unitLeft = {},
    groupEnters = {},
    groupInside = {},
    groupLeft = {},
}
   
local _groupEvents = {
    -- [zoneName] = { entered = {}, inside = {}, left = {} }
}

function _groupEvents:IsHandled( event )
    local zone = event.Zone
    local group = event.Group
    local zoneTable = self[zone:GetName()]
    if (zoneTable == nil) then return false end
    local groupName = group:GetName()
    if (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Enters) then
        return zoneTable.entered[groupName] ~= nil 
    end
    if (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Inside) then
        return zoneTable.inside[groupName] ~= nil 
    end
    if (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Left) then
        return zoneTable.left[groupName] ~= nil 
    end
end

function _groupEvents:SetHandled( event )
    local zone = event.Zone
    local group = event.Group
    local zoneTable = self[zone:GetName()]
    if (zoneTable == nil) then 
        zoneTable = { entered = {}, inside = {}, left = {} }
        _groupEvents[zone:GetName()] = zoneTable
    end
    local groupName = group:GetName()
    if (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Enters) then
        zoneTable.entered[groupName] = true
    elseif (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Inside) then
        zoneTable.inside[groupName] = true
    elseif (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Left) then
        zoneTable.left[groupName] = true
    end
end

local function triggerZoneEventDispatcher( event )

    local group = event.Group
    if (group:IsPartlyOrCompletelyInZone(event.Zone)) then
        local function invokeGroupLeft( group )
            -- there are other units remaining in the zone so we're skipping this event
            return 
        end
        for k, handler in pairs(_triggerZoneUnitHandlers.groupLeft) do
            local groupEvent = routines.utils.deepCopy(event)
            args.Group = group
            args[Unit] = nil
            _groupEvents:SetHandled( event )
            handler( groupEvent )
        end
    end

    local function invokeGroupInside( group )
        for k, handler in pairs(_triggerZoneUnitHandlers.groupInside) do
            local groupEvent = routines.utils.deepCopy(event)
            args.Group = group
            args[Unit] = nil
            _groupEvents:SetHandled( event )
            handler( groupEvent )
        end
    end

    local function invokeGroupEnters( group )
        for k, handler in pairs(_triggerZoneUnitHandlers.groupEnters) do
            local groupEvent = routines.utils.deepCopy(event)
            args.Group = group
            args[Unit] = nil
            _groupEvents:SetHandled( event )
            handler( groupEvent )
            -- also, always trigger the 'group inside' event ...
            invokeGroupInside(event)
        end
    end

    if (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Enters) then
        local group = event.Unit:GetGroup()
        if (#_triggerZoneUnitHandlers.groupEnters > 0 and not _groupEvents:IsHandled( event )) then
            invokeGroupEnters( group )
        end
        for k, v in pairs(_triggerZoneUnitHandlers.unitEnters) do
            v.handler( event )
        end
    end

    if (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Inside) then
        local group = event.Unit:GetGroup()
        if (#_triggerZoneUnitHandlers.groupInside > 0 and not _groupEvents:IsHandled( event )) then
            invokeGroupInside( group )
        end
        for k, v in pairs(_triggerZoneUnitHandlers.unitInside) do
            v.handler( event )
        end
    end

    if (event.EventType == TRIGGER_ZONE_EVENT_TYPE.Left) then
        local group = event.Unit:GetGroup()
        if (#_triggerZoneUnitHandlers.groupLeft > 0 and not _groupEvents:IsHandled( event )) then
            invokeGroupLeft( group )
        end
        for k, v in pairs(_triggerZoneUnitHandlers.unitLeft) do
            v.handler( event )
        end
    end
end

local _triggerZoneUnitsInfo = {}

function MonitorTriggerZones( options )

   if (_triggerZoneUnitHandlers.isMonitoring) then error("Trigger zones are already monitored for events") end
    _triggerZoneUnitHandlers.isMonitoring = true
    options = options or TriggerZoneOptions
    local handler = triggerZoneEventDispatcher

    local function timeCallback()
        local timestamp = UTILS.SecondsOfToday()
        -- todo Consider some filtering mechanism to avoid scanning TZ's that are intended for other purposes
        for zoneName, zone in pairs(_DATABASE.ZONES) do
            local ignoreZone = false

            if (options.IncludeZoneNamePattern ~= nil and not string.find(zoneName, options.IncludeZoneNamePattern)) then --  not string.match(zoneName, options.IncludeZoneNamePattern)) then
                -- Debug("---> Filters out zone " .. zoneName .. " (does not match pattern '".. options.IncludeZoneNamePattern .."')")
                ignoreZone = true
            elseif (options.ExcludeZoneNamePattern ~= nil and string.match(zoneName, options.ExcludeZoneNamePattern)) then
                -- Debug("---> Filters out zone " .. zoneName .. " (matches pattern '".. options.ExcludeZoneNamePattern .."')")
                ignoreZone = true
            end
                                        
            if (not ignoreZone) then
                local unitsInZone = SET_UNIT:New():FilterZones({ zone })--:FilterCategories({ "plane" })
                if (coalitions ~= nil) then
                    unitsInZone:FilterCoalitions(coalitions)
                end
                local units = unitsInZone:FilterActive():FilterOnce()
                local unhandledUnits = nil
                local zoneInfo = _triggerZoneUnitsInfo[zoneName]
                if (zoneInfo ~= nil) then
                    unhandledUnits = routines.utils.deepCopy(routines.utils.deepCopy(zoneInfo))
                end
                units:ForEach(
                    function(unit)
                        local unitName = unit:GetName()
                        local handlerArgs = { 
                            Zone = zone, 
                            ZoneName = zoneName,
                            Unit = unit, 
                            Group = unit:GetGroup(),
                            Time = timestamp,
                            EntryTime = timestamp,
                            EventType = nil
                        }
                        if (zoneInfo == nil) then
                            -- unit has entered zone ...
                            zoneInfo = { [unitName] =  { unit = unit, entryTime = timestamp } }
                            _triggerZoneUnitsInfo[zoneName] = zoneInfo
                            handlerArgs.EventType = TRIGGER_ZONE_EVENT_TYPE.Entered
                            Debug("---> MonitorTriggerZones-" .. zoneName .." :: unit name " .. unitName .. " :: ENTERED")
                        elseif (zoneInfo[unitName] == nil) then
                            Debug("---> MonitorTriggerZones-" .. zoneName .." :: unit name " .. unitName .. " :: ENTERED")
                            handlerArgs.EventType = TRIGGER_ZONE_EVENT_TYPE.Entered
                            zoneInfo[unitName] = { unit = unit, entryTime = timestamp }
                        else
                            local unitInfo = zoneInfo[unitName]
                            handlerArgs.EventType = TRIGGER_ZONE_EVENT_TYPE.Inside
                            handlerArgs.EntryTime = unitInfo.entryTime
                            unhandledUnits[unitName] = nil
                            --Debug("---> MonitorTriggerZones-" .. zoneName .." :: unit name " .. unitName .. " :: INSIDE")
                        end
                        handler( handlerArgs )
                    end)
    
                if (unhandledUnits ~= nil) then
                    for k, v in pairs(unhandledUnits) do
                        -- unit has left the zone 
                        local unitInfo = zoneInfo[k]
                        local handlerArgs = { 
                            Zone = zone, 
                            Unit = unitInfo.unit,
                            Time = timestamp,
                            EventType = TRIGGER_ZONE_EVENT_TYPE.Left,
                            EntryTime = unitInfo.entryTime
                        }
                        --Debug("---> MonitorTriggerZones-" .. zoneName .." :: unit name " .. k .. " :: LEFT")
                        handler( handlerArgs )
                        zoneInfo[k] = nil
                    end
                end
            end
        end
        _groupEvents = {}

    end

    local interval = options.Interval or TriggerZoneOptions.Interval
    TIMER:New(timeCallback):Start(interval, interval)
end

function OnUnitEntersTriggerZone( callback, data )
    if (not _triggerZoneUnitHandlers.isMonitoring) then error( "Please start monitoring trigger zones for events first (call MonitorTriggerZones once)" ) end
    table.insert(_triggerZoneUnitHandlers.unitEnters, { handler = callback, data = data })
end

function OnUnitInsideTriggerZone( callback, data )
    if (not _triggerZoneUnitHandlers.isMonitoring) then error( "Please start monitoring trigger zones for events first (call MonitorTriggerZones once)" ) end
    table.insert(_triggerZoneUnitHandlers.unitInside, { handler = callback, data = data })
end

function OnUnitLeftTriggerZone( callback, data )
    if (not _triggerZoneUnitHandlers.isMonitoring) then error( "Please start monitoring trigger zones for events first (call MonitorTriggerZones once)" ) end
    table.insert(_triggerZoneUnitHandlers.unitLeft, { handler = callback, data = data })
end

function OnGroupEntersTriggerZone( callback, data )
    if (not _triggerZoneUnitHandlers.isMonitoring) then error( "Please start monitoring trigger zones for events first (call MonitorTriggerZones once)" ) end
    table.insert(_triggerZoneUnitHandlers.groupEnters, { handler = callback, data = data })
end

function OnGroupInsideTriggerZone( callback, data )
    if (not _triggerZoneUnitHandlers.isMonitoring) then error( "Please start monitoring trigger zones for events first (call MonitorTriggerZones once)" ) end
    table.insert(_triggerZoneUnitHandlers.groupInside, { handler = callback, data = data })
end

function OnGroupLeftTriggerZone( callback, data )
    if (not _triggerZoneUnitHandlers.isMonitoring) then error( "Please start monitoring trigger zones for events first (call MonitorTriggerZones once)" ) end
    table.insert(_triggerZoneUnitHandlers.groupLeft, { handler = callback, data = data })
end

Trace("DCAF.Core was loaded")
