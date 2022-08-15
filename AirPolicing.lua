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

-- unit :: MOOSE UNIT to be monitored for 'follow me' signals
-- callback :: function to be invoked when unit performs 'follow me' signal
-- options
local OnFollowMeSignalledDefaults = {
  timeout = 120,        -- interceptor have 2 minutes to signal 'follow me' / 'deviate now'
  rockWings = {         -- when set, script looks for interceptor rocking wings to signal 'follow me' (daytime procedure)
    minBankAngle = 20,  -- minimum bank angle to register a "wing rock"
    minCount = 2,       -- no. of times wings must be rocked to trigger callback
    maxTime = 7         -- max time (seconds) to perform wing rock maneuvre
  },
  pumpLights = true,    -- when set, script looks for interceptor flashing nav lights to signal 'follow me' (night time procedure)
  interval = 0.5        -- how often (seconds) the timer polls for interceptors,
}
--[[
  returns object:
  {
    interceptor -- MOOSE UNIT (signalled 'follow me')
  }
]]--
function OnFollowMeSignal( unit, callback, options )

  if (unit == nil) then
    Debug("OnFollowMeSignal :: unit not specified :: EXITS")
    return
  end
  local unitName = unit:GetName()
  if (callback == nil) then 
    Debug("OnFollowMeSignal-"..groupName.." :: missing callback function :: EXITS")
    return 
  end

  options = options or OnFollowMeSignalledDefaults
  local rockWings = options.rockWings ~= nil
  local pumpLights = options.pumpLights or OnFollowMeSignalledDefaults.pumpLights
  local minBankAngle = options.rockWings.minBankAngle or OnFollowMeSignalledDefaults.rockWings.minBankAngle
  local minCount = options.rockWings.minCount or OnFollowMeSignalledDefaults.rockWings.minBankAngle
  local maxTime = options.rockWings.maxTime or OnFollowMeSignalledDefaults.rockWings.maxTime
  local interval = options.interval or OnFollowMeSignalledDefaults.interval
  local timeout = options.timeout or OnFollowMeSignalledDefaults.timeout

  local lastMaxBankAngle = nil
  local bankEvents = {}
  local isWingRockComplete = false
  local isLightsFlashedComplete = false 
  local countEvents = 0
  local timer = nil
  local startTime = UTILS.SecondsOfToday()
  local totalTime = 0

  Debug("OnFollowMeSignal-"..unitName.." :: BEGINS :: "..string.format("rockWings="..tostring(rockWings ~= nil).."; minBankAngle=%d, minCount=%d, maxTime=%d", minBankAngle, minCount, maxTime))

  local function DetectFollowMeSignal()

    local timestamp = UTILS.SecondsOfToday()
    totalTime = timestamp - startTime
    local bankAngle = unit:GetRoll()
    Debug("OnFollowMeSignal :: '"..unitName.." :: "..string.format("bankAngle=%d; lastMaxBankAngle=%d", bankAngle, lastMaxBankAngle or 0))
    local absBankAngle = math.abs(bankAngle)

    function IsWingRockComplete() 
      table.insert(bankEvents, 1, timestamp)
      countEvents = countEvents+1
      --  Debug("OnFollowMeSignal :: '"..unitName.." :: events="..tostring(countEvents))
      if (countEvents < minCount) then return false end
      local prevTimestamp = bankEvents[minCount]
      local timeSpent = timestamp - prevTimestamp
      if (timeSpent > maxTime) then
      --  Debug("OnFollowMeSignal :: '"..unitName.." :: TOO SLOW")
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
        Debug("OnFollowMeSignal :: '"..unitName.." :: Times out :: Timer stops!")
        timer:Stop()
        bankEvents = nil
      end
      return
    end

    -- follow me signal detected ...
    callback( { interceptor = unit } )
    Debug("OnFollowMeSignal :: '"..unitName.." :: Follow-me signal detected! :: Timer stops!")
    timer:Stop()
    bankEvents = nil

  end

  timer = TIMER:New(DetectFollowMeSignal)
  timer:Start(interval, interval)

end

