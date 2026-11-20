local _, addon = ...

local GROUP_FRAME_STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
local GROUP_SPAWN_TOP_INSET_FRACTION = 0.15
local GROUP_SPAWN_ORBIT_FRACTION = 0.08
local GROUP_SPAWN_POSITION_COUNT = 6

local function GetDefaultGroupPosition(groupId)
    local index = math.max(1, math.floor(tonumber(groupId) or 1))
    local screenHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
    local position = (index - 1) % GROUP_SPAWN_POSITION_COUNT
    local angle = math.rad(position * (360 / GROUP_SPAWN_POSITION_COUNT))
    local orbitRadius = screenHeight * GROUP_SPAWN_ORBIT_FRACTION
    return {
        x = math.cos(angle) * orbitRadius,
        y = -(screenHeight * GROUP_SPAWN_TOP_INSET_FRACTION) + (math.sin(angle) * orbitRadius),
        anchor = { point = "TOP", relativePoint = "TOP" },
    }
end

local function SetFrameTreeMouseEnabled(frame, enabled)
    if not frame then return end
    if frame.EnableMouse then frame:EnableMouse(enabled) end
    if not frame.GetChildren then return end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        SetFrameTreeMouseEnabled(child, enabled)
    end
end

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
                module = value.module or (value.showDetails == true and module or nil),
                showDetails = value.showDetails == true,
            }
        end
    end
    if #items == 0 then
        return { { key = "main", display = GetModuleDisplay(module, orientation), showDetails = true } }
    end
    return items
end

local function HasValidInteraction(module, detailsEnabled)
    local interaction = module and module.interaction
    if type(interaction) == "function" then return true end
    if type(interaction) ~= "table" then return module and module.hasSettingsPage == true or false end
    return type(interaction.onClick) == "function"
        or type(interaction.onRightClick) == "function"
        or module.hasSettingsPage == true
        or (detailsEnabled ~= false and type(interaction.getDetails) == "function")
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
    if window.RefreshNotepadSurface then window:RefreshNotepadSurface() end
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

function addon:ShowModuleContextMenu(module, anchor, groupId)
    if not module or not self.UI or not self.UI.ContextMenu then return end
    local entries = {}
    if module.hasSettingsPage and module.contextMenuSettings ~= false then
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
    self.moduleContextMenus = self.moduleContextMenus or {}
    local menu = self.moduleContextMenus[groupId]
    if not menu then
        local owner = self.groupStyleOwners and self.groupStyleOwners[groupId] or self.name
        menu = self.UI.ContextMenu:Create(owner)
        self.moduleContextMenus[groupId] = menu
    end
    menu:Open(anchor, module.label, entries)
end

function addon:ShowGroupContextMenu(groupId, anchor)
    local group = HUDCraftDB and HUDCraftDB.groups and HUDCraftDB.groups.byId
        and HUDCraftDB.groups.byId[groupId]
    if not group or not anchor or not self.UI or not self.UI.ContextMenu then return end
    self.groupContextMenus = self.groupContextMenus or {}
    local menu = self.groupContextMenus[groupId]
    if not menu then
        local owner = self.groupStyleOwners and self.groupStyleOwners[groupId] or self.name
        menu = self.UI.ContextMenu:Create(owner)
        self.groupContextMenus[groupId] = menu
    end
    menu:Open(anchor, group.name or "Group", {
        {
            label = group.kind == "notepad" and "Notepad Help" or "Edit Group Settings",
            action = function()
                if group.kind == "notepad" then
                    self:ShowModuleSettings("notepads")
                else
                    self:ShowGroupManagementSettings(groupId)
                end
            end,
        },
    })
end

