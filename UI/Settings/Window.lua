local addonName, addon = ...

local PAGES = {
    {
        id = "main",
        title = "Main",
        subpages = {
            { id = "welcome", title = "Welcome" },
            { id = "global-styles", title = "Global Styles" },
        },
    },
    { id = "style", title = "Style", subpages = { { id = "overrides", title = "Style Overrides" } } },
    { id = "groups", title = "Groups", subpages = {
        { id = "group-creation", title = "Group Creation" },
        { id = "group-management", title = "Group Management" },
        { id = "module-settings", title = "Module Settings" },
    } },
}

-- SettingsPageHost owns the scroll frame, content measurement, popup reserve,
-- and scrollbar lifecycle. Keep a small body Section around each consumer flow
-- so the host can measure every existing page layout through its normal API.
local function CreateHostedPage(ui, parent, layout, pageId)
    local host = ui.SettingsPageHost:CreateEmbedded(parent, pageId)
    local body = layout:Section(host.content, pageId .. "-body", { border = false })
    local row = layout:Row(body, pageId .. "-body-row", { flow = true })
    layout:AddContent(body, row, { fillWidth = true })
    local flow = layout:Container(row, pageId .. "-body-flow")
    layout:AddContent(row, flow, { fillWidth = true })
    return host, flow
end

local function BindHostedPage(ui, host)
    ui.SettingsPageHost:BindSections(host)
    if host.ScheduleMeasure then host.ScheduleMeasure() end
end

