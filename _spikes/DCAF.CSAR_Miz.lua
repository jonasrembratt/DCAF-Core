
local GroomLake = AIRBASE:FindByName(AIRBASE.Nevada.Groom_Lake_AFB)
local Nellis = AIRBASE:FindByName(AIRBASE.Nevada.Nellis_AFB)
local Mesquite = AIRBASE:FindByName(AIRBASE.Nevada.Mesquite)

local w = DCAF.Weather:Static()

local pursued = DCAF.CSAR.DistressedGroup:New("CSAR-1", nil, "Downed Pilot", "CSAR-1")
                 :WithBeacon("Downed Pilot-Beacon"):MoveTo(Nellis, 6)
                 :Start()

DCAF.CSAR.HunterGroup:New("Hunter 1", "RED Pursuing Helicopter", pursued) --, Mesquite)
                     :WithRTB(Mesquite)
                     :Start(Knots(200))
DCAF.CSAR.HunterGroup:New("Hunter 2", "RED Pursuing Helicopter", pursued) --, Mesquite)
                     :WithRTB(Mesquite)
                     :Start(Knots(200))
DCAF.CSAR.HunterGroup:New("Hunter 3", "RED Pursuing Helicopter", pursued) --, Mesquite)
                     :WithRTB(Mesquite)
                     :Start(Knots(200))                       