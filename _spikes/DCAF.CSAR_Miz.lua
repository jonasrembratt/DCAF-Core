
local GroomLake = AIRBASE:FindByName(AIRBASE.Nevada.Groom_Lake_AFB)
local Nellis = AIRBASE:FindByName(AIRBASE.Nevada.Nellis_AFB)
local Mesquite = AIRBASE:FindByName(AIRBASE.Nevada.Mesquite)

local pursued = DCAF.CSAR.PursuedGroup:New("CSAR-1", "Downed Pilot", "CSAR-1")
                 :WithBeacon("Downed Pilot-Beacon"):MoveTo(Nellis, 6)
                 :Start()

DCAF.CSAR.PursuingGroup:New("CSAR-1", "RED Pursuing Helicopter", pursued) -- , Mesquite)
                       :WithRTB(Mesquite)
                       :Start(Knots(200))