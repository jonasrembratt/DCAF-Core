-- DCAF AIRAC 2022-1
--[[
for SRS testing:
C:\Program Files\DCS-SimpleRadio-Standalone>.\\DCS-SR-ExternalAudio.exe -t "Automated Traffic Information Service, Charlie. Hello World, " -f 305 -m AM -c 2
]]

DCAF.AIRAC = {
    SRS_PATH = [[C:\Program Files\DCS-SimpleRadio-Standalone]],
    SRS_PORT = nil -- default = 5002
}

ATIS.Gender = {
    Male = "male",
    Female = "female",
    Random = "random",
}

ATIS.Culture = {
    GB = "en-GB",
    US = "en-US",
    Random = "random",
}

function DCAF.AIRAC:ConfigureSRS(path, port)
    if isAssignedString(path) then
        DCAF.AIRAC.SRS_PATH = path
    end
    if isNumber(port) then
        DCAF.AIRAC.SRS_PORT = port
    end
end

function ATIS.Gender:IsValid(value)
    if value == nil then return true end
    for k, v in pairs(ATIS.Gender) do
        if value == v then
            return true
        end
    end
end

function ATIS.Culture:IsValid(value)
    if value == nil then return true end
    for k, v in pairs(ATIS.Culture) do
        if value == v then
            return true
        end
    end
end

AIRAC_Aerodrome = {
    ClassName = "AIRAC_Aerodrome",
    Id = nil,                   -- eg. AIRBASE.Syria.Incirlik
    ICAO = nil,                 -- #string; ICAO code; eg. "LTAG"
    ATIS = nil,                 -- #number; eg. 305 (the ATIS frequency)
    TACAN = nil,                -- #number; eg. 27 (for 27X)
    VOR = nil,                  -- #number; eg. 116.7 (the VOR frequency)
    TWR = { -- list
        -- item = #number (TWR frequency)
    },
    GND = { -- list
    -- item = #number (GND frequency)
    },
    DEP_APP = { -- list
    -- item = #number (DEP/APP frequency)
    },
    ILS = { -- dictionary
        -- key = runway (eg. 27)
        -- value = #number; frequency; eg 108.7
    }
}

function AIRAC_Aerodrome:New(id, icao)
  if not isAssignedString(id) then
      error("AIRAC_Aerodrome:New :: id must be assigned string, but was: " .. DumpPretty(id)) end

  local aerodrome = DCAF.clone(AIRAC_Aerodrome)
  aerodrome.Id = id
  if isAssignedString(icao) then
      aerodrome.ICAO = icao
  end
  return aerodrome
end

function AIRAC_Aerodrome:WithATIS(freq)
    if not isNumber(freq) then
        error("AIRAC_Aerodrome:WithATIS :: `atis` must be a number but was: " .. DumpPretty(freq)) end

    self.ATIS = freq
    return self
end    
    
function AIRAC_Aerodrome:WithTWR(freq)
    if isNumber(freq) then
        freq = { freq }
    end
    if not isTable(freq) then
        error("AIRAC_Aerodrome:WithTWR :: `twr` must be a  number or table with numbers, but was: " .. DumpPretty(freq)) end

    for i, frequency in ipairs(freq) do
        if not isNumber(frequency) then
            error("AIRAC_Aerodrome:WithTWR :: frequency #" .. Dump(i) .. " must be a  number or table with numbers, but was: " .. DumpPretty(frequency)) end
    end

    self.TWR = freq
    return self
end

function AIRAC_Aerodrome:WithGND(freq)
  if isNumber(freq) then
    freq = { freq }
  end
  if not isTable(freq) then
      error("AIRAC_Aerodrome:WithGND :: `gnd` must be a  number or table with numbers, but was: " .. DumpPretty(freq)) end

  for i, frequency in ipairs(freq) do
      if not isNumber(frequency) then
          error("AIRAC_Aerodrome:WithGND :: frequency #" .. Dump(i) .. " must be a  number or table with numbers, but was: " .. DumpPretty(frequency)) end
  end

  self.GND = freq
  return self
end

function AIRAC_Aerodrome:WithDEP(freq)
  if isNumber(freq) then
    freq = { freq }
  end
  if not isTable(freq) then
      error("AIRAC_Aerodrome:WithDepartureAndApproach :: `gnd` must be a  number or table with numbers, but was: " .. DumpPretty(freq)) end

  for i, frequency in ipairs(freq) do
      if not isNumber(frequency) then
          error("AIRAC_Aerodrome:WithDepartureAndApproach :: frequency #" .. Dump(i) .. " must be a  number or table with numbers, but was: " .. DumpPretty(frequency)) end
  end

  self.DEP_APP = freq
  return self
end

function AIRAC_Aerodrome:WithTACAN(tacan)
    if not isNumber(tacan) then
        error("AIRAC_Aerodrome:WithTACAN :: `tacan` must be a number but was: " .. DumpPretty(tacan)) end

    self.TACAN = tacan
    return self
end

