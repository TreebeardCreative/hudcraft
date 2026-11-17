local _, addon = ...

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "performance",
    label = "Performance",
    refreshInterval = 5,
    getText = function()
        local _, _, home, world = GetNetStats()
        return string.format("%.0f FPS  %d ms", GetFramerate() or 0, world or home or 0)
    end,
    interaction = {
        getDetails = function()
            local bandwidthIn, bandwidthOut, home, world = GetNetStats()
            return {
                string.format("Frames per second: %.0f", GetFramerate() or 0),
                string.format("Home latency: %d ms", tonumber(home) or 0),
                string.format("World latency: %d ms", tonumber(world) or 0),
                string.format("Download: %.2f KB/s", tonumber(bandwidthIn) or 0),
                string.format("Upload: %.2f KB/s", tonumber(bandwidthOut) or 0),
            }
        end,
    },
}
