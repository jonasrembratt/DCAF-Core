
local GroomLake = AIRBASE:FindByName(AIRBASE.Nevada.Groom_Lake_AFB)
local Nellis = AIRBASE:FindByName(AIRBASE.Nevada.Nellis_AFB)
local Mesquite = AIRBASE:FindByName(AIRBASE.Nevada.Mesquite)

local w = DCAF.Weather:Static()

function DCAF.CSAR:OnCreated(csar)
    Debug("CSAR was created: " .. csar.Name)
end

local nellisAndGroomLake = { Nellis, GroomLake }
DCAf.CSAR:AddDistressBeacon("Downed Pilot-Beacon")
DCAF.CSAR:AddResource(DCAF.CSAR.RescueResource:New("BLUE Rescue Blackhawk", nellisAndGroomLake, 2))
DCAF.CSAR:AddResource(DCAF.CSAR.RescueResource:New("BLUE Rescue Apache", nellisAndGroomLake, 2))

DCAF.CSAR:AddResource(DCAF.CSAR.CaptureResource:New("RED Pursuing Heli-transport", Mesquite, 2))
DCAF.CSAR:AddResource(DCAF.CSAR.CaptureResource:New("RED Pursuing Heli-escort", Mesquite, 2))


-- actively create CSAR story (for testing) ...
local csar = DCAF.CSAR:New(nil, "Downed Pilot", "CSAR-1"):StartRescue():StartCapture()

-- GROUP IN DISTRESS...

local distressed = DCAF.CSAR.DistressedGroup:New(nil, "Downed Pilot", "CSAR-1")
                 :WithBeacon("Downed Pilot-Beacon"):MoveTo(Nellis, 6)
                 :Start()
local csar = distressed.CSAR

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
DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Blackhawk", distressed) --, Nellis)
                     :WithRTB(Nellis)
                     :Start(Knots(300))
DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Apache", distressed) --, Nellis)
                     :WithRTB(Nellis)
                     :WithCapabilities(false) -- cannot pickup unit (Apaches can't transport)
                     :Start(Knots(300))
DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Apache", distressed) --, Nellis)
                     :WithRTB(Nellis)
                     :WithCapabilities(false) -- cannot pickup unit (Apaches can't transport)
                     :Start(Knots(300))

                     