function addon:ShowGroupManagementSettings(groupId)
    local group = HUDCraftDB and HUDCraftDB.groups and HUDCraftDB.groups.byId
        and HUDCraftDB.groups.byId[groupId]
    if not group or not self.settingsWindow or type(self.ShowSettingsPage) ~= "function"
        or type(self.SelectGroupManagementGroup) ~= "function" then
        return false
    end
    self.settingsWindow:Show()
    self:ShowSettingsPage("groups", "group-management")
    return self:SelectGroupManagementGroup(groupId)
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
    local headerPosition = config.controlPanelPosition
    if headerPosition ~= "top" and headerPosition ~= "bottom"
        and headerPosition ~= "left" and headerPosition ~= "right" then
        headerPosition = HUDCraftDB.general.groupHeaderPosition or "top"
    end
    local initialWidth, initialHeight = config.kind == "notepad" and 320 or 280,
        config.kind == "notepad" and 180 or 40
    local position = {}
    local positionSource = type(initialPosition) == "table"
        and initialPosition or GetDefaultGroupPosition(groupId)
    for key, value in pairs(positionSource) do
        position[key] = value
    end
    position.mode = "screenAdaptive"
    local window = self.UI.WindowFrame:Create({
        id = groupId,
        title = "",
        owner = owner,
        sizing = {
            mode = "consumer",
            initial = { width = initialWidth, height = initialHeight },
            minimum = config.kind == "notepad"
                and { width = 180, height = 100 } or { width = 15, height = 15 },
            position = position,
        },
        interaction = {
            movable = initialMovable,
            borderHover = initialMovable,
            resize = config.kind == "notepad" and { corner = true } or nil,
            onMovableChanged = function(movable, frame)
                if movable then
                    HUDCraftCharDB.groupsLocked[groupId] = nil
                else
                    HUDCraftCharDB.groupsLocked[groupId] = true
                end
                frame:SetBorderHoverEnabled(movable)
                if config.kind == "notepad" then frame:SetResizeEnabled(movable) end
                if frame.notepadInputSurface then
                    frame.notepadInputSurface:SetInputEnabled(movable)
                elseif frame.notepadEditBox then
                    if not movable then frame.notepadEditBox:ClearFocus() end
                    frame.notepadEditBox:EnableMouse(movable)
                    frame.notepadEditBox:EnableKeyboard(movable)
                end
                if frame.notepadScrollbar then
                    SetFrameTreeMouseEnabled(frame.notepadScrollbar, movable)
                end
            end,
        },
        surface = { frameBorder = "body" },
        frameHeader = {
            visibility = controlPanelVisibility,
            position = headerPosition,
            width = { mode = "content" },
            controls = { lock = true },
        },
    })
    self.groupFrames[groupId] = window
    self:ApplyGroupFrameLayer(window)
    local headerAnchors = { top = "right", left = "top", bottom = "left", right = "top" }
    window:SetFrameHeaderPosition(headerPosition, headerAnchors[headerPosition])
    if window.frameHeader and window.frameHeader.HookScript then
        window.frameHeader:HookScript("OnMouseUp", function(header, button)
            if button == "RightButton" then
                self:ShowGroupContextMenu(groupId, header)
            end
        end)
    end
    self:RenameGroupFrame(groupId)
    if groupId == 1 then self.mainGroup = window end
    window:SetShown(HUDCraftCharDB.groupsEnabled[groupId] ~= false)
    if config.kind == "notepad" then
        HUDCraftCharDB.notepadTexts = type(HUDCraftCharDB.notepadTexts) == "table"
            and HUDCraftCharDB.notepadTexts or {}

        local function GetNotepadText()
            if config.noteScope == "account" then return config.noteText or "" end
            return HUDCraftCharDB.notepadTexts[groupId] or ""
        end
        local function SaveNotepadText(text)
            if config.noteScope == "account" then
                config.noteText = text
            else
                HUDCraftCharDB.notepadTexts[groupId] = text
            end
        end
        local styles = self.UI.WindowStyles
        local surface = self.UI.SettingsControls:CreateCustomMultilineTextInput(window.content, {
            insets={left=5, top=5, right=5, bottom=5},
            -- Text inset plus the slim scrollbar's 2-unit lane gap gives the
            -- established 5-unit visual clearance between text and scrollbar.
            textInsets={left=6, right=3, top=6, bottom=6},
            text=GetNotepadText(),
            scrollbar={variant="slim"},
            textColorRole=false,
            caretWidth=1,
            onTextChanged=function(box, userInput)
                if userInput then SaveNotepadText(box:GetText()) end
            end,
            onVisibleTextCreated=function(text)
                local function ApplyNotepadTextColor(target)
                    local colorFactory = self.UI.ColorFactory
                    local overrides = HUDCraftDB.styles and HUDCraftDB.styles.groupOverrides
                    local colors = overrides and overrides.colors
                    local opacity = overrides and overrides.opacity
                    local customColor = type(colors) == "table" and colors.notepadText
                    local alpha = math.max(0, math.min(100,
                        tonumber(type(opacity) == "table" and opacity.notepadText) or 100)) / 100
                    local red, green, blue
                    local styleAlpha = 1
                    if type(customColor) == "string" and customColor:match("^#%x%x%x%x%x%x$") then
                        red, green, blue = colorFactory.ToRGBA(customColor)
                    else
                        local group = HUDCraftDB.groups.byId[groupId]
                        local presetName = group and group.useGlobalStyle == false
                            and group.customStyle or HUDCraftDB.styles.groups
                        local preset = styles.Presets[presetName] or styles.Presets[styles.DefaultPreset]
                        if preset then
                            local color = styles:ResolveColor(preset.textMainColor, preset)
                            if color then
                                red, green, blue = color[1], color[2], color[3]
                                styleAlpha = color[4] or 1
                            end
                        end
                    end
                    if red then target:SetTextColor(red, green, blue, styleAlpha * alpha) end
                end
                styles:RegisterVisual(text, ApplyNotepadTextColor)
                ApplyNotepadTextColor(text)
            end,
        })
        local scrollFrame, editBox = surface.scrollFrame, surface.editBox
        local slimScrollbar = surface.scrollbar
        window.notepadInputSurface = surface
        window.notepadEditBox = editBox

        window.SetNotepadTextSize = function(_, size)
            size = tonumber(size)
            if not size or size < 10 or size > 20 or size % 2 ~= 0 then return end
            local fontTargets = { editBox, surface.visibleText, surface.measureText }
            for _, fontTarget in ipairs(fontTargets) do
                if fontTarget and fontTarget.GetFont and fontTarget.SetFont then
                    local fontPath, _, fontFlags = fontTarget:GetFont()
                    if fontPath then fontTarget:SetFont(fontPath, size, fontFlags or "") end
                end
            end
            if surface.caret then surface.caret:SetHeight(size) end
            if surface.QueueGeometry then surface:QueueGeometry() end
        end
        window:SetNotepadTextSize(tonumber(config.notepadTextSize) or 12)

        local function SetNotepadEditingBorder(editing)
            if not editing then
                window:SetSurfaceOptions({})
                return
            end
            local color = styles:GetWindowInteractionColor(window)
            window:SetSurfaceOptions({
                border = { color = { color[1], color[2], color[3] }, opacity = (color[4] or 1) * 100 },
                hoverBorder = { color = { color[1], color[2], color[3] }, opacity = (color[4] or 1) * 100 },
                interactionBorder = { color = { color[1], color[2], color[3] }, opacity = (color[4] or 1) * 100 },
            })
        end
        window.RefreshNotepadSurface = function()
            SetNotepadEditingBorder(editBox:HasFocus())
        end
        editBox:HookScript("OnEditFocusGained", function(target)
            if not window:GetMovableEnabled() then
                target:ClearFocus()
                SetNotepadEditingBorder(false)
                return
            end
            SetNotepadEditingBorder(true)
        end)
        editBox:HookScript("OnEditFocusLost", function()
            SetNotepadEditingBorder(false)
        end)
        window.notepadScrollFrame = scrollFrame
        window.notepadScrollbar = slimScrollbar
        editBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
        local isMovable = window:GetMovableEnabled()
        window:SetResizeEnabled(isMovable)
        SetFrameTreeMouseEnabled(window.notepadScrollbar, isMovable)
        surface:SetInputEnabled(isMovable)
        if not isMovable then editBox:ClearFocus() end
    else
        self.groupRenderers[groupId] = self.GroupRenderer:Create(window.content, {
            groupId = groupId,
            orientation = self:GetGroupDirection(groupId),
            fontSize = tonumber(HUDCraftDB.general.fontSize) or 14,
            horizontalGap = math.max(0, tonumber(HUDCraftDB.general.spacing) or 6),
            verticalGap = math.max(0, tonumber(HUDCraftDB.general.spacing) or 6),
            padding = 5,
            onSizeChanged = function(width, height)
                window:SetExpandedSize(width + 2, height + 2)
            end,
            onModuleEnter = function(module, source)
                self:ShowGroupModuleDetails(groupId, module, source)
            end,
            onModuleLeave = function()
                self:ScheduleGroupDetailsHide(groupId)
            end,
        })
    end
    window:HookScript("OnHide", function()
        local details = self.groupDetails and self.groupDetails[groupId]
        if details then details:Hide() end
    end)
    window:HookScript("OnShow", function() self:RefreshGroup(groupId) end)
    if config.kind ~= "notepad" then self:RefreshGroup(groupId) end
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
    if self.moduleContextMenus and self.moduleContextMenus[groupId] then
        self.moduleContextMenus[groupId]:Hide()
        self.moduleContextMenus[groupId] = nil
    end
    if self.groupContextMenus and self.groupContextMenus[groupId] then
        self.groupContextMenus[groupId]:Hide()
        self.groupContextMenus[groupId] = nil
    end
    self.groupStyleOwners[groupId] = nil
    for _, stateKey in ipairs({ "windowPositions", "windowCollapsed", "windowSizes", "frameHeaderPositions", "groupsLocked" }) do
        if HUDCraftCharDB[stateKey] then HUDCraftCharDB[stateKey][groupId] = nil end
    end
    HUDCraftCharDB.groupsEnabled[groupId] = nil
    if HUDCraftCharDB.notepadTexts then HUDCraftCharDB.notepadTexts[groupId] = nil end
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
        if type(currentGroup) == "table" and currentGroup.kind ~= "notepad" then
            groupCount = groupCount + 1
        end
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
    self:CreateGroupFrame(groupId)
    return groupId
