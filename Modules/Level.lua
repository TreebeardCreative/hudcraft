local _, addon = ...

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "level",
    label = "Level",
    updateEvents = { "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" },
    getText = function()
        return "Level " .. tostring(UnitLevel("player") or "—")
    end,
}
