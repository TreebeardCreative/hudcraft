local addonName, addon = ...

addon.name = addonName
addon.version = "0.1.1"
addon.requiredTreebeardUIAPI = 1

local library = _G.TreebeardUI
addon.UI = library
addon.libraryCompatible = type(library) == "table"
    and library.API_VERSION == addon.requiredTreebeardUIAPI

if not addon.libraryCompatible then
    addon.UI = nil
    local message = string.format(
        "hudcraft requires TreebeardUI API %s; installed API %s. Addon UI disabled.",
        tostring(addon.requiredTreebeardUIAPI),
        tostring(type(library) == "table" and library.API_VERSION or "unavailable"))
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444" .. message .. "|r")
    elseif print then
        print(message)
    end
end



