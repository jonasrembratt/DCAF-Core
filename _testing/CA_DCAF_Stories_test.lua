DCAF.Trace = true
DCAF.Debug = true
DCAF.DebugToUI = true

local storyName = "airbase hopping"

local story = Story:New(storyName)
    :WithDescription("Test story in three steps. Step 2 may branch into different storylines depending on whether the Viper gets shot down by the SA-15")
    :WithStorylines(
        Storyline:New(storyName .. " - step 1")
            :WithDescription("Viggen lands Senaki-Kolkhi, triggering step 2 after 30 seconds")
            :WithGroups("AIR TEST-1")
            :OnAircraftLanded("AIR TEST-1-1", function(e)
-- Debug("Storyline:OnAircraftLanded :: e: " .. DumpPretty(e))
                MessageTo(nil, "Viggen has landed " .. e.PlaceName)
                e:DestroyGroups()
                e:EndStoryline()
                e:RunStorylineDelayed("airbase hopping - step 2", 30, function() 
                    MessageTo(nil, "Viper takes off from " .. e.PlaceName)
                end)
            end),

        -- Viper; ferry Senaki ==> Kobuleti; might get shot down by SA-15
        Storyline:NewIdle(storyName .. " - step 2")
            :WithDescription("F-16C T/O Senaki-Kolkhi then lands Kobuleti, triggering step 3 after 30 seconds")
            :WithGroups("AIR TEST-2", "RUS SAM-1")
            :OnGroupEntersZone("Activate RUS SAM-1", nil, function(e)
                ROEWeaponFree("RUS SAM-1")
                MessageTo(nil, "Russian SAM is weapons free!")
            end, ZoneFilter:Coalitions( Coalition.Blue ):GroupType( GroupType.Air ))
            :OnUnitDestroyed({"AIR TEST-2-2", "AIR TEST-2-1"}, function(e)
                -- Viper shot down; launch Hornet for DEAD mission ...
                MessageTo(nil, "A viper was shot down. Launches DEAD misson from Kobuleti ... ")
                e:EndStoryline()
                e:RunStorylineDelayed(storyName .. " - step 3//DEAD", 10)
            end)
            :OnAircraftLanded("AIR TEST-2-1", function(e)
                -- Viper landed safely; launch Hornet for FERRY mission ...
                MessageTo(nil, "Viper has landed " .. e.PlaceName)
                e:DestroyGroups()
                e:EndStoryline()
                e:RunStorylineDelayed(storyName .. " - step 3//FERRY", 30)
            end),

        Storyline:NewIdle(storyName .. " - step 3//FERRY")
            -- Hornet; ferry Kobuleti ==> Kutaisi
            :WithDescription("F-18C T/O Kobuleti then lands Kutaisi, ending the story")
            :WithGroups("AIR TEST FERRY-3")
            :OnRun(function(e)
                MessageTo(nil, "Hornet takes off from Kobuleti, heading to Kutaisi")
            end)
            :OnAircraftLanded(nil, function(e)
                e:DestroyGroups()
                e:EndStory()
                MessageTo(nil, "Hornet has landed " .. e.PlaceName .. " :: '" .. e.Story .. "'' story ends")
            end),

        Storyline:NewIdle(storyName .. " - step 3//DEAD")
            -- Hornet; SEAD (SA-15 that shot down Viper) ==> Kutaisi
            :WithDescription("F-18C twoship T/O Kobuleti; kill SA_15, then lands Kutaisi, ending the story")
            :WithGroups("AIR TEST DEAD-3")
            :OnRun(function(e)
                MessageTo(nil, "Hornet takes off from  Kobuleti, to kill SA-15")
            end)
            :OnUnitInGroupDestroyed("AIR TEST DEAD-3", function(e)
                -- keep launching same DEAD group as long as the SA-15 shoots down Hornets ...
                if e:IsKillerGroup("RUS SAM-1") then
Debug(storyName .. " - step 3//DEAD:OnUnitInGroupDestroyed :: e: " .. DumpPrettyDeep(e))
                    e:LaunchGroups("AIR TEST DEAD-3")
                end
            end)
            :OnAircraftLanded(nil, function(e)
                e:DestroyGroups()
                e:EndStory()
                MessageTo(nil, "Hornet has landed " .. e.PlaceName .. " :: '" .. e.Story .. "'' story ends")
            end))

    :Run()