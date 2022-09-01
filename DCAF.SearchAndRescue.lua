--[[
    Example:
    SearchAndRescue:New():SpawnFollowingCarrier( "Carrier-1-1", "Carrier-SAR-SH60B", SPAWN.Takeoff.Cold, 300)
]]--

SearchAndRescue = {
    _carrierUnit = nil,
    _spawns = {},
    FollowingRespawnInterval = 3600, -- (seconds) SAR followinfg helicopter lands and a new one gets spawned at this interval
}

function SearchAndRescue:New( carrier )
    return routines.utils.deepCopy( SearchAndRescue )
end

function SearchAndRescue:GetSpawn( name )
    local spawn = SearchAndRescue._spawns[name]
    if spawn then
        return spawn
    end
    spawn = SPAWN:New( name )
    SearchAndRescue._spawns[name] = spawn
    return spawn
end

function SearchAndRescue:SpawnFollowingCarrier( carrierUnit, group, takeoff, respawnInterval )
    self._carrierUnit = getUnit( carrierUnit )
    if (self._carrierUnit == nil) then
        Warning("SearchAndRescue:SpawnFollowingCarrier :: cannot resolve carrier group from '" .. Dump(carrierUnit).. "'' :: EXITS")
        return self
    end
    local carrierName = self._carrierUnit:GetName()
    local carrierGrp = self._carrierUnit:GetGroup()
    local airbase = AIRBASE:FindByName(carrierName)
    if (airbase == nil) then
        Warning("SearchAndRescue:SpawnFollowing :: cannot resolve airbase from carrier '" .. carrierName .. "' :: EXITS")
        return self
    end
    
    local templateGrp = getGroup( group )
    if (templateGrp == nil) then
        Warning("SearchAndRescue:SpawnFollowingCarrier :: cannot resolve SAR group " .. Dump(group).. " :: EXITS")
        return self
    end

    local offset = { x = 0, y = 30, z = 100 }
    takeoff = takeoff or SPAWN.Takeoff.Cold

    local function takeoffAndFollow()
    end

    local spawn = self:GetSpawn( templateGrp.GroupName )
    spawn:OnSpawnGroup( 
        function( group )
            local oldRoute = group:GetTaskRoute()
            local followTasks = {
                [1] = {
                    ["enabled"] = true,
                    ["auto"] = false,
                    ["id"] = "Follow",
                    ["number"] = 1,
                    ["params"] = {
                        ["lastWptIndexFlagChangedManually"] = true,
                        ["groupId"] = carrierGrp:GetID(),
                        ["lastWptIndex"] = 99,
                        ["lastWptIndexFlag"] = true,
                        ["pos"] = offset,
                    },
                }
            }
        
            local wp1 = oldRoute[1]
            local wp1coord = COORDINATE:New(wp1.x, wp1.y, 0 )
            local wp2coord = wp1coord:Translate( 1000, 90 )
            local wp2 = wp2coord:WaypointAir(
                COORDINATE.WaypointAltType.BARO,
                COORDINATE.WaypointType.TurningPoint,
                COORDINATE.WaypointAction.TurningPoint,
                30,
                false,
                nil,
                followTasks)
            local wp3coord = wp2coord:Translate( 300, 90 )
            local wp3 = wp3coord:WaypointAir(
                COORDINATE.WaypointAltType.BARO,
                COORDINATE.WaypointType.TurningPoint,
                COORDINATE.WaypointAction.TurningPoint,
                30,
                false,
                nil,
                nil,
                DCAFCore.WaypointNames.RTB)
            local wp4 = wp3coord:WaypointAirLanding( wp1.speed, airbase )
        
            local route = {}
            table.insert( route, wp1 )
            table.insert( route, wp2 )
            table.insert( route, wp3 )
            table.insert( route, wp4 )
        
        local deep = DumpPrettyOptions:New():Deep()
        Debug("nisse :: route before set: " .. DumpPretty(route, deep))
        
            group:Route( route )
        
        local nisse_route = group: CopyRoute()
        Debug("nisse :: route set: " .. DumpPretty(nisse_route, deep))
        end)
    
    local sarGrp = spawn:SpawnAtAirbase( airbase, takeoff )

    respawnInterval = respawnInterval or SearchAndRescue.FollowingRespawnInterval
    if (respawnInterval < 1) then
        return self
    end

    function landOnCarrier()
        local startCoord = sarGrp:GetCoordinate():Translate( 300, 90 )
        local wp1 = startCoord:WaypointAirTurningPoint(COORDINATE.WaypointAltType.BARO)
        local wp2 = startCoord:WaypointAirLanding(nil, airbase)
        local landRoute = {}
        table.insert(landRoute, wp1)
        table.insert(landRoute, wp2)
        sarGrp:Route(landRoute)
        sarGrp:HandleEvent(EVENTS.Land, 
            function()
                Delay(120, function()
                    sarGrp:Destroy()
                end)
            end)
    end

    -- spawn a new SAR group and remove the current one ... TODO see if it's possible to land the old SAR
    Delay(respawnInterval, 
        function()
            Trace("SearchAndRescue:SpawnFollowingCarrier :: replacing SAR group from carrier '"..carrierName.."'")
            landOnCarrier()
            SearchAndRescue:New():SpawnFollowingCarrier(carrierUnit, group, takeoff, respawnInterval)
        end)

    return group

end