StaticPopupDialogs["HUDCRAFT_DELETE_GROUP"] = {
    text = "Delete the group \"%s\"?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, groupId)
        if addon:DeleteGroup(groupId) then
            if addon.groupCreationRefresh then addon.groupCreationRefresh() end
            if addon.groupManagementRefresh then addon.groupManagementRefresh() end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function addon:CreateSettingsWindow()
    local ui = self.UI
    local geometry = ui.WindowStyles.GeometryDefaults or {}
    local navGap = tonumber(geometry.navigationGap) or 10
    local mainHeight = tonumber(geometry.navigationItemHeight) or 28
    local subpageHeight = tonumber(geometry.navigationItemHeight) or 28
    ui.WindowStyles:SetConsumerPreset(self.name, HUDCraftDB.styles.settings)
    local window = ui.WindowFrame:Create({
        id = "settings",
        title = "hudcraft",
        owner = self.name,
        sizing = {
            initial = { width = 620, height = 440 },
            minimum = { width = 400, height = 500 },
            position = { x = -290, y = 0 },
        },
        interaction = { resize = { corner = true } },
        frameHeader = { controls = { close = true, minimize = true } },
    })
    self.settingsWindow = window

    local escapeFrameName = "HUDCraftSettingsWindow"
    _G[escapeFrameName] = window
    if type(UISpecialFrames) == "table" then
        local alreadyRegistered = false
        for _, registeredName in ipairs(UISpecialFrames) do
            if registeredName == escapeFrameName then
                alreadyRegistered = true
                break
            end
        end
        if not alreadyRegistered then
            UISpecialFrames[#UISpecialFrames + 1] = escapeFrameName
        end
    end

    local mainNavigation = CreateFrame("Frame", nil, window.content)
    mainNavigation:SetPoint("TOPLEFT", window.content, "TOPLEFT", 0, 0)
    mainNavigation:SetPoint("TOPRIGHT", window.content, "TOPRIGHT", 0, 0)
    mainNavigation:SetHeight(mainHeight + (tonumber(geometry.navigationEdgeInset) or 5))

    local subpageNavigation = CreateFrame("Frame", nil, window.content)
    subpageNavigation:SetPoint("TOPLEFT", mainNavigation, "BOTTOMLEFT", 0, -navGap)
    subpageNavigation:SetPoint("TOPRIGHT", mainNavigation, "BOTTOMRIGHT", 0, -navGap)
    subpageNavigation:SetHeight(subpageHeight)

    local pageArea = CreateFrame("Frame", nil, window.content)
    pageArea:SetPoint("TOPLEFT", subpageNavigation, "BOTTOMLEFT", 0, -2)
    pageArea:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", 0, 0)

    local mainButtons, subpageButtons, pageFrames = {}, {}, {}
    for _, page in ipairs(PAGES) do
        local pageId = page.id
        local defaultSubpageId = page.subpages[1].id
        pageFrames[pageId] = {}
        subpageButtons[pageId] = {}
        for _, subpage in ipairs(page.subpages) do
            local subpageId = subpage.id
            local content = CreateFrame("Frame", nil, pageArea)
            content:SetAllPoints(pageArea)
            content:Hide()
            if pageId == "main" and subpageId == "welcome" then
                local layout = ui.SettingsLayout
                local controls = ui.SettingsControls
                local host, flow = CreateHostedPage(ui, content, layout, "hudcraft-welcome")
                local scroll, pageContent, scrollbar = host.scroll, host.content, host.scrollbar
                flow.layoutHorizontalAlign = "CENTER"
                local centeredHeaders = {}

                local function AddAreaHeader(parent, text, centered)
                    local label, underline
                    if centered then
                        label, underline = layout:AreaHeader(parent, text, { justifyH = "CENTER" })
                    else
                        label, underline = layout:AreaHeader(parent, text)
                    end
                    if not label or not underline then return end
                    if centered then
                        centeredHeaders[#centeredHeaders + 1] = { label = label, underline = underline }
                    end
                    return label, underline
                end
                local function AddHeader(parent, text)
                    return AddAreaHeader(parent, text, false)
                end
                local function AddCenteredHeader(parent, text)
                    return AddAreaHeader(parent, text, true)
                end
                local function RecenterUnderlines()
                    for _, header in ipairs(centeredHeaders) do
                        local label, underline = header.label, header.underline
                        local availableWidth = math.max(1, label:GetWidth() or 1)
                        local measuredWidth = tonumber(label:GetStringWidth()) or availableWidth
                        local lineWidth = math.max(1, math.min(availableWidth, measuredWidth))
                        local point, relativeTo, relativePoint, _, yOffset = underline:GetPoint(1)
                        if point then
                            underline:ClearAllPoints()
                            underline:SetPoint(point, relativeTo, relativePoint,
                                (availableWidth - lineWidth) / 2, yOffset)
                            underline:SetWidth(lineWidth)
                        end
                    end
                end
                local function AddText(parent, text, isNote, justifyH)
                    local item
                    if isNote then
                        item = layout:Note(parent, text, { justifyH = justifyH })
                    else
                        item = layout:Text(parent, text, { justifyH = justifyH })
                    end
                    layout:AddContent(parent, item, { fillWidth = true, wrap = true })
                    return item
                end
                local function AddAction(parent, label, callback)
                    local actionRow = layout:Row(parent, "hudcraft-discord-action-row", { flow = true })
                    local actionColumn = layout:Columns(actionRow, 1, { "discord-action" }, {
                        horizontalAlign = "CENTER",
                    })[1]
                    local item = controls.AddActionButtonContent(actionColumn, label, callback, {
                        widthMode = "auto",
                        autoHeight = true,
                    })
                    layout:AddContent(actionColumn, item, {
                        role = "button",
                        fillWidth = false,
                    })
                    return item
                end
                local function AddTwoColumns(parent, id, leftId, rightId)
                    local row = layout:Row(parent, id, { flow = true })
                    local columns = layout:Columns(row, 2, { leftId, rightId })
                    return columns[1], columns[2]
                end
                local function NewSection(id, title, summary, centered)
                    local section = layout:BorderedSection(flow, id, {
                        treatment = "rounded",
                        edgeSize = 24,
                        borderColor = "interactionAccent_4",
                    })
                    layout:AddContent(flow, section, {
                        fillWidth = true,
                        maxWidth = 1000,
                    })
                    local titleHeader
                    if centered then
                        titleHeader = AddCenteredHeader(section, title)
                    else
                        titleHeader = AddHeader(section, title)
                    end
                    if summary then
                        AddText(section, summary, true, centered and "CENTER" or nil)
                    end
                    return section
                end

                local addonInfo = NewSection("addon-information", "Addon Information")
                AddText(addonInfo,
                    "hudcraft is a lightweight information HUD for WoW Forever. It works " ..
                    "alongside your existing interface, focusing on useful information " ..
                    "without replacing your UI.\n\n", false)
                local brushfire = ui.WindowStyles.Presets["Brushfire"]
                local authorColor = brushfire
                    and ui.WindowStyles:ResolveColor("interactionAccent_4", brushfire)
                if type(authorColor) == "table" then
                    local red = math.floor((tonumber(authorColor[1]) or 1) * 255 + 0.5)
                    local green = math.floor((tonumber(authorColor[2]) or 0) * 255 + 0.5)
                    local blue = math.floor((tonumber(authorColor[3]) or 0) * 255 + 0.5)
                    AddText(addonInfo, string.format("Developed by |cff%02x%02x%02xTreebeardCreative|r.\n\n",
                        red, green, blue), false)
                else
                    AddText(addonInfo, "Developed by TreebeardCreative.\n\n", false)
                end

                local settingsColumn, groupsColumn = AddTwoColumns(addonInfo,
                    "addon-information-row", "settings-characters", "groups-modules")
                AddHeader(settingsColumn, "Settings and Characters")
                AddText(settingsColumn,
                    "Group definitions are shared across your account. Visibility and " ..
                    "positions are saved per character. Notepads can keep text account-wide " ..
                    "or per character.\n\n")
                AddHeader(groupsColumn, "Groups and Modules")
                AddText(groupsColumn,
                    "Groups are compact HUD displays for selected information. Choose " ..
                    "modules, arrange their order, and set each Group's layout and behavior.\n\n")

                local feedbackColumn, communityColumn = AddTwoColumns(addonInfo,
                    "support-row", "feedback-bugs", "community")
                AddHeader(feedbackColumn, "Feedback and Bugs")
                AddText(feedbackColumn,
                    "If something looks wrong or behaves unexpectedly, report what you were " ..
                    "doing and what you expected to happen.\n\n")
                AddHeader(communityColumn, "Community")
                AddText(communityColumn,
                    "Join the hudcraft Discord to share suggestions, report issues, and " ..
                    "follow development.\n\n")
                local discordUrl = "https://discord.gg/q3ey4Bbqeh"
                local discordBrowser = {
                    OpenExternalLink = function() LaunchURL(discordUrl) end,
                    CopyExternalLink = function() CopyToClipboard(discordUrl) end,
                }
                AddAction(communityColumn, "Join the Discord", function()
                    StaticPopup_Show("EXTERNAL_LINK", discordUrl, nil, {
                        url = discordUrl,
                        browser = discordBrowser,
                    })
                end)

                local versionSection = NewSection("version-installation",
                    "Version & Installation", "Current build information for troubleshooting.", true)
                AddCenteredHeader(versionSection, "Installed Build")
                local installedVersion = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
                AddText(versionSection,
                    "Current hudcraft version: " .. tostring(installedVersion) .. "\n" ..
                    "Client: WoW Forever 1.60.1\n" ..
                    "When reporting a bug or sharing feedback, include your installed version.",
                    false, "CENTER")

                local commandSection = NewSection("chat-commands", "Chat Commands",
                    nil, true)
                AddText(commandSection, table.concat(self.commandHelpLines or {}, "\n"), false, "CENTER")

                BindHostedPage(ui, host)
                local recenterUpdate = ui.SettingsPageMeasure:Create(content, RecenterUnderlines, { passes = 4 })
                scroll:HookScript("OnSizeChanged", recenterUpdate)
                content:HookScript("OnShow", recenterUpdate)
                recenterUpdate()
            elseif pageId == "main" and subpageId == "global-styles" then
                local layout = ui.SettingsLayout
                local controls = ui.SettingsControls
                local styles = ui.WindowStyles
                local host, flow = CreateHostedPage(ui, content, layout, "hudcraft-global-styles")
                local scroll, pageContent, scrollbar = host.scroll, host.content, host.scrollbar
                flow.layoutHorizontalAlign = "CENTER"

                local function AddHeader(parent, text)
                    return layout:AreaHeader(parent, text)
                end
                local function AddControl(parent, control, role)
                    layout:AddContent(parent, control, { role = role, fillWidth = true, wrap = true })
                    return control
                end
                local function AddColumns(parent, id, leftId, rightId)
                    local row = layout:Row(parent, id, { flow = true })
                    return layout:Columns(row, 2, { leftId, rightId })
                end
                local function NewSection(id, title)
                    local section = layout:Section(flow, "hudcraft-global-styles-" .. id, {
                        border = false,
                    })
                    layout:AddContent(flow, section, { fillWidth = true, maxWidth = 1000 })
                    AddHeader(section, title)
                    return section
                end
                local styleNames, seenStyles = {}, {}
                for _, name in ipairs({ "Brushfire", "Embersteel", "Warm Warcraft" }) do
                    if styles.Presets[name] then
                        styleNames[#styleNames + 1] = name
                        seenStyles[name] = true
                    end
                end
                local additionalStyles = {}
                for name in pairs(styles.Presets) do
                    if not seenStyles[name] and not self:IsGroupStyleOverridePreset(name) then
                        additionalStyles[#additionalStyles + 1] = name
                    end
                end
                table.sort(additionalStyles)
                for _, name in ipairs(additionalStyles) do styleNames[#styleNames + 1] = name end
                local styleOptions = {}
                for _, name in ipairs(styleNames) do
                    styleOptions[#styleOptions + 1] = { name = name, value = name }
                end

                local styleSection = NewSection("styles", "Styles")
                local styleColumns = AddColumns(styleSection, "style-selectors",
                    "settings-style", "group-style")
                AddControl(styleColumns[1], controls.AddDropdownContent(styleColumns[1],
                    "Settings panel style", styleOptions,
                    function()
                        local current = HUDCraftDB.styles.settings
                        return styles.Presets[current] and current or styles.DefaultPreset
                    end,
                    function(value)
                        if not styles.Presets[value] then return end
                        HUDCraftDB.styles.settings = value
                        styles:SetConsumerPreset(self.name, value)
                    end), "dropdown")

                AddControl(styleColumns[2], controls.AddDropdownContent(styleColumns[2],
                    "Group style", styleOptions,
                    function()
                        local current = HUDCraftDB.styles.groups
                        return styles.Presets[current] and current or styles.DefaultPreset
                    end,
                    function(value)
                        if not styles.Presets[value] then return end
                        HUDCraftDB.styles.groups = value
                        self:ApplyAllGroupAppearances()
                        ui:RefreshAll()
                    end), "dropdown")

                local controlsSection = NewSection("groups", "Groups")
                local controlsColumns = AddColumns(controlsSection, "control-options",
                    "frame-layer", "group-text-size")

                local frameLayers = {
                    { name = "1 — Background", value = 1 },
                    { name = "2 — Low", value = 2 },
                    { name = "3 — Medium", value = 3 },
                    { name = "4 — High", value = 4 },
                    { name = "5 — Dialog", value = 5 },
                }
                AddControl(controlsColumns[1], controls.AddDropdownContent(controlsColumns[1],
                    "Group frame level", frameLayers,
                    function() return HUDCraftDB.general.groupFrameLayer or 3 end,
                    function(value)
                        HUDCraftDB.general.groupFrameLayer = value
                        self:ApplyAllGroupFrameLayers()
                    end), "dropdown")

                local fontSizes = {}
                for _, size in ipairs({ 10, 11, 12, 13, 14, 16, 18, 20, 22, 24 }) do
                    fontSizes[#fontSizes + 1] = { name = tostring(size), value = size }
                end
                AddControl(controlsColumns[2], controls.AddDropdownContent(controlsColumns[2],
                    "Group text size", fontSizes,
                    function() return HUDCraftDB.general.fontSize or 14 end,
                    function(value)
                        HUDCraftDB.general.fontSize = value
                        self:RefreshAllGroups()
                    end), "dropdown")

                local clockSources = {
                    { name = "Local time", value = "local" },
                    { name = "Realm time", value = "realm" },
                }
                AddControl(controlsSection, controls.AddDropdownContent(controlsSection,
                    "Clock time source", clockSources,
                    function() return HUDCraftDB.general.clockSource or "local" end,
                    function(value)
                        if value ~= "local" and value ~= "realm" then return end
                        HUDCraftDB.general.clockSource = value
                        self:RefreshAllGroups({ "clock" })
                    end), "dropdown")

                local separatorSection = NewSection("separators", "Separators")
                local separatorColumns = AddColumns(separatorSection, "separator-options",
                    "horizontal-separator", "vertical-separator")
                local separatorStyles = {
                    { name = "None", value = "" },
                    { name = "Dash (-)", value = "-" },
                    { name = "Bar (|)", value = "|" },
                }
                AddControl(separatorColumns[1], controls.AddDropdownContent(separatorColumns[1],
                    "Horizontal separator", separatorStyles,
                    function() return HUDCraftDB.general.horizontalSeparator end,
                    function(value)
                        HUDCraftDB.general.horizontalSeparator = value
                        self:RefreshAllGroups()
                    end), "dropdown")
                AddControl(separatorColumns[2], controls.AddDropdownContent(separatorColumns[2],
                    "Vertical separator", separatorStyles,
                    function() return HUDCraftDB.general.verticalSeparator end,
                    function(value)
                        HUDCraftDB.general.verticalSeparator = value
                        self:RefreshAllGroups()
                    end), "dropdown")

                BindHostedPage(ui, host)
            elseif pageId == "style" and subpageId == "overrides" then
                local layout = ui.SettingsLayout
                local controls = ui.SettingsControls
                local styles = ui.WindowStyles
                local colorFactory = ui.ColorFactory
                local host, flow = CreateHostedPage(ui, content, layout, "hudcraft-style-overrides")
                local scroll, pageContent, scrollbar = host.scroll, host.content, host.scrollbar
                flow.layoutHorizontalAlign = "CENTER"

                local function AddHeader(parent, text)
                    return layout:AreaHeader(parent, text)
                end
                local section = layout:Section(flow, "hudcraft-group-style-overrides", {
                    border = true,
                })
                layout:AddContent(flow, section, { fillWidth = true, maxWidth = 1000 })
                AddHeader(section, "Group Style Overrides")

                local overrides = HUDCraftDB.styles.groupOverrides
                local function GetCurrentGroupBaseColor(key)
                    local base = styles.Presets[HUDCraftDB.styles.groups]
                        or styles.Presets[styles.DefaultPreset]
                    if not base then return colorFactory.ToHex(colorFactory.white) end
                    local value
                    if key == "text" then
                        value = styles:ResolveColor(base.textInteractionAccentColor, base)
                    elseif key == "border" then
                        value = styles:GetWindowBorderColor(base)
                    elseif key == "interaction" then
                        value = styles:GetWindowInteractionColor(base)
                    else
                        value = styles:GetMainCanvasColor(base)
                    end
                    return colorFactory.ToHex(value) or colorFactory.ToHex(colorFactory.white)
                end
                local function GetOverrideColor(key)
                    local saved = overrides.colors[key]
                    if type(saved) == "string" and saved:match("^#%x%x%x%x%x%x$") then
                        return saved
                    end
                    return GetCurrentGroupBaseColor(key)
                end
                local function SetOverrideColor(key, value)
                    if type(value) ~= "string" or not value:match("^#%x%x%x%x%x%x$") then
                        return false
                    end
                    overrides.colors[key] = value:upper()
                    return true
                end
                local function GetOverrideOpacity(key)
                    return math.max(0, math.min(100, tonumber(overrides.opacity[key]) or 100))
                end
                local function SetOverrideOpacity(key, value)
                    value = tonumber(value)
                    if not value or value < 0 or value > 100 then return end
                    overrides.opacity[key] = math.floor(value + 0.5)
                    self:ApplyAllGroupAppearances()
                end

                local opacityValues = {}
                for value = 0, 100, 5 do opacityValues[#opacityValues + 1] = value end
                local function FormatOpacity(value) return tostring(value) .. "%" end
                local overrideRows = {
                    { key = "text", colorLabel = "Group text color", opacityLabel = "Group text opacity" },
                    { key = "border", colorLabel = "Border color", opacityLabel = "Border opacity" },
                    { key = "interaction", colorLabel = "Interaction color", opacityLabel = "Interaction opacity" },
                    { key = "background", colorLabel = "Background color", opacityLabel = "Background opacity" },
                }
                for _, rowDefinition in ipairs(overrideRows) do
                    local row = layout:Row(section,
                        "hudcraft-group-style-override-" .. rowDefinition.key, { flow = true })
                    local columns = layout:Columns(row, 2, {
                        rowDefinition.key .. "-color",
                        rowDefinition.key .. "-opacity",
                    })
                    local colorInput = controls.AddHexColorContent(columns[1], rowDefinition.colorLabel,
                        function() return GetOverrideColor(rowDefinition.key) end,
                        function(value) return SetOverrideColor(rowDefinition.key, value) end,
                        function() self:ApplyAllGroupAppearances() end)
                    colorInput.editBox:SetMaxLetters(7)
                    layout:AddContent(columns[1], colorInput, { role = "color", fillWidth = true })

                    local opacitySlider = controls.AddSteppedSlider(columns[2],
                        rowDefinition.opacityLabel, opacityValues, 0, 0,
                        function() return GetOverrideOpacity(rowDefinition.key) end,
                        function(value) SetOverrideOpacity(rowDefinition.key, value) end,
                        FormatOpacity)
                    layout:AddContent(columns[2], opacitySlider, { role = "slider", fillWidth = true })
                end

                local resetRow = layout:Row(section, "hudcraft-clear-group-overrides-row", { flow = true })
                local resetColumns = layout:Columns(resetRow, 2, {
                    "hudcraft-clear-group-overrides-button",
                    "hudcraft-clear-group-overrides-spacer",
                }, {
                    horizontalAlignments = { "CENTER", "CENTER" },
                    verticalAlignments = { "CENTER", "CENTER" },
                })
                local clearOverridesButton = controls.AddActionButtonContent(
                    resetColumns[1], "Clear Group Overrides", function()
                        for key in pairs(overrides.colors) do overrides.colors[key] = nil end
                        for key in pairs(overrides.opacity) do overrides.opacity[key] = nil end
                        self:ApplyAllGroupAppearances()
                        ui:RefreshAll()
                    end, { widthMode = "auto" })
                layout:AddContent(resetColumns[1], clearOverridesButton, { role = "button" })

                BindHostedPage(ui, host)
            elseif pageId == "groups" and subpageId == "group-creation" then
                local layout = ui.SettingsLayout
                local controls = ui.SettingsControls
                local metrics = layout.Metrics
                local host, flow = CreateHostedPage(ui, content, layout, "hudcraft-group-creation")
                local scroll, pageContent, scrollbar = host.scroll, host.content, host.scrollbar
                flow.layoutHorizontalAlign = "CENTER"

                local managementPanel = layout:Container(flow, "hudcraft-group-creation-panel")
                layout:AddContent(flow, managementPanel, { fillWidth = true, maxWidth = 1000 })

                local groupsSection = layout:Section(managementPanel, "hudcraft-group-creation-list", {
                    border = false,
                })
                layout:AddContent(managementPanel, groupsSection, { fillWidth = true })
                local actionsSection = layout:Section(managementPanel, "hudcraft-group-creation-actions", {
                    border = false,
                })
                layout:AddContent(managementPanel, actionsSection, { fillWidth = true })
                local notepadsSection = layout:Section(managementPanel, "hudcraft-notepad-creation-list", {
                    border = false,
                })
                layout:AddContent(managementPanel, notepadsSection, { fillWidth = true })
                local notepadActionsSection = layout:Section(managementPanel, "hudcraft-notepad-creation-actions", {
                    border = false,
                })
                layout:AddContent(managementPanel, notepadActionsSection, { fillWidth = true })
                layout:AreaHeader(groupsSection, "Groups")
                layout:AreaHeader(notepadsSection, "Notepads")
                local groupRows, groupInputs = {}, {}
                local notepadRows, notepadInputs = {}, {}

                local function CreateGroupRow(groupId, group)
                    local isNotepad = group.kind == "notepad"
                    local parent = isNotepad and notepadsSection or groupsSection
                    local row = layout:Row(parent, (isNotepad and "hudcraft-notepad-row-" or "hudcraft-group-row-") .. tostring(groupId), {
                        flow = true,
                    })
                    local scopeLabel = isNotepad
                        and (group.noteScope == "account" and "[Account-Wide]" or "[Per-Character]") or ""
                    local scopeText
                    local columnIds, widths, horizontalAlignments, verticalAlignments, minHeights
                    if isNotepad then
                        scopeText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                        scopeText:SetJustifyH("LEFT")
                        scopeText:SetText(scopeLabel)
                        columnIds = { "notepad-scope-" .. tostring(groupId),
                            "notepad-name-" .. tostring(groupId), "notepad-delete-" .. tostring(groupId) }
                        widths = { math.max(1, math.ceil(scopeText:GetStringWidth() or 1)), nil, 22 }
                        horizontalAlignments = { "LEFT", "LEFT", "CENTER" }
                        verticalAlignments = { "CENTER", "CENTER", "CENTER" }
                        minHeights = { 24, 24, 24 }
                    else
                        columnIds = { "group-name-" .. tostring(groupId), "group-delete-" .. tostring(groupId) }
                        widths = { nil, 22 }
                        horizontalAlignments = { "LEFT", "CENTER" }
                        verticalAlignments = { "CENTER", "CENTER" }
                        minHeights = { 24, 24 }
                    end
                    local entryColumns = layout:Columns(row, #columnIds, columnIds, {
                        widths = widths,
                        horizontalAlignments = horizontalAlignments,
                        verticalAlignments = verticalAlignments,
                        minHeights = minHeights,
                    })
                    local nameColumn = isNotepad and entryColumns[2] or entryColumns[1]
                    local deleteColumn = isNotepad and entryColumns[3] or entryColumns[2]
                    if scopeText then
                        layout:AddContent(entryColumns[1], scopeText, { role = "notes" })
                    end

                    local nameInput = controls.AddTextInputContent(nameColumn, "",
                        function() return self:GetGroupName(groupId) end,
                        function(value)
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current then return false end
                            local name = tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
                            current.name = name
                            self:RenameGroupFrame(groupId)
                            if self.groupManagementRefresh then self.groupManagementRefresh() end
                            if host.ScheduleMeasure then host.ScheduleMeasure() end
                            return true
                        end)
                    nameInput.label:Hide()
                    nameInput.editBox:ClearAllPoints()
                    nameInput.editBox:SetPoint("TOPLEFT", nameInput, "TOPLEFT", 0, 0)
                    nameInput.editBox:SetPoint("BOTTOMRIGHT", nameInput, "BOTTOMRIGHT", 0, 0)
                    nameInput:SetHeight(nameInput.editBox:GetHeight())
                    nameInput.editBox:SetText(self:GetGroupName(groupId))
                    nameInput.editBox:HookScript("OnTextChanged", function(editBox, userInput)
                        if not userInput then return end
                        local current = HUDCraftDB.groups.byId[groupId]
                        if not current then return end
                        current.name = editBox:GetText()
                        self:RenameGroupFrame(groupId)
                        if self.groupManagementRefresh then self.groupManagementRefresh() end
                    end)
                    layout:AddContent(nameColumn, nameInput, { role = "text-input", fillWidth = true })

                    local headerClose = self.settingsWindow and self.settingsWindow.closeButton
                    local iconScale = 0.75
                    local iconOptions = {
                        hitWidth = ((headerClose and headerClose:GetWidth()) or 25) * iconScale,
                        hitHeight = nameInput:GetHeight(),
                        visualSize = (((headerClose and headerClose.visualFrame
                            and headerClose.visualFrame:GetWidth()) or 20) * iconScale),
                        glyphSize = (((headerClose and headerClose.icon
                            and headerClose.icon:GetWidth()) or 18) * iconScale),
                    }
                    local deleteButton = ui.WindowStyles:CreateIconButton(deleteColumn, "exit_icon", function()
                        local current = HUDCraftDB.groups.byId[groupId]
                        if current then StaticPopup_Show("HUDCRAFT_DELETE_GROUP", current.name, nil, groupId) end
                    end, HUDCraftDB.styles.settings, iconOptions)
                    layout:AddContent(deleteColumn, deleteButton, { role = "button" })
                    if isNotepad then
                        notepadRows[groupId] = row
                        nameInput.scopeLabel = scopeText
                        nameInput.scopeLabelColumn = entryColumns[1]
                        notepadInputs[groupId] = nameInput
                    else
                        groupRows[groupId] = row
                        groupInputs[groupId] = nameInput
                    end
                    return row
                end

                local emptyGroupsText = groupsSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                emptyGroupsText:SetJustifyH("LEFT")
                emptyGroupsText:SetText("No Groups have been added.")
                layout:AddContent(groupsSection, emptyGroupsText, { role = "notes" })

                local createGroupRow = layout:Row(actionsSection,
                    "hudcraft-add-group-row", { flow = true })
                layout:AddContent(actionsSection, createGroupRow, { fillWidth = true })
                local createGroupColumn = layout:Columns(createGroupRow, 1,
                    { "hudcraft-add-group-column" }, { horizontalAlign = "CENTER" })[1]
                local createGroupButton = controls.AddActionButtonContent(createGroupColumn,
                    "Add Group", function()
                        local newId = self:CreateGroup()
                        if self.groupCreationRefresh then self.groupCreationRefresh() end
                        if self.groupManagementRefresh then self.groupManagementRefresh() end
                        local input = newId and groupInputs[newId]
                        if input and input.editBox then
                            input.editBox:SetFocus()
                            input.editBox:HighlightText()
                        end
                    end, { widthMode = "auto" })
                layout:AddContent(createGroupColumn, createGroupButton, {
                    role = "button",
                    fillWidth = false,
                })

                local notepadButtonRow = layout:Row(notepadActionsSection,
                    "hudcraft-add-notepad-buttons", { flow = true })
                layout:AddContent(notepadActionsSection, notepadButtonRow, { fillWidth = true })
                local notepadButtonColumns = layout:Columns(notepadButtonRow, 2, {
                    "hudcraft-add-account-notepad-column",
                    "hudcraft-add-character-notepad-column",
                }, { horizontalAlign = "CENTER" })
                local function AddNotepadButton(parent, label, scope)
                    local button = controls.AddActionButtonContent(parent, label, function()
                        local newId = self:CreateNotepad(scope)
                        if self.groupCreationRefresh then self.groupCreationRefresh() end
                        if self.groupManagementRefresh then self.groupManagementRefresh() end
                        local input = newId and notepadInputs[newId]
                        if input and input.editBox then
                            input.editBox:SetFocus()
                            input.editBox:HighlightText()
                        end
                    end, { widthMode = "auto" })
                    layout:AddContent(parent, button, { role = "button", fillWidth = false })
                    return button
                end
                AddNotepadButton(notepadButtonColumns[1],
                    "Add Account-Wide Notepad", "account")
                AddNotepadButton(notepadButtonColumns[2],
                    "Add Per-Character Notepad", "character")

                local function RefreshGroupCreation()
                    local order = HUDCraftDB.groups.order or {}
                    local present = {}
                    local groupCount = 0
                    for _, groupId in ipairs(order) do
                        local group = HUDCraftDB.groups.byId[groupId]
                        if group then
                            present[groupId] = true
                            if group.kind == "notepad" then
                                local notepadRow = notepadRows[groupId] or CreateGroupRow(groupId, group)
                                notepadRow:Show()
                                if notepadInputs[groupId] then
                                    notepadInputs[groupId].scopeLabel:SetText(group.noteScope == "account"
                                        and "[Account-Wide]" or "[Per-Character]")
                                    notepadInputs[groupId]:Refresh()
                                end
                            else
                                groupCount = groupCount + 1
                                local row = groupRows[groupId] or CreateGroupRow(groupId, group)
                                row:Show()
                                if groupInputs[groupId] then groupInputs[groupId]:Refresh() end
                            end
                        end
                    end
                    for groupId, row in pairs(groupRows) do
                        if not present[groupId] then row:Hide() end
                    end
                    for groupId, row in pairs(notepadRows) do
                        if not present[groupId] then row:Hide() end
                    end
                    emptyGroupsText:SetShown(groupCount == 0)
                    if host.ScheduleMeasure then host.ScheduleMeasure() end
                end
                self.groupCreationRefresh = RefreshGroupCreation
                RefreshGroupCreation()

                BindHostedPage(ui, host)
            elseif pageId == "groups" and subpageId == "group-management" then
                local layout = ui.SettingsLayout
                local controls = ui.SettingsControls
                local metrics = layout.Metrics
                -- The hosted body Section supplies the second shared padding unit.
                local sidebarContentGap = metrics.SECTION_PADDING
                local sidebarHost = CreateFrame("Frame", nil, content)
                sidebarHost:SetAllPoints(content)
                local scroll
                local host, flow = CreateHostedPage(ui, content, layout, "hudcraft-group-management")
                scroll = host.scroll
                local pageContent = host.content
                flow.layoutHorizontalAlign = "CENTER"
                local sidebarColumn = CreateFrame("Frame", nil, sidebarHost)
                sidebarColumn:SetPoint("TOPLEFT", sidebarHost, "TOPLEFT", 0, 0)
                sidebarColumn:SetPoint("BOTTOMLEFT", sidebarHost, "BOTTOMLEFT", 0, 0)
                local sidebarViewport = CreateFrame("ScrollFrame", nil, sidebarColumn)
                sidebarViewport:EnableMouseWheel(true)
                sidebarViewport:SetClipsChildren(true)
                sidebarViewport:SetPoint("TOPLEFT", sidebarColumn, "TOPLEFT", 0, 0)
                sidebarViewport:SetPoint("BOTTOMLEFT", sidebarColumn, "BOTTOMLEFT", 0, 0)
                sidebarViewport:SetWidth(15)
                local sidebarScrollContent = CreateFrame("Frame", nil, sidebarViewport)
                sidebarScrollContent:SetSize(15, 1)
                sidebarViewport:SetScrollChild(sidebarScrollContent)
                local sidebarScrollbar = controls.AttachScrollbar
                    and controls:AttachScrollbar(sidebarHost, sidebarViewport, "inherit", { variant = "slim" })
                local sidebarDivider = ui.WindowStyles:CreateFlatTexture(sidebarHost, "BORDER",
                    ui.WindowStyles:GetSubpageUnderlineColor(content))
                if sidebarDivider then
                    sidebarDivider:SetWidth(1)
                    sidebarDivider:SetPoint("TOPRIGHT", sidebarColumn, "TOPRIGHT", 0, 0)
                    sidebarDivider:SetPoint("BOTTOMRIGHT", sidebarColumn, "BOTTOMRIGHT", 0, 0)
                    ui.WindowStyles:RegisterVisual(sidebarDivider, function(target)
                        target:SetVertexColor(unpack(ui.WindowStyles:GetSubpageUnderlineColor(content)))
                    end)
                end
                local managementPanel = layout:Container(flow, "hudcraft-group-settings-panel")
                layout:AddContent(flow, managementPanel, { fillWidth = true, maxWidth = 1000 })

                local emptyGroupsText = layout:Note(managementPanel,
                    "Create a Group or Notepad on the Group Creation page to configure it.", {
                        justifyH = "LEFT",
                    })
                layout:AddContent(managementPanel, emptyGroupsText, { fillWidth = true, wrap = true })

                local entries, selectedGroupId = {}, nil
                local RefreshGroupManagement
                local navigation, notepadNavigation, notepadNavigationHeader
                local navigationOrderSignature
                local navigationContentHeight = 0
                local function ApplySidebarWidthLimit()
                    local scrollbarGutter = controls.GetScrollbarGutterWidth
                        and controls:GetScrollbarGutterWidth("slim") or 12
                    local dividerClearance = 4
                    local maximumWidth = math.max(15,
                        (window:GetWidth() or 1) * 0.30 - scrollbarGutter - dividerClearance)
                    if navigation then navigation:SetMaxWidth(maximumWidth) end
                    if notepadNavigation then notepadNavigation:SetMaxWidth(maximumWidth) end
                    local sharedWidth = navigation and (navigation:GetWidth() or 15) or 15
                    if notepadNavigation then
                        sharedWidth = math.max(sharedWidth, notepadNavigation:GetWidth() or 15)
                    end
                    if navigation then navigation:SetDisplayWidth(sharedWidth) end
                    if notepadNavigation then notepadNavigation:SetDisplayWidth(sharedWidth) end
                    local railWidth = navigation and (navigation:GetWidth() or 15) or 15
                    sidebarViewport:SetWidth(railWidth)
                    sidebarScrollContent:SetWidth(railWidth)
                    -- Flush scroll-child bounds before the lower Notepad rail is queried or painted.
                    sidebarViewport:UpdateScrollChildRect()
                    sidebarColumn:SetWidth(railWidth + scrollbarGutter)
                    if sidebarDivider then
                        sidebarDivider:ClearAllPoints()
                        sidebarDivider:SetPoint("TOPLEFT", sidebarViewport, "TOPRIGHT",
                            scrollbarGutter + dividerClearance, 0)
                        sidebarDivider:SetPoint("BOTTOMLEFT", sidebarColumn, "BOTTOMRIGHT",
                            dividerClearance, 0)
                    end
                    scroll:ClearAllPoints()
                    scroll:SetPoint("TOPLEFT", sidebarColumn, "TOPRIGHT", sidebarContentGap, 0)
                    scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT",
                        -(tonumber(controls.ScrollbarGutterWidth) or 12), 0)
                    if sidebarScrollbar and sidebarScrollbar.RefreshVisibility then
                        sidebarScrollbar:RefreshVisibility()
                    end
                end

                local function ScrollSidebar(_, delta)
                    local current = sidebarViewport:GetVerticalScroll() or 0
                    local range = sidebarViewport:GetVerticalScrollRange() or 0
                    sidebarViewport:SetVerticalScroll(math.max(0, math.min(range, current - delta * 35)))
                    if sidebarScrollbar and sidebarScrollbar.Update then sidebarScrollbar:Update() end
                end
                sidebarViewport:SetScript("OnMouseWheel", ScrollSidebar)
                local function EnableSidebarWheel(region)
                    if not region or not region.EnableMouseWheel then return end
                    region:EnableMouseWheel(true)
                    region:SetScript("OnMouseWheel", ScrollSidebar)
                end
                local function ClearNavigationSelection(target)
                    if not target then return end
                    target.selectedIndex = nil
                    for _, button in ipairs(target.buttons or {}) do
                        button:SetSelected(false)
                    end
                end
                local moduleOptions, moduleById = {}, {}
                for _, module in ipairs(self.Modules or {}) do
                    moduleById[module.id] = module
                    moduleOptions[#moduleOptions + 1] = module
                end
                table.sort(moduleOptions, function(left, right)
                    return tostring(left.label or left.id) < tostring(right.label or right.id)
                end)

                local styleOptions = {}
                local styleNames = {}
                for name in pairs(ui.WindowStyles.Presets or {}) do
                    if not self:IsGroupStyleOverridePreset(name) then
                        styleNames[#styleNames + 1] = name
                    end
                end
                table.sort(styleNames)
                for _, name in ipairs(styleNames) do
                    styleOptions[#styleOptions + 1] = { name = name, value = name }
                end

                local function SelectGroup(groupId)
                    selectedGroupId = groupId
                    if RefreshGroupManagement then RefreshGroupManagement() end
                end
                self.SelectGroupManagementGroup = function(_, groupId)
                    if not HUDCraftDB.groups.byId[groupId] then return false end
                    SelectGroup(groupId)
                    return true
                end

                local function CreateMultiDropdownOptions(groupId)
                    local options = {}
                    for _, module in ipairs(moduleOptions) do
                        local moduleId = module.id
                        options[#options + 1] = {
                            name = module.label or moduleId,
                            getter = function()
                                local group = HUDCraftDB.groups.byId[groupId]
                                return group and group.selectedModules[moduleId] == true or false
                            end,
                            setter = function(enabled)
                                local group = HUDCraftDB.groups.byId[groupId]
                                if not group then return end
                                group.selectedModules[moduleId] = enabled and true or nil
                                local order, seen = {}, {}
                                for _, orderedId in ipairs(group.moduleOrder or {}) do
                                    if orderedId ~= moduleId and group.selectedModules[orderedId] == true
                                        and moduleById[orderedId] and not seen[orderedId] then
                                        order[#order + 1] = orderedId
                                        seen[orderedId] = true
                                    end
                                end
                                if enabled and not seen[moduleId] then
                                    order[#order + 1] = moduleId
                                    seen[moduleId] = true
                                end
                                for _, availableModule in ipairs(moduleOptions) do
                                    if group.selectedModules[availableModule.id] == true
                                        and not seen[availableModule.id] then
                                        order[#order + 1] = availableModule.id
                                        seen[availableModule.id] = true
                                    end
                                end
                                group.moduleOrder = order
                                self:RefreshGroup(groupId)
                                local entry = entries[groupId]
                                if entry and entry.orderControl then entry.orderControl:SetValues(order) end
                                if host.ScheduleMeasure then host.ScheduleMeasure() end
                            end,
                        }
                    end
                    return options
                end

                local function CreateGroupManagementPage(groupId, groupPage, group)
                    local settingsSection = layout:Section(groupPage,
                        "hudcraft-group-settings-general-" .. tostring(groupId), {
                            border = false,
                        })
                    layout:AddContent(groupPage, settingsSection, { fillWidth = true, maxWidth = 1000 })
                    layout:AreaHeader(settingsSection,
                        group.kind == "notepad" and "Notepad Settings" or "Group Settings")

                    local visibility = controls.AddCheckbox(settingsSection,
                        group.kind == "notepad" and "Show Notepad for This Character"
                            or "Show Group for This Character",
                        function() return HUDCraftCharDB.groupsEnabled[groupId] ~= false end,
                        function(enabled)
                            HUDCraftCharDB.groupsEnabled[groupId] = enabled and true or false
                            local window = self.groupFrames and self.groupFrames[groupId]
                            if window then window:SetShown(enabled) end
                        end)
                    layout:AddContent(settingsSection, visibility, { role = "control", fillWidth = true })

                    if group.kind ~= "notepad" then
                    layout:AreaHeader(settingsSection, "Layout")
                    local orientationOptions = {
                        { name = "Horizontal", value = "row" },
                        { name = "Vertical", value = "column" },
                    }
                    local detailsPositionPicker
                    local orientationPicker = controls.AddDropdownContent(settingsSection,
                        "Group orientation", orientationOptions,
                        function()
                            return self:GetGroupDirection(groupId)
                        end,
                        function(value)
                            if value ~= "row" and value ~= "column" then return end
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current then return end
                            current.orientation = value
                            self:RefreshGroup(groupId)
                            if detailsPositionPicker and current.detailsPosition == nil then
                                detailsPositionPicker:RefreshDisplay()
                            end
                        end)
                    layout:AddContent(settingsSection, orientationPicker,
                        { role = "control", fillWidth = true })

                    layout:AreaHeader(settingsSection, "Details Panel")
                    local detailsEnabled = controls.AddCheckbox(settingsSection,
                        "Show Details panel",
                        function()
                            local current = HUDCraftDB.groups.byId[groupId]
                            return not current or current.detailsEnabled ~= false
                        end,
                        function(enabled)
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current then return end
                            current.detailsEnabled = enabled == true
                            if not enabled then
                                local details = self.groupDetails and self.groupDetails[groupId]
                                if details then
                                    if details.hideTimer then details.hideTimer:Hide() end
                                    details:Hide()
                                    details.detailSource = nil
                                    details.detailModule = nil
                                end
                            end
                            self:RefreshGroup(groupId)
                        end)
                    layout:AddContent(settingsSection, detailsEnabled,
                        { role = "control", fillWidth = true })
                    local detailsPositionOptions = {
                        { name = "Below", value = "bottom" },
                        { name = "Right", value = "right" },
                        { name = "Above", value = "top" },
                        { name = "Left", value = "left" },
                    }
                    detailsPositionPicker = controls.AddDropdownContent(settingsSection,
                        "Details panel position", detailsPositionOptions,
                        function()
                            return self:GetGroupDetailsPosition(groupId)
                        end,
                        function(value)
                            if value ~= "bottom" and value ~= "right"
                                and value ~= "top" and value ~= "left" then return end
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current then return end
                            current.detailsPosition = value
                            local details = self.groupDetails and self.groupDetails[groupId]
                            if details and details:IsShown() and details.detailModule then
                                self:ShowGroupModuleDetails(groupId, details.detailModule, details.detailSource)
                            end
                        end)
                    layout:AddContent(settingsSection, detailsPositionPicker,
                        { role = "control", fillWidth = true })
                    end

                    layout:AreaHeader(settingsSection, "Style")
                    local styleRow = layout:Row(settingsSection,
                        "hudcraft-group-style-row-" .. tostring(groupId), { flow = true })
                    layout:AddContent(settingsSection, styleRow, { fillWidth = true })
                    local styleColumns = layout:Columns(styleRow, 2, {
                        "hudcraft-group-style-mode-" .. tostring(groupId),
                        "hudcraft-group-control-panel-" .. tostring(groupId),
                    })
                    local styleChoices = {
                        { name = "Global style", value = "global" },
                        { name = "Custom style", value = "custom" },
                    }
                    local stylePicker
                    local styleMode = controls.AddRadioSelectorContent(styleColumns[1],
                        "", styleChoices,
                        function()
                            local current = HUDCraftDB.groups.byId[groupId]
                            return current and current.useGlobalStyle ~= false and "global" or "custom"
                        end,
                        function(value)
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current then return end
                            current.useGlobalStyle = value == "global"
                            if value == "custom" and not ui.WindowStyles.Presets[current.customStyle] then
                                current.customStyle = HUDCraftDB.styles.groups
                            end
                            if stylePicker then stylePicker:SetShown(value == "custom") end
                            self:ApplyGroupAppearance(groupId)
                            if host.ScheduleMeasure then host.ScheduleMeasure() end
                        end)
                    layout:AddContent(styleColumns[1], styleMode, { role = "control", fillWidth = true })

                    local controlPanelOptions = {
                        { name = "No control panel", value = "never" },
                        { name = "Show control panel on hover", value = "hover" },
                        { name = "Always show control panel", value = "always" },
                    }
                    local controlPanelPicker = controls.AddDropdownContent(styleColumns[2],
                        "Control panel", controlPanelOptions,
                        function()
                            local current = HUDCraftDB.groups.byId[groupId]
                            local value = current and current.controlPanelVisibility
                            if value == "never" or value == "hover" or value == "always" then return value end
                            return "always"
                        end,
                        function(value)
                            if value ~= "never" and value ~= "hover" and value ~= "always" then return end
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current then return end
                            current.controlPanelVisibility = value
                            local window = self.groupFrames and self.groupFrames[groupId]
                            if window then window:SetFrameHeaderVisibility(value) end
                        end)
                    layout:AddContent(styleColumns[2], controlPanelPicker, { role = "control", fillWidth = true })

                    local controlPanelPositionOptions = {
                        { name = "Above", value = "top" },
                        { name = "Below", value = "bottom" },
                        { name = "Left", value = "left" },
                        { name = "Right", value = "right" },
                    }
                    local controlPanelPositionPicker = controls.AddDropdownContent(styleColumns[2],
                        "Control Panel Location", controlPanelPositionOptions,
                        function()
                            local current = HUDCraftDB.groups.byId[groupId]
                            local position = current and current.controlPanelPosition
                            if position == "top" or position == "bottom"
                                or position == "left" or position == "right" then
                                return position
                            end
                            local fallback = HUDCraftDB.general.groupHeaderPosition
                            if fallback == "top" or fallback == "bottom"
                                or fallback == "left" or fallback == "right" then
                                return fallback
                            end
                            return "top"
                        end,
                        function(value)
                            if value ~= "top" and value ~= "bottom"
                                and value ~= "left" and value ~= "right" then return end
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current then return end
                            current.controlPanelPosition = value
                            local window = self.groupFrames and self.groupFrames[groupId]
                            if window then
                                local anchors = { top = "right", left = "top", bottom = "left", right = "top" }
                                window:SetFrameHeaderPosition(value, anchors[value])
                            end
                        end)
                    layout:AddContent(styleColumns[2], controlPanelPositionPicker,
                        { role = "control", fillWidth = true })

                    stylePicker = controls.AddDropdownContent(styleColumns[1], "Style", styleOptions,
                        function()
                            local current = HUDCraftDB.groups.byId[groupId]
                            local value = current and current.customStyle
                            return ui.WindowStyles.Presets[value] and value or HUDCraftDB.styles.groups
                        end,
                        function(value)
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current or not ui.WindowStyles.Presets[value] then return end
                            current.customStyle = value
                            self:ApplyGroupAppearance(groupId)
                        end)
                    stylePicker:SetShown(group.useGlobalStyle == false)
                    layout:AddContent(styleColumns[1], stylePicker, { role = "control", fillWidth = true })

                    if group.kind ~= "notepad" then
                    local modulesSection = layout:Section(groupPage,
                        "hudcraft-group-settings-modules-" .. tostring(groupId))
                    layout:AddContent(groupPage, modulesSection, { fillWidth = true, maxWidth = 1000 })
                    layout:AreaHeader(modulesSection, "Modules")
                    local row = layout:Row(modulesSection,
                        "hudcraft-group-module-row-" .. tostring(groupId), { flow = true })
                    layout:AddContent(modulesSection, row, { fillWidth = true })
                    local columns = layout:Columns(row, 2, {
                        "hudcraft-group-module-list-" .. tostring(groupId),
                        "hudcraft-group-module-order-" .. tostring(groupId),
                    })

                    local modulePicker = controls.AddMultiDropdownContent(columns[1],
                        "Module List", CreateMultiDropdownOptions(groupId), 206, { emptyText = "None" })
                    layout:AddContent(columns[1], modulePicker, { role = "control", fillWidth = true })

                    local orderedIds = {}
                    local seen = {}
                    for _, moduleId in ipairs(group.moduleOrder or {}) do
                        if group.selectedModules[moduleId] == true and moduleById[moduleId] and not seen[moduleId] then
                            orderedIds[#orderedIds + 1] = moduleId
                            seen[moduleId] = true
                        end
                    end
                    for _, module in ipairs(moduleOptions) do
                        if group.selectedModules[module.id] == true and not seen[module.id] then
                            orderedIds[#orderedIds + 1] = module.id
                            seen[module.id] = true
                        end
                    end
                    local orderControl = controls.AddDraggableOrderedListContent(columns[2],
                        "Module Order", orderedIds,
                        function(moduleId)
                            local module = moduleById[moduleId]
                            return module and (module.label or moduleId) or tostring(moduleId)
                        end,
                        function(values)
                            local current = HUDCraftDB.groups.byId[groupId]
                            if not current then return end
                            local order, ordered = {}, {}
                            for _, moduleId in ipairs(values or {}) do
                                if moduleById[moduleId] and current.selectedModules[moduleId] == true
                                    and not ordered[moduleId] then
                                    order[#order + 1] = moduleId
                                    ordered[moduleId] = true
                                end
                            end
                            for _, module in ipairs(moduleOptions) do
                                if current.selectedModules[module.id] == true and not ordered[module.id] then
                                    order[#order + 1] = module.id
                                    ordered[module.id] = true
                                end
                            end
                            current.moduleOrder = order
                            self:RefreshGroup(groupId)
                            if host.ScheduleMeasure then host.ScheduleMeasure() end
                        end)
                    layout:AddContent(columns[2], orderControl, { role = "control", fillWidth = true })
                    end

                    return { stylePicker = stylePicker, orderControl = orderControl }
                end

                local function CreateGroupManagementEntry(groupId, group)
                    local groupPage = layout:Container(managementPanel,
                        "hudcraft-group-settings-" .. tostring(groupId))
                    layout:AddContent(managementPanel, groupPage, { fillWidth = true })
                    local controlsForGroup = CreateGroupManagementPage(groupId, groupPage, group)
                    groupPage:Hide()
                    entries[groupId] = {
                        page = groupPage,
                        orderControl = controlsForGroup.orderControl,
                        stylePicker = controlsForGroup.stylePicker,
                    }
                    return entries[groupId]
                end

                local function SyncGroupNavigation(groupIds, notepadIds)
                    local signature = table.concat(groupIds, "\001") .. "\002" .. table.concat(notepadIds, "\001")
                    if not navigation or signature ~= navigationOrderSignature then
                        if navigation then
                            navigation:Hide()
                            if navigation.host then navigation.host:Hide() end
                        end
                        if notepadNavigation then
                            notepadNavigation:Hide()
                            if notepadNavigation.host then notepadNavigation.host:Hide() end
                        end
                        if notepadNavigationHeader then
                            notepadNavigationHeader:Hide()
                            if notepadNavigationHeader.underline then
                                notepadNavigationHeader.underline:Hide()
                            end
                        end

                        local metrics = layout.Metrics
                        local sectionPadding = tonumber(metrics.SECTION_PADDING) or 5
                        local contentGap = tonumber(metrics.CONTENT_GAP) or 2
                        local sectionGap = tonumber(metrics.SECTION_GAP) or contentGap
                        local navigationHeight = tonumber(ui.WindowStyles.GeometryDefaults.navigationItemHeight) or 28
                        local groupNavHeight = #groupIds > 0
                            and (sectionPadding * 2 + #groupIds * navigationHeight
                                + math.max(0, #groupIds - 1) * contentGap) or 0
                        local groupNavHost = CreateFrame("Frame", nil, sidebarScrollContent)
                        groupNavHost:SetPoint("TOPLEFT", sidebarScrollContent, "TOPLEFT", 0, 0)
                        groupNavHost:SetPoint("TOPRIGHT", sidebarScrollContent, "TOPRIGHT", 0, 0)
                        groupNavHost:SetHeight(math.max(1, groupNavHeight))
                        local items = {}
                        for _, groupId in ipairs(groupIds) do
                            items[#items + 1] = {
                                label = self:GetGroupName(groupId),
                                groupId = groupId,
                            }
                        end
                        navigation = ui.NavigationControls:CreateVerticalSubpageNavigation(
                            groupNavHost, items, {
                                maxWidth = math.max(15, (window:GetWidth() or 1) * 0.30),
                                onSelect = function(_, item)
                                    if item then SelectGroup(item.groupId) end
                                end,
                            })
                        navigation.host = groupNavHost
                        navigation.separator:Hide()
                        EnableSidebarWheel(navigation)
                        for _, button in ipairs(navigation.buttons or {}) do
                            EnableSidebarWheel(button)
                        end
                        navigationContentHeight = groupNavHeight

                        if #notepadIds > 0 then
                            local header = sidebarScrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                            header:SetJustifyH("LEFT")
                            header:SetText("Notepads")
                            header:SetPoint("TOPLEFT", sidebarScrollContent, "TOPLEFT",
                                sectionPadding, -(groupNavHeight + sectionGap))
                            EnableSidebarWheel(header)
                            local function RepaintNotepadNavigationHeader(target)
                                local color = ui.WindowStyles:GetTextColor("textInteractionAccentColor", content)
                                if color then target:SetTextColor(unpack(color)) end
                            end
                            ui.WindowStyles:RegisterVisual(header, RepaintNotepadNavigationHeader)
                            RepaintNotepadNavigationHeader(header)
                            local underline = ui.WindowStyles:CreateFlatTexture(sidebarScrollContent, "BORDER",
                                ui.WindowStyles:GetTextColor("textNeutralAccentColor", content))
                            if underline then
                                underline:SetHeight(2)
                                underline:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
                                underline:SetWidth(math.max(1, header:GetStringWidth() or 1))
                                ui.WindowStyles:RegisterVisual(underline, function(target)
                                    target:SetVertexColor(unpack(ui.WindowStyles:GetTextColor(
                                        "textNeutralAccentColor", content)))
                                end)
                            end
                            header.underline = underline
                            notepadNavigationHeader = header

                            local noteHeaderHeight = math.max(header:GetStringHeight() or 12, 12) + 4
                            local notepadNavigationHeight = sectionPadding * 2
                                + #notepadIds * navigationHeight
                                + math.max(0, #notepadIds - 1) * contentGap
                            local noteHost = CreateFrame("Frame", nil, sidebarScrollContent)
                            noteHost:SetPoint("TOPLEFT", sidebarScrollContent, "TOPLEFT", 0,
                                -(groupNavHeight + sectionGap + noteHeaderHeight + contentGap))
                            noteHost:SetPoint("TOPRIGHT", sidebarScrollContent, "TOPRIGHT", 0,
                                -(groupNavHeight + sectionGap + noteHeaderHeight + contentGap))
                            noteHost:SetHeight(math.max(1, notepadNavigationHeight))
                            local noteItems = {}
                            for _, groupId in ipairs(notepadIds) do
                                noteItems[#noteItems + 1] = {
                                    label = self:GetGroupName(groupId),
                                    groupId = groupId,
                                }
                            end
                            notepadNavigation = ui.NavigationControls:CreateVerticalSubpageNavigation(
                                noteHost, noteItems, {
                                    maxWidth = math.max(15, (window:GetWidth() or 1) * 0.30),
                                    onSelect = function(_, item)
                                        if item then SelectGroup(item.groupId) end
                                    end,
                                })
                            notepadNavigation.host = noteHost
                            notepadNavigation.separator:Hide()
                            EnableSidebarWheel(notepadNavigation)
                            for _, button in ipairs(notepadNavigation.buttons or {}) do
                                EnableSidebarWheel(button)
                            end
                            navigationContentHeight = groupNavHeight + sectionGap
                                + noteHeaderHeight + contentGap + notepadNavigationHeight
                        else
                            notepadNavigation = nil
                            notepadNavigationHeader = nil
                        end

                        sidebarScrollContent:SetHeight(math.max(1, navigationContentHeight))
                        -- The Notepad rail sits below the top Group rail, so its bounds depend on this update.
                        sidebarViewport:UpdateScrollChildRect()
                        local scrollRange = sidebarViewport:GetVerticalScrollRange() or 0
                        sidebarViewport:SetVerticalScroll(math.min(
                            sidebarViewport:GetVerticalScroll() or 0, scrollRange))
                        if sidebarScrollbar and sidebarScrollbar.RefreshVisibility then
                            sidebarScrollbar:RefreshVisibility()
                        end
                        ApplySidebarWidthLimit()
                        if sidebarDivider then sidebarDivider:SetShown(#groupIds > 0 or #notepadIds > 0) end
                        navigationOrderSignature = signature
                    else
                        for index, groupId in ipairs(groupIds) do
                            navigation:SetLabel(index, self:GetGroupName(groupId))
                        end
                        for index, groupId in ipairs(notepadIds) do
                            notepadNavigation:SetLabel(index, self:GetGroupName(groupId))
                        end
                        ApplySidebarWidthLimit()
                    end

                    local selectedIndex
                    for index, groupId in ipairs(groupIds) do
                        if groupId == selectedGroupId then selectedIndex = index break end
                    end
                    local selectedNotepadIndex
                    for index, groupId in ipairs(notepadIds) do
                        if groupId == selectedGroupId then selectedNotepadIndex = index break end
                    end
                    if selectedNotepadIndex and notepadNavigation then
                        ClearNavigationSelection(navigation)
                        notepadNavigation:SetSelected(selectedNotepadIndex)
                    elseif selectedIndex then
                        navigation:SetSelected(selectedIndex)
                        ClearNavigationSelection(notepadNavigation)
                    else
                        ClearNavigationSelection(navigation)
                        ClearNavigationSelection(notepadNavigation)
                    end
                end

                RefreshGroupManagement = function()
                    local order = HUDCraftDB.groups.order or {}
                    local present, validOrder, validNotepads = {}, {}, {}
                    for _, groupId in ipairs(order) do
                        local group = HUDCraftDB.groups.byId[groupId]
                        if group then
                            present[groupId] = true
                            if group.kind == "notepad" then
                                validNotepads[#validNotepads + 1] = groupId
                            else
                                validOrder[#validOrder + 1] = groupId
                            end
                            entries[groupId] = entries[groupId] or CreateGroupManagementEntry(groupId, group)
                        end
                    end
                    if not selectedGroupId or not present[selectedGroupId] then
                        selectedGroupId = validOrder[1] or validNotepads[1]
                    end
                    SyncGroupNavigation(validOrder, validNotepads)
                    for groupId, entry in pairs(entries) do
                        if not present[groupId] then
                            entry.page:Hide()
                        end
                    end
                    for groupId, entry in pairs(entries) do
                        local selected = groupId == selectedGroupId and present[groupId] == true
                        entry.page:SetShown(selected)
                    end
                    emptyGroupsText:SetShown(#validOrder == 0)
                    if host.ScheduleMeasure then host.ScheduleMeasure() end
                end
                self.groupManagementRefresh = RefreshGroupManagement
                content:HookScript("OnShow", RefreshGroupManagement)

                RefreshGroupManagement()
                BindHostedPage(ui, host)
            elseif pageId == "groups" and subpageId == "module-settings" then
                content:HookScript("OnShow", function()
                if content.moduleSettingsBuilt then return end
                local layout = ui.SettingsLayout
                local controls = ui.SettingsControls
                local metrics = layout.Metrics
                -- The hosted body Section supplies the second shared padding unit.
                local sidebarContentGap = metrics.SECTION_PADDING
                local sidebarHost = CreateFrame("Frame", nil, content)
                sidebarHost:SetAllPoints(content)
                local modulePages = {}
                local moduleNavigation

                local function ShowModuleSettings(index)
                    for pageIndex, pageFrame in ipairs(modulePages) do
                        pageFrame:SetShown(pageIndex == index)
                    end
                end

                local moduleNavigationItems = {
                    { id = "weaponSkills", label = "Weapon Skills" },
                    { id = "professions", label = "Professions" },
                    { id = "reputation", label = "Reputation" },
                    { id = "gold", label = "Gold" },
                    { id = "durability", label = "Durability" },
                    {
                        id = "notepads",
                        label = "Notepads",
                        buildPage = function(flow)
                            local section = layout:Section(flow, "hudcraft-notepad-help")
                            layout:AddContent(flow, section, { fillWidth = true })
                            layout:AreaHeader(section, "Notepads")
                            local paragraphs = {
                                {
                                    label = "Standalone Windows:",
                                    description = "Notepads are standalone, resizable windows. They are managed separately from Groups and cannot be added as modules to a Group.",
                                },
                                {
                                    label = "Text Scope:",
                                    description = "Each Notepad's text scope is chosen when it is created. Account-Wide Notepads share the same text across your characters on this WoW account. Per-Character Notepads keep separate text for each character.",
                                },
                                {
                                    label = "Visibility and Position:",
                                    description = "Both types follow the usual per-character visibility and position settings. A new Notepad is enabled on the character that creates it; enable it manually on other characters in Group Management.",
                                },
                                {
                                    label = "Editing:",
                                    description = "Unlock a Notepad to edit, move, or resize it. Its text saves as you type. Lock it when you want to prevent accidental edits or movement.",
                                },
                            }
                            local function ColorText(role, text, frame)
                                local color = ui.WindowStyles:GetTextColor(role, frame)
                                local red = math.floor(math.max(0, math.min(1, color[1] or 1)) * 255 + 0.5)
                                local green = math.floor(math.max(0, math.min(1, color[2] or 1)) * 255 + 0.5)
                                local blue = math.floor(math.max(0, math.min(1, color[3] or 1)) * 255 + 0.5)
                                return string.format("|cff%02X%02X%02X%s|r", red, green, blue, text or "")
                            end
                            local function AddLabeledParagraph(parent, labelText, noteText,
                                labelColorRole, noteColorRole, gapBefore)
                                local paragraph = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                                paragraph:SetJustifyH("LEFT")
                                paragraph:SetJustifyV("TOP")
                                paragraph:SetWordWrap(true)
                                if paragraph.SetNonSpaceWrap then paragraph:SetNonSpaceWrap(true) end
                                local function RefreshParagraphColors()
                                    paragraph:SetText(ColorText(labelColorRole, labelText, paragraph) .. " "
                                        .. ColorText(noteColorRole, noteText, paragraph))
                                end
                                ui.WindowStyles:RegisterVisual(paragraph, RefreshParagraphColors)
                                RefreshParagraphColors()
                                layout:AddContent(parent, paragraph, {
                                    role = "content",
                                    fillWidth = true,
                                    wrap = true,
                                    gapBefore = gapBefore,
                                })
                            end
                            for index, paragraph in ipairs(paragraphs) do
                                AddLabeledParagraph(section, paragraph.label, paragraph.description,
                                    "primary", "notes",
                                    index == 1 and layout.Metrics.CONTENT_GAP
                                        or layout.Metrics.SECTION_BODY_GAP)
                            end
                        end,
                    },
                }
                moduleNavigation = ui.NavigationControls:CreateVerticalSubpageNavigation(
                    sidebarHost, moduleNavigationItems, {
                        onSelect = function(index) ShowModuleSettings(index) end,
                    })
                self.SelectModuleSettings = function(_, moduleId)
                    for index, item in ipairs(moduleNavigationItems) do
                        if item.id == moduleId then
                            moduleNavigation:SetSelected(index)
                            ShowModuleSettings(index)
                            return true
                        end
                    end
                    return false
                end

                for pageIndex, navigationItem in ipairs(moduleNavigationItems) do
                    local moduleId = navigationItem.id
                    local module
                    for _, candidate in ipairs(self.Modules or {}) do
                        if candidate.id == moduleId then module = candidate break end
                    end

                    local modulePage = CreateFrame("Frame", nil, content)
                    modulePage:SetPoint("TOPLEFT", moduleNavigation, "TOPRIGHT", sidebarContentGap, 0)
                    modulePage:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT",
                        -(tonumber(controls.ScrollbarGutterWidth) or 12), 0)
                    modulePage:Hide()
                    modulePages[pageIndex] = modulePage

                    local host, flow = CreateHostedPage(ui, modulePage, layout,
                        "hudcraft-module-settings-" .. moduleId)
                    local scroll, pageContent, scrollbar = host.scroll, host.content, host.scrollbar

                    local settingsEntries = module and type(module.getSettingsEntries) == "function"
                        and module.getSettingsEntries()
                    if type(navigationItem.buildPage) == "function" then
                        navigationItem.buildPage(flow)
                    elseif module and type(module.buildSettingsPage) == "function" then
                        module.buildSettingsPage(flow, {
                            addon = self,
                            layout = layout,
                            controls = controls,
                        })
                    elseif type(settingsEntries) == "table" then
                        local entries = settingsEntries
                    local moduleSettings = HUDCraftCharDB.moduleSettings
                    local config = moduleSettings[moduleId]
                    if type(config) ~= "table" then
                        config = {}
                        moduleSettings[moduleId] = config
                    end
                    if type(config.selected) ~= "table" then config.selected = {} end
                    if type(config.order) ~= "table" then config.order = {} end
                    if config.initialized ~= true and #entries > 0 then
                        if next(config.selected) == nil and #config.order == 0 then
                            for _, entry in ipairs(entries) do
                                config.selected[entry.id] = true
                                config.order[#config.order + 1] = entry.id
                            end
                        end
                        config.initialized = true
                    end
                    local known = {}
                    for _, entry in ipairs(entries) do known[entry.id] = entry end
                    local selectedOrder, seen = {}, {}
                    for _, id in ipairs(config.order) do
                        if known[id] and config.selected[id] == true and not seen[id] then
                            selectedOrder[#selectedOrder + 1] = id
                            seen[id] = true
                        end
                    end
                    for _, entry in ipairs(entries) do
                        if config.selected[entry.id] == true and not seen[entry.id] then
                            selectedOrder[#selectedOrder + 1] = entry.id
                            seen[entry.id] = true
                        end
                    end
                    config.order = selectedOrder
                    local orderControl
                    local function selectedOrderForCurrentEntries()
                        local result = {}
                        for _, entry in ipairs(entries) do
                            if config.selected[entry.id] == true then result[#result + 1] = entry.id end
                        end
                        local position = {}
                        for index, id in ipairs(config.order) do position[id] = index end
                        table.sort(result, function(left, right)
                            return (position[left] or math.huge) < (position[right] or math.huge)
                        end)
                        return result
                    end

                    local section = layout:Section(flow, "hudcraft-module-tracking-" .. moduleId)
                    layout:AddContent(flow, section, { fillWidth = true })
                    layout:AreaHeader(section, navigationItem.label)
                    local description = layout:Note(section,
                        module.settingsDescription or "Choose which learned entries appear in each Group, then drag to set their display order. Untracked learned entries remain available in the Details pane when its module label is shown.", {
                            justifyH = "LEFT",
                        })
                    layout:AddContent(section, description, { fillWidth = true, wrap = true })

                    if module.showLabelSetting ~= false then
                        local showLabelControl = controls.AddCheckbox(section,
                            "Show " .. navigationItem.label .. " label",
                            function() return HUDCraftCharDB.moduleLabels[moduleId] ~= false end,
                            function(enabled)
                                HUDCraftCharDB.moduleLabels[moduleId] = enabled and true or false
                                self:RefreshAllGroups({ moduleId })
                            end)
                        layout:AddContent(section, showLabelControl, { role = "control", fillWidth = true })
                    end

                    local row = layout:Row(section, "hudcraft-module-tracking-row-" .. moduleId, { flow = true })
                    layout:AddContent(section, row, { fillWidth = true })
                    local columns = layout:Columns(row, 2, {
                        "hudcraft-module-tracking-picker-" .. moduleId,
                        "hudcraft-module-tracking-order-" .. moduleId,
                    })
                    local options = {}
                    for _, entry in ipairs(entries) do
                        local entryId = entry.id
                        options[#options + 1] = {
                            name = entry.name,
                            getter = function() return config.selected[entryId] == true end,
                            setter = function(enabled)
                                config.selected[entryId] = enabled and true or nil
                                local order, ordered = {}, {}
                                for _, id in ipairs(config.order) do
                                    if config.selected[id] == true and not ordered[id] then
                                        order[#order + 1] = id
                                        ordered[id] = true
                                    end
                                end
                                if enabled and not ordered[entryId] then
                                    order[#order + 1] = entryId
                                    ordered[entryId] = true
                                end
                                config.order = order
                                if orderControl then orderControl:SetValues(selectedOrderForCurrentEntries()) end
                                self:RefreshAllGroups({ moduleId })
                            end,
                        }
                    end

                    local picker = controls.AddMultiDropdownContent(columns[1],
                        navigationItem.label,
                        options, 206, { emptyText = "None" })
                    layout:AddContent(columns[1], picker, { role = "control", fillWidth = true })
                    orderControl = controls.AddDraggableOrderedListContent(columns[2],
                        "Display Order", selectedOrderForCurrentEntries(),
                        function(id)
                            local entry = known[id]
                            return entry and entry.name or tostring(id)
                        end,
                        function(values)
                            local ordered, order = {}, {}
                            for _, id in ipairs(values or {}) do
                                if known[id] and config.selected[id] == true and not ordered[id] then
                                    order[#order + 1] = id
                                    ordered[id] = true
                                end
                            end
                            for _, entry in ipairs(entries) do
                                if config.selected[entry.id] == true and not ordered[entry.id] then
                                    order[#order + 1] = entry.id
                                    ordered[entry.id] = true
                                end
                            end
                            config.order = order
                            self:RefreshAllGroups({ moduleId })
                        end)
                    layout:AddContent(columns[2], orderControl, { role = "control", fillWidth = true })
                    self:RefreshAllGroups({ moduleId })
                    else
                        local note = layout:Note(flow, "Module settings are unavailable.", { justifyH = "LEFT" })
                        layout:AddContent(flow, note, { fillWidth = true, wrap = true })
                    end

                    BindHostedPage(ui, host)
                    modulePage.MeasureModuleSettings = host.ScheduleMeasure
                end

                moduleNavigation:SetSelected(1)
                ShowModuleSettings(1)
                content.moduleSettingsBuilt = true
                end)
            end
            pageFrames[pageId][subpageId] = content
            subpageButtons[pageId][subpageId] = ui.NavigationControls:AddSubpageNavigationButton(
                subpageNavigation, subpage.title, {
                width = 1,
                height = subpageHeight,
                onClick = function() self:ShowSettingsPage(pageId, subpageId) end,
            })
        end
        mainButtons[pageId] = ui.NavigationControls:AddMainNavigationButton(
            mainNavigation, page.title, {
                width = 1,
                height = mainHeight,
                onClick = function() self:ShowSettingsPage(pageId, defaultSubpageId) end,
            })
    end

    local navigationLayoutInProgress = false
    local function LayoutNavigation()
        if navigationLayoutInProgress then return end
        navigationLayoutInProgress = true
        local mainButtonList = {}
        for index, page in ipairs(PAGES) do
            mainButtonList[index] = mainButtons[page.id]
        end
        local mainNavigationHeight = ui.NavigationControls:LayoutHorizontalButtons(
            mainNavigation, mainButtonList, { kind="main", height=mainHeight, gap=navGap })
        if math.abs((mainNavigation:GetHeight() or 0) - mainNavigationHeight) > 0.001 then
            mainNavigation:SetHeight(mainNavigationHeight)
        end

        local selectedPage = self.selectedSettingsPage or PAGES[1]
        local subpages = selectedPage and selectedPage.subpages or {}
        local subpageButtonList = {}
        for index, subpage in ipairs(subpages) do
            subpageButtonList[index] = subpageButtons[selectedPage.id][subpage.id]
        end
        local subpageNavigationHeight = ui.NavigationControls:LayoutHorizontalButtons(
            subpageNavigation, subpageButtonList,
            { kind="subpage", height=subpageHeight, gap=navGap })
        if math.abs((subpageNavigation:GetHeight() or 0) - subpageNavigationHeight) > 0.001 then
            subpageNavigation:SetHeight(subpageNavigationHeight)
        end
        navigationLayoutInProgress = false
    end

    mainNavigation:HookScript("OnSizeChanged", LayoutNavigation)
    subpageNavigation:HookScript("OnSizeChanged", LayoutNavigation)
    window:HookScript("OnSizeChanged", function()
        if self.groupManagementRefresh then self.groupManagementRefresh() end
    end)
    self.LayoutSettingsNavigation = LayoutNavigation
    LayoutNavigation()

    self.settingsMainButtons = mainButtons
    self.settingsSubpageButtons = subpageButtons
    self.settingsPageFrames = pageFrames
    self:ShowSettingsPage("main", "welcome")
end

function addon:ShowSettingsPage(pageId, subpageId)
    local selectedPage
    for _, page in ipairs(PAGES) do
        if page.id == pageId then selectedPage = page break end
    end
    if not selectedPage then selectedPage = PAGES[1] end
    local selectedSubpage
    for _, subpage in ipairs(selectedPage.subpages) do
        if subpage.id == subpageId then selectedSubpage = subpage break end
    end
    if not selectedSubpage then selectedSubpage = selectedPage.subpages[1] end
    self.selectedSettingsPage = selectedPage

    for _, page in ipairs(PAGES) do
        local selectedMain = page == selectedPage
        self.settingsMainButtons[page.id]:SetSelected(selectedMain)
        for _, subpage in ipairs(page.subpages) do
            local selectedSub = selectedMain and subpage == selectedSubpage
            self.settingsPageFrames[page.id][subpage.id]:SetShown(selectedSub)
            local button = self.settingsSubpageButtons[page.id][subpage.id]
            button:SetSelected(selectedSub)
            button:SetShown(selectedMain)
        end
    end
    HUDCraftCharDB.lastSettingsPage = selectedPage.id
    HUDCraftCharDB.lastSettingsSubpage = selectedSubpage.id
    if self.LayoutSettingsNavigation then self.LayoutSettingsNavigation() end
    return true
end

function addon:ShowSettings()
    if not self.settingsWindow then return end
    self:ShowSettingsPage(HUDCraftCharDB.lastSettingsPage, HUDCraftCharDB.lastSettingsSubpage)
    self.settingsWindow:Show()
end

function addon:ShowModuleSettings(moduleId)
    if not self.settingsWindow then return false end
    self.settingsWindow:Show()
    self:ShowSettingsPage("groups", "module-settings")
    return type(self.SelectModuleSettings) == "function" and self:SelectModuleSettings(moduleId) or false
end