function AIRAC_Aerodrome:WithILS(ils)
    if not isTable(ils) then
        error("AIRAC_Aerodrome:WithILS :: `ils` must be a  number or table with numbers, but was: " .. DumpPretty(ils)) end

    for rwy, frequency in pairs(ils) do
        if not isAssignedString(rwy) then
            error("AIRAC_Aerodrome:WithILS :: runway must be a assigned string but was: " .. DumpPretty(rwy)) end

        -- local rwyNumber = tonumber(rwy)
        -- if not rwyNumber then
        --     error("AIRAC_Aerodrome:WithILS :: runway string must be convertible to number but was: " .. DumpPretty(rwy)) end

        if not isNumber(frequency) then
            error("AIRAC_Aerodrome:WithILS :: frequency for rwy " .. rwy .. " must be a number but was: " .. DumpPretty(frequency)) end
    end

    self.ILS = ils
    return self
end

function AIRAC_Aerodrome:WithVOR(vor)
    if not isNumber(vor) then
        error("AIRAC_Aerodrome:WithVOR :: `vor` must be a number but was: " .. DumpPretty(vor)) end

    self.VOR = vor
    return self
end

function AIRAC_Aerodrome:WithVoice(culture, gender)
    if not ATIS.Culture:IsValid(culture) then
        error("AIRAC_Aerodrome:WithVoice :: invalid `culture` value: " .. DumpPretty(culture)) end

    if not ATIS.Gender:IsValid(gender) then
        error("AIRAC_Aerodrome:WithVoice :: invalid `gender` value: " .. DumpPretty(gender)) end

    self.CultureATIS = culture
    self.GenderATIS = gender
    return self
end

function AIRAC_Aerodrome:StartATIS(sCulture, sGender, nFrequency)
    local icao
    if isAssignedString(self.ICAO) then
        icao = " (" .. self.ICAO .. ")"
    end

    local function getCulture()
        if not isAssignedString(sCulture) then
            sCulture = self.CultureATIS
        end
        if sCulture ~= ATIS.Culture.Random and ATIS.Culture:IsValid(sCulture) then
            return sCulture
        end
        local key = dictRandomKey(ATIS.Culture)
        while key == ATIS.Culture.Random or isFunction(ATIS.Culture[key]) do
            key = dictRandomKey(ATIS.Culture)
        end
        return ATIS.Culture[key]
    end

    local function getGender()
        if not isAssignedString(sGender) then
            sGender = self.GenderATIS
        end
        if sGender ~= ATIS.Gender.Random and ATIS.Gender:IsValid(sGender)  then
            return sGender
        end
        local key = dictRandomKey(ATIS.Gender)
        while key == ATIS.Gender.Random or isFunction(ATIS.Gender[key]) do
          key = dictRandomKey(ATIS.Gender)
        end
        return ATIS.Gender[key]
    end

    local function getATISFrequency()
        if isNumber(nFrequency) then
            return nFrequency 
        end
        return self.ATIS
    end

    local function getGroundFrequencies(text)
        if #self.GND == 0 then
            return text end

        text = text or ""
        text = text .. ". ground frequency "
        for _, frequency in ipairs(self.GND) do
            text = text .. tostring(frequency) .. " "
        end
        return text
    end

    local function getDepartureAndApproachFrequencies(text)
        if #self.DEP_APP == 0 then
            return text end

        text = text or ""
        text = text .. ". departure frequency "
        for _, frequency in ipairs(self.DEP_APP) do
            text = text .. tostring(frequency) .. " "
        end
        return text
    end

    local gender = getGender()
    local culture = getCulture()

    Debug("Starts ATIS for aerodrome '" .. self.Id .. "'" .. icao .. "; AIRAC (v " .. DCAF.AIRAC.Version .. ") @" .. Dump(self.ATIS) .. "; gender=" .. Dump(gender) .. ", culture=" .. Dump(culture))

    local atisFrequency = getATISFrequency()
    local atis = ATIS:New(self.Id, atisFrequency)
        :SetSRS(DCAF.AIRAC.SRS_PATH, gender, culture, nil, DCAF.AIRAC.SRS_PORT)
        :SetImperialUnits()
    if isTable(self.TWR) then
        atis:SetTowerFrequencies(self.TWR)
    end
    local extra = getGroundFrequencies()
    extra = getDepartureAndApproachFrequencies(extra)
    if extra and string.len(extra) > 0 then
        atis:SetAdditionalInformation(extra)
    end
    if isTable(self.ILS) then
        for runway, frequency in pairs(self.ILS) do
            atis:AddILS(frequency, runway)
        end
    end
    if isNumber(self.TACAN) then
        atis:SetTACAN(self.TACAN)
    end
    if isNumber(self.VOR) then
        atis:SetVOR(self.VOR)
    end
    atis:Start()
end

function DCAF.AIRAC:StartAerodromeATIS(aerodromeName, SRSPath, SRSPort)
    if not isAssignedString(aerodromeName) then
        error("DCAF.AIRAC:StartAerodromeATIS :: `aerodromeName` must be assigned string but was: " .. DumpPretty(aerodromeName)) end

    local aerodrome = DCAF.AIRAC.Aerodromes[aerodromeName]
    if not aerodrome then
        Warning("DCAF.AIRAC:StartAerodromeATIS :: aerodrome '" .. aerodromeName .. "' does not have ATIS (DCAF AIRAC " .. DCAF.AIRAC.Version .. ")")
        error("DCAF.AIRAC:StartAerodromeATIS ::  `aerodromeName` must be assigned string but was: " .. DumpPretty(aerodromeName)) end

    DCAF.AIRAC:ConfigureSRS(SRSPath, SRSPort)

end

----------------------------------------------------------------------------------------------

Trace("DCAF.AIRAC.lua was loaded")