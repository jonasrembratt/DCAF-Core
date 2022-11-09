DCAF.Debug = true

local TracePrefix = "DCAF.GBAD :: "             -- used for traces

DCAF.GBAD_DIFFICULTY = {
    Easy = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 0,
        Desc = "Easy (unprotected SAM sites)",
    },
    AAA = {
        ClassName = "GBAD_DIFFICULTY",
        Value = 1,
        Desc = "AAA (SAMs protected with AAA)",
        AAA = {
            Range = 800,
            Min = 1,
            Max = 3
        }
    },
    MANPADS = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 2,
        Desc = "MANPADS (SAMs protected with MANPADS)",
        MANPAD = {
            Range = 800,
            Min = 1,
            Max = 3
        }
    },
    SHORAD = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 3,
        Desc = "SHORAD (SAMs protected with SHORAD)",
        SHORAD = {
            Range = 4000,
            Min = 1,
            Max = 4
        }
    },
    Risky = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 4,
        Desc = "Risky (SAMs protected with MANPADS+AAA)",
        AAA = {
            Range = 800,
            Min = 1,
            Max = 3
        },
        MANPAD = {
            Range = 800,
            Min = 1,
            Max = 3
        }
    },
    Realistic = { 
        ClassName = "GBAD_DIFFICULTY",
        Value = 5,
        Desc = "Realistic (SAMs fully protected)",
        AAA = {
            Range = 800,
            Min = 0,
            Max = 3
        },
        MANPAD = {
            Range = 800,
            Min = 0,
            Max = 3
        },
        SHORAD = {
            Range = 4000,
            Min = 1,
            Max = 4
        }
    },   
}

