-- DCAF.TrainingRange = {
--     ClassName = "DCAF.TrainingRange",
--     Name = "TrainingRange",
--     IsActive = false,
--     Spawns = {
--       -- list of #SPAWN
--     }
-- }

-- local TRAINING_RANGES_MENUS = {
--     _keyMain = "_main_"
-- }
-- local _rebuildRadioMenus

-- local TRAINING_RANGES = { -- dictionary
--     -- key   :: #string (name of #DCAF.TrainingRange)
--     -- value :: #NTTR_RANGE
-- }

-- local TRAINING_RANGES_GROUPS = { -- dinctionary (helps ensuring not two ranges control same spawn)
--     -- key   :: #string (name of group, associated wit range)
--     -- value :: #NTTR_RANGE
-- }

-- -- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- --                                                   DCAF.TrainingRange
-- -- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- function DCAF.TrainingRange:New(name)
--     local range = DCAF.clone(DCAF.TrainingRange)
--     range.Name = name
--     range.IsActive = false
--     TRAINING_RANGES[name] = range
--     return range
-- end

-- --- Finds and returns a named #DCAF.TrainingRange
-- -- @arg :: list of #string (name of group to be associated with range)
-- function DCAF.TrainingRange:WithGroups(...)  --  arg = list of template names
--     local function isPrefixPattern(s)
--         local match = string.match(s, ".+[*]$")
--         if match then
--             return string.sub(s, 1, string.len(s)-1)
--         end
--     end

--     local function getGroupsThatStartsWith(prefix)
--         local groupNames = {}
--         for _, group in pairs(_DATABASE.GROUPS) do
--             local match = string.find(group.GroupName, prefix)
--             if match == 1 then
--                 table.insert(groupNames, group.GroupName)
--             end
--         end
--         return groupNames
--     end

--     local function init(name)
--         if not isAssignedString(name) then
--             error("NTTR_RANGE:WithGroups :: arg[" .. Dump(i) .. "] was not assigned string. Was instead: " .. DumpPretty(name)) end

--         local range = TRAINING_RANGES_GROUPS[name]
--         if range then
--             error("NTTR_RANGE:WithGroups :: arg[" .. Dump(i) .. "] ('" .. name .. "') is already associated with range '" .. range.Name .."'") end

-- -- Debug("DCAF.TrainingRange:WithGroups :: self.Name: " .. self.Name .. " :: group name: " .. Dump(name))
--         table.insert(self.Spawns, SPAWN:New(name))
--         TRAINING_RANGES_GROUPS[name] = self
--     end

--     for i = 1, #arg, 1 do
--         local name = arg[i]
--         local pattern = isPrefixPattern(name)
--         if pattern then 
--             local groupNames = getGroupsThatStartsWith(pattern)
--             for _, groupName in ipairs(groupNames) do
--                 init(groupName)
--             end
--         else
--             init(name)
--         end
--     end
--     return self
-- end

-- --- Finds and returns a named #DCAF.TrainingRange
-- -- @name :: #string; name of range
-- function DCAF.TrainingRange:Find(name)
--     return TRAINING_RANGES[name]
-- end

-- --- Returns value to indicate whether a range is activated
-- -- @name :: #string; name of range
-- function DCAF.TrainingRange:IsActive(name)
--     return DCAF.TrainingRange:Find(name).IsActive
-- end

-- function DCAF.TrainingRange:Spawn(source)
--     local spawn
--     if isAssignedString(source) then
--         spawn = self.Spawns[source]
--         if not spawn then
--             spawn = SPAWN:New(source)
--             self.Spawns[source] = spawn
--         end
--     elseif isClass(source, SPAWN.ClassName) then
--         spawn = source
--     end
--     local group = spawn:Spawn()
--     table.insert(self._groups, group)
-- end

-- --- Activates all groups associated with range
-- -- @name :: #string; specifies name of range to activate
-- -- @interval :: #number; specifies interval (seconds) between spawning groups associated with range
-- function DCAF.TrainingRange:Activate(name, interval)
-- -- Debug("DCAF.TrainingRange:Activate :: name: " .. Dump(name) .. " :: interval: " .. Dump(interval) .. " :: self: " .. DumpPrettyDeep(self, 1))
--     if isAssignedString(name) then
--         local range = DCAF.TrainingRange:Find(name)
--         if range then
--             range:Activate(nil, interval)
--         end
--         return range
--     end

--     if self.IsActive then
--         return end

--     self.IsActive = true
--     if isNumber(name) and interval == nil then
--         interval = name
--     end

