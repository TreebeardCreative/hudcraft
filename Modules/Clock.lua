local _, addon = ...

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "clock",
    label = "Clock",
    getText = function()
        return date("%H:%M")
    end,
}