function OnInterceptorClosing( groupName, callback, options )
  
  if ( groupName == nil) then
    Debug("OnInterceptorClosing-? :: Group name missing :: EXITS")
    return 
  end
  if (callback == nil) then 
    Debug("OnInterceptorClosing-"..groupName.." :: missing callback function :: EXITS")
    return 
  end
  local intruderGroup = GROUP:FindByName( groupName )
  if (intruderGroup == nil) then 
    Debug("OnInterceptorClosing-"..groupName.." :: intruder group not found :: EXITS")
    return 
  end
  local intruderUnit = intruderGroup:GetUnit(1) -- todo Consider making intruder unit (to be intercepted) configurable (options)
  if (intruderUnit == nil) then 
    Debug("OnInterceptorClosing-"..groupName.." :: intruder group unit #1 not found :: EXITS")
    return 
  end
  
  local intruderUnitName = intruderUnit:GetName()
  local zoneRadius = 600 -- todo make configurable (options)
  local zoneOffset = {   -- todo make configurable (options)
    relative_to_unit = true,
    dx = -100,   -- longitudinal offset (positive = in front; negative = to the back)
    dy = 0,      -- latitudinal offset (positive = right; negative = left)
    dz = 5       -- vertical offset (positive = up; negative = down)
  }
  local coalitions = { "blue" } -- todo make configurable (options)
  local interval = 5     -- todo make configurable (options)
  local timer = nil
  local stopTimerAfter = 0
  local interceptingUnit = nil
  local interceptZone = ZONE_UNIT:New(intruderUnitName.."-closing", intruderUnit, zoneRadius, zoneOffset)

  Debug("OnInterceptorClosing-"..groupName.." :: BEGINS :: "..string.format("zoneRadius=%d; interval=%d", zoneRadius, interval))

  local function FindClosingInterceptors()

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
    local intruderUnitMSL = pos.y

    interceptors:ForEach(
      function(interceptor)
        if (groupName == interceptor:GetGroup().GroupName) then
          Debug("OnInterceptorClosing-"..groupName.." :: filters out intruder group units")
          return 
        end
        local interceptorName = interceptor:GetName()
        local pos = Unit.getByName(interceptorName):getPoint()
        local interceptorUnitMSL = pos.y
        local distance = math.abs(interceptorUnitMSL - intruderUnitMSL)

        if (distance > zoneRadius) then 
          Debug("OnInterceptorClosing-"..groupName.." :: filters out "..interceptorName.." (vertically outside radius) :: EXITS")
          return 
        end
        interceptingUnit = interceptor
      end, 
      interceptors)

    if (stopTimerAfter > 0) then
      stopTimerAfter = stopTimerAfter - interval
      if (stopTimerAfter <= 0) then
        Debug("OnInterceptorClosing-"..groupName.." :: TIMER STOPPED")
        timer:Stop()
      end
      return
    end

    if (interceptingUnit ~= nil) then
      stopTimerAfter = interval
      Debug("OnInterceptorClosing-"..groupName.." :: Interception by "..interceptingUnit:GetName())
      callback({
        interceptorUnit = interceptingUnit,
        intruderGroup = intruderGroup
      })
    end

  end

  timer = TIMER:New(FindClosingInterceptors, interceptZone)
  timer:Start(interval, interval)
end

