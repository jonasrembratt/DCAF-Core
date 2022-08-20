local function isString( value ) return type(value) == "string" end
local function isNumber( value ) return type(value) == "number" end
local function isTable( value ) return type(value) == "table" end
local function isUnit( value ) return isTable(value) and value.ClassName == "UNIT" end
local function isGroup( value ) return  isTable(value) and value.ClassName == "GROUP" end

local feetPerNauticalMile = 6076.1155

AirPolicing = {
  Debug = false,
  DebugToUI = false,

  -- Obey/disobey patterns are mutually exclusive; if one is set the other should be set to nil
  -- (using the AirPolicing:WithObeyPattern and AirPolicing:WithDisobeyPattern functions will ensure this behavior)
  -- If both obey and disobey patterns are set, only the ObeyPattern is honored (meaning all groups not matching the ObeyPattern) will
  -- disobey the interceptor
  DefaultInterceptedReaction = nil,
  Assistance = {
    IsAllowed = true,
    Duration = 12, -- the duration (seconds) for all assistance messages
    ApproachInstruction = 
      "Approach slowly and non-aggressively, especially with civilian aircraft",
    EstablishInstruction = 
      "Lead continues to a position to the side and slightly above the lead A/C\n"..
      "Wing takes up a watch position behind, keeping watch and ready to engage if needed",
    SignalInstruction = 
      "Lead rocks wings (daytime) or flashes nav lights in irregular pattern to signal "..
      "'follow me' or 'deviate now!'",
    ObeyingInstruction = 
      "You now lead the flight! Please divert it to a location or airport "..
      "and order it to land, or continue its route from that location (see menus)",
    DisobeyingInstruction = 
      "The flight doesn't seem to obey your orders!",
    CancelledInstruction = 
      "Interceopt was cancelled. Please use menu for further airspace policing",
    LandHereOrderedInstruction =
      "The flight leaves your formation to land at %s. Good job!",
    DivertNowOrderedInstruction =
      "The flight now resumes its route from this location. Good job!"
  },
  LandingIntruders = {}
}

function Debug( message )
  BASE:E(message)
  if (AirPolicing.DebugToUI) then
    MESSAGE:New("DBG: "..message):ToAll()
  end
end


local NoMessage = "_none_"

local InterceptionDefault = {
  divertToWaypointName = '_divert_',
  interceptReactionQualifier = "icpt"
}

INTERCEPT_REACTION = {
  None =   "none", -- icpt=none (disobeys orders and just continues)
  Divert = "divt", -- icpt=divt (if flight has InterceptionDefault.divertToWaypointName) in route it goes DIRECT; otherwise RTB (back to 1st wp)
  Land =   "land", -- icpt=land (lands at nearest friendly airbase)
  Follow = "folw"  -- icpt=folw (follows interceptor)
}

function INTERCEPT_REACTION:IsValid( reaction )
  if (not isString(reaction)) then 
    return false
  end

  reaction = string.lower(reaction)
  for k, v in pairs(INTERCEPT_REACTION) do
    if (reaction == v) then 
      return true 
    end
  end
  return false
end

function AirPolicing:RegisterLanding( group )
    self.LandingIntruders[group.GroupName] = group
end

function AirPolicing:IsLanding( group )
  return self.LandingIntruders[group.GroupName] ~= nil
end

_ActiveIntercept = {
  intruder = nil,
  interceptor = nil,
  cancelFunction = nil
}

function _ActiveIntercept:New( intruder, interceptor )
  local ai = routines.utils.deepCopy(_ActiveIntercept)
  ai.intruder = intruder
  ai.interceptor = interceptor
  return ai
end

function _ActiveIntercept:Cancel()
  local ai = self
  if (ai.cancelFunction ~= nil) then
    ai.cancelFunction()
  end
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
    indentlvl :: (int; default = 0) Specifies indentation level 
    indentcount :: (int; default = 2) Specifies indentation size (no. of spaces)
  }
]]--
local DumpPrettyDefaults = {
  asJson = false,
  indentSize = 2
}
function DumpPretty(value, options)

  options = options or DumpPrettyDefaults
  local idtSize = options.indentSize or DumpPrettyDefaults.indentSize
  local asJson = options.asJson or DumpPrettyDefaults.asJson
 
  local function dumpRecursive(value, ilvl)
    if type(value) ~= 'table' then
      if (isString(value)) then
        return '"' .. tostring(value) .. '"'
      end
      return tostring(value)
    end

    local s = '{\n'
    local indent = mkIndent(ilvl * idtSize)
    for k,v in pairs(value) do
      if (asJson) then
        s = s .. indent..'"'..k..'"'..' : '
      else
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. indent.. '['..k..'] = '
      end
      s = s .. dumpRecursive(v, ilvl+1, idtSize) .. ',\n'
    end
    return s .. mkIndent((ilvl-1) * idtSize) .. '}'
  end

  return dumpRecursive(value, 0)

end

function DumpPrettyJson(value, options)
  options = options or DumpPrettyDefaults
  options.asJson = true
  return DumpPretty(value, options)
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
  if (isGroup(source)) then return source end
  if (isUnit(source)) then return source:GetGroup() end
  if (not isString(source)) then return nil end

  local group = GROUP:FindByName( source )
  if (group ~= nil) then 
    return group end

  local unit = UNIT:FindByName( source )
  if (unit ~= nil) then 
     return unit:GetGroup() end
  return nil
end

function getControllable( source )
  local unit = getUnit(source)
  if (unit ~= nil) then return unit end
  
  local group = getGroup(source)
  if (group ~= nil) then return group end

  return nil
end

function DistanceToStringA2A( meters, estimated )
  
  if (not isNumber(meters)) then error( "<meters> must be a number" ) end

  local feet = UTILS.MetersToFeet( meters )
  if (feet < feetPerNauticalMile / 2) then
    if (estimated or false) then
      feet = EstimatedDistance( feet )
    end
    return tostring( math.modf(feet) ) .. " feet"
  end
  local nm = UTILS.Round( feet / feetPerNauticalMile, 1)
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

function GetClockPosition( heading, bearing )
  return tostring(UTILS.Round(((-heading + bearing) % 360) / 30, 0)) .. " o'clock"
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

function AirPolicing:SetDefaultInterceptedReaction( reaction )
  if (not INTERCEPT_REACTION:IsValid( reaction )) then
    Debug("AirPolicing:WithDefaultInterceptReaction :: not a valid raction: "..Dump(reaction).." :: EXITS")
    return
  end
  AirPolicing.DefaultInterceptedReaction = reaction
  Debug("AirPolicing:WithDefaultInterceptReaction :: set to " .. reaction) 
end

function CanBeIntercepted( controllable )
  local group = getGroup(controllable)
  if (group == nil) then
      Debug("CanBeIntercepted-?  :: group cannot be resolve :: EXITS")
     return false
  end
  local leadUnit = group:GetUnit(1)
  if (leadUnit:IsPlayer()) then  -- TOTEST -- this needs tp be testen on MP server
    Debug("CanBeIntercepted  :: Lead unit " .. leadUnit:GetName() .. " is player (cannot be intercepted)")
    return false 
  end 
  if AirPolicing:IsLanding(group) then return false end
  return true
end

function GetInterceptedReaction( controllable )
  local unit = getUnit(controllable)
  local group = nil
  if (unit ~= nil) then
    group = unit:GetGroup()
  end
  group = group or getGroup( controllable )
  if (group == nil) then
    Debug("GetInterceptedReaction  :: cannot resolve group :: EXITS")
    return false
  end

  local default = AirPolicing.DefaultInterceptedReaction or INTERCEPT_REACTION.None
  local s = group.GroupName
  local at = string.find(s, InterceptionDefault.interceptReactionQualifier)
  if (at == nil) then
    Debug("GetInterceptedReaction-".. s .." :: reaction not set; resolves default: ".. default)
    return default
  end
  local len = string.len(InterceptionDefault.interceptReactionQualifier)
  local reaction = string.sub(s, at+len+1, at+len+4)

  reaction = string.lower(reaction)
  for k,v in pairs(INTERCEPT_REACTION) do
    if (v == reaction) then
      return v
    end
  end

  Debug("GetInterceptedReaction-".. s .." :: unknown reaction: ".. reaction or "nil" .." :: default reaction used: " .. default)
  return default
