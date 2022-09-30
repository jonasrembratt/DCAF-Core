local _isDebuggingWithAiInterceptor = false -- nisse
local _aiInterceptedBehavior = {}

AirPolicing = {
    -- Obey/disobey patterns are mutually exclusive; if one is set the other should be set to nil
    -- (using the AirPolicing:WithObeyPattern and AirPolicing:WithDisobeyPattern functions will ensure this behavior)
    -- If both obey and disobey patterns are set, only the ObeyPattern is honored (meaning all groups not matching the ObeyPattern) will
    -- disobey the interceptor
    DefaultInterceptedBehavior = nil,
    Assistance = {
        IsAllowed = true,
        DescriptionDelay = 7, -- delay from entering intruder zone to intruder description is presented (if available); see AirPolicingOptions:WithGroupDescriptions
        Duration = 12, -- the duration (seconds) for all assistance messages

        ApproachInstruction = 
          "Approach carefully and non-aggressively, especially with civilian aircraft",
        ApproachInstructionAudio = "ApproachInstruction.ogg",

        GroupsSpottedInstruction = "%s flights spotted nearby. Use menu to intercept",
        GroupsSpottedInstructionAudio = "GroupsSpottedInstruction.ogg",

        EstablishInstructionSingleton = 
          "Lead takes up position to the left side of the aircraft's cockpit to establish visual contact with the aircrew\n"..
          "Wing takes up a surveillance position further behind to keep watch and protect lead",
        EstablishInstructionSingletonAudio = "EstablishInstructionSingleton.ogg",
        EstablishInstructionSingletonAudioTime = 9,

        EstablishInstructionEscorted = 
          "Lead takes up position to the left side of the aircraft's cockpit to establish visual contact with the aircrew\n"..
          "Wing takes up a surveillance position behind the escort, to keep watch and be ready to engage if needed",
        EstablishInstructionEscortedAudio = "EstablishInstructionEscorted.ogg",
        EstablishInstructionEscortedAudioTime = 11,

        SignalInstruction = 
          "Lead rocks wings to order 'follow me' or 'deviate now!'",
        SignalInstructionAudio = "SignalInstruction.ogg",
        SignalInstructionAudioTime = 2,
         
        CancelledInstruction = 
          "Intercept procedure was cancelled. Please use menu for further airspace policing",
        CancelledInstructionAudio = "CancelledInstruction.ogg",
        CancelledInstructionAudioTime = 4,

        -- AI reaction assist ...
        AiComplyingInstruction = 
          "You now lead the flight! Please divert it to a location or airport "..
          "and order it to land, or continue its route from that location (see menus)",
        AiComplyingInstructionAudio = "AiComplyingInstruction.ogg",
        AiComplyingInstructionAudioTime = 7,

        AiDisobeyingInstruction = 
          "The flight is not complying",
        AiDisobeyingInstructionAudio = "AiDisobeyingInstruction.ogg",
        AiDisobeyingInstructionAudioTime = 1,

        AiDisobeyDivertingInstruction = 
          "The flight is not complying, but seems to be diverting",
        AiDisobeyDivertingInstructionAudio = "AiDisobeyDivertingInstruction.ogg",
        AiDisobeyDivertingInstructionAudioTime = 3,

        AiAttackingInstruction = 
          "The flight doesn't seem to comply and is behaving aggressively. Be cautious and ready for a fight!",
        AiAttackingInstructionAudio = "AiAttackingInstruction.ogg",
        AiAttackingInstructionAudioTime = 1,
 
        AiLandingInstruction =
          "The flight leaves your formation to land at %s. Good job!",
        AiLandingInstructionAudio = "AiLandingInstruction.ogg",
        AiLandingInstructionAudioTime = 2,

        AiDivertingInstruction =
          "The flight now resumes its route from this location. Good job!",
        AiDivertingInstructionAudio = "AiDivertingInstruction.ogg",
        AiDivertingInstructionAudioTime = 3,

        AiEscortAttacks =
            "Be advised! The escort moves into an offensive position!",
        AiEscortAttacksAudio = "AiEscortAttacks.ogg",
        AiEscortAttacksAudioTime = 3,
    },
    LandingIntruders = {},
    _aiGroupDescriptions = {},
    Trace = false,
    Debug = false
}

local InterceptionDefault = {
    interceptReactionQualifier = 'icpt',
    interceptReactionFallbackQualifier = '>',
    escortIdentifier = 'escort',
}

INTERCEPT_REACTIONS = {
    None =   "none",     -- icpt=none (disobeys orders and just continues)
    Attack1 = "atk1",    -- icpt=atk1 (changes to aggressive behavior if intruder group have superiority [in size])
    Attack2 = "atk2",    -- icpt=atk2 (changes to aggressive behavior if intruder is larger or equal in size to interceptor group)
    Attack3 = "atk3",    -- icpt=atk3 (changes to aggressive behavior unconditionally)
    Defensive1 = "def1", -- icpt=def1 (changes to defensive behavior)
    Divert = "divt",     -- icpt=divt (if flight has divert waypoint) in route it goes DIRECT; otherwise RTB (back to 1st wp)
    Stop =   "stop",     -- icpt=stop (intercepted aircraft lands at nearest friendly airbase; "show-of-forced" surface/ground units shuts down)
    Follow = "folw",     -- icpt=folw (follows interceptor)
}

INTERCEPT_PHASES = {
    Closing = "c",
    Establishing = "e",
    Intercepted = "i"
}

function INTERCEPT_PHASES:IsValid( s )
    if (not isString(s)) then
        return false
    end

    local phase = string.lower(s)
    for k, ident in pairs(INTERCEPT_PHASES) do
        if (phase == ident) then 
            return true 
        end
    end
    return false
end

INTERCEPT_REACTION = {
    Name = nil,
    Randomization = nil,    -- a number (0-100)
    Phase = nil,            -- see INTERCEPT_PHASES
    ClassName = "INTERCEPT_REACTION"
}

function INTERCEPT_REACTION:New(name, randomization, phase)
    if (not isString(name)) then error("intercept reaction name was not specified") end
    local ir = routines.utils.deepCopy(INTERCEPT_REACTION)
    ir.Name = name
    ir.Randomization = randomization
    ir.Phase = phase or INTERCEPT_PHASES.Intercepted
    return ir
end

function INTERCEPT_REACTION:IsValid( reaction )
    if (not isClass(reaction, INTERCEPT_REACTION.ClassName)) then 
        return false
    end

    reaction = string.lower(reaction.Name)
    for k, v in pairs(INTERCEPT_REACTIONS) do
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

function AirPolicing:GetGroupDescription( group )
    group = getGroup(group)
    if (group == nil) then
        Warning("AirPolicing:GetGroupDescription :: cannot resolve group from "..Dump(group).." :: EXITS")
        return
    end

    local description = self._aiGroupDescriptions[group.GroupName]
    if (description) then 
        return description
    end

    for k, d in ipairs(self._aiGroupDescriptions) do
        if (string.match(group.GroupName, k)) then
            return d
        end
    end

    return nil
end

_ActiveIntercept = {
    intruder = nil,
    escort = nil,
    interceptor = nil,
    cancelFunction = nil
}

function _ActiveIntercept:New( intruder, interceptor, escort )
    local ai = routines.utils.deepCopy(_ActiveIntercept)
    ai.intruder = intruder
    ai.escort = escort
    ai.interceptor = interceptor
    return ai
end

function _ActiveIntercept:Cancel()
    local ai = self
    if (ai.cancelFunction ~= nil) then
        ai.cancelFunction()
    end
end

function CanBeIntercepted( controllable )
    local group = getGroup(controllable)
    if (group == nil) then
        Trace("CanBeIntercepted-?  :: group cannot be resolve :: EXITS")
        return false
    end
    local leadUnit = group:GetUnit(1)
    if (leadUnit:IsPlayer()) then  -- TOTEST -- this needs tp be testen on MP server
        Trace("CanBeIntercepted  :: Lead unit " .. leadUnit:GetName() .. " is player (cannot be intercepted)")
        return false 
    end 
    if AirPolicing:IsLanding(group) then return false end
    return true
end

--------------------------------------------- [[ INTRUDER BEHAVIOR ]] ---------------------------------------------

local function tryGetRegisteredInterceptedBehavior( s )
    for pattern, behavior in pairs(_aiInterceptedBehavior) do
        if (s == pattern or string.match( s, pattern )) then
            return behavior
        end
    end
    return nil
end

local function parseReaction( s, next ) -- next = start index in 's'

    next = next or 1
    local sLength = string.len( s )
    local tokenLen = string.len(INTERCEPT_REACTIONS.None) -- all reaction identifiers are same length

    next = findFirstNonWhitespace(s, next)
    local reactionName = string.lower( string.sub(s, next, next+tokenLen-1) )
    local nRandom = nil
    local phase = nil
    next = next+tokenLen
    if (next+3 >= sLength) then
        return reactionName, nRandom, phase, next 
    end

    -- look for randomization ('%nn') ...
    local op = string.sub(s, next, next)
    if (op == '%') then
        local sRandom = string.sub(s, next+1, next+3)
        nRandom = tonumber(sRandom)
        next = next+3
    end

     -- atk2%20-c > atk2%50-e > atk2%90-i > divt
    if (next+2 >= sLength) then
        return reactionName, nRandom, phase, next
    end

    -- look for phase information 
    op = string.sub(s, next, next)
    if (op == '-') then
        next = next+1
        op = string.sub(s, next, next)
        if (INTERCEPT_PHASES:IsValid(op)) then
            phase = op
            next = next+1
        end
    end

    return reactionName, nRandom, phase, next
end

local function parseBehavior( s, groupName )

    groupName = groupName or '?'
    local sLength = string.len(s)
    local next = string.find(s, InterceptionDefault.interceptReactionQualifier)
    if (next == nil) then
        next = 1
    else
        next = 2
    end

    local tokenLen = string.len(INTERCEPT_REACTIONS.None)
    local behavior = {}
    local reactionName, nRandom, phase, next = parseReaction(s, next)
    local reaction = INTERCEPT_REACTION:New(reactionName, nRandom, phase)

    while (true) do
        if (not INTERCEPT_REACTION:IsValid( reaction )) then
            Trace("parseBehavior-".. groupName .." :: invalid reaction: '".. reaction.Name .."'")
            return behavior
        else
            table.insert( behavior, reaction )
            next = string.find( s, InterceptionDefault.interceptReactionFallbackQualifier, next )
            if (next == nil or next + tokenLen > sLength) then
                return behavior end

            -- found another fallback reaction ...
            next = next+1
            reactionName, nRandom, phase, next = parseReaction(s, next)
			reaction = INTERCEPT_REACTION:New(reactionName, nRandom, phase)
        end
    end

    Trace("parseBehavior-".. groupName .." :: unknown reaction: ".. reaction or "nil" .." :: returns nil")
    return nil

