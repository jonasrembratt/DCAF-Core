DCAF.Trace = true
DCAF.Debug = true
DCAF.DebugToUI = true

-- local nisse_spawned = SPAWN:New("AIR TEST=A-1"):Spawn()
-- local nisse_unit1 = nisse_spawned:GetUnit(1)
-- Debug("nisse_unit1: " .. DumpPrettyDeep(nisse_unit1))

local storyName = "airbase hopping"

local story = Story:New(storyName)
    :WithDescription("Test story in three steps, each triggering the next with a 30 sec delay")
    :WithStorylines(
        Storyline:New(storyName .. " - step 1")
            :WithDescription("Viggen lands Senaki-Kolkhi, triggering step 2 after 30 seconds")
            :WithGroups("AIR TEST=A-1")
            :OnAircraftLanded("AIR TEST=A-1-1", function(e)
                MessageTo(nil, "Viggen has landed " .. e.PlaceName)
                e:DestroyGroups()
                e:EndStoryline()
                e:RunStorylineDelayed("airbase hopping - step 2", 30, function() 
                    MessageTo(nil, "Viper takes off from " .. e.PlaceName)
                end)
            end),
        Storyline:NewIdle(storyName .. " - step 2")
            :WithDescription("F-16C T/O Senaki-Kolkhi then lands Kobuleti, triggering step 3 after 30 seconds")
            :WithGroups("AIR TEST=A-2")
            :OnAircraftLanded("AIR TEST=A-2-1", function(e)
                MessageTo(nil, "Viper has landed " .. e.PlaceName)
                e:DestroyGroups("AIR TEST=A-2")
                e:EndStoryline()
                e:RunStorylineDelayed("airbase hopping - step 3", 30, function()
                    MessageTo(nil, "Hornet takes off from " .. e.PlaceName)
                end)
            end),
        Storyline:NewIdle(storyName .. " - step 3")
            :WithDescription("F-18C T/O Kobuleti then lands Kutaisi, ending the story")
            :WithGroups("AIR TEST=A-3")
            :OnAircraftLanded("AIR TEST=A-3-1", function(e)
                e:DestroyGroups()
                e:EndStory()
                MessageTo(nil, "Hornet has landed " .. e.PlaceName .. " :: '" .. e.Story .. "'' story ends")
            end))
    :Run()