--     if not isNumber(interval) then
--         interval = 0
--     else
--         -- ensure positive value...
--         interval = math.max(0, interval)
--     end

--     self._groups = {}
--     if interval == 0 then
--         for i, spawn in ipairs(self.Spawns) do
--             local group = spawn:Spawn()
--             table.insert(self._groups, group)
--         end
--     else
--         local spawns = listCopy(self.Spawns)
--         local _scheduler
--         local scheduler = SCHEDULER:New(spawns)
--         scheduler:Schedule(spawns, function() 
--             local spawn = spawns[1]
--             if not spawn then
-- -- Debug("nisse - DCAF.TrainingRange:Activate :: no more spawns :: stops scheduler")
--                 _scheduler:Stop()
--                 return
--             end
--             local group = spawn:Spawn()
--             table.insert(self._groups, group)
--             table.remove(spawns, 1)
--         end, {}, 0, interval)
--         _scheduler = scheduler
--         scheduler:Start()
--     end
--     MessageTo(nil, "Training range '" .. self.Name .. "' was activated")
--     _rebuildRadioMenus()
--     if self._onActivated then
--         self._onActivated(self, self._onActivatedArg) 
--     end
-- end

-- function DCAF.TrainingRange:Deactivate(name)
--     if isAssignedString(name) then
--         local range = DCAF.TrainingRange:Find(name)
--         if range then
--             range:Deactivate()
--         end
--         return range
--     end

--     if not self.IsActive then
--         return end

--     self.IsActive = false
--     for _, group in ipairs(self._groups) do
--         group:Destroy()
--     end
--     self._groups = nil
--     MessageTo(nil, "Training range '" .. self.Name .. "' was deactivated")
--     _rebuildRadioMenus()
--     if self._onDeactivated then
--         self._onDeactivated(self, self._onDeactivatedArg) 
--     end
-- end

-- function DCAF.TrainingRange:OnActivated(func, ...)
--     if not isFunction(func) then
--         error("DCAF.TrainingRange:OnActivated :: `func` must be function but was: " .. type(func)) end

--     self._onActivated = func
--     self._onActivatedArg = arg
--     return self
-- end

-- function DCAF.TrainingRange:OnDeactivated(func, ...)
--     if not isFunction(func) then
--         error("DCAF.TrainingRange:OnDeactivated :: `func` must be function but was: " .. type(func)) end

--     self._onDeactivated = func
--     self._onDeactivatedArg = arg
--     return self
-- end

-- -- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- --                                                         F10 RADIO MENUS
-- -- /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- local function sort(ranges)
--     local list = {}
--     for k, v in pairs(ranges) do
--         table.insert(list, v)
--     end
--     table.sort(list, function(a, b) 
--         if a and b then
--             if a.IsActive and not b.IsActive then
--                 return true
--             elseif b.IsActive and not a.IsActive then
--                 return false
--             else
--                 local result = a.Name < b.Name
--                 return result
--             end
--         elseif a then 
--             return true
--         else 
--             return false 
--         end
--     end)
--     return list
-- end

-- local _radioMenusCaption
-- local function buildRangesMenus(caption)
--     caption = caption or _radioMenusCaption
--     if not isAssignedString(caption) then
--         caption = "Training Ranges"
--     end
--     _radioMenusCaption = caption
--     local menuMain = TRAINING_RANGES_MENUS[TRAINING_RANGES_MENUS._keyMain]
--     if menuMain then
--         menuMain:RemoveSubMenus()
--     else
--         menuMain = MENU_COALITION:New(coalition.side.BLUE, caption)
--         TRAINING_RANGES_MENUS[TRAINING_RANGES_MENUS._keyMain] = menuMain
--     end
--     local menu = DCAF.MENU:New(menuMain)
--     -- sort menu so that active ranges comes first, then in alphanumerical order
--     local sorted = sort(TRAINING_RANGES)
--     for _, range in ipairs(sorted) do
--         local menuText = range.Name
--         if not range.IsActive then
--             menuText = menuText .. " (inactive)"
--         end
--         local menuRange = menu:Blue(menuText)
--         TRAINING_RANGES_MENUS[range.Name] = menuRange
--         if range.IsActive then
--             MENU_COALITION_COMMAND:New(coalition.side.BLUE, "DEACTIVATE", menuRange, function() 
--                 range:Deactivate()
--                 -- _rebuildRadioMenus()
--             end)
--         else
--             MENU_COALITION_COMMAND:New(coalition.side.BLUE, "ACTIVATE", menuRange, function() 
--                 range:Activate(.1)
--                 -- _rebuildRadioMenus()
--             end)
--         end
--     end
-- end
-- _rebuildRadioMenus = buildRangesMenus

