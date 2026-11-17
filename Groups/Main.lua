local _, addon = ...

local GROUP_FRAME_STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }

function addon:ApplyGroupFrameLayer(window)
    if not window then return end
    local layer = tonumber(HUDCraftDB.general.groupFrameLayer) or 3
    layer = math.max(1, math.min(#GROUP_FRAME_STRATA, math.floor(layer)))
    local strata = GROUP_FRAME_STRATA[layer]
    if window.frameAssembly then window.frameAssembly:SetFrameStrata(strata) end
    window:SetFrameStrata(strata)
    if window.frameHeader then window.frameHeader:SetFrameStrata(strata) end
end

function addon:ApplyAllGroupFrameLayers()
    for _, window in pairs(self.groupFrames or {}) do
        self:ApplyGroupFrameLayer(window)
    end
end

local function GetModuleDisplay(module, orientation)
    local getter = module.getDisplay or module.getText
    if type(getter) ~= "function" then return { text = "—" } end
    local ok, value = pcall(getter, orientation)
    if not ok then return { text = "—" } end
    if type(value) == "table" then return value end
    return { text = tostring(value or "") }
end

local function GetModuleGroupDisplays(module, orientation)
    local provider = module and module.getGroupItems
    if type(provider) ~= "function" then
        return { { key = "main", display = GetModuleDisplay(module, orientation), showDetails = true } }
    end

    local labelOptions = HUDCraftCharDB and HUDCraftCharDB.moduleLabels
    local showLabel = type(labelOptions) ~= "table" or labelOptions[module.id] ~= false
    local ok, values = pcall(provider, orientation, showLabel)
    if not ok or type(values) ~= "table" then
        return { { key = "main", display = GetModuleDisplay(module, orientation), showDetails = true } }
    end

    local items = {}
    for index, value in ipairs(values) do
        if type(value) == "table" then
            local key = value.key or value.id or index
            local display = value.display
            if display == nil then display = { text = value.text or "" } end
            items[#items + 1] = {
                key = tostring(key),
                display = display,
                showDetails = value.showDetails == true,
            }
        end
    end
    if #items == 0 then
        return { { key = "main", display = GetModuleDisplay(module, orientation), showDetails = true } }
    end
    return items
end

local function HasValidInteraction(module)
    local interaction = module and module.interaction
    if type(interaction) == "function" then return true end
    if type(interaction) ~= "table" then return false end
    return type(interaction.onClick) == "function"
        or type(interaction.onRightClick) == "function"
        or type(interaction.getDetails) == "function"
end

function addon:ApplyGroupAppearance(groupId)
    local config = HUDCraftDB.groups.byId[groupId]
    local window = self.groupFrames and self.groupFrames[groupId]
    if not config or not window then return end
    local owner = self.groupStyleOwners[groupId]
    local preset = config.useGlobalStyle == false and config.customStyle or HUDCraftDB.styles.groups
    if not self.UI.WindowStyles.Presets[preset] then preset = HUDCraftDB.styles.groups end
    preset = self:GetGroupStylePreset(preset or HUDCraftDB.styles.groups)
    self.UI.WindowStyles:SetConsumerPreset(owner, preset)
    window:SetSurfaceOptions({})
end

function addon:ApplyMainGroupAppearance()
    self:ApplyGroupAppearance(1)
end

function addon:ApplyAllGroupAppearances()
    for groupId in pairs(self.groupFrames or {}) do self:ApplyGroupAppearance(groupId) end
end

function addon:GetGroupName(groupId)
    local group = HUDCraftDB and HUDCraftDB.groups
        and HUDCraftDB.groups.byId and HUDCraftDB.groups.byId[groupId]
    return group and type(group.name) == "string" and group.name or ""
end

function addon:GetGroupDirection(groupId)
    local group = HUDCraftDB and HUDCraftDB.groups
        and HUDCraftDB.groups.byId and HUDCraftDB.groups.byId[groupId]
    local direction = group and group.orientation
    if direction ~= "row" and direction ~= "column" then
        direction = HUDCraftDB and HUDCraftDB.general and HUDCraftDB.general.groupDirection
    end
    return direction == "column" and "column" or "row"
end

function addon:ShowModuleContextMenu(module, anchor)
    if not module or not self.UI or not self.UI.ContextMenu then return end
    local entries = {}
    if module.id == "weaponSkills" or module.id == "professions" then
        entries[#entries + 1] = {
            label = "Settings",
            action = function() self:ShowModuleSettings(module.id) end,
        }
    end
    local interaction = module.interaction
    if type(interaction) == "table" and type(interaction.onRightClick) == "function" then
        entries[#entries + 1] = { label = "Module action", action = function() interaction.onRightClick(anchor) end }
    end
    if #entries == 0 then return end
    if not self.moduleContextMenu then self.moduleContextMenu = self.UI.ContextMenu:Create(self.name) end
    self.moduleContextMenu:Open(anchor, module.label, entries)
end

function addon:CreateGroupFrame(groupId, initialPosition)
    local config = HUDCraftDB.groups.byId[groupId]
    if not config or self.groupFrames[groupId] then return end
    config.selectedModules = type(config.selectedModules) == "table" and config.selectedModules or {}
    config.moduleOrder = type(config.moduleOrder) == "table" and config.moduleOrder or {}
    local owner = self.name .. ":group:" .. tostring(groupId)
    self.groupStyleOwners[groupId] = owner
    self.UI:RegisterConsumer(owner, { windowState = function() return HUDCraftCharDB end })
    local baseStyle = config.useGlobalStyle == false and config.customStyle or HUDCraftDB.styles.groups
    if not self.UI.WindowStyles.Presets[baseStyle] then baseStyle = HUDCraftDB.styles.groups end
    self.UI.WindowStyles:SetConsumerPreset(owner,
        self:GetGroupStylePreset(baseStyle or HUDCraftDB.styles.groups))
    local initialMovable = HUDCraftCharDB.groupsLocked[groupId] ~= true
    local controlPanelVisibility = config.controlPanelVisibility
    if controlPanelVisibility ~= "always" and controlPanelVisibility ~= "hover"
        and controlPanelVisibility ~= "never" then
        controlPanelVisibility = "always"
    end
    local orderIndex = 1
    for index, orderedId in ipairs(HUDCraftDB.groups.order or {}) do
        if orderedId == groupId then orderIndex = index break end
    end
    local window = self.UI.WindowFrame:Create({
        id = groupId,
        title = "",
        owner = owner,
        sizing = {
            mode = "consumer",
            initial = { width = 280, height = 40 },
            minimum = { width = 15, height = 15 },
            position = initialPosition or { x = 0, y = -215 - ((orderIndex - 1) * 70) },
        },
        interaction = {
            movable = initialMovable,
            borderHover = initialMovable,
            onMovableChanged = function(movable, frame)
                if movable then
                    HUDCraftCharDB.groupsLocked[groupId] = nil
                else
                    HUDCraftCharDB.groupsLocked[groupId] = true
                end
                frame:SetBorderHoverEnabled(movable)
            end,
        },
        surface = { frameBorder = "body" },
        frameHeader = {
            visibility = controlPanelVisibility,
            position = HUDCraftDB.general.groupHeaderPosition or "top",
            width = { mode = "content" },
            controls = { lock = true },
        },
    })
    self.groupFrames[groupId] = window
    self:ApplyGroupFrameLayer(window)
    local headerPosition = HUDCraftDB.general.groupHeaderPosition or "top"
    local headerAnchors = { top = "right", left = "top", bottom = "left", right = "bottom" }
    window:SetFrameHeaderPosition(headerPosition, headerAnchors[headerPosition])
    self:RenameGroupFrame(groupId)
    if groupId == 1 then self.mainGroup = window end
    window:SetShown(HUDCraftCharDB.groupsEnabled[groupId] ~= false)
    self.groupRenderers[groupId] = self.GroupRenderer:Create(window.content, {
        orientation = self:GetGroupDirection(groupId),
        fontSize = tonumber(HUDCraftDB.general.fontSize) or 14,
        horizontalGap = math.max(0, tonumber(HUDCraftDB.general.spacing) or 6),
        verticalGap = math.max(0, tonumber(HUDCraftDB.general.spacing) or 6),
        padding = 5,
        onSizeChanged = function(width, height) window:SetExpandedSize(width + 2, height + 2) end,
        onModuleEnter = function(module, source)
            self:ShowGroupModuleDetails(groupId, module, source)
        end,
        onModuleLeave = function()
            self:ScheduleGroupDetailsHide(groupId)
        end,
    })
    window:HookScript("OnHide", function()
        local details = self.groupDetails and self.groupDetails[groupId]
        if details then details:Hide() end
    end)
    window:HookScript("OnShow", function() self:RefreshGroup(groupId) end)
    self:RefreshGroup(groupId)
end

function addon:RenameGroupFrame(groupId)
    local window = self.groupFrames and self.groupFrames[groupId]
    if not window then return end
    if window.frameHeader and window.frameHeader.label then
        window.frameHeader.label:SetText(self:GetGroupName(groupId))
        window:SetFrameHeaderWidth({ mode = "content" })
    end
end

function addon:DeleteGroupFrame(groupId)
    local window = self.groupFrames and self.groupFrames[groupId]
    if window then window:Hide(); window:SetParent(nil) end
    local details = self.groupDetails and self.groupDetails[groupId]
    if details then details:Hide(); details:SetParent(nil); self.groupDetails[groupId] = nil end
    if self.groupFrames then self.groupFrames[groupId] = nil end
    if self.groupRenderers then self.groupRenderers[groupId] = nil end
    self.groupStyleOwners[groupId] = nil
    for _, stateKey in ipairs({ "windowPositions", "windowCollapsed", "windowSizes", "frameHeaderPositions", "groupsLocked" }) do
        if HUDCraftCharDB[stateKey] then HUDCraftCharDB[stateKey][groupId] = nil end
    end
    HUDCraftCharDB.groupsEnabled[groupId] = nil
end

function addon:CreateGroup()
    local groups = HUDCraftDB.groups
    groups.byId = type(groups.byId) == "table" and groups.byId or {}
    groups.order = type(groups.order) == "table" and groups.order or {}
    local nextId = tonumber(groups.nextId)
    if not nextId or nextId < 1 or nextId ~= math.floor(nextId) then
        local maxId = 0
        for groupId in pairs(groups.byId) do
            if type(groupId) == "number" and groupId > maxId then maxId = groupId end
        end
        nextId = maxId + 1
    end

    local groupCount = 0
    for _, currentGroup in pairs(groups.byId) do
        if type(currentGroup) == "table" then groupCount = groupCount + 1 end
    end

    local groupId = nextId
    local group = {
        id = groupId,
        name = "Group " .. tostring(groupCount + 1),
        builtIn = false,
        editable = true,
        selectedModules = { character = true, experience = true },
        moduleOrder = { "character", "experience" },
        horizontalSeparator = HUDCraftDB.general.horizontalSeparator or "-",
        verticalSeparator = HUDCraftDB.general.verticalSeparator or "",
        useGlobalStyle = true,
    }
    groups.byId[groupId] = group
    groups.order[#groups.order + 1] = groupId
    groups.nextId = groupId + 1
    groups.initialized = true
    HUDCraftCharDB.groupsEnabled[groupId] = true
    self:CreateGroupFrame(groupId, { x = 400, y = 0 })
    return groupId
end

function addon:DeleteGroup(groupId)
    local groups = HUDCraftDB.groups
    if type(groupId) ~= "number" or type(groups.byId[groupId]) ~= "table" then return false end
    groups.byId[groupId] = nil
    for index = #(groups.order or {}), 1, -1 do
        if groups.order[index] == groupId then table.remove(groups.order, index) end
    end
    self:DeleteGroupFrame(groupId)
    if groupId == 1 then
        self.mainGroup = nil
        self.mainGroupRenderer = nil
    end
    return true
end

function addon:SetGroupLocked(groupId, locked)
    local window = self.groupFrames and self.groupFrames[groupId]
    if not window then return false end
    HUDCraftCharDB.groupsLocked = type(HUDCraftCharDB.groupsLocked) == "table"
        and HUDCraftCharDB.groupsLocked or {}
    HUDCraftCharDB.groupsLocked[groupId] = locked == true and true or nil
    window:SetMovableEnabled(locked ~= true)
    return true
end

function addon:RefreshGroup(groupId, moduleIds)
    local window = self.groupFrames and self.groupFrames[groupId]
    local renderer = self.groupRenderers and self.groupRenderers[groupId]
    local config = HUDCraftDB.groups.byId[groupId]
    if not window or not renderer or not config then return end
    config.selectedModules = type(config.selectedModules) == "table" and config.selectedModules or {}
    config.moduleOrder = type(config.moduleOrder) == "table" and config.moduleOrder or {}
    local direction = self:GetGroupDirection(groupId)
    local spacing = math.max(0, tonumber(HUDCraftDB.general.spacing) or 6)
    local horizontalSeparator = config.useGlobalStyle ~= false
        and HUDCraftDB.general.horizontalSeparator or config.horizontalSeparator or ""
    local verticalSeparator = config.useGlobalStyle ~= false
        and HUDCraftDB.general.verticalSeparator or config.verticalSeparator or ""
    local moduleById, signatureParts = {}, {}
    for _, module in ipairs(self.Modules or {}) do
        moduleById[module.id] = module
        signatureParts[#signatureParts + 1] = module.id
        signatureParts[#signatureParts + 1] = config.selectedModules[module.id] == true and "1" or "0"
        signatureParts[#signatureParts + 1] = HasValidInteraction(module) and "i" or "n"
    end
    signatureParts[#signatureParts + 1] = table.concat(config.moduleOrder, "\001")
    signatureParts[#signatureParts + 1] = horizontalSeparator
    signatureParts[#signatureParts + 1] = verticalSeparator
    signatureParts[#signatureParts + 1] = direction
    signatureParts[#signatureParts + 1] = HUDCraftDB.general.fontSize or 14
    local renderItems, shapeParts = {}, {}
    for _, moduleId in ipairs(config.moduleOrder) do
        local module = moduleById[moduleId]
        if module and config.selectedModules[moduleId] == true then
            for _, part in ipairs(GetModuleGroupDisplays(module, direction)) do
                local renderId = moduleId .. ":" .. part.key
                renderItems[#renderItems + 1] = {
                    id = renderId,
                    moduleId = moduleId,
                    module = part.showDetails and module or nil,
                    display = part.display,
                    showDetails = part.showDetails == true,
                }
                shapeParts[#shapeParts + 1] = renderId
            end
        end
    end
    signatureParts[#signatureParts + 1] = table.concat(shapeParts, "\001")
    local signature = table.concat(signatureParts, "\002")
    local rebuild = window.rendererSignature ~= signature
    if rebuild then
        if #renderItems == 0 then renderItems[1] = { id = "empty", display = { text = "No modules selected" } } end
        renderer:SetItems(renderItems, {
            orientation = direction,
            horizontalGap = spacing,
            verticalGap = spacing,
            horizontalSeparator = horizontalSeparator,
            verticalSeparator = verticalSeparator,
            fontSize = HUDCraftDB.general.fontSize or 14,
        })
        window.rendererSignature = signature
    else
        renderer:SetOptions({
            orientation = direction,
            horizontalGap = spacing,
            verticalGap = spacing,
            horizontalSeparator = horizontalSeparator,
            verticalSeparator = verticalSeparator,
            fontSize = HUDCraftDB.general.fontSize or 14,
        })
    end
    local requested
    if moduleIds then requested = {}; for _, id in ipairs(moduleIds) do requested[id] = true end end
    local updates = {}
    if not rebuild then
        for _, item in ipairs(renderItems) do
            -- Refresh every row owned by this module, including intentionally
            -- noninteractive skill/profession lines. Hover stays on the label.
            if item.moduleId and (not requested or requested[item.moduleId]) then
                updates[item.id] = item.display
            end
        end
    end
    renderer:UpdateItems(updates)
end

function addon:RefreshMainGroup(moduleIds)
    self:RefreshGroup(1, moduleIds)
end

function addon:RefreshAllGroups(moduleIds)
    for groupId in pairs(self.groupFrames or {}) do self:RefreshGroup(groupId, moduleIds) end
end

function addon:GetGroupPositionDiagnostics(filter)
    local lines = {}
    local groups = HUDCraftDB and HUDCraftDB.groups
    local byId = groups and groups.byId or {}
    local characterState = HUDCraftCharDB or {}
    local savedPositions = characterState.windowPositions or {}
    local requested = type(filter) == "string" and filter:lower():match("^%s*(.-)%s*$") or ""
    local found = false

    local function add(message)
        lines[#lines + 1] = message
    end
    local function formatNumber(value)
        return type(value) == "number" and string.format("%.2f", value) or "n/a"
    end

    for _, groupId in ipairs(groups and groups.order or {}) do
        local group = byId[groupId]
        local name = type(group) == "table" and tostring(group.name or "") or ""
        if requested == "" or tostring(groupId) == requested or name:lower():find(requested, 1, true) then
            found = true
            local saved = savedPositions[groupId]
            local frame = self.groupFrames and self.groupFrames[groupId]
            add(string.format("group id=%s name=%q orientation=%s collapsed=%s",
                tostring(groupId), name, tostring(self:GetGroupDirection(groupId)),
                tostring(characterState.windowCollapsed and characterState.windowCollapsed[groupId] == true)))
            if type(saved) == "table" then
                add(string.format("saved anchor=%s/%s x=%s y=%s",
                    tostring(saved.point), tostring(saved.relativePoint),
                    formatNumber(saved.x), formatNumber(saved.y)))
            else
                add("saved anchor=none (TreebeardUI will use the configured default position)")
            end
            if frame then
                local left, bottom, width, height = frame:GetRect()
                local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
                add(string.format("live shown=%s anchor=%s/%s x=%s y=%s rect left=%s bottom=%s width=%s height=%s",
                    tostring(frame:IsShown()), tostring(point),
                    relativeTo == UIParent and "UIParent" or tostring(relativeTo),
                    formatNumber(x), formatNumber(y), formatNumber(left), formatNumber(bottom),
                    formatNumber(width), formatNumber(height)))
                add(string.format("live relativePoint=%s effectiveScale=%s",
                    tostring(relativePoint), formatNumber(frame:GetEffectiveScale())))
            else
                add("live frame=not created")
            end
        end
    end

    if not found then
        add("No Group matched " .. string.format("%q", requested) .. ".")
    end
    return lines
end

function addon:CreateMainGroup()
    self.groupFrames, self.groupRenderers, self.groupStyleOwners = {}, {}, {}
    self.groupDetails = {}
    for _, groupId in ipairs(HUDCraftDB.groups.order) do
        self:CreateGroupFrame(groupId)
    end
    self.mainGroupRenderer = self.groupRenderers[1]

    local updates = CreateFrame("Frame")
    local eventModules = {}
    updates.refreshTimers = {}
    for _, module in ipairs(self.Modules or {}) do
        for _, event in ipairs(module.updateEvents or {}) do
            eventModules[event] = eventModules[event] or {}
            eventModules[event][#eventModules[event] + 1] = module.id
            updates:RegisterEvent(event)
        end
        local interval = tonumber(module.refreshInterval)
        if interval and interval > 0 then
            local moduleId = module.id
            updates.refreshTimers[#updates.refreshTimers + 1] = C_Timer.NewTicker(interval, function()
                self:RefreshAllGroups({ moduleId })
            end)
        end
    end
    updates:SetScript("OnEvent", function(_, event) self:RefreshAllGroups(eventModules[event]) end)
end
