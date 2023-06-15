
local Khasab = AIRBASE:FindByName(AIRBASE.PersianGulf.Khasab)
local ThunbIsl = AIRBASE:FindByName(AIRBASE.PersianGulf.Tunb_Island_AFB)
local Jiroft = AIRBASE:FindByName(AIRBASE.PersianGulf.Jiroft_Airport)

local Farp_London = AIRBASE:FindByName("FARP London-1")
local Farp_Tehran = AIRBASE:FindByName("FARP Tehran-1")
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
    DCAF.CSAR.DistressedGroup:NewTemplate("CSAR Distressed Ground", true, DCAF.Smoke:New(2), DCAF.Flares:New(4), .3),
    DCAF.CSAR.DistressedGroup:NewTemplate("CSAR Distressed Water", true, DCAF.Smoke:New(2), DCAF.Flares:New(4)), .3)
DCAF.CSAR.InitDistressBeacon("CSAR Distress Beacon")

-- rescue
DCAF.CSAR.InitRescueMissions(Coalition.Blue,
    DCAF.CSAR.Mission:New("Blackhawk + 2 Apaches", 
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Blackhawk"):WithCapabilities(true, true, true, true),
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Apache", 2)):AddAirbases(BlueAirforceCSARAirbases),
    DCAF.CSAR.Mission:New("Chinook + 2 Apaches", 
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Chinook"):WithCapabilities(true, true),
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Apache", 2)):AddAirbases({ Khasab }),
    DCAF.CSAR.Mission:New("2 x Seahawks",
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Seahawk", 2):WithCapabilities(true, true)):AddAirbases({ CVN_73 }),
    DCAF.CSAR.Mission:New("Single Seahawk",
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Seahawk"):WithCapabilities(true, true, true, true)):AddAirbases({ LHA_1 }),
    DCAF.CSAR.Mission:New("Seahawk + 2 Cobras",
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Seahawk", 2):WithCapabilities(true, true, true, true),
        DCAF.CSAR.RescueGroup:New("BLUE Rescue Cobra", 2)):AddAirbases({ LHA_1 }))

local between_3_and_10_minutes = VariableValue:NewRange(Minutes(3), Minutes(10))
DCAF.CSAR.InitDelayedCaptureMissions(Coalition.Red, between_3_and_10_minutes,
    DCAF.CSAR.Mission:New("Mi-8 + 2 Ka-50", 
        DCAF.CSAR.RescueGroup:New("RED Capture Heli-transport"):WithCapabilities(nil, true),
        DCAF.CSAR.RescueGroup:New("RED Capture Heli-escort", 2)):AddAirbases({ AIRBASE.PersianGulf.Jiroft_Airport, Farp_Tehran }))
        
local c2_group -- = "_C2"

DCAF.CSAR.OnStarted(function(csar) 
    MessageTo(c2_group, "CSAR_PilotDown.ogg")
    MessageTo(c2_group, "ALERT! Personnel in distress, codeword is '" .. csar.Name .. "'")
end)

DCAF.CSAR.OnRescueUnitTargeted(function(event) 
    MessageTo(c2_group, "OnRescueUnitTargeted :: event\n" .. DumpPretty(event))
end)

DCAF.CSAR.OnDistressedGroupLocated(function(event) 
    MessageTo(c2_group, "OnDistressedGroupLocated :: event\n" .. DumpPretty(event))
end)

DCAF.CSAR.OnDistressedGroupExtracted(function(event) 
    MessageTo(c2_group, "OnDistressedGroupExtracted :: event\n" .. DumpPretty(event))
end)

DCAF.CSAR.OnRescueUnitHit(function(event) 
    MessageTo(c2_group, "OnRescueUnitHit :: event\n" .. DumpPretty(event))
end)

DCAF.CSAR.OnRescueUnitDestroyed(function(event) 
    MessageTo(c2_group, "OnRescueUnitDestroyed :: event\n" .. DumpPretty(event))
end)

DCAF.CSAR.OnRecoveryUnitDestroyed(function(event) 
    MessageTo(c2_group, "OnRecoveryUnitDestroyed :: event\n" .. DumpPretty(event))
end)

DCAF.CSAR.OnRecoveryUnitSafe(function(event) 
    MessageTo(c2_group, "SAFELY LANDED :: event: " .. DumpPretty(event))
end)

-- DCAF.CSAR.OnDistressedGroupAttractAttention(function(event) 
--     MessageTo(nil, "OnDistressedGroupAttractAttention :: event\n" .. DumpPretty(event))
-- end)

DCAF.CSAR.MapControlled("Test CSAR") --, "_C2", options)
-- DCAF.CSAR.MenuControlled("Test CSAR", "_C2", options)
DCAF.CSAR.RunInZone("TZ_CSAR", Coalition.Blue, options)
DCAF.CSAR.RunInZone("TZ_CSAR-2", Coalition.Blue, options)
