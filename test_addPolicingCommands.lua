_policingGroups = {}

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
    return _policingGroups[group.GroupName] ~= nil
end

function PolicingGroup:register(pg)
    table.insert( _policingGroups, pg )
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
        RouteDivert( ig )
        if (pg.interceptAssist) then
            MessageTo( pg.group, AirPolicing.Assistance.DivertNowOrderedInstruction, AirPolicing.Assistance.Duration )
        end
        pg:interceptInactive()
        makeInactiveMenus( pg )
    end

    MENU_GROUP_COMMAND:New(pg.group, "Order: Land here!", pg.mainMenu, landHereCommand)
    if (CanDivert(ig)) then 
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

            pg:interceptControlling()
            controllingInterceptMenus( pg, ig, ai )
            Follow( intercept.intruder, intercept.interceptor )
            if (pg.interceptAssist) then
                MessageTo( intercept.interceptor, AirPolicing.Assistance.LeadInstruction, AirPolicing.Assistance.Duration )
            end

        end, 
        options:WithActiveIntercept( ai ))

    establishInterceptMenus( pg, ig, ai )

end

local function menuSeparator( pg, parentMenu )
    function ignore() end
    MENU_GROUP_COMMAND:New(pg.group, "-----", parentMenu, ignore)
end

local function intrudersMenus( pg )
    local radius = UTILS.NMToMeters(4)
    local zone = ZONE_UNIT:New(pg.group.GroupName.."-scan", pg.group, radius)
    
    local groups = SET_GROUP:New()
        :FilterCategories( { "plane" } )
        --:FilterCoalitions( coalitions )
        :FilterZones( { zone } )
        :FilterActive()
        :FilterOnce()

    local intruders = {}
    groups:ForEach(
        function(g)
            if (pg.group.GroupName == g.GroupName or not g:InAir() or not CanBeIntercepted(g)) then return end
            
            local ownCoordinate =  pg.group:GetCoordinate()
            local intruderCoordinate = g:GetCoordinate()

            -- bearing
            local dirVec3 = ownCoordinate:GetDirectionVec3( intruderCoordinate )
            local angleRadians = ownCoordinate:GetAngleRadians( dirVec3 )
            local angleDegrees = UTILS.Round( UTILS.ToDegree( angleRadians ), 0 )
            local sBearing = string.format( '%03d°', angleDegrees )

            -- distance
            local distance = ownCoordinate:Get2DDistance(intruderCoordinate)
            Debug("---> intrudersMenus :: distance = "..tostring(distance))
            local sDistance = DistanceToStringA2A( distance, true )
            
            -- angels
            local sAngels = GetAltitudeAsAngelsOrCherubs(g) -- ToStringAngelsOrCherubs( feet )

            --local lead = g:GetUnit(1)
            table.insert(intruders, { text = "Intercept flight at "..string.format( "%s for %s, %s", sBearing, sDistance, sAngels ), intruder = g })
        end)

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
            pg.lookAgainMenu = MENU_GROUP_COMMAND:New(pg.group, "LOOK AGAIN for nearby intruders", pg.mainMenu, intrudersMenus, pg)
        end
        local intruderMenus = {}
        for k, v in pairs(intruders) do 
            table.insert(intruderMenus, MENU_GROUP_COMMAND:New(pg.group, v.text, pg.mainMenu, beginIntercept, pg, v.intruder))
        end
        pg:interceptReady(intruderMenus)
        if (pg.interceptAssist) then
            MessageTo( pg.group, tostring(#intruders).." intruders are nearby. Use menu to intercept", 6)
        end
    else
        if (pg.interceptAssist) then
            MessageTo( pg.group, "no nearby intruders found", 4)
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
    pg.interceptMenu = MENU_GROUP_COMMAND:New(pg.group, "Look for airspace intruders", pg.mainMenu, intrudersMenus, pg)
    pg.showOfForceMenu = MENU_GROUP_COMMAND:New(pg.group, "Begin show-of-force", pg.mainMenu, buildSOFMenus, pg)

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
    local pg = PolicingGroup:register(routines.utils.deepCopy(PolicingGroup))
    pg.group = group
    pg.mainMenu = MENU_GROUP:New(group, "Policing")
    pg.interceptAssist = options.interceptAssist
    pg.sofAssist = options.showOfForceAssist
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
    --EVENT:New():HandleEvent(EVENTS.PlayerEnterAircraft,
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

end

