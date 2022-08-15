function Debug( message )
  BASE:E(message)
  MESSAGE:New("DBG: "..message):ToAll()
end

-- options
local OnWingsRockedDefaults = {
  minBankAngle = 20,  -- minimum bank angle to register a "wing rock"
  minCount = 2,       -- no. of times wings must be rocked to trigger callback
  maxTime = 7,        -- max time (seconds) to perform wing rock maneuvre
  interval = 0.5,     -- how often (seconds) the timer polls for interceptors,
  unitNumber = 1      -- the number (index) of the unit to monitor for wing rocking
}
--[[
  returns object:
  {
    unitName, (string, name of unit that rocked wings and triggered the event )
    groupName (string, name of unit group )
  }
]]--
function OnWingsRocked( groupName, callback, options )

  options = options or OnWingsRockedDefaults
  local minBankAngle = options.minBankAngle or OnWingsRockedDefaults.minBankAngle
  local minCount = options.minCount or OnWingsRockedDefaults.minBankAngle
  local maxTime = options.maxTime or OnWingsRockedDefaults.maxTime
  local unitNumber = options.unitNumber or OnWingsRockedDefaults.unitNumber
  local interval = options.interval or OnWingsRockedDefaults.interval

  local group = GROUP:FindByName( groupName )
  if (group == nil) then
    Debug("OnWingsRocked-? :: group '"..groupName.."' not found :: EXITS")
    return
  end
  local unit = group:GetUnit(unitNumber)
  if (unit == nil) then
    Debug("OnWingsRocked-? :: unit #"..tostring(unitNumber).." not found :: EXITS")
    return
  end

  local lastMaxBankAngle = nil
  local bankEvents = {}
  local isWingRockComplete = false
  local countEvents = 0

  function DetectWingsRocked()

    local timestamp = UTILS.SecondsOfToday()
    local bankAngle = unit:GetRoll()
   Debug("OnWingsRocked :: '"..groupName.." #"..tostring(unitNumber).." :: "..string.format("bankAngle=%d; lastMaxBankAngle=%d", bankAngle, lastMaxBankAngle or 0))
    local absBankAngle = math.abs(bankAngle)

    function IsWingRockComplete() 
      table.insert(bankEvents, 1, timestamp)
      countEvents = countEvents+1
  --  Debug("OnWingsRocked :: '"..groupName.." #"..tostring(unitNumber).." :: events="..tostring(countEvents))
      if (countEvents < minCount) then return false end
      local prevTimestamp = bankEvents[minCount]
      local timeSpent = timestamp - prevTimestamp
      if (timeSpent > maxTime) then
  --  Debug("OnWingsRocked :: '"..groupName.." #"..tostring(unitNumber).." :: TOO SLOW")
        return false
      end
      return true
    end

    if (bankAngle >= 0) then
      -- positive bank angle ...
      if (bankAngle >= minBankAngle and (lastMaxBankAngle == nil or lastMaxBankAngle < 0)) then
        lastMaxBankAngle = bankAngle
--  Debug("OnWingsRocked :: '"..groupName.." #"..tostring(unitNumber).." :: ++NISSE++")
        isWingRockComplete = IsWingRockComplete(timestamp)
      end
    else
      -- negative bank angle ...
      if (absBankAngle >= minBankAngle and (lastMaxBankAngle == nil or lastMaxBankAngle > 0)) then
        lastMaxBankAngle = bankAngle
--  Debug("OnWingsRocked :: '"..groupName.." #"..tostring(unitNumber).." :: --NISSE--")
        isWingRockComplete = IsWingRockComplete(timestamp)
      end
    end
    if (not isWingRockComplete) then
      return
    end

    -- wing rock maneuvre detected ...
    local result = {
      unitName = unit.GetName()
      groupName = groupName,
    }
    if (callback ~= nil) then
      callback( result )
    end
    Debug("OnWingsRocked :: '"..groupName.." #"..tostring(unitNumber).." :: Wing Rocking detected!")
    Timer:Stop()
    bankEvents = nil

  end

  Timer = TIMER:New(DetectWingsRocked)
  Timer:Start(interval, interval)

end


