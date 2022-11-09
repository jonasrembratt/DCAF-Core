DCAF.Debug = true

local function delayStart()
   return 0
   -- replace above line with the next instead, to delay betwen 1 and 10 minutes:
   -- return math.random(60, 600)
end

----- SECOND WAVE OF TANKERS (Shell-2 and Texaco-2; please look for >>SECOND WAVE<< below)
local function launchShell2()
   DCAF.Tanker:NewFromCallsign(CALLSIGN.Tanker.Shell, 2 )
      -- >>SHELL TRACK<< next line establishes the tanker track at waypoint 2, with 102 degree heading for 40nm (change )
     :SetTrackFromWaypoint(2, 201, NauticalMiles(40)) -- track begins at WP2, tracks heading 102 degrees for 40nm at block 22, and 'true' = track is drawn on F10 map
     :OnFuelState(0.17, function(tanker)  -- will automatically spawn its replacement when fuel reaches 17%
         tanker:RTB()
         -- uncomment next line to always have a SHELL-2 tanker working the track
         -- tanker:SpawnReplacement(delay) -- spawns after <delay> seconds (nil/0 seconds = wpasn now)
      end) 
     :Start(delayStart())
end

local function launchTexaco2()
   DCAF.Tanker:NewFromCallsign(CALLSIGN.Tanker.Texaco, 2 )
      -- >>SHELL TRACK<< next line establishes the tanker track at waypoint 2, with 102 degree heading for 40nm (change )
     :SetTrackFromWaypoint(2, 21, NauticalMiles(40)) -- track begins at WP2, tracks heading 102 degrees for 40nm at block 22, and 'true' = track is drawn on F10 map
     :OnFuelState(0.17, function(tanker)  -- will automatically spawn its replacement when fuel reaches 17%
         tanker:RTB()
         -- uncomment next line to always have a SHELL-2 tanker working the track
         -- tanker:SpawnReplacement(delay) -- spawns after <delay> seconds (nil/0 seconds = wpasn now)
      end) 
     :Start(delayStart())
end


----- FIRST WAVE OF TANKERS (Shell-1 and Texaco-1)
DCAF.Tanker:NewFromCallsign(CALLSIGN.Tanker.Shell, 1)
           -- >>SHELL TRACK<< next line establishes the tanker track at waypoint 2, with 102 degree heading for 40nm (change )
           :SetTrackFromWaypoint(2, 201, NauticalMiles(40), nil, true) -- track begins at WP2, tracks heading 201 degrees for 40nm at block 22, and 'true' = track is drawn on F10 map
           :OnFuelState(0.4, function() 
               -- >>SECOND WAVE<< uncomment next line to launch SHELL-2 once SHELL-1 reaches 40% fuel
               -- launchShell2() 
            end)
           :OnFuelState(0.17, function(tanker)  -- makes tanker RTB, to orifinal airbase, when when fuel reaches 17%
               tanker:RTB()
               -- uncomment next line to always have a SHELL-1 tanker working the track
               -- tanker:SpawnReplacement(delay)   -- spawns after <delay> seconds (nil/0 seconds = wpasn now)
            end) 
           :Start(delayStart())

DCAF.Tanker:NewFromCallsign(CALLSIGN.Tanker.Texaco, 1)
           -- >>SHELL TRACK<< next line establishes the tanker track at waypoint 2, with 102 degree heading for 40nm (change )
           :SetTrackFromWaypoint(2, 21, NauticalMiles(40), nil, true) -- track begins at WP2, tracks heading 21 degrees for 40nm at block 22, and 'true' = track is drawn on F10 map
           :OnFuelState(0.40, function() 
               -- >>SECOND WAVE<< uncomment next line to launch TEXACO-2 once TEXACO-1 reaches 40% fuel
               -- launchTexaco2() 
            end)
           :OnFuelState(0.17, function(tanker)  -- makes tanker RTB, to orifinal airbase, when when fuel reaches 17%
               tanker:RTB()
               -- uncomment next line to always have a SHELL-1 tanker working the track
               -- tanker:SpawnReplacement(delayStart())   -- spawns after <delay> seconds (nil/0 seconds = wpasn now)
            end) 
           :Start(delayStart())


-- comment this function if you don't want tankers to be automatically removed 10 mins after landing
MissionEvents:OnAircraftLanded(function(event) 

   if (IsTankerCallsign(event.IniGroup, CALLSIGN.Tanker.Shell, CALLSIGN.Tanker.Texaco)) then
      Delay(600, function() event.IniGroup:Destroy() end)
   end

end)


Trace("DCAF.AirForce.lua was loaded")