local OnInterceptedDefaults = {
-- options
  zoneOffset = {
    -- default intercept zone is 50 m radius, 55 meters in front of intruder aircraft
    relative_to_unit = true,
    dx = 30,   -- longitudinal offset (positive = in front; negative = to the back)
    dy = 0,    -- latitudinal offset (positive = right; negative = left)
    dz = 5     -- vertical offset (positive = up; negative = down)
  },
  zoneRadius = 100,
  coalitions = { "blue" },
  description = nil,
  delay = 4,         -- time (seconds) required for interceptor to be established in interceopt zone before interception is triggered
  interval = 2
}
function OnIntercepted( groupName, callback, options )

  if ( groupName == nil) then
    Debug("OnIntercepted-? :: Group name missing :: EXITS")
    return 
  end
  if (callback == nil) then 
    Debug("OnIntercepted-"..groupName.." :: missing callback function :: EXITS")
    return 
  end
  local intruderGroup = GROUP:FindByName( groupName )
  if (intruderGroup == nil) then 
    Debug("OnIntercepted-"..groupName.." :: intruder group not found :: EXITS")
    return 
  end
  local intruderUnit = intruderGroup:GetUnit(1) -- todo Consider making intruder unit (to be intercepted) configurable (options)
  if (intruderUnit == nil) then 
    Debug("OnIntercepted-"..groupName.." :: intruder group unit #1 not found :: EXITS")
    return 
  end
  local intruderUnitName = intruderUnit:GetName()

  options = options or OnInterceptedDefaults
  local coalitions = options.coalitions or OnInterceptedDefaults.coalitions 
  local zoneRadius = options.zoneRadius or OnInterceptedDefaults.zoneRadius
  local delay = options.delay or OnInterceptedDefaults.delay
  local interval = options.interval or OnInterceptedDefaults.interval
  local description = options.description

  local countIntercepts = 0
  local stopTimerAfter = 0
  local interceptorInfos = {} -- item structure = { establishedTimestamp=<seconds>, isDescriptionProvided=<bool> }
  local intruderName = intruderGroup:GetName()
  local zoneOffset = options.zoneOffset or OnInterceptedDefaults.zoneOffset
  local interceptingUnit = nil
  local timer = nil

  Debug("OnIntercepted-"..groupName.." ::  zoneOffset = {dx = "..tostring(zoneOffset.dx)..", dy="..tostring(zoneOffset.dy)..", dz="..tostring(zoneOffset.dz).."}")

  local interceptZone = ZONE_UNIT:New(intruderUnitName.."-intercepted", intruderUnit, zoneRadius, zoneOffset)
  Debug("OnIntercepted-"..groupName.." :: BEGINS :: "..string.format("zoneRadius=%d; delay=%d; interval=%d, description=%s", zoneRadius, delay, interval, description or ""))
  
  local function FindInterceptors()

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
    local intruderUnitMSL = pos.y
    local timestamp = UTILS.SecondsOfToday()

    interceptors:ForEach(
      function(interceptor)
        if (groupName == interceptor:GetGroup().GroupName) then
          Debug("OnInterceptorClosing-"..groupName.." :: filters out intruder group units")
          return 
        end
        local interceptorName = interceptor:GetName()
        local pos = Unit.getByName(interceptorName):getPoint()
        local interceptorUnitMSL = pos.y
        local distance = math.abs(interceptorUnitMSL - intruderUnitMSL)

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
        intruderGroup = intruderGroup,
        interceptorUnit = interceptingUnit
      }
      Debug("OnIntercepted-"..groupName.." :: Intercepted by "..interceptingUnit:GetName())
      callback( result )
    end
    
  end
  
  timer = TIMER:New(FindInterceptors, interceptZone)
  timer:Start(interval, interval)

end

local OnShowOfForceDefaults =
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

  local intruderGroup = GROUP:FindByName( groupName )
  if (intruderGroup == nil) then 
    Debug("OnShowOfForce-? :: intruder group '"..groupName.."' not found :: EXITS")
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

  local intruderName = intruderGroup:GetName()
  local interceptZone = ZONE_GROUP:New(intruderName, intruderGroup, radius)
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
    
    local intruderCoord = intruderGroup:GetCoordinate()
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
          Debug("OnShowOfForce-"..groupName.." :: filters out intruder from interceptors")
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
        intruder = intruderGroup.GroupName,
        interceptors = { foundInterceptor }
      }
      Debug("OnShowOfForce-"..groupName.." :: Found interceptor '"..foundInterceptor.."'")
      callback( result )
    end
    
  end
  
  Timer = TIMER:New(FindAircrafts, sofInfo)
  Timer:Start(interval, interval)

end

-- this is a convenient method to send a simple message to all interceptors in a OnIntercepted `result`
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
  if (type(recipient) ~= "string") then
    if (recipient.ClassName == "GROUP") then
      MESSAGE:New(message, duration):ToGroup(recipient)
      Debug("MessageTo :: Group "..recipient.GroupName.."' :: "..message)
    end
    if (recipient.ClassName == "UNIT") then
      MESSAGE:New(message, duration):ToGroup(recipient:GetGroup())
      Debug("MessageTo :: Unit Group "..recipient:GetName().."' :: "..message)
    end
    if (recipient.ClassName == "CLIENT") then
      MESSAGE:New(message, duration):ToClient(recipient)
      Debug("MessageTo :: Client "..recipient:GetName().."' :: "..message)
    end
    return
  end
  local group = GROUP:FindByName( recipient )
  if (group ~= nil) then
    Debug("MessageTo"..recipient.." :: "..message)
    MESSAGE:New(message, duration):ToGroup(group)
    return
  end

  local unit = CLIENT:FindByName( recipient )
  if (unit ~= nil) then
    Debug("MessageTo-"..recipient.." :: "..message)
    MESSAGE:New(message, duration):ToClient(unit)
    return
  end
  Debug("MessageTo-"..recipient.." :: Recipient not found")

end