local OnInterceptedDefaults = {
-- options
  radius = 150,
  coalitions = { "blue" },
  description = nil,
  duration = 60, 
  interval = 2
}
function OnIntercepted( groupName, callback, options )

  local intruderGroup = GROUP:FindByName( groupName )
  if (intruderGroup == nil) then 
    Debug("OnIntercepted-? :: intruder group '"..groupName.."' not found :: EXITS")
    return 
  end
  if (callback == nil) then 
    Debug("OnIntercepted-"..groupName.." :: missing callback function :: EXITS")
    return 
  end
  local countIntercepts = 0
  local Timer
  options = options or OnInterceptedDefaults
  local coalitions = options.coalitions or OnInterceptedDefaults.coalitions 
  local radius = options.radius or OnInterceptedDefaults.radius
  local duration = options.duration or OnInterceptedDefaults.duration
  local interval = options.interval or OnInterceptedDefaults.interval
  local description = options.description
  local stopTimerAfter = 0
  local interceptorInfos = {} -- item structure = { isDescriptionProvided=<bool> }
  local intruderName = intruderGroup:GetName()

  local intruderZone = ZONE_GROUP:New(intruderName, intruderGroup, radius)

Debug("OnIntercepted-"..groupName.." :: BEGINS :: "..string.format("radius=%d; duration=%d; interval=%d, description=%s", radius, duration, interval, description or ""))
  
  function FindInterceptors(Zone)

    local interceptors = SET_GROUP:New()
      :FilterCategoryAirplane()
      :FilterCoalitions( coalitions )
      :FilterZones( {Zone} )
      :FilterActive()
      :FilterOnce()

    --[[

    if the intruder belongs to interceptor(s) coalition it will be included in the `interceptors` set, so needs to be fitered out
    also, oddly enough, the above filtering doesn't exclude groups flying vertically outside the radius 
    (zone appears to be cylinder rather than orb, not sure if that's a MOOSE bug)
    so we need to filter those out manually 

    ]]--
    
    local intruderCoord = intruderGroup:GetCoordinate()
    local interceptorGroupNames = {}
    local interceptorCount = 0
    
    interceptors:ForEachGroup(
      function(interceptor)
        if (groupName == interceptor.GroupName) then
          --Debug("OnIntercepted-"..groupName.." :: filters out intruder (belongs to interceptor coalition)")
          return 
        end
        local interceptorCoord = interceptor:GetCoordinate()
        local distance = interceptorCoord:Get3DDistance(intruderCoord)
        if (distance > radius) then 
          --Debug("OnIntercepted-"..groupName.." :: filters out "..interceptor.GroupName.." (vertically outside radius)")
          return 
        end
        table.insert(interceptorGroupNames, interceptor.GroupName)
        Debug("OnIntercepted-"..groupName.." :: "..string.format("Interceptor %s", interceptor.GroupName))
        interceptorCount = interceptorCount+1
        local interceptorInfo = interceptorInfos[interceptor.GroupName]
        if (interceptorInfo == nil) then
          if (description ~= nil) then
            MESSAGE:New(description, duration):ToGroup(interceptor)
            Debug("OnIntercepted-"..groupName.." :: description sent to "..interceptor.GroupName.." :: "..description)
          end
          interceptorInfo = { isDescriptionProvided = true }
          interceptorInfos[interceptor.GroupName] = interceptorInfo
        end
      end)
    
    if (stopTimerAfter > 0) then
      stopTimerAfter = stopTimerAfter - interval
      if (stopTimerAfter <= 0) then
        Debug("OnIntercepted-"..groupName.." :: TIMER STOPPED")
        Timer:Stop()
        interceptorInfos = nil
      end
      return
    end
    if (interceptorCount > 0) then
      countIntercepts = countIntercepts + interval
    end
    if (countIntercepts >= duration) then
      stopTimerAfter = 5 -- seconds
      local result = {
        intruder = intruderGroup.GroupName,
        interceptors = interceptorGroupNames
      }
      callback( result )
    end
    
  end
  
  Timer = TIMER:New(FindInterceptors, intruderZone)
  Timer:Start(interval, interval)

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
function OnShowOfForce(groupName, callback, options) --, radius, minCount, minSpeedKts, coalitions, minTimeBetween, interval)

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
  local intruderZone = ZONE_GROUP:New(intruderName, intruderGroup, radius)
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
      :FilterZones({intruderZone})
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
            MESSAGE:New(description, duration):ToGroup(interceptor)
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
function MessageToInterceptors( result, message )

    message = message or "Intruder  group was diverted. Good job!"
    
    local interceptors = SET_GROUP:New()
    interceptors:AddGroupsByName( result.interceptors )
    interceptors:ForEachGroup(
      function(interceptor)
        BASE:E("OnIntercepted-"..interceptor.GroupName.." :: Message to interceptor '"..interceptor.GroupName.."' :: "..message)
        MESSAGE:New(message):ToGroup(interceptor)
      end)

end