end

--[[
getGroupBehavior
  Resolves behavior (one or more reactions) for intruder group when being intercepted

Parameters
  @intruder :: (string [name of controllable] or controllable) The intruder

Returns
  A table containing one or more Reactions. First one is primary (may be conditional); the others are fallback reactions
]]--
local function getGroupBehavior( intruderGroup, defaultBehavior )

    if (not isGroup(intruderGroup)) then
        error("intruderGroup is of type " .. type(intruderGroup))
        return
    end
    local groupName = intruderGroup.GroupName
    local behavior = tryGetRegisteredInterceptedBehavior(groupName)
    if (behavior ~= nil) then
        return behavior 
    end
    if defaultBehavior ~= nil then
        Trace("getGroupBehavior-".. groupName .." :: reaction not set; resolves to default behavior")
        return defaultBehavior
    end
    Trace("getGroupBehavior-".. groupName .." :: reaction not set")
    return {}
end

local function resolveIntruderReaction( behavior, intruder, interceptor, intruderSize, intruderMissiles, interceptorSize, interceptorMissiles )
    intruderSize = intruderSize or intruder:CountAliveUnits()
    interceptorSize = interceptorSize or interceptor:CountAliveUnits()
    
    function getMissiles(g, count)
        if isNumber(count) then return count end
        local _, _, _, _, msls = g:GetAmmunition()
        return msls
    end
    intruderMissiles = getMissiles( intruder, intruderMissiles)
    interceptorMissiles = getMissiles( interceptor, interceptorMissiles )

    function getValidated( reaction )
        if (isNumber(reaction.Randomization) and reaction.Randomization < 100) then
            local outcome = math.random(0, reaction.Randomization)
            if (outcome > reaction.Randomization) then
                return nil 
            end
        end

        if (reaction.Name == INTERCEPT_REACTIONS.None) then return reaction.Name end
        if (reaction.Name == INTERCEPT_REACTIONS.Divert) then return reaction.Name end
        if (reaction.Name == INTERCEPT_REACTIONS.Follow) then return reaction.Name end
        if (reaction.Name == INTERCEPT_REACTIONS.Attack3) then return reaction.Name end
        if (reaction.Name == INTERCEPT_REACTIONS.Defensive1) then return reaction.Name end

        -- conditional reactions ...
        if (reaction.Name == INTERCEPT_REACTIONS.Attack1 and GetGroupSuperiority( intruder, interceptor, intruderSize, intruderMissiles, interceptorSize, interceptorMissiles ) < 0) then
            -- intruder is/feels superior ...
            Trace("getInterceptedIntruderReaction-"..intruder.GroupName.." :: intruder feels superior to interceptor")
            return INTERCEPT_REACTIONS.Attack3
        end
        
        if (reaction.Name == INTERCEPT_REACTIONS.Attack2 and GetGroupSuperiority( intruder, interceptor, intruderSize, intruderMissiles, interceptorSize, interceptorMissiles ) <= 0) then
            -- intruder is/feels superior ...
            Trace("getInterceptedIntruderReaction-"..intruder.GroupName.." :: intruder feels superior or equal to interceptor")
            return INTERCEPT_REACTIONS.Attack3
        end

        -- todo support validating more reactions here
        Trace("getInterceptedIntruderReaction-"..intruder.GroupName.." :: reaction was ruled out: "..reaction.Name)
        return nil
    end

    for _, reaction in pairs(behavior) do
        local validReaction = getValidated( reaction )
        if (validReaction ~= nil) then 
            return validReaction 
        end
    end

    return nil
end

local function getDefaultIntruderReaction( useDefault, intruder, interceptor, intruderSize, intruderMissiles )
    return useDefault 
            or resolveIntruderReaction( AirPolicing.DefaultInterceptedBehavior, intruder, interceptor, intruderSize, intruderMissiles ) 
            or INTERCEPT_REACTIONS.None
end

-- getIntrudersReactions :: resolves intruders' reactions to being intercepted
-- @param intruder :: the intruder group
-- @param escorts :: (optional) numbered table with groups escorting the intruder
-- @param interceptor :: the group intercepting
-- @returns table :: { [<group name>] = <reaction> }
local function getIntrudersReactions( intruder, interceptor, escorts, useDefault )
  
    local reactions = {}
    local intruderMissiles = 0
    local intruderSize = 0

    if not intruder then error("getIntrudersReactions :: intruder was nil") end
    if not interceptor then error("getIntrudersReactions :: interceptor was nil") end

    -- get intruder size (incl. escorts) and amount of missiles ...

Debug("getIntrudersReactions :: #escorts= " .. tostring(#escorts))    

    if (#escorts > 0) then
        for _, escortGrp in ipairs(escorts) do
            intruderSize = intruderSize + escortGrp:CountAliveUnits()
            local _, _, _, _, missiles = escortGrp:GetAmmunition()
            intruderMissiles = intruderMissiles + missiles
        end
    end
    if intruderSize == 0 then
        intruderSize = intruder:CountAliveUnits()
        local _, _, _, _, missiles = intruder:GetAmmunition()
        intruderMissiles = intruderMissiles + missiles
    end
    local interceptorSize = interceptor:CountAliveUnits()
    local _, _, _, _, interceptorMissiles = interceptor:GetAmmunition()

    local function getGroupReaction( g, defaultGroup )
        if not g then
            Trace("getIntrudersReactions.getGroupReaction-? :: cannot resolve intruder group from ".. Dump(intruder).." :: EXITS")
            return getDefaultIntruderReaction( useDefault )
        end

        local behavior = getGroupBehavior( g )

        if #behavior == 0 then
            if defaultGroup then
                Trace("getIntrudersReactions.getGroupReaction-".. g.GroupName .." :: cannot resolve group reaction :: tries default group behavior (" .. defaultGroup.GroupName .. ")")
                behavior = getGroupBehavior( defaultGroup )
            end
            if #behavior == 0 then
                Trace("getIntrudersReactions.getGroupReaction-".. g.GroupName .." :: cannot resolve group reaction :: uses default reaction")
                return getDefaultIntruderReaction( useDefault )
            end
        end
        return resolveIntruderReaction(behavior, intruder, interceptor, intruderSize, intruderMissiles, interceptorSize, interceptorMissiles)
    end

    if #escorts > 0 then
        for _, escort in ipairs(escorts) do
            reactions[escort.GroupName] = getGroupReaction( escort, intruder )
        end
    end

    reactions[intruder.GroupName] = getGroupReaction( intruder )
    return reactions
end

local function setDefaultInterceptedBehavior( behavior )
    if (isString(behavior)) then
        -- behavior is string ...
        behavior = parseBehavior( behavior )
        if (behavior == nil) then 
            Trace("setDefaultInterceptedBehavior :: invalid behavior: " .. behavior)
            return
        end
        AirPolicing.DefaultInterceptedBehavior = behavior
        return self
    end

    if (not isTable( behavior )) then 
        error("Intercepted behavior must be table or string (invalid type: "..type(behavior)..")") 
    end

    for _, reaction in pairs(behavior) do
      if (not INTERCEPT_REACTION:IsValid( reaction )) then
          Trace("setDefaultInterceptedBehavior :: not a valid raction: "..Dump(reaction).." :: EXITS")
          return self
      end
    end
    AirPolicing.DefaultInterceptedBehavior = behavior
    Trace("WithDefaultInterceptReaction :: set to " .. reaction) 
    return self
end

local function setDefaultShowOfForceBehavior( behavior )
    if (isString(behavior)) then
        -- behavior is string ...
        behavior = parseBehavior( behavior )
        if (behavior == nil) then 
            Trace("setDefaultShowOfForceBehavior :: invalid behavior: " .. behavior)
            return
        end
        AirPolicing.DefaultInterceptedBehavior = behavior
        return self
    end

    if (not isTable( behavior )) then 
        error("Show of force behavior must be table or string (invalid type: "..type(behavior)..")") 
    end

    for _, reaction in pairs(behavior) do
      if (not INTERCEPT_REACTION:IsValid( reaction )) then
          Trace("setDefaultInterceptedBehavior :: not a valid raction: "..Dump(reaction).." :: EXITS")
          return self
      end
    end
    AirPolicing.DefaultInterceptedBehavior = behavior
    Trace("WithDefaultInterceptReaction :: set to " .. reaction) 
    return self
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
    interval = 2
}

function OnInsideGroupZone( groupName, callback, options )
    if ( groupName == nil) then
      Trace("OnInsideGroupZone-? :: Group name missing :: EXITS")
      return 
    end
    if (callback == nil) then 
      Trace("OnInsideGroupZone-"..groupName.." :: missing callback function :: EXITS")
      return 
    end
    local monitoredGroup = GROUP:FindByName( groupName )
    if (monitoredGroup == nil) then 
      Trace("OnInsideGroupZone-"..groupName.." :: intruder group not found :: EXITS")
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
      Trace("OnInsideGroupZone-"..groupName.." :: monitored group unit #"..tostring(unitNo).." not found :: EXITS")
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
        Trace("OnInsideGroupZone-"..groupName.." :: Monitored unit () was killed :: EXITS")
        stopTimerAfter = interval
      end
      )
    ]]--

    Trace("OnInsideGroupZone-"..groupName.." :: BEGINS :: "..string.format("zoneRadius=%d; interval=%d", zoneRadius, interval))

    local function detectUnits()

        monitoredUnit = monitoredGroup:GetUnit(unitNo)
        if (monitoredUnit == nil) then
            Trace("OnInsideGroupZone-"..groupName.." :: monitored group unit #"..tostring(unitNo).." not found (might be dead) :: Timer stopped!")
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
                    --Trace("OnInsideGroupZone-"..groupName.." :: filters out monitored group's units")
                    return 
                end
                local unitName = unit:GetName()
                local pos = Unit.getByName(unitName):getPoint()
                local unitUnitMSL = pos.y
                local distance = math.abs(unitUnitMSL - monitoredUnitMSL)

                if (distance > zoneRadius) then 
                    Trace("OnInsideGroupZone-"..unitName.." :: filters out "..unitName.." (vertically outside radius) :: EXITS")
                    return 
                end
                count = count+1
                table.insert(detected, count, unit:GetName())
            end)

        if (stopTimerAfter > 0) then
            stopTimerAfter = stopTimerAfter - interval
            if (stopTimerAfter <= 0) then
                Trace("OnInsideGroupZone-"..groupName.." :: TIMER STOPPED")
                timer:Stop()
            end
            return
        end

        if (count > 0) then
            Trace("OnInsideGroupZone-"..groupName.." :: "..tostring(count).." units detected inside zone")
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

    timer = TIMER:New(detectUnits, interceptZone)
    timer:Start(interval, interval)
    if (ar ~= nil) then
        ar.cancelFunction = function() timer:Stop() end
    end

