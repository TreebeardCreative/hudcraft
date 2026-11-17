local _, addon = ...

local SAMPLE_WINDOW_SECONDS = 10 * 60
local LEVEL_REWARD_DISCOUNT = 0.95
local observedLevel

local function CurrentTime()
    if type(GetServerTime) == "function" then return GetServerTime() end
    if type(time) == "function" then return time() end
    return 0
end

local function EnsureSamples()
    if type(HUDCraftCharDB) ~= "table" then return {} end
    if type(HUDCraftCharDB.experienceKillSamples) ~= "table" then
        HUDCraftCharDB.experienceKillSamples = {}
    end
    return HUDCraftCharDB.experienceKillSamples
end

local function PruneSamples(now)
    local samples = EnsureSamples()
    local cutoff = now - SAMPLE_WINDOW_SECONDS
    for index = #samples, 1, -1 do
        local sample = samples[index]
        if type(sample) ~= "table" or type(sample.time) ~= "number"
            or type(sample.xp) ~= "number" or sample.xp <= 0 or sample.time < cutoff then
            table.remove(samples, index)
        end
    end
    return samples
end

local function ReconcileLevel()
    local level = tonumber(UnitLevel("player"))
    if not level or level <= 0 then return end
    local samples = EnsureSamples()
    if observedLevel and level > observedLevel then
        local discount = LEVEL_REWARD_DISCOUNT ^ (level - observedLevel)
        for _, sample in ipairs(samples) do sample.xp = sample.xp * discount end
    end
    observedLevel = level
    if type(HUDCraftCharDB) == "table" then
        HUDCraftCharDB.experienceObservedLevel = level
    end
end

local function LoadHistory()
    local savedLevel = type(HUDCraftCharDB) == "table"
        and tonumber(HUDCraftCharDB.experienceObservedLevel)
    observedLevel = savedLevel
    EnsureSamples()
    ReconcileLevel()
    PruneSamples(CurrentTime())
end

local function ParseCreatureKillXP(message)
    if type(message) ~= "string" then return nil end
    local value
    local format = _G.COMBATLOG_XPGAIN_FIRSTPERSON
    if type(format) == "string" then
        local pattern, index = { "^" }, 1
        while index <= #format do
            local character = format:sub(index, index)
            if character == "%" and index < #format then
                local token = format:sub(index + 1, index + 1)
                if token == "s" then
                    pattern[#pattern + 1] = ".+"
                    index = index + 2
                elseif token == "d" then
                    pattern[#pattern + 1] = "([%d%p]+)"
                    index = index + 2
                else
                    pattern[#pattern + 1] = "%%"
                    index = index + 1
                end
            else
                if character:match("[%^%$%(%)%.%[%]%*%+%-%?]") then
                    pattern[#pattern + 1] = "%"
                end
                pattern[#pattern + 1] = character
                index = index + 1
            end
        end
        value = message:match(table.concat(pattern))
    end
    if not value then
        -- CHAT_MSG_COMBAT_XP_GAIN also fires for quest rewards. Only count the
        -- creature-death wording when the localized format string is missing.
        value = message:match("^.+ dies, you gain ([%d,]+) experience%.?$")
    end
    if not value then return nil end
    local amount = tonumber((value:gsub("%D", "")))
    return amount and amount > 0 and amount or nil
end

local xpEvents = CreateFrame("Frame")
xpEvents:RegisterEvent("PLAYER_LOGIN")
xpEvents:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
xpEvents:RegisterEvent("PLAYER_LEVEL_UP")
xpEvents:RegisterEvent("PLAYER_XP_UPDATE")
xpEvents:SetScript("OnEvent", function(_, event, message)
    if event == "PLAYER_LOGIN" then
        LoadHistory()
        return
    end

    if event == "PLAYER_LEVEL_UP" then
        ReconcileLevel()
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        local gained = ParseCreatureKillXP(message)
        if gained then
            local now = CurrentTime()
            local samples = PruneSamples(now)
            samples[#samples + 1] = { time = now, xp = gained }
            ReconcileLevel()
        end
    end

    if type(addon.RefreshAllGroups) == "function" then
        addon:RefreshAllGroups({ "experience" })
    end
end)

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then return string.format("%d h %d min", hours, minutes) end
    if minutes > 0 then return string.format("%d min", minutes) end
    return "less than 1 min"
end

local function GetDetails()
    local now = CurrentTime()
    local samples = PruneSamples(now)
    ReconcileLevel()

    local current, maximum = tonumber(UnitXP("player")) or 0, tonumber(UnitXPMax("player")) or 0
    if maximum <= 0 then return { "At max level" } end
    local remaining = math.max(0, maximum - current)
    local percent = maximum > 0 and (current / maximum * 100) or 0
    local totalXP, firstTime = 0, nil
    for _, sample in ipairs(samples) do
        totalXP = totalXP + sample.xp
        firstTime = not firstTime and sample.time or math.min(firstTime, sample.time)
    end

    local lines = {
        string.format("XP remaining: %d (%.1f%% complete)", remaining, percent),
    }
    local elapsed = firstTime and math.min(SAMPLE_WINDOW_SECONDS, math.max(0, now - firstTime)) or 0
    if #samples > 0 and elapsed >= 60 then
        local xpPerSecond = totalXP / elapsed
        local averageXPPerKill = totalXP / #samples
        lines[#lines + 1] = string.format("Rate: %.0f XP/hour", xpPerSecond * 3600)
        lines[#lines + 1] = string.format("Time to level: %s", FormatDuration(remaining / xpPerSecond))
        if averageXPPerKill > 0 then
            lines[#lines + 1] = string.format("Estimated kills to level: %d",
                math.ceil(remaining / averageXPPerKill))
        end
    else
        local sampledSeconds = math.min(SAMPLE_WINDOW_SECONDS, math.max(0, now - (firstTime or now)))
        lines[#lines + 1] = string.format("Kill XP rate: sampling (%d/%d sec)",
            sampledSeconds, SAMPLE_WINDOW_SECONDS)
        lines[#lines + 1] = "Time to level: sampling"
        lines[#lines + 1] = "Estimated kills to level: sampling"
    end
    return lines
end

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "experience",
    label = "Experience",
    updateEvents = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" },
    getText = function()
        local current, maximum = tonumber(UnitXP("player")) or 0, tonumber(UnitXPMax("player")) or 0
        if maximum <= 0 then return "XP —" end
        return string.format("XP: %d%%", math.floor(current / maximum * 100 + 0.5))
    end,
    interaction = {
        getDetails = GetDetails,
    },
}
