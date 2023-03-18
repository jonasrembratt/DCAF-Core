
local GroomLake = AIRBASE:FindByName(AIRBASE.Nevada.Groom_Lake_AFB)
local Nellis = AIRBASE:FindByName(AIRBASE.Nevada.Nellis_AFB)

DCAF.CSAR:New("CSAR-1", "Downed Pilot", "CSAR-1"):WithBeacon("Downed Pilot-Beacon"):MoveTo(Nellis, 100):Start()