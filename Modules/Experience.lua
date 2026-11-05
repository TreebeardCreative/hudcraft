local _, addon = ...

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "experience",
    label = "Experience",
    updateEvents = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" },
    getText = function()
        local current, maximum = UnitXP("player") or 0, UnitXPMax("player") or 0
        if maximum <= 0 then return "XP —" end
        return string.format("XP %d%%", math.floor(current / maximum * 100 + 0.5))
    end,
}
