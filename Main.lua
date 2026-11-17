local addonName, addon = ...

addon.commandHelpLines = {
    "/hudcraft - Toggle the Settings window.",
    "/hudcraft settings - Toggle the Settings window.",
    "/hudcraft minimap - Show or hide the minimap button.",
    "/hudcraft debug - Print recent diagnostic output.",
    "/hudcraft commands - List available commands.",
    "/hudcraft groups-debug - Print Group Management data and frame layout.",
    "/hudcraft group-position [name|id] - Print saved and live Group frame position data.",
}

function addon:Initialize()
    if self.initialized then return end

    HUDCraftDB = type(HUDCraftDB) == "table" and HUDCraftDB or {}
    HUDCraftDB.minimap = type(HUDCraftDB.minimap) == "table" and HUDCraftDB.minimap or {}
    if type(HUDCraftDB.minimap.hide) ~= "boolean" then HUDCraftDB.minimap.hide = false end
    local minimapAngle = tonumber(HUDCraftDB.minimap.angle)
    if not minimapAngle or minimapAngle ~= minimapAngle then
        HUDCraftDB.minimap.angle = 225
    else
        HUDCraftDB.minimap.angle = minimapAngle % 360
    end
    HUDCraftDB.general = type(HUDCraftDB.general) == "table" and HUDCraftDB.general or {}
    if HUDCraftDB.general.clockSource ~= "realm" and HUDCraftDB.general.clockSource ~= "local" then
        HUDCraftDB.general.clockSource = addon.Defaults.Account.general.clockSource
    end
    if HUDCraftDB.general.showGroupName == nil then
        HUDCraftDB.general.showGroupName = addon.Defaults.Account.general.showGroupName
    end
    if HUDCraftDB.general.spacing == nil then
        HUDCraftDB.general.spacing = addon.Defaults.Account.general.spacing
    end
    if HUDCraftDB.general.groupDirection == nil then
        HUDCraftDB.general.groupDirection = addon.Defaults.Account.general.groupDirection
    end
    local fontSize = tonumber(HUDCraftDB.general.fontSize)
    if not fontSize or fontSize < 8 or fontSize > 32 then
        HUDCraftDB.general.fontSize = addon.Defaults.Account.general.fontSize
    else
        HUDCraftDB.general.fontSize = fontSize
    end
    if HUDCraftDB.general.groupHeaderPosition == nil then
        HUDCraftDB.general.groupHeaderPosition = addon.Defaults.Account.general.groupHeaderPosition
    end
    local validHeaderPositions = { top = true, left = true, bottom = true, right = true }
    if not validHeaderPositions[HUDCraftDB.general.groupHeaderPosition] then
        HUDCraftDB.general.groupHeaderPosition = addon.Defaults.Account.general.groupHeaderPosition
    end
    local groupFrameLayer = tonumber(HUDCraftDB.general.groupFrameLayer)
    if not groupFrameLayer or groupFrameLayer ~= math.floor(groupFrameLayer)
        or groupFrameLayer < 1 or groupFrameLayer > 5 then
        HUDCraftDB.general.groupFrameLayer = addon.Defaults.Account.general.groupFrameLayer
    else
        HUDCraftDB.general.groupFrameLayer = groupFrameLayer
    end
    HUDCraftDB.general.moduleHighlightTexture = nil
    HUDCraftDB.general.moduleHighlightTint = nil
    if HUDCraftDB.general.horizontalSeparator == nil then
        HUDCraftDB.general.horizontalSeparator = addon.Defaults.Account.general.horizontalSeparator
    end
    if HUDCraftDB.general.verticalSeparator == nil then
        HUDCraftDB.general.verticalSeparator = addon.Defaults.Account.general.verticalSeparator
    end
    local validSeparators = { [""] = true, ["-"] = true, ["|"] = true }
    for _, separatorKey in ipairs({ "horizontalSeparator", "verticalSeparator" }) do
        if not validSeparators[HUDCraftDB.general[separatorKey]] then
            HUDCraftDB.general[separatorKey] = addon.Defaults.Account.general[separatorKey]
        end
    end
    HUDCraftDB.general.moduleHighlightScale = nil
    HUDCraftDB.groups = type(HUDCraftDB.groups) == "table" and HUDCraftDB.groups or {}
    HUDCraftDB.groups.order = type(HUDCraftDB.groups.order) == "table"
        and HUDCraftDB.groups.order or { 1 }
    HUDCraftDB.groups.byId = type(HUDCraftDB.groups.byId) == "table" and HUDCraftDB.groups.byId or {}
    local groupDefinitionsInitialized = HUDCraftDB.groups.initialized == true
    local savedGroups = HUDCraftDB.groups.byId
    local groupIdMigration = {}
    local oldSystemGroup = type(savedGroups[1]) == "table" and savedGroups[1]
    if tonumber(HUDCraftDB.version) ~= addon.Defaults.Account.version
        and oldSystemGroup and oldSystemGroup.name == "System" and type(savedGroups[2]) == "table" then
        local oldIds, seenOldIds = { 2 }, { [1] = true, [2] = true }
        for _, groupId in ipairs(HUDCraftDB.groups.order) do
            if type(groupId) == "number" and groupId > 2 and groupId == math.floor(groupId)
                and type(savedGroups[groupId]) == "table" and not seenOldIds[groupId] then
                oldIds[#oldIds + 1] = groupId
                seenOldIds[groupId] = true
            end
        end
        local remainingIds = {}
        for groupId, group in pairs(savedGroups) do
            if type(groupId) == "number" and groupId > 2 and groupId == math.floor(groupId)
                and type(group) == "table" and not seenOldIds[groupId] then
                remainingIds[#remainingIds + 1] = groupId
            end
        end
        table.sort(remainingIds)
        for _, groupId in ipairs(remainingIds) do oldIds[#oldIds + 1] = groupId end

        local migratedGroups, migratedOrder = {}, {}
        for index, oldId in ipairs(oldIds) do
            local newId = index
            groupIdMigration[oldId] = newId
            local group = savedGroups[oldId]
            group.id = newId
            migratedGroups[newId] = group
            migratedOrder[#migratedOrder + 1] = newId
        end
        savedGroups = migratedGroups
        HUDCraftDB.groups.byId = savedGroups
        HUDCraftDB.groups.order = migratedOrder
        HUDCraftDB.groups.nextId = #migratedOrder + 1
    end

    local mainGroup = type(savedGroups[1]) == "table" and savedGroups[1] or nil
    if not mainGroup and not groupDefinitionsInitialized then mainGroup = {} end
    local mainDefaults = addon.Defaults.Account.groups.byId[1]
    if mainGroup then
    mainGroup.id = 1
    mainGroup.useGlobalStyle = mainGroup.useGlobalStyle ~= false
    if type(mainGroup.name) ~= "string" or mainGroup.name == "" or mainGroup.name == "System" then
        mainGroup.name = "Main"
    end
    mainGroup.builtIn = true
    mainGroup.editable = true
    if type(mainGroup.selectedModules) ~= "table" then
        mainGroup.selectedModules = {}
        for moduleId, enabled in pairs(mainDefaults.selectedModules) do
            mainGroup.selectedModules[moduleId] = enabled
        end
    end
    if type(mainGroup.moduleOrder) ~= "table" then
        mainGroup.moduleOrder = {}
        for index, moduleId in ipairs(mainDefaults.moduleOrder) do
            mainGroup.moduleOrder[index] = moduleId
        end
    end
    for _, separatorKey in ipairs({ "horizontalSeparator", "verticalSeparator" }) do
        if not validSeparators[mainGroup[separatorKey]] then
            mainGroup[separatorKey] = mainDefaults[separatorKey]
        end
    end
    local validModuleIds, normalizedOrder = {}, {}
    for _, module in ipairs(addon.Modules or {}) do
        validModuleIds[module.id] = true
        if mainGroup.selectedModules[module.id] ~= true then
            mainGroup.selectedModules[module.id] = nil
        end
    end
    local orderedModules = {}
    for _, moduleId in ipairs(mainGroup.moduleOrder) do
        if validModuleIds[moduleId] and mainGroup.selectedModules[moduleId] == true
            and not orderedModules[moduleId] then
            normalizedOrder[#normalizedOrder + 1] = moduleId
            orderedModules[moduleId] = true
        end
    end
    for _, module in ipairs(addon.Modules or {}) do
        if mainGroup.selectedModules[module.id] == true and not orderedModules[module.id] then
            normalizedOrder[#normalizedOrder + 1] = module.id
            orderedModules[module.id] = true
        end
    end
    mainGroup.moduleOrder = normalizedOrder
    savedGroups[1] = mainGroup
    end
    HUDCraftDB.groups.initialized = true
    local orderedGroups, orderedGroupIds = {}, {}
    if type(savedGroups[1]) == "table" then
        orderedGroups[#orderedGroups + 1] = 1
        orderedGroupIds[1] = true
    end
    for _, groupId in ipairs(HUDCraftDB.groups.order) do
        if type(groupId) == "number" and groupId > 0 and groupId == math.floor(groupId)
            and type(savedGroups[groupId]) == "table"
            and not orderedGroupIds[groupId] then
            orderedGroups[#orderedGroups + 1] = groupId
            orderedGroupIds[groupId] = true
        end
    end
    HUDCraftDB.groups.order = orderedGroups
    local maxGroupId = 0
    for groupId in pairs(savedGroups) do
        if type(groupId) == "number" and groupId > maxGroupId then maxGroupId = groupId end
    end
    if type(HUDCraftDB.groups.nextId) ~= "number"
        or HUDCraftDB.groups.nextId ~= math.floor(HUDCraftDB.groups.nextId)
        or HUDCraftDB.groups.nextId <= maxGroupId then
        HUDCraftDB.groups.nextId = maxGroupId + 1
    end
    HUDCraftDB.version = addon.Defaults.Account.version

    HUDCraftCharDB = type(HUDCraftCharDB) == "table" and HUDCraftCharDB or {}
    HUDCraftCharDB.moduleSettings = type(HUDCraftCharDB.moduleSettings) == "table"
        and HUDCraftCharDB.moduleSettings or {}
    HUDCraftCharDB.moduleLabels = type(HUDCraftCharDB.moduleLabels) == "table"
        and HUDCraftCharDB.moduleLabels or {}
    for _, moduleId in ipairs({ "weaponSkills", "professions" }) do
        if HUDCraftCharDB.moduleLabels[moduleId] == nil then
            for _, groupId in ipairs(HUDCraftDB.groups.order or {}) do
                local group = HUDCraftDB.groups.byId[groupId]
                local labels = group and group.moduleLabels
                if type(labels) == "table" and type(labels[moduleId]) == "boolean" then
                    HUDCraftCharDB.moduleLabels[moduleId] = labels[moduleId]
                    break
                end
            end
        end
    end
    HUDCraftCharDB.windowPositions = type(HUDCraftCharDB.windowPositions) == "table" and HUDCraftCharDB.windowPositions or {}
    HUDCraftCharDB.windowCollapsed = type(HUDCraftCharDB.windowCollapsed) == "table" and HUDCraftCharDB.windowCollapsed or {}
    HUDCraftCharDB.windowSizes = type(HUDCraftCharDB.windowSizes) == "table" and HUDCraftCharDB.windowSizes or {}
    HUDCraftCharDB.frameHeaderPositions = type(HUDCraftCharDB.frameHeaderPositions) == "table"
        and HUDCraftCharDB.frameHeaderPositions
        or (type(HUDCraftCharDB.windowTitlePositions) == "table" and HUDCraftCharDB.windowTitlePositions or {})
    if type(HUDCraftCharDB.lastSettingsPage) ~= "string" then
        HUDCraftCharDB.lastSettingsPage = addon.Defaults.Character.lastSettingsPage
    end
    if type(HUDCraftCharDB.lastSettingsSubpage) ~= "string" then
        HUDCraftCharDB.lastSettingsSubpage = addon.Defaults.Character.lastSettingsSubpage
    end
    for _, stateKey in ipairs({ "windowPositions", "windowCollapsed", "windowSizes", "frameHeaderPositions" }) do
        local state = HUDCraftCharDB[stateKey]
        if state[1] == nil and state["setup-group"] ~= nil then state[1] = state["setup-group"] end
        if state[2] == nil and state["main-group"] ~= nil then state[2] = state["main-group"] end
        state["setup-group"] = nil
        state["main-group"] = nil
    end
    HUDCraftCharDB.groupsEnabled = type(HUDCraftCharDB.groupsEnabled) == "table"
        and HUDCraftCharDB.groupsEnabled or {}
    if next(groupIdMigration) then
        for _, stateKey in ipairs({ "windowPositions", "windowCollapsed", "windowSizes", "frameHeaderPositions", "groupsEnabled" }) do
            local state = HUDCraftCharDB[stateKey]
            local remapped = {}
            for oldId, value in pairs(state) do
                if type(oldId) == "number" then
                    local newId = groupIdMigration[oldId]
                    if newId then remapped[newId] = value end
                else
                    remapped[oldId] = value
                end
            end
            HUDCraftCharDB[stateKey] = remapped
        end
    end
    HUDCraftCharDB.groupsLocked = type(HUDCraftCharDB.groupsLocked) == "table"
        and HUDCraftCharDB.groupsLocked or {}
    if next(groupIdMigration) then
        local remappedLocks = {}
        for oldId, value in pairs(HUDCraftCharDB.groupsLocked) do
            local newId = type(oldId) == "number" and groupIdMigration[oldId]
            if newId then remappedLocks[newId] = value end
        end
        HUDCraftCharDB.groupsLocked = remappedLocks
    end
    for groupId in pairs(HUDCraftCharDB.groupsLocked) do
        if type(groupId) == "number" and not savedGroups[groupId] then
            HUDCraftCharDB.groupsLocked[groupId] = nil
        end
    end
    for groupId in pairs(HUDCraftCharDB.groupsEnabled) do
        if not savedGroups[groupId] then HUDCraftCharDB.groupsEnabled[groupId] = nil end
    end
    for _, stateKey in ipairs({ "windowPositions", "windowCollapsed", "windowSizes", "frameHeaderPositions" }) do
        local state = HUDCraftCharDB[stateKey]
        for groupId in pairs(state) do
            if type(groupId) == "number" and not savedGroups[groupId] then
                state[groupId] = nil
            end
        end
    end
    local hasSavedGroupVisibility = false
    for _, groupId in ipairs(HUDCraftDB.groups.order) do
        if type(HUDCraftCharDB.groupsEnabled[groupId]) == "boolean" then
            hasSavedGroupVisibility = true
            break
        end
    end
    for index, groupId in ipairs(HUDCraftDB.groups.order) do
        if not hasSavedGroupVisibility then
            HUDCraftCharDB.groupsEnabled[groupId] = index == 1
        elseif type(HUDCraftCharDB.groupsEnabled[groupId]) ~= "boolean" then
            HUDCraftCharDB.groupsEnabled[groupId] = true
        end
    end

    if not self.UI then
        return
    end

    HUDCraftDB.styles = type(HUDCraftDB.styles) == "table" and HUDCraftDB.styles or {}
    if type(HUDCraftDB.styles.groups) ~= "string"
        or not self.UI.WindowStyles.Presets[HUDCraftDB.styles.groups] then
        HUDCraftDB.styles.groups = addon.Defaults.Account.styles.groups
    end
    if type(HUDCraftDB.styles.settings) ~= "string"
        or not self.UI.WindowStyles.Presets[HUDCraftDB.styles.settings] then
        HUDCraftDB.styles.settings = HUDCraftDB.styles.groups
    end
    HUDCraftDB.styles.groupOverrides = type(HUDCraftDB.styles.groupOverrides) == "table"
        and HUDCraftDB.styles.groupOverrides or {}
    local groupOverrides = HUDCraftDB.styles.groupOverrides
    groupOverrides.colors = type(groupOverrides.colors) == "table" and groupOverrides.colors or {}
    groupOverrides.opacity = type(groupOverrides.opacity) == "table" and groupOverrides.opacity or {}
    for _, key in ipairs({ "text", "border", "interaction", "background" }) do
        local color = groupOverrides.colors[key]
        if type(color) ~= "string" or not color:match("^#%x%x%x%x%x%x$") then
            groupOverrides.colors[key] = nil
        else
            groupOverrides.colors[key] = color:upper()
        end
        local opacity = tonumber(groupOverrides.opacity[key])
        if not opacity or opacity ~= opacity then
            groupOverrides.opacity[key] = nil
        else
            groupOverrides.opacity[key] = math.floor(math.max(0, math.min(100, opacity)) + 0.5)
        end
    end
    for groupId, group in pairs(savedGroups) do
        if type(group) == "table" then
            group.selectedModules = type(group.selectedModules) == "table" and group.selectedModules or {}
            group.moduleOrder = type(group.moduleOrder) == "table" and group.moduleOrder or {}
            -- Remove the retired per-group surface settings. Group appearance
            -- now comes from the selected TreebeardUI preset and current
            -- HUDCraft style overrides.
            group.backgroundColor = nil
            group.borderColor = nil
            group.backgroundOpacity = nil
            group.borderOpacity = nil
            local hadCustomSeparators = group.useGlobalSeparators == false
            group.useGlobalStyle = group.useGlobalStyle ~= false
            if hadCustomSeparators then group.useGlobalStyle = false end
            if group.useGlobalStyle == false then
                if not hadCustomSeparators then
                    group.horizontalSeparator = HUDCraftDB.general.horizontalSeparator
                    group.verticalSeparator = HUDCraftDB.general.verticalSeparator
                end
                if type(group.customStyle) ~= "string" or group.customStyle == "" then
                    group.customStyle = HUDCraftDB.styles.groups
                end
            end
            group.useGlobalSeparators = nil
            for _, separatorKey in ipairs({ "horizontalSeparator", "verticalSeparator" }) do
                if not validSeparators[group[separatorKey]] then
                    group[separatorKey] = addon.Defaults.Account.groups.byId[1][separatorKey]
                end
            end
        end
    end
    self.groupStyleOwner = self.name .. ":groups"

    self.UI:RegisterConsumer(self.name, {
        windowState = function()
            return HUDCraftCharDB
        end,
        logger = function(message)
            self:AppendOutput(message)
        end,
    })
    self.UI:RegisterConsumer(self.groupStyleOwner, {
        windowState = function()
            return HUDCraftCharDB
        end,
    })
    self.UI.WindowStyles:SetConsumerPreset(self.groupStyleOwner, HUDCraftDB.styles.groups)

    self:CreateMainGroup()
    self:CreateSettingsWindow()
    self:CreateMinimapButton()
    self.initialized = true
    self:Log("Loaded hudcraft " .. self.version .. " with TreebeardUI API " .. tostring(self.requiredTreebeardUIAPI))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(frame, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    frame:UnregisterEvent("ADDON_LOADED")
    DEFAULT_CHAT_FRAME:AddMessage("|cffd8b24ahudcraft|cffffffff: Version " .. addon.version .. " loaded. Use /hudcraft commands to view commands.|r")
    addon:Initialize()
end)

SLASH_HUDCRAFT1 = "/hudcraft"
SlashCmdList.HUDCRAFT = function(message)
    local command = string.lower(tostring(message or "")):match("^%s*(.-)%s*$")
    if command == "debug" then
        addon:PrintOutput()
    elseif command == "groups-debug" then
        if type(addon.GetGroupManagementDiagnostics) ~= "function" then
            DEFAULT_CHAT_FRAME:AddMessage("hudcraft: Group Management diagnostics are unavailable; reload the diagnostic build.")
        else
            for _, line in ipairs(addon:GetGroupManagementDiagnostics()) do
                DEFAULT_CHAT_FRAME:AddMessage("|cffd8b24ahudcraft|r " .. line)
            end
        end
    elseif command:match("^group%-position") then
        local filter = command:match("^group%-position%s*(.-)%s*$") or ""
        if type(addon.GetGroupPositionDiagnostics) ~= "function" then
            DEFAULT_CHAT_FRAME:AddMessage("hudcraft: Group position diagnostics are unavailable; reload the diagnostic build.")
        else
            for _, line in ipairs(addon:GetGroupPositionDiagnostics(filter)) do
                DEFAULT_CHAT_FRAME:AddMessage("|cffd8b24ahudcraft|r " .. line)
            end
        end
    elseif command == "commands" then
        for _, line in ipairs(addon.commandHelpLines) do
            DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. line .. "|r")
        end
    elseif command == "minimap" then
        local shown = addon:ToggleMinimapButton()
        DEFAULT_CHAT_FRAME:AddMessage("hudcraft minimap button " .. (shown and "shown." or "hidden."))
    elseif command == "" or command == "settings" then
        addon:ToggleSettings()
    else
        print("hudcraft: /hudcraft [settings|minimap|debug|commands|groups-debug|group-position]")
    end
end
