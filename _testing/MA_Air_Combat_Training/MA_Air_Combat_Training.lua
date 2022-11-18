
DCAF.Debug = true
DCAF.DebugToUI = true

DCAF.AirThreats
        -- adds a list of air threats to be supported in the mission (1st arg is display name; 2nd arg is name of late activated group in miz)
    :InitCategory(DCAF.AirThreatCategory:New("BVR")
        :InitAdversary("Su-33", "RED Su-33_bvr")
        :InitAdversary("Su-30", "RED Su-30_bvr")
        :InitAdversary("Su-27", "RED Su-27_bvr")
        :InitAdversary("Mig-29S", "RED Mig-29S_bvr")
        :InitAdversary("Mig-29A", "RED Mig-29A_bvr")
        :InitAdversary("Mig-23", "RED Mig-23_bvr")
        :InitAdversary("Mig-21", "RED Mig-21_bvr")
        :InitAdversary("Mirage 2000-5", "RED M2000-5_bvr")
        :InitAdversary("Mirage F1CE", "RED Mirage F1CE_bvr")
    )
    :InitCategory(DCAF.AirThreatCategory:New("BFM")
        :InitOptions(DCAF.AirThreatOptions:New():SetDistance(20))
        -- :InitAdversary("Su-33", "RED Su-33_bvr")
        -- :InitAdversary("Su-30", "RED Su-30_bvr")
        -- :InitAdversary("Su-27", "RED Su-27_bvr")
        :InitAdversary("Mig-29S", "RED Mig-29S_bvr")
        -- :InitAdversary("Mig-29A", "RED Mig-29A_bvr")
        -- :InitAdversary("Mig-23", "RED Mig-23_bvr")
        :InitAdversary("Mig-21", "RED Mig-21_bvr")
        :InitAdversary("Mirage 2000-5", "RED M2000-5_bvr")
        -- :InitAdversary("Mirage F1CE", "RED Mirage F1CE_bvr")
    )
    :WithGroupRandomization()  -- << -- randomizes air threats (accepts an #DCAF.AirThreats.Randomization as argument)
    :WithGroupMenus()     -- << -- builds menus for all groups, as players enter aircrafts, to manually spawn air threats
    :Start()


DCAF.Tanker:NewFromCallsign(CALLSIGN.Tanker.Shell, 1)
           -- >>SHELL TRACK<< next line establishes the tanker track at waypoint 2, with 102 degree heading for 40nm (change )
           :SetTrackFromWaypoint(2, 243, NauticalMiles(40), nil, true) -- track begins at WP2, tracks heading 201 degrees for 40nm at block 22, and 'true' = track is drawn on F10 map
           :OnFuelState(0.4, function() 
               -- >>SECOND WAVE<< uncomment next line to launch SHELL-2 once SHELL-1 reaches 40% fuel
               -- launchShell2() 
            end)
           :OnFuelState(0.17, function(tanker)  -- makes tanker RTB, to orifinal airbase, when when fuel reaches 17%
               tanker:RTB()
               -- uncomment next line to always have a SHELL-1 tanker working the track
               -- tanker:SpawnReplacement(delay)   -- spawns after <delay> seconds (nil/0 seconds = wpasn now)
            end) 
           :Start()

Trace("MA_Air_Combat_Training.lua loaded")