DCAFCore = {
    Trace = true,
    TraceToUI = false, 
    Debug = false,
    DebugToUI = false, 
    WaypointNames = {
        RTB = '_rtb_',
        Divert = '_divert_',
    }
}

function isString( value ) return type(value) == "string" end
function isNumber( value ) return type(value) == "number" end
function isTable( value ) return type(value) == "table" end
function isClass( value, class ) return isTable(value) and value.ClassName == class end
function isUnit( value ) return isClass(value, "UNIT") end
function isGroup( value ) return isClass(value, "GROUP") end

FeetPerNauticalMile = 6076.1155
MetersPerNauticalMile = UTILS.NMToMeters(1)

function NauticalMilesToMeters( nm )
    if (not isNumber(nm)) then error("Expected 'nm' to be number") end
    return MetersPerNauticalMile * nm
end

function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
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
    local timer = TIMER:New(function() 
        userFunction(data)
    end):Start(seconds, 0, seconds)
end

local _missionStartTime = UTILS.SecondsOfToday()

function MissionClock( short )
    if (short == nil) then
        short = true
    end
    return UTILS.SecondsToClock(UTILS.SecondsOfToday(), short)
end

function MissionTime()
    return UTILS.SecondsOfToday() - _missionStartTime
end

function MissionClockTime( short )
    if (short == nil) then
        short = true
    end
    return UTILS.SecondsToClock( MissionTime(), short )
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
  
function getControllable( source )
    local unit = getUnit(source)
    if (unit ~= nil) then 
      return unit end
    
    local group = getGroup(source)
    if (group ~= nil) then 
      return group end

    return nil
end

function GetOtherCoalitions( controllable )
    local group = getGroup( controllable )
    if (group == nil) then
        Warning("GetOtherCoalitions :: group not found: "..Dump(controllable).." :: EXITS")
        return
    end

    local coalition = group:GetCoalition()
    if (coalition == "red" ) then
        return { "blue", "neutral" }
    elseif coalition == "blue" then
        return { "red", "neutral" }
    elseif coalition == "neutral" then
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
function GetGroupSuperiority( a, b )
    local groupA = getGroup(a)
    local groupB = getGroup(b)
    if (groupA == nil) then
        if (groupB == nil) then return 0 end
        return 1
    end

    if (groupB == nil) then
        return -1
    end

    -- todo consider more interesting ways to compare groups relative superiority/inferiority
    local aSize = groupA:CountAliveUnits()
    local bSize = groupB:CountAliveUnits()
    if (aSize > bSize) then return -1 end
    if (aSize < bSize) then return 1 end
    return 0
end

local NoMessage = "_none_"

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
      local group = getGroup(recipient)
      if (group == nil) then
          Warning("MessageTo-?"..recipient.." :: Group could not be resolved :: EXITS")
          return
      end
      local group = GROUP:FindByName( recipient )
      if (group ~= nil) then
          MessageTo( group, message, duration )
          return
      end
    
      local unit = UNIT:FindByName( recipient )
      if (unit ~= nil) then
          MessageTo( unit, message, duration )
          return
      end
  end

  if (type(recipient) == "table") then
      if (recipient.ClassName == "UNIT") then
          -- MOOSE doesn't support sending messages to units; send to group and ignore other units from same group ...
          recipient = recipient:GetGroup()
          MessageTo( group, message, duration )
    end
    if (recipient.ClassName == "GROUP") then
        MESSAGE:New(message, duration):ToGroup(recipient)
        Trace("MessageTo :: Group "..recipient.GroupName.." :: '"..message.."'")
        return
    end
    if (recipient.ClassName == "CLIENT") then
        MESSAGE:New(message, duration):ToClient(recipient)
        Trace("MessageTo :: Client "..recipient:GetName().." :: "..message.."'")
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
          Debug("MessageTo-"..recipient.." :: "..message)
          MESSAGE:New(message, duration):ToClient(unit)
          return
      end
  end

  if (pcall(SendMessageToClient(recipient))) then return end
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
  
function GetAltitudeAsAngelsOrCherubs( controllable ) 
    controllable = getControllable( controllable )
    if (controllable == nil) then error( "Could not resolve controllable" ) end
    local feet = UTILS.MetersToFeet( controllable:GetCoordinate().y )
    if (feet >= 1000) then
        local angels = feet / 1000
        return "angels " .. tostring(UTILS.Round( angels, 0 ))
    end

    local cherubs = feet / 100
    return "cherubs " .. tostring(UTILS.Round( cherubs, 0 ))
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
        Debug("DirectTo-" .. group.GroupName .." :: cannot resolved steerpoint: "..Dump(steerpoint).." :: EXITS")
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

    local off = calcGroupOffset(followerGrp, leaderGrp)
    if (offset ~= nil) then
        off.x = offset.x or off.x
        off.y = offset.y or off.y
        off.z = offset.z or off.z
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