end

--[[
OnInsideGroupZone
  Monitors a group and scans a zone* around it for other groups aproaching it

Parameters
  groupName :: (string) Name of the group to be monitored
  callback :: function to be invoked when group is detected inside the zone

Callback method parameters
  (object)
  {
    units :: (table with strings) Names of group(s) detected inside the zone
    monitoredGroup :: (string) Name of monitored group (== 'groupName' parameter)
    time :: (integer) The time (seconds since game time midnight) of the detection
    stop :: (boolean, default=true) When set the monitoring will end after the latest callback invocation (can be set by calback function)
  }
]]--
OnInsideGroupZoneDefaults = 
{
  monitoredUnitNo = 1,
  zoneRadius = 250,
  zoneOffset = {
    relative_to_unit = true,
    dx = -100,   -- longitudinal offset (positive = in front; negative = to the back)
    dy = 0      -- latitudinal offset (positive = right; negative = left)
  },
  coalitions = { "blue" },
  messageToDetected = NoMessage,
  messageToDetectedDuration = 30,
  interval = 5
}

--local ignoreMessagingGroups = {}
--[[ 
Sends a simple message to groups, clients or lists of groups or clients
]]--
function MessageTo( recipient, message, duration )

  if (recipient == nil) then
    Debug("MessageTo :: Recipient name not specified :: EXITS")
    return
  end
  if (message == nil) then
    Debug("MessageTo :: Message was not specified :: EXITS")
    return
  end
  duration = duration or 5

  if (isString(recipient)) then
    local group = getGroup(recipient)
    if (group == nil) then
      Debug("MessageTo-?"..recipient.." :: Group could not be resolved :: EXITS")
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
      --local isIgnored = ignoreMessagingGroups[group.GroupName] ~= nil
      --if (not isIgnored) then
        MessageTo( group, message, duration )
        --ignoreMessagingGroups[group.GroupName] = group.GroupName
      --end
      --return
    end
    if (recipient.ClassName == "GROUP") then
      --local isIgnored = ignoreMessagingGroups[recipient.GroupName] ~= nil
      --if (isIgnored) then
        --Debug("MessageTo :: Group "..recipient.GroupName.." is ignored")
        --return
      --end
      MESSAGE:New(message, duration):ToGroup(recipient)
      Debug("MessageTo :: Group "..recipient.GroupName.." :: '"..message.."'")
      return
    end
    if (recipient.ClassName == "CLIENT") then
      MESSAGE:New(message, duration):ToClient(recipient)
      Debug("MessageTo :: Client "..recipient:GetName().." :: "..message.."'")
      return
    end

    for k, v in pairs(recipient) do
      MessageTo( v, message, duration )
    end
    --ignoreMessagingGroups = {}
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
  Debug("MessageTo-"..recipient.." :: Recipient not found")

end


