
local Khasab = AIRBASE:FindByName(AIRBASE.PersianGulf.Khasab)
local ThunbIsl = AIRBASE:FindByName(AIRBASE.PersianGulf.ThunbIslis)
local Jiroft = AIRBASE:FindByName(AIRBASE.PersianGulf.Jiroft_Airport)

local Seerik_harbor = DCAF.Location:NewNamed("Godu", COORDINATE:NewFromLLDD(26.95750000, 57.02083333))

local w = DCAF.Weather:Static()

DCAF.CSAR:InitSafeLocations(Coalition.Blue, Seerik_harbor)
DCAF.CSAR:InitDistressedGroup(
    DCAF.CSAR.DistressedGroup:NewTemplate("CSAR Distressed Ground", true, DCAF.Smoke:New(2), DCAF.Flares:New(4)),
    DCAF.CSAR.DistressedGroup:NewTemplate("CSAR Distressed Water", true, DCAF.Smoke:New(2), DCAF.Flares:New(4)))
DCAF.CSAR:InitDistressBeacon("CSAR Distress Beacon")

-- rescue
DCAF.CSAR:AddResource(DCAF.CSAR.RescueResource:New("BLUE Rescue Blackhawk", { ThunbIsl, Khasab }, 2))
DCAF.CSAR:AddResource(DCAF.CSAR.RescueResource:New("BLUE Rescue Apache", { ThunbIsl, Khasab }, 2))

-- capturew
DCAF.CSAR:AddResource(DCAF.CSAR.CaptureResource:New("RED Pursuing Heli-transport", Jiroft, 2))
DCAF.CSAR:AddResource(DCAF.CSAR.CaptureResource:New("RED Pursuing Heli-escort", Jiroft, 2))


-- actively create CSAR story (for testing) ...
-- local csar = DCAF.CSAR:New(nil, "Downed Pilot", "CSAR-1"):StartRescue():StartCapture()
local options = DCAF.CSAR.Options:New():WithCodewords("JamesBond")
Debug("nisse - MIZ :: options: " .. DumpPrettyDeep(options))
DCAF.CSAR:NewOnPilotEjects(options)

-- GROUP IN DISTRESS...

-- local distressed = DCAF.CSAR.DistressedGroup:New(nil, "Downed Pilot", "CSAR-1")
--                  :WithBeacon("Downed Pilot-Beacon"):MoveTo(Nellis, 6)
--                  :Start()
-- local csar = distressed.CSAR

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
-- DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Blackhawk", distressed) --, Nellis)
--                      :WithRTB(Nellis)
--                      :Start(Knots(300))
-- DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Apache", distressed) --, Nellis)
--                      :WithRTB(Nellis)
--                      :WithCapabilities(false) -- cannot pickup unit (Apaches can't transport)
--                      :Start(Knots(300))
-- DCAF.CSAR.RescueGroup:New(csar, "BLUE Rescue Apache", distressed) --, Nellis)
--                      :WithRTB(Nellis)
--                      :WithCapabilities(false) -- cannot pickup unit (Apaches can't transport)
--                      :Start(Knots(300))

                     
