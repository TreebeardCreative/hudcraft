local addonName, addon = ...

addon.name = addonName
addon.version = "0.1.125"
addon.requiredTreebeardUIAPI = 1
addon.requiredTreebeardUIVersion = "0.2.50"

local function VersionAtLeast(version, required)
    local versionMajor, versionMinor, versionPatch = tostring(version or ""):match("^(%d+)%.(%d+)%.(%d+)$")
    local requiredMajor, requiredMinor, requiredPatch = tostring(required or ""):match("^(%d+)%.(%d+)%.(%d+)$")
    if not versionMajor or not requiredMajor then return false end
    local actual = { tonumber(versionMajor), tonumber(versionMinor), tonumber(versionPatch) }
    local minimum = { tonumber(requiredMajor), tonumber(requiredMinor), tonumber(requiredPatch) }
    for index = 1, 3 do
        if actual[index] ~= minimum[index] then return actual[index] > minimum[index] end
    end
    return true
end

local library = _G.TreebeardUI
addon.UI = library
addon.libraryCompatible = type(library) == "table"
    and library.API_VERSION == addon.requiredTreebeardUIAPI
    and VersionAtLeast(library.VERSION, addon.requiredTreebeardUIVersion)
    and type(library.HoverEffects) == "table"
    and type(library.HoverEffects.Attach) == "function"
    and type(library.NavigationControls) == "table"
    and type(library.NavigationControls.AddMainNavigationButton) == "function"
    and type(library.NavigationControls.AddSubpageNavigationButton) == "function"
    and type(library.NavigationControls.LayoutHorizontalButtons) == "function"
    and type(library.NavigationControls.CreateVerticalSubpageNavigation) == "function"
    and type(library.SettingsLayout) == "table"
    and type(library.SettingsLayout.BorderedSection) == "function"
    and type(library.ContextMenu) == "table"
    and type(library.ContextMenu.Create) == "function"
    and type(library.WindowFrame) == "table"
    and type(library.WindowFrame.Create) == "function"
    and type(library.WindowStyles) == "table"
    and type(library.WindowStyles.SetConsumerPreset) == "function"
    and type(library.SettingsPageHost) == "table"
    and type(library.SettingsPageHost.CreateEmbedded) == "function"
    and type(library.SettingsPageHost.BindSections) == "function"
    and type(library.SettingsPageMeasure) == "table"
    and type(library.SettingsPageMeasure.Create) == "function"
    and type(library.SettingsControls) == "table"
    and type(library.SettingsControls.AttachScrollbar) == "function"
    and type(library.SettingsControls.GetScrollbarGutterWidth) == "function"
    and type(library.ColorFactory) == "table"

if not addon.libraryCompatible then
    addon.UI = nil
    local message
    if type(library) == "table" and library.API_VERSION == addon.requiredTreebeardUIAPI then
            message = "hudcraft requires TreebeardUI 0.2.50 or newer for current framework helpers. Update TreebeardUI. Addon UI disabled."
    else
        message = string.format(
            "hudcraft requires TreebeardUI API %s; installed API %s. Addon UI disabled.",
            tostring(addon.requiredTreebeardUIAPI),
            tostring(type(library) == "table" and library.API_VERSION or "unavailable"))
    end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444" .. message .. "|r")
    elseif print then
        print(message)
    end
end