end

OnInterceptedDefaults = {
    interceptedUnitNo = 1,
    zoneRadius = 180,
    zoneOffset = {
        -- default intercept zone is 50 m radius, 55 meters in front of intruder aircraft
        relative_to_unit = true,
        dx = 120,   -- longitudinal offset (positive = in front; negative = to the back)
        dy = 0,     -- latitudinal offset (positive = right; negative = left)
        dz = 10     -- vertical offset (positive = up; negative = down)
    },
    coalitions = { "blue" },
    description = nil,
    delay = 4,         -- time (seconds) required for interceptor to be established in intercept zone before interception is triggered
    interval = 2
}
function OnIntercepted( groupName, callback, options )
    if (groupName == nil) then
      Trace("OnIntercepted-? :: Group name missing :: EXITS")
      return 
    end
    if (callback == nil) then 
      Trace("OnIntercepted-"..groupName.." :: missing callback function :: EXITS")
      return 
    end
    local monitoredGroup = GROUP:FindByName( groupName )
    if (monitoredGroup == nil) then 
      Trace("OnIntercepted-"..groupName.." :: intruder group not found :: EXITS")
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
      Trace("OnIntercepted-"..groupName.." :: intruder group unit #"..tostring(unitNo).." not found :: EXITS")
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

    Trace("OnIntercepted-"..groupName.." ::  zoneOffset = {dx = "..tostring(zoneOffset.dx)..", dy="..tostring(zoneOffset.dy)..", dz="..tostring(zoneOffset.dz).."}")

    local interceptZone = ZONE_UNIT:New(intruderUnitName.."-intercepted", intruderUnit, zoneRadius, zoneOffset)
    Trace("OnIntercepted-"..groupName.." :: BEGINS :: "..string.format("zoneRadius=%d; delay=%d; interval=%d, description=%s", zoneRadius, delay, interval, description or ""))
    
    local function FindInterceptors()

        intruderUnit = monitoredGroup:GetUnit(unitNo) 
        if (intruderUnit == nil) then
            Trace("OnIntercepted-"..groupName.." :: monitored group unit #"..tostring(unitNo).." not found (might be dead) :: Timer stopped!")
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
                    --Trace("OnIntercepted-"..groupName.." :: filters out intruder group units")
                    return 
                end
                local interceptorName = interceptor:GetName()
                local pos = Unit.getByName(interceptorName):getPoint()
                local interceptorUnitMSL = pos.y
                local distance = math.abs(interceptorUnitMSL - monitoredUnitMSL)

                if (distance > zoneRadius) then 
                    --Trace("OnIntercepted-"..groupName.." :: filters out "..interceptorName.." (vertically outside radius)")
                    return 
                end
                local interceptorInfo = interceptorInfos[interceptorName]
                local timeEstablished = 0
                if (interceptorInfo == nil) then
                    Trace("OnIntercepted-"..groupName.." :: "..interceptorName.." is established in intercept zone")
                    if (description ~= nil) then
                        MESSAGE:New(description, delay):ToUnit(interceptor)
                        Trace("OnIntercepted-"..groupName.." :: description sent to "..interceptorName.." :: "..description)
                    end
                    interceptorInfo = { establishedTimestamp = timestamp, isDescriptionProvided = true }
                    interceptorInfos[interceptorName] = interceptorInfo
                else
                    timeEstablished = timestamp - interceptorInfo.establishedTimestamp
                    Trace("OnIntercepted-"..groupName.." :: "..interceptorName.." remains in intercept zone :: time="..tostring(timeEstablished).."s")
                end
                if (timeEstablished >= delay) then
                    interceptingUnit = interceptor
                end
          end,
          interceptors)

        if (stopTimerAfter > 0) then
            stopTimerAfter = stopTimerAfter - interval
            if (stopTimerAfter <= 0) then
                Trace("OnIntercepted-"..groupName.." :: TIMER STOPPED")
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
            Trace("OnIntercepted-"..groupName.." :: Intercepted by "..interceptingUnit:GetName())
            callback( result )
        end 
      
    end
    
    timer = TIMER:New(FindInterceptors, interceptZone)
    timer:Start(interval, interval)

end

SofDifficulty = { -- experimental concept
    Soft = 1,        -- will react to a single buzz
    Defensive = 2,   -- requires warning shots to react
    Hard = 3         -- requires getting hit before reacting
}


-- consider different default options for different types of groups (naval, helis, ground ...)
OnShowOfForceDefaults = {
    -- options
    Radius = 300,            -- in meters, max distance between interceptor and intruder for show of force to trigger
    MinBuzzCount = 1,        -- number of show-of force buzzes needed to trigger
    MinSpeedKts = 350,       -- minimum speed (knots) for show of force to trigger
    Coalitions = { "blue" }, -- only interceptors from this/these coalitions will be considered
    MinTimeBetween = 20,     -- time (seconds) betwwen SOF, when minCount > 1
    Interval = 2,            -- 
    MinTriggerDelay = 2,     -- minimum delay (seconds) before SOF triggers
    MaxTriggerDelay = 12,    -- maximum delay (seconds) before SOF triggers
    Description = nil,       -- (string) when provided a message is sent to interceptor (describing the intruder)
    Difficulty = SofDifficulty.Soft
}

--[[  WORK IN PROGRESS (rebuild show of force into a more object-oriented api and allow detection and menus, like with intercept)
ShowOfForceState = {
    Idle = 1,                -- no intruders detected yet
    IntrudersDetected = 2,   -- a list of detected intruders are available
    Active = 3               -- a show of force is in progress
}

ShowOfForce = {
    _state = ShowOfForceState.Idle,
    _interceptorGrp = nil,
    _detectedGroups = {}
}

function ShowOfForce:New( interceptor, detectionRange )
    local sof = routines.utils.deepCopy(ShowOfForce)
    local group = getGroup( interceptor )
    if (sof._interceptorGrp == nil) then
        Warning("ShowOfForce:New :: interceptor cannot be resolved from " .. Dump(interceptor) .. " :: EXITS")
        return nil
    end
    sof._interceptorGrp = group
    if (not isNumber(detectionRange)) then
        error("ShowOfForce:New :: detectionRange was not a number")
        Warning(debug.traceback())
    end
    local setGroup = SET_GROUP:New():AddGroup( sof._interceptorGrp )
    local detection = DETECTION_TYPES:New( setGroup ):SetAcceptRange( detectionRange )
    sof._detection = detection
    return sof
end

function ShowOfForce:Cancel()
    self._state = ShowOfForceState.Idle
    self._detectedGroups = {}
    return self
end

SofDetectOptions = {}

function ShowOfForce:Detect( range, options )
end
]]--

function OnShowOfForce( intruder, callback, options ) --, radius, minCount, minSpeedKts, coalitions, minTimeBetween, interval)

    local group = getGroup( intruder )
    if (group == nil) then
        Trace("OnShowOfForce-? :: cannot resolve group from ".. Dump(intruder) .." :: EXITS")
        return 
    end
    local groupName = group.GroupName
    if (callback == nil) then 
        Trace("OnShowOfForce-"..groupName.." :: missing callback function :: EXITS")
        return 
    end

    options = options or OnShowOfForceDefaults
    local countIntercepts = 0
    local Timer
    local stopTimerAfter = 0 
    local coalitions = options.Coalitions or GetOtherCoalitions( group )
    local radius = options.Radius or OnShowOfForceDefaults.Radius
    local minSpeedKts = options.MinSpeedKts or OnShowOfForceDefaults.MinSpeedKts
    local minBuzzCount = options.BuzzMinCount or OnShowOfForceDefaults.MinBuzzCount
    local minTimeBetween = options.MinTimeBetween or OnShowOfForceDefaults.MinTimeBetween
    local minTriggerDelay = options.MinTriggerDelay or OnShowOfForceDefaults.MinTriggerDelay
    local maxTriggerDelay = options.MaxTriggerDelay or OnShowOfForceDefaults.MaxTriggerDelay
    local interval = options.Interval or OnShowOfForceDefaults.Interval
    local description = options.Description or OnShowOfForceDefaults.Description 
    local difficulty = options.Difficulty or OnShowOfForceDefaults.Difficulty

    Trace("OnShowOfForce-"..groupName.." :: BEGINS :: "..string.format("radius=%d; minSpeedKts=%d; minCount=%d, minTimeBetween=%d, description=%s, coalitions=%s", radius, minSpeedKts, minBuzzCount, minTimeBetween, description or "", Dump(coalitions)))

    local interceptZone = ZONE_GROUP:New(groupName, group, radius)
    local interceptorsInfo = {}
    local onShootingStartFunc = nil
    local onUnitHitFunc = nil

    local INTERCEPT_INFO = {
        interceptor = nil,                         -- group name for interceptor performing SOF
        BuzzCount = 0,                             -- counts no. of show-of-forces performed for intruder
        lastTimestamp = nil,                       -- used to calculate next SOF when more than one is required
        Shots = 0,                                 -- no of shots fired by interceptor
        Hits = 0,                                  -- no of hits on intruder
        WasTriggered = false,                      -- set when iterceptor triggerd a SOF reaction (to avoid multiple triggers)
    }

    function INTERCEPT_INFO:New(interceptorGroup, timestamp, shots, hits)
        local info = routines.utils.deepCopy(INTERCEPT_INFO)
        info.interceptor = interceptorGroup.GroupName
        info.lastTimeStamp = timestamp
        info.Shots = shots
        info.Hits = hits
        interceptorsInfo[interceptorGroup.GroupName] = info
        return info
    end

    function INTERCEPT_INFO:IsTriggering()
        if self.BuzzCount < minBuzzCount then
            return false end

