local _, addon = ...

local function FormatClockTime(hour, minute, timeFormat)
    hour = math.floor(tonumber(hour) or 0) % 24
    minute = math.floor(tonumber(minute) or 0) % 60
    if timeFormat == "24h" then
        if type(TIMEMANAGER_TICKER_24HOUR) == "string" then
            return string.format(TIMEMANAGER_TICKER_24HOUR, hour, minute)
        end
        return string.format("%02d:%02d", hour, minute)
    end

    local suffix = hour < 12 and "AM" or "PM"
    hour = hour % 12
    if hour == 0 then hour = 12 end
    local localizedFormat = suffix == "AM" and TIME_TWELVEHOURAM or TIME_TWELVEHOURPM
    if type(localizedFormat) == "string" then
        return string.format(localizedFormat, hour, minute)
    end
    return string.format("%d:%02d %s", hour, minute, suffix)
end

local function GetClockText(options)
    options = type(options) == "table" and options or {}
    local source = options.source == "realm" and "realm" or "local"
    local blizzardTime
    if source == "realm" then
        blizzardTime = GameTime_GetGameTime
    else
        blizzardTime = GameTime_GetLocalTime
    end
    if type(blizzardTime) == "function" then
        local defaultText, hour, minute = blizzardTime(true)
        if options.format == nil then return defaultText end
        return FormatClockTime(hour, minute, options.format)
    end

    local hour, minute
    if source == "realm" and type(GetGameTime) == "function" then
        hour, minute = GetGameTime()
    else
        local localTime = date("*t")
        hour, minute = localTime.hour, localTime.min
    end
    return FormatClockTime(hour, minute, options.format)
end

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "clock",
    label = "Clock",
    refreshInterval = 5,
    getText = function()
        local general = type(HUDCraftDB) == "table" and type(HUDCraftDB.general) == "table"
            and HUDCraftDB.general
        return GetClockText({ source = general and general.clockSource })
    end,
}
