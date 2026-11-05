local addonName, addon = ...

addon.commandHelpLines = {
    "/hudcraft - Toggle the settings window.",
    "/hudcraft settings - Toggle the settings window.",
    "/hudcraft debug - Open the debug output window.",
    "/hudcraft commands - List these commands.",
    "/hudcraft home - Open the Home page in settings.",
    "/hudcraft hide - Hide the settings and debug windows.",
}

function addon:Initialize()
    if self.initialized then return end

    HUDCraftDB = type(HUDCraftDB) == "table" and HUDCraftDB or {}
    HUDCraftDB.version = HUDCraftDB.version or addon.Defaults.Account.version
    HUDCraftDB.general = type(HUDCraftDB.general) == "table" and HUDCraftDB.general or {}
    if HUDCraftDB.general.showGroupName == nil then
        HUDCraftDB.general.showGroupName = addon.Defaults.Account.general.showGroupName
    end
    if HUDCraftDB.general.spacing == nil then
        HUDCraftDB.general.spacing = addon.Defaults.Account.general.spacing
    end
    if HUDCraftDB.general.groupDirection == nil then
        HUDCraftDB.general.groupDirection = addon.Defaults.Account.general.groupDirection
    end
    HUDCraftCharDB = type(HUDCraftCharDB) == "table" and HUDCraftCharDB or {}
    HUDCraftCharDB.windowPositions = type(HUDCraftCharDB.windowPositions) == "table" and HUDCraftCharDB.windowPositions or {}
    HUDCraftCharDB.windowCollapsed = type(HUDCraftCharDB.windowCollapsed) == "table" and HUDCraftCharDB.windowCollapsed or {}
    HUDCraftCharDB.windowSizes = type(HUDCraftCharDB.windowSizes) == "table" and HUDCraftCharDB.windowSizes or {}
    HUDCraftCharDB.frameHeaderPositions = type(HUDCraftCharDB.frameHeaderPositions) == "table"
        and HUDCraftCharDB.frameHeaderPositions
        or (type(HUDCraftCharDB.windowTitlePositions) == "table" and HUDCraftCharDB.windowTitlePositions or {})
    if type(HUDCraftCharDB.lastSettingsPage) ~= "string" then
        HUDCraftCharDB.lastSettingsPage = addon.Defaults.Character.lastSettingsPage
    end

    if not self.UI then
        return
    end

    self.UI:RegisterConsumer(self.name, {
        windowState = function()
            return HUDCraftCharDB
        end,
        logger = function(message)
            self:AppendOutput(message)
        end,
    })

    self:CreateOutputWindow()
    self:CreateSettingsWindow()
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
        addon:ShowOutput()
    elseif command == "home" then
        addon:ShowSettings()
        addon:ShowSettingsPage(command)
    elseif command == "hide" then
        if addon.settingsWindow then addon.settingsWindow:Hide() end
        if addon.outputWindow then addon.outputWindow:Hide() end
    elseif command == "commands" then
        for _, line in ipairs(addon.commandHelpLines) do
            DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. line .. "|r")
        end
    elseif command == "" or command == "settings" then
        if addon.settingsWindow and addon.settingsWindow:IsShown() then
            addon.settingsWindow:Hide()
        else
            addon:ShowSettings()
        end
    else
        print("hudcraft: /hudcraft [commands|settings|home|debug|hide]")
    end
end