--Debug("INTERCEPT_INFO:IsTriggering :: " .. string.format("BuzzCount=%d, Shots=%d, Hits=%d", self.BuzzCount, self.Shots, self.Hits))

        if difficulty == SofDifficulty.Soft then
            Debug("OnShowOfForce :: Soft :: intruder was buzzed "..tostring(self.BuzzCount).." :: triggers ...")
            return true 
        end

        if difficulty == SofDifficulty.Defensive and self.Shots > 0 then
            Debug("OnShowOfForce :: Defensive :: shots were fired :: triggers ...")
            return true 
        end

        if difficulty == SofDifficulty.Hard and self.Hits > 0 then
            Debug("OnShowOfForce :: Hard :: hits were scored :: triggers ...")
            return true 
        end

        return false
    end

    function INTERCEPT_INFO:Trigger()
        stopTimerAfter = 5 -- seconds
        self.WasTriggered = true
        MissionEvents:EndOnShootingStart(onShootingStartFunc)
        MissionEvents:EndOnUnitHit(onUnitHitFunc)
        -- call back
        local result = {
            intruder = groupName,
            interceptors = { self.interceptor }
        }
        Trace("OnShowOfForce-"..groupName.." :: triggers show of force reaction from interceptor ".. self.interceptor)
        Delay(math.random(minTriggerDelay, maxTriggerDelay), function() callback( result )  end)
    end

    function INTERCEPT_INFO:AddBuzz()
        self.BuzzCount = self.BuzzCount + 1
        Trace("OnShowOfForce-"..groupName.." :: interceptor: "..self.interceptor.."  :: buzz count="..tostring(self.BuzzCount))
        if self:IsTriggering() then
            self:Trigger()
        end
        return self
    end

    function INTERCEPT_INFO:AddShots(count)
        self.Shots = self.Shots + count
        if self:IsTriggering() then
            self:Trigger()
        end
        return self
    end

    function INTERCEPT_INFO:AddHits(count)
        self.Hits = self.Hits + count
        if self:IsTriggering() then
            self:Trigger()
        end
        return self
    end

    local function addInterceptorInfo( interceptorGroup, timestamp, shots, hits )
        local desc = AirPolicing:GetGroupDescription(group)
        if desc then -- todo Support turning off assistance to suppress sending description
            MessageTo( interceptorGroup, desc, AirPolicing.Assistance.Duration )
        end
        return INTERCEPT_INFO:New(interceptorGroup, timestamp, shots, hits)
    end

    -- monitor (warning) shots and hits ...
    onShootingStartFunc = function(event)

        if not IsHeadingFor(event.IniUnit, group, NauticalMilesToMeters(2), 5) then
            return end

        local interceptorInfo = interceptorsInfo[event.IniGroupName.GroupName]
        if interceptorInfo == nil then
            INTERCEPT_INFO:New(event.IniGroup, nil, 1, 0)
        else
            interceptorInfo:AddShots(1)
        end
    end

    onUnitHitFunc = function(event)

        if group.GroupName ~= event.TgtGroupName then
            return end

        local interceptorInfo = interceptorsInfo[event.IniGroupName.GroupName]
        if interceptorInfo == nil then
            INTERCEPT_INFO:New(event.IniGroup, nil, 1, 1)
        else
            interceptorInfo:AddHits(1)
        end
    end
    MissionEvents:OnShootingStart(onShootingStartFunc)
    MissionEvents:OnUnitHit(onUnitHitFunc)

    local function findAircrafts()

        if (not group:IsAlive()) then
            Trace("OnShowOfForce-"..group.GroupName.." :: group is no longer alive :: STOPS")
            Timer:Stop()
            return
        end

        local function getSetGroup()
            local set = SET_GROUP:New()
                :FilterCategoryAirplane()
                :FilterZones({ interceptZone })
                :FilterActive()
            if coalitions ~= nil then
                set:FilterCoalitions(coalitions) end
            return set:FilterOnce()
        end

        local ok, interceptors = pcall(getSetGroup)

        if (not ok) then
            -- check to see whether the intruder still exists, or is dead ...
            local checkGroup = getGroup( intruder )
            if (checkGroup == nil) then
                Trace("OnShowOfForce-"..groupName.." :: group no longer exists :: STOPS")
                Timer:Stop()
                return 
            end
            if (not group:IsAlive()) then
                Trace("OnShowOfForce-"..groupName.." :: group now is dead :: STOPS")
                Timer:Stop()
                return 
            end
            return
        end

        local timestamp = UTILS.SecondsOfToday()

        -- if the intruder belongs to interceptor(s) coalition it will be included in the `interceptors` set, so needs to be fitered out
        -- also, oddly enough, the above filtering doesn't exclude groups flying vertically outside the radius
        -- (not sure if that's a MOOSE bug)
        -- so we need to filter those out manually 
        
        local intruderCoord = group:GetCoordinate()
        local foundInterceptor = nil
        
        Trace("OnShowOfForce.findAircrafts-"..groupName.." :: found interceptors "..tostring(#interceptors).." (timestamp = "..tostring(timestamp)..")")

        interceptors:ForEachGroup(
            function(interceptor)

                if (groupName == interceptor.GroupName) then
                    return end

                function isTooEarly(info)
                    if not info or not info.lastTimeStamp then 
                        return false end

                    -- check if enough time have passed since last SOF
                    local timeSinceLastSof = timestamp - (info.lastTimeStamp or timestamp)
                    info.lastTimeStamp = timestamp
                    return timeSinceLastSof < minTimeBetween

                end
                
                local interceptorInfo = interceptorsInfo[interceptor.GroupName]
                if isTooEarly(interceptorInfo) then
                    Trace("OnShowOfForce-"..groupName.." :: filters out interceptor (SOF is too early)")
                    return 
                end

                local velocityKts = interceptor:GetVelocityKNOTS()
                if (velocityKts < minSpeedKts) then
                    Trace("OnShowOfForce-"..groupName.." :: filters out interceptor (too slow at "..tostring(velocityKts)..")")
                    return
                end
                local interceptorCoord = interceptor:GetCoordinate()
                local distance = interceptorCoord:Get3DDistance(intruderCoord)
                if (distance > radius) then 
                    Trace("OnShowOfForce-"..groupName.." :: filters out "..interceptor.GroupName.." (vertically outside radius)")
                    return 
                end
                if (interceptorInfo == nil) then
                    interceptorInfo = addInterceptorInfo(interceptor, timestamp, 0, 0)
                end
                if interceptorInfo.WasTriggered then
                    return 
                end

                interceptorInfo:AddBuzz()
            end)

        if (stopTimerAfter > 0) then
            stopTimerAfter = stopTimerAfter - interval
            if (stopTimerAfter <= 0) then
                Trace("OnShowOfForce-"..groupName.." :: STOPS")
                Timer:Stop()
                interceptorsInfo = nil
            end
            return
        end
    end

    -- start timer to monitor buzzes ...
    Timer = TIMER:New(findAircrafts):Start(interval, interval)

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
      Trace("OnFollowMe-? :: unitName not specified :: EXITS")
      return
    end
    local unit = UNIT:FindByName( unitName )
    if (unit == nil) then
      Trace("OnFollowMe-"..unitName.." :: Unit was not found :: EXITS")
      return
    end
    if (escortedGroupName == nil) then
      Trace("OnFollowMe-"..groupName.." :: missing escortedGroupName :: EXITS")
      return
    end
    local escortedGroup = GROUP:FindByName( escortedGroupName )
    if (escortedGroup == nil) then
      Trace("OnFollowMe-"..groupName.." :: Escorted group ("..escortedGroupName..") not found :: EXITS")
      return
    end
    if (callback == nil) then 
      Trace("OnFollowMe-"..groupName.." :: missing callback function :: EXITS")
      return 
    end

    options = options or OnFollowMeDefaults
    local rockWings = options.rockWings ~= nil
    local pumpLights = options.pumpLights or OnFollowMeDefaults.pumpLights
    local minBankAngle = options.rockWings.minBankAngle or OnFollowMeDefaults.rockWings.minBankAngle
    local minCount = options.rockWings.minCount or OnFollowMeDefaults.rockWings.minBankAngle
    local maxTime = options.rockWings.maxTime or OnFollowMeDefaults.rockWings.maxTime
    local interval = options.interval or OnFollowMeDefaults.interval
    local timeout = OnFollowMeDefaults.timeout
    local autoTriggerTimeout = options.debugTimeoutTrigger or OnFollowMeDefaults.debugTimeoutTrigger

    local lastMaxBankAngle = nil
    local bankEvents = {}
    local isWingRockComplete = false
    local isLightsFlashedComplete = false 
    local countEvents = 0
    local timer = nil
    local startTime = UTILS.SecondsOfToday()
    local totalTime = 0

    Trace("OnFollowMe-"..unitName.." :: BEGINS :: "..string.format("rockWings="..tostring(rockWings ~= nil).."; minBankAngle=%d, minCount=%d, maxTime=%d", minBankAngle, minCount, maxTime))

    local function DetectFollowMeSignal()

        local timestamp = UTILS.SecondsOfToday()
        totalTime = timestamp - startTime
        local bankAngle = unit:GetRoll()
        --    Trace("OnFollowMe :: '"..unitName.." :: "..string.format("bankAngle=%d; lastMaxBankAngle=%d", bankAngle, lastMaxBankAngle or 0))
        local absBankAngle = math.abs(bankAngle)

        function getIsWingRockComplete() 
            table.insert(bankEvents, 1, timestamp)
            countEvents = countEvents+1
            --Trace("OnFollowMe :: '"..unitName.." :: count="..tostring(countEvents).."/"..tostring(minCount))
            if (countEvents < minCount) then return false end
            local prevTimestamp = bankEvents[minCount]
            local timeSpent = timestamp - prevTimestamp
            if (timeSpent > maxTime) then
                Trace("OnFollowMe :: '"..unitName.." :: TOO SLOW")
                return false
            end
            return true
        end

        if (rockWings) then
            if (bankAngle >= 0) then
                -- positive bank angle ...
                if (bankAngle >= minBankAngle and (lastMaxBankAngle == nil or lastMaxBankAngle < 0)) then
                    lastMaxBankAngle = bankAngle
                    isWingRockComplete = getIsWingRockComplete()
                end
            else
                -- negative bank angle ...
                if (absBankAngle >= minBankAngle and (lastMaxBankAngle == nil or lastMaxBankAngle > 0)) then
                    lastMaxBankAngle = bankAngle
                    isWingRockComplete = getIsWingRockComplete()
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
            Trace("OnFollowMe :: '"..unitName.." :: Triggers automatically (debug)")
        end

        if (not isComplete) then
            if (totalTime >= timeout) then
                Trace("OnFollowMe :: '"..unitName.." :: Times out :: Timer stops!")
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
        Trace("OnFollowMe :: '"..unitName.." :: Follow-me signal detected! :: Timer stops!")
        timer:Stop()
        bankEvents = nil

    end

    timer = TIMER:New(DetectFollowMeSignal)
    timer:Start(interval, interval)

end

InterceptionOptions = {
    OnInsideZone = OnInsideGroupZoneDefaults,
    OnIntercepted = OnInterceptedDefaults,
    OnFollowMe = OnFollowMeDefaults,
    showAssistance = false,
    audioAssistance = false
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
    if value ~= nil then
        self.showAssistance = value
    else
        self.showAssistance = true
    end

    if duration ~= nil then
        self.assistanceDuration = duration
    else
        self.assistanceDuration = AirPolicing.Assistance.Duration
    end

    return self
end

function InterceptionOptions:WithAudioAssistance( value )
    if value ~= nil then
        self.audioAssistance = value
    else
        self.audioAssistance = true
    end

    return self
end

function InterceptionOptions:WithAiReactionAssistance( value )
    if value ~= nil then
        self.aiReactionAssistance = value
    else
        self.aiReactionAssistance = true
    end

    return self
end

function InterceptionOptions:WithAiReactionAudioAssistance( value )
    if value ~= nil then
        self.aiReactionAudioAssistance = value
    else
        self.aiReactionAudioAssistance = true
    end

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
function OnInterception( group, callback, options, pg )

    group = getGroup( group )
    if (group == nil) then
        Trace("OnInterception-? :: Group could not be resolved :: EXITS")
        return 
    end
    if (callback == nil) then
        Trace("OnInterception-"..group.GroupName.." :: Callback function missing :: EXITS")
        return 
    end
    options = options or InterceptionOptions
    local ai = options._activeIntercept

    if (ai and options.showAssistance) then
        MessageTo( ai.interceptor, AirPolicing.Assistance.ApproachInstruction, options.assistanceDuration )
    end
    if (ai and options.audioAssistance) then
        MessageTo( ai.interceptor, AirPolicing.Assistance.ApproachInstructionAudio )
    end
    OnInsideGroupZone( group.GroupName,
        function( closing )
            local establishAssist = AirPolicing.Assistance.EstablishInstructionSingleton
            local establishAssistAudio = AirPolicing.Assistance.EstablishInstructionSingletonAudio
            -- if escort was not discovered when selecting the group for intercept, try spotting it again ...
            if ai.escort ~= nil or IsEscorted( ai.intruder ) then
                establishAssist = AirPolicing.Assistance.EstablishInstructionEscorted
                establishAssistAudio = AirPolicing.Assistance.EstablishInstructionEscortedAudio
            end

            if (ai and options.showAssistance) then
                MessageTo( ai.interceptor, establishAssist, options.assistanceDuration )
            end
            if (ai and options.audioAssistance) then
                MessageTo( ai.interceptor, establishAssistAudio )
            end
            -- display intruder description if available ...
            Delay( AirPolicing.Assistance.DescriptionDelay, 
                function()
                    local desc = AirPolicing:GetGroupDescription( group )
                    if desc then
                        MessageTo( ai.interceptor, desc, options.assistanceDuration )
                    end
                end)
            OnIntercepted( closing.monitoredGroup, 
                function( intercepted )
                    if (ai and options.showAssistance) then
                        MessageTo( ai.interceptor, AirPolicing.Assistance.SignalInstruction, options.assistanceDuration )
                    end
                    if (ai and options.audioAssistance) then
                        MessageTo( ai.interceptor, AirPolicing.Assistance.SignalInstructionAudio )
                    end
                    OnFollowMe(
                        intercepted.interceptingUnit, 
                        intercepted.interceptedGroup,
                        callback,
                        options.OnFollowMe)

                end, options.OnIntercepted)
        end, options.OnInsideZone)
end

function DebugOnInterception( source )

    OnInterception( source,
        function( ... )
        end)

end

function FollowOffsetLimits:GetFor( follower )

end

--------------------------------------------- [[ RADIO COMMANDS ]] ---------------------------------------------

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
    optionsMenu = nil,
    interceptMenu = nil,
    showOfForceMenu = nil,
    lookAgainMenu = nil,
    intruderMenus = {},
    
    -- interception state
    interceptState = INTERCEPT_STATE.Inactive,
    intruder = nil,
    
    -- assist options
    interceptAssist = false,
    interceptAssistAudio = false,
    sofAssist = false,
    sofAssistAudio = false,
    aiReactionAssist = false,
    aiReactionAssistAudio = false,
}

local makeInactiveMenus = nil

function PolicingGroup:isPolicing(group)
    local coalition = group:GetCoalition()
    local coalitionPolicing = _policingGroups[coalition]
    return coalitionPolicing ~= nil and coalitionPolicing[group.GroupName] ~= nil
end

function PolicingGroup:register(pg)
    local coalition = pg.group:GetCoalition()
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
    self.intruder = nil
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

local _debugTriggerOnAiWasInterceptedFunction = nil
local makeOptionsMenus = nil

local function establishInterceptMenus( pg, ig, ai ) -- ig = intruder group; ai = _ActiveIntercept

    pg.mainMenu:RemoveSubMenus()
    local function cancel()
        ai:Cancel()
        makeInactiveMenus( pg )
        if (pg.interceptAssist) then
            MessageTo( pg.group, AirPolicing.Assistance.CancelledInstruction, AirPolicing.Assistance.Duration )
        end
        if (pg.interceptAssistAudio) then
            MessageTo( pg.group, AirPolicing.Assistance.CancelledInstructionAudio )
        end
    end
    makeOptionsMenus( pg )
    MENU_GROUP_COMMAND:New(pg.group, "--CANCEL Interception--", pg.mainMenu, cancel, ig)
    if (DCAFCore.Debug) then
        MENU_GROUP_COMMAND:New(pg.group, ">> DEBUG: Trigger intercept", pg.mainMenu, _debugTriggerOnAiWasInterceptedFunction, ai, ig, pg)
    end
end

local function controllingInterceptMenus( pg, ig, ai ) -- ig = intruder group; ai = _ActiveIntercept

    pg.mainMenu:RemoveSubMenus()

    local function landHereCommand()
        local airbase = LandHere( ig )
        if (pg.aiReactionAssist) then
            local text = string.format( AirPolicing.Assistance.AiLandingInstruction, airbase.AirbaseName )
            MessageTo( pg.group, text, AirPolicing.Assistance.Duration )
        end
        if (pg.aiReactionAssistAudio) then
            MessageTo( pg.group, AirPolicing.Assistance.AiLandingInstructionAudio )
        end
        pg:interceptInactive()
        makeInactiveMenus( pg )
    end

    local function divertCommand()
        Divert( ig )
        if (pg.aiReactionAssist) then
            MessageTo( pg.group, AirPolicing.Assistance.AiDivertingInstruction, AirPolicing.Assistance.Duration )
        end
        if (pg.aiReactionAssistAudio) then
            MessageTo( pg.group, AirPolicing.Assistance.AiDivertingInstructionAudio )
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
        if (pg.interceptAssistAudio) then
            MessageTo( pg.group, AirPolicing.Assistance.CancelledInstructionAudio )
        end
    end
end

local function onAiWasIntercepted( intercept, ig, pg )

    local audioDelay = 0
    local function delayAudio( time ) audioDelay = audioDelay + time end

    -- delay reaction (random no. of seconds) ...
    local delay = AirPolicingOptions.GetAiReactionDelay(ig)
--Debug("onAiWasIntercepted :: delay="..tostring(delay)) -- nisse
    Delay(
        delay,
        function()
            local escorts = GetEscortingGroups( ig )
            if OnFollowMeDefaults.debugTimeoutTrigger then
                -- note: For debugging purposes the interceptor might also be an escort; remove it if that's the case ...
                for i, escort in ipairs(escorts) do
                    if escort == pg.group then
                        table.remove(escorts, i)
                        break
                    end
                end
            end

            local reactions = getIntrudersReactions( ig, pg.group, escorts, "unknown" )

-- Debug("onAiWasIntercepted :: reactions: " .. DumpPretty(reactions))             -- nisse
            local reaction = reactions[ig.GroupName]
            local defaultEscortReaction = nil
            for groupName, r in pairs(reactions) do
                defaultEscortReaction = r
                break
            end
            if (reaction == nil or reaction == "unknown") then
                -- there's no explicit reaction for escorted group; fall back to escorting group reaction (if any) ...
                reaction = defaultEscortReaction
                if reaction == nil or reaction == "unknown" then
                    local intruderSize = ig:CountAliveUnits()
                    local _, _, _, _, intruderMissiles = ig:GetAmmunition()
                    reaction = getDefaultIntruderReaction( nil, ig, pg.group, intruderSize, intruderMissiles )
                end
            end
            local intruderReaction = reaction
            reactions[ig.GroupName] = nil
            local icptorName = nil
            if (pg == nil) then
                icptorName = UNIT:FindByName(intercept.interceptor):GetGroup().GroupName
            else
                icptorName = pg.group.GroupName
            end

            function applyReactionTo( g, gReaction )
                if gReaction == INTERCEPT_REACTIONS.Defensive1 then
                    -- intruder goes into defensive (1) state ...
                    Trace("onAiWasIntercepted-"..icptorName.." :: " .. g.GroupName .. " goes defensive")
                    ROEDefensive( g )
                    return true
                elseif gReaction == INTERCEPT_REACTIONS.Attack3 then
                    Trace("onAiWasIntercepted-"..icptorName.." :: " .. g.GroupName .. " attacks interceptor")
                    TaskAttackGroup( g, pg.group )
                    return true
                elseif reaction == INTERCEPT_REACTIONS.Divert then
                    Trace("onAiWasIntercepted-"..icptorName.." :: " .. g.GroupName .. " diverts")
                    Divert( intercept.intruder )
                    return true
                elseif reaction == INTERCEPT_REACTIONS.Stop then
                    Trace("onAiWasIntercepted-"..icptorName.." :: " .. g.GroupName .. " lands")
                    LandHere( intercept.intruder )
                    return true
                elseif reaction == INTERCEPT_REACTIONS.Follow then
                    Trace("onAiWasIntercepted-"..icptorName.." :: "..ig.GroupName.." follows interceptor")
                    TaskFollow( intercept.intruder, intercept.interceptor, FollowOffsetLimits:New()) -- todo consider setting offset limit as configurable
                    return true
                end
                Warning("onAiWasIntercepted-" .. icptorName .. " :: unresolved reaction: " .. tostring(gReaction))
                return false
            end

            if (reaction == INTERCEPT_REACTIONS.None) then
                -- intruder ignores order ...
                Trace("Interception-"..icptorName.." :: "..ig.GroupName.." ignores interceptor")
                if (pg ~= nil) then
                    pg:interceptInactive()
                    inactiveMenus( pg )
                    if (pg.aiReactionAssist) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiDisobeyingInstruction, AirPolicing.Assistance.Duration )
                    end
                    if (pg.aiReactionAssistAudio) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiDisobeyingInstructionAudio )
                        delayAudio(AirPolicing.Assistance.AiDisobeyingInstructionAudioTime)
                    end
                end
                return
            end

            if (reaction == INTERCEPT_REACTIONS.Defensive1) then
                -- intruder goes into defensive (1) state ...
                if (pg ~= nil) then
                    pg:interceptInactive()
                    inactiveMenus( pg )
                    if (pg.aiReactionAssist) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiDisobeyingInstruction, AirPolicing.Assistance.Duration )
                    end
                    if (pg.aiReactionAssistAudio) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiDisobeyingInstructionAudio )
                        delayAudio(AirPolicing.Assistance.AiDisobeyingInstructionAudioTime)
                    end
                end
            elseif reaction == INTERCEPT_REACTIONS.Attack3 then
                -- intruder gets aggressive ...
                if (pg ~= nil) then
                    pg:interceptInactive()
                    inactiveMenus( pg )
                    if (pg.aiReactionAssist) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiAttackingInstruction, AirPolicing.Assistance.Duration )
                    end
                    if (pg.aiReactionAssistAudio) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiAttackingInstructionAudio )
                        delayAudio(AirPolicing.Assistance.AiAttackingInstructionAudioTime)
                    end
                end
                applyReactionTo( ig, reaction )
            elseif reaction == INTERCEPT_REACTIONS.Divert then
                -- intruder disobeys, but diverts ...
                if (pg ~= nil) then
                    pg:interceptInactive()
                    inactiveMenus( pg )
                    delayAudio(AirPolicing.Assistance.AiDisobeyDivertingInstructionAudioTime + 2)
                    Delay(1, 
                        function()
                            if (pg.aiReactionAssist) then
                                MessageTo( intercept.interceptor, AirPolicing.Assistance.AiDisobeyDivertingInstruction, AirPolicing.Assistance.Duration )
                            end
                            if (pg.aiReactionAssistAudio) then
                                MessageTo( intercept.interceptor, AirPolicing.Assistance.AiDisobeyDivertingInstructionAudio )
                            end
                        end)
                end
            elseif reaction == INTERCEPT_REACTIONS.Stop then
                -- intruder lands ...
                if (pg ~= nil) then
                    pg:interceptInactive()
                    inactiveMenus( pg )
                    if (pg.aiReactionAssist) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiLandingInstruction, AirPolicing.Assistance.Duration )
                    end
                    if (pg.aiReactionAssistAudio) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiLandingInstructionAudio )
                        delayAudio(AirPolicing.Assistance.AiLandingInstructionAudioTime)
                    end
                end
            elseif reaction == INTERCEPT_REACTIONS.Follow then
                -- intruder complies and follows interceptor ...
                if (pg ~= nil) then
                    pg:interceptControlling()
                    controllingInterceptMenus( pg, ig, ai )
                    if (pg.aiReactionAssist) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiComplyingInstruction, AirPolicing.Assistance.Duration )
                    end
                    if (pg.aiReactionAssistAudio) then
                        MessageTo( intercept.interceptor, AirPolicing.Assistance.AiComplyingInstructionAudio )
                        delayAudio(AirPolicing.Assistance.AiComplyingInstructionAudioTime)
                    end
                end
            end

            if not applyReactionTo( ig, reaction) then
                -- NOTE we should not reach this line!
                Trace("Interception-"..icptorName.." :: HUH?! :: Unknown reaction: " .. tostring(reaction))
            end

            -- apply escort reactions ...

