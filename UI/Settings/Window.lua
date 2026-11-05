local _, addon = ...

addon.SettingsPages = {
    {
        id = "home",
        title = "Home",
    },
}

function addon:CreateSettingsWindow()
    local ui = self.UI
    local windowStyle = ui.WindowStyles:Get(ui.WindowStyles:GetConsumerPreset(self.name))
    local window = ui.WindowFrame:Create({
        id = "settings",
        title = "Hudcraft — Settings",
        owner = self.name,
        sizing = {
            position = { x = -290, y = 0 },
            minimum = { mode = "content" },
        },
        frameHeader = { controls = { close = true, minimize = true } },
    })
    self.settingsWindow = window

    local navigation = window:CreatePane(window.content, {
        navigation = true,
    })
    self.settingsNavigationPane = navigation
    navigation:SetPoint("TOPLEFT", window.content, "TOPLEFT", windowStyle.paneGutter, -windowStyle.paneGutter)
    navigation:SetPoint("BOTTOMLEFT", window.content, "BOTTOMLEFT", windowStyle.paneGutter, windowStyle.paneGutter)
    navigation:SetWidth(windowStyle.navigationWidth)
    navigation:SetMinimumBodySize(116, 44)
    navigation:SetHeaderText("Navigation")

    local pagePane = window:CreatePane(window.content, {
        header = true,
        footer = true,
    })
    pagePane:SetPoint("TOPLEFT", navigation, "TOPRIGHT", windowStyle.navigationGap, 0)
    pagePane:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", -windowStyle.paneGutter, windowStyle.paneGutter)
    pagePane:SetMinimumBodySize(1, 1)
    self.settingsPagePane = pagePane

    local host = ui.SettingsPageHost:CreateEmbedded(pagePane.body, "hudcraft-settings")
    self.settingsPageHost = host
    local navigationItems = {}
    for _, page in ipairs(self.SettingsPages) do
        page.sections = {}
        if page.navigation ~= false then
            page.button = ui.WindowStyles:CreateButton(navigation.body, page.title, 100, function()
                self:ShowSettingsPage(page.id)
            end)
            navigationItems[#navigationItems + 1] = page.button
        end
    end
    navigation:LayoutNavigationItems(navigationItems)

    local homePage
    for _, page in ipairs(self.SettingsPages) do
        if page.id == "home" then
            homePage = page
            break
        end
    end
    if homePage then
        local layout = ui.SettingsLayout
        local section = layout:Section(host.content, "hudcraft-home-commands")
        layout:MainHeader(section, "Commands")
        local row = layout:Row(section, "hudcraft-home-command-list", { flow = true })
        layout:SetFlowChild(section, row, "row")
        local columns = layout:Columns(row, 1)
        local paragraph = columns[1]:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        paragraph:SetJustifyH("LEFT")
        paragraph:SetWordWrap(true)
        paragraph:SetText(table.concat(addon.commandHelpLines, "\n"))
        homePage.sections[#homePage.sections + 1] = section
    end

    ui.SettingsPageHost:BindSections(host, {
        wrapSections = true,
    })
    self:ShowSettingsPage(HUDCraftCharDB.lastSettingsPage)
end

function addon:ShowSettingsPage(pageId)
    if not self.settingsPagePane then return false end
    local selectedPage
    for _, page in ipairs(self.SettingsPages) do
        if page.id == pageId then
            selectedPage = page
            break
        end
    end
    if not selectedPage then
        for _, page in ipairs(self.SettingsPages) do
            if page.id == "home" then
                selectedPage = page
                break
            end
        end
    end
    selectedPage = selectedPage or self.SettingsPages[1]
    if not selectedPage then return false end

    for _, page in ipairs(self.SettingsPages) do
        local selected = page == selectedPage
        for _, section in ipairs(page.sections or {}) do
            section:SetShown(selected)
        end
        if page.button then
            page.button.tbuSelected = selected
            self.UI.WindowStyles:ApplyButton(page.button, page.button:IsMouseOver(), nil, selected)
        end
    end
    self.settingsPagePane:SetHeaderText(selectedPage.title)
    HUDCraftCharDB.lastSettingsPage = selectedPage.id
    if self.settingsPageHost and self.settingsPageHost.ScheduleMeasure then
        self.settingsPageHost.ScheduleMeasure()
        self.settingsPageHost.scroll:SetVerticalScroll(0)
    end
    return true
end

function addon:ShowSettings()
    if self.settingsWindow then
        self:ShowSettingsPage(HUDCraftCharDB.lastSettingsPage)
        self.settingsWindow:Show()
    end
end

