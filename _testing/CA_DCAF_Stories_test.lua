DCAF.Trace = true
DCAF.Debug = true
DCAF.DebugToUI = true

local story = Story:New("airbase hopping")
    :WithDescription("Test story in three steps, each triggering the next with a 30 sec delay")
    :WithStorylines(
        Storyline:New("airbase hopping - step 1")
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
        Storyline:NewIdle("airbase hopping - step 2")
            :WithDescription("F-16C T/O Senaki-Kolkhi then lands Kobuleti, triggering step 3 after 30 seconds")
            :WithGroups("AIR TEST=A-2")
            :OnAircraftLanded("AIR TEST=A-2-1", function(e)
                MessageTo(nil, "Viper has landed " .. e.PlaceName)
                e:DestroyGroups()
                e:EndStoryline()
                e:RunStorylineDelayed("airbase hopping - step 3", 30, function()
                    MessageTo(nil, "Hornet takes off from " .. e.PlaceName)
                end)
            end),
        Storyline:NewIdle("airbase hopping - step 3")
            :WithDescription("F-18C T/O Kobuleti then lands Kutaisi, ending the story")
            :WithGroups("AIR TEST=A-3")
            :OnAircraftLanded("AIR TEST=A-3-1", function(e)
                e:DestroyGroups()
                e:EndStory()
                MessageTo(nil, "Hornet has landed " .. e.PlaceName .. " :: '" .. e.Story .. "'' story ends")
            end))
    :Run()

-- for idx, sl in ipairs(story.Storylines) do
--     Debug("nisse - story.Storyline #" .. tostring(idx) .. " :: Name: " .. sl.Name .. " :: story #" .. tostring(story._debug) .. " :: storyline #: " .. tostring(sl._debug) .. " :: State: " .. sl.State)
--     Debug("storyline #: " .. tostring(idx) .. ": " .. DumpPrettyDeep(storyline))
-- end
--story:_debug_storyline_state(2) -- nisse