--Debug("onAiWasIntercepted :: reactions: " .. DumpPretty(reactions))

            for escortName, reaction in pairs(reactions) do
                local eGroup = getGroup(escortName)
                local eReaction = nil
                if eGroup then
                    eReaction = reactions[escortName]
                                or intruderReaction 
                                or INTERCEPT_REACTIONS.None
                    if not applyReactionTo( eGroup, eReaction ) then
                        Trace("Interception-"..icptorName.." :: HUH?! :: Unknown escort reaction: " .. tostring(eReaction))
                    elseif eReaction == INTERCEPT_REACTIONS.Attack3 then
                        Trace("Interception-"..icptorName.." :: Escort (" .. escortName .. ") attacks!")
                        Delay(audioDelay,
                            function()
                                if (pg.aiReactionAssist) then
                                    MessageTo( intercept.interceptor, AirPolicing.Assistance.AiEscortAttacks, AirPolicing.Assistance.Duration )
                                end
                                if (pg.aiReactionAssistAudio) then
                                    MessageTo( intercept.interceptor, AirPolicing.Assistance.AiEscortAttacksAudio )
                                    delayAudio(AirPolicing.Assistance.AiEscortAttacksAudioTime)
                                end
                            end)
                    end
                end
            end

        end)
  
end

_debugTriggerOnAiWasInterceptedFunction = onAiWasIntercepted