function OnInsideGroupZone( groupName, callback, options )
  
  if ( groupName == nil) then
    Debug("OnInsideGroupZone-? :: Group name missing :: EXITS")
    return 
  end
  if (callback == nil) then 
    Debug("OnInsideGroupZone-"..groupName.." :: missing callback function :: EXITS")
    return 
  end
  local monitoredGroup = GROUP:FindByName( groupName )
  if (monitoredGroup == nil) then 
    Debug("OnInsideGroupZone-"..groupName.." :: intruder group not found :: EXITS")
    return 
  end

  options = options or OnInsideGroupZoneDefaults
  local zoneRadius = options.zoneRadius or OnInsideGroupZoneDefaults.zoneRadius
  local zoneOffset = options.zoneOffset or OnInsideGroupZoneDefaults.zoneOffset
  local coalitions = options.coalitions or OnInsideGroupZoneDefaults.coalitions
  local interval = options.interval or OnInsideGroupZoneDefaults.interval
  
  local unitNo = options.monitoredUnitNo or OnInsideGroupZoneDefaults.monitoredUnitNo
  local monitoredUnit = monitoredGroup:GetUnit(unitNo)
  if (monitoredUnit == nil) then 
    Debug("OnInsideGroupZone-"..groupName.." :: monitored group unit #"..tostring(unitNo).." not found :: EXITS")
    return 
  end

  local timer = nil
  local stopTimerAfter = 0
  local interceptingUnit = nil
  local monitoredUnitName = monitoredUnit:GetName()
  local interceptZone = ZONE_UNIT:New(monitoredUnitName.."-closing", monitoredUnit, zoneRadius, zoneOffset)
  local ar = options._activeIntercept
  --[[ todo Deal with unit getting killed (end monitoring)
  local groupDeadEvent = EVENT:OnEventForUnit( 
    monitoredUnitName,
    function()
      Debug("OnInsideGroupZone-"..groupName.." :: Monitored unit () was killed :: EXITS")
      stopTimerAfter = interval
    end
    )
  ]]--

  Debug("OnInsideGroupZone-"..groupName.." :: BEGINS :: "..string.format("zoneRadius=%d; interval=%d", zoneRadius, interval))

  local function DetectUnits()

    monitoredUnit = monitoredGroup:GetUnit(unitNo)
    if (monitoredUnit == nil) then
      Debug("OnInsideGroupZone-"..groupName.." :: monitored group unit #"..tostring(unitNo).." not found (might be dead) :: Timer stopped!")
      timer:Stop()      
      return
    end

    local units = SET_UNIT:New()
      :FilterCategories({ "plane" })
      :FilterCoalitions( coalitions )
      :FilterZones( { interceptZone } )
      :FilterActive()
      :FilterOnce()
    local timestamp = UTILS.SecondsOfToday()
  
    --[[

    if the detected unit belongs to interceptor(s) coalition it will be included in the `units` set, so needs to be fitered out
    also, oddly enough, the above filtering doesn't exclude groups flying vertically outside the radius 
    (zone appears to be cylinder rather than orb, not sure if that's a MOOSE bug)
    so we need to filter those out manually 

    ]]--
    
    local pos = Unit.getByName(monitoredUnitName):getPoint()
    local monitoredUnitMSL = pos.y
    local detected = {}
    local count = 0

    units:ForEach(
      function(unit)
        if (groupName == unit:GetGroup().GroupName) then
          --Debug("OnInsideGroupZone-"..groupName.." :: filters out monitored group's units")
          return 
        end
        local unitName = unit:GetName()
        local pos = Unit.getByName(unitName):getPoint()
        local unitUnitMSL = pos.y
        local distance = math.abs(unitUnitMSL - monitoredUnitMSL)

        if (distance > zoneRadius) then 
          Debug("OnInsideGroupZone-"..unitName.." :: filters out "..unitName.." (vertically outside radius) :: EXITS")
          return 
        end
        count = count+1
        table.insert(detected, count, unit:GetName())
      end)

    if (stopTimerAfter > 0) then
      stopTimerAfter = stopTimerAfter - interval
      if (stopTimerAfter <= 0) then
        Debug("OnInsideGroupZone-"..groupName.." :: TIMER STOPPED")
        timer:Stop()
      end
      return
    end

    if (count > 0) then
      Debug("OnInsideGroupZone-"..groupName.." :: "..tostring(count).." units detected inside zone")
      local args = {
        units = detected,
        monitoredGroup = groupName,
        time = timestamp,
        stop = true  
      }
      callback( args )
      if (options.messageToDetected ~= NoMessage) then
        MessageTo( detected, options.messageToDetected, options.messageToDetectedDuration )
      end
      if (args.stop) then
        stopTimerAfter = interval
      end
    end

  end

  timer = TIMER:New(DetectUnits, interceptZone)
  timer:Start(interval, interval)
  if (ar ~= nil) then
    ar.cancelFunction = function() timer:Stop() end
  end

end

OnInterceptedDefaults = {
  interceptedUnitNo = 1,
  zoneRadius = 120,
  zoneOffset = {
    -- default intercept zone is 50 m radius, 55 meters in front of intruder aircraft
    relative_to_unit = true,
    dx = 75,   -- longitudinal offset (positive = in front; negative = to the back)
    dy = 0,    -- latitudinal offset (positive = right; negative = left)
    dz = 5     -- vertical offset (positive = up; negative = down)
  },
  coalitions = { "blue" },
  description = nil,
  delay = 4,         -- time (seconds) required for interceptor to be established in interceopt zone before interception is triggered
  interval = 2
}
function OnIntercepted( groupName, callback, options )

  if (groupName == nil) then
    Debug("OnIntercepted-? :: Group name missing :: EXITS")
    return 
  end
  if (callback == nil) then 
    Debug("OnIntercepted-"..groupName.." :: missing callback function :: EXITS")
    return 
  end
  local monitoredGroup = GROUP:FindByName( groupName )
  if (monitoredGroup == nil) then 
    Debug("OnIntercepted-"..groupName.." :: intruder group not found :: EXITS")
    return 
  end

  options = options or OnInterceptedDefaults
  local coalitions = options.coalitions or OnInterceptedDefaults.coalitions 
  local zoneRadius = options.zoneRadius or OnInterceptedDefaults.zoneRadius
  local delay = options.delay or OnInterceptedDefaults.delay
  local interval = options.interval or OnInterceptedDefaults.interval
  local description = options.description

  local unitNo = options.interceptedUnitNo or OnInterceptedDefaults.interceptedUnitNo
  local intruderUnit = monitoredGroup:GetUnit(unitNo) 
  if (intruderUnit == nil) then 
    Debug("OnIntercepted-"..groupName.." :: intruder group unit #"..tostring(unitNo).." not found :: EXITS")
    return 
  end
  local intruderUnitName = intruderUnit:GetName()

  local countIntercepts = 0
  local stopTimerAfter = 0
  local interceptorInfos = {} -- item structure = { establishedTimestamp=<seconds>, isDescriptionProvided=<bool> }
  local intruderName = monitoredGroup:GetName()
  local zoneOffset = options.zoneOffset or OnInterceptedDefaults.zoneOffset
  local interceptingUnit = nil
  local timer = nil

  Debug("OnIntercepted-"..groupName.." ::  zoneOffset = {dx = "..tostring(zoneOffset.dx)..", dy="..tostring(zoneOffset.dy)..", dz="..tostring(zoneOffset.dz).."}")

  local interceptZone = ZONE_UNIT:New(intruderUnitName.."-intercepted", intruderUnit, zoneRadius, zoneOffset)
  Debug("OnIntercepted-"..groupName.." :: BEGINS :: "..string.format("zoneRadius=%d; delay=%d; interval=%d, description=%s", zoneRadius, delay, interval, description or ""))
  
  local function FindInterceptors()

    intruderUnit = monitoredGroup:GetUnit(unitNo) 
    if (intruderUnit == nil) then
      Debug("OnIntercepted-"..groupName.." :: monitored group unit #"..tostring(unitNo).." not found (might be dead) :: Timer stopped!")
      timer:Stop()      
      return
    end

    local interceptors = SET_UNIT:New()
      :FilterCategories({ "plane" })
      :FilterCoalitions( coalitions )
      :FilterZones( { interceptZone } )
      :FilterActive()
      :FilterOnce()
    
    --[[

    if the intruder belongs to interceptor(s) coalition it will be included in the `interceptors` set, so needs to be fitered out
    also, oddly enough, the above filtering doesn't exclude groups flying vertically outside the radius 
    (zone appears to be cylinder rather than orb, not sure if that's a MOOSE bug)
    so we need to filter those out manually 

    ]]--
    
    local pos = Unit.getByName(intruderUnitName):getPoint()
    local monitoredUnitMSL = pos.y
    local timestamp = UTILS.SecondsOfToday()

    interceptors:ForEach(
      function(interceptor)
        if (groupName == interceptor:GetGroup().GroupName) then
          --Debug("OnIntercepted-"..groupName.." :: filters out intruder group units")
          return 
        end
        local interceptorName = interceptor:GetName()
        local pos = Unit.getByName(interceptorName):getPoint()
        local interceptorUnitMSL = pos.y
        local distance = math.abs(interceptorUnitMSL - monitoredUnitMSL)

        if (distance > zoneRadius) then 
          --Debug("OnIntercepted-"..groupName.." :: filters out "..interceptorName.." (vertically outside radius)")
          return 
        end
        local interceptorInfo = interceptorInfos[interceptorName]
        local timeEstablished = 0
        if (interceptorInfo == nil) then
          Debug("OnIntercepted-"..groupName.." :: "..interceptorName.." is established in intercept zone")
          if (description ~= nil) then
            MESSAGE:New(description, delay):ToUnit(interceptor)
            Debug("OnIntercepted-"..groupName.." :: description sent to "..interceptorName.." :: "..description)
          end
          interceptorInfo = { establishedTimestamp = timestamp, isDescriptionProvided = true }
          interceptorInfos[interceptorName] = interceptorInfo
        else
          timeEstablished = timestamp - interceptorInfo.establishedTimestamp
          Debug("OnIntercepted-"..groupName.." :: "..interceptorName.." remains in intercept zone :: time="..tostring(timeEstablished).."s")
        end
        if (timeEstablished >= delay) then
          interceptingUnit = interceptor
        end
      end,
      interceptors)

    if (stopTimerAfter > 0) then
      stopTimerAfter = stopTimerAfter - interval
      if (stopTimerAfter <= 0) then
        Debug("OnIntercepted-"..groupName.." :: TIMER STOPPED")
        timer:Stop()
        interceptorInfos = nil
      end
      return
    end

    if (interceptingUnit ~= nil) then
      stopTimerAfter = 3 -- seconds
      local result = {
        interceptedGroup = monitoredGroup.GroupName,
        interceptingUnit = interceptingUnit:GetName()
      }
      Debug("OnIntercepted-"..groupName.." :: Intercepted by "..interceptingUnit:GetName())
      callback( result )
    end
    
  end
  
  timer = TIMER:New(FindInterceptors, interceptZone)
  timer:Start(interval, interval)

end

OnShowOfForceDefaults =
{
  -- options
  radius = 150,            -- in meters, max distance between interceptor and intruder for show of force oto trigger
  minCount = 1,            -- number of show-of force buzzes needed to trigger 
  minSpeedKts = 350,       -- minimum speed (knots) for show of force to trigger
  coalitions = { "blue" }, -- only interceptors from this/these coalitions will be considered
  minTimeBetween = 30,     -- time (seconds) betwwen SOF, when minCount > 1
  interval = 2,            -- 
  description = nil        -- (string) when provided a message is sent to interceptor (describing the intruder)
}
function OnShowOfForce( groupName, callback, options ) --, radius, minCount, minSpeedKts, coalitions, minTimeBetween, interval)

  if (groupName == nil) then
    Debug("OnShowOfForce-? :: Group name missing :: EXITS")
    return 
  end
  local monitoredGroup = GROUP:FindByName( groupName )
  if (monitoredGroup == nil) then 
    Debug("OnShowOfForce-"..groupName.." :: Group not found :: EXITS")
    return 
  end
  if (callback == nil) then 
    Debug("OnShowOfForce-"..groupName.." :: missing callback function :: EXITS")
    return 
  end

  options = options or OnShowOfForceDefaults
  local countIntercepts = 0
  local Timer
  local stopTimerAfter = 0 
  local coalitions = options.coalitions or OnShowOfForceDefaults.coalitions
  local radius = options.radius or OnShowOfForceDefaults.radius
  local minSpeedKts = options.minSpeedKts or OnShowOfForceDefaults.minSpeedKts
  local minCount = options.minCount or OnShowOfForceDefaults.minCount
  local minTimeBetween = options.minTimeBetween or OnShowOfForceDefaults.minTimeBetween
  local interval = options.interval or OnShowOfForceDefaults.interval
  local description = options.description or OnShowOfForceDefaults.description

  Debug("OnShowOfForce-"..groupName.." :: BEGINS :: "..string.format("radius=%d; minSpeedKts=%d; minCount=%d, minTimeBetween=%d, description=%s", radius, minSpeedKts, minCount, minTimeBetween, description or ""))

  local intruderName = monitoredGroup:GetName()
  local interceptZone = ZONE_GROUP:New(intruderName, monitoredGroup, radius)
  local interceptorsInfo = {}

  --[[ "InterceptorInfo":
     {
        interceptor = "<group name>",  -- group name for interceptor performing SOF
        countSof = 0,                  -- counts no. of show-of-forces performed for intruder
        lastTimestamp = <timestamp>    -- used to calculate next SOF when more than one is required
     }
  ]]--

  function FindAircrafts()

    local interceptors = SET_GROUP:New()
      :FilterCategoryAirplane()
      :FilterCoalitions(coalitions)
      :FilterZones({interceptZone})
      :FilterActive()
      :FilterOnce()

    local timestamp = UTILS.SecondsOfToday()
    Debug("OnShowOfForce-"..groupName.." :: looks for interceptors (timestamp = "..tostring(timestamp)..") ...")

    -- if the intruder belongs to interceptor(s) coalition it will be included in the `interceptors` set, so needs to be fitered out
    -- also, oddly enough, the above filtering doesn't exclude groups flying vertically outside the radius
    -- (not sure if that's a MOOSE bug)
    -- so we need to filter those out manually 
    
    local intruderCoord = monitoredGroup:GetCoordinate()
    local foundInterceptor = nil
    
    interceptors:ForEachGroup(
      function(interceptor)
        
        function isTooEarly(Info)
          -- check if enought time have passed since last SOF
          local timeSinceLastSof = timestamp - (Info.lastTimeStamp or timestamp)
          if (timeSinceLastSof > minTimeBetween) then 
            return true
          end
          return false
        end

        if (groupName == interceptor.GroupName) then
          -- Debug("OnShowOfForce-"..groupName.." :: filters out intruder from interceptors")
          return 
        end

        local interceptorInfo = interceptorsInfo[interceptor.GroupName]
        if (interceptorInfo ~= nil and isTooEarly(interceptorInfo)) then
          Debug("OnShowOfForce-"..groupName.." :: filters out interceptor (SOF is too early)")
          return 
        end

        local velocityKts = interceptor:GetVelocityKNOTS()
        if (velocityKts < minSpeedKts) then
          Debug("OnShowOfForce-"..groupName.." :: filters out interceptor (too slow at "..tostring(velocityKts)..")")
          return
        end
        local interceptorCoord = interceptor:GetCoordinate()
        local distance = interceptorCoord:Get3DDistance(intruderCoord)
        if (distance > radius) then 
          Debug("OnShowOfForce-"..groupName.." :: filters out "..interceptor.GroupName.." (vertically outside radius)")
          return 
        end
        Debug("OnShowOfForce-"..groupName.." :: "..string.format("Interceptor %s", interceptor.GroupName))
        if (interceptorInfo == nil) then
          if (description ~= nil) then
            MESSAGE:New(description, delay):ToGroup(interceptor)
            Debug("OnIntercepted-"..groupName.." :: description sent to "..interceptor.GroupName.." :: "..description)
          end
          interceptorInfo = {
            interceptor = interceptor.GroupName,  -- group name for interceptor performing SOF
            countSof = 0,                         -- counts no. of show-of-forces performed for intruder
            lastTimestamp = timestamp             -- used to calculate next SOF when more than one is required
          }
          interceptorsInfo[interceptor.GroupName] = interceptorInfo
        end
        interceptorInfo.countSof = interceptorInfo.countSof+1
        Debug("OnShowOfForce-"..groupName.." :: Interceptor "..interceptor.GroupName.." SOF count="..tostring(interceptorInfo.countSof))
        if (interceptorInfo.countSof >= minCount) then
          foundInterceptor = interceptor.GroupName
        end
      end)
  
    if (stopTimerAfter > 0) then
      stopTimerAfter = stopTimerAfter - interval
      if (stopTimerAfter <= 0) then
        Debug("OnShowOfForce-"..groupName.." :: TIMER STOPPED")
        Timer:Stop()
        interceptorsInfo = nil
      end
      return
    end
    if (foundInterceptor ~= nil) then
      stopTimerAfter = 5 -- seconds
      local result = {
        intruder = monitoredGroup.GroupName,
        interceptors = { foundInterceptor }
      }
      Debug("OnShowOfForce-"..groupName.." :: Found interceptor '"..foundInterceptor.."'")
      callback( result )
    end
    
  end
  
  Timer = TIMER:New(FindAircrafts, sofInfo)
  Timer:Start(interval, interval)

end

--[[
OnFollowMe - description
    Monitors a unit for 'follow me' signalling (typically used in interception procedures). 
    The unit can either rock its wings more than 20° trhee times (configurable values),
    which is the normal daytime procedure, or turn its navigation lights on/off (WIP - not supported yet)
    which is thr normal night time procedure.

Parameters
    unitName :: Name of the unit to be monitored
    callback :: function to be invoked when unit performs 'follow me' signal
    options :: (object, see OnFollowMeDefaults below for structure)
]]--
OnFollowMeDefaults = {
  timeout = 120,        -- interceptor have 2 minutes to signal 'follow me' / 'deviate now'
  rockWings = {         -- when set, script looks for interceptor rocking wings to signal 'follow me' (daytime procedure)
    minBankAngle = 12,  -- minimum bank angle to register a "wing rock"
    minCount = 2,       -- no. of times wings must be rocked to trigger callback
    maxTime = 7         -- max time (seconds) to perform wing rock maneuvre
  },
  pumpLights = true,    -- when set, script looks for interceptor flashing nav lights to signal 'follow me' (night time procedure)
  interval = 0.5,       -- how often (seconds) the timer polls for interceptors,
  -- when set to positive number (of seconds) the 'follow me' signal will be triggered automatiucally after this time. 
  -- Useful for testing wityh AI as interceptors
  debugTimeoutTrigger = 0
}
--[[
  returns object:
  {
    interceptorUnit,  -- (string) Name of interceptor unit
    escortedGroup     -- (string) Name of escorted group
  }
]]--
function OnFollowMe( unitName, escortedGroupName, callback, options )

  if (unitName == nil) then
    Debug("OnFollowMe-? :: unitName not specified :: EXITS")
    return
  end
  local unit = UNIT:FindByName( unitName )
  if (unit == nil) then
    Debug("OnFollowMe-"..unitName.." :: Unit was not found :: EXITS")
    return
  end
  if (escortedGroupName == nil) then
    Debug("OnFollowMe-"..groupName.." :: missing escortedGroupName :: EXITS")
    return
  end
  local escortedGroup = GROUP:FindByName( escortedGroupName )
  if (escortedGroup == nil) then
    Debug("OnFollowMe-"..groupName.." :: Escorted group ("..escortedGroupName..") not found :: EXITS")
    return
  end
  if (callback == nil) then 
    Debug("OnFollowMe-"..groupName.." :: missing callback function :: EXITS")
    return 
  end

  options = options or OnFollowMeDefaults
  local rockWings = options.rockWings ~= nil
  local pumpLights = options.pumpLights or OnFollowMeDefaults.pumpLights
  local minBankAngle = options.rockWings.minBankAngle or OnFollowMeDefaults.rockWings.minBankAngle
  local minCount = options.rockWings.minCount or OnFollowMeDefaults.rockWings.minBankAngle
  local maxTime = options.rockWings.maxTime or OnFollowMeDefaults.rockWings.maxTime
  local interval = options.interval or OnFollowMeDefaults.interval
  local timeout = options.timeout or OnFollowMeDefaults.timeout
  local autoTriggerTimeout = options.debugTimeoutTrigger or OnFollowMeDefaults.debugTimeoutTrigger

  local lastMaxBankAngle = nil
  local bankEvents = {}
  local isWingRockComplete = false
  local isLightsFlashedComplete = false 
  local countEvents = 0
  local timer = nil
  local startTime = UTILS.SecondsOfToday()
  local totalTime = 0

  Debug("OnFollowMe-"..unitName.." :: BEGINS :: "..string.format("rockWings="..tostring(rockWings ~= nil).."; minBankAngle=%d, minCount=%d, maxTime=%d", minBankAngle, minCount, maxTime))

  local function DetectFollowMeSignal()

    local timestamp = UTILS.SecondsOfToday()
    totalTime = timestamp - startTime
    local bankAngle = unit:GetRoll()
--    Debug("OnFollowMe :: '"..unitName.." :: "..string.format("bankAngle=%d; lastMaxBankAngle=%d", bankAngle, lastMaxBankAngle or 0))
    local absBankAngle = math.abs(bankAngle)

    function getIsWingRockComplete() 
      table.insert(bankEvents, 1, timestamp)
      countEvents = countEvents+1
      --Debug("OnFollowMe :: '"..unitName.." :: count="..tostring(countEvents).."/"..tostring(minCount))
      if (countEvents < minCount) then return false end
      local prevTimestamp = bankEvents[minCount]
      local timeSpent = timestamp - prevTimestamp
      if (timeSpent > maxTime) then
        Debug("OnFollowMe :: '"..unitName.." :: TOO SLOW")
        return false
      end
      return true
    end

    if (rockWings) then
      if (bankAngle >= 0) then
        -- positive bank angle ...
        if (bankAngle >= minBankAngle and (lastMaxBankAngle == nil or lastMaxBankAngle < 0)) then
          lastMaxBankAngle = bankAngle
          isWingRockComplete = getIsWingRockComplete(timestamp)
        end
      else
        -- negative bank angle ...
        if (absBankAngle >= minBankAngle and (lastMaxBankAngle == nil or lastMaxBankAngle > 0)) then
          lastMaxBankAngle = bankAngle
          isWingRockComplete = getIsWingRockComplete(timestamp)
        end
      end
    end

    --[[
    if (pumpLights) then
      local device = GetDevice(11) -- note device '11' is for F-16C external lights. Each model might have different device for this
      BASE:E(device)
    end
    ]]--

    local isComplete = isWingRockComplete or isLightsFlashedComplete
    if (not isComplete and autoTriggerTimeout > 0 and totalTime >= autoTriggerTimeout) then
      isComplete = true
      Debug("OnFollowMe :: '"..unitName.." :: Triggers automatically (debug)")
    end

    if (not isComplete) then
      if (totalTime >= timeout) then
        Debug("OnFollowMe :: '"..unitName.." :: Times out :: Timer stops!")
        timer:Stop()
        bankEvents = nil
      end
      return
    end

    callback( 
      { 
        interceptor = unit:GetName(), 
        intruder = escortedGroupName 
      })
    Debug("OnFollowMe :: '"..unitName.." :: Follow-me signal detected! :: Timer stops!")
    timer:Stop()
    bankEvents = nil

  end

  timer = TIMER:New(DetectFollowMeSignal)
  timer:Start(interval, interval)

end


local function CalcGroupOffset( group1, group2 )

  local coord1 = group1:GetCoordinate()
  local coord2 = group2:GetCoordinate()
  return {
    x = coord1.x-coord2.x,
    y = coord1.y-coord2.y,
    z = coord1.z-coord2.z
  }

end

InterceptionOptions = {
  OnInsideZone = OnInsideGroupZoneDefaults,
  OnIntercepted = OnInterceptedDefaults,
  OnFollowMe = OnFollowMeDefaults,
  showAssistance = false
}

function InterceptionOptions:New()
  local options = routines.utils.deepCopy( InterceptionOptions )
  if (messageToApproachingInterceptors and messageToApproachingInterceptors ~= NoMessage) then
    options.OnInsideZone.messageToDetected = messageToApproachingInterceptors
  end
  return options
end

--[[
Sets the textual message to be sent to units entering the monitored zone around a group

Parameters
  message :: The message to be sent
]]--
function InterceptionOptions:MessageOnApproaching( message )
  if (not isString(message)) then return self end
  self.OnInsideZone.messageToDetected = message
  return self
end

--[[
InterceptionOptions:RockWingsBehavior
  Sets the behavior for how the unit needs to rock its wings to signal 'follow me'

Parameters
  optiona :: (object) :
  {
    minBankAngle :: (integer; default = 20) The minimum bank angle needed to detect unit is rocking its wings
    count :: (integer; default = 2) Number of times unit needs to bank to either side
    duration :: (integer; default = 7) The maximum time (seconds) allowed to perform the whole wing rocking maneuvre
    
  }
]]--
function InterceptionOptions:RockWingsBehavior( options )
  if (options == nil) then return self end
  self.OnFollowMe.rockWings.count = options.count or self.OnFollowMe.rockWings.count
  self.OnFollowMe.rockWings.minBankAngle = options.minBankAngle or self.OnFollowMe.rockWings.minBankAngle
  self.OnFollowMe.rockWings.maxTime = options.maxTime or self.OnFollowMe.rockWings.maxTime
  return self
end

--[[
InterceptionOptions:FollowMeDebugTimeoutTrigger
  Sets a timeout value to be tracked after a unit was established in the intercept zone. 
  When the timer triggers the 'follow me' event will automatically be triggered.
  This is mainly useful for debugging using AI interceptors that can't be made to rock their wings.

Parameters
  optiona :: (object) :
  {
    minBankAngle :: (integer; default = 20) The minimum bank angle needed to detect unit is rocking its wings
    count :: (integer; default = 2) Number of times unit needs to bank to either side
    duration :: (integer; default = 7) The maximum time (seconds) allowed to perform the whole wing rocking maneuvre
    
  }
]]--
function InterceptionOptions:FollowMeDebugTimeoutTrigger( timeout )
  if (not isNumber(timeout)) then return self end
  self.OnFollowMe.debugTimeoutTrigger = timeout
  return self
end

function InterceptionOptions:PolicingAssistanceAllowed( value )
  AirPolicing.IsAssistanceAllowed = value or true
  return self
end

function InterceptionOptions:WithAssistance( value, duration )
  self.showAssistance = value or true
  self.assistanceDuration = value or AirPolicing.Assistance.Duration
  return self
end

function InterceptionOptions:WithActiveIntercept( ai )
  if (not isTable(self)) then error("Cannot set active intercept for a non-table value") end
  self._activeIntercept = ai
  return self
end


--[[
InterceptionOptions
  Copies and returns default options for use with the OnInterception function

Parameters
  (none)
function InterceptionOptions()
  local options = routines.utils.deepCopy( InterceptionOptions )
  if (messageToApproachingInterceptors and messageToApproachingInterceptors ~= NoMessage) then
    options.OnInsideZone.messageToDetected = messageToApproachingInterceptors
  end
  return options
end
]]--

--[[
InterceptionOptions
  Performs monitoring of a group intercepting another group. 

Parameters
  (none)

Remarks
  This is a fairly complex function that breaks down an intercept into three phases:
    1. Approach
       Monitors a large moving zone around the affected (to-be intercepted) group.
       As one or more units enter the moving zone a message can be sent to the intercepting group.
       This can be useful to describe the intercepted group (if their skins aren't sufficient).
       This phase uses an internal timer that fires every 5 seconds, so avoid taxing the sim engine.
       The timer stops before moving on to the next phase:

    2. Establish
       Monitors a space in front of the intercepted group's lead aircraft.
       When one or more units enter this zone and remains there for 6 seconds (configurable)
       the 'established' event triggers. A new message can automatically be sent to the established
       units at this point (useful for clarity). The phase also uses an internal timer with shorter 
       intervals, which is stopped before moving to the final phase:

    3. Signal
       The function now monitors the interceptors' behavior to see if they signal 'follow me'
       (rocking wings or flashing nav lights). When this happens the 'signal' event fires and
       a callback function is invoked to indicate the fact. This can be used to affect intercepted
       group's behavior (make it follow the interceptor, divert, reroute, RTB, etc.).

See also
  `Follow` (function)
]]--
function OnInterception( group, callback, options )
  group = getGroup( group )
  if (group == nil) then
    Debug("OnInterception-? :: Group could not be resolved :: EXITS")
    return 
  end
  if (callback == nil) then
    Debug("OnInterception-"..group.GroupName.." :: Callback function missing :: EXITS")
    return 
  end
  options = options or InterceptionOptions
  local ai = options._activeIntercept
  if (ai and options.showAssistance) then
    MessageTo( ai.interceptor, AirPolicing.Assistance.ApproachInstruction, options.assistanceDuration )
  end
  OnInsideGroupZone( group.GroupName,
  function( closing )

    if (ai and options.showAssistance) then
      MessageTo( ai.interceptor, AirPolicing.Assistance.EstablishInstruction, options.assistanceDuration )
    end
    OnIntercepted( closing.monitoredGroup, 
      function( intercepted )

        if (ai and options.showAssistance) then
          MessageTo( ai.interceptor, AirPolicing.Assistance.SignalInstruction, options.assistanceDuration )
        end
        OnFollowMe(
          intercepted.interceptingUnit, 
          intercepted.interceptedGroup,
          callback,
          options.OnFollowMe)

      end, options.OnIntercepted)
    end, options.OnInsideZone)
end

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

function GetDivertWaypoint( group ) 
  local nisse = FindWaypointByName( group, InterceptionDefault.divertToWaypointName ) 
  return nisse ~= nil
end

function CanDivert( group ) 
  return GetDivertWaypoint( group ) ~= nil
end

FollowOffsetLimits = {
  -- longitudinal offset limits
  xMin = nil,
  xMax = nil,

  -- vertical offset limits
  yMin = nil,
  yMax = nil,

  -- latitudinal offset limits
  zMin = nil,
  zMax = nil 
}

function FollowOffsetLimits:GetFor( follower )



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
function Follow( follower, leader, offsetLimits, lastWaypoint )

  if (follower == nil) then
    Debug("Follow-? :: Follower was not specified :: EXITS")
    return
  end
  local followerGrp = getGroup(follower)
  if (followerGrp == nil) then
    Debug("Follow-? :: Cannot find follower: "..Dump(follower).." :: EXITS")
    return
  end

  if (leader == nil) then
    Debug("Follow-? :: Leader was not specified :: EXITS")
    return
  end
  local leaderGrp = getGroup(leader)
  if (leaderGrp == nil) then
    Debug("Follow-? :: Cannot find leader: "..Dump(leader).." :: EXITS")
    return
  end

  if (lastWaypoint == nil) then
    local route = leaderGrp:CopyRoute()
    lastWaypoint = #route
  end

  local off = CalcGroupOffset(followerGrp, leaderGrp)
  if (offset ~= nil) then
    off.x = offset.x or off.x
    off.y = offset.y or off.y
    off.z = offset.z or off.z
  end
  local task = followerGrp:TaskFollow( leaderGrp, off, lastWaypoint)
  followerGrp:SetTask( task )
  Debug("FollowGroup-"..follower.." ::  Group is now following "..leader.." to WP #"..tostring(lastWaypoint))

end

function RouteDirectTo( controllable, steerpoint )
  if (controllable == nil) then
    Debug("DirectTo-? :: controllable not specified :: EXITS")
    return
  end
  if (steerpoint == nil) then
    Debug("DirectTo-? :: steerpoint not specified :: EXITS")
    return
  end

  local route = nil
  local group = getGroup( controllable )
  if ( group == nil ) then
    Debug("DirectTo-? :: cannot resolve group: "..Dump(controllable).." :: EXITS")
    return
  end
  
  route = group:CopyRoute()
  if (route == nil) then
    Debug("DirectTo-" .. group.GroupName .." :: cannot resolve route from controllable: "..Dump(controllable).." :: EXITS")
    return
  end

  local wpIndex = nil
  if (isString(steerpoint)) then
    local wp = FindWaypointByName( route, steerpoint )
    if (wp == nil) then
      Debug("DirectTo-" .. group.GroupName .." :: no waypoint found with name '"..steerpoint.."' :: EXITS")
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

function Divert( controllable )
  local divertRoute = RouteDirectTo(controllable, InterceptionDefault.divertToWaypointName)
  return SetRoute( controllable, divertRoute )
end

function SetRoute( controllable, route )

  if (controllable == nil) then
    Debug("SetRoute-? :: controllable not specified :: EXITS")
    return
  end
  if (not isTable(route)) then
    Debug("SetRoute-? :: invalid route (not a table) :: EXITS")
    return
  end
  local group = getGroup(controllable)
  if (group == nil) then
    Debug("SetRoute-? :: group not found: "..Dump(controllable).." :: EXITS")
    return
  end

  group:SetTask( group:TaskRoute( route ) )
  Debug("SetRoute-"..group.GroupName.." :: group route was set :: DONE")

end

function LandHere( controllable, category, coalition )

  local group = getGroup( controllable )
  if (group == nil) then
    Debug("LandHere-? :: group not found: "..Dump(controllable).." :: EXITS")
    return
  end

  category = category or Airbase.Category.AIRDROME

  local ab = group:GetCoordinate():GetClosestAirbase2( category, coalition )
  if (ab == nil) then
    Debug("LandHere-"..group.GroupName.." :: no near airbase found :: EXITS")
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
  AirPolicing:RegisterLanding( group )
  Debug("LandHere-"..group.GroupName.." :: is tasked with landing at airbase ("..ab.AirbaseName..") :: DONE")
  return ab

end




--[[ ====================    RADIO COMMANDS  ==================== ]]--

local _policingGroups = {} -- contains one table of PolicingGroup items per coalition. Each table is indexed with policing group names

local INTERCEPT_STATE = {
    Inactive = 1,      -- group have no available intruders
    Ready = 2,         -- intruders are available 
    Establishing = 3,  -- interception is under way
    Controlling = 4    -- interceptor is controlling intruder
}

-- USed to specify how to reference intruders 
local REF_TYPE = {
    BRA = "BRA",
    Bulls = "Bullseye"
}

local PolicingGroup = {
    group = nil,
    -- menus
    mainMenu = nil,
    interceptMenu = nil,
    showOfForceMenu = nil,
    lookAgainMenu = null,
    intruderMenus = {},
    
    -- interception state
    interceptState = INTERCEPT_STATE.Inactive,
    intruder = nil,
    
    -- assist options
    interceptAssist = false,
    sofAssist = false
}

makeInactiveMenus = nil

function PolicingGroup:isPolicing(group)
    local coalition = group:GetCoalition()
    local coalitionPolicing = _policingGroups[coalition]
    return coalitionPolicing ~= nil and coalitionPolicing[group.GroupName] ~= nil
    --return _policingGroups[group.GroupName] ~= nil
end

function PolicingGroup:register(pg)
    local coaliton = pg.group:GetCoalition()
    local coalitionPolicing = _policingGroups[coalition]
    if (coalitionPolicing == nil) then
        coalitionPolicing = {}
        _policingGroups[coalition] = coalitionPolicing
    end
    coalitionPolicing[pg.group.GroupName] = pg
    return pg
end

function PolicingGroup:interceptInactive()
    self.interceptState = INTERCEPT_STATE.Inactive
    self.intruder = intruder
    return self
end

function PolicingGroup:interceptReady( intruderMenus )
    self.interceptState = INTERCEPT_STATE.Ready
    self.intruderMenus = intruderMenus
    return self
end

function PolicingGroup:interceptEstablishing( intruder )
    self.interceptState = INTERCEPT_STATE.Establishing
    self.intruder = intruder
    return self
end

function PolicingGroup:isInterceptInactive()
    return self.interceptState == INTERCEPT_STATE.Inactive
end

function PolicingGroup:isInterceptReady( intruderMenus )
    return self.interceptState == INTERCEPT_STATE.Ready
end

function PolicingGroup:interceptControlling()
    self.interceptState = INTERCEPT_STATE.Controlling
    return self
end

function PolicingGroup:RemoveLookAgainMenu()
    local pg = self
    if (pg.lookAgainMenu > 0) then
        pg.lookAgainMenu:Remove()
    end
end
 
function PolicingGroup:RemoveIntruderMenus()
    local pg = self
    if (#pg.intruderMenus > 0) then
        for k, v in pairs(pg.intruderMenus) do
            menu:Remove()
        end
    end
end

local function establishInterceptMenus( pg, ig, ai ) -- ig = intruder group; ai = _ActiveIntercept

    pg.mainMenu:RemoveSubMenus()
    local function cancel()
        ai:Cancel()
        makeInactiveMenus( pg )
        if (pg.interceptAssist) then
            MessageTo( pg.group, AirPolicing.Assistance.CancelledInstruction, AirPolicing.Assistance.Duration )
        end
    end
    MENU_GROUP_COMMAND:New(pg.group, "--CANCEL Interception--", pg.mainMenu, cancel, ig)
end

local function controllingInterceptMenus( pg, ig, ai ) -- ig = intruder group; ai = _ActiveIntercept

    pg.mainMenu:RemoveSubMenus()

    function landHereCommand()
        local airbase = LandHere( ig )
        if (pg.interceptAssist) then
            local text = string.format( AirPolicing.Assistance.LandHereOrderedInstruction, airbase.AirbaseName )
            MessageTo( pg.group, text, AirPolicing.Assistance.Duration )
        end
        pg:interceptInactive()
        makeInactiveMenus( pg )
    end

    function divertCommand()
        Divert( ig )
        if (pg.interceptAssist) then
            MessageTo( pg.group, AirPolicing.Assistance.DivertNowOrderedInstruction, AirPolicing.Assistance.Duration )
        end
        pg:interceptInactive()
        makeInactiveMenus( pg )
    end

    MENU_GROUP_COMMAND:New(pg.group, "Order: Land here!", pg.mainMenu, landHereCommand)
    if (CanDivert( ig )) then 
        MENU_GROUP_COMMAND:New(pg.group, "Order: Divert from here", pg.mainMenu, divertCommand)
    end

    local function cancel()
        ai:Cancel()
        makeInactiveMenus( pg )
        if (pg.interceptAssist) then
            MessageTo( pg.group, AirPolicing.Assistance.CancelledInstruction, AirPolicing.Assistance.Duration )
        end
    end
--    MENU_GROUP_COMMAND:New(pg.group, "--CANCEL INTERCEPT--", pg.mainMenu, cancel, ig)
end

local function beginIntercept( pg, ig ) -- ig = intruder group
    
    pg:interceptEstablishing( ig )
    if (pg.lookAgainMenu ~= nil) then
        pg.lookAgainMenu:Remove()
    end
    local options = InterceptionOptions:New():WithAssistance( pg.interseptAssist )
    local ai = _ActiveIntercept:New( id, pg.group )
    OnInterception(
        ig,
        function( intercept ) 

            -- 'follow me' was ordered; wait 3 seconds for reaction ...
            local reactDelay = UTILS.SecondsOfToday() + 3
            delayTimer = TIMER:New(
                function()

                    if (UTILS.SecondsOfToday() < reactDelay) then return end
                    delayTimer:Stop()

                    local reaction = GetInterceptedReaction( intercept.intruder )
                    local icptorName = pg.group.GroupName

                    if (reaction == INTERCEPT_REACTION.None) then
                        -- intruder disobeys order ...
                        Debug("Interception-"..icptorName.." :: "..ig.GroupName.." ignores interceptor")
                        pg:interceptInactive()
                        inactiveMenus( pg )
                        if (pg.interceptAssist) then
                            MessageTo( intercept.interceptor, AirPolicing.Assistance.DisobeyingInstruction, AirPolicing.Assistance.Duration )
                        end
                        return
                    end

                    if (reaction == INTERCEPT_REACTION.Divert) then
                        -- intruder diverts ...
                        Debug("Interception-"..icptorName.." :: "..ig.GroupName.." diverts")
                        pg:interceptInactive()
                        inactiveMenus( pg )
                        Divert( intercept.intruder )
                        if (pg.interceptAssist) then
                            MessageTo( intercept.interceptor, AirPolicing.Assistance.DisobeyingInstruction, AirPolicing.Assistance.Duration )
                        end
                        return
                    end

                    if (reaction == INTERCEPT_REACTION.Land) then
                        -- intruder lands ...
                        Debug("Interception-"..icptorName.." :: "..ig.GroupName.." lands")
                        pg:interceptInactive()
                        inactiveMenus( pg )
                        LandHere( intercept.intruder )
                        if (pg.interceptAssist) then
                            MessageTo( intercept.interceptor, AirPolicing.Assistance.DisobeyingInstruction, AirPolicing.Assistance.Duration )
                        end
                        return
                    end

                    if (reaction == INTERCEPT_REACTION.Follow) then
                        -- intruder obeys order and follows interceptor ...
                        Debug("Interception-"..icptorName.." :: "..ig.GroupName.." follows interceptor")
                        Follow( intercept.intruder, intercept.interceptor )
                        pg:interceptControlling()
                        controllingInterceptMenus( pg, ig, ai )
                        if (pg.interceptAssist) then
                            MessageTo( intercept.interceptor, AirPolicing.Assistance.ObeyingInstruction, AirPolicing.Assistance.Duration )
                        end
                        return
                    end

                    -- NOTE we should not reach this line!
                    Debug("Interception-"..icptorName.." :: HUH?!")

                end)
            delayTimer:Start(1, 1)

        end, 
        options:WithActiveIntercept( ai ))

    establishInterceptMenus( pg, ig, ai )

end

local function menuSeparator( pg, parentMenu )
    function ignore() end
    MENU_GROUP_COMMAND:New(pg.group, "-----", parentMenu, ignore)
end

local function intrudersMenus( pg )
    local radius = UTILS.NMToMeters(4) -- TODO make "look for intruders" radius configurable
    local zone = ZONE_UNIT:New(pg.group.GroupName.."-scan", pg.group, radius)
    
    local groups = SET_GROUP:New()
        :FilterCategories( { "plane" } )
        --:FilterCoalitions( coalitions ) -- TODO consider whether it would make sense to filter "interceptable" A/C on coalition
        :FilterZones( { zone } )
        :FilterActive()
        :FilterOnce()

    local intruders = {}
    groups:ForEach(
        function(g)
            if (pg.group.GroupName == g.GroupName or not g:InAir() or not CanBeIntercepted(g)) then return end
            
            local ownCoordinate =  pg.group:GetCoordinate()
            local intruderCoordinate = g:GetCoordinate()
            if (not ownCoordinate:IsLOS(intruderCoordinate)) then 
                Debug("intrudersMenus-"..pg.group.GroupName.." :: group "..g.GroupName.." is obscured (no line of sight)")
                return 
            end
            
            local verticalDistance = ownCoordinate.y - intruderCoordinate.y

            -- consider looking at MOOSE's 'detection' apis for a better/more realistic mechanic here
            if (verticalDistance >= 0) then
                -- intruder is above interceptor (easier to detect - unfortunately we can't account for clouds) ...
                if (verticalDistance > radius) then return end
            else if (math.abs(verticalDistance) > radius * 0.65 ) then
                return end
            end

            -- bearing
            local dirVec3 = ownCoordinate:GetDirectionVec3( intruderCoordinate )
            local angleRadians = ownCoordinate:GetAngleRadians( dirVec3 )
            local bearing = UTILS.Round( UTILS.ToDegree( angleRadians ), 0 )
            -- local sBearing = string.format( '%03d°', angleDegrees )

            --  o'clock position
            local heading = pg.group:GetUnit(1):GetHeading()
            local sPosition = GetClockPosition( heading, bearing )

            -- distance
            local distance = ownCoordinate:Get2DDistance(intruderCoordinate)
            local sDistance = DistanceToStringA2A( distance, true )

            -- level position
            local sLevelPos = GetLevelPosition( ownCoordinate, intruderCoordinate )
            
            -- angels
            local sAngels = GetAltitudeAsAngelsOrCherubs(g) -- ToStringAngelsOrCherubs( feet )

            --local lead = g:GetUnit(1)
            table.insert(intruders, { 
                text = string.format( "%s %s for %s, %s", sPosition, sLevelPos, sDistance, sAngels ), 
                intruder = g,
                distance = distance})
        end)
    
    -- sort intruder menu with closest ones at the bottom
    table.sort(intruders, function(a, b) return a.distance > b.distance end)

    -- remove existing intruder menus and build new ones ...
    if (#pg.intruderMenus > 0) then
        for k,v in pairs(pg.intruderMenus) do
            v:Remove()
        end
    end
    if (#intruders > 0) then
        if (pg:isInterceptInactive()) then
            pg.interceptMenu:Remove()
            menuSeparator( pg, pg.mainMenu )
            pg.lookAgainMenu = MENU_GROUP_COMMAND:New(pg.group, "SCAN AREA again", pg.mainMenu, intrudersMenus, pg)
        end
        local intruderMenus = {}
        for k, v in pairs(intruders) do 
            table.insert(intruderMenus, MENU_GROUP_COMMAND:New(pg.group, v.text, pg.mainMenu, beginIntercept, pg, v.intruder))
        end
        pg:interceptReady(intruderMenus)
        if (pg.interceptAssist) then
            MessageTo( pg.group, tostring(#intruders).." flights spotted nearby. Use menu to intercept", 6)
        end
    else
        if (pg.interceptAssist) then
            MessageTo( pg.group, "no nearby flights found", 4)
        end
    end
end

local function buildSOFMenus( pg )
    -- todo (add ground groups)
end

function inactiveMenus( pg )

    -- options
    local optionsMenu = nil
    pg:interceptInactive()
    pg.mainMenu:RemoveSubMenus()
    if (AirPolicing.Assistance.IsAllowed) then -- currently the OPTIONS menu only contains assistance options 
        optionsMenu = MENU_GROUP:New(pg.group, "OPTIONS", pg.mainMenu)
    end
    local updateOptionsMenuFunction = nil

    -- policing actions
    --pg.showOfForceMenu = MENU_GROUP_COMMAND:New(pg.group, "Begin show-of-force", pg.mainMenu, buildSOFMenus, pg) -- TODO
    pg.interceptMenu = MENU_GROUP_COMMAND:New(pg.group, "SCAN AREA for nearby flights", pg.mainMenu, intrudersMenus, pg)

    local function toggleInterceptAssist()
        pg.interceptAssist = not pg.interceptAssist
        updateOptionsMenu()
    end

    local function toggleSofAssist()
        pg.sofAssist = not pg.sofAssist
        updateOptionsMenu()
    end

    local function addOptionsMenus()
        Debug("updateOptionsMenus :: Updates options menu (itcpt assist="..tostring(pg.interceptAssist).."; sofAssist="..tostring(pg.sofAssist)..")")
        optionsMenu:RemoveSubMenus()

        if (not AirPolicing.Assistance.IsAllowed) then
            return end

        if (pg.interceptAssist) then
            MENU_GROUP_COMMAND:New(pg.group, "Turn OFF intersept assistance", optionsMenu, toggleInterceptAssist)
        else
            MENU_GROUP_COMMAND:New(pg.group, "ACTIVATE intersept assistance", optionsMenu, toggleInterceptAssist)
        end
        if (pg.sofAssist) then
            MENU_GROUP_COMMAND:New(pg.group, "Turn OFF Show-of-Force assistance", optionsMenu, toggleSofAssist, false)
        else
            MENU_GROUP_COMMAND:New(pg.group, "ACTIVATE Show-of-Force assistance", optionsMenu, toggleSofAssist, true)
        end
    end
    updateOptionsMenu = addOptionsMenus
    if (AirPolicing.Assistance.IsAllowed) then -- currently the OPTIONS menu only contains assistance options 
        addOptionsMenus()
    end

end

makeInactiveMenus = inactiveMenus

function PolicingGroup:New( group, options )
    if (PolicingGroup:isPolicing(group)) then error("Cannot register same policing group twice: '"..group.GroupName.."'") end
    local pg = routines.utils.deepCopy(PolicingGroup)
    pg.group = group
    pg.mainMenu = MENU_GROUP:New(group, "Policing")
    pg.interceptAssist = options.interceptAssist
    pg.sofAssist = options.showOfForceAssist
    PolicingGroup:register(pg)
    inactiveMenus( pg )
    return pg
end

--[[ obsolete
function addPolicingGroup( group )
  local mnuPolicing = MENU_GROUP:New(group, "Policing")
  policingGroups[group.GroupName] = { group = group, menu = mnuPolicing, intercept = nil, showOfForce = nil }
  local cmdIntercept = MENU_GROUP_COMMAND:New(group, "Begin intercept", mnuPolicing, buildStartInterceptMenus, group)
  local cmdShowOfForce = MENU_GROUP_COMMAND:New(group, "Begin show-of-force", mnuPolicing, startIntercept, group)
  Debug("addPolicingGroup >> commands added for group "..group.GroupName)
end
]]--

AirPolicingOptions = {
    interceptAssist = false,
    showOfForceAssist = false,
}

function AirPolicingOptions:New()
    local options = routines.utils.deepCopy(AirPolicingOptions)
    return options
end

function AirPolicingOptions:WithAssistance()
    AirPolicing.Assistance.IsAllowed = true
    self.interceptAssist = true
    self.showOfForceAssist = true
    return self
end

function AirPolicingOptions:WithInterceptAssist()
    AirPolicing.Assistance.IsAllowed = true
    self.interceptAssist = true
    return self
end

function AirPolicingOptions:WithShowOfForceAssist()
    AirPolicing.Assistance.IsAllowed = true
    self.showOfForceAssist = true
    return self
end

function EnableAirPolicing( options ) -- todo consider allowing filtering which groups/type of groups are to be policing
    options = options or AirPolicingOptions
    EVENTHANDLER:New():HandleEvent(EVENTS.PlayerEnterAircraft,
    function( event, data )
  
        local group = getGroup( data.IniGroupName )
        if (group ~= null) then 
            if (PolicingGroup:isPolicing(group)) then
                Debug("EnableAirPolicing :: player ("..data.IniPlayerName..") entered "..data.IniUnitName.." :: group is already air police: "..data.IniGroupName)
                return
            end
            PolicingGroup:New(group, options)

        end
        Debug("EnableAirPolicing :: player ("..data.IniPlayerName..") entered "..data.IniUnitName.." :: air policing options added for group "..data.IniGroupName)
  
    end)

    Debug("AirPolicing was enabled")
end