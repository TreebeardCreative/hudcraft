local addonName, addon = ...

function addon:CreateAddonOptionsPanel()
    if self.addonOptionsPanel then return self.addonOptionsPanel end
    local settings = _G.Settings
    if type(settings) ~= "table"
        or type(settings.RegisterCanvasLayoutCategory) ~= "function"
        or type(settings.RegisterAddOnCategory) ~= "function" then
        self:Log("Blizzard Settings API is unavailable; the HUDCraft AddOns page was not registered.")
        return nil
    end

    local panel = CreateFrame("Frame", "HUDCraftAddonOptionsPanel")
    panel.name = "hudcraft"
    self.addonOptionsPanel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOP", panel, "TOP", 0, -120)
    local titleFont, _, titleFlags = title:GetFont()
    if titleFont then title:SetFont(titleFont, 26, titleFlags) end
    title:SetText("hudcraft")
    title:SetTextColor(1, 0.82, 0)

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    version:SetPoint("TOP", title, "BOTTOM", 0, -18)
    version:SetText("Version: " .. tostring(self.version or "unknown"))
    version:SetTextColor(1, 1, 1)

    local command = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    command:SetPoint("TOP", version, "BOTTOM", 0, -8)
    command:SetText("Access options with /hudcraft")
    command:SetTextColor(1, 1, 1)

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(150, 32)
    button:SetPoint("TOP", command, "BOTTOM", 0, -24)
    button:SetText("Options")
    button:SetScript("OnClick", function()
        addon:ShowSettings()
    end)

    local category = settings.RegisterCanvasLayoutCategory(panel, panel.name)
    settings.RegisterAddOnCategory(category)
    self.addonOptionsCategory = category
    return panel
end