local deep = DumpPrettyOptions:New():Deep()
local nisse_grp = getGroup(controllable)
local nisse_route = nisse_grp:TaskRoute()
Debug("RTB :: nisse_route: " .. DumpPretty(nisse_route, deep))

    local steerpointName = steerpointName or DCAFCore.WaypointNames.RTB
    local route = RouteDirectTo(controllable, steerpointName)

Debug("RTB :: route: " .. DumpPretty(route, deep))

    return SetRoute( controllable, route )
end

function GetDivertWaypoint( group ) 
    return FindWaypointByName( group, DCAFCore.WaypointNames.Divert ) ~= nil
end

function CanDivert( group ) 
    return GetDivertWaypoint( group ) ~= nil
end

function Divert( controllable, steerpointName )
    local steerpointName = steerpointName or DCAFCore.WaypointNames.Divert
    local divertRoute = RouteDirectTo(controllable, steerpointName)
    return SetRoute( controllable, divertRoute )
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
            --ROTEvadeFire( controllable )
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
            --group:OptionROEWeaponFree()
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

function TaskAttackGroup( attacker, target )

    local ag = getGroup(attacker)
    if (ag == nil) then
        Warning("TaskAttackGroup-? :: cannot resolve attacker group "..Dump(attacker) .." :: EXITS")
    end
    local tg = getGroup(target)
    if (tg == nil) then
        Warning("TaskAttackGroup-? :: cannot resolve target group "..Dump(tg) .." :: EXITS")
    end

    if (not ag:OptionROEOpenFirePossible()) then
        ROEOpenFire(ag)
    end
    ag:SetTask(ag:TaskAttackGroup(tg))
    Trace("TaskAttackGroup-"..ag.GroupName.." :: attacks group "..tg.GroupName..":: DONE")

end

--------------------------------------------- [[ MISSION EVENTS ]] ---------------------------------------------

MissionEvents = {
    _groupBirthHandlers = {},
    _unitDeadHandlers = {}
}

local isMissionEventsListenerRegistered = false
local _e = {}

function _e:onEvent( event )
    local function invokeHandlers( handlers, data )
        for _, handler in ipairs(handlers) do
            handler( data )
        end
    end

    if (event.id == world.event.S_EVENT_BIRTH and event.IniGroup and #MissionEvents._groupBirthHandlers > 0) then
        invokeHandlers( MissionEvents._groupBirthHandlers, { IniGroupName = event.IniGroup.GroupName } )
        return
    end

    if (event.id == world.event.S_EVENT_DEAD and event.IniUnit and #MissionEvents._unitDeadHandlers > 0) then
        invokeHandlers( MissionEvents._unitDeadHandlers, { IniUnitName = event.IniUnit.UnitName, IniGroupName=event.IniUnit.GroupName } )
        return
    end
end

local function registerEventListener( listeners, func)
    table.insert(listeners, func)
    if (isMissionEventsListenerRegistered) then
        return 
    end
    isMissionEventsListenerRegistered = true
    world.addEventHandler(_e)
end

function MissionEvents:OnGroupBirth( func ) registerEventListener(MissionEvents._groupBirthHandlers, func) end
function MissionEvents:OnUnitDead( func ) registerEventListener(MissionEvents._unitDeadHandlers, func) end


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

    local function invokeGroupLeft( group )
        if (group:IsPartlyOrCompletelyInZone(event.Zone)) then
            -- there are other units remaining in the zone soe we're sjipping this event
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
            if (options.IncludeZoneNamePattern ~= nil and not string.match(zoneName, options.IncludeZoneNamePattern)) then
                --Debug("---> Filters out zone " .. zoneName .. " (does not match pattern '".. options.IncludeZoneNamePattern .."'")
                ignoreZone = true
            elseif (options.ExcludeZoneNamePattern ~= nil and string.match(zoneName, options.ExcludeZoneNamePattern)) then
                --Debug("---> Filters out zone " .. zoneName .. " (matches pattern '".. options.ExcludeZoneNamePattern .."'")
                ignoreZone = true
            end
                                        
            if (not ignoreZone) then
                local unitsInZone = SET_UNIT:New():FilterZones({ zone }):FilterCategories({ "plane" })
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
                            Unit = unit, 
                            Time = timestamp,
                            EntryTime = timestamp,
                            EventType = nil
                        }
                        if (zoneInfo == nil) then
                            -- unit has entered zone ...
                            zoneInfo = { [unitName] =  { unit = unit, entryTime = timestamp } }
                            _triggerZoneUnitsInfo[zoneName] = zoneInfo
                            handlerArgs.EventType = TRIGGER_ZONE_EVENT_TYPE.Entered
                            --Debug("---> MonitorTriggerZones-" .. zoneName .." :: unit name " .. unitName .. " :: ENTERED")
                        elseif (zoneInfo[unitName] == nil) then
                            --Debug("---> MonitorTriggerZones-" .. zoneName .." :: unit name " .. unitName .. " :: ENTERED")
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