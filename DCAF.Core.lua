-- //CodeWordseAvailability///////////////////////////////////////////////////////////////////////////////////////////////////
--                                     DCAF.Core - The DCAF Lua foundation (relies on MOOSE)
--                                              Digital Coalition Air Force
--                                                        2022
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

DCAF.DateTime = {
    ClassName = "DCAF.DateTime",
    Year = nil,         -- #number
    Month = nil,        -- #number
    Day = nil,          -- #number
    Hour = 0,           -- #number
    Minute = 0,         -- #number
    Second = 0,         -- #number
    IsDST = false       -- #bool - true = is Daylight Saving time
}

DCAF.Smoke = {
    ClassName = "DCAF.Smoke",
    Color = SMOKECOLOR.Red,
    Remaining = 1
}

DCAF.Flares = {
    ClassName = "DCAF.Flares",
    Color = SMOKECOLOR.Red,
    Remaining = 1
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

function DCAF.clone(template, deep, suppressDebugData)
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
        if not isBoolean(suppressDebugData) or suppressDebugData == false then
            return with_debug_info(cloned)
        end
    end
    return cloned
end

local function resolveSource(source)
    if isTable(source) then
        return source end

    local obj = getUnit(source)
    if obj then
        return obj end

    obj = getGroup(source)
    if obj then 
        return obj end

end

function DCAF.tagGet(source, key)
    local obj = resolveSource(source)
    if not obj then 
        return end

    if not isTable(obj.DCAF) then
        return end

    return obj.DCAF[key]
end

function DCAF.tagSet(source, key, value)
    local obj = resolveSource(source)
    if not obj then
        error("DCAF.tagSet :: could not resolve `source`: " .. DumpPretty(source)) end

    if not isTable(obj.DCAF) then
        obj.DCAF = {}
    end
    obj.DCAF[key] = value
    return value, obj
end

function DCAF.tagEnsure(source, key, value)
    local obj = resolveSource(source)
    if not obj then
        error("DCAF.tagEnsure :: could not resolve `source`: " .. DumpPretty(source)) end

    if not isTable(obj.DCAF) then
        obj.DCAF = {}
    end
    if obj.DCAF[key] ~= nil then
        return obj.DCAF[key], obj end

    obj.DCAF[key] = value
    return value, obj
end

VariableValue = {
    ClassName = "VariableValue",
    Value = 100,           -- #number - fixed value)
    Variance = nil         -- #number - variance (0.0 --> 1.0)
}

function isString( value ) return type(value) == "string" end
function isBoolean( value ) return type(value) == "boolean" end
function isNumber( value ) return type(value) == "number" end
function isTable( value ) return type(value) == "table" end
function isFunction( value ) return type(value) == "function" end
function isClass( value, class ) return isTable(value) and value.ClassName == class end
function isUnit( value ) return isClass(value, UNIT.ClassName) end
function isGroup( value ) return isClass(value, GROUP.ClassName) end
function isZone( value ) return isClass(value, ZONE.ClassName) or isClass(value, ZONE_POLYGON_BASE.ClassName) or isClass(value, ZONE_POLYGON.ClassName) end
function isCoordinate( value ) return isClass(value, COORDINATE.ClassName) end
function isVec2( value ) return isClass(value, POINT_VEC2.ClassName) end
function isVec3( value ) return isClass(value, POINT_VEC3.ClassName) end
function isAirbase( value ) return isClass(value, AIRBASE.ClassName) end
function isStatic( value ) return isClass(value, STATIC.ClassName) end
function isVariableValue( value ) return isClass(value, VariableValue.ClassName) end

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

function isListOfAssignedStrings(list, ignoreFunctions)
    if not isList(list) then
        return false end

    if not isBoolean(ignoreFunctions) then
        ignoreFunctions = true
    end
    for _, v in ipairs(list) do
        if not ignoreFunctions and isFunction(v) then
            return false end

        if not isAssignedString(v) then
            return false end
    end
    return true
end

function isDictionary( value ) 
    local tableType = getTableType(value)
    return tableType == "dictionary"
end

function listClone(table, deep, startIndex, endIndex)
    if not isList(table) then
        error("tableClone :: `table` must be a list") end
    if not isBoolean(deep) then
        deep = false end
    if not isNumber(startIndex) then
        startIndex = 1  end
    if not isNumber(endIndex) then
        endIndex = #table end
    
    local clone = {}
    local index = 1
    for i = startIndex, endIndex, 1 do
        clone[index] = table[i]
        index = index+1
    end
    return clone
end

function listReverse(list)
    if not isList(list) then
        error("tableClone :: `list` must be a list, but was " .. type(list)) end

    local reversed = {}
    local r = 1
    for i = #list, 1, -1 do
        table.insert(reversed, list[i])
    end
    return reversed
end

function isAssignedString( value )
    if not isString(value) then
        return false end

    return string.len(value) > 0 
end

Skill = {
    Average = "Average",
    High = "High",
    Good = "Good",
    Excellent = "Excellent",
    Random = "Random"
}

function Skill.Validate(value)
    if not isAssignedString(value) then
        return false end

    local testValue = string.lower(value)
    for k, v in pairs(Skill) do
        if isAssignedString(v) and string.lower(v) == testValue then
            if v == Skill.Random then
                local i = math.random(4)
                if i == 1 then
                    return Skill.Average
                elseif i == 2 then
                    return Skill.High
                elseif i == 3 then
                    return Skill.Good
                elseif i == 4 then
                    return Skill.Excellent
                end
            end
            return v
        end
    end
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
        return name end

    -- indexer now have format: <group indexer>-<unit indexer> (eg. "001-2", for second unit of first spawned group)
    local dashAt = string.find(indexer, '-')
    if not dashAt then
        -- should never happen, but ...
        return name end
    
    local unitIndex = string.sub(indexer, dashAt+1)
    return groupName,AirTurningPoint
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

    -- check for spawned pattern (eg. "Unit-1#001-1") ...
    local i = string.find(name, "#%d")
    if i then
        local test, instanceElement = trimInstanceFromName(name, i)
        if test == templateName then
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

function MachToKnots(mach)
    if not isNumber(mach) then
        error("MachToKnots :: `mach` must be a number but was : " .. type(mach)) end

    return 666.738661 * mach
end

function getMaxSpeed(source)

    local function getUnitMaxSpeed(unit)
        local unitDesc = Unit.getDesc(unit:GetDCSObject())
        return unitDesc.speedMax
-- Debug("nisse - getMaxSpeed :: dcsUnit: (" .. unit.UnitName .. ") " .. DumpPrettyDeep(unitDesc))        
--         local velocityVec3 = dcsUnitDesc:getVelocity()
--         local velocity = math.abs( velocityVec3.x ) + math.abs( velocityVec3.y ) + math.abs( velocityVec3.z )
--         return velocity, unit
    end

    local unit = getUnit(source)
    if unit then
        return getUnitMaxSpeed(unit)
    end

    local group = getGroup(source)
    if not group then
        error("getMaxSpeed :: cannot resolve neither #UNIT nor #GROUP from `source: `" .. DumpPretty(source)) end

    local slowestMaxSpeed = 999999
    local slowestUnit
    for _, u in ipairs(group:GetUnits()) do
        local speedMax = getUnitMaxSpeed(u)
        if speedMax < slowestMaxSpeed then
            slowestMaxSpeed = speedMax
            slowestUnit = u
        end
    end
    return slowestMaxSpeed, slowestUnit
end

function Hours(seconds)
    if isNumber(seconds) then
        return seconds * 3600
    end
end

function Angels(angels)
    if isNumber(angels) then
        return Feet(angels * 1000)
    end
end

function Minutes(seconds)
    if not isNumber(seconds) then
        error("Minutes :: `value` must be a number but was " .. type(value)) end
        
    return seconds * 60
end

function Hours(value)
    if not isNumber(seconds) then
        error("Hours :: `value` must be a number but was " .. type(value)) end

    return value * 3600
end

function NauticalMiles( nm )
    if (not isNumber(nm)) then error("Expected 'nm' to be number") end
    return MetersPerNauticalMile * nm
end

function ReciprocalAngle(angle)
    return (angle + 180) % 360
end

function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function inString( s, pattern )
    return string.find(s, pattern ) ~= nil 
end

function newString(pattern, count)
    if not isAssignedString(pattern) then
        error("newString :: `pattern` must be an assigned string, but was: " .. DumpPretty(pattern)) end

    if not isNumber(count) then
        error("newString :: `count` must be a number, but was: " .. type(count)) end

    local s = pattern
    for i = 1, count-1, 1 do
        s = s .. pattern
    end
    return s
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
        count = count+1
        if itemSerializeFunc then
            s = s .. itemSerializeFunc(v)
        else
            if v == nil then
                s = s .. 'nil'
            elseif v.ToString then
                s = s .. v:ToString()
            else
                s = s .. tostring(v)
            end
        end
    end
    return s
end

function listCopy(source, target, sourceStartIndex, targetStartIndex)
    if not isNumber(sourceStartIndex) then
        sourceStartIndex = 1
    end
    if not isTable(target) then
        target = {}
    end
    if isNumber(targetStartIndex) then
        for i = sourceStartIndex, #source, 1 do
            table.insert( target, targetStartIndex, source[i] )
            targetStartIndex = targetStartIndex+1
        end
    else
        for i = sourceStartIndex, #source, 1 do
            table.insert( target, source[i] )
        end
    end
    return target, #target
end

function listJoin(list, otherList)
    if not isList(list) then
        error("listJoin :: `list` must be a list, but was: " .. type(list)) end

    if not isList(otherList) then
        error("listJoin :: `otherList` must be a list, but was: " .. type(otherList)) end

    local newList = {}
    for _, v in ipairs(list) do
        table.insert(newList, v)
    end
    for _, v in ipairs(otherList) do
        table.insert(newList, v)
    end
    return newList
end

-- function listIndexOf(list, item)
--     if not isList(list) then
--         error("listIndexOf :: unexpected type for table: " .. type(list)) end
    
--     if item == nil then
--         error("listIndexOf :: item was unassigned") end
-- end

function tableCopy(source, target, deep)
    local count = 0
    if not isTable(target) then
        target = {}
    end
    for k,v in pairs(source) do
        if target[k] == nil then
            -- if isTable(v) then
            --     target[k] = routines.utils.deepCopy(v)
            -- else
                target[k] = v
            -- end
        end
        count = count + 1
    end
    return target, count
end

function tableIndexOf( table, itemOrFunc )
    if not isTable(table) then
        error("tableIndexOf :: unexpected type for table: " .. type(table)) end

    if itemOrFunc == nil then
        error("tableIndexOf :: item was unassigned") end

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
        error("tableKeyOf :: unexpected type for table: " .. type(table)) end

    if item == nil then
        error("tableKeyOf :: item was unassigned") end

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

function dictCount(table)
    if not isTable(table) then
        error("dictionaryCount :: `table` is of type " .. type(table)) end
    
    local count = 0
    for k, v in pairs(table) do
        count = count+1
    end
    return count
end

function listRandomItem(list, ignoreFunctions)
    if not isTable(list) then
        error("tableRandomItem :: `list` must be table but was " .. type(list)) end

    if not isBoolean(ignoreFunctions) then
        ignoreFunctions = true
    end
    local index = math.random(#list)
    local item = list[index]
    while ignoreFunctions and isFunction(item) do
        index = math.random(#list)
        item = list[index]
    end
    return item, index
end

function dictRandomKey(table, maxIndex, ignoreFunctions)
-- Debug("nisse - dictRandomKey :: table: " .. DumpPretty(table))

    if not isTable(table) then
        error("dictRandomKey :: `table` is of type " .. type(table)) end

    if not isNumber(maxIndex) then
        maxIndex = dictCount(table)
    end
    if not isBoolean(ignoreFunctions) then
        ignoreFunctions = true
    end

    local function getRandomKey()
        local randomIndex = math.random(1, maxIndex)
        local count = 1
        for key, _ in pairs(table) do
-- Debug("nisse - dictRandomKey :: key: " .. DumpPretty(key) .. " :: count: " .. Dump(count) .. " :: randomIndex: " .. Dump(randomIndex))
            if count == randomIndex then
-- Debug("nisse - dictRandomKey :: returns key: " .. DumpPretty(key))
                return key
            end
            count = count + 1
        end
    end

    local key = getRandomKey()
    while ignoreFunctions and isFunction(table[key]) do
        key = getRandomKey()
    end
    return key    
end

function dictGetKeyFor(table, criteria)
    if not isTable(table) then
        error("dictGetKeyFor :: `table` is of type " .. type(table)) end

    for key, v in pairs(table) do
        if isAssignedString(criteria) and criteria == v then
            return key end

        if isFunction(criteria) and criteria(v) then
            return key end
    end
end

function VariableValue:New(value, variance)
    if not isNumber(value) then
        error("VariableValue:New :: `value` must be a number but was " .. type(value)) end

    if isNumber(variance) then
        if variance < 0 or variance > 1 then
            error("VariableValue:New :: `variance` must be a number between 0 and 1.0, but was " .. Dump(variance)) end
    else
        variance = math.max(1, math.abs(variance))
    end
    
    local vv = DCAF.clone(VariableValue)
    vv.Value = value
    vv.Variance = variance
    return vv
end

function VariableValue:NewRange(min, max, minVariance, maxVariance)
    if not isNumber(min) then
        error("VariableValue:New :: `min` must be a number but was " .. type(min)) end
    if not isNumber(max) then
        error("VariableValue:New :: `max` must be a number but was " .. type(max)) end
    if minVariance ~= nil and not isNumber(minVariance) then
        error("VariableValue:New :: `minVariance` must be a number but was " .. type(minVariance)) end
    if maxVariance ~= nil and not isNumber(maxVariance) then
        error("VariableValue:New :: `maxVariance` must be a number but was " .. type(maxVariance)) end
        
    if min > max then
        min, max = swap(min, max)
    elseif min == max then
        return VariableValue:New(min, minVariance)
    end

    local vv = DCAF.clone(VariableValue)
    vv.MinValue = min
    vv.MaxValue = max
    vv.MinVariance = minVariance
    vv.MaxVariance = maxVariance
    return vv
end

function VariableValue:GetValue()
    local function getValue(value, variance)
        if variance == nil or variance == 0 then
            return value end

        local rndVar = math.random(variance * 100) / 100
        local var = rndVar * value
        if math.random(100) <= 50 then
            return value - var
        else
            return value + var
        end
    end

    local function getBoundedValue()
        local minValue = getValue(self.MinValue, self.MinVariance)
        local maxValue = getValue(self.MaxValue, self.MaxVariance or self.MinVariance)
        return math.random(minValue, maxValue )
    end

    if self.MinValue then
        return getBoundedValue()
    end
    return getValue(self.Value, self.Variance)
end

function Vec3_FromBullseye(aCoalition)
    local testCoalition = Coalition.Resolve(aCoalition, true)
    if isNumber(testCoalition) then
-- Debug("nisse - Vec3_FromBullseye :: gets bullseye for coalition: " .. Dump(aCoalition))
        return coalition.getMainRefPoint(testCoalition)
    end
end

function ParseTACANChannelAndMode(text, defaultMode)
    local sChannel = text:match("[0-9]*")
    if not isAssignedString(sChannel) then
        return end

    local mode = text:match("[X,Y]")
    if not isAssignedString(mode) then
        if not isAssignedString(defaultMode) then
            defaultMode = "X"
        else
            local test = string.upper(defaultMode)
            if test ~= 'X' and test ~= 'Y' then
                error("ParseTACANChannelAndMode :: `defaultMode` must be 'X' or 'Y', but was: '" .. mode .. "'")
            end
        end
    end
    return tonumber(sChannel), mode
end

function DCAF.DateTime:New(year, month, day, hour, minute, second)
    local date = DCAF.clone(DCAF.DateTime)
    date.Year = year
    date.Month = month
    date.Day = day
    date.Hour = hour or DCAF.DateTime.Hour
    date.Minute = minute or DCAF.DateTime.Minute
    date.Second = second or DCAF.DateTime.Second
    local t = { year = date.Year, month = date.Month, day = date.Day, hour = date.Hour, min = date.Minute, sec = date.Second }
    date._timeStamp = os.time(t)
    local d = os.date("*t", date._timeStamp)
    date.IsDST = d.isdst
    date.IsUTC = false
-- Debug("nisse - DCAF.DateTime:NewSignalmpPretty(date) .. " :: d: " .. DumpPretty(d))
    return date
end

function DCAF.DateTime:ParseDate(sYMD)
    local sYear, sMonth, sDay = string.match(sYMD, "(%d+)/(%d+)/(%d+)")
    return DCAF.DateTime:New(tonumber(sYear), tonumber(sMonth), tonumber(sDay))
end

function DCAF.DateTime:ParseDateTime(sYMD_HMS)
    local sYear, sMonth, sDay, sHour, sMinute, sSecond = string.match(sYMD_HMS, "(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")
    return DCAF.DateTime:New(tonumber(sYear), tonumber(sMonth), tonumber(sDay), tonumber(sHour), tonumber(sMinute), tonumber(sSecond))
end

function DCAF.DateTime:Now()
    return DCAF.DateTime:ParseDateTime(UTILS.GetDCSMissionDate() .. " " .. UTILS.SecondsToClock(UTILS.SecondsOfToday()))
end

function DCAF.DateTime:TotalHours()
    return self.Hour + self.Minute / 60 + self.Second / 3600
end

function DCAF.DateTime:AddSeconds(seconds)
    local timestamp = self._timeStamp + seconds
    local d = os.date("*t", timestamp)
    return DCAF.DateTime:New(d.year, d.month, d.day, d.hour, d.min, d.sec)
end

function DCAF.DateTime:AddMinutes(minutes)
    return self:AddSeconds(minutes * 60)
end

function DCAF.DateTime:AddHours(hours)
    return self:AddSeconds(hours * 3600)
end

function DCAF.DateTime:ToUTC()
    local diff = UTILS.GMTToLocalTimeDifference()
    if self.IsDST then
        diff = diff + 1
    end
    return self:AddHours(diff)
end

function DCAF.DateTime:ToString()
    return Dump(self.Year) .. "/" .. Dump(self.Month) .. "/" ..Dump(self.Day) .. " " .. Dump(self.Hour) .. ":" .. Dump(self.Minute) .. ":" .. Dump(self.Second)
end

local Deg2Rad = math.pi / 180.0;
local Rad2Deg = 180.0 / math.pi

function COORDINATE:SunPosition(dateTime)
    if not isClass(dateTime, DCAF.DateTime.ClassName) then
        dateTime = DCAF.DateTime:Now()--:ToUTC()
    end
    if dateTime.IsDST then
        dateTime = dateTime:AddHours(-1)
    end
    -- Get latitude and longitude as radians
    local latitude, longitude = self:GetLLDDM()
    latitude = math.rad(latitude)
    longitude = math.rad(longitude)

    local function correctAngle(angleInRadians)
        if angleInRadians < 0 then
            return 2 * math.pi - (math.abs(angleInRadians) % (2 * math.pi)) end
        if angleInRadians > 2 * math.pi then
            return angleInRadians % (2 * math.pi) end

        return angleInRadians
    end

    local julianDate = 367 * dateTime.Year -
            ((7.0 / 4.0) * (dateTime.Year +
                    ((dateTime.Month + 9.0) / 12.0))) +
            ((275.0 * dateTime.Month) / 9.0) +
            dateTime.Day - 730531.5
    local julianCenturies = julianDate / 36525.0
    local siderealTimeHours = 6.6974 + 2400.0513 * julianCenturies
    local siderealTimeUT = siderealTimeHours + (366.2422 / 365.2422) * dateTime:TotalHours()
    local siderealTime = siderealTimeUT * 15 + longitude
    -- Refine to number of days (fractional) to specific time.
    julianDate = julianDate + dateTime:TotalHours()
    julianCenturies = julianDate / 36525.0

    -- Solar Coordinates
    local meanLongitude = correctAngle(Deg2Rad * (280.466 + 36000.77 * julianCenturies))
    local meanAnomaly = correctAngle(Deg2Rad * (357.529 + 35999.05 * julianCenturies))
    local equationOfCenter = Deg2Rad * ((1.915 - 0.005 * julianCenturies) * math.sin(meanAnomaly) + 0.02 * math.sin(2 * meanAnomaly))
    local elipticalLongitude = correctAngle(meanLongitude + equationOfCenter)
    local obliquity = (23.439 - 0.013 * julianCenturies) * Deg2Rad

    -- Right Ascension
    local rightAscension = math.atan(
            math.cos(obliquity) * math.sin(elipticalLongitude),
            math.cos(elipticalLongitude))
    local declination = math.asin(math.sin(rightAscension) * math.sin(obliquity))

    -- Horizontal Coordinates
    local hourAngle = correctAngle(siderealTime * Deg2Rad) - rightAscension
    if hourAngle > math.pi then
        hourAngle = hourAngle - 2 * math.pi
    end

    local altitude = math.asin(math.sin(latitude * Deg2Rad) *
            math.sin(declination) + math.cos(latitude * Deg2Rad) *
            math.cos(declination) * math.cos(hourAngle))

    -- Nominator and denominator for calculating Azimuth
    -- angle. Needed to test which quadrant the angle is in.
    local aziNominator = -math.sin(hourAngle);
    local aziDenominator = math.tan(declination) * math.cos(latitude * Deg2Rad) - math.sin(latitude * Deg2Rad) * math.cos(hourAngle)
    local azimuth = math.atan(aziNominator / aziDenominator)
    if aziDenominator < 0 then -- In 2nd or 3rd quadrant
        azimuth = azimuth + math.pi
    elseif (aziNominator < 0) then -- In 4th quadrant
        azimuth = azimuth + 2 * math.pi
    end
    return altitude * Rad2Deg, azimuth * Rad2Deg
end

function COORDINATE:GetFlatArea(flatAreaSize, searchAreaSize, excludeSelf, maxInclination)
    if not isNumber(flatAreaSize) then
        error("COORDINATE:GetFlatArea :: `radius` must be number, but was: " .. DumpPretty(flatAreaSize)) end

    if not isNumber(searchAreaSize) then
        searchAreaSize = 200 
    end
    if not isBoolean(excludeSelf) then
        excludeSelf = false
    end
    searchAreaSize = math.max(searchAreaSize, flatAreaSize)
    if not isNumber(maxInclination) then
        maxInclination = 0.06
    end
    maxInclination = math.max(0.005, maxInclination)
    if not excludeSelf then
        local inclination = self:GetLandInclination(flatAreaSize)
        if inclination <= maxInclination then
            return self end
    end

    local function searchSquareEdge(searchSize) -- 1, 2, 3... (eg. 2 = `flatAreaSize` x 2)
        local coord = self:Translate(flatAreaSize * searchSize, 360):Translate(flatAreaSize * searchSize, 270)
        local function searchHeading(hdg)
            for i = 1, searchSize*2, 1 do
                coord = coord:Translate(flatAreaSize, hdg)
                local inclination = coord:GetLandInclination(flatAreaSize)
                if inclination <= maxInclination then
                    return coord end
            end
        end

        for _, hdg in ipairs({90, 180, 270, 360}) do
            local coordFlat = searchHeading(hdg)
            if coordFlat then
                return coordFlat end
        end
    end

    local maxSearchSize = searchAreaSize / flatAreaSize
    for size = 1, maxSearchSize, 1 do
        local coord = searchSquareEdge(size)
        if coord then
            return coord end
    end
end

function COORDINATE:GetLandInclination(gridSizeX, gridSizeY, measureInterval)
    if not isNumber(gridSizeX) then
        gridSizeX = 200 -- meters
    end
    if not isNumber(gridSizeY) then
        gridSizeY = gridSizeX
    end
    if not isNumber(measureInterval) then
        measureInterval = math.max(gridSizeX, gridSizeY) / 10 -- 10 measurepoints 
    end

    local heightMin = 9999999999
    local coordMin
    local heightMax = 0
    local coordMax
    local function measureHeight(coord)
        local height = coord:GetLandHeight()
        if height < heightMin then
            heightMin = height;
            coordMin = coord
        end
        if height > heightMax then
            heightMax = height
            coordMax = coord
        end
    end

    local coordX = self:Translate(gridSizeX / 2, 360):Translate(gridSizeY / 2, 270)
    measureHeight(coordX)
    for x = measureInterval, gridSizeX - measureInterval, measureInterval do
        for y = measureInterval, gridSizeY - measureInterval, measureInterval do
            local coordY = coordX:Translate(y, 180)
            measureHeight(coordY)
        end
        coordX = coordX:Translate(x, 90)
        measureHeight(coordX)
    end

    local distMinMax = coordMin:Get2DDistance(coordMax)
    local heightDifference = heightMax - heightMin
    return heightDifference / distMinMax
end

function COORDINATE_FromWaypoint(wp)
    return COORDINATE:New(wp.x, wp.alt, wp.y)
end

function COORDINATE_FromBullseye(aCoalition)
    local vec3 = Vec3_FromBullseye(aCoalition)
    if vec3 then
        return COORDINATE:NewFromVec3(vec3)
    end
end

function DCAF.GetBullseye(location, aCoalition)
    local testLocation = DCAF.Location.Resolve(location)
    if not testLocation then
        error("DCAF.GetBullseye :: cannot resolve `location` from: " .. DumpPretty(location)) end

    local be = COORDINATE:NewFromVec3(Vec3_FromBullseye(aCoalition))
    local coord = location:GetCoordinate()
    local bearing = be:HeadingTo(coord)
    local distance = be:Get2DDistance(coord)
    return bearing, UTILS.MetersToNM(distance), DCAF.GetBullseyeName(aCoalition)
end

function DCAF.GetBullseyeText(location, aCoalition)
    local beBearing, beDistance, beName = DCAF.GetBullseye(location, aCoalition)
    return string.format("%s %d %d", beName, beBearing, beDistance)
end

function DCAF.InitBullseyeName(sName, aCoalition)
    if aCoalition == nil then
        aCoalition = Coalition.Blue
    else
        aCoalition = Coalition.Resolve(aCoalition)
        if not aCoalition then
            error("DCAF.InitBullseyeName :: cannot resolve `aCoalition` from: " .. DumpPretty(aCoalition)) end
    end

    if not DCAF.BullseyeNames then
        DCAF.BullseyeNames = {}
    end
    DCAF.BullseyeNames[aCoalition] = sName
end

function DCAF.GetBullseyeName(aCoalition)
    if aCoalition == nil then
        aCoalition = Coalition.Blue
    else
        local testCoalition = Coalition.Resolve(aCoalition)
        if not testCoalition then
            error("DCAF.InitBullseyeName :: cannot resolve `aCoalition` from: " .. DumpPretty(aCoalition)) end
        
        aCoalition = testCoalition
    end
    if DCAF.BullseyeNames and DCAF.BullseyeNames[aCoalition] then
        return DCAF.BullseyeNames[aCoalition]
    else
        return "BULLSEYE" 
    end
end

function Debug_DrawWaypoints(waypoints)
    if not isTable(waypoints) then
        return end

    for _, wp in ipairs(waypoints) do
        local coord = COORDINATE_FromWaypoint(wp)
        coord:CircleToAll(nil, nil, nil, nil, nil, nil, nil, nil, wp.name)
    end
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
    if isVariableValue(seconds) then
        seconds = seconds:GetValue()
    end
    if not isNumber(seconds) then error("Delay :: `seconds` must be #number or #VariableValue, but was: " .. DumpPretty(seconds)) end
    if not isFunction(userFunction) then error("Delay :: `userFunction` must be function, but was: " .. type(userFunction)) end
    
    if seconds == 0 then
        userFunction(data)
        return 
    end

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

AiSkill = {
    Average = "Average", 
    Good = "Good", 
    High = "High", 
    Excellent = "Excellent"
}

function Coalition.Resolve(value, returnDCS)
    local resolvedCoalition
    if isAssignedString(value) then
        local test = string.lower(value)
        if test == Coalition.Blue then resolvedCoalition = Coalition.Blue 
        elseif test == Coalition.Red then resolvedCoalition = Coalition.Red
        elseif test == Coalition.Neutral then resolvedCoalition = Coalition.Neutral end
    elseif isList(value) then
        local isValid, coalition
        for _, v in ipairs(value) do
            resolvedCoalition = Coalition.Resolve(v)
            if resolvedCoalition then
                break end
        end
        return resolvedCoalition
    elseif isNumber(value) then
        if value == coalition.side.BLUE then
            resolvedCoalition = Coalition.Blue 
        elseif value == coalition.side.RED then
            resolvedCoalition = Coalition.Red
        elseif value == coalition.side.NEUTRAL then
            resolvedCoalition = Coalition.Neutral
        end
    elseif isGroup(value) or isUnit(value) then
        return Coalition.Resolve(value:GetCoalition())
    end
    if resolvedCoalition and returnDCS then
        if resolvedCoalition == Coalition.Blue then return coalition.side.BLUE end
        if resolvedCoalition == Coalition.Red then return coalition.side.RED end
        if resolvedCoalition == Coalition.Neutral then return coalition.side.NEUTRAL end
    else
        return resolvedCoalition
    end
end

function Coalition.ToNumber(coalitionValue)
    if not isAssignedString(coalitionValue) then
        error("Coalition.ToNumber :: `coalition` must be string (but was " .. type(coalitionValue) .. ")")
    end
    local c = string.lower(coalitionValue)
    if c == Coalition.Blue then return coalition.side.BLUE end
    if c == Coalition.Red then return coalition.side.RED end
    if c == Coalition.Neutral then return coalition.side.NEUTRAL end
    error("Coalition.ToNumber :: unrecognized `coalition` name: '" .. coalitionValue .. "'")
    return -1
end

function Coalition.FromNumber(coalitionValue)
    if coalitionValue == coalition.side.RED then
        return Coalition.Red end

    if coalitionValue == coalition.side.BLUE then
        return Coalition.Blue end
        
    if coalitionValue == coalition.side.NEUTRAL then
        return Coalition.Neutral end
end

function Coalition.Equals(a, b)
    if isAssignedString(a) then
        a = Coalition.ToNumber(a)
    elseif not isNumber(a) then
        error("Coalition.Equals :: `a` must be string or number (but was " .. type(a) .. ")")
    end
    if isAssignedString(b) then
        b = Coalition.ToNumber(b)
    elseif not isNumber(b) then
        error("Coalition.Equals :: `b` must be string or number (but was " .. type(b) .. ")")
    end
    return a == b    
end

function Coalition.IsAny(coalition, table)
    if not isTable(table) then
        error("Coalition.IsAny :: `table` must be string or number (but was " .. type(table) .. ")")
    end
    for _, c in ipairs(table) do
        if Coalition.Equals(coalition, c) then
            return true
        end
    end
end

function GroupType.IsValid(value, caseSensitive)
    if not isBoolean(caseSensitive) then
        caseSensitive = false
    end
    if isString(value) then
        local test
        if caseSensitive then
            test = value
        else
            test = string.lower(value)
        end
        return test == GroupType.Air
            or test == GroupType.Airplane
            or test == GroupType.Ground
            or test == GroupType.Ship
            or test == GroupType.Structure
    elseif isList(value) then
        for _, v in ipairs(value) do
            if not GroupType.IsValid(v) then
                return false end
        end
        return true
    end
end

function GroupType.IsAny(groupType, table)
    if not isTable(table) then
        error("GroupType.IsAny :: `table` must be string or number (but was " .. type(table) .. ")")
    end
    for _, gt in ipairs(table) do
        if groupType == gt then
            return true
        end
    end
end

function DCAF.Smoke:New(remaining, color)
    if not isNumber(remaining) then
        remaining = 1
    end
    if not isNumber(color) then
        color = SMOKECOLOR.Red
    end
    local smoke = DCAF.clone(DCAF.Smoke)
    smoke.Color = color
    smoke.Remaining = remaining
    return smoke
end

function DCAF.Flares:Shoot(coordinate)
    if not isCoordinate(coordinate) then
        error("DCAF.Flares:Shoot :: `coordinate` must be " .. COORDINATE.ClassName .. ", but was: " .. DumpPretty(coordinate)) end

    if self.Remaining == 0 then
        return end

-- Debug("nisse - DCAF.Flares:Shoot!")
-- MessageTo(nil, "nisse - DCAF.Flares:Shoot!")

    coordinate:Flare(self.Color)
    self.Remaining = self.Remaining-1
    return self
end

function DCAF.Flares:New(remaining, color)
    if not isNumber(remaining) then
        remaining = 1
    end
    if not isNumber(color) then
        color = SMOKECOLOR.Red
    end
    local smoke = DCAF.clone(DCAF.Flares)
    smoke.Color = color
    smoke.Remaining = remaining
    return smoke
end

-- @smoke       :: #DCAF.Smoke
function DCAF.Smoke:Pop(coordinate, color)
    if not isCoordinate(coordinate) then
        error("DCAF.Smoke:Pop :: `coordinate` must be " .. COORDINATE.ClassName .. ", but was: " .. DumpPretty(coordinate)) end

    if self.Remaining == 0 then
        return end

-- Debug("nisse - DCAF.Smoke:Pop!")
-- MessageTo(nil, "nisse - DCAF.Smoke:Pop!")

    coordinate:Smoke(color or self.Color)
    self.Remaining = self.Remaining-1
    return self
end


local SPAWNS = { -- dictionary
    -- key   = template name
    -- value = #SPAWN
}

function getSpawn(name)
    local function f()
        local spawn = SPAWNS[name]
        if spawn then return
            spawn end
        spawn = SPAWN:New(name)
        SPAWNS[name] = spawn
        return spawn
    end

    local success, spawn = pcall(f)
    if success then 
        return spawn end
end

function getSpawnWithAlias(name, alias)
    local function f()
        local key = name .. "::" .. alias
        local spawn = SPAWNS[key]
        if spawn then return
            spawn end
        spawn = SPAWN:NewWithAlias(name, alias)
        SPAWNS[key] = spawn
        return spawn
    end

    local success, spawn = pcall(f)
    if success then 
        return spawn end
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
    if (not isAssignedString(source)) then 
        return end

    local group = GROUP:FindByName( source )
    if (group ~= nil) then 
        return group 
    end
    local unit = UNIT:FindByName( source )
    if (unit ~= nil) then 
        return unit:GetGroup() 
    end
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

function getStatic( source )
    if isStatic(source) then
        return source end
    if not isAssignedString(source) then
        return end

    local static
    pcall(function() 
        static = STATIC:FindByName(source)
    end)
    return static
end

function getAirbase( source )
    if isClass(source, AIRBASE.ClassName) then
        return source end
        
    if isAssignedString(source) then
        return AIRBASE:FindByName(source) end

    if isNumber(source) then
        return AIRBASE:FindByID(source) end
end

function getZone( source )
Debug("nisse - getZone :: source: " .. DumpPretty(source))
    if isZone(source) then
        return source end

    if not isAssignedString(source) then
        return end

    local zone = ZONE:FindByName(source)
Debug("nisse - getZone :: source: " .. source .. " :: zone: " .. Dump(zone~=nil))
    return zone
end

function activateNow( source )
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

function COORDINATE:EnsureY(useDefaultY)
    if self.y == nil then
        self.y = useDefaultY or 0
    end
    return self
end

function COORDINATE:GetBearingTo(coordinate)
    local from = self:EnsureY()
    coordinate = coordinate:EnsureY()
    local dirVec3 = from:GetDirectionVec3(coordinate)
    local bearing = from:GetAngleDegrees(dirVec3)
    return bearing
end

DCAF.Location = {
    ClassName = "DCAF.Location", 
    Name = nil,        -- #string 
    Source = nil,      -- #COORDINATE, #GROUP, #AIRBASE, or #STATIC
    Coordinate = nil   -- COORDINATE
}

function DCAF.Location:NewNamed(name, source, throwOnFail)
-- Debug("nisse - DCAF.Location:NewNamed :: source: " .. DumpPretty(source))

    if source == nil then
        error("DCAF.Location:New :: `source` cannot be unassigned") end

    if not isBoolean(throwOnFail) then
        throwOnFail = true
    end
    local location = DCAF.clone(DCAF.Location)
    location.Source = source
    location.IsAir = false
    if isCoordinate(source) then
        location.Coordinate = source
        location.Name = source:ToStringLLDDM()
        return location
    elseif isZone(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = source:GetName()
        return location
    elseif isVec2(source) then
        location.Coordinate = COORDINATE:NewFromVec2(source)
        location.Name = "(x="..Dump(source.x)..",y=" .. Dump(source.y) .. ")"
        return location
    elseif isVec3(source) then
        location.Coordinate = COORDINATE:NewFromVec3(source)
        location.Name = "(x="..Dump(source.x)..",y=" .. Dump(source.y) .. ", z=" .. Dump(source.z) .. ")"
        return location
    elseif isAirbase(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = source.AirbaseName
        location.IsAir = false
        -- location.IsAirdrome = true
        return location
    elseif isGroup(source) or isUnit(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = source.GroupName
        location.IsAir = source:IsAir()
        location.IsControllable = true
        return location
    elseif isStatic(source) then
        location.Coordinate = source:GetCoordinate()
        location.Name = source.GroupName
        location.IsStatic = true
        return location
    else
        -- try resolve source...
        local zone = getZone(source)
        if zone then return DCAF.Location:New(zone) end
        local group = getGroup(source)
        if group then return DCAF.Location:New(group) end
        local unit = getUnit(source)
        if unit then return DCAF.Location:New(unit) end
        local airbase = getAirbase(source)
        if airbase then return DCAF.Location:New(airbase) end
        local static = getStatic(source)
        if static then return DCAF.Location:New(static) end
        if throwOnFail then
            error("DCAF.Location:New :: `source` is unexpected value: " .. DumpPretty(source))
        end
    end
end

function DCAF.Location:New(source, throwOnFail)
    return DCAF.Location:NewNamed(nil, source, throwOnFail)
end

function DCAF.Location.Resolve(source)
    if isClass(source, DCAF.Location.ClassName) then
        return source end

    local d = DCAF.Location:New(source, false)
    if d then
        return d
    end
end

function DCAF.Location:GetCoordinate()
    return self.Coordinate
end

function DCAF.Location:Translate(distance, angle, keepAltitude)
    return DCAF.Location:New(self.Coordinate:Translate(distance, angle, keepAltitude))
end

function DCAF.Location:GetAGL()
    if isUnit(self.Source) or isGroup(self.Source) then
        return self.Source:GetAltitude(true)
    end

    return self.Coordinate.y - self.Coordinate:GetLandHeight()
end

--- Examines a 'location' and returns a value to indicate it is airborne
-- See also: DCAF.Location:IsGrounded()
function DCAF.Location:IsAirborne(errorMargin)
    if not self.IsAir then
        return false 
    end
    if not isNumber(errorMargin) then
        errorMargin = 5
    end
    return self.Source:IsAirborne()
    -- return self:GetAGL() > errorMargin
end

--- Examines a 'location' and returns a value to indicate it is "grounded" (not airborne)
-- See also: DCAF.Location:IsAirborne()
function DCAF.Location:IsGrounded(errorMargin)
    return not self:IsAirborne(errorMargin)
end

DCAF.ClosestUnits = {
    ClassName = "DCAF.ClosestUnits",
    Count = 0,
    Units = { -- dictionary 
        -- key = #Coalition
        -- value = { Unit = #UNIT, Distance = #number (meters)}
    }
}

function DCAF.ClosestUnits:New()
    return DCAF.clone(DCAF.ClosestUnits)        
end

function DCAF.ClosestUnits:Get(coalition)
    local testCoaliton = Coalition.Resolve(coalition)
    if not testCoaliton then
        error("DCAF.ClosestUnits:Get :: cannot resolve #Coalition from: " .. DumpPretty(coalition)) end

    return self.Units[testCoaliton]
end

function DCAF.ClosestUnits:Set(unit, distance)
    local coalition = Coalition.Resolve(unit:GetCoalition())
    local info = self.Units[coalition]
    if not info then
        info = { Unit = unit, Distance = distance }
        self.Units[coalition] = info
        self.Count = self.Count+1
    else
        info.Unit = unit
        info.Distance = distance
    end
    return self
end

--- Gets the closest units for specified coalition(s)
-- @maxDistance : #numeric (meters)
-- @coalitions : #Coalition (#string), #number (DCS) or table of these types
-- returns #DCAF.ClosestUnits
function DCAF.Location:GetClosestUnits(maxDistance, coalitions, filterFunc)

-- Debug("nisse - DCAF.Location:GetClosestUnits :: " .. DumpPretty(coalitions))
if #coalitions > 0 and isNumber(coalitions[1]) then
    error("NISSE!") end


    if not isNumber(maxDistance) then
        maxDistance = NauticalMiles(50)
    end
    local isMultipleCoalitions = false
    if isNumber(coalitions) then
        local testCoalition = Coalition.Resolve(coalitions)
        if not testCoalition then
            error("DCAF.Location:GetClosestUnit :: cannot resolve coalition from: " .. DumpPretty(coalitions)) end
        
        coalitions = testCoalition
    elseif isList(coalitions) then
        local cList = {}
        for i, c in ipairs(coalitions) do
            local testCoalition = Coalition.Resolve(c)
            if not testCoalition then
                error("DCAF.Location:GetClosestUnit :: cannot resolve coalition #" .. Dump(i) .. "; from: " .. DumpPretty(c)) end
            
            table.insert(cList, testCoalition)
        end
        if #cList > 1 then
            coalitions = cList
            isMultipleCoalitions = true
        else
            coalitions = cList[1]
        end
    else
        local testCoalition = Coalition.Resolve(coalitions)
        if not testCoalition then
            error("DCAF.Location:GetClosestUnit :: cannot resolve coalition from: " .. DumpPretty(coalitions)) end

        coalitions = testCoalition
    end

    local closest = DCAF.ClosestUnits:New()

    local units = self.Coordinate:ScanUnits(maxDistance)
-- Debug("DCAF.Location:GetClosestUnits :: coalitions: " .. DumpPretty(coalitions))

    local function isCoalition(unitCoalition)

-- Debug("DCAF.Location:GetClosestUnits :: unitCoalition: " .. DumpPretty(unitCoalition))

        if not isMultipleCoalitions then
            return unitCoalition == coalitions
        end
        for _, testCoalition in ipairs(coalitions) do
            if testCoalition == unitCoalition then
                return true
            end
        end
    end
    local hasFilterFunc = isFunction(filterFunc)
    units:ForEachUnit(function(u) 

-- Debug("DCAF.Location:GetClosestUnits :: unit: " .. DumpPretty(u.UnitName))

        if not u:IsAlive() then
            return end
            
        local unitCoalition = Coalition.Resolve(u:GetCoalition())
        if not isCoalition(unitCoalition) then
-- Debug("DCAF.Location:GetClosestUnits :: unit: " .. DumpPretty(u.UnitName) .. " is not filtered coalition")
            return end

        local distance = self.Coordinate:Get3DDistance(u:GetCoordinate())
        if not hasFilterFunc or filterFunc(u, distance) then
            local info = closest:Get(unitCoalition)
            if not info or info.Distance > distance then 
-- Debug("DCAF.Location:GetClosestUnits_ForEachUnit :: sets closest: " .. DumpPretty(u.UnitName) .. " : distance: " .. Dump(distance))
                closest:Set(u, distance)
            end
        end
    end)
-- Debug("DCAF.Location:GetClosestUnits_ForEachUnit :: closest: " .. DumpPretty(closest))
    return closest
end

function DCAF.Location:IsCoordinate() return isCoordinate(self.Source) end
function DCAF.Location:IsVec2() return isVec2(self.Source) end
function DCAF.Location:IsVec3() return isVec3(self.Source) end
function DCAF.Location:IsZone() return isZone(self.Source) end
function DCAF.Location:IsAirbase() return isAirbase(self.Source) end

function GetClosestFriendlyUnit(source, maxDistance, ownCoalition)
    local coord
    local unit = getUnit(source)
    if unit then 
        coord = unit:GetCoordinate()
    else
        local group = getGroup(source)
        if not group then
            error("GetClosestFriendlyUnit :: cannot resolve UNIT or GROUp from: " .. DumpPretty(source)) end

        coord = group:GetCoordinate()
    end
    if not isNumber(maxDistance) then
        maxDistance = NauticalMiles(50)
    end
    local ownCoalition = ownCoalition or unit:GetCoalition()
    local closestDistance = maxDistance
    local closestFriendlyUnit
    local units = coord:ScanUnits(maxDistance)
    for _, u in ipairs(units) do
        if u:GetCoalition() == ownCoalition then
            local distance = coord:Get3DDistance(u:GetCoordinate())
            if distance < closestDistance then
                closestDistance = distance
                closestFriendlyUnit = u
            end
        end
    end
    return closestFriendlyUnit, closestDistance
end

function GetBearingAndDistance(from, to)
    local dFrom = DCAF.Location.Resolve(from)
    if not dFrom then
        error("GetBearing :: cannot resolve `from`: " .. DumpPretty(from)) end

    local dTo = DCAF.Location.Resolve(to)
    if not dTo then
        error("GetBearing :: cannot resolve `to`: " .. DumpPretty(dTo)) end

    local fromCoord = dFrom:GetCoordinate()
    local toCoord = dTo:GetCoordinate()
    local distance = fromCoord:Get2DDistance(toCoord)
    return fromCoord:GetBearingTo(toCoord), distance
end

function COORDINATE:GetHeadingTo(location)
    local d = DCAF.Location.Resolve(location)
    if d then 
        return self:GetCoordinate():GetBearingTo(d:GetCoordinate()) end

    return errorOnDebug("COORDINATE:GetHeadingTo :: cannot resolve location: " .. DumpPretty(location))
end

-- returns : #COORDINATE (or nil)
function COORDINATE:ScanSurfaceType(surfaceType, startAngle, maxDistance, scanOutward, angleInterval, scanInterval)
    -- surfaceTye = land.SurfaceType (numeric: LAND=1, SHALLOW_WATER=2, WATER=3, ROAD=4, RUNWAY=5)
    if not isNumber(surfaceType) then
        error("COORDINATE:GetClosesSurfaceType :: `surfaceType` must be #number, but was: " .. DumpPretty(surfaceType)) end

    local testSurfaceType = self:GetSurfaceType()
    if surfaceType == testSurfaceType then
        return self end

    if not isNumber(maxDistance) then
        maxDistance = 500 
    end
    if not isBoolean(scanOutward) then
        scanOutward = false
    end
    if not isNumber(angleInterval) then
        angleInterval = 10
    end
    if not isNumber(scanInterval) then
        scanInterval = 10
    end
    if not isNumber(startAngle) then
        startAngle = math.random(360)
    end
    local distanceStart
    local distanceEnd
    if scanOutward then
        distanceStart = scanInterval
        distanceEnd = maxDistance
    else
        distanceStart = maxDistance
        scanInterval = -math.abs(scanInterval)
        distanceEnd = scanInterval
    end
    for angle = startAngle, (startAngle-1) % 360, angleInterval do
        for distance = distanceStart, distanceEnd, scanInterval do
            local coordTest = self:Translate(distance, angle)
            testSurfaceType = coordTest:GetSurfaceType()
            if surfaceType == testSurfaceType then
                return coordTest 
            end
        end
    end
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
function CALLSIGN.Tanker:ToString(nCallsign, number)
    local name
    if     nCallsign == CALLSIGN.Tanker.Arco then name = "Arco"
    elseif nCallsign == CALLSIGN.Tanker.Shell then name = "Shell"
    elseif nCallsign == CALLSIGN.Tanker.Texaco then name = "Texaco"
    end
    if isNumber(number) then
        return name .. " " .. tostring(number)
    else
        return name
    end
end

function CALLSIGN.Tanker:FromString(sCallsign)
    if     sCallsign == "Arco" then return CALLSIGN.Tanker.Arco
    elseif sCallsign == "Shell" then return CALLSIGN.Tanker.Shell
    elseif sCallsign == "Texaco" then return CALLSIGN.Tanker.Texaco
    end
end

function CALLSIGN.AWACS:ToString(nCallsign, number)
    local name
    if     nCallsign == CALLSIGN.AWACS.Darkstar then name = "Darkstar"
    elseif nCallsign == CALLSIGN.AWACS.Focus then name = "Focus"
    elseif nCallsign == CALLSIGN.AWACS.Magic then name = "Magic"
    elseif nCallsign == CALLSIGN.AWACS.Overlord then name = "Overlord"
    elseif nCallsign == CALLSIGN.AWACS.Wizard then name = "Wizard"
    end
    if isNumber(number) then
        return name .. " " .. tostring(number)
    else
        return name
    end
end

function CALLSIGN.AWACS:FromString(sCallsign)
    if     sCallsign == "Darkstar" then return CALLSIGN.AWACS.Darkstar
    elseif sCallsign == "Focus" then return CALLSIGN.AWACS.Focus
    elseif sCallsign == "Magic" then return CALLSIGN.AWACS.Magic
    elseif sCallsign == "Overlord" then return CALLSIGN.AWACS.Overlord
    elseif sCallsign == "Wizard" then return CALLSIGN.AWACS.Wizard
    end
end

function GetTwoLetterCallsign(name)
    local len = string.len(name)
    if isAssignedString(name) and len >= 2 then
        return string.sub(name, 1, 1) .. string.sub(name, len)
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
  
function GetOtherCoalitions( source, excludeNeutral )
    local c
    if isAssignedString(source) then
        local group = getGroup( source )
        if group then
            c = Coalition.Resolve(group:GetCoalition())
        else
            c = Coalition.Resolve(source)
        end
    elseif isGroup(source) then
        c = Coalition.Resolve(source:GetCoalition())
    else
        c = Coalition.Resolve(source)
    end
    if (c == nil) then
        return exitWarning("GetOtherCoalitions :: cannot resolve coalition from: " .. DumpPretty(source))
    end
    
-- Debug("nisse - GetOtherCoalitions :: c: " .. Dump(c))
    if excludeNeutral == nil then 
        excludeNeutral = false end

    if c == Coalition.Red or c == coalition.side.RED then
        if excludeNeutral then 
            return { Coalition.Blue } end
        return { Coalition.Blue, Coalition.Neutral }
    elseif c == Coalition.Blue or c == coalition.side.BLUE then
-- Debug("nisse - GetOtherCoalitions :: Blue")
        if excludeNeutral then 
            return { Coalition.Red } end
        return { Coalition.Red, Coalition.Neutral }
    elseif c == Coalition.Neutral or c == coalition.side.NEUTRAL then
        return { Coalition.Red, Coalition.Blue }
    end
end

function GetHostileCoalition(source)
    return GetOtherCoalitions(source, true)[1]
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
function MessageTo(recipient, message, duration )
    if (message == nil) then
        return exitWarning("MessageTo :: Message was not specified")
    end
    duration = duration or 5

    if (isAssignedString(recipient)) then
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
        local dcafCoalition = Coalition.Resolve(recipient)
        if dcafCoalition then
            if (string.match(message, ".\.ogg") or string.match(message, ".\.wav")) then
                local audio = USERSOUND:New(message)
                if dcafCoalition == Coalition.Blue then
                    audio:ToCoalition(coalition.side.BLUE)
                elseif dcafCoalition == Coalition.Red then
                    audio:ToCoalition(coalition.side.RED)
                end
                return
            end
            if dcafCoalition == Coalition.Blue then
                MessageToBlue(message, duration)
            elseif coalition == Coalition.Red then
                MessageToRed(message, duration)
            end
            return
            -- note: Seems we can't send messages to neutral faction
        end
        return exitWarning("MessageTo-?"..recipient.." :: Group could not be resolved")
    end

    if (string.match(message, ".\.ogg") or string.match(message, ".\.wav")) then
Debug("nisse - MessageTo :: sound: " .. message)
        local audio = USERSOUND:New(message)
        if recipient == nil or DebugAudioMessageToAll then
            Trace("MessageTo (audio) :: (all) :: '" .. message .. "'")
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
            error("GetCallsign :: cannot resolve unit or group from " .. DumpPretty(source)) end

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

function IsTankerCallsign(controllable, ...)
    local group = getGroup(controllable)
    if not group then
        return false end

    local groupCallsign, number = GetCallsign(group)
    local tankerCallsign = CALLSIGN.Tanker:FromString(groupCallsign)
    if not tankerCallsign then
        return end

    if #arg == 0 then
        return tankerCallsign, number
    end

    for i = 1, #arg, 1 do
       if tankerCallsign == arg[i] then
          return tankerCallsign, number
       end
    end
 end

 function IsAWACSCallsign(controllable, ...)
    local group = getGroup(controllable)
    if not group then
        return false end

    local groupCallsign, number = GetCallsign(group)
    local awacsCallsign = CALLSIGN.AWACS:FromString(groupCallsign)
    if not awacsCallsign then
        return end

    if #arg == 0 then
        return awacsCallsign, number
    end

    for i = 1, #arg, 1 do
       if awacsCallsign == arg[i] then
          return awacsCallsign, number
       end
    end
    -- local callsign = CALLSIGN.AWACS:FromString(GetCallsign(group))
    -- for i = 1, #arg, 1 do
    --    if callsign == arg[i] then
    --       return true
    --    end
    -- end
 end

 function IsAirService(controllable, ...)
    return IsTankerCallsign(controllable, ...) or IsAWACSCallsign(controllable, ...)
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

function GetAGL( source )
    local location = DCAF.Location:New(source)
    if isClass(source, DCAF.Location.ClassName) then
        coord = source.Coordinate
    else
        local unit = getUnit(source) 
        if unit then
            return unit:GetAltitude(true)
        end
        local group = getGroup( source )
        if (group == nil) then
            return exitWarning("GetAGL :: cannot resolve group from "..Dump(source), false)
        end 
        coord = group:GetCoordinate()
    end
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
        ["alt_type"] = COORDINATE.WaypointAltType.BARO,
        ["y"] = abCoord.y,
        ["x"] = abCoord.x,
        ["alt"] = ab:GetAltitude(),
        ["type"] = "Land",
    }
    group:Route( { landHere } )
    Trace("LandHere-"..group.GroupName.." :: is tasked with landing at airbase ("..ab.AirbaseName..") :: DONE")
    return ab

end

local _onGroupLandedHandlers = { -- dictionary
    -- key = group name
    -- value = handler function
}

function OnGroupLandedEvent(group, func, bOnce)
    if not isFunction(func) then
        error("OnLandedEvent :: expected function but got: " .. DumpPretty(func)) end

    local forGroup = getGroup(group)
    if not forGroup then
        error("OnLandedEvent :: cannot resolve group from: " .. DumpPretty(group)) end

    if _onGroupLandedHandlers[forGroup.GroupName] then
        return 
    else
        _onGroupLandedHandlers[group.GroupName] = func
    end

    local _onLandedFuncWrapper
    local function onLandedFuncWrapper(event)
        if event.IniGroupName ~= group.GroupName then
            return end

        func(event)
        MissionEvents:EndOnAircraftLanded(_onLandedFuncWrapper)
        _onGroupLandedHandlers[group.GroupName] = nil
    end
    _onLandedFuncWrapper = onLandedFuncWrapper
    MissionEvents:OnAircraftLanded(_onLandedFuncWrapper)
end

function DestroyOnLanding(group, delaySeconds)
    OnGroupLandedEvent(group, function(event)
        if isNumber(delaySeconds) then
            Delay(delaySeconds, function()
                group:Destroy()
            end)
        else
            group:Destroy()
        end
    end)
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

Debug("nisse - CommandActivateTACAN :: group: " .. group.GroupName .. " :: nChannel: " .. Dump(nChannel) .. " :: sModeChannel: " .. sModeChannel .. " :: ident: " .. sIdent)

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

--- Starts or stops a group
function CommandStartStop(controllable, value)
    if not isBoolean(value) then
        error("CommandStartStop :: `value` must be boolean, but was " .. type(value)) end

    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("CommandStartStop :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    group:SetCommand({ id = 'StopRoute', params = { value = value } })
end

function CommandStart(controllable, delay, startedFunc)
    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("CommandStart :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    local function start(startDelayed)
        if group:IsAir() then
            group:StartUncontrolled(startDelayed)
        else
            group:SetAIOn()
        end
    end

    if isNumber(delay) then
        -- need to make the delay 'manually', beacuse we must invoke custom handler, or because it's a ground group...
        if isFunction(startedFunc) or not group:IsAir() then
            Delay(delay, function() 
                start()
                if isFunction(startedFunc) then
                    startedFunc(group)
                end
            end)
        else
            start(delay)
        end
    else
        start()
    end
end

--- Activates a LATE ACTIVATED group and returns it
function Activate(controllable)
    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("Activate :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    if not group:IsActive() then
        group:Activate()
    end
    return group
end

--- Activates an Uncontrolled group (at its current location). Please note that Air groups needs to be set to 'UNCONTROLLED' in ME
function ActivateUncontrolled(controllable)
    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("ActivateUncontrolled :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    if isNumber(delayStart) and group:IsGround() then
        group:SetAIOff()
    end

    if not group:IsActive() then
        group:Activate()
    end
    return group
end

--- Activates an Uncontrolled group (at its current location) and then starts it, optionally after a delay. 
--- Please note that Air groups needs to be set to 'UNCONTROLLED' in ME
function ActivateUncontrolledThenStart(controllable, delayStart, startedFunc)
    return CommandStart(ActivateUncontrolled(controllable), delayStart, startedFunc)
end

--- Spawns a group as Uncontrolled and then starts it, optionally after a delay
function SpawnUncontrolledThenStart(controllable, delayStart, startedFunc) -- todo Need to be able to set parking spot
    local group = getGroup(controllable)
    if not isClass(group, GROUP.ClassName) then
        error("CommandStart :: could not resolve group from `controllable`: " .. DumpPretty(controllable)) end

    local spawn = getSpawn(group.GroupName) -- << -- gets SPAWN for group
    if isNumber(delayStart) and group:IsAir() then
        spawn:InitUnControlled(true)
    end

    group = spawn:Spawn()
    return ActivateUncontrolledThenStart(group, delayStart, startedFunc)
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
            Warning("ROEWeaponFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            if (group:IsShip()) then
                ROEOpenFireWeaponFree( group )
                return
            end
            group:OptionAlarmStateAuto()
            Trace("ROEWeaponFree-"..group.GroupName.." :: is alarm state AUTO")
            group:OptionROEWeaponFree()
            Trace("ROEWeaponFree-"..group.GroupName.." :: is weapons free")
        end
    end
end

function ROEDefensive( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEDefensive-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            ROTEvadeFire( controllable )
            group:OptionAlarmStateRed()
            Trace("ROEDefensive-"..group.GroupName.." :: is alarm state RED")
            ROEHoldFire( group )
            Trace("ROEDefensive-"..group.GroupName.." :: is weapons free")
        end
    end
end

function ROEActiveDefensive( ... )
    for _, controllable in ipairs(arg) do
        local group = getGroup( controllable )
        if (group == nil) then
            Warning("ROEWeaponsFree-? :: cannot resolve group "..Dump(controllable) .." :: IGNORES")
        else
            ROTEvadeFire( controllable )
            group:OptionAlarmStateRed()
            Trace("ROEWeaponsFree-"..group.GroupName.." :: is alarm state RED")
            ROEReturnFire( group )
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
            Trace("SetAIOn-" .. group.GroupName .. " :: sets AI=ON :: DONE")
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
            Trace("SetAIOff-" .. group.GroupName .. " :: sets AI=OFF :: DONE")
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

function HasWaypointAction(waypoints, sActionId, wpIndex) -- todo move higher up, to more general part of the file
    local function hasWpAction(wp)
        for index, task in ipairs(wp.task.params.tasks) do
            if task.id == "WrappedAction" and task.params.action.id == sActionId then 
                return index end
        end
    end

    if not wpIndex then
        for wpIndex, wp in ipairs(waypoints) do
            if hasWpAction(wp) then 
                return wpIndex end
        end
    elseif hasWpAction(route[wpIndex]) then
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

function HasLandingTask(controllabe) 
    -- note: The way I understand it a landing task can be a WrappedAction or a special type of "Land" waypint
    local wrappedLandingWpIndex = HasAction(controllabe, "Landing")
    if wrappedLandingWpIndex then
        return wrappedLandingWpIndex 
    end

    local group = getGroup(controllabe)
    if not group then
        error("HasLandingTask :: cannot resolve group from: " .. DumpPretty(controllabe)) end

    local route = group:CopyRoute()
    for wpIndex, wp in ipairs(route) do
        if wp.type == "Land" then 
            return wpIndex, AIRBASE:FindByID(wp.airdromeId)
        end
    end
end
function HasOrbitTask(controllabe) return HasTask(controllabe, "Orbit") end
function HasTankerTask(controllabe) return HasTask(controllabe, "Tanker") end
function HasSetFrequencyTask(controllabe) return HasAction(controllabe, "SetFrequency") end
function HasActivateBeaconTask(controllabe) return HasAction(controllabe, "ActivateBeacon") end
function HasDeactivateBeaconTask(controllabe) return HasAction(controllabe, "DeactivateBeacon") end

--------------------------------------------- [[ MISSION EVENTS ]] ---------------------------------------------


MissionEvents = { }

MissionEvents.MapMark = {
    EventID = nil,                      -- #number - event id
    Coalition = nil,                    -- #Coalition
    Index = nil,                        -- #number - mark identity
    Time = nil,                         -- #number - game world time in seconds (UTILS.SecondsOfToday)
    Text = nil,                         -- #string - map mark text
    GroupID = nil,                      -- #number - I have NOOO idea what this is (doesn't seem to identify who added the mark)
    Location = nil,                     -- DCAF.Location
}

function MissionEvents.MapMark:New(event)
    local mark = DCAF.clone(MissionEvents.MapMark)
    mark.ID = event.id
    mark.Coalition = Coalition.Resolve(event.coalition)
    mark.Index = event.index
    mark.Time = event.time
    mark.Text = event.text
    mark.GroupID = event.groupID
    local coord = COORDINATE:New(event.pos.x, event.pos.y, event.pos.z)
    mark.Location = DCAF.Location:New(coord)
    return mark
end

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
    _mapMarkAddedHandlers = {},
    _mapMarkChangedHandlers = {},
    _mapMarkDeletedHandlers = {},
}

local PlayersAndUnits = { -- dictionary
    -- key = <unit name>
    -- value = { Unit = #UNIT, PlayerName = <player name> }
}

function PlayersAndUnits:Add(unit, playerName)
    PlayersAndUnits[unit.UnitName] = { Unit = unit, PlayerName = playerName}
end

function PlayersAndUnits:Remove(unitName)
    PlayersAndUnits[unitName] = nil
end

function PlayersAndUnits:Get(unitName)
    local info = PlayersAndUnits[unitName]
    if info then
        return info.Unit, info.PlayerName
    end
end

local isMissionEventsListenerRegistered = false
local _e = {}

function MissionEvents:Invoke(handlers, data)
    for _, handler in ipairs(handlers) do
        handler( data )
    end
end

function _e:onEvent( event )
---Debug("nisse - _e:onEvent-? :: event: " .. Dump(event))

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
                Warning("_e:onEvent :: event: " .. Dump(event.id) .. " :: could not resolve TgtUnit from DCS object")
                return event
            end
            event.TgtUnitName = event.TgtUnit.UnitName
            -- if DCSUnit then
            --   local UnitGroup = GROUP:FindByName( dcsTarget:getGroup():getName() )
            --   return UnitGroup
            -- end
            event.TgtGroup = event.TgtUnit:GetGroup()
            if not event.TgtGroup then
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

    if event.id == world.event.S_EVENT_BIRTH then
        -- todo consider supporting MissionEvents:UnitBirth(...)
        
        if isAssignedString(event.IniPlayerName) then
            event.id = world.event.S_EVENT_PLAYER_ENTER_UNIT
        end
    end

    if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then --  event
        if not event.initiator then
            return end -- weird!

        local unit = UNIT:Find(event.initiator)
        if not unit then 
            return end -- weird!

        if PlayersAndUnits:Get(event.IniUnitName) then
            return end
        
        PlayersAndUnits:Add(unit, event.IniPlayerName)
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
        PlayersAndUnits:Remove(event.IniUnitName)
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
        end
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
        MissionEvents:Invoke(_missionEventsHandlers._ejectionHandlers, addInitiatorAndTarget(event))
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

    if event.id == world.event.S_EVENT_MARK_ADDED then
        MissionEvents:Invoke(_missionEventsHandlers._mapMarkAddedHandlers, MissionEvents.MapMark:New(event))
        return
    end
    if event.id == world.event.S_EVENT_MARK_CHANGE then
        MissionEvents:Invoke(_missionEventsHandlers._mapMarkChangedHandlers, MissionEvents.MapMark:New(event))
        return
    end
    if event.id == world.event.S_EVENT_MARK_REMOVED then
        MissionEvents:Invoke(_missionEventsHandlers._mapMarkDeletedHandlers, MissionEvents.MapMark:New(event))
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
    local idx
    for i, f in ipairs(listeners) do
        if func == f then
            idx = i
        end
    end
    if idx then
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
end
function MissionEvents:EndOnAircraftLanded( func ) MissionEvents:RemoveListener(_missionEventsHandlers._aircraftLandedHandlers, func) end

function MissionEvents:OnMapMarkAdded( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._mapMarkAddedHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnMapMarkAdded( func ) MissionEvents:RemoveListener(_missionEventsHandlers._mapMarkAddedHandlers, func) end

function MissionEvents:OnMapMarkChanged( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._mapMarkChangedHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnMapMarkChanged( func ) MissionEvents:RemoveListener(_missionEventsHandlers._mapMarkChangedHandlers, func) end

function MissionEvents:OnMapMarkDeleted( func, insertFirst )
    MissionEvents:AddListener(_missionEventsHandlers._mapMarkDeletedHandlers, func, nil, insertFirst)
end
function MissionEvents:EndOnMapMarkDeleted( func ) MissionEvents:RemoveListener(_missionEventsHandlers._mapMarkDeletedHandlers, func) end

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
        --   value = {
        --       list of #UnitInfo        
        --  } 
    },               
    CountMonitored = 0,           -- ¤number; no. of items in $self.Units
}

function _missionEventsAircraftFielStateMonitor:Start(key, units, fuelState, func)

    local monitored = _missionEventsAircraftFielStateMonitor.Monitored[key]
    if monitored then
        if  monitored.State == fuelState then
            return errorOnDebug("MissionEvents:OnFuelState :: key was already monitored for same fuel state ("..Dump(fuelState)..")") end
    else
        monitored = {}
        _missionEventsAircraftFielStateMonitor.Monitored[key] = monitored
    end

    local info = DCAF.clone(_missionEventsAircraftFielStateMonitor.UnitInfo)
    info.Units = units
    info.State = fuelState
    info.Func = func
    _missionEventsAircraftFielStateMonitor.CountMonitored = _missionEventsAircraftFielStateMonitor.CountMonitored + 1
    table.insert(monitored, info)

    if self.Timer then 
        return end

    local function monitorFuelStates()
        local triggeredKeys = {}
        for key, monitored in pairs(_missionEventsAircraftFielStateMonitor.Monitored) do
            for _, info in ipairs(monitored) do
                for index, unit in pairs(info.Units) do
                    local state = unit:GetFuel()
                    if state == nil or info.State == nil then
                        -- stop monitoring (unit was probably despawned)
                        table.insert(triggeredKeys, { Key = key, Index = index })
                    elseif state <= info.State then
-- Debug("monitor fuel state :: unit: " .. unit.UnitName .. " :: state: " .. Dump(state) .. " :: info.State: " .. Dump(info.State))                
-- Debug("triggers onfuel state :: unit: " .. unit.UnitName .. " :: state: " .. Dump(state) .. " :: info.State: " .. Dump(info.State))                
                        info.Func(unit)
                        table.insert(triggeredKeys, { Key = key, Index = index })
                    end
                end
            end
        end

        -- end triggered keys ...
        for i = #triggeredKeys, 1, -1 do
            local triggered = triggeredKeys[i]
            self:End(triggered.Key, triggered.Index)
        end
    end
    
    self.Timer = TIMER:New(monitorFuelStates):Start(1, 60)
end

function _missionEventsAircraftFielStateMonitor:End(key, index)

    if not _missionEventsAircraftFielStateMonitor.Monitored[key] then
        return errorOnDebug("MissionEvents:OnFuelState :: key was not monitored") 
    else
        local monitored = _missionEventsAircraftFielStateMonitor.Monitored[key]
        local info = monitored[index]
        Trace("MissionEvents:OnFuelState :: " .. key .. "/state("..tostring(info.State)..") :: ENDS")
        table.remove(monitored, index)
        _missionEventsAircraftFielStateMonitor.CountMonitored = _missionEventsAircraftFielStateMonitor.CountMonitored - 1
        if #monitored == 0 then
            _missionEventsAircraftFielStateMonitor.Monitored[key] = nil
        end
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
    local activations = _DCAFEvents_lateActivations[source]
    if not activations then
        return
    end
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
            if not Coalition.Resolve(v) then
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

    if isAssignedString(zone) then
        zoneEvent.zone = ZONE:FindByName(zone)
        if not zoneEvent.zone then
            error("MonitoredZoneEvent:New :: could not find zone: '" .. Dump(zone) .. "'")
        end
    elseif isClass(zone, ZONE.ClassName) then
        zoneEvent.zone = zone
    else
        error("MonitoredZoneEvent:New :: unexpected/unassigned zone: " .. Dump(zone))
    end
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
    IsStrict = false,         -- #boolean; when set, an error will be thrown if carrier cannt be resolved (not setting it allows referencing carrier that might not be needed in a particular miz)
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

DCAF_TACAN = {
    Group = nil,          -- #GROUP
    Unit = nil,           -- #UNIT
    Channel = nil,        -- #number (eg. 73, for channel 73X)     
    Mode = nil,           -- #string (eg. 'X' for channel 73X)
    Ident = nil,          -- #string (eg. 'C73')
    Beaering = true       -- #boolean; Emits bearing information when set
}

DCAF_ICLS = {
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
    local carrier = DCAF.clone(DCAF.Carrier)
    if not forGroup then
        if DCAF.Carrier.IsStrict then
            error("DCAF.Carrier:New :: cannot resolve group from: " .. DumpPretty(group)) 
        end
        return carrier
    end

    local forUnit = resolveUnitInGroup(forGroup, nsUnit)
    -- todo: Ensure unit is actually a carrier!
    if isAssignedString(forUnit) then
        error("DCAF.Carrier:New :: cannot resolve unit from: " .. DumpPretty(nsUnit)) end

    if not isAssignedString(sDisplayName) then
        sDisplayName = forUnit.UnitName
    end

    carrier.Group = forGroup
    carrier.Unit = forUnit
    carrier.DisplayName = sDisplayName
    return DCAFCarriers:Add(carrier)
end

function DCAF.Carrier:IsEmpty()
    return self.Group == nil
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

function DCAF_TACAN:IsValidMode(mode)
    if not isAssignedString(mode) then
        error("DCAF_TACAN:IsValidMode :: `mode` must be assigned string but was: " .. DumpPretty(mode)) end

    local test = string.upper(mode)
    return test == 'X' or test == 'Y'
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
    if self:IsEmpty() then
        return self end

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
    if self:IsEmpty() then
        return self end
        
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

    if self:IsEmpty() then
        return self end
            
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

    if self:IsEmpty() then
        return self end
        
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
    if self:IsEmpty() then
        return self end

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
        Frequency = 290,
        TACANChannel = 37,
        TACANMode = 'Y',
        TACANIdent = 'ACA',
        TrackBlock = 8,
        TrackSpeed = 350
    },
    [2] = {
        Frequency = 290.25,
        TACANChannel = 38,
        TACANMode = 'Y',
        TACANIdent = 'ACB',
        TrackBlock = 10,
        TrackSpeed = 350
    }
}

function DCAF.Carrier:WithArco1(sGroupName, nTakeOffType, bLaunchNow, nAltitudeFeet)
    if self:IsEmpty() then
        return self end
        
    if not isNumber(nAltitudeFeet) then
        nAltitudeFeet = DCAF_ArcosInfo[1].TrackBlock * 1000
    end
    local tanker = makeRecoveryTanker(
        self.Unit,
        sGroupName,
        DCAF_ArcosInfo[1].TACANChannel,
        DCAF_ArcosInfo[1].TACANMode,
        DCAF_ArcosInfo[1].TACANIdent,
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
    if self:IsEmpty() then
        return self end

    if not isNumber(nAltitudeFeet) then
        nAltitudeFeet = DCAF_ArcosInfo[1].TrackBlock*1000
    end
    local tanker = makeRecoveryTanker(
        self.Unit,
        sGroupName,
        DCAF_ArcosInfo[2].TACANChannel,
        DCAF_ArcosInfo[2].TACANMode,
        DCAF_ArcosInfo[2].TACANIdent,
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

-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                              BIG (air force) TANKERS & AWACS
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
            TrackBlock = 24,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [3] = {
            Frequency = 270.5,
            TACANChannel = 41,
            TACANMode = 'Y',
            TACANIdent = 'SHC',
            TrackBlock = 26,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
    },
    [CALLSIGN.Tanker.Texaco] = {
        [1] = {
            Frequency = 280,
            TACANChannel = 42,
            TACANMode = 'Y',
            TACANIdent = 'TXA',
            TrackBlock = 18,  -- x1000 feet
            TrackSpeed = 350, -- knots
        },
        [2] = {
            Frequency = 280.25,
            TACANChannel = 43,
            TACANMode = 'Y',
            TACANIdent = 'TXB',
            TrackBlock = 20,  -- x1000 feet
            TrackSpeed = 350, -- knots
        },
        [3] = {
            Frequency = 280.5,
            TACANChannel = 44,
            TACANMode = 'Y',
            TACANIdent = 'TXC',
            TrackBlock = 16,  -- x1000 feet
            TrackSpeed = 350, -- knots
        },
    },
    [CALLSIGN.Tanker.Arco] = {
        [1] = DCAF_ArcosInfo[1],
        [2] = DCAF_ArcosInfo[2]
    }
}

local DCAF_TankerMonitor = {
    Timer = nil,              
}

local DCAF_ServiceTrack = {
    ClassName = "DCAF_ServiceTrack"
}

function DCAF_ServiceTrack:New(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    if not isNumber(nStartWp) then
        error("DCAF.<service>:SetTrack :: start waypoint was unassigned/unexpected value: " .. Dump(nStartWp)) end
    if nStartWp < 1 then
        error("DCAF.<service>:SetTrack :: start waypoint must be 1 or more (was: " .. Dump(nStartWp) .. ")") end

    local track = DCAF.clone(DCAF_ServiceTrack)
    track.StartWpIndex = nStartWp
    track.Heading = nHeading
    track.Length = nLength
    track.Block = nBlock
    track.Color = rgbColor
    track.TrackName = sTrackName
    return track
end

local DCAF_SERVICE_TYPE = {
    Tanker = "DCAF.Tanker",
    AWACS = "DCAF.AWACS"
}

DCAF.Tanker = {
    _isTemplate = true,
    ClassName = DCAF_SERVICE_TYPE.Tanker,
    Group = nil,              -- #GROUP (the tanker group)
    TACANChannel = nil,       -- #number; TACAN channel
    TACANMode = nil,          -- #string; TACAN mode
    TACANIdent = nil,         -- #string; TACAN ident
    FuelStateRtb = 0.15,      -- 
    Frequency = nil,          -- #number; radio frequency
    StartFrequency = nil,     -- #number; radio frequency tuned at start and during RTB/landing
    RTBAirbase = nil,         -- #AIRBASE; the last WP landing airbase; or starting/closest airbase otherwise
    RTBWaypoint = nil,        -- #number; first waypoint after track waypoints (set by :SetTrack()
    TrackBlock = nil,         -- #number; x1000 feet
    TrackSpeed = nil,         -- #number; knots
    Track = nil,
    Events = {},              -- dictionary; key = name of event (eg. 'OnFuelState'), value = event arguments
}

local DCAF_AWACS = {
    [CALLSIGN.AWACS.Magic] = {
        [1] = {
            TrackBlock = 35,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [2] = {
            TrackBlock = 34,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
        [3] = {
            TrackBlock = 33,  -- x1000 feet
            TrackSpeed = 430, -- knots
        },
    }
}

DCAF.AWACS = {
    _isTemplate = true,
    ClassName = DCAF_SERVICE_TYPE.AWACS,
    Group = nil,              -- #GROUP (the tanker group)
    FuelStateRtb = 0.15,      -- 
    RTBAirbase = nil,         -- #AIRBASE; the last WP landing airbase; or starting/closest airbase otherwise
    RTBWaypoint = nil,        -- #number; first waypoint after track waypoints (set by :SetTrack)
    TrackBlock = nil,         -- #number; x1000 feet
    TrackSpeed = nil,         -- #number; knots
    Track = nil,
    Events = {},              -- dictionary; key = name of event (eg. 'OnFuelState'), value = event arguments
}

function DCAF.Tanker:IsMissing()
    return not self.Group
end

function DCAF.Tanker:New(controllable, replicate, callsign, callsignNumber)
    local tanker = DCAF.clone(replicate or DCAF.Tanker)
    tanker._isTemplate = false
    local group = getGroup(controllable)
    if not group then
        -- note: To make code API more versatile we accept missing tankers. This allows for reusing same script in missions where not all tankers are present
        Warning("DCAF.Tanker:New :: cannot resolve group from " .. DumpPretty(controllable))
        return tanker
    end

    -- initiate tanker ...
    tanker.Group = group
    local defaults
    if callsign ~= nil then
        if not isNumber(callsign) then
            error("DCAF.Tanker:New :: `callsign` must be number but was " .. type(callsign))  end
        if not isNumber(callsignNumber) then
            error("DCAF.Tanker:New :: `callsignNumber` must be number but was " .. type(callsignNumber))  end
        defaults = DCAF_Tankers[callsign][callsignNumber]
    else
        callsign, callsignNumber = GetCallsign(group)
        defaults = DCAF_Tankers[CALLSIGN.Tanker:FromString(callsign)][callsignNumber]
    end
    Trace("DCAF.Tanker:New :: callsign: " .. Dump(callsign) .. " " .. Dump(callsignNumber) .. " :: defaults: " .. DumpPrettyDeep(defaults))
    tanker.TACANChannel = defaults.TACANChannel
    tanker.TACANMode = defaults.TACANMode
    tanker.TACANIdent = defaults.TACANIdent
    tanker.Frequency = defaults.Frequency
    tanker.RTBAirbase = GetRTBAirbaseFromRoute(group)
    tanker.TrackBlock = defaults.TrackBlock
    tanker.TrackSpeed = defaults.TrackSpeed
    tanker.DisplayName = CALLSIGN.Tanker:ToString(callsign, callsignNumber)
    
    if tanker.Track and tanker.Track.Route then
        -- replicate route from previous tanker ...
        group:Route(tanker.Track.Route)
    end

    -- register all events (from replicate)
    for _, event in pairs(tanker.Events) do
        event.EventFunc(event.Args)
    end

    return tanker
end

function DCAF.Tanker:InitFrequency(frequency)
    if not isNumber(frequency) then
        error("DCAF.Tanker:WithFrequency :: `frequency` must be a number but was " .. type(frequency)) end
    
    self.Frequency = frequency
    return self
end

function DCAF.Tanker:FindGroupWithCallsign(callsign, callsignNumber)
    local callsignName = CALLSIGN.Tanker:ToString(callsign)
    local groups = _DATABASE.GROUPS
    for _, g in pairs(groups) do
        if g:IsAir() then
            local csName, csNumber = GetCallsign(g:GetUnit(1))
            if csName == callsignName and csNumber == callsignNumber then
                return g
            end
        end
    end
end

function DCAF.Tanker:NewFromCallsign(callsign, callsignNumber)
    if callsign == nil then
        error("DCAF.Tanker:New :: callsign group was not specified") end

    local group = self:FindGroupWithCallsign(callsign, callsignNumber)
    if not group then
        error("DCAF.Tanker:NewFromCallsign :: cannot resolve Tanker from callsign: " .. CALLSIGN.Tanker:ToString(callsign, callsignNumber)) end

    return DCAF.Tanker:New(group)
end

function DCAF_ServiceTrack:IsTanker()
    return self.Service.ClassName == DCAF_SERVICE_TYPE.Tanker
end

function DCAF_ServiceTrack:IsAWACS()
    return self.Service.ClassName == DCAF_SERVICE_TYPE.AWACS
end

function InsertWaypointTask(waypoint, task)
    task.number = #waypoint.task.params.tasks+1 
    table.insert(waypoint.task.params.tasks, task)
end

function TankerTask()
    return {
        auto = false,
        id = "Tanker",
        enabled = true,
        params = { },
    }
end

local function FrequencyAction(nFrequency, nPower, modulation)
    if not isNumber(nFrequency) then
        error("FrequencyAction :: `nFrequency` must be number but was " .. type(nFrequency)) end

    if not isNumber(nPower) then
        nPower = 10
    end

    if not modulation then
        modulation = radio.modulation.AM
    end

    return 
    { 
        id = 'SetFrequency', 
        params = { 
            power = nPower,
            frequency = nFrequency * 1000000, 
            modulation = modulation 
        }, 
    }
end

function ActivateBeaconAction(beaconType, nChannel, nFrequency, sModeChannel, sCallsign, nBeaconSystem, bBearing, bAA)
    if not isNumber(beaconType) then
        beaconType = BEACON.Type.TACAN
    end
    if not isBoolean(bBearing) then
        bBearing = true
    end    
    if not isBoolean(bAA) then
        bAA = false
    end

    return {
        id = "ActivateBeacon",
        params = {
            modeChannel = sModeChannel,
            type = beaconType,
            system = nBeaconSystem,
            AA = bAA,
            callsign = sCallsign,
            channel = nChannel,
            bearing = bBearing,
            frequency = nFrequency
        }
    }
end

local function ActivateTankerTacanAction(nChannel, sModeChannel, sCallsign, bBearing, bAA)
    local tacanSystem
    if sModeChannel == "X" then
        tacanSystem = BEACON.System.TACAN_TANKER_X
    else
        tacanSystem = BEACON.System.TACAN_TANKER_Y
    end
    return ActivateBeaconAction(
        BEACON.Type.TACAN, 
        nChannel,
        UTILS.TACANToFrequency(nChannel, sModeChannel), 
        sModeChannel, 
        sCallsign, 
        tacanSystem, 
        bBearing, 
        bAA)
end

function InsertWaypointAction(waypoint, action)
    table.insert(waypoint.task.params.tasks, {
        number = #waypoint.task.params.tasks+1,
        auto = false,
        id = "WrappedAction",
        enabled = true,
        params = { action = action },
      })
end

function ScriptAction(script)
    if not isAssignedString(script) then
        error("ScriptAction :: `script` must be assigned string, but was " .. type(script)) end

    return {
        id = "Script",
        params = 
        {
            command = script
        }
    }
end

local DCAF_CALLBACK_INFO = {
    ClassName = "DCAF_CALLBACK_INFO",
    NextId = 1,
    Id = 0,              -- #int
    Func = nil           -- #function
}

local DCAF_CALLBACKS = { -- dictionary
    -- key   = #string
    -- value = #AIR_ROUTE_CALLBACK_INFO
}

function DCAF_CALLBACK_INFO:New(func, oneTime)
    local info = DCAF.clone(DCAF_CALLBACK_INFO)
    if not isBoolean(oneTime) then
        oneTime = true
    end
    info.Func = func
    info.Id = DCAF_CALLBACK_INFO.NextId
    info.OneTime = oneTime
    DCAF_CALLBACKS[tostring(info.Id)] = info
    DCAF_CALLBACK_INFO.NextId = DCAF_CALLBACK_INFO.NextId + 1
    return info
end

function DCAF_CALLBACKS:Callback(id)
    local key = tostring(id)
    local info = DCAF_CALLBACKS[key]
    if not info then
        Warning("DCAF_CALLBACKS:Callback :: no callback found with id: " .. Dump(id) .. " :: IGNORES")
        return
    end
    info.Func()
    if info.OneTime then
        DCAF_CALLBACKS[key] = nil
    end
end

function ___dcaf_callback___(id)
    DCAF_CALLBACKS:Callback(id)
end

function WaypointCallback(waypoint, func, oneTime)
    local info
    info = DCAF_CALLBACK_INFO:New(function() 
        func(waypoint)
    end, oneTime)
    InsertWaypointAction(waypoint, ScriptAction("___dcaf_callback___(" ..Dump(info.Id) .. ")"))
end

function DCAF_ServiceTrack:Execute(direct) -- direct = service will proceed direct to track
    if not isBoolean(direct) then
        direct = false
    end

    local waypoints, route = self.Service:GetWaypoints() -- .Route or self.Service.Group:CopyRoute()
    local wpOffset = 1
    local startWpIndex = self.StartWpIndex
    startWpIndex = startWpIndex + wpOffset -- this is to harmonize with WP numbers on map (1st WP on map is zero - 0)
Debug("nisse - DCAF_ServiceTrack:Execute :: waypoints: " .. DumpPrettyDeep(waypoints, 2))    
    if startWpIndex > #waypoints then
        error("DCAF.Tanker:SetTrack :: start waypoint must be within route (route is " .. Dump(#waypoints) .. " waypoints, startWp was ".. Dump(startWpIndex) .. ")") end

    local startWp = waypoints[startWpIndex]
    
    local trackLength = self.Length
    local trackAltitude
    local trackHeading = self.Heading
    if not isNumber(trackLength) then
        trackLength = NauticalMiles(30)
    end
    if isNumber(self.Block) then
        trackAltitude = Feet(self.Block * 1000)
    elseif isNumber(self.Service.TrackBlock) then
        trackAltitude = Feet(self.Service.TrackBlock * 1000)
    end
    startWp.alt = trackAltitude
    if DCAF.Debug then
        startWp.name = "TRACK IP"
    end

    local startWpCoord = COORDINATE:NewFromWaypoint(startWp)
    local endWpCoord 

    if not isNumber(trackHeading) then
        if startWpIndex == #waypoints then
            error(self.Service.ClassName.."SetTrackFromWaypoint :: heading was unassigned/unexpected value and start of track was also last waypoint")
        else
            endWpCoord = COORDINATE:NewFromWaypoint(waypoints[startWpIndex+1])
            self.RTBWaypoint = startWpIndex+2 -- note, if last WP in track was also last waypoint in route, this will point 'outside' the route
        end
    else
        endWpCoord = startWpCoord:Translate(trackLength, trackHeading, trackAltitude)
    end
    
    local function drawActiveTrack(color)
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
        wp1:MarkupToAllFreeForm({wp2, wp3, wp4}, self.Service.Group:GetCoalition(), rgbColor, 0.5, nil, 0, 3)
        wp4:SetHeading(trackHeading)
        if isAssignedString(self.TrackName) then
            wp4:TextToAll(self.TrackName, self.Service.Group:GetCoalition(), rgbColor, 0.5, nil, 0)
        end
    end

    local function hasOrbitTask() return HasTask(self.Service.Group, "Orbit") end                          -- todo consider elevating this func to global
    local function hasTankerTask() return HasTask(self.Service.Group, "Tanker") end                        -- todo consider elevating this func to global
    local function hasSetFrequencyTask() return HasWaypointAction(self.Service._waypoints, "SetFrequency") end          -- todo consider elevating this func to global
    local function hasActivateBeaconTask() return HasAction(self.Service.Group, "ActivateBeacon") end      -- todo consider elevating this func to global
    local function hasDeactivateBeaconTask() return HasAction(self.Service.Group, "DeactivateBeacon") end  -- todo consider elevating this func to global

    drawActiveTrack()

    if self:IsTanker() then
        local tankerTask = hasTankerTask()
        if not tankerTask or tankerTask > startWpIndex then
            InsertWaypointTask(startWp, TankerTask())
        end
    end

    local setFrequencyTask = hasSetFrequencyTask()
    if self.Service.Frequency and (not setFrequencyTask or setFrequencyTask > startWpIndex) then
        local frequencyAction = FrequencyAction(self.Service.Frequency)
        InsertWaypointAction(startWp, frequencyAction)
    end

    local orbitTask = hasOrbitTask()
    if not orbitTask or orbitTask ~= startWpIndex then
        InsertWaypointTask(startWp, self.Service.Group:TaskOrbit(startWpCoord, trackAltitude, Knots(self.Service.TrackSpeed), endWpCoord))
        if orbitTask and orbitTask ~= startWpIndex then
            Warning(self.Service.ClassName..":SetTrack :: there is an orbit task set to a different WP (" .. Dump(orbitTask) .. ") than the one starting the tanker track (" .. Dump(startWpIndex) .. ")") end

        self.Service.RTBWaypoint = startWpIndex+1 -- note, if 1st WP in track was also last waypoint in route, this will point 'outside' the route
    end

    local tacanWpIndex
    local tacanWpSpeed = UTILS.KnotsToKmph(self.Service.TrackSpeed)

    local isAlreadyActivated = false
    if isNumber(self.Service._serviceWP) then
        isAlreadyActivated = self.Service._serviceWP < startWpIndex
    end
    if self:IsTanker() and not hasActivateBeaconTask() and not isAlreadyActivated then
        -- ensure TACAN gets activated _before_ the first Track WP (some weird bug in DCS otherwise may cause it to not activate)
        -- inject a new waypoint 2 nm before the tanker track, or use the previous WP if < 10nm from the tanker track
        local prevWp = waypoints[startWpIndex - wpOffset]
        local prevWpCoord = COORDINATE:NewFromWaypoint(prevWp)
        local distance = prevWpCoord:Get2DDistance(startWpCoord)
        local tacanWp
        if distance <= NauticalMiles(10) then
            tacanWp = prevWp
            tacanWpIndex = startWpIndex-1
        else
            local dirVec3 = prevWpCoord:GetDirectionVec3(startWpCoord)
            local heading = prevWpCoord:GetAngleDegrees(dirVec3)
            local tacanWpCoord = prevWpCoord:Translate(distance - NauticalMiles(2), heading, trackAltitude)
            tacanWp = tacanWpCoord:WaypointAir(
                COORDINATE.WaypointAltType.BARO, 
                COORDINATE.WaypointType.TurningPoint,
                COORDINATE.WaypointAction.TurningPoint,
                tacanWpSpeed)
            tacanWp.alt = trackAltitude
            table.insert(waypoints, startWpIndex, tacanWp)
            tacanWpIndex = startWpIndex
        end
        if DCAF.Debug and not tacanWp.name then
            tacanWp.name = "ACTIVATE"
        end

        local tacanSystem
        if self.TACANMode == "X" then
            tacanSystem = BEACON.System.TACAN_TANKER_X
        else
            tacanSystem = BEACON.System.TACAN_TANKER_Y
        end

        InsertWaypointAction(tacanWp, ActivateTankerTacanAction(
            self.Service.TACANChannel,
            self.Service.TACANMode,
            self.Service.TACANIdent,
            true,
            false
        ))
        startWpIndex = startWpIndex+1          
    end

    if startWpIndex == #waypoints or startWpIndex == #waypoints-1 then
        -- add waypoint for end of track ...
        local endWp = endWpCoord:WaypointAir(
            COORDINATE.WaypointAltType.BARO, 
            COORDINATE.WaypointType.TurningPoint,
            COORDINATE.WaypointAction.TurningPoint,
            tacanWpSpeed)
        endWp.alt = trackAltitude
        if DCAF.Debug then
            endWp.name = "TRACK END"
        end
        table.insert(waypoints, startWpIndex+1, endWp)
    end
    if direct then
        waypoints = listCopy(waypoints, nil, tacanWpIndex)
    end
    self.Route = waypoints
    self.Service:SetRoute(route or waypoints)
end

local function setServiceTrack(service, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
    if not isNumber(nStartWp) then
        error("DCAF.Tanker:SetTrack :: start waypoint was unassigned/unexpected value: " .. Dump(nStartWp)) end
    if nStartWp < 1 then
        error("DCAF.Tanker:SetTrack :: start waypoint must be 1 or more (was: " .. Dump(nStartWp) .. ")") end

    if service:IsMissing() then
        return service end

    service.Track = DCAF_ServiceTrack:New(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    service.Track.Service = service
    service.Track:Execute(direct)
    return service
end

function SetAirServiceRoute(service, route)
    if DCAF.AIR_ROUTE and isClass(route, DCAF.AIR_ROUTE.ClassName) then
        service._waypoints = route.Waypoints
        service._airRoute = route
    elseif isTable(route) then
        service._waypoints = route
    end
    service.Group:Route(service._waypoints)
end

local function getAirServiceWaypoints(service)
    if isTable(service._waypoints) then
        return service._waypoints, service._airRoute
    else
        return service.Group:CopyRoute()
    end
end

function DCAF.Tanker:GetWaypoints()
    return getAirServiceWaypoints(self)
end

function DCAF.Tanker:SetRoute(route)
    SetAirServiceRoute(self, route)
    return self
end

--- Activates Tanker at specified waypoint (if not set, the tanker will activate as it enters its track - see: SetTrack)
--- Please note that the WP should preceed the Track start WP for this to make sense 
function DCAF.Tanker:ActivateService(nServiceWp, waypoints)
    if not isNumber(nServiceWp) then
        error("DCAF.Tanker:ActivateService :: `nActivateWp` must be number but was " .. type(nServiceWp)) end

    if nServiceWp < 1 then 
        error("DCAF.Tanker:ActivateService :: `nActivateWp` must be a positive non-zero value") end

    nServiceWp = nServiceWp+1
    local route
    if not isTable(waypoints) then
        waypoints, route = self:GetWaypoints()
    end
    if nServiceWp > #waypoints then
        error("DCAF.Tanker:ActivateService :: `nActivateWp` must be a WP of the (currently there are " .. #waypoints .. " waypoints in route") end

    -- activate TACAN, Frequency and 'Tanker' task at specified WP
    self._serviceWP = nServiceWp
    local serviceWp = waypoints[nServiceWp]
    if DCAF.Debug then
        serviceWp.name = "ACTIVATE"
    end
    InsertWaypointTask(serviceWp, TankerTask())
    InsertWaypointAction(serviceWp, ActivateTankerTacanAction(
        self.TACANChannel,
        self.TACANMode,
        self.TACANIdent,
        true,
        false
    ))

    InsertWaypointAction(serviceWp, FrequencyAction(self.Frequency))
    self:SetRoute(route or waypoints)
-- Debug_DrawWaypoints(waypoints)    
-- Debug("nisse - DCAF.Tanker:ActivateService :: waypoints: " .. DumpPrettyDeep(waypoints))
    return self
end

function DCAF.Tanker:SetTrack(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
    if isBoolean(rgbColor) and rgbColor then
        rgbColor = { 1, 1, 0 }
    end
    return setServiceTrack(self, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
end

function DCAF.Tanker:SetTrackDirect(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    if isBoolean(rgbColor) and rgbColor then
        rgbColor = { 0, 1, 1 }
    end
    return setServiceTrack(self, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, true)
end

local function DCAF_Service_OnFuelState(args)
    MissionEvents:OnFuelState(args.Service.Group, args.State, function() args.Func(args.Service) end)
end

local DCAF_AttackedHVAA = { -- dictionary
    -- key = #string :: HVAA group name
}

function AttackHVAA(controllable, nRadius, callsign, callsignNo)
    local group = getGroup(controllable)
    if not group then
        return Warning("AttackAirService :: cannot resolve group from `controlable`: " .. DumpPretty(ControlledPlane)) 
    end
    if not isNumber(nRadius) then 
        nRadius = NauticalMiles(60)
    end
    local coord = group:GetCoordinate()
    local zone = ZONE_GROUP:New(group.GroupName, group, nRadius)
    local set_groups = SET_GROUP:New():FilterZones({ zone }):FilterOnce()
    local hvaaGroups = {}

    local function setupAttack(hvaaGroup)
Debug("AttackAirHVAA :: '" .. group.GroupName .. " attacks " .. hvaaGroup.GroupName)
        local countAttacks = DCAF_AttackedHVAA[hvaaGroup.GroupName]
        if not countAttacks then
            countAttacks = 1
        else
            countAttacks = countAttacks + 1
        end
        DCAF_AttackedHVAA[hvaaGroup.GroupName] = countAttacks
        TaskAttackGroup(group, hvaaGroup)
    end

    local function sortHVAAGroupsForAttack()
        table.sort(hvaaGroups, function(a, b)
            if a == nil then
                return false end

            if b == nil then
                return true end

            local countA = DCAF_AttackedHVAA[a.GroupName]
            local countB = DCAF_AttackedHVAA[b.GroupName]
            if not countA then countA = 0 end
            if not countB then countB = 0 end
            return countA < countB

        end)
        return hvaaGroups
    end

    set_groups:ForEachGroup(function(hvaaGroup)
        local hvaaCallsign, number = IsAirService(hvaaGroup)
        if not hvaaCallsign then 
            return end

        if callsign then
            if callsign ~= hvaaCallsign then
                return end
            
            if callsignNo then
                if callsignNo ~= number then
                    return end
                
                return setupAttack(hvaaGroup)
            else
                return setupAttack(hvaaGroup)
            end
        end

        table.insert(hvaaGroups, hvaaGroup)
    end)

    local sortedHVAA = sortHVAAGroupsForAttack()
    setupAttack(sortedHVAA[1])

end

local function onFuelState(service, state, func)
    local self = service
    if self:IsMissing() then
        return self end

    local args = {
        Service = self,
        State = state,
        Func = func
    }
    DCAF_Service_OnFuelState(args)
    self.Events["OnFuelState"] = { EventFunc = DCAF_Service_OnFuelState, Args = args }
    return self
end

function DCAF.Tanker:OnFuelState(state, func)
    if not isFunction(func) then
        error("DCAF.Tanker:OnFuelState :: func was unassigned/unexpected value: " .. DumpPretty(func)) end

    if self:IsMissing() then
        return self end

    local args = {
        Service = self,
        State = state,
        Func = func
    }
    DCAF_Service_OnFuelState(args)
    self.Events["OnFuelState"] = { EventFunc = DCAF_Service_OnFuelState, Args = args }
    return self
end

function DCAF.Tanker:OnBingoState(func)
    return self:OnFuelState(0.15, func)
end

function DCAF.Tanker:Start(delay)
    if self:IsMissing() then
        return self end

    if isNumber(delay) then
        Delay(delay, function()
            activateNow(self.Group)
        end)
    else
        activateNow(self.Group)
    end
    return self
end

function WaypointLandAt(location, speed)
    local testLocation = DCAF.Location.Resolve(location)
    if not testLocation then
        error("WaypointLandAt :: cannot resolve `location`: " .. DumpPretty(location)) end

    if not testLocation:IsAirbase() then
        error("WaypointLandAt :: `location` is not an airbase") end

    location = testLocation
    local airbase = location.Source
    return location:GetCoordinate():WaypointAirLanding(speed, airbase)
end

function IsOnAirbase(source, airbase)
    local location = DCAF.Location:New(source)
    if not location:IsGrounded() then
        return false end

    if not isAirbase(airbase) then
        if isAssignedString(airbase) then
            local testAirbase = AIRBASE:FindByName(airbase)
            if not testAirbase then
                Warning("IsOnAirbase :: cannot resolve airbase from: " .. DumpPretty(airbase)) 
            end
            airbase = testAirbase
        else
            error("IsOnAirbase :: `airbase` must be #AIRBASE or assigned string, but was: " .. DumpPretty(airbase))
        end
    end

    -- source is on the ground; check nearest airbase...
Debug("nisse - IsOnAirbase :: group: " .. Dump(source.GroupName))

    local closestAirbase = location.Coordinate:GetClosestAirbase()
    if closestAirbase.AirbaseName ~= airbase.AirbaseName then
        return false end

    local coordClosestAirbase = closestAirbase:GetCoordinate()
    return coordClosestAirbase:Get2DDistance(location.Coordinate) < NauticalMiles(2.5)
end

function RTBNow(controllable, airbase, onLandedFunc, altitude, altitudeType)
    local group = getGroup(controllable)
    if not group then 
        return errorOnDebug("RTBNow :: cannot resolve group from " .. DumpPretty(controllable)) end

    if IsOnAirbase(controllable, airbase) then
        -- controllable is already on specified airbase - despawn
-- Debug("nisse - RTBNow_IsOnAirbase :: controllable: " .. DumpPretty(controllable))
        group:Destroy()
        return
    end

    local coord = group:GetCoordinate()
    if isFunction(onLandedFunc) then
        local _onLandedFuncWrapper
        local function onLandedFuncWrapper(event)
            onLandedFunc(event.IniGroup)
            MissionEvents:EndOnAircraftLanded(_onLandedFuncWrapper)
        end
        _onLandedFuncWrapper = onLandedFuncWrapper
        MissionEvents:OnAircraftLanded(_onLandedFuncWrapper)
    end

    local function buildRoute(airbase, wpLanding, enforce_alsoForShips) -- note the @enforce_alsoForShips is only a tamporary hack until we support CASE I, II, and III
Debug("nisse - buildRoute :: airbase:IsShip: " .. Dump(airbase:IsShip()))    
        if airbase:IsShip() and not enforce_alsoForShips then
            return end -- Carriers require custom approach

        if not isAirbase(airbase) then
            error("RTBNow-"..group.GroupName.." :: not an #AIRBASE: " .. DumpPretty(airbase)) end

        local route = {}
        local wpArrive
        local wpInitial
        wpLanding = wpLanding or WaypointLandAt(airbase)
        if not wpLanding then
            error("RTBNow-"..group.GroupName.." :: cannot create landing waypoint for airbase: " .. DumpPretty(airbase)) end

        local abCoord = airbase:GetCoordinate()
        local bearing, distance = GetBearingAndDistance(airbase, group)
        local coordApproach 
        local appoachAltType = COORDINATE.WaypointAltType.RADIO
        local distApproach
        local altApproach
        local altDefault
        if isNumber(altitude) then
            altDefault = altitude
        elseif group:IsAirPlane() then
            altDefault = Feet(15000)
        elseif group:IsHelicopter() then
            altDefault = Feet(500)
        end
        altApproach = altitude or altDefault
        if airbase.isHelipad and group:IsHelicopter() then
-- Debug("nisse - RTB to helipad")            
            distApproach = 1000
        elseif distance > NauticalMiles(25) or group:GetAltitude(true) > Feet(15000) then
            -- approach waypoint 25nm from airbase...
            distApproach = NauticalMiles(25)
            appoachAltType = COORDINATE.WaypointAltType.BARO
        else 
            -- approach 10nm from airbase...
            distApproach = NauticalMiles(15)
        end
        local landingRWY = airbase:GetActiveRunwayLanding()
        if landingRWY then
            bearing = ReciprocalAngle(landingRWY.heading)
        else
            bearing = ReciprocalAngle(bearing)
        end
        coordApproach = abCoord:Translate(distApproach, bearing)
        coordApproach:SetAltitude(altApproach)
        -- we need an 'initial' waypoint (or the approachWP is ignored by DCS) ...
        
        local speedInitial = math.max(Knots(250), group:GetVelocityKMH())
        local coordInitial = coordApproach:Translate(NauticalMiles(1), bearing, altApproach)
        coordInitial:SetAltitude(math.max(group:GetAltitude(), altApproach))
        local wpApproach = coordInitial:WaypointAirTurningPoint(appoachAltType, speedInitial)
        wpInitial = coordApproach:WaypointAirTurningPoint(appoachAltType, Knots(250))
        wpApproach.name = "APPROACH"
        wpInitial.name = "INITIAL"
        return { wpApproach, wpInitial, wpLanding }
    end

    local function buildCarrierRoute(carrier, wpLanding)
        -- return buildRoute(airbase, wpLanding, true)
        local altType = COORDINATE.WaypointAltType.RADIO
        if group:IsHelicopter() then
-- Debug("nisse - RTBNow :: helicopter landing at carrier...")            
            local hdg3oclock = (carrier:GetHeading() + 90) % 360
            local wpDummy = group:GetCoordinate():WaypointAirFlyOverPoint(altType, group:GetVelocityKMH())
            local coordInitial = carrier:GetCoordinate():Translate(NauticalMiles(2), hdg3oclock)
            coordInitial:SetAltitude(Feet(200))
            local wpInitial = coordInitial:WaypointAirTurningPoint(altType, UTILS.KnotsToKmph(100))
            wpInitial.name = "INITIAL"
            if not wpLanding then
                wpLanding = WaypointLandAt(carrier)
            end
            return { wpDummy, wpInitial, wpLanding }
        else
--         -- todo Implement CASE I, II, and III approaches for RTB to carriers
            return buildRoute(airbase, wpLanding, true)
        end
    end

    local wpLanding
    if airbase ~= nil then
        -- landing location was specified, build route to specified airbase ...
        local ab = getAirbase(airbase)
        if not ab then
            return error("RTBNow :: cannot resolve AIRBASE from " .. DumpPretty(airbase)) end
        airbase = ab
    else
        local landingWpIndex, airdrome = HasLandingTask(group)
        if landingWpIndex then
            -- the route ends in a landing WP, just reuse it
            if airdrome then
                -- landing WP was "Landing" type waypoint, with airdrome - not wrapped action. We have the airbase...
                airbase = airdrome
                wpLanding = route[landingWpIndex]
            else
                -- todo ...
                error("nisse - todo")
            end
        end
    end
    local waypoints = buildRoute(airbase, wpLanding) or buildCarrierRoute(airbase, wpLanding)
-- Debug("nisse - RTBNow :: group: " .. group.GroupName .. " :: waypoints: " .. DumpPrettyDeep(waypoints))
    group:Route(waypoints)
    return group, waypoints
end

local function serviceRTB(service, airbase, onLandedFunc)
    local _, waypoints = RTBNow(service.Group, airbase or service.RTBAirbase, onLandedFunc)
    CommandDeactivateBeacon(service.Group)
    return service, waypoints
end

local function serviceSpawnReplacement(service, funcOnSpawned, nDelay)
    local self = service
    if self:IsMissing() then
        return self end

    local function spawnNow()
        service.Spawner = service.Spawner or SPAWN:New(self.Group.GroupName)
        local group = service.Spawner:Spawn()
        if isClass(service, DCAF_SERVICE_TYPE.Tanker) then
            DCAF.Tanker:New(group, self)
        elseif isClass(service, DCAF_SERVICE_TYPE.AWACS) then
            DCAF.AWACS:New(group, self)
        end
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

function DCAF.Tanker:RTB(airbase, onLandedFunc, route)
    local _
    local waypoints
-- Debug("nisse - DCAF.Tanker:RTB :: DCAF.Tanker:RTB :: waypoints: " .. DumpPretty(waypoints))
    if isTable(route) then
        self:SetRoute(route)    
        waypoints = route.Waypoints
-- Debug("nisse - DCAF.Tanker:RTB :: route :: name: " .. route.Name .. " :: waypoints: " .. DumpPrettyDeep(waypoints, 3))
    else
        _, waypoints = serviceRTB(self, airbase, onLandedFunc)
    end
-- Debug("nisse - DCAF.Tanker:RTB :: tanker.Behavior: " .. DumpPretty(self.Behavior.Availability))
    if self.Behavior.Availability == DCAF.AirServiceAvailability.Always and not self.IsBingo then
        -- inject new 'ACTIVATE' WP, to ensure tankers keeps serving fuel while RTB...
        local wp1 = waypoints[1]
        local coord = self.Group:GetCoordinate()
        local hdg = self.Group:GetHeading() --  coord:GetHeadingTo(COORDINATE_FromWaypoint(wp1))
        local speed = self.Group:GetUnit(1):GetVelocityKMH()
        local wpStart = coord:WaypointAirTurningPoint(COORDINATE.WaypointAltType.BARO, speed)
        local wpActivate = coord:Translate(NauticalMiles(1), hdg):WaypointAirTurningPoint(COORDINATE.WaypointAltType.BARO, speed)
-- wpActivate.name = "nisse_activate"        
        table.insert(waypoints, 1, wpStart)
        table.insert(waypoints, 2, wpActivate)
        -- todo consider deactivating at some waypoint near the homeplate
-- Debug("nisse - DCAF.Tanker:RTB :: activates tanker :: waypoints: " .. DumpPrettyDeep(waypoints, 2))
        self:ActivateService(1, waypoints)
    end

    return self
end

function DCAF.Tanker:RTBBingo(airbase, onLandedFunc, route)
    self.IsBingo = true
    return self:RTB(airbase, onLandedFunc, route)
end

function DCAF.Tanker:DespawnOnLanding(nDelaySeconds)
    DestroyOnLanding(self.Group, nDelaySeconds)
    return self
end

function DCAF.Tanker:SpawnReplacement(funcOnSpawned, nDelay)
    return serviceSpawnReplacement(self, funcOnSpawned, nDelay)
end

function DCAF.AWACS:IsMissing()
    return not self.Group
end

function DCAF.AWACS:New(controllable, replicate, callsign, callsignNumber)
    local awacs = DCAF.clone(replicate or DCAF.AWACS)
    awacs._isTemplate = false
    local group = getGroup(controllable)
    if not group then
        -- note: To make code API more versatile we accept a missing group. This allows for reusing same script in missions where not all AWACS are present
        Warning("DCAF.AWACS:New :: cannot resolve group from " .. DumpPretty(controllable))
        return awacs
    end

    -- initiate AWACS ...
    awacs.Group = group
    local defaults
    if callsign ~= nil then
        if not isNumber(callsign) then
            error("DCAF.AWACS:New :: `callsign` must be number but was " .. type(callsign))  end
        if not isNumber(callsignNumber) then
            error("DCAF.AWACS:New :: `callsignNumber` must be number but was " .. type(callsignNumber))  end
        defaults = DCAF_AWACS[callsign][callsignNumber]
    else
        callsign, callsignNumber = GetCallsign(group)
        defaults = DCAF_AWACS[CALLSIGN.AWACS:FromString(callsign)][callsignNumber]
    end
    Trace("DCAF.DCAF_AWACS:New :: callsign: " .. Dump(callsign) .. " " .. Dump(callsignNumber) .. " :: defaults: " .. DumpPrettyDeep(defaults))
    if defaults then
        awacs.TrackBlock = defaults.TrackBlock
        awacs.TrackSpeed = defaults.TrackSpeed
    else
        awacs.TrackBlock = 35
        awacs.TrackSpeed = 430
    end
    awacs.RTBAirbase = GetRTBAirbaseFromRoute(group)
    
    if awacs.Track and awacs.Track.Route then
        -- replicate route from previous AWACS ...
        group:Route(awacs.Track.Route)
    end

    -- register all events (from replicate)
    for _, event in pairs(awacs.Events) do
        event.EventFunc(event.Args)
    end

    return awacs
end

function DCAF.AWACS:NewFromCallsign(callsign, callsignNumber)
    if callsign == nil then
        error("DCAF.AWACS:New :: callsign group was not specified") end

    local group 
    local groups = _DATABASE.GROUPS
    local callsignName = CALLSIGN.AWACS:ToString(callsign)
    for _, g in pairs(groups) do
        if g:IsAir() then
            local csName, csNumber = GetCallsign(g:GetUnit(1))
            if csName == callsignName and csNumber == callsignNumber then
                group = g
                break
            end
        end
    end

    return DCAF.AWACS:New(group)
end

function DCAF.AWACS:GetWaypoints()
    return getAirServiceWaypoints(self)
end

function DCAF.AWACS:SetTrack(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
    if isBoolean(rgbColor) and rgbColor then
        rgbColor = { 0, 1, 1 }
    end
    return setServiceTrack(self, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, direct)
end

function DCAF.AWACS:SetTrackDirect(nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName)
    if isBoolean(rgbColor) and rgbColor then
        rgbColor = { 0, 1, 1 }
    end
    return setServiceTrack(self, nStartWp, nHeading, nLength, nBlock, rgbColor, sTrackName, true)
end

function DCAF.AWACS:OnFuelState(state, func)
    if not isFunction(func) then
        error("DCAF.Tanker:OnFuelState :: func was unassigned/unexpected value: " .. DumpPretty(func)) end
    
    return onFuelState(self, state, func)
end

function DCAF.AWACS:OnBingoState(func)
    return self:OnFuelState(0.15, func)
end

function DCAF.AWACS:Start(delay)
    if self:IsMissing() then
        return self end

    if isNumber(delay) then
        Delay(delay, function()
            activateNow(self.Group)
        end)
    else
        activateNow(self.Group)
    end
    return self
end

function DCAF.AWACS:SetRoute(route)
    SetAirServiceRoute(self, route)
    return self
end

function DCAF.AWACS:RTB(airbase, onLandedFunc)
    return serviceRTB(self, airbase, onLandedFunc)
end

function DCAF.AWACS:DespawnOnLanding(nDelaySeconds)
    DestroyOnLanding(self.Group, nDelaySeconds)
    return self
end

function DCAF.AWACS:SpawnReplacement(funcOnSpawned, nDelay)
    return serviceSpawnReplacement(self)
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                         AIR SERVICE TRACKS / ASSIGNMENTS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.AirServiceAvailability = {
    InTrack = "In Track",
    Always = "Always"
}

DCAF.AirServiceBehavior = {
    ClassName = "DCAF.AirServiceBehavior",
    SpawnReplacementFuelState = .22,
    BingoFuelState = .17,    -- #number - percentage of full fuel that defines BINGO fuel state
    RtbAirdrome = nil,       -- 
    Availability = DCAF.AirServiceAvailability.InTrack,
    NotifyAssignmentScope = '_none_' -- #Any - coalition (eg. coalition.side.BLUE), #GROUP (or group name) or '_none_'
}

function DCAF.AirServiceBehavior:New()
    return DCAF.clone(DCAF.AirServiceBehavior)
end

function DCAF.AirServiceBehavior:RTB(airdrome, fuelState)
    if airdrome ~= nil and not isAssignedString(airdrome) then
        error("DCAF.AirServiceBehavior:RTB :: `airdrome` is expected to be a string, but was " .. type(airdrome)) end

    if not isNumber(fuelState) then
        fuelState = DCAF.AirServiceBehavior.BingoFuelState
    end
    self.RtbAirdrome = AIRBASE:FindByName(airdrome)
    self.BingoFuelState = fuelState
    return self
end

function DCAF.AirServiceBehavior:NotifyAssignment(recipient)
    self.NotifyAssignmentScope = recipient
    return self
end

function DCAF.AirServiceBehavior:SpawnReplacement(fuelState)
    if not isNumber(fuelState) then
        error("DCAF.AirServiceBehavior:SpawnReplacement :: `fuelState` is expected to be number, but was " .. type(fuelState)) end
    
   self.SpawnReplacementFuelState = fuelState
   return self
end

function DCAF.AirServiceBehavior:WithAvailability(availability, delaySeconds)
    if not DCAF.AirServiceAvailability:IsValid(availability) then
        error("DCAF.AirServiceBehavior:SetAvailability :: invalid value: " .. DumpPretty(availability)) end

    if availability == DCAF.AirServiceAvailability.Delayed then
        if not isNumber(delaySeconds) or delaySeconds < 1 then
            error("DCAF.AirServiceBehavior:SetAvailability :: `delaySeconds` musty be positive value, but was: " .. Dump(delaySeconds)) end

        self.AvailabilityDelay = delaySeconds
    end
    self.Availability = availability
    return self
end

function DCAF.AirServiceAvailability:IsValid(value)
    if not isAssignedString(value) then
        return false end

    for k, v in pairs(DCAF.AirServiceAvailability) do
        if value == v then
            return true 
        end
    end
    return false
end

DCAF.AvailableTanker = { -- todo Remove and use DCAF.Tanker instead
    ClassName = "DCAF.AvailableTanker",
    Callsign = nil,     -- #number
    Number = nil,       -- #number
    Group = nil,        -- #GROUP
    Track = nil,        -- #DCAF.TankerTrack
    Unlimited = false,  -- #bool - true = any number of this tanker can be spawned; false = tanker can be respawned 15 mins after landing
    DelayAvailability = Minutes(15) -- #int (seconds) - < 0 = can be spawned when goes active; 0 = can be spawned when landed; > 0 = can be spawned after delay
}

local AAR_TANKERS = {
    -- list of #DCAF.AvailableTanker
}

DCAF.TankerTracks = {
    -- list of #DCAF.TankerTrack
}

DCAF.TrackAppearance = {
    IdleColor = {0, .5, .5},
    ActiveColor = {0, 1, 1},
}

local DCAF_AirServiceBase = {
    ClassName = "DCAF_AirServiceBase",
    Airbase = nil,          -- #AIRBASE
    Routes = nil,           -- list of #DCAF.AIR_ROUTE
    RTBRoutes = nil         -- list of #DCAF.AIR_ROUTE
}

function DCAF_AirServiceBase:New(airbase)
    local base = DCAF.clone(DCAF_AirServiceBase)
    base.Airbase = airbase
    return base
end

function DCAF_AirServiceBase:AddRoute(route)
    if not isList(self.Routes) then
        self.Routes = {}
    end
    table.insert(self.Routes, route)
    return self
end

function DCAF_AirServiceBase:AddRTBRoute(rtbRoute)
    if not isList(self.RTBRoutes) then
        self.RTBRoutes = {}
    end
    table.insert(self.RTBRoutes, rtbRoute)
    return self
end

function DCAF.TrackAppearance:New(idleColor, activeColor)
    local appearance = DCAF.clone(DCAF.TrackAppearance)
    appearance.IdleColor = idleColor or DCAF.TrackAppearance.IdleColor
    appearance.ActiveColor = activeColor or DCAF.TrackAppearance.ActiveColor
    return appearance
end

function DCAF.AvailableTanker:New(callsign, number, airbases)
    local tanker = DCAF.clone(DCAF.AvailableTanker)
    tanker.Callsign = callsign
    tanker.Number = number
    if isAssignedString(airbases) then
        airbases = { airbases }
    end
    if (isList(airbases)) then
        for _, airbase in ipairs(airbases) do
            tanker:FromAirbase(airbase)
        end
    end
    table.insert(AAR_TANKERS, tanker)
    return tanker
end

function DCAF.AvailableTanker:IsActive()
    return self.Group ~= nil
end

function DCAF.AvailableTanker:Activate(group, track)
    self.Group = group
    self.GroupRTB = nil
    self.Track = track
    return self
end

function DCAF.AvailableTanker:Deactivate(isRTB)
    if not isBoolean(isRTB) then
        isRTB = true 
    end
    if isRTB then
        self.GroupRTB = self.Group
    end
    self.Group = nil
    self.Track = nil
    return self
end

function DCAF.AvailableTanker:ToString()
    return CALLSIGN.Tanker:ToString(self.Callsign, self.Number)
end

function DCAF.AvailableTanker:FromAirbases(airbases)
    if not isList(airbases) then
        error("DCAF.AvailableTanker:FromAirbases :: `airbases` must be a list, but was: " .. DumpPretty) end

    for _, airbase in ipairs(airbases) do
        self:FromAirbase(airbase)
    end
end

function DCAF.AvailableTanker:FromAirbase(airbase, depRoutes, arrRoutes)
    if not isList(self.Airbases) then 
        self.Airbases = {}
    end
    if isAssignedString(airbase) then
        local testAirbase = AIRBASE:FindByName(airbase)
        if not testAirbase then
            error("DCAF.AvailableTanker:FromAirbase :: cannot resolve airbase from: " .. DumpPretty(airbase)) end

        airbase = testAirbase
    elseif not isAirbase(airbase) then
        error("DCAF.AvailableTanker:FromAirbase :: expected `airbase` to be #AIRBASE, or assigned string (airbase name), but was: " .. DumpPretty(airbase))
    end
    local base = DCAF_AirServiceBase:New(airbase)
    table.insert(self.Airbases, base)
    if not isList(depRoutes) and DCAF.AIRAC then
        depRoutes = DCAF.AIRAC:GetDepartureRoutes(airbase)
    end    
    local hasRoutes = isList(depRoutes)
    if hasRoutes then
        for _, route in ipairs(depRoutes) do
            if not isClass(route, DCAF.AIR_ROUTE.ClassName) then
                error("DCAF.AvailableTanker:FromAirbase :: route #" .. Dump(i) .. " was not type '" .. DCAF.AIR_ROUTE.ClassName .. "'") end
                
            base:AddRoute(route)
        end
    end
    if not isList(arrRoutes) then
        if DCAF.AIRAC then
            arrRoutes = DCAF.AIRAC:GetArrivalRoutes(airbase)
-- Debug("nisse - DCAF.AvailableTanker:FromAirbase :: arrRoutes: " .. DumpPretty(arrRoutes))
        elseif hasRoutes then
            -- use reversed routes for RTB...
            arrRoutes = {}
            for _, route in ipairs(depRoutes) do
                local revRoute = route:CloneReversed("(rev) " .. route.Name)
                local coordLanding = route.DepartureAirbase:GetCoordinate()
                local wpLanding = coordLanding:WaypointAirLanding(250, route.DepartureAirbase)
                table.insert(revRoute.Waypoints, #revRoute.Waypoints+1, wpLanding)
                table.insert(arrRoutes, revRoute)
            end
        end
    end
    if isList(arrRoutes) then
        for _, arrRoute in ipairs(arrRoutes) do
            if not isClass(arrRoute, DCAF.AIR_ROUTE.ClassName) then
                error("DCAF.AvailableTanker:FromAirbase :: route #" .. Dump(i) .. " was not type '" .. DCAF.AIR_ROUTE.ClassName .. "'") end
                
            base:AddRTBRoute(arrRoute)
        end
    end

    return self
end

DCAF.TankerTrack = {
    ClassName = "DCAF.TankerTrack",
    Name = nil,
    CoordIP = nil,
    Heading = nil,
    Length = nil,
    Capacity = 2,           -- #number - no. of tankers thack can work this track
    DefaultBehavior = nil,  -- #DCAF.AirServiceBehavior
    DrawIdle = true,
    IsDynamic = false,      -- #boolean - true = track was created from a F10 map marker
    Tankers = {
        -- list of #DCAF.AvailableTanker (currently active in track)
    },
    Frequencies = {
        -- list of #number (primary + secondary frequency, if used)
    },
    Blocks = {
        -- list i #number (primary + secondary altitude block [in K of feet MSL], is used)
    },
    Width = NauticalMiles(13),
    InfoAnchorPoint = nil        -- #number - nil = (auto), 1..4 = Southeast, Northeast, Northwest, and Southwest corner in north-facing track (rotates with track heading)
}

local function getFrequency(track)
    if not track.Frequencies or #track.Frequencies == nil then
        return end

    local index = #track.Tankers+1
    return track.Frequencies[index]
end

local function getBlock(track)
    if not track.Blocks or #track.Blocks == nil then
        return end

    local index = #track.Tankers+1
    return track.Blocks[index]
end

function DCAF.TankerTrack:New(name, coalition, heading, coordIP, length, frequencies, blocks, capacity, behavior, appearance)
Debug("nisse - DCAF.TankerTrack:New :: name: " .. Dump(name) .. " :: coalition: " .. Dump(coalition) .. " :: heading: " .. Dump(heading))
    local track = DCAF.clone(DCAF.TankerTrack)
    track.Name = name
    track.Heading = heading
    track.CoordIP = coordIP
    track.Length = length or NauticalMiles(30)
    track.Capacity = capacity or DCAF.TankerTrack.Capacity
    track.DefaultBehavior = behavior or DCAF.TankerTrack.DefaultBehavior
    track.Appearance = appearance or DCAF.TrackAppearance:New()
    track.Coalition = Coalition.ToNumber(coalition)
    if isTable(frequencies) then
        track.Frequencies = frequencies
    else
        track.Frequencies = {}
    end
    if isTable(blocks) then
        track.Blocks = blocks
    else
        track.Blocks = {}
    end
    table.insert(DCAF.TankerTracks, track)
    return track
end

function DCAF.TankerTrack:AddTanker(tankerInfo, drawUpdate)
    if not isBoolean(drawUpdate) then
        drawUpdate = true
    end
    table.insert(self.Tankers, tankerInfo)
    if (drawUpdate and self.IsDrawn) then
        self:Draw()
    end
end

function DCAF.TankerTrack:RemoveTanker(tankerInfo, drawUpdate)
    if not isBoolean(drawUpdate) then
        drawUpdate = true
    end
    local index = tableIndexOf(self.Tankers, function(info)
        return info.Callsign == tankerInfo.Callsign and info.Number == tankerInfo.Number
    end)
    if index then
        table.remove(self.Tankers, index)
        if #self.Tankers == 0 then
            self:Deactivate()
        end
        if (drawUpdate and self.IsDrawn) then
            self:Draw()
        end
    end
end

local function notifyTankerAssignment(track, tanker, isReassigned, airbase)
    local behavior = tanker.Behavior
    if behavior.NotifyAssignmentScope == '_none_' then
        return end

    local freq = tanker.Frequency
    local msg1, msg2
    if airbase then
        msg1 = tanker.DisplayName .. " is departing " .. airbase.AirbaseName .. " for track '" .. track.Name .. "' (freq: " .. string.format("%.3f", freq) .. ")"
        if behavior.Availability == DCAF.AirServiceAvailability.Always then
            msg2 = tanker.DisplayName .. " should be available in 10 minutes or less"
        else
            msg2 = tanker.DisplayName .. " will become available once it reaches the track"
        end
    elseif isReassigned then
        msg1 = tanker.DisplayName .. " was reassigned to track '" .. track.Name .. "' (freq: " .. string.format("%.3f", freq) .. ")"
    else
        msg1 = tanker.DisplayName .. " is approaching track '" .. track.Name .. "' (freq: " .. string.format("%.3f", freq)
    end
    
    local duration = 12
    MessageTo(behavior.NotifyAssignmentScope, msg1, duration)
    if not msg2 then
        msg2 = tanker.DisplayName .. " should be available in a minute or less"
        if behavior.Availability == DCAF.AirServiceAvailability.InTrack then
            msg2 = tanker.DisplayName .. " will become available once it reaches the track"
        end
    end
    MessageTo(behavior.NotifyAssignmentScope, msg2, duration)
end

--- Activates a tanker in air to work this track
function DCAF.TankerTrack:ActivateAir(tankerInfo, behavior)
    if tankerInfo.GroupRTB then
        self:Reassign(tankerInfo)
        return
    end

    local revHdg = ReciprocalAngle(self.Heading)
    local coordSpawn = self.CoordIP:Translate(NauticalMiles(15), revHdg)
    coordSpawn:SetAltitude(Feet(20000))
    local group = DCAF.Tanker:FindGroupWithCallsign(tankerInfo.Callsign, tankerInfo.Number)
    local spawn = getSpawn(group.GroupName)
    spawn:InitHeading(self.Heading, self.Heading)
    local wp0 = coordSpawn:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, 350)
    local wp1 = self.CoordIP:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, 350)
    local wp2
    if not isClass(behavior, DCAF.AirServiceBehavior.ClassName) then
        behavior = self.DefaultBehavior or DCAF.AirServiceBehavior:New()
    end
    local availability = behavior.Availability
    local trackIP = 1
    if availability ~= DCAF.AirServiceAvailability.InTrack then
        if availability == DCAF.AirServiceAvailability.Always then
            -- inject nearby WP to activate service ...
            wp2 = wp1
            local coordActivate = coordSpawn:Translate(NauticalMiles(.5), self.Heading)
            wp1 = coordActivate:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, 350)
            trackIP = 2
        else
            error("DCAF.TankerTrack:ActivateAir :: unsupported availabilty behavior: " .. DumpPretty(availability))
        end
    end
    local group = spawn:SpawnFromCoordinate(coordSpawn)
    group:CommandSetCallsign(tankerInfo.Callsign, tankerInfo.Number)
    tankerInfo.Tanker = DCAF.Tanker:New(group, nil, tankerInfo.Callsign, tankerInfo.Number)
                                   :SetRoute({ wp0, wp1, wp2 })
    tankerInfo.Tanker.Behavior = behavior
    local freq = getFrequency(self) or tankerInfo.Tanker.Frequency
    local block = getBlock(self) or tankerInfo.Tanker.TrackBlock
    if freq then
        tankerInfo.Tanker:InitFrequency(freq)
    end
    if availability == DCAF.AirServiceAvailability.Always then
        tankerInfo.Tanker:ActivateService(1)
    end
    tankerInfo.Tanker:SetTrack(trackIP, self.Heading, self.Length, block)
    if tankerInfo.Tanker.Behavior.SpawnReplacementFuelState > 0 then
        tankerInfo.Tanker:OnFuelState(tankerInfo.Tanker.Behavior.SpawnReplacementFuelState, function(tanker)
            tanker:SpawnReplacement()
        end)
    end
    if tankerInfo.Tanker.Behavior.BingoFuelState > 0 then
        tankerInfo.Tanker:OnFuelState(tankerInfo.Tanker.Behavior.BingoFuelState, function(tanker)
            tanker:RTBBingo(tankerInfo.Tanker.Behavior.RtbAirdrome)
        end)
    end
    tankerInfo.Tanker:Start()
    tankerInfo:Activate(group, self)
    self:AddTanker(tankerInfo)
    notifyTankerAssignment(self, tankerInfo.Tanker)
    return self
end

--- Activates a tanker at an airbase to work this track
-- @tankerInfo :: #DCAF.AvailableTanker
-- @waypoints  :: #Any -- can be #table of waypoints or #AIRBASE
-- @behavior   :: 
function DCAF.TankerTrack:ActivateAirbase(tankerInfo, route, behavior)
    -- resolve route...
    local airbase
    local wpIP
    local waypoints    

    local function trackIngressWaypoints()
        local revHdg = ReciprocalAngle(self.Heading)
        wpIP = self.CoordIP:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, UTILS.KnotsToKmph(350))
        wpIP.name = "TRACK IP"
        local coordIngress = self.CoordIP:Translate(NauticalMiles(15), revHdg)
        coordIngress:SetAltitude(Feet(20000))
        local wpIngress = coordIngress:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, UTILS.KnotsToKmph(370))
        wpIngress.name = "TRACK INGRESS"
        wpIngress.speed = Knots(370)
        return { wpIngress, wpIP }
    end

-- Debug("nisse - DCAF.TankerTrack:ActivateAirbase :: route: " .. DumpPretty(route))

    if DCAF.AIR_ROUTE and isRoute(route) then
        airbase = route.DepartureAirbase
        waypoints = listJoin(route.Waypoints, trackIngressWaypoints())
        wpIP = #route.Waypoints
    elseif isAirbase(route) then
        airbase = route
        local coordAirbase = airbase:GetCoordinate()
        local wpDeparture = coordAirbase:WaypointAirTakeOffParkingHot(COORDINATE.WaypointAltType.BARO) -- todo consider ability to configure type of takeoff
        wpDeparture.airdromeId = airbase:GetID()
        waypoints = listJoin({ wpDeparture }, trackIngressWaypoints())
        wpIP = 2
-- Debug("nisse - DCAF.TankerTrack:ActivateAirbase (aaa) :: wpIP: " .. Dump(wpIP) .. " :: waypoints: " .. DumpPrettyDeep(waypoints, 2))
    else
        local msg = "DCAF.TankerTrack:ActivateAirbase :: `route` must be an " .. AIRBASE.ClassName
        if DCAF.AIR_ROUTE then
            msg = msg .. " or " ..  DCAF.AIR_ROUTE.ClassName
        end
        error(msg)
    end
    if not isNumber(wpIP) then
        wpIP = 1
    end
    
    -- spawn...
    local group = DCAF.Tanker:FindGroupWithCallsign(tankerInfo.Callsign, tankerInfo.Number)
    local spawn = getSpawn(group.GroupName)
    spawn:InitGroupHeading(self.Heading)
    local group = spawn:SpawnAtAirbase(airbase)
    tankerInfo.Tanker = DCAF.Tanker:New(group, nil, tankerInfo.Callsign, tankerInfo.Number)
    if isClass(behavior, DCAF.AirServiceBehavior.ClassName) then
        tankerInfo.Tanker.Behavior = behavior
    else
        tankerInfo.Tanker.Behavior = self.DefaultBehavior or DCAF.AirServiceBehavior:New()
    end

    behavior = tankerInfo.Tanker.Behavior
    if behavior.Availability == DCAF.AirServiceAvailability.Always then
        -- inject WP 10nm from airbase, where the tanker activates...
        local coord0 = COORDINATE_FromWaypoint(waypoints[1])
        local coordIP = COORDINATE_FromWaypoint(waypoints[2])
        local distance = UTILS.MetersToNM(coord0:Get2DDistance(coordIP))
        if distance > 20 then
            local heading = coord0:HeadingTo(coordIP)
            local coordActivate = coord0:Translate(NauticalMiles(10))
            local wpActivate = coord0:Translate(NauticalMiles(10), heading):SetAltitude(Feet(15000)):WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, UTILS.KnotsToKmph(350))
            table.insert(waypoints, 2, wpActivate)
            wpIP = wpIP+1
        end
    end
    tankerInfo.Tanker:SetRoute(waypoints)
    tankerInfo.Tanker.Behavior.RtbAirdrome = airbase

    local freq = getFrequency(self) or tankerInfo.Tanker.Frequency
    local block = getBlock(self) or tankerInfo.Tanker.TrackBlock
    if freq then
        tankerInfo.Tanker:InitFrequency(freq)
    end
    if behavior.Availability == DCAF.AirServiceAvailability.Always then
        tankerInfo.Tanker:ActivateService(1)
-- Debug("nisse - DCAF.TankerTrack:ActivateAirbase (bbb) :: wpIP: " .. Dump(wpIP) .. " :: waypoints: " .. DumpPrettyDeep(waypoints, 2))
    end
    tankerInfo.Tanker:SetTrack(wpIP, self.Heading, self.Length, block):Start()
    if tankerInfo.Tanker.Behavior.SpawnReplacementFuelState > 0 then
        tankerInfo.Tanker:OnFuelState(tankerInfo.Tanker.Behavior.SpawnReplacementFuelState, function(tanker)
            tanker:SpawnReplacement()
        end)
    end
    if tankerInfo.Tanker.Behavior.BingoFuelState > 0 then
        tankerInfo.Tanker:OnFuelState(tankerInfo.Tanker.Behavior.BingoFuelState, function(tanker)
            tanker:RTBBingo(tankerInfo.Tanker.Behavior.RtbAirdrome)
        end)
    end
    tankerInfo.Tanker:Start()
    tankerInfo:Activate(group, self)
    self:AddTanker(tankerInfo)
    notifyTankerAssignment(self, tankerInfo.Tanker, false, airbase)
    return self
end

--- Reassigns an already active tanker from its current track to this track
function DCAF.TankerTrack:Reassign(tankerInfo)
    if tankerInfo.GroupRTB then
        tankerInfo.Group = tankerInfo.GroupRTB
        tankerInfo.GroupRTB = nil
    end
    local speed = UTILS.KnotsToKmph(350)
    local coord = tankerInfo.Group:GetCoordinate()
    local alt = tankerInfo.Group:GetAltitude()
    local revHdg = ReciprocalAngle(self.Heading)
    local coordIngress = self.CoordIP:Translate(NauticalMiles(15), revHdg):SetAltitude(alt) -- todo Consider setting correct entry altitude
    local heading = tankerInfo.Group:GetHeading() -- coord:GetHeadingTo(coordIngress)
    local group = tankerInfo.Group
    local wp0 = coord:Translate(100, heading):SetAltitude(alt):WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed) -- pointless "inital" waypoint
    wp0.name = "INIT"
    local wpReassign = coord:Translate(NauticalMiles(.5), heading):SetAltitude(alt):WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
    wpReassign.Name = "REASSIGN"
    local wpIngress = coordIngress:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
    wpIngress.name = "INGRESS"
    local wpTrack = self.CoordIP:WaypointAirFlyOverPoint(COORDINATE.WaypointAltType.BARO, speed)
    local waypoints = { wp0, wpIngress, wpTrack }
    local trackIP = 2
    local availability = tankerInfo.Tanker.Behavior.Availability
    if availability == DCAF.AirServiceAvailability.Always then
        -- inject nearby WP to activate service ...
        table.insert(waypoints, 2, wpReassign)
        trackIP = 3
    elseif availability ~= DCAF.AirServiceAvailability.InTrack then
        error("DCAF.TankerTrack:ActivateAir :: unsupported availabilty behavior: " .. DumpPretty(availability))
    end
    tankerInfo.Tanker:SetRoute(waypoints)

--Debug_DrawWaypoints(waypoints)

    if availability == DCAF.AirServiceAvailability.Always then
        local freq = getFrequency(self) or tankerInfo.Tanker.Frequency
        if freq then
            tankerInfo.Tanker:InitFrequency(freq)
        end
        tankerInfo.Tanker:ActivateService(1)
    end
    local block = getBlock(self) or tankerInfo.Tanker.TrackBlock
    tankerInfo.Tanker:SetTrack(trackIP, self.Heading, self.Length, block):Start()
    if tankerInfo.Track then
        tankerInfo.Track:RemoveTanker(tankerInfo)
    end
    self:AddTanker(tankerInfo)
    tankerInfo:Activate(group, self)
    local behavior = tankerInfo.Tanker.Behavior
    notifyTankerAssignment(self, tankerInfo.Tanker, true)
    return self
end

function DCAF.TankerTrack:Deactivate()
    for _, tankerInfo in pairs(self.Tankers) do
        tankerInfo.Tanker:RTB(tankerInfo.Tanker.Behavior.RtbAirdrome)
        tankerInfo:Deactivate()
    end
    self.Tankers = {}
    if self.IsDrawn and self.IsDrawn then
        self:Draw()
    end
end

local function drawArc(coordCenter, radius, heading, coalition, rgbColor, lineType, alpha, readOnly, countPoints)
    if not isNumber(countPoints) then
        countPoints = 10
    end
    local perpHeading = (heading + 90) % 360
    local incHeading = 180 / countPoints
    local wp1 = coordCenter:Translate(radius, perpHeading)
    local hdg2 = (perpHeading - incHeading) % 360
    local markIDs = {}
    local wp2
    local markID
    for i = 1, countPoints, 1 do
        wp2 = coordCenter:Translate(radius, hdg2)
        markID = wp1:LineToAll(wp2, coalition, rgbColor, alpha, lineType, readOnly)
        table.insert(markIDs, markID)
        wp1 = wp2
        hdg2 = hdg2 - incHeading
    end
    return markIDs
end

local function drawServiceTrackInfo(track)
    local rgbColor 
    if isTable(track.Color) then
        rgbColor = track.Color
    else
        rgbColor = {0,1,1}
    end
    local width = track.Width
    local heading = track.Heading
    local revHeading = (heading - 180) % 360
    local length = track.Length
    local perpHeading = (heading - 90) % 360
    local radius = width * .5

    local function getAnchorPoint()
        local hdg = heading
        if track.InfoAnchorPoint == 1 then 
            hdg = 45
        elseif track.InfoAnchorPoint == 2 then 
            hdg = 135
        elseif track.InfoAnchorPoint == 3 then 
            hdg = 215
        elseif track.InfoAnchorPoint == 4 then 
            hdg = 315
        end

        if hdg > 0 and hdg < 90 then
            return track.CoordIP:Translate(radius, revHeading)
        elseif hdg >= 90 and hdg < 180 then
            return track.CoordIP:Translate(length + radius, heading)
        elseif hdg >= 180 and hdg < 270 then
            return track.CoordIP:Translate(length + radius, heading):Translate(width, perpHeading)
        else
            return track.CoordIP:Translate(radius, revHeading):Translate(width, perpHeading)
        end
    end

    local text = "\n" .. track.Name
    local tankersText = ""
    local alpha = .5
    for _, tankerInfo in ipairs(track.Tankers) do
        alpha = 1
        local tanker = tankerInfo.Tanker
        tankersText = tankersText .. "\n" .. tanker.DisplayName
        local prefix = '\n  '
        if (tanker.Frequency) then
            tankersText = tankersText .. prefix .. string.format("%.3f", tanker.Frequency)
            prefix = "  "
        end
        if tanker.TACANChannel and tanker.TACANMode then
            tankersText = tankersText .. prefix .. tostring(tanker.TACANChannel) .. tanker.TACANMode
            prefix = " "
        end
        if isAssignedString(tanker.TACANIdent) then
            tankersText = tankersText .. prefix .. "[" .. tanker.TACANIdent .. "]"
        end
    end
    if isAssignedString(tankersText) then
        text = text .. "\n" .. newString('=', 15) .. tankersText
    end
    local anchor = getAnchorPoint()
    return anchor:TextToAll(text, track.Coalition, rgbColor, alpha, nil, 0, 11, true)
end

local function drawActiveServiceTrack(track)
    local rgbColor 
    if isTable(track.Color) then
        rgbColor = track.Color
    else
        rgbColor = {0,1,1}
    end
    local width = track.Width
    local heading = track.Heading
    local revHeading = (heading - 180) % 360
    local length = track.Length
    local perpHeading = (heading - 90) % 360
    local radius = width * .5

    -- first leg
    local wp1 = track.CoordIP
    local wp2 = wp1:Translate(length, heading)
    local markID = wp1:LineToAll(wp2, track.Coalition, rgbColor, .5, 1, true)
    --table.insert(markIDs, markID)

    -- end arc
    local coordCenter = wp2:Translate(radius, perpHeading)
    local arcMarkIDs = drawArc(coordCenter, radius, heading, track.Coalition, rgbColor, 1, .5, true)
    local markIDs = listJoin({ markID }, arcMarkIDs)

    -- second leg
    wp1 = wp1:Translate(width, perpHeading)
    wp2 = wp1:Translate(length, heading)
    markID = wp1:LineToAll(wp2, track.Coalition, rgbColor, .5, 1, true)
    table.insert(markIDs, markID)

    -- end arc
    coordCenter = track.CoordIP:Translate(radius, perpHeading)
    arcMarkIDs = drawArc(coordCenter, radius, revHeading, track.Coalition, rgbColor, 1, .5, true)
    markIDs = listJoin(markIDs, arcMarkIDs)

    -- info block 
    markID = drawServiceTrackInfo(track)
    table.insert(markIDs, markID)

    return markIDs
end

local function drawIdleServiceTrack(track)
    local markIDs = {}
    local rgbColor 
    if isTable(track.Color) then
        rgbColor = track.Color
    else
        rgbColor = {0,1,1}
    end
    local width = track.Width
    local heading = track.Heading
    local revHeading = (heading - 180) % 360
    local length = track.Length
    local perpHeading = (heading - 90) % 360
    local radius = width * .5

    -- base triangle
    local wp1 = track.CoordIP:Translate(radius, perpHeading)
    local wp2 = track.CoordIP:Translate(radius * .5, revHeading)
    local wp3 = wp2:Translate(width, perpHeading)
    local markID = wp1:MarkupToAllFreeForm({wp2, wp3}, track.Coalition, rgbColor, .5, nil, .15, 3, true)
    table.insert(markIDs, markID)

    -- line
    wp2 = wp1:Translate(length + radius, heading)
    markID = wp1:LineToAll(wp2, track.Coalition, rgbColor, .5, 3, true)
    table.insert(markIDs, markID)

    -- end line
    wp1 = track.CoordIP:Translate(length + radius, heading)
    wp2 = wp1:Translate(width, perpHeading)
    markID = wp1:LineToAll(wp2, track.Coalition, rgbColor, .5, 3, true)
    table.insert(markIDs, markID)

    -- info block 
    markID = drawServiceTrackInfo(track)
    table.insert(markIDs, markID)

    return markIDs
end

function DCAF.TankerTrack:Draw(infoAnchorPoint)
    self.IsDrawn = true
    if isNumber(infoAnchorPoint) then
        self.InfoAnchorPoint = infoAnchorPoint
    end
    self:EraseTrack()
    if self:IsActive() then
        self._isActiveMarkIDs = true
        self._markIDs = drawActiveServiceTrack(self)
    else
        self._isActiveMarkIDs = false
        self._markIDs = drawIdleServiceTrack(self)
    end
    return self
end

function DCAF.TankerTrack:EraseTrack(hide)
    if isBoolean(hide) and hide then
        self.IsDrawn = false
    end
    if isTable(self._markIDs) then
        for _, markID in ipairs(self._markIDs) do
            self.CoordIP:RemoveMark(markID)
        end
    end
    self._markIDs = nil
end

function DCAF.TankerTrack:IsActive()
    return #self.Tankers > 0
end

function DCAF.TankerTrack:IsFull()
    return #self.Tankers == self.Capacity
end

function DCAF.TankerTrack:IsBlocked()
    return self.BlockedWhenActive and self.BlockedWhenActive:IsActive()
end

function DCAF.TankerTracks:GetActiveTankers()
    local result = {}
    for _, track in ipairs(DCAF.TankerTracks) do
        for _, tanker in pairs(track.Tankers) do
            table.insert(result, { Tanker = tanker, Track = track })
        end 
    end
    return result
end

local _tanker_menu

local function sortedTracks()
    table.sort(DCAF.TankerTracks, function(a, b) 
        if a and b then
            if a.IsActive and not b.IsActive then
                return true
            elseif b.IsActive and not a.IsActive then
                return false
            else
                local result = a.Name < b.Name
                return result
            end
        elseif a then 
            return true
        else 
            return false 
        end
    end)
    return DCAF.TankerTracks
end

local isDynamicTankerTracksSupported = false
local rebuildTankerMenus
local _defaultTankerMenuCaption
local _defaultTankerMenuScope
local function buildTankerMenus(caption, scope)
    if not isAssignedString(caption) then
        caption = _defaultTankerMenuCaption or "Tankers"
    end
    _defaultTankerMenuCaption = caption
    local dcafCoalition = Coalition.Resolve(scope or _defaultTankerMenuScope, true)
    local group
    if not dcafCoalition then
        group = getGroup(scope)
        if not group then
            error("buildTankerMenus :: unrecognized `scope` (expected #Coalition or #GROUP/group name): " .. DumpPretty(scope)) end

        dcafCoalition = group:GetCoalition()
    end
    _defaultTankerMenuScope = group or dcafCoalition
    local tracks = sortedTracks()
    if _tanker_menu then
        _tanker_menu:RemoveSubMenus()
    else
        if group then
            _tanker_menu = MENU_GROUP:New(group, caption)
        else
            _tanker_menu = MENU_COALITION:New(dcafCoalition, caption)
        end
    end
    for _, track in ipairs(tracks) do
        local menuTrack
        if group then
            menuTrack = MENU_GROUP:New(group, track.Name, _tanker_menu)
        else
            menuTrack = MENU_COALITION:New(dcafCoalition, track.Name, _tanker_menu)
        end

        if not track:IsBlocked() then
            if track:IsActive() then
                local function deactivateTrack()
                    track:Deactivate()
                    rebuildTankerMenus(caption, scope)
                end
                if group then
                    MENU_GROUP_COMMAND:New(group, "DEACTIVATE", menuTrack, deactivateTrack)
                else
                    MENU_COALITION_COMMAND:New(dcafCoalition, "DEACTIVATE", menuTrack, deactivateTrack)
                end
            end
            
            -- active tankers 
            for _, tankerInfo in ipairs(track.Tankers) do
                local tanker = tankerInfo.Tanker

                local function sendTankerHome(airbaseName, route)
                    local airbase = AIRBASE:FindByName(airbaseName)
                    track:RemoveTanker(tankerInfo)
                    tanker:RTB(airbase, nil, route)
                    tankerInfo.GroupRTB = tankerInfo.Group
                    tankerInfo:Deactivate()
                    rebuildTankerMenus(caption, scope)
                end        

                local airdromes
                if tanker.Behavior and tanker.Behavior.RTBAirbase then
                    airdromes = { tanker.Behavior.RTBAirbase }
                else
                    airdromes = tankerInfo.Airbases
                end
                local rtbMenu
                if #airdromes > 1 then
                    if group then
                        rtbMenu = MENU_GROUP:New(group, "RTB " .. tanker.DisplayName, menuTrack)
                    else
                        rtbMenu = MENU_COALITION:New(dcafCoalition, "RTB " .. tanker.DisplayName, menuTrack)
                    end
                end
                for _, airServiceBase in ipairs(airdromes) do
                    local airbaseName = airServiceBase.Airbase.AirbaseName
                    local menuText = ">> RTB " .. tanker.DisplayName .. " >> " .. airbaseName
                    if airServiceBase.RTBRoutes and #airServiceBase.RTBRoutes > 0 then
                        local rtbMenu = DCAF.MENU:New(rtbMenu or menuTrack)
                        for _, rtbRoute in ipairs(airServiceBase.RTBRoutes) do
                             if group then
                                rtbMenu:GroupCommand(group, menuText .. " (" .. rtbRoute.Name .. ")", sendTankerHome, airbaseName, rtbRoute)
                             else
                                rtbMenu:CoalitionCommand(dcafCoalition, menuText .. " (" .. rtbRoute.Name .. ")", sendTankerHome, airbaseName, rtbRoute)
                             end
                        end
                    else
                        if group then
                            MENU_GROUP_COMMAND:New(group, menuText, rtbMenu or menuTrack, sendTankerHome, airbaseName)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, menuText, rtbMenu or menuTrack, sendTankerHome, airbaseName)
                        end
                    end
                end
            end

            -- available tankers..
            if not track:IsFull() then
                local activeTankers = {}
                for _, tankerInfo in ipairs(AAR_TANKERS) do
                    if not tankerInfo:IsActive() then
                        local function activateAir()
                            track:ActivateAir(tankerInfo)
                            rebuildTankerMenus(caption, scope)
                        end
                        local function activateGround(airbase, route)
                            track:ActivateAirbase(tankerInfo, route or airbase)
                            rebuildTankerMenus(caption, scope)
                        end
                        local menuTanker
                        if group then
                            menuTanker = MENU_GROUP:New(group, tankerInfo:ToString(), menuTrack)
                        else
                            menuTanker = MENU_COALITION:New(dcafCoalition, tankerInfo:ToString(), menuTrack)
                        end
                        -- if group then
                        --     MENU_GROUP_COMMAND:New(group, "Activate AIR", menuTanker, activateAir)
                        --     MENU_GROUP_COMMAND:New(group, "Activate GND", menuTanker, activateGround)
                        --     -- todo Support multiple airbases/routes for group senctric menu
                        -- else
                        if group then
                            MENU_GROUP_COMMAND:New(group, "Activate AIR", menuTanker, activateAir)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, "Activate AIR", menuTanker, activateAir)
                        end
                        -- MENU_COALITION_COMMAND:New(dcafCoalition, "Activate AIR", menuTanker, activateAir)
                        if isList(tankerInfo.Airbases) then
                            local mnuAirbases = DCAF.MENU:New(menuTanker)
                            for _, airServiceBase in ipairs(tankerInfo.Airbases) do  -- #DCAF_AirServiceBase
                                local airbaseName = airServiceBase.Airbase.AirbaseName
                                if isList(airServiceBase.Routes) then
                                    for _, route in ipairs(airServiceBase.Routes) do -- #DCAF.AIR_ROUTE
                                        local mnuText = "Activate from " .. airbaseName .. " (" .. route.Name  .. ")"
                                        if group then
                                            mnuAirbases:GroupCommand(group, mnuText,  activateGround, route)
                                        else
                                            mnuAirbases:CoalitionCommand(dcafCoalition, mnuText,  activateGround, route)
                                        end
                                    end
                                else
                                    if group then
                                        mnuAirbases:GroupCommand(group, "Activate from " .. airbaseName, activateGround, airServiceBase.Airbase)
                                    else
                                        mnuAirbases:CoalitionCommand(dcafCoalition, "Activate from " .. airbaseName, activateGround, airServiceBase.Airbase)
                                    end
                                end
                            end
                            -- end
                        end
                    elseif tankerInfo.Track.Name ~= track.Name then
                        table.insert(activeTankers, tankerInfo)
                    end
                end
                if #activeTankers > 0 then
                    local function reassignTanker(tanker)
                        track:Reassign(tanker)
                        rebuildTankerMenus(caption, scope)
                    end
                    for _, tanker in ipairs(activeTankers) do
                        if group then
                            MENU_GROUP_COMMAND:New(group, "REASSIGN " .. tanker:ToString() .. " @ " .. tanker.Track.Name, menuTrack, reassignTanker, tanker)
                        else
                            MENU_COALITION_COMMAND:New(dcafCoalition, "REASSIGN " .. tanker:ToString() .. " @ " .. tanker.Track.Name, menuTrack, reassignTanker, tanker)
                        end
                    end
                end
            end
        end
    end
end
rebuildTankerMenus = buildTankerMenus

function DCAF.TankerTracks:BuildMenus(caption, scope)
    buildTankerMenus(caption, scope)
    return self
end

function DCAF.TankerTracks:AllowDynamicTracks(value)
    if  not isBoolean(value) then
        value = true
    end
    if value == isDynamicTankerTracksSupported then
        return end

    isDynamicTankerTracksSupported = value

    local function listenForDynamicTrackMarks(event)
-- Debug("nisse - listenForDynamicTrackMarks :: event: " .. DumpPretty(event))
        -- format: AAR <name> <heading> <length> <capacity> 
        if string.len(event.Text) < 3 then
            return end

        local tokens = {}
        for word in event.Text:gmatch("%w+") do
            table.insert(tokens, word)
        end
        local ident = tokens[1]

        -- requires as a minimum the ident 'AAR' and a name for the new track...
        if #tokens < 2 or string.upper(tokens[1]) ~= "AAR" then
            return end

        local default = DCAF.TankerTracks[#DCAF.TankerTracks]
        local name = tokens[2]

        local function resolveNumeric(name, sValue, fallback)
            local value
-- Debug("nisse - resolveNumeric :: name: " .. name .. " :: sValue: " .. sValue .. " :: fallback: " .. Dump(fallback))
            if isAssignedString(sValue) then
                value = tonumber(sValue)
            elseif default then
                value = default[name]
            end
            return value or fallback
        end

-- Debug("nisse - listenForDynamicTrackMarks :: tokens: " .. DumpPretty(tokens))

        local sHeading = tokens[3]
        local heading = resolveNumeric("Heading", tokens[3], 360)
        local length = resolveNumeric("Length", tokens[4])
        local capacity = resolveNumeric("Capacity", tokens[5], 2)

        DCAF.TankerTrack:New(name, event.Coalition, heading, event.Location.Source, length):Draw()
        rebuildTankerMenus()
    end

    if value then
        MissionEvents:OnMapMarkChanged(listenForDynamicTrackMarks)
    else
        MissionEvents:EndOnMapMarkChanged(listenForDynamicTrackMarks)
    end
    
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                             MENU BUILDING - HELPERS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.MENU = {}

function DCAF.MENU:New(parentMenu, maxCount, count, nestedMenuCaption)
    local menu = DCAF.clone(DCAF.MENU)
    if not isNumber(maxCount) then
        maxCount = 9
    end
    if not isNumber(count) then
        count = 0
    end
    menu._maxCount = maxCount
    menu._count = count
    menu._parentMenu = parentMenu
    menu._nestedMenuCaption = "(more)"
    return menu
end

function DCAF.MENU:Blue(text)
    return self:Coalition(coalition.side.BLUE, text)
end

function DCAF.MENU:BlueCommand(text, func, ...)
    return self:CoalitionCommand(coalition.side.BLUE, text, func, ...)
end

function DCAF.MENU:CoalitionCommand(dcsCoalition, text, func, ...)
    local dcafCoalition = Coalition.Resolve(dcsCoalition)
    if dcafCoalition then
       dcsCoalition = Coalition.ToNumber(dcafCoalition)
    elseif not isNumber(dcsCoalition) then
        error("DCAf.Menu:CoalitionCommand :: `coalition` must be #Coalition or #number (eg. coalition.side.RED), but was: " .. type(dcsCoalition))
    end

    if not isAssignedString(text) then
        error("DCAF.MENU:CoalitionCommand :: `text` must be assigned string") end

    if not isFunction(func) then
        error("DCAF.MENU:CoalitionCommand :: `func` must be a function but was: " .. type(func)) end

    if self._count == self._maxCount then
        self._parentMenu = MENU_COALITION:New(dcsCoalition, self._nestedMenuCaption, self._parentMenu)
        self._count = 1
    else
        self._count = self._count + 1
    end
    return MENU_COALITION_COMMAND:New(dcsCoalition, text, self._parentMenu, func, ...)
end

function DCAF.MENU:Coalition(coalition, text)
    local dcafCoalition = Coalition.Resolve(coalition)
    if dcafCoalition then
       coalition = Coalition.ToNumber(dcafCoalition)
    elseif not isNumber(coalition) then
        error("DCAf.Menu:Coalition :: `coalition` must be #Coalition or #number (eg. coalition.side.RED), but was: " .. type(coalition))
    end

    if not isAssignedString(text) then
        error("DCAF.MENU:Blue :: `text` must be assigned string") end

    if self._count == self._maxCount then
        self._parentMenu = MENU_COALITION:New(coalition, self._nestedMenuCaption, self._parentMenu)
        self._count = 1
    else
        self._count = self._count + 1
    end
    return MENU_COALITION:New(coalition, text, self._parentMenu)
end

function DCAF.MENU:Group(group, text)
    local testGroup = getGroup(group)
    if not testGroup then
        error("DCAF.MENU:Group :: cannot resolve group from: " .. DumpPretty(group)) end

    if not isAssignedString(text) then
        error("DCAF.MENU:Group :: `text` must be assigned string") end

    group = testGroup
    if self._count == self._maxCount then
        self._parentMenu = MENU_GROUP:New(group, self._nestedMenuCaption, self._parentMenu)
        self._count = 1
    else
        self._count = self._count + 1
    end
    return MENU_GROUP:New(group, text, self._parentMenu)
end

function DCAF.MENU:GroupCommand(group, text, func, ...)
    local testGroup = getGroup(group)
    if not testGroup then
        error("DCAF.MENU:GroupCommand :: cannot resolve group from: " .. DumpPretty(group)) end

    if not isAssignedString(text) then
        error("DCAF.MENU:GroupCommand :: `text` must be assigned string") end

    if not isFunction(func) then
        error("DCAF.MENU:GroupCommand :: `func` must be a function but was: " .. type(func)) end

    group = testGroup
    if self._count == self._maxCount then
        self._parentMenu = MENU_GROUP:New(group, self._nestedMenuCaption, self._parentMenu)
        self._count = 1
    else
        self._count = self._count + 1
    end
    return MENU_GROUP_COMMAND:New(group, text, self._parentMenu, func, ...)
end


-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                             EXPERIMENT - WEAPONS SIMULATION
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

local __wpnSim_count = 0
local __wpnSim_minSafetyDistance = 300
local __wpnSim_simulations = { -- list
  -- #DCAF.WeaponSimulation
}

DCAF.WeaponSimulationConfig = {
  ClassName = "DCAF.WeaponSimulationConfig",
  IniCoalitions = { Coalition.Red },
  IniTypes = { GroupType.Air, GroupType.Ground, GroupType.Ship },
  TgtTypes = { GroupType.Air, GroupType.Ground, GroupType.Ship },
  ExcludeAiTargets = true,
  ExcludePlayerTargets = false,
  SafetyDistance = 300, -- (meters) missiles deactivates at this distance to target
  AudioSimulatedHitSelf = "SimulatedWpnHitSelf.ogg",
  AudioSimulatedHitTarget = "SimulatedWpnHitTarget.ogg",
  AudioSimulatedHitFratricide = "SimulatedWpnHitFratricide.ogg",
  AudioSimulatedMiss = "SimulatedWeaponMiss.ogg",
}

DCAF.WeaponSimulation = {
    ClassName = "DCAF.WeaponSimulation",
    Name = "WPN_SIM",
    Config = nil, -- #DCAF.MissileSimulationConfig
    __scheduler = nil,
    __managers = {

    }
}

function DCAF.WeaponSimulationConfig:New(iniCoalitions, iniTypes, tgtTypes, safetyDistance, bExcludeAiTargets, bExcludePlayerTargets)
    if isAssignedString(iniCoalitions) and Coalition.Resolve(iniCoalitions) then
        iniCoalitions = { iniCoalitions }
    elseif not isTable(iniCoalitions) then
        iniCoalitions = DCAF.WeaponSimulationConfig.IniCoalitions
    end
    if isAssignedString(iniTypes) and GroupType.IsValid(iniTypes) then
        iniTypes = { iniTypes }
    elseif not isTable(iniTypes) then
        iniTypes = DCAF.WeaponSimulationConfig.IniTypes
    end
    if isAssignedString(tgtTypes) and GroupType.IsValid(tgtTypes) then
        tgtTypes = { tgtTypes }
    elseif not isTable(tgtTypes) then
        tgtTypes = DCAF.WeaponSimulationConfig.TgtTypes
    end
    if not isNumber(safetyDistance) then
        safetyDistance = DCAF.WeaponSimulationConfig.SafetyDistance
    else
        safetyDistance = math.max(__wpnSim_minSafetyDistance, safetyDistance)
    end
    if not isBoolean(bExcludeAiTargets) then
        bExcludeAiTargets = DCAF.WeaponSimulationConfig.ExcludeAiTargets
    end
    if not isBoolean(bExcludePlayerTargets) then
        bExcludePlayerTargets = DCAF.WeaponSimulationConfig.ExcludePlayerTargets
    end
    local cfg = DCAF.clone(DCAF.WeaponSimulationConfig)
    cfg.IniCoalitions = iniCoalitions
    cfg.IniTypes = iniTypes
    cfg.TgtTypes = tgtTypes
    cfg.ExcludeAiTargets = bExcludeAiTargets
    cfg.ExcludePlayerTargets = bExcludePlayerTargets
    cfg.SafetyDistance = safetyDistance
    return cfg
end

function DCAF.WeaponSimulationConfig:WithAudioSimulatedHitTarget(filename)
    if not isAssignedString(filename) then
        error("DCAF.WeaponSimulation:WithAudioSimulatedHitTarget :: `filename` must be assigned string") end
    
    self.AudioSimulatedHitTarget = filename
    return self
end

function DCAF.WeaponSimulationConfig:WithAudioSimulatedHitFratricide(filename)
    if not isAssignedString(filename) then
        error("DCAF.WeaponSimulation:WithAudioSimulatedHitFratricide :: `filename` must be assigned string") end
    
    self.AudioSimulatedHitFratricide = filename
    return self
end

function DCAF.WeaponSimulationConfig:WithAudioSimulatedHitSelf(filename)
    if not isAssignedString(filename) then
        error("DCAF.WeaponSimulation:WithAudioSimulatedHitSelf :: `filename` must be assigned string") end
    
    self.AudioSimulatedHitSelf = filename
    return self
end

function DCAF.WeaponSimulationConfig:WithAudioSimulatedMiss(filename)
    if not isAssignedString(filename) then
        error("DCAF.WeaponSimulation:WithAudioSimulatedMiss :: `filename` must be assigned string") end
    
    self.AudioSimulatedMiss = filename
    return self
end

function DCAF.WeaponSimulation:New(name, config)
   __wpnSim_count = __wpnSim_count+1
   if not isAssignedString(name) then
      name = DCAF.WeaponSimulation.Name .. "-" .. Dump(__wpnSim_count)
   end
   if config ~= nil then
      if not isClass(config, DCAF.WeaponSimulationConfig.ClassName) then
        error("DCAF.WeaponSimulation:New :: `config` must be of type " .. DCAF.WeaponSimulationConfig.ClassName)
        return
      end
   else 
      config = DCAF.WeaponSimulationConfig:New()
   end
   local sim = DCAF.clone(DCAF.WeaponSimulation)
   sim.Name = name
   sim.Config = config
   return sim
end

function DCAF.WeaponSimulation:Manage(func) -- #function(weapon, iniUnit, tgtUnit, config)
    if not isFunction(func) then
        error("DCAF.WeaponSimulation:Manage :: `func` must be function, but was " .. type(func)) end

    table.insert(self.__managers, func)
    return self
end

function DCAF.WeaponSimulation:IsManaged(weapon, iniUnit, tgtUnit, config)
    -- the rule here is that if there are managers added, one of them needs to return true for the weapon to be managed (simulated)
    -- if no managers are registered; the weapon is automatically managed (simulated)
    if #self.__managers == 0 then
        return true end

    for _, manager in ipairs(self.__managers) do
        local result, msg = manager(weapon, iniUnit, tgtUnit, config)
        if isBoolean(result) and result then
            return result, msg end
    end
    return false, "No manager found for weapon"
end

function DCAF.WeaponSimulation:_IsSimulated(weapon, iniUnit, tgtUnit, config)

   -- note: 'weapon' is currently not included in filtering; just passed for future proofing
--    local iniCoalition = iniUnit:GetCoalition()
--    if not Coalition.IsAny(iniCoalition, config.IniCoalitions) then
--       return false, "Initiator is excluded coaltion: '" .. iniUnit:GetCoalitionName() end

   if config.ExcludeAiTargets and not tgtUnit:IsPlayer() then
      return false, "AI targets are excluded" end

   if config.ExcludePlayerTargets and tgtUnit:IsPlayer() then
      return false, "Player targets are excluded" end
  
   if iniUnit:IsGround() and not GroupType.IsAny(GroupType.Ground, config.IniTypes) then 
      return false, "Initiator type is excluded: 'Ground'" end
  
   if iniUnit:IsAir() and not GroupType.IsAny(GroupType.Air, config.IniTypes) then 
      return false, "Initiator type is excluded: 'Air'" end
    
   if iniUnit:IsShip() and not GroupType.IsAny(GroupType.Ship, config.IniTypes) then 
      return false, "Initiator type is excluded: 'Ship'" end

   if tgtUnit:IsGround() and not GroupType.IsAny(GroupType.Ground, config.TgtTypes) then 
      return false, "Target type is excluded: 'Ground'" end
  
   if tgtUnit:IsAir() and not GroupType.IsAny(GroupType.Air, config.TgtTypes) then 
      return false, "Target type is excluded: 'Air'" end
    
   if tgtUnit:IsShip() and not GroupType.IsAny(GroupType.Ship, config.TgtTypes) then 
      return false, "Target type is excluded: 'Ship'" end
      
   return true, ""
end

function DCAF.WeaponSimulation:IsSimulated(weapon, iniUnit, tgtUnit, config)
   return self:_IsSimulated(weapon, iniUnit, tgtUnit, config)
end

-- GROUP.OnHitBySimulatedWeapon = function(group, unitHit, unitInitiating, weapon)
--     -- to be overridden
-- end

-- function GROUP:OnHitBySimulatedWeapon(unitHit, unitInitiating, weapon)
--     -- to be overridden
-- end

function DCAF.WeaponSimulation:_OnWeaponMisses(wpnType, iniUnit, tgtUnit)
    if isFunction(self.OnWeaponMisses) then
        local isMiss = self:OnWeaponMisses(wpnType, iniUnit, tgtUnit)
        if not isMiss then
            return end
    end

    local tgtGroup = tgtUnit:GetGroup()
    local tgtActor
    if tgtUnit:IsPlayer() then
        tgtActor = string.format("%s (%s)", tgtUnit:GetPlayerName(), tgtUnit.UnitName)
    else
        tgtActor = tgtUnit.UnitName
    end
    local iniGroup = iniUnit:GetGroup()
    local msg = string.format("%s defeated %s by %s (%s)", tgtActor, wpnType, iniGroup.GroupName, iniGroup:GetTypeName())

    MessageTo(tgtUnit, msg)
    MessageTo(tgtUnit, self.Config.AudioSimulatedMiss)
end

function DCAF.WeaponSimulation:_OnWeaponHits(wpn, iniUnit, tgtUnit)
    if isFunction(self.OnWeaponHits) then
        local isHit = self:OnWeaponHits(wpn, iniUnit, tgtUnit)
        if isBoolean(isHit) and not isHit then
            return end
    end

    local tgtGroup = tgtUnit:GetGroup()
    if isFunction(tgtGroup.OnHitBySimulatedWeapon) then
        local success, err = pcall(tgtGroup.OnHitBySimulatedWeapon(tgtGroup, tgtUnit, iniUnit, wpn))
        if not success then
            Warning("DCAF.WeaponSimulation:_OnWeaponHits :: error when invoking targeted group's `OnSimulatedHit` function: " .. DumpPretty(err))
        end
    end

    local tgtActor
    if tgtUnit:IsPlayer() then
        tgtActor = string.format("%s (%s)", tgtUnit:GetPlayerName(), tgtUnit.UnitName)
    else
        tgtActor = tgtUnit.UnitName
    end
    local iniGroup = iniUnit:GetGroup()
    local iniCoalition = iniGroup:GetCoalitionName()
    local tgtCoalition = tgtGroup:GetCoalitionName()
    local msg = string.format("%s was hit by %s (%s)", tgtActor, iniGroup.GroupName, iniGroup:GetTypeName())
    if tgtCoalition == iniCoalition then
        -- todo What sound for fratricide?
        msg = "FRATRICIDE! :: " .. msg
        MessageTo(iniCoalition, self.Config.AudioSimulatedHitFratricide)
    else
        -- different sounds for each coalition
        MessageTo(iniCoalition, self.Config.AudioSimulatedHitTarget)
        MessageTo(tgtCoalition, self.Config.AudioSimulatedHitSelf)
    end
    MessageTo(nil, msg)
end

function DCAF.WeaponSimulation:OnWeaponMisses(wpnType, iniUnit, tgtUnit)
    return true
end

function DCAF.WeaponSimulation:OnWeaponHits(wpn, iniUnit, tgtUnit)
    return true
end

function DCAF.WeaponSimulation:Start(safetyDistance)
    local scheduler = SCHEDULER:New()
    self.__scheduler = scheduler
    self.__countTrackedWeapons = 0
    if not isNumber(safetyDistance) then
        safetyDistance = self.Config.SafetyDistance
    else
        safetyDistance = math.max(__wpnSim_minSafetyDistance, safetyDistance)
    end

-- Debug("DCAF.WeaponSimulation(" .. self.Name .. "):Start :: config: " .. DumpPretty({
--   iniCoalitions = Dump(self.Config.IniCoalitions),
--   iniTypes = Dump(self.Config.IniTypes),
--   tgtTypes = Dump(self.Config.TgtTypes),
--   isAiTargetsExcluded = Dump(self.Config.ExcludeAiTargets),
--   isPlayerTargetsExcluded = Dump(self.Config.ExcludePlayerTargets),
--   safetyDistance = Dump(safetyDistance)
-- }))

    self.__monitorFunc = function(event)
-- Debug("DCAF.WeaponSimulation:Start :: event: " .. DumpPrettyDeep(event, 2))
        local wpn = event.weapon
        local wpnType = wpn:getTypeName()
        local tgt = wpn:getTarget()
        local iniUnit = event.IniUnit
        local tgtUnit = event.TgtUnit

        local isManaged, msg = self:IsManaged(wpn, iniUnit, tgtUnit, self.Config)
        if not isManaged then
            Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: is NOT managing '" .. wpnType .."' fired by '" .. iniUnit.UnitName .. "' at " .. tgtUnit.UnitName .. " (" .. msg .. ")")
            return
        end

        local isSimulated, msg = self:IsSimulated(wpn, iniUnit, tgtUnit, self.Config)
        if not isSimulated then
            Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: will NOT deactive '" .. wpnType .."' fired by '" .. iniUnit.UnitName .. "' at " .. tgtUnit.UnitName .. " (" .. msg .. ")")
            return
        end

        -- local scheduler = SCHEDULER:New(self)
        --   local wpnSimulation = self

        local function getDistance3D(pos1, pos2)
            local xDiff = pos1.x - pos2.x
            local yDiff = pos1.y - pos2.y
            local zDiff = pos1.z - pos2.z
            return math.sqrt(xDiff * xDiff + yDiff * yDiff + zDiff*zDiff)
        end

        local scheduleId
        local function trackWeapon()
            local mslAlive, mslPos = pcall(function() return wpn:getPoint() end)
            if not mslAlive then
                -- weapon missed/was defeated...
                Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: weapon no longer alive :: IGNORES")
                scheduler:Stop(scheduleId)
                scheduler:Remove(scheduleId)
                self.__countTrackedWeapons = self.__countTrackedWeapons - 1
                self:_OnWeaponMisses(wpnType, iniUnit, tgtUnit)
                return 
            end

            local tgtAlive, tgtPos = pcall(function() return tgt:getPoint() end)
            if not tgtAlive then
                -- target is (no longer) alive...
                Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: target no longer alive :: IGNORES")
                scheduler:Stop(scheduleId)
                scheduler:Remove(scheduleId)
                self.__countTrackedWeapons = self.__countTrackedWeapons - 1
                return 
            end

            local distance = getDistance3D(mslPos, tgtPos)
            if distance <= safetyDistance then
                -- weapon hit ...
                wpn:destroy()
                Debug("DCAF.WeaponSimulation(" .. self.Name .. ") :: weapon would have hit " .. tgtUnit.UnitName .. " (fired by " .. iniUnit.UnitName .. ") :: WPN TRACKING END")
                scheduler:Stop(scheduleId)
                scheduler:Remove(scheduleId)
                self.__countTrackedWeapons = self.__countTrackedWeapons - 1
                self:_OnWeaponHits(wpn, iniUnit, tgtUnit)
            end
        end

        scheduleId = scheduler:Schedule(self, trackWeapon, { }, 1, .05)
        scheduler:Start(scheduleId)
        self.__countTrackedWeapons = self.__countTrackedWeapons+1
    end

    MissionEvents:OnWeaponFired(self.__monitorFunc)
    table.insert( __wpnSim_simulations, self )
    -- scheduler:Start()
    if isFunction(self.OnStarted) then
        self:OnStarted()
    end
    return self
end

function DCAF.WeaponSimulation:Stop()
    if not self.__scheduler then
        return end

    MissionEvents:EndOnWeaponFired(self.__monitorFunc)
    if self.__countTrackedWeapons > 0 then
        self.__scheduler:Clear()
    end
    self.__monitorFunc = nil
    self.__scheduler = nil
    local idx = tableIndexOf(__wpnSim_simulations, self)
    if idx then
        table.remove(__wpnSim_simulations, idx)
    end
    if isFunction(self.OnStopped) then
        self:OnStopped()
    end
end

function DCAF.WeaponSimulation:IsActive()
    return self.__scheduler ~= nil
end

function DCAF.WeaponSimulation:OnStarted()
end

function DCAF.WeaponSimulation:OnStopped()
end

-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                                           CODEWORDS
-- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.Codewords = {
    FlashGordon = { "Flash Gordon", "Prince Barin", "Ming", "Princess Aura", "Zarkov", "Klytus", "Vultan" },
    JamesBond = { "Moneypenny", "Jaws", "Swann", "Gogol", "Tanner", "Blofeld", "Leiter" },
    RockHeroes = { "Idol", "Dio", "Vaughan", "Lynott", "Lemmy", "Mercury", "Fogerty" },
    Disney = { "Goofy", "Donald Duck", "Mickey", "Snow White", "Peter Pan", "Cinderella", "Baloo" },
    Princesses = { "Cinderella", "Pocahontas", "Ariel", "Anastasia", "Leia", "Astrid", "Fiona" },
    Poets = { "Eliot", "Blake", "Poe", "Keats", "Shakespeare", "Yeats", "Byron", "Wilde" },
    Painters = { "da Vinci", "van Gogh", "Rembrandt", "Monet", "Matisse", "Picasso", "Boticelli" },
    Marvel = { "Wolverine", "Iron Man", "Thor", "Captain America", "Spider Man", "Black Widow", "Star-Lord" },
}

DCAF.CodewordType = {
    Person = {
        DCAF.Codewords.FlashGordon,
        DCAF.Codewords.JamesBond,
        DCAF.Codewords.FlashGordon,
        DCAF.Codewords.JamesBond,
        DCAF.Codewords.RockHeroes,
        DCAF.Codewords.Disney,
        DCAF.Codewords.Princesses,
        DCAF.Codewords.Poets,
        DCAF.Codewords.Painters,
        DCAF.Codewords.Marvel
    }
}

DCAF.CodewordTheme = {
    ClassName = "DCAF.CodewordTheme",
    Name = nil,
    Codewords = {}
}

function DCAF.Codewords:RandomTheme(type, singleUse)
    local themes
    if isAssignedString(type) then
        themes = DCAF.CodewordType[type]
        if not themes then
            error("DCAF.Codewords:RandomTheme :: `type` is not supported: " .. type) end
    else
        themes = DCAF.Codewords
    end

    local key = dictRandomKey(themes)
Debug("nisse - DCAF.Codewords:RandomTheme :: key: " .. Dump(key, DumpPrettyOptions:New():IncludeFunctions()))
    local codewords = themes[key]
    local theme = DCAF.CodewordTheme:New(key, codewords, singleUse)
    if isBoolean(singleUse) and singleUse == true then
        DCAF.Codewords[key] = nil
    end
    return theme
end

function DCAF.CodewordTheme:New(name, codewords, singleUse)
    local theme = DCAF.clone(DCAF.CodewordTheme)
    theme.Name = name
    if isBoolean(singleUse) then
        theme.SingleUse = singleUse
    else
        theme.SingleUse = true
    end
    listCopy(codewords, theme.Codewords)
    return theme
end

function DCAF.CodewordTheme:GetNextRandom()
    local codeword, index = listRandomItem(self.Codewords)
    if self.SingleUse then
        table.remove(self.Codewords, index)
    end
    return codeword
end


-------------- LOADED

Trace("DCAF.Core was loaded")