function beginIntercept( pg, igInfo ) -- ig = intruder group
    
    pg:interceptEstablishing( igInfo.group )
    if (pg.lookAgainMenu ~= nil) then
        pg.lookAgainMenu:Remove()
    end

    local options = InterceptionOptions:New()
        :WithAssistance( pg.interceptAssist )
        :WithAudioAssistance( pg.interceptAssistAudio )
        :WithAiReactionAssistance( pg.aiReactionAssistance )
        :WithAiReactionAudioAssistance( pg.aiReactionAssistAudio )

    if (options.OnFollowMe.debugTimeoutTrigger ~= nil) then
      Trace("beginIntercept :: uses AI intercept debugging ...")
    end
    local ai = _ActiveIntercept:New( igInfo.group, pg.group )
    OnInterception(
        igInfo.group,
        function( intercept ) 
            onAiWasIntercepted( intercept, igInfo.group, pg )
        end, 
        options:WithActiveIntercept( ai ))

    establishInterceptMenus( pg, igInfo.group, ai )

end

local function menuSeparator( pg, parentMenu )
    function ignore() end
    MENU_GROUP_COMMAND:New(pg.group, "-----", parentMenu, ignore)
end

function GetSpottedFlights( source, radius, coalitions )

    local group = getGroup(source)
    if not group then
        Warning("GetSpottedFlights :: cannot resolve group from " .. Dump(source) .. " :: EXITS")
        return 0, {}
    end

    if radius == nil then
        radius = AirPolicingOptions.scanRadius
    end
    local zone = ZONE_UNIT:New(group.GroupName.."-scan", group, radius)
    local sourceCoordinate =  group:GetCoordinate()

    local groups = SET_GROUP:New()
    if coalitions then
        groups:FilterCoalitions( coalitions )
    end        
    groups
        :FilterCategoryAirplane()
        :FilterZones( { zone } )
        :FilterActive()
        :FilterOnce()

    local flights = { }
        function flights:isIn( g )
            for name, _ in pairs(flights) do
                if name == g.GroupName then
                    return true
                end
                return false
            end
        end

    local escortedGroups = {}
    --- escorts ---
    local escorts = {
        _count = 0
    }
        function escorts:isRegisteredEscort(g)
            for k, _ in pairs(escorts) do
                if (k == g.GroupName) then return true end
            end
            return false
        end
        function escorts:isClient(g)
            if self._count == 0 then return false end
            for k, info in pairs(self) do
                if isTable(info) then
                    if (info.escortingGroup == g.GroupName) then return true, info.group end
                end
            end
            return false, nil
        end
        function escorts:add( g, info )
            self[g.GroupName] = info
            self._count = self._count+1
        end
    --- escorts ---

    local countflights = 0

    -- ensure plane spotting is OFF until player takes off ...
    if not group:InAir() then
        return countflights, flights end

    groups:ForEachGroupAlive(
        function(g)

            if (group == g or not g:InAir() or not CanBeIntercepted(g)) then 
                Trace("GetSpottedFlights-" .. group.GroupName .. " :: group ".. g.GroupName .." is source, or filtered out :: IGNORES")
                return 
            end
            
            if (escorts:isRegisteredEscort(g)) then
                -- this is an escort group and its client group was already included; ignore ...
                Trace("GetSpottedFlights-" .. group.GroupName .. " :: group ".. g.GroupName .." is already registered as escort :: IGNORES")
                return
            end

            local intruderCoordinate = g:GetCoordinate()
            if (not sourceCoordinate:IsLOS(intruderCoordinate)) then 
                Trace("GetSpottedFlights-"..group.GroupName.." :: group "..g.GroupName.." is obscured (no line of sight)")
                return 
            end
            
            local verticalDistance = sourceCoordinate.y - intruderCoordinate.y

            -- consider looking at MOOSE's 'detection' apis for a better/more realistic mechanic here
            if (verticalDistance >= 0) then
                -- intruder is level or above interceptor (easier to detect - unfortunately we can't account for clouds) ...
                if (verticalDistance > radius) then 
                    Trace("GetSpottedFlights-"..group.GroupName.." :: group "..g.GroupName.." is too high")
                    return 
                end
            else 
                -- intruder is below interceptor (harder to detect) TODO account for lighting conditions? ...
                if (math.abs(verticalDistance) > radius * 0.65 ) then
                    Trace("GetSpottedFlights-"..group.GroupName.." :: group "..g.GroupName.." is too low")
                    return 
                end
            end

            local escortName = nil
            local isClient, escort = escorts:isClient(g)
            if (isClient) then
                -- this group is escorted; merge its escort and remove escort group from list of escorts ...
                Trace("flightsMenus-"..group.GroupName.." :: group "..g.GroupName.." is escorted by " .. escort.GroupName .. " :: MERGES")
                escortName = escort.GroupName
                escorts[escort.GroupName] = nil
            end

            local info = nil
            local rLoc = GetRelativeLocation( group, g )
            local client = GetEscortClientGroup(g)

            if client then
                -- this group is escorting another 'client' group; stash it for now and look for client group ...
                info = { 
                    text = nil, -- 2b resolved string.format( "%s %s for %s, %s", sPosition, sLevelPos, sDistance, sAngels ), 
                    group = g,
                    distance = rLoc.distance,
                    reaction = nil,
                    escortingGroup = client.GroupName
                } 
                escorts:add(g, info)
                Trace("GetSpottedFlights-"..group.GroupName.." :: group "..g.GroupName.." is escorting: ".. client.GroupName .."  :: STASHED")
            else
                info = { 
                    text = rLoc.ToString(),
                    group = g,
                    distance = rLoc.Distance,
                    reaction = nil,
                    escortingGroup = escortName,
                } 
                Trace("GetSpottedFlights-"..group.GroupName.." :: group "..g.GroupName.." is included")
                flights[g.GroupName] = info
                countflights = countflights+1
            end
        end)
    
    -- might be that escort was spotted but that its client group was not;
    -- if so the escort group needs to be included as a standalone group ...
    if escorts._count > 0 then
        for escortName, info in pairs(escorts) do
            local g = GROUP:FindByName(escortName)
            if g then
                local rLoc = GetRelativeLocation( group, g )
                local info = { 
                    text = rLoc.ToString(), 
                    group = g,
                    distance = rLoc.Distance,
                    reaction = nil,
                    escortingGroup = nil,
                } 
            end
        end
    end

    -- sort intruder menu with closest ones at the bottom
    table.sort(flights, function(a, b) return a.distance > b.distance end)
    
    return countflights, flights

end

local function intrudersMenus( pg )

    local countIntruders, intruders = GetSpottedFlights( pg.group )

    -- remove existing intruder menus and build new ones ...
    if (#pg.intruderMenus > 0) then
        for k,v in pairs(pg.intruderMenus) do
            v:Remove()
        end
    end
    if (countIntruders == 0) then
        if (pg.interceptAssist) then
            MessageTo(pg.group, "no nearby flights found", 4)
        end
        return
    end
    
    if (pg:isInterceptInactive()) then
        pg.interceptMenu:Remove()
        --menuSeparator( pg, pg.mainMenu ) obsolete
        pg.lookAgainMenu = MENU_GROUP_COMMAND:New(pg.group, "SCAN AREA again", pg.mainMenu, intrudersMenus, pg)
    end
    local intruderMenus = {}
    for k, info in pairs(intruders) do 
        if isTable(info) then
            table.insert(intruderMenus, MENU_GROUP_COMMAND:New(pg.group, info.text, pg.mainMenu, beginIntercept, pg, info))
        end
    end
    pg:interceptReady(intruderMenus)
    if (pg.interceptAssist) then
        MessageTo(pg.group, string.format( AirPolicing.Assistance.GroupsSpottedInstruction, countIntruders))
    end
    if (pg.interceptAssistAudio) then
        MessageTo(pg.group, AirPolicing.Assistance.GroupsSpottedInstructionAudio)
    end
end

local function buildSOFMenus( pg )
    -- todo (add ground groups)
end

function optionsMenus( pg )

    local optionsMenu = nil
    if (AirPolicing.Assistance.IsAllowed) then -- currently the OPTIONS menu only contains assistance options 
        optionsMenu = MENU_GROUP:New(pg.group, "OPTIONS", pg.mainMenu)
    end

    local function toggleInterceptAssist()
        pg.interceptAssist = not pg.interceptAssist
        updateOptionsMenu()
    end

    local function toggleInterceptAssistAudio()
        pg.interceptAssistAudio = not pg.interceptAssistAudio
        updateOptionsMenu()
    end

    local function toggleSofAssist()
        pg.sofAssist = not pg.sofAssist
        updateOptionsMenu()
    end

    local function toggleSofAssistAudio()
        pg.sofAssistAudio = not pg.sofAssistAudio
        updateOptionsMenu()
    end

    local function toggleAiReaactionAssist()
        pg.aiReactionAssist = not pg.aiReactionAssist
        updateOptionsMenu()
    end

    local function addOptionsMenus()
        Trace("updateOptionsMenus :: Updates options menu (interceptAssist="..tostring(pg.interceptAssist).."; sofAssist="..tostring(pg.sofAssist)..")")
        optionsMenu:RemoveSubMenus()

        if (not AirPolicing.Assistance.IsAllowed) then
            return end

        if (pg.interceptAssist) then
            MENU_GROUP_COMMAND:New(pg.group, "Turn OFF intercept assistance", optionsMenu, toggleInterceptAssist)
        else
            MENU_GROUP_COMMAND:New(pg.group, "ACTIVATE intercept assistance", optionsMenu, toggleInterceptAssist)
        end

        if (pg.aiReactionAssist) then
            MENU_GROUP_COMMAND:New(pg.group, "Turn OFF AI reaction assistance", optionsMenu, toggleAiReaactionAssist)
        else
            MENU_GROUP_COMMAND:New(pg.group, "ACTIVATE AI reaction assistance", optionsMenu, toggleAiReaactionAssist)
        end

        if (pg.interceptAssistAudio) then
            MENU_GROUP_COMMAND:New(pg.group, "Turn OFF verbal assistance", optionsMenu, toggleInterceptAssistAudio)
        else
            MENU_GROUP_COMMAND:New(pg.group, "ACTIVATE verbal assistance", optionsMenu, toggleInterceptAssistAudio)
        end
--[[
    TODO add SoF assist options menu
        if (pg.sofAssist) then
            MENU_GROUP_COMMAND:New(pg.group, "Turn OFF Show-of-Force assistance", optionsMenu, toggleSofAssist, false)
        else
            MENU_GROUP_COMMAND:New(pg.group, "ACTIVATE Show-of-Force assistance", optionsMenu, toggleSofAssist, true)
        end

        if (pg.sofAssist) then
            MENU_GROUP_COMMAND:New(pg.group, "Turn OFF Show-of-Force assistance", optionsMenu, toggleSofAssist, false)
        else
            MENU_GROUP_COMMAND:New(pg.group, "ACTIVATE Show-of-Force assistance", optionsMenu, toggleSofAssist, true)
        end
]]--
    end
    updateOptionsMenu = addOptionsMenus
    if (AirPolicing.Assistance.IsAllowed) then -- currently the OPTIONS menu only contains assistance options 
        addOptionsMenus()
    end

end

makeOptionsMenus = optionsMenus

function inactiveMenus( pg )

    pg:interceptInactive()
    pg.mainMenu:RemoveSubMenus()
    makeOptionsMenus( pg )
    pg.interceptMenu = MENU_GROUP_COMMAND:New(pg.group, "SCAN AREA for nearby flights", pg.mainMenu, intrudersMenus, pg)
end

makeInactiveMenus = inactiveMenus

function PolicingGroup:New( group, options )

    if (PolicingGroup:isPolicing(group)) then error("Cannot register same policing group twice: '"..group.GroupName.."'") end
    local pg = routines.utils.deepCopy(PolicingGroup)
    pg.group = group
    pg.mainMenu = MENU_GROUP:New(group, "Policing")
    pg.interceptAssist = options.interceptAssist
    pg.interceptAssistAudio = options.interceptAssistAudio
    pg.aiReactionAssist = options.aiReactionAssist
    pg.aiReactionAssistAudio = options.aiReactionAssistAudio
    pg.sofAssist = options.showOfForceAssist
    pg.sofAssistAudio = options.showOfForceAssistAudio
    PolicingGroup:register(pg)
    inactiveMenus( pg )
    return pg

end

AirPolicingOptions = {
    scanRadius = NauticalMilesToMeters(5),
    aiReactionDelayMin = 2,          -- minimum time after an order was issued until AI reacts
    aiReactionDelayMax = 5,          -- maximum time after an order was issued until AI reacts
    interceptAssist = false,
    interceptAssistAudio = false,
    aiReactionAssist = false,
    aiReactionAssistAudio = false,
    showOfForceAssist = false,
    showOfForceAssistAudio = false,

    GetAiReactionDelay = function( aiGroup )
        -- todo consider using different AI reaction delays for different types of AI groups (ships might take longer to react, cocky fighter pilots might be insubordinate)
        if (AirPolicingOptions.aiReactionDelayMax == AirPolicingOptions.aiReactionDelayMin) then
            return AirPolicingOptions.aiReactionDelayMin
        end
        return math.random(AirPolicingOptions.aiReactionDelayMin, AirPolicingOptions.aiReactionDelayMax)
    end
}

function AirPolicingOptions:New()
    local options = routines.utils.deepCopy(AirPolicingOptions)
    return options
end

function AirPolicingOptions:WithScanRadius( value )
    if (not isNumber(value)) then error("WithScanRadius expects a numeric value") end
    self.scanRadius = 4
    return self
end

--[[
AirPolicingOptions:WithAssistance    
    Enables textual assist messages for intercept and SoF procedures
]]--
function AirPolicingOptions:WithAssistance( audio )
    AirPolicing.Assistance.IsAllowed = true
    if audio == nil then
        audio = true
    end
    self.interceptAssist = true
    self.interceptAssistAudio = audio
    self.aiReactionAssist = true
    self.aiReactionAssistAudio = audio
    self.showOfForceAssist = true
    return self
end

--[[
AirPolicingOptions:WithInterceptAssist    
    Enables textual assist messages for intercept procedure
]]--
function AirPolicingOptions:WithInterceptAssist()
    AirPolicing.Assistance.IsAllowed = true
    self.interceptAssist = true
    return self
end

--[[
AirPolicingOptions:WithShowOfForceAssist    
    Enables textual assist messages for show of force procedure
]]--
function AirPolicingOptions:WithShowOfForceAssist()
    AirPolicing.Assistance.IsAllowed = true
    self.showOfForceAssist = true
    return self
end


--[[
AirPolicingOptions:WithAudioAssist
    Enables verbal assist messages for intercept and SoF procedures
]]--
function AirPolicingOptions:WithAudioAssist()
    AirPolicing.Assistance.IsAllowed = true
    self.interceptAssistAudio = true
    self.showOfForceAssistAudio = true
    self.aiReactionAssistAudio = true
    return self
end

--[[
AirPolicingOptions:WithAiInterceptBehavior
  Sets AI intercepted behaviors  

Parameters
  Can be one or two; 
  If only one parameter is passed then it is assumed to be used to specify one or "pattern" behaviors
  If two parameters are passed then the first one will be used as a default behavior 
  and the second will be one or more "pattern" behaviors.

Remarks
  TODO : explain the various available behaviors and how they can be used as fallbacks to conditioned behaviors
  TODO : explain pattern behaviors
  TODO : explain conditioned behaviors
]]--
function AirPolicingOptions:WithAiInterceptBehavior( ... )
    Trace("AirPolicingOptions:WithAiInterceptBehavior :: " .. DumpPretty(arg))
    if (#arg == 0) then
        error("Expected arguments!")
    end
    local idx = 1
    if (#arg > 1) then
        setDefaultInterceptedBehavior(arg[1])
        idx = 2
    end
    local behaviors = arg[idx]
    -- todo Consider validating the behaviors for correct syntax/identifiers/qualifiers
    if (not isTable( behaviors )) then
         error(" Behaviors must be table or single string (for default)") 
    end
    for k, s in pairs(behaviors) do
        local behavior = parseBehavior( s )
        behaviors[k] = behavior
    end
    _aiInterceptedBehavior = behaviors
    return self
end

function AirPolicingOptions:WithAiShowOfForceBehavior( ... )
    Trace("AirPolicingOptions:WithAiShowOfForceBehavior :: " .. DumpPretty(arg))
    if (#arg == 0) then
        error("Expected arguments!")
    end

end

function AirPolicingOptions:WithGroupDescriptions( descriptions )
    AirPolicing._aiGroupDescriptions = descriptions or {}
    return self
end

function AirPolicingOptions:WithAiInterceptorDebugging( timeout )
  OnFollowMeDefaults.debugTimeoutTrigger = timeout or 2
  Trace("AirPolicingOptions:WithAiInterceptorDebugging :: " .. tostring(OnFollowMeDefaults.debugTimeoutTrigger))
  return self
end

function AirPolicingOptions:WithTracing( value )
    value = value or true
    AirPolicing.Trace = value
    DCAFCore.Trace = DCAFCore.Trace or value
    return self
end

function EnableAirPolicing( options ) -- todo consider allowing filtering which groups/type of groups are to be policing
    options = options or AirPolicingOptions
    MissionEvents:OnPlayerEnteredAirplane(
        function( data )
            local group = getGroup( data.IniGroupName )
            if (group ~= null) then 
                if (PolicingGroup:isPolicing(group)) then
                    Trace("EnableAirPolicing :: player ("..data.IniPlayerName..") entered "..data.IniUnitName.." :: group is already air police: "..data.IniGroupName)
                    return
                end
                PolicingGroup:New(group, options)
                Trace("EnableAirPolicing :: player ("..data.IniPlayerName..") entered "..data.IniUnitName.." :: air policing options added for group "..data.IniGroupName)
            end
    
        end)
    Trace("AirPolicing was enabled")
end


-------------------------- DEBUGGING ---------------------------

function INTERCEPT_STATE:ToString(value)
    if value == INTERCEPT_STATE.Inactive then
        return "Inactive" end

    if value == INTERCEPT_STATE.Ready then
        return "Ready" end
    
    if value == INTERCEPT_STATE.Establishing then
        return "Establishing" end
        
    if value == INTERCEPT_STATE.Controlling then
        return "Controlling" end

    return "(unknown)"
end

function AirPolicingOptions:WithDebugging( value )
    value = value or true
    AirPolicing.Debug = value
    DCAFCore.Debug = DCAFCore.Debug or value
    return self
end

function AirPolicingOptions:WithDebuggingToUI( value )
    value = value or true
    DCAFCore.DebugToUI = value
    return self
end

function AirPolicing:AddDebugMenus( policingCoalition, scope )

    local targetCoalition = nil
    local targetGroup = nil

    if scope then
        if isNumber(scope) then
            -- assume coalition ...
            targetCoalition = scope
            if scope ~= coalition.side.BLUE and scope ~= coalition.side.RED and scope ~= coalition.side.NEUTRAL then
                -- nope, wasn't coalition ...
                targetCoalition = nil
            else
                Warning("AirPolicing:AddDebugMenus :: adds debug options for coalition " .. Dump(targetCoalition) .. " ...")
            end
        end

        if not targetCoalition then 
            -- assume group ...
            targetGroup = getGroup(scope)
            if not targetGroup then
                Warning("AirPolicing:AddDebugMenus :: cannot resolve group from " .. Dump(scope) .. " :: EXITS")
                return
            end
            Warning("AirPolicing:AddDebugMenus :: adds debug options for group " .. Dump(targetGroup.GroupName) .. " ...")
        end
    end

    local coalition = policingCoalition
    if not coalition and targetCoalition then
        coalition = targetCoalition
    elseif not coalition and targetGroup then
        coalition = targetGroup:GetCoalition()
    end
    if not coalition then
        Warning("AirPolicing:AddDebugMenus :: cannot resolve coalition from " .. Dump(policingCoalition) .. " :: EXITS")
        return
    end

    local pgDebugging = _policingGroups.debugging
    if not pgDebugging then
        pgDebugging = {}
        _policingGroups.debugging = pgDebugging
    end

    local debugging = pgDebugging[scope]
    if not debugging then
        debugging = {
            timer = nil,
            mainMenu = nil,
            -- policing groups debugging
            isShowingPolicingGroups = true,
            policingGroupsMenu = nil
        }
    end
    if targetCoalition then
        debugging.mainMenu = MENU_COALITION:New(targetCoalition, "DEBUG Policing")
    elseif targetGroup then
        debugging.mainMenu = MENU_GROUP:New(targetGroup, "DEBUG Policing")
    else
        debugging.mainMenu = MENU_MISSION:New("DEBUG Policing")
    end

    local function showPolicingGroups()
        local text = "------- POLICING GROUPS -------\n"
        local policingGroups = _policingGroups[coalition]
        if policingGroups then
            local function getPlayers(info)
                local units = info.group:GetUnits()
                local s = ""
                for _, unit in ipairs(units) do
                    if string.len(s) > 0 then
                        s = s .. "; "
                    end
                    s = s .. "[" .. unit:GetName() .. "] = " .. unit:GetPlayerName()
                end
                return s
            end

            local function getPgInfoText(info)
                local s = string.format("{\n  interceptState=%s,\n", tostring(INTERCEPT_STATE:ToString(info.interceptState)))
                       .. string.format("  intcptAssist=%s, intcptAudioAssist=%s,\n", tostring(info.interceptAssist), tostring(info.interceptAssistAudio))
                if info.intruder then
                    s = s .. string.format("  intruder=%s,\n", tostring(info.intruder.GroupName))
                end
                s = s .. string.format("  sofAssist=%s, sofAudioAssist=%s,\n", tostring(info.sofAssist), tostring(info.sofAudioAssist))
                      .. string.format("  aiReactionAssist=%s,\n", tostring(info.aiReactionAssist))
                      .. string.format("  players=%s\n}", getPlayers(info))
                return s
            end

            for name, info in pairs(policingGroups) do
                text = text .. name .. " = " .. getPgInfoText(info) .. "\n"
            end
        end
        if targetCoalition then
            MESSAGE:New(text, 9):ToCoalition(targetCoalition)
        elseif targetGroup then
            MessageTo(targetGroup, text, 9)
        else
            MESSAGE:New(text, 9):ToAll()
        end
    end

    local togglePolicingGroupsFunc = nil
    local function togglePolicingGroupsMenu()
        debugging.isShowingPolicingGroups = not debugging.isShowingPolicingGroups
        if debugging.policingGroupsMenu then
            debugging.policingGroupsMenu:Remove()
        end

        local caption = nil
        if debugging.isShowingPolicingGroups then
            caption = "Hide Policing Groups"
            debugging.timer = TIMER:New(showPolicingGroups):Start(1,10)
        else
            caption = "Show Policing Groups"
            if debugging.timer then
                debugging.timer:Stop()
            end
        end
        if targetCoalition then
            debugging.policingGroupsMenu = MENU_COALITION_COMMAND:New(targetCoalition, caption, debugging.mainMenu, togglePolicingGroupsFunc)
        elseif targetGroup then
            debugging.policingGroupsMenu = MENU_GROUP_COMMAND:New(targetGroup, caption, debugging.mainMenu, togglePolicingGroupsFunc)
        else
            debugging.policingGroupsMenu = MENU_MISSION_COMMAND:New(caption, debugging.mainMenu, togglePolicingGroupsFunc)
        end
    end
    togglePolicingGroupsFunc = togglePolicingGroupsMenu
    togglePolicingGroupsMenu()

end

function DebugIntercept( intruder )
    Debug("DebugIntercept-"..Dump(intruder).." :: initiated")
    OnInterception(
        intruder, 
        function( intercept ) 
            onAiWasIntercepted( intercept, GROUP:FindByName(intercept.intruder) ) 
        end)

end

function DebugGetSpottedFlights( source ) -- nisse Remove when debugged

    local deep = DumpPrettyOptions:New():Deep()
    local count, flights = GetSpottedFlights( source, NauticalMilesToMeters(10) )

    local txt = ""
    for k, v in pairs(flights) do
        txt = txt .. k .. "; "
    end
    Debug( "no. of nearby flights: " .. tostring(count) .. " :: { " .. txt .. " }")
    
end

Warning("DCAF.AirPolicing.Debugging was loaded")

----------------------- END -----------------------

Trace("DCAF.AirPolicing was loaded")