-- -------------------------------------------------------------------------------------------------------------------
-- --                                             SUPPORT FUNCTIONS
-- --                      allows for creating range sub menus from a declared structure
-- -------------------------------------------------------------------------------------------------------------------

-- -- SUB MENU STRUCTURES

-- DCAF.TrainingRangeSubMenuStructure = { -- dictionary
--     ClassName = "DCAF.TrainingRangeSubMenuStructure", 
--     Range = nil,       -- #DCAF.TrainingRange
--     Items = {}         -- list of #DCAF.TrainingRangeSubMenuGroupActivation or #DCAF.TrainingRangeSubMenuCategory
-- }

-- DCAF.TrainingRangeSubMenuCategory = {
--     ClassName = "DCAF.TrainingRangeSubMenuCategory",
--     Parent = nil,      -- #DCAF.TrainingRangeSubMenuCategory | #DCAF.TrainingRangeSubMenuStructure
--     Text = nil,        -- menu text
--     Items = {}         -- list of #DCAF.TrainingRangeSubMenuGroupActivation or #DCAF.TrainingRangeSubMenuCategory
-- }

-- DCAF.TrainingRangeSubMenuGroupActivation = {
--     ClassName = "DCAF.TrainingRangeSubMenuGroupActivation", 
--     Parent = nil,      -- #DCAF.TrainingRangeSubMenuCategory | #DCAF.TrainingRangeSubMenuStructure
--     Text = nil,        -- menu text
--     GroupNames = {}    -- list of group names 
-- }

-- local function addItemsRaw(struct, dictionary)
--     for k, v in pairs(dictionary) do
--         local item
--         if isListOfAssignedStrings(v) then 
--             item = DCAF.TrainingRangeSubMenuGroupActivation:NewRaw(k, v)
--             table.insert(struct.Items, item)
--         elseif isDictionary(v) then
--             item = DCAF.TrainingRangeSubMenuCategory:NewRaw(k, v)
--             table.insert(struct.Items, item)
--         else
--             error("DCAF.TrainingRangeSubMenuStructure:New :: item #" .. Dump(i) .. " was not a valid sub menu object: " .. DumpPretty(item)) 
--         end
--         item.Parent = struct
--     end
--     return struct
-- end

-- local function addItems(struct, ...)
--     for i = 1, #arg, 1 do
--         local item = arg[i]
--         if not isClass(item, DCAF.TrainingRangeSubMenuCategory.ClassName) and not isClass(item, DCAF.TrainingRangeSubMenuGroupActivation.ClassName) then
--             error("DCAF.TrainingRangeSubMenuStructure:New :: item #" .. Dump(i) .. " was not a valid sub menu object: " .. DumpPretty(item)) end
        
--         table.insert(struct.Items, item)
--         item.Parent = struct
--     end
--     return struct
-- end

-- function DCAF.TrainingRangeSubMenuStructure:New(range, ...)
--     if not isClass(range, DCAF.TrainingRange) then
--         error("DCAF.TrainingRangeSubMenuStructure:New :: `range` must be #" .. DumpPretty(DCAF.TrainingRange.ClassName) .. ", but was: " .. DumpPretty(range)) end

--     local structure = DCAF.clone(DCAF.TrainingRangeSubMenuStructure)
--     structure.Range = range
--     return addItems(structure, ...)
-- end

-- function DCAF.TrainingRangeSubMenuStructure:NewRaw(range, table)
--     local structure = DCAF.clone(DCAF.TrainingRangeSubMenuStructure)
--     if not isTable(table) then
--         error("DCAF.TrainingRangeSubMenuStructure:NewRaw :: `table` must be a table, but was: " .. DumpPretty(table)) end

--     structure.Range = range
--     return addItemsRaw(structure, DCAF.clone(table, nil, true))
-- end

-- function DCAF.TrainingRangeSubMenuCategory:New(text, ...)
--     if #arg == 1 and isDictionary(arg[1]) then
--         return DCAF.TrainingRangeSubMenuCategory:NewRaw(text, arg[1]) end

--     if not isAssignedString(text) then
--         error("DCAF.TrainingRangeSubMenuCategory:New :: `text` must be assigned string, but was: " .. DumpPretty(text)) end

--     local category = DCAF.clone(DCAF.TrainingRangeSubMenuCategory)
--     category.Text = text
--     return addItems(category, { DCAF.TrainingRangeSubMenuCategory, DCAF.TrainingRangeSubMenuGroupActivation }, ...)
-- end

