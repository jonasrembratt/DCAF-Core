
local Khasab = AIRBASE:FindByName(AIRBASE.PersianGulf.Khasab)
local ThunbIsl = AIRBASE:FindByName(AIRBASE.PersianGulf.Tunb_Island_AFB)
local Jiroft = AIRBASE:FindByName(AIRBASE.PersianGulf.Jiroft_Airport)

local Farp_London = AIRBASE:FindByName("FARP London-1")
local CVN_73 = AIRBASE:FindByName("CVN-73 George Wshington")
local LHA_1 = AIRBASE:FindByName("LHA-1 Tarawa-1-1")
local BlueAirforceCSARAirbases = {
    Farp_London,
    ThunbIsl,
    Khasab
}
local BlueNavyCSARAirbases = {
    CVN_73,
    LHA_1
}

-- Debug("nisse - BlueCSARAirbases: " .. DumpPretty(BlueAirforceCSARAirbases))

local Godu = DCAF.Location:NewNamed("Godu", COORDINATE:NewFromLLDD(26.95750000, 57.02083333))

-- local w = DCAF.Weather:Static()

DCAF.InitBullseyeName("DART")
DCAF.CSAR.InitSafeLocations(Coalition.Blue, Godu)
DCAF.CSAR.InitDistressedGroup(
    DCAF.CSAR.DistressedGroup:NewTemplate("CSAR Distressed Ground", true, DCAF.Smoke:New(2), DCAF.Flares:New(4)),
    DCAF.CSAR.DistressedGroup:NewTemplate("CSAR Distressed Water", true, DCAF.Smoke:New(2), DCAF.Flares:New(4)))
DCAF.CSAR.InitDistressBeacon("CSAR Distress Beacon")

-- rescue
DCAF.CSAR.InitRescueMissions(
    DCAF.CSAR.Mission:New("Blackhawk + 2 Apaches", 
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Blackhawk"):WithCapabilities(true, true),
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Apache", 2)):AddAirbases(BlueAirforceCSARAirbases),
    DCAF.CSAR.Mission:New("Chinook + 2 Apaches", 
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Chinook"):WithCapabilities(true, true),
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Apache", 2)):AddAirbases({ Khasab }),
    DCAF.CSAR.Mission:New("2 x Seahawks",
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Seahawk", 2):WithCapabilities(true, true)):AddAirbases({ CVN_73 }),
    DCAF.CSAR.Mission:New("Seahawk + 2 Cobras",
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Seahawk"):WithCapabilities(true, true),
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Cobra", 2)):AddAirbases({ LHA_1 }))--.InitCallsign("Roman")

DCAF.CSAR.InitCaptureMissions(
    DCAF.CSAR.Mission:New("Mi-8 + 2 Ka-50", 
        DCAF.CSAR.RescueGroup:New("RED Capture Heli-transport"):WithCapabilities(nil, true),
        DCAF.CSAR.RescueGroup:New("RED Capture Heli-escort", 2)):AddAirbases({ AIRBASE.PersianGulf.Jiroft_Airport }))

-- actively create CSAR story (for testing) ...
-- local csar = DCAF.CSAR:New(nil, "Downed Pilot", "CSAR-1"):StartRescue():StartCapture()
local options = DCAF.CSAR.Options:New():WithCodewords("JamesBond")--:WithTrigger(CSAR_Trigger.Ejection)
Debug("nisse - MIZ :: options: " .. DumpPrettyDeep(options))
DCAF.CSAR.MenuControlled(options, "Test CSAR") --, "_C2") -- NewOnPilotEjects(options)

DCAF.CSAR.RunScenarioInZone("TZ_CSAR", Coalition.Blue, options)

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

                     
