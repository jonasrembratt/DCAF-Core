AirPolicing = {
  Debug = false,
  DebugToUI = false
}

function Debug( message )
  BASE:E(message)
  if (AirPolicing.Debug) then
    MESSAGE:New("DBG: "..message):ToAll()
  end
end

function GetUnitFromGroupName( groupName, unitNumber )

  unitNumber = unitNumber or 1
  local group = GROUP:FindByName( groupName )
  if (group == nil) then return nil end
  return group.GetUnit( unitNumber )

end

local function isString( value ) return type(value) == "string" end
local function isNumber( value ) return type(value) == "number" end
local function isNumber( value ) return type(value) == "table" end


local function mkIndent( count )
  local s = ""
  for i=count,0,-1 do
    s = s.." "
  end
  return s
end

function dump(o)
  if type(o) ~= 'table' then
      return tostring(o)
  end

  local s = "{ "
  for k,v in pairs(o) do
     if type(k) ~= 'number' then k = '"'..k..'"' end
     s = s .. '['..k..'] = ' .. dump(v) .. ','
  end
  return s .. '} '
end

function dumpPretty(o, indentlvl, indentcount)
  if type(o) ~= 'table' then
      return tostring(o)
  end

  if (isNumber(indentlvl)) then indentlvl = indentlvl else indentlvl = 0 end
  if (isNumber(indentcount)) then indentcount = indentcount else indentcount = 2 end
  local indentLen = indentlvl * indentcount
  local indent = mkIndent(indentLen)
  local s = indent..'{\n'
  local nxtIndent = mkIndent(indentLen + indentcount)
  for k,v in pairs(o) do
     if type(k) ~= 'number' then k = '"'..k..'"' end
     s = s .. nxtIndent.. '['..k..'] = ' .. dump(v, indentlvl+1, indentcount) .. ',\n'
  end
  return s .. indent .. '}\n'
end

local NoMessage = "_none_"

