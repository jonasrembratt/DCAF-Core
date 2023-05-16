-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--                                                            TANKERS
-- ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DCAF.TankerTrack.DefaultBehavior = DCAF.AirServiceBehavior:New()
                                                          :RTB(AIRBASE.Caucasus.Batumi)
                                                          :WithAvailability(DCAF.AirServiceAvailability.Always)
                                                          :NotifyAssignment(Coalition.Blue)

local Batumi = AIRBASE:FindByName(AIRBASE.Caucasus.Batumi)
Batumi:SetActiveRunwayTakeoff("31")
local Kobuleti = AIRBASE:FindByName(AIRBASE.Caucasus.Kobuleti)
Batumi:SetActiveRunwayTakeoff("25")

-- SHELL tankers available only from Batumi...
local SHELL = CALLSIGN.Tanker.Shell
DCAF.AvailableTanker:New(SHELL, 1):FromAirbase(Batumi)
DCAF.AvailableTanker:New(SHELL, 2):FromAirbase(Batumi)
DCAF.AvailableTanker:New(SHELL, 3):FromAirbase(Batumi)

-- SHELL tankers available from Batumi and Kobuleti...
local TEXACO = CALLSIGN.Tanker.Texaco
DCAF.AvailableTanker:New(TEXACO, 1):FromAirbases({ Batumi, Kobuleti })
DCAF.AvailableTanker:New(TEXACO, 2):FromAirbases({ Batumi, Kobuleti })
DCAF.AvailableTanker:New(TEXACO, 3):FromAirbases({ Batumi, Kobuleti })

-- Sets up two initial tanker tracks: "OAK" and "PINE"...
DCAF.TankerTrack:New("OAK", 
                     Coalition.Blue, 
                     280, 
                     COORDINATE:NewFromLLDD(41.90805556, 41.00194444), 
                     NauticalMiles(50))
                     :Draw()
DCAF.TankerTrack:New("PINE", 
                     Coalition.Blue, 
                     280, 
                     COORDINATE:NewFromLLDD(42.73472222, 40.91500000))
                     :Draw()

----- MENUS ----- 
DCAF.TankerTracks:BuildMenus("AAR", Coalition.Blue)
                 :AllowDynamicTracks(true)

---- DONE ----
Trace("CCS_Tankers.lua was loaded")