-- function DCAF.TrainingRangeSubMenuCategory:NewRaw(text, dictionary)
--     if not isAssignedString(text) then
--         error("DCAF.TrainingRangeSubMenuCategory:NewRaw :: `text` must be assigned string, but was: " .. DumpPretty(text)) end

--     local category = DCAF.clone(DCAF.TrainingRangeSubMenuCategory)
--     category.Text = text
--     return addItemsRaw(category, dictionary)
-- end

-- function DCAF.TrainingRangeSubMenuGroupActivation:New(text, ...)
--     if not isAssignedString(text) then
--         error("DCAF.TrainingRangeSubMenuGroupActivation:New :: `text` must be assigned string, but was: " .. DumpPretty(text)) end

--     if #arg == 1 and isAssignedString(arg[1]) then
--         return DCAF.TrainingRangeSubMenuGroupActivation:NewRaw(text, arg[1]) end

--     local activation = DCAF.clone(DCAF.TrainingRangeSubMenuGroupActivation)
--     activation.Text = text
--     for i = 1, #arg, 1 do
--         if not isAssignedString(arg[i]) then
--             error("DCAF.TrainingRangeSubMenuGroupActivation:New :: item #" .. Dump(i) .. " was expected to be string, but was: " .. DumpPretty(arg[i])) end

--         table.insert(activation.GroupNames, arg[i])
--     end
--     return activation
-- end

-- function DCAF.TrainingRangeSubMenuGroupActivation:NewRaw(text, groupNames)
--     local activation = DCAF.clone(DCAF.TrainingRangeSubMenuGroupActivation)
--     activation.Text = text
--     activation.GroupNames = groupNames
--     return activation
-- end

-- -------------------------- ACTIVATION

-- local function activateAll(range, structure)
--     for _, groupStruct in pairs(structure) do
--         for _, groupName in ipairs(groupStruct.GroupNames) do
--             range:Spawn(groupName)
--         end
--     end
-- end

-- local _text_activateAll = "Activate all"

-- local function menuActivateGroups(structure, groups, parentMenu)
--     local menu
--     local range = structure.Range
-- Debug("BBB" .. Dump(range ~= nil))    
--     menu = MENU_COALITION_COMMAND:New(coalition.side.BLUE, groups.Text, parentMenu or range:GetMenu(), function()
--         for _, groupName in ipairs(groups.GroupNames) do
--             range:Spawn(groupName)
--         end
--         menu:Remove()
--         if parentMenu then
--             local parentMenuText = getMenuText(parentMenu)
--             local parentItemIndex = tableIndexOf(groups.Parent.Items, function(item) return item.Text == groups.Text end)
--             groups.Parent.Items[parentItemIndex] = nil
--             if #groups.Parent.Items == 0 then
--                 parentMenu:Remove()
--             end
--         end
--     end)
-- end

-- local function menuCategory(structure, category, parentMenu)
-- -- Debug("nisse - menuCategory :: category.Text: " .. Dump(category.Text) .. " :: category.Items: " .. DumpPrettyDeep(category.Items))

--     local range = structure.Range
--     local menuCat = MENU_COALITION:New(coalition.side.BLUE, category.Text, parentMenu or range:GetMenu())
--     for _, groups in ipairs(category.Items) do
--         MENU_COALITION_COMMAND:New(coalition.side.BLUE, _text_activateAll, menuCat, function()
--             activateAll(range, category.Items)
--             menuCat:Remove()
--         end)
--         menuActivateGroups(structure, groups, menuCat)
--     end
-- end

-- function DCAF.TrainingRange:BuildF10Menus(caption)
--     buildRangesMenus(caption)
-- end

-- function DCAF.TrainingRange:BuildSubMenus(structure)
--     if not isClass(structure, DCAF.TrainingRangeSubMenuStructure) then
--         error("DCAF.TrainingRange:BuildSubMenus :: structure was expected to be #" .. DCAF.TrainingRangeSubMenuStructure.ClassName .. ", but was: " .. DumpPretty(structure)) end

-- -- Debug("nisse - DCAF.TrainingRange:BuildSubMenus :: structure: " .. DumpPrettyDeep(structure))

--     for _, item in ipairs(structure.Items) do
--         if isClass(item, DCAF.TrainingRangeSubMenuCategory) then
--             menuCategory(structure, item)
--         else
--             menuActivateGroups(structure, item)
--         end
--     end   
-- end

-- function DCAF.TrainingRange:GetMenu()
--     return TRAINING_RANGES_MENUS[self.Name]
-- end


-- -- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- Debug("\\\\\\\\\\\\\\\\\\\\ DCAF.TrainingRanges.lua was loaded ///////////////////")