--[[
OnApproaching
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
end

OnInterceptedDefaults = {
  interceptedUnitNo = 1,
  zoneRadius = 100,
  zoneOffset = {
    -- default intercept zone is 50 m radius, 55 meters in front of intruder aircraft
    relative_to_unit = true,
    dx = 30,   -- longitudinal offset (positive = in front; negative = to the back)
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
    minBankAngle = 20,  -- minimum bank angle to register a "wing rock"
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

Debug("autoTriggerTimeout = "..autoTriggerTimeout)

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
    Debug("OnFollowMe :: '"..unitName.." :: "..string.format("bankAngle=%d; lastMaxBankAngle=%d", bankAngle, lastMaxBankAngle or 0))
    local absBankAngle = math.abs(bankAngle)

    function IsWingRockComplete() 
      table.insert(bankEvents, 1, timestamp)
      countEvents = countEvents+1
      --  Debug("OnFollowMe :: '"..unitName.." :: events="..tostring(countEvents))
      if (countEvents < minCount) then return false end
      local prevTimestamp = bankEvents[minCount]
      local timeSpent = timestamp - prevTimestamp
      if (timeSpent > maxTime) then
      --  Debug("OnFollowMe :: '"..unitName.." :: TOO SLOW")
        return false
      end
      return true
    end

    if (rockWings) then
      if (bankAngle >= 0) then
        -- positive bank angle ...
        if (bankAngle >= minBankAngle and (lastMaxBankAngle == nil or lastMaxBankAngle < 0)) then
          lastMaxBankAngle = bankAngle
          isWingRockComplete = IsWingRockComplete(timestamp)
        end
      else
        -- negative bank angle ...
        if (absBankAngle >= minBankAngle and (lastMaxBankAngle == nil or lastMaxBankAngle > 0)) then
          lastMaxBankAngle = bankAngle
          isWingRockComplete = IsWingRockComplete(timestamp)
        end
      end
    end

    --[[
    if (pumpLights) then
      local device = GetDevice(11) -- note device '11' is for F-16C external lights. Each model might have different device for this
      BASE:E(device)
    end
    ]]--

    if (not isWingRockComplete and not isLightsFlashedComplete) then
      if (totalTime >= timeout) then
        Debug("OnFollowMe :: '"..unitName.." :: Times out :: Timer stops!")
        timer:Stop()
        bankEvents = nil
      end
    end
    if (autoTriggerTimeout <= 0 or totalTime < autoTriggerTimeout) then
      return
    else
      Debug("OnFollowMe :: '"..unitName.." :: Triggers automatically (debug)")
    end

    -- follow me signal detected ...
    callback( 
      { 
        interceptor = unit:GetName(), 
        follower = escortedGroupName 
      })
    Debug("OnFollowMe :: '"..unitName.." :: Follow-me signal detected! :: Timer stops!")
    timer:Stop()
    bankEvents = nil

  end

  timer = TIMER:New(DetectFollowMeSignal)
  timer:Start(interval, interval)

end

local function IndexOfNamedWaypoint( route, name )
  if (not isTable(route)) then return -1 end
  if (not isString(name)) then return -1 end
  local i = 1
  for v,wp in pairs(route) do
    if (wp["name"] == name) then
      return 1
    end
    i = i+1
  end
  return -1
end

local ignoreMessagingGroups = {}
-- this is a convenient method to send a simple message to groups, clients or lists of groups or clients
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

  if (type(recipient) == "table") then
    if (recipient.ClassName == "UNIT") then
      -- MOOSE doesn't support sending messages to units; send to group and ignore other units from same group ...
      local group = recipient:GetGroup()
      local isIgnored = ignoreMessagingGroups[group.GroupName] ~= nil
      if (not isIgnored) then
        MessageTo( group, message, duration )
        ignoreMessagingGroups[group.GroupName] = group.GroupName
      end
      return
    end
    if (recipient.ClassName == "GROUP") then
      local isIgnored = ignoreMessagingGroups[recipient.GroupName] ~= nil
      if (isIgnored) then
        Debug("MessageTo :: Group "..recipient.GroupName.." is ignored")
        return
      end
      MESSAGE:New(message, duration):ToGroup(recipient)
      Debug("MessageTo :: Group "..recipient.GroupName.." :: '"..message.."'")
      return
    end
    if (recipient.ClassName == "CLIENT") then
      MESSAGE:New(message, duration):ToClient(recipient)
      Debug("MessageTo :: Client "..recipient:GetName().." :: "..message.."'")
      return
    end

    for key, value in pairs(recipient) do
      MessageTo( value, message, duration )
    end
    ignoreMessagingGroups = {}
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

local function CalcGroupOffset( group1, group2 )

  local coord1 = group1:GetCoordinate()
  local coord2 = group2:GetCoordinate()
  return {
    x = coord1.x-coord2.x,
    y = coord1.y-coord2.y,
    z = coord1.z-coord2.z
  }

end

function Follow( followerName, leaderName, offset, lastWaypoint )

  if (not isString(followerName)) then
    Debug("FollowGroup-? :: Missing followerName :: EXITS")
    return
  end
  local follower = GROUP:FindByName( followerName )
  if (followerName == nil) then
    follower = UNIT:FindByName( followerName )
    if (follower == nil) then
      Debug("FollowGroup-"..followerName.." :: Group not found="..followerName.." :: EXITS")
      return
    else
      follower = follower:GetGroup()
    end
  end

  if (not isString(leaderName)) then
    Debug("FollowGroup-? :: Missing leaderName :: EXITS")
    return
  end
  local escort = GROUP:FindByName( leaderName )
  if (escort == nil) then
    escort = UNIT:FindByName( leaderName )
    if (escort == nil) then
      Debug("FollowGroup-"..followerName.." :: Escort not found="..leaderName.." :: EXITS")
      return
    else
      escort = escort:GetGroup()
    end  
  end

  if (lastWaypoint == nil) then
    local escortRoute = escort:CopyRoute()
Debug("--->\n"..dumpPretty(escortRoute))
    lastWaypoint = #escortRoute
  end

  local off = CalcGroupOffset(follower, escort)
  if (offset ~= nil) then
    off.x = offset.x or off.x
    off.y = offset.y or off.y
    off.z = offset.z or off.z
  end
  local task = follower:TaskFollow( escort, off, lastWaypoint)
  follower:SetTask( task )
  Debug("FollowGroup-"..followerName.." ::  Group is now following "..leaderName.." to WP #"..tostring(lastWaypoint))

end

local OnInterceptionDefaults = {
  OnInsideZone = OnInsideGroupZoneDefaults,
  OnIntercepted = OnInterceptedDefaults,
  OnFollowMe = OnFollowMeDefaults,
}

--[[
Sets the behavior for how the unit needs to rock its wings to signal 'follow me'

Parameters
  (object):
  {
    minBankAngle :: (integer; default = 20) The minimum bank angle needed to detect unit is rocking its wings
    count :: (integer; default = 2) Number of times unit needs to bank to either side
    duration :: (integer; default = 7) The maximum time (seconds) allowed to perform the whole wing rocking maneuvre
    
  }
]]--

function OnInterceptionDefaults:MessageOnApproaching( message )
  if (not isString(message)) then return self end
  self.OnInsideZone.messageToDetected = message
  return self
end

function OnInterceptionDefaults:RockWingsBehavior( options )
  if (options == nil) then return self end
  self.OnFollowMe.rockWings.count = options.count or self.OnFollowMe.rockWings.count
  self.OnFollowMe.rockWings.minBankAngle = options.minBankAngle or self.OnFollowMe.rockWings.minBankAngle
  self.OnFollowMe.rockWings.maxTime = options.maxTime or self.OnFollowMe.rockWings.maxTime
  return self
end

function OnInterceptionDefaults:FollowMeDebugTimeoutTrigger( timeout )
  if (not isNumber(timeout)) then return self end
  self.OnFollowMe.debugTimeoutTrigger = timeout
  return self
end

function InterceptionOptions()
  local options = routines.utils.deepCopy( OnInterceptionDefaults )
  if (messageToApproachingInterceptors and messageToApproachingInterceptors ~= NoMessage) then
    options.OnInsideZone.messageToDetected = messageToApproachingInterceptors
  end
  return options
end

function OnGroupIntercepted( groupName, callback, options )

  if (groupName == nil) then
    Debug("OnInterception-? :: Group name missing :: EXITS")
    return 
  end
  if (callback == nil) then
    Debug("OnInterception-"..groupName.." :: Callback function missing :: EXITS")
    return 
  end
  options = options or OnInterceptionDefaults
  OnInsideGroupZone( groupName,
  function( closing )

    OnIntercepted( closing.monitoredGroup, 
      function( intercepted )

        OnFollowMe(
          intercepted.interceptingUnit, 
          intercepted.interceptedGroup,
          callback,
          options.OnFollowMe)

      end, options.OnIntercepted)
    end, options.OnInsideZone)
end