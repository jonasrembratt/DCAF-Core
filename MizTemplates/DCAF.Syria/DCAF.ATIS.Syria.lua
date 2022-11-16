-- DCAF AIRAC 2022-1

-- local SRS_PATH = [[D:\Program Files\DCS-SimpleRadio-Standalone]]

--== TURKEY ==--

-- Incirlik // LTAG
ATIS:New(AIRBASE.Syria.Incirlik, 305)
        :SetRadioRelayUnitName("Radio Relay "..AIRBASE.Syria.Incirlik)
        :SetImperialUnits()
        :SetTACAN(21)
        :SetTowerFrequencies({360.2, 129.4})
        :AddILS(109.30, "5")
        :AddILS(111.70, "23")
        -- :SetSRS(SRS_PATH, "male", "en-US")
        :Start()

-- Gaziantep Intl // LTAJ
ATIS:New(AIRBASE.Syria.Gaziantep, 119.275)
        :SetRadioRelayUnitName("Radio Relay "..AIRBASE.Syria.Gaziantep)
        :SetImperialUnits()
        :SetVOR(116.7)
        :SetTowerFrequencies({250.9, 121.1})
        :AddILS(108.7, "5")
        --:SetSRS(SRS_PATH)
        :Start()


--== BRITISH OVERSEAS TERRITORIES ==--

-- RAF Akrotiri // LCRA
ATIS:New(AIRBASE.Syria.Akrotiri, 125)
        :SetRadioRelayUnitName("Radio Relay "..AIRBASE.Syria.Akrotiri)
        :SetImperialUnits()
        :SetTACAN(107)
        :SetTowerFrequencies({339.85, 130.075})
        :AddILS(109.7, "28")
        -- :SetSRS(SRS_PATH)
        :Start()


--== REPUBLIC OF CYPRUS ==--

-- Paphos Intl. Airport // LCPH
ATIS:New(AIRBASE.Syria.Paphos, 127.325, radio.modulation.AM)
        :SetRadioRelayUnitName("Radio Relay "..AIRBASE.Syria.Paphos)
        :SetImperialUnits()
        :SetTACAN(79)
        :SetTowerFrequencies({250.25, 127.8})
        :AddILS(108.9, "29")
        -- :SetSRS(SRS_PATH, "male", "en-US")
        :Start()

--== ISRAEL ==--

-- Ramat David AB // LLRD
ATIS:New(AIRBASE.Syria.Ramat_David, 123)
        :SetRadioRelayUnitName("Radio Relay "..AIRBASE.Syria.Ramat_David)
        :SetImperialUnits()
        :SetTACAN(84)
        :SetTowerFrequencies({250.95})
        :AddILS(111.10, "32")
        -- :SetSRS(SRS_PATH)
        :Start()
