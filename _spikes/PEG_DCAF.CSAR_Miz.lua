
local Khasab = AIRBASE:FindByName(AIRBASE.PersianGulf.Khasab)
local ThunbIsl = AIRBASE:FindByName(AIRBASE.PersianGulf.Tunb_Island_AFB)
local Jiroft = AIRBASE:FindByName(AIRBASE.PersianGulf.Jiroft_Airport)

Debug("nisse - Jiroft: " .. DumpPretty(Jiroft))

local FarpLondon = AIRBASE:FindByName("FARP London-1")
local BlueCSARAirbases = {
    FarpLondon,
    ThunbIsl,
    Khasab
}

Debug("nisse - BlueCSARAirbases: " .. DumpPretty(BlueCSARAirbases))

local Godu = DCAF.Location:NewNamed("Godu", COORDINATE:NewFromLLDD(26.95750000, 57.02083333))

local w = DCAF.Weather:Static()

DCAF.CSAR.InitSafeLocations(Coalition.Blue, Godu)
DCAF.CSAR.InitDistressedGroup(
    DCAF.CSAR.DistressedGroup:NewTemplate("CSAR Distressed Ground", true, DCAF.Smoke:New(2), DCAF.Flares:New(4)),
    DCAF.CSAR.DistressedGroup:NewTemplate("CSAR Distressed Water", true, DCAF.Smoke:New(2), DCAF.Flares:New(4)))
DCAF.CSAR.InitDistressBeacon("CSAR Distress Beacon")

-- rescue
DCAF.CSAR.InitRescueMissions(
    DCAF.CSAR.Mission:New("Blackhawk + 2 Apaches", 
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Blackhawk"),
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Apache", 2)):AddAirbases(BlueCSARAirbases))

DCAF.CSAR.InitCaptureMissions(
    DCAF.CSAR.Mission:New("Mi-8 + 2 Ka-50", 
        DCAF.CSAR.RescueGroup:New("RED Hunter Heli-transport"),
        DCAF.CSAR.RescueGroup:New("RED Hunter Heli-escort", 2)):AddAirbases({ AIRBASE.PersianGulf.Jiroft_Airport }))

-- actively create CSAR story (for testing) ...
-- local csar = DCAF.CSAR:New(nil, "Downed Pilot", "CSAR-1"):StartRescue():StartCapture()
local options = DCAF.CSAR.Options:New():WithCodewords("JamesBond")--:WithTrigger(CSAR_Trigger.Ejection)
Debug("nisse - MIZ :: options: " .. DumpPrettyDeep(options))
DCAF.CSAR.MenuControlled(options, "Test CSAR") --, "_C2") -- NewOnPilotEjects(options)

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

                     
