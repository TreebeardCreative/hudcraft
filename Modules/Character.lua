local _, addon = ...

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "character",
    label = "Character",
    updateEvents = { "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" },
    getText = function()
        local level = UnitLevel("player") or "—"
        local className = UnitClass("player")
        if className and className ~= "" then
            return string.format("Level %s %s", tostring(level), className)
        end
        return "Level " .. tostring(level)
    end,
}