SAM_AREA = {
    Name = nil,
    Zones = {
        -- list of #ZONE
    },
    SpawnedSamSites = { -- dictionary
        -- key = SAM type (eg. 'SA-5')
        -- value = { list of #SPAWNED_SAM_SITE }
    },
    SAM = {
        -- list of #string (template name for SAM groups)
    },
    AAA = {
        -- list of #SPAWN (for AAA groups)
    },
    MANPAD = {
        -- list of #SPAWN (for MANPAD groups)
    },
    SHORAD = {
        -- list of #SPAWN (for SHORAD groups)
    },
    UseSkynet = false,
    IADS = nil,
}

DCAF.GBAD = {
    Difficulty = DCAF.GBAD_DIFFICULTY.Realistic,
    Areas = {
        -- list of #SAM_AREA
    }
}

------------------------ SKYNET IADS ------------------------

local function teardownIADS(area)
    if not area.IADS then
        return end
    
    area.IADS:deactivate()
    area.IADS:removeRadioMenu()
    area.IADS = nil
    local message = "Skynet IADS was removed"
    MessageTo(nil, message)
    Trace(TracePrefix .. message)
end

local function buildIADS(area)
    if area.IADS then
        teardownIADS(area)
    end
    if not area.UseSkynet then
        return end

    area.IADS = SkynetIADS:create(area.Name .. " IADS")
    area.IADS:addSAMSitesByPrefix("RED SAM")
    area.IADS:addEarlyWarningRadarsByPrefix("RED EW")
    area.IADS:activate()
    area.IADS:addRadioMenu()
    local message = "Skynet IADS was constructed"
    MessageTo(nil, message)
    Trace(TracePrefix .. message)
end

local SAM_SITE_BASE = {
    Group = nil,
    AAA = {
        -- list of #GROUP (AAA groups)
    },
    MANPADS = {
        -- list of #GROUP (MANPAD groups)
    }
}

------------------------ SAM SITES ------------------------

function SAM_SITE_BASE:New(area, group, aaaGroups, manpadGroups)
    local samSite = DCAF.clone(SAM_SITE_BASE)
    samSite.Group = group
    samSite.AAA = aaaGroups or {}
    samSite.MANPAD = manpadGroups or {}
    if not group:IsActive() then
        group:Activate()
    end
    for _, aaa in ipairs(samSite.AAA) do
        if not aaa:IsActive() then
            aaa:Activate()
        end
    end
    for _, manpad in ipairs(samSite.MANPAD) do
        if not manpad:IsActive() then
            manpad:Activate()
        end
    end
    buildIADS(area)
    return samSite
end

function SAM_SITE_BASE:Destroy()
    if self.Group then
        self.Group:Destroy()
    end
    if isTable(self.AAA) then
        for _, aaa in ipairs(self.AAA) do
            aaa:Destroy()
        end
    end
    if isTable(self.MANPAD) then
        for _, manpad in ipairs(self.MANPAD) do
            manpad:Destroy()
        end
    end
end

local SAM_SITE = { -- inherits SAM_SITE_BASE
    Shorads = {
        -- list of #SAM_SITE
    }
}

function SAM_SITE:New(area, group, shoradSites, aaaGroups, manpadGroups)
    local samSite = DCAF.clone(SAM_SITE)
    samSite.Group = group
    samSite._base = SAM_SITE_BASE:New(area, group, aaaGroups, manpadGroups)
    samSite.Shorads = shoradSites or {}
    for _, shoradSite in ipairs(samSite.Shorads) do
        if not shoradSite.Group:IsActive() then
            shoradSite.Group:Activate()
        end
    end
    return samSite
end

function SAM_SITE:Destroy()
    self._base:Destroy()
    for _, shorad in ipairs(self.Shorads) do
        shorad:Destroy()
    end
end

local SPAWNED_SAM_SITE = {
    Spawner = nil,              -- #SPAWN (MOOSE object)
    SamSites = { 
                                -- list of #SAM_SITE
    }
}

function SPAWNED_SAM_SITE:New(template)
    local sss = DCAF.clone(SPAWNED_SAM_SITE)
    sss.Spawner = SPAWN:New(template)
    return sss
end

local TRAINING_SAM_SITES = { -- dictionary
    -- key = SAM type (eg. 'SA-5')
    -- value = { list of #SPAWNED_SAM_SITE }
}

local function destroySAMSites(area, template)

    local function destroyAllForTenplate(template)
        local s3 = area.SpawnedSamSites[template]
        if not s3 then
            return end
    
        local countRemoved = 0
        for _, samSite in ipairs(s3.SamSites) do
            samSite:Destroy()
            countRemoved = countRemoved+1
        end
        if countRemoved > 0 then
            local message = "Removed " .. Dump(countRemoved) .. " '" .. template .. "' SAM sites from '" .. area.Name .. "'"
            MessageTo(nil, message)
            Trace(TracePrefix .. message)
        end
    end

    if isAssignedString(template) then
        destroyAllForTenplate(template)
        return
    end

    for template, _ in pairs(area.SpawnedSamSites) do
        destroyAllForTenplate(template)
    end

end

local function spawnRandomAAA(area, samGroup)
    local aaaGroups = {}
    if #area.AAA == 0 then
        return aaaGroups end

    local aaa = DCAF.GBAD.Difficulty.AAA
    if not isTable(aaa) then
        return aaaGroups end

    local count = math.random(aaa.Min, aaa.Max)
    if count == 0 then
        return aaaGroups end
    
    local coord = samGroup:GetCoordinate()
    local range = DCAF.GBAD.Difficulty.AAA.Range
    for i = 1, count, 1 do
        local vec2 = coord:GetRandomVec2InRadius(range)
        local aaaCoord = COORDINATE:NewFromVec2(vec2)
        local countRetry = 6
        while not aaaCoord:IsSurfaceTypeLand() and countRetry > 0 do
            aaaCoord = COORDINATE:NewFromVec2(coord:GetRandomVec2InRadius(range))
            countRetry = countRetry-1
        end
        if countRetry == 0 then
            break end -- just protecting from locking the sim due to some unforseen use case where there's no land available (should never happen)

        local index = math.random(1, #area.AAA)
        local spawn = area.AAA[index]
        table.insert(aaaGroups, spawn:SpawnFromVec2(vec2))
    end
    return aaaGroups
end

local function spawnRandomMANPADS(area, samGroup)
    local manpadGroups = {}
    if #area.MANPAD == 0 then
        return manpadGroups end

    local manpad = DCAF.GBAD.Difficulty.MANPAD
    if not isTable(manpad) then
        return manpadGroups end

    local count = math.random(manpad.Min, manpad.Max)
    if count == 0 then
        return manpadGroups end
    
    local coord = samGroup:GetCoordinate()
    local range = DCAF.GBAD.Difficulty.MANPAD.Range
    for i = 1, count, 1 do
        local vec2 = coord:GetRandomVec2InRadius(range)
        local manpadCoord = COORDINATE:NewFromVec2(vec2)
        local countRetry = 6
        while not manpadCoord:IsSurfaceTypeLand() and countRetry > 0 do
            manpadCoord = COORDINATE:NewFromVec2(coord:GetRandomVec2InRadius(range))
            countRetry = countRetry-1
        end
        if countRetry == 0 then
            break end -- just protecting from locking the sim due to some unforseen use case where there's no land available (should never happen)

        local index = math.random(1, #area.MANPAD)
        local spawn = area.MANPAD[index]
        table.insert(manpadGroups, spawn:SpawnFromVec2(vec2))
    end
    return manpadGroups
end

local function spawnRandomSHORADs(area, samGroup)
    local shoradSites = {}
    if #area.SHORAD == 0 then
        return shoradSites end

    local shorad = DCAF.GBAD.Difficulty.SHORAD
    if not isTable(shorad) then
        return shoradSites end

    local count = math.random(shorad.Min, shorad.Max)
    if count == 0 then
        return shoradSites end
    
    local coord = samGroup:GetCoordinate()
    local range = DCAF.GBAD.Difficulty.SHORAD.Range
    for i = 1, count, 1 do
        local vec2 = coord:GetRandomVec2InRadius(range)
        local shoradCoord = COORDINATE:NewFromVec2(vec2)
        local countRetry = 6
        while not shoradCoord:IsSurfaceTypeLand() and countRetry > 0 do
            shoradCoord = COORDINATE:NewFromVec2(coord:GetRandomVec2InRadius(range))
            countRetry = countRetry-1
        end
        if countRetry == 0 then
            break end -- just protecting from locking the sim due to some unforseen use case where there's no land available (should never happen)

        local index = math.random(1, #area.MANPAD)
        local spawn = area.SHORAD[index]
        local shoradGroup = spawn:SpawnFromVec2(vec2)
        local aaaGroups = spawnRandomAAA(area, shoradGroup)
        local manpadGroups = spawnRandomMANPADS(area, shoradGroup)
        local shoradSite = SAM_SITE:New(area, shoradGroup, nil, aaaGroups, manpadGroups)
        table.insert(shoradSites, shoradSite)
    end
    return shoradSites
end

local function spawnSAMSite(area, template, vec2, destroyExisting, shorads)
    local s3 = area.SpawnedSamSites[template]
    if s3 then 
        if destroyExisting then
            for _, samSite in ipairs(s3.SamSites) do
                samSite:Destroy()
            end
        end
    else
        s3 = SPAWNED_SAM_SITE:New(template)
        area.SpawnedSamSites[template] = s3
    end
    local samGroup = s3.Spawner:SpawnFromVec2(vec2)
    local aaaGroups = spawnRandomAAA(area, samGroup)
    local manpadGroups = spawnRandomMANPADS(area, samGroup)
    local shorads = spawnRandomSHORADs(area, samGroup)
    table.insert(s3.SamSites, SAM_SITE:New(area, samGroup, shorads, aaaGroups, manpadGroups))
    local skynetStatus 
    if area.UseSkynet then
        skynetStatus = "ON"
    else
        skynetStatus = "OFF"
    end
    local message = "SAM site was spawned: " .. template .. " (Skynet is "..skynetStatus..")"
    MessageTo(nil, message)
    Trace(TracePrefix .. message)
    return samGroup
end

function SAM_AREA:Spawn(template, destroyExisting)
    if #self.Zones == 0 then
        return self end

    local zoneIndex = math.random(1, #self.Zones)
    local zone = self.Zones[zoneIndex]
    local vec2 = zone:GetRandomVec2()
    local coord = COORDINATE:NewFromVec2(vec2)
    -- only spawn on land and no closer to "scenery" than 400 meters (right now I don't know how to filter on different types of scenery -Jonas)
    while not coord:IsSurfaceTypeLand() or coord:FindClosestScenery(400) do
        vec2 = zone:GetRandomVec2()
        coord = COORDINATE:NewFromVec2(vec2)
    end

    return spawnSAMSite(self, template, vec2, destroyExisting)
    -- todo Add Shorads and AAA
end

function SAM_AREA:Destroy(template)
    if isAssignedString(template) then
        destroySAMSites(self, template)
        return
    end

    -- destroy all SAM sites ...
    for template, s3 in pairs(self.SpawnedSamSites) do
        destroySAMSites(self, template)
    end
end

------------------------- AAA, MANPAD and SHORAD templates ----------------------------

function DCAF.GBAD:WithDifficulty(difficulty)
    if not isTable(difficulty) or difficulty.ClassName ~= "GBAD_DIFFICULTY" then
        error("SAM_TRAINING:WithDifficulty :: unexpected difficulty value: " .. DumpPretty(difficulty)) end

    DCAF.GBAD.Difficulty = difficulty
    return DCAF.GBAD
end

function DCAF.GBAD:AddArea(sName, ...)
    if not isAssignedString(sName) then
        error("SAM_TRAINING:AddArea :: `sName` must be assigned string but was: " .. DumpPretty(sName)) end

    local area = DCAF.clone(SAM_AREA)
    area.Name = sName
    for i = 1, #arg, 1 do
        local zoneName = arg[i]
        if isAssignedString(zoneName) then
            local zone = ZONE:FindByName(zoneName)
            if zone then
                table.insert(area.Zones, zone)
            else
                error("SAM_TRAINING:AddArea :: zone could not be found: '" .. zoneName .. "'")
            end
        end
    end
    table.insert(DCAF.GBAD.Areas, area)
    return area
end

function SAM_AREA:WithSAM(displayName, template)
    self.SAM[displayName] = template
    return self
end

function SAM_AREA:WithAAA(template)
    table.insert(self.AAA, SPAWN:New(template))
    return self
end

function SAM_AREA:WithMANPAD(template)
    table.insert(self.MANPAD, SPAWN:New(template))
    return self
end

function SAM_AREA:WithSHORAD(template)
    table.insert(self.SHORAD, SPAWN:New(template))
    return self
end

--------------- F10 MENUS (great for training) ---------------

local _menuBuiltFor = nil

-- Settings ...
local SETTINGS_MENUS = {
    MainMenu = nil,
    SkyNetMenu = nil
}

function SETTINGS_MENUS:BuildCoalition(parentMenu, forCoalition)
    if not self.MainMenu then
        self.MainMenu = MENU_COALITION:New(forCoalition, "Settings", parentMenu)
    end

    self.MainMenu:RemoveSubMenus()

    -- Difficulty
    local difficultyMenu = MENU_COALITION:New(coalition.side.BLUE, DCAF.GBAD.Difficulty.Desc, self.MainMenu)
    for key, difficulty in pairs(DCAF.GBAD_DIFFICULTY) do
        MENU_COALITION_COMMAND:New(coalition.side.BLUE, difficulty.Desc, difficultyMenu, function() 
            DCAF.GBAD.Difficulty = difficulty
            self:BuildCoalition(forCoalition)
        end)
    end
end

function SETTINGS_MENUS:BuildGroup(parentMenu, group)
    if not self.MainMenu then
        self.MainMenu = MENU_GROUP:New(group, "Settings", parentMenu)
    end

    self.MainMenu:RemoveSubMenus()

    -- Difficulty
    local difficultyMenu = MENU_GROUP:New(group, DCAF.GBAD.Difficulty.Desc, self.MainMenu)
    for key, difficulty in pairs(DCAF.GBAD_DIFFICULTY) do
        MENU_GROUP_COMMAND:New(group, difficulty.Desc, difficultyMenu, function() 
            DCAF.GBAD.Difficulty = difficulty
            self:BuildGroup(group)
        end)
    end
end

local _area_buildSkynetCoalitionMenuFunc
local function buildSkynetCoalitionMenu(area, forCoalition, parentMenu)
    if area.UseSkynet then
        MENU_COALITION_COMMAND:New(forCoalition, "Deactivate Skynet", parentMenu, function()
            area.UseSkynet = false
            MessageTo(nil, "Skynet is turned OFF in '" .. area.Name .. "'")
            teardownIADS(area)
            _area_buildSkynetCoalitionMenuFunc(area, forCoalition, parentMenu)
        end)
    else
        MENU_COALITION_COMMAND:New(forCoalition, "Activate Skynet", parentMenu, function() 
            area.UseSkynet = true
            MessageTo(nil, "Skynet is activated in '" .. area.Name .. "' (all SAMs are added to IADS)")
            buildIADS(area) 
            _area_buildSkynetCoalitionMenuFunc(area, forCoalition, parentMenu)
        end)
    end
end
_area_buildSkynetCoalitionMenuFunc = buildSkynetCoalitionMenu

local _area_buildSkynetGroupMenuFunc
local function buildSkynetGroupMenu(area, forGroup, parentMenu)
    if area.UseSkynet then
        MENU_GROUP_COMMAND:New(forGroup, "Deactivate Skynet", parentMenu, function()
            area.UseSkynet = false
            MessageTo(forGroup, "Skynet is turned OFF in '" .. area.Name .. "'")
            teardownIADS(area)
            _area_buildSkynetGroupMenuFunc(area, forCoalition, parentMenu)
        end)
    else
        MENU_GROUP_COMMAND:New(forGroup, "Activate Skynet", parentMenu, function() 
            area.UseSkynet = true
            MessageTo(forGroup, "Skynet is activated in '" .. area.Name .. "' (all SAMs are added to IADS)")
            buildIADS(area) 
            _area_buildSkynetGroupMenuFunc(area, forCoalition, parentMenu)
        end)
    end
end
_area_buildSkynetGroupMenuFunc = buildSkynetGroupMenu

function DCAF.GBAD:BuildF10CoalitionMenus(parentMenu, forCoalition)
    if _menuBuiltFor then
        error("DCAF.GBAD:BuildF10CoalitionMenus :: menu was already built") end

    if forCoalition == nil then
        forCoalition = coalition.side.BLUE
    end
    if isAssignedString(parentMenu) then
        parentMenu = MENU_COALITION:New(forCoalition, parentMenu)
    end
    SETTINGS_MENUS:BuildCoalition(parentMenu, forCoalition)
    for i, area in ipairs(DCAF.GBAD.Areas) do
        local areaMenu = MENU_COALITION:New(forCoalition, area.Name, parentMenu)
        buildSkynetCoalitionMenu(area, forCoalition, areaMenu)
        MENU_COALITION_COMMAND:New(forCoalition, "Remove all", areaMenu, function() 
            area:Destroy()
        end)
        for displayName, template in pairs(area.SAM) do
            local samMenu = MENU_COALITION:New(forCoalition, displayName, areaMenu)
            MENU_COALITION_COMMAND:New(forCoalition, "Add", samMenu, function() 
                area:Spawn(template)
            end)
            MENU_COALITION_COMMAND:New(forCoalition, "Remove all", samMenu, function() 
                area:Destroy(template)
            end)
        end
    end
end

function DCAF.GBAD:BuildF10GroupMenus(parentMenu, group)
    if _menuBuiltFor then
        error("DCAF.GBAD:BuildF10CoalitionMenus :: menu was already built") end

    local forGroup = getGroup(group)
    if forGroup == nil then
        error("DCAF.GBAD:BuildF10GroupMenus :: cannot resolve group from: " .. DumpPretty(group)) end
    
    if isAssignedString(parentMenu) then
        parentMenu = MENU_GROUP:New(forGroup, parentMenu)
    end
    SETTINGS_MENUS:BuildCoalition(parentMenu)
    for i, area in ipairs(DCAF.GBAD.Areas) do
        local areaMenu = MENU_GROUP:New(forGroup, area.Name, parentMenu)
        buildSkynetGroupMenu(area, forGroup, areaMenu)
        MENU_GROUP_COMMAND:New(forGroup, "Remove all", areaMenu, function() 
            area:Destroy()
        end)
        for displayName, template in pairs(area.SAM) do
            local samMenu = MENU_GROUP:New(forGroup, displayName, areaMenu)
            MENU_GROUP_COMMAND:New(forGroup, "Add", samMenu, function() 
                area:Spawn(template)
            end)
            MENU_GROUP_COMMAND:New(forGroup, "Remove all", samMenu, function() 
                area:Destroy(template)
            end)
        end
    end
end