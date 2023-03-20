
local GroomLake = AIRBASE:FindByName(AIRBASE.Nevada.Groom_Lake_AFB)
local Nellis = AIRBASE:FindByName(AIRBASE.Nevada.Nellis_AFB)
local Mesquite = AIRBASE:FindByName(AIRBASE.Nevada.Mesquite)

local w = DCAF.Weather:Static()

-- GROUP IN DISTRESS...
local distressed = DCAF.CSAR.DistressedGroup:New("CSAR-1", nil, "Downed Pilot", "CSAR-1")
                 :WithBeacon("Downed Pilot-Beacon"):MoveTo(Nellis, 6)
                 :Start()

-- HUNTERS...
-- DCAF.CSAR.HunterGroup:New("Hunter 1", "RED Pursuing Heli-transport", distressed) --, Mesquite)
--                      :WithRTB(Mesquite)
--                      :Start(Knots(200))
-- DCAF.CSAR.HunterGroup:New("Hunter 2", "RED Pursuing Heli-transport", distressed) --, Mesquite)
--                      :WithRTB(Mesquite)
--                      :Start(Knots(200))
-- DCAF.CSAR.HunterGroup:New("Hunter 3", "RED Pursuing Heli-escort", distressed) --, Mesquite)
--                      :WithCapabilities(false) -- cannot pickup unit (KA-50s can't transport)
--                      :WithRTB(Mesquite)
--                      :Start(Knots(250))

-- RESCUERS...                    
DCAF.CSAR.RescueGroup:New("Rescue 1", "BLUE Rescue Blackhawk", distressed) --, Nellis)
                     :WithRTB(Nellis)
                     :Start(Knots(300))
DCAF.CSAR.RescueGroup:New("Rescue 2", "BLUE Rescue Apache", distressed) --, Nellis)
                     :WithRTB(Nellis)
                     :WithCapabilities(false) -- cannot pickup unit (Apaches can't transport)
                     :Start(Knots(300))
DCAF.CSAR.RescueGroup:New("Rescue 3", "BLUE Rescue Apache", distressed) --, Nellis)
                     :WithRTB(Nellis)
                     :WithCapabilities(false) -- cannot pickup unit (Apaches can't transport)
                     :Start(Knots(300))

                     
