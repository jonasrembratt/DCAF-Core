DCAFCore = {
    Debug = false,
    DebugToUI = false, 
}

function isString( value ) return type(value) == "string" end
function isNumber( value ) return type(value) == "number" end
function isTable( value ) return type(value) == "table" end
function isUnit( value ) return isTable(value) and value.ClassName == "UNIT" end
function isGroup( value ) return  isTable(value) and value.ClassName == "GROUP" end

local feetPerNauticalMile = 6076.1155

function Debug( message )
    BASE:E(message)
    if (DCAFCore.DebugToUI) then
      MESSAGE:New("DBG: "..message):ToAll()
    end
  end
  
  
local NoMessage = "_none_"


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
    handler = triggerZoneEventDispatcher

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
function GetSuperiority( a, b )
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