end

function addon:CreateNotepad(scope)
    if scope ~= "account" and scope ~= "character" then return nil end
    local groups = HUDCraftDB.groups
    groups.byId = type(groups.byId) == "table" and groups.byId or {}
    groups.order = type(groups.order) == "table" and groups.order or {}
    local groupId = tonumber(groups.nextId)
    if not groupId or groupId < 1 or groupId ~= math.floor(groupId) then
        groupId = 1
        for existingId in pairs(groups.byId) do
            if type(existingId) == "number" and existingId >= groupId then
                groupId = existingId + 1
            end
        end
    end
    while groups.byId[groupId] do groupId = groupId + 1 end
    local noteNameIndex = 1
    local nameInUse = true
    while nameInUse do
        nameInUse = false
        local candidate = "Notepad " .. tostring(noteNameIndex)
        for _, group in pairs(groups.byId) do
            if type(group) == "table" and group.name == candidate then
                nameInUse = true
                noteNameIndex = noteNameIndex + 1
                break
            end
        end
    end
    local notepad = {
        id = groupId,
        name = "Notepad " .. tostring(noteNameIndex),
        kind = "notepad",
        noteScope = scope,
        builtIn = false,
        editable = true,
        selectedModules = {},
        moduleOrder = {},
        useGlobalStyle = true,
    }
    if scope == "account" then notepad.noteText = "" end
    groups.byId[groupId] = notepad
    groups.order[#groups.order + 1] = groupId
    groups.nextId = groupId + 1
    groups.initialized = true
    HUDCraftCharDB.groupsEnabled[groupId] = true
    HUDCraftCharDB.notepadTexts = type(HUDCraftCharDB.notepadTexts) == "table"
        and HUDCraftCharDB.notepadTexts or {}
    if scope == "character" then
        HUDCraftCharDB.notepadTexts[groupId] = HUDCraftCharDB.notepadTexts[groupId] or ""
    end
    self:CreateGroupFrame(groupId)
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
    if config and config.kind == "notepad" then return end
    if not window or not renderer or not config then return end
    config.selectedModules = type(config.selectedModules) == "table" and config.selectedModules or {}
    config.moduleOrder = type(config.moduleOrder) == "table" and config.moduleOrder or {}
    local detailsEnabled = config.detailsEnabled ~= false
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
        signatureParts[#signatureParts + 1] = HasValidInteraction(module, detailsEnabled) and "i" or "n"
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
                    module = part.module or (part.showDetails and module or nil),
                    display = part.display,
                    showDetails = part.showDetails == true and detailsEnabled,
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

function addon:RecoverGroup(argument)
    local groups = HUDCraftDB and HUDCraftDB.groups
    local byId = groups and groups.byId or {}
    local order = groups and groups.order or {}
    local query = tostring(argument or ""):match("^%s*(.-)%s*$")
    local lines = {}
    if query == "" then
        lines[#lines + 1] = "Use /hudcraft recover <name or ID> to center and unlock one Group."
        for _, groupId in ipairs(order) do
            local group = byId[groupId]
            if group then
                local disabled = HUDCraftCharDB.groupsEnabled[groupId] == false
                lines[#lines + 1] = string.format("ID %s — %s%s", tostring(groupId),
                    tostring(group.name or "Unnamed"), disabled and " (disabled)" or "")
            end
        end
        lines[#lines + 1] = "Use id:<number> if a name and ID match."
        return lines
    end

    local explicitId = query:lower():match("^id:(%d+)$")
    local quotedName = query:match('^"(.*)"$')
    local numericId = not quotedName and tonumber(explicitId or query) or nil
    local matches = {}
    for _, groupId in ipairs(order) do
        local group = byId[groupId]
        if group then
            local nameMatches = not explicitId and tostring(group.name or ""):lower()
                == (quotedName or query):lower()
            local idMatches = numericId and tonumber(groupId) == numericId
            if nameMatches or idMatches then
                matches[#matches + 1] = { id = groupId, name = group.name }
            end
        end
    end
    if #matches == 0 then
        return { "No Group matches " .. string.format("%q", query) .. ". Use /hudcraft recover to list Groups." }
    end
    if #matches > 1 then
        lines[#lines + 1] = "Several Groups match. Use /hudcraft recover id:<number>."
        for _, match in ipairs(matches) do
            lines[#lines + 1] = string.format("ID %s — %s", tostring(match.id), tostring(match.name or "Unnamed"))
        end
        return lines
    end

    local groupId = matches[1].id
    if HUDCraftCharDB.groupsEnabled[groupId] == false then
        return { "That Group is disabled for this character. Enable it in Settings first." }
    end
    if InCombatLockdown and InCombatLockdown() then
        return { "Group recovery is unavailable during combat. Try again afterward." }
    end
    local frame = self.groupFrames and self.groupFrames[groupId]
    if not frame then return { "The Group frame is unavailable. Try /reload first." } end

    if frame.SetCollapsed then frame:SetCollapsed(false) end
    self:SetGroupLocked(groupId, false)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    HUDCraftCharDB.windowPositions = type(HUDCraftCharDB.windowPositions) == "table"
        and HUDCraftCharDB.windowPositions or {}
    HUDCraftCharDB.windowPositions[groupId] = {
        point = "CENTER", relativePoint = "CENTER", x = 0, y = 0,
    }
    frame:BringToFront()
    return { string.format("Recovered %s (ID %s) to screen center and unlocked it. Drag it into place.",
        tostring(matches[1].name or "Unnamed"), tostring(groupId)) }
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
