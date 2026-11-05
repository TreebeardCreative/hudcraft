local _, addon = ...

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "performance",
    label = "Performance",
    getText = function()
        local _, _, home, world = GetNetStats()
        return string.format("%.0f FPS  %d ms", GetFramerate() or 0, world or home or 0)
    end,
}
