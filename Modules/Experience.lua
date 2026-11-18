local _, addon = ...

-- Raw kill events and completed minute/ten-minute points are kept for one hour.
-- Zero-XP minute points preserve the timeline but are excluded from the active
-- XP-rate denominator, so short breaks do not lower the active-play estimate.
local RAW_HISTORY_SECONDS = 60 * 60
local KILL_AVERAGE_SAMPLE_COUNT = 20
local MINUTE_SECONDS = 60
local TEN_MINUTE_SECONDS = 10 * MINUTE_SECONDS
local MINUTE_POINT_LIMIT = RAW_HISTORY_SECONDS / MINUTE_SECONDS
local TEN_MINUTE_POINT_LIMIT = RAW_HISTORY_SECONDS / TEN_MINUTE_SECONDS
local FIVE_MINUTE_POINT_COUNT = 5 * 60 / MINUTE_SECONDS
local TEN_MINUTE_POINT_COUNT = TEN_MINUTE_SECONDS / MINUTE_SECONDS
local LEVEL_REWARD_DISCOUNT = 0.95
local observedLevel

local function CurrentTime()
    if type(GetServerTime) == "function" then return GetServerTime() end
    if type(time) == "function" then return time() end
    return 0
end

local function CharacterData()
    if type(HUDCraftCharDB) ~= "table" then return nil end
    return HUDCraftCharDB
end

local function EnsureTable(data, key)
    if type(data[key]) ~= "table" then data[key] = {} end
    return data[key]
end

local function EnsureSamples(data)
    return EnsureTable(data, "experienceKillSamples")
end

local function PruneList(list, cutoff, valid)
    for index = #list, 1, -1 do
        local item = list[index]
        if type(item) ~= "table" or type(item.time) ~= "number"
            or item.time < cutoff or not valid(item) then
            table.remove(list, index)
        end
    end
end

local function PruneSamples(data, now)
    local samples = EnsureSamples(data)
    PruneList(samples, now - RAW_HISTORY_SECONDS, function(sample)
        return type(sample.xp) == "number" and sample.xp > 0
    end)
    return samples
end

local function SumSamples(samples, startTime, endTime)
    local total = 0
    for _, sample in ipairs(samples) do
        if sample.time >= startTime and sample.time < endTime then
            total = total + sample.xp
        end
    end
    return total
end

local function AppendPoint(points, point, limit)
    points[#points + 1] = point
    while #points > limit do table.remove(points, 1) end
end

local function AdvanceHistory(data, now)
    local samples = PruneSamples(data, now)
    local minutePoints = EnsureTable(data, "experienceMinutePoints")
    local tenMinutePoints = EnsureTable(data, "experienceTenMinutePoints")

    PruneList(minutePoints, now - RAW_HISTORY_SECONDS, function(point)
        return type(point.xp) == "number" and point.xp >= 0
    end)
    PruneList(tenMinutePoints, now - RAW_HISTORY_SECONDS, function(point)
        return type(point.xp) == "number" and point.xp >= 0
    end)

    local cursor = tonumber(data.experienceMinuteCursor)
    if not cursor then
        local firstSample = samples[1]
        if not firstSample then return samples end
        cursor = firstSample.time
        data.experienceMinuteCursor = cursor
        data.experienceTenMinuteCursor = cursor
    end

    -- A long absence should not make the catch-up loop walk every offline
    -- minute. Rebase to the earliest retained event (or now) once all saved
    -- interval history is older than the one-hour window.
    if cursor + MINUTE_SECONDS < now - RAW_HISTORY_SECONDS then
        cursor = samples[1] and samples[1].time or now
        data.experienceMinuteCursor = cursor
        data.experienceTenMinuteCursor = cursor
        for index = #minutePoints, 1, -1 do minutePoints[index] = nil end
        for index = #tenMinutePoints, 1, -1 do tenMinutePoints[index] = nil end
    elseif not tonumber(data.experienceTenMinuteCursor) then
        data.experienceTenMinuteCursor = cursor
    end

    -- Fill every completed minute, including intervals with no kills. The
    -- first interval begins at the first observed kill, so startup idle time
    -- does not dilute the initial estimate.
    while cursor + MINUTE_SECONDS <= now do
        local endTime = cursor + MINUTE_SECONDS
        local xp = SumSamples(samples, cursor, endTime)
        AppendPoint(minutePoints, { time = endTime, xp = xp }, MINUTE_POINT_LIMIT)
        cursor = endTime
        data.experienceMinuteCursor = cursor

        local tenCursor = tonumber(data.experienceTenMinuteCursor) or cursor
        if cursor - tenCursor >= TEN_MINUTE_SECONDS then
            local intervalStart = cursor - TEN_MINUTE_SECONDS
            local total = SumSamples(samples, intervalStart, cursor)
            AppendPoint(tenMinutePoints, { time = cursor, xp = total }, TEN_MINUTE_POINT_LIMIT)
            data.experienceTenMinuteCursor = cursor
        end
    end

    return samples
end

local function UpdateAverageXPPerKill(data, samples, now)
    if #samples == 0 then return end
    local first = math.max(1, #samples - KILL_AVERAGE_SAMPLE_COUNT + 1)
    local total, count = 0, 0
    for index = first, #samples do
        local sample = samples[index]
        total = total + (tonumber(sample.averageXP) or sample.xp)
        count = count + 1
    end
    data.experienceAverageXPPerKill = count > 0 and total / count or nil
    data.experienceAverageXPPerKillUpdated = now
end

local function ReconcileLevel()
    local level = tonumber(UnitLevel("player"))
    if not level or level <= 0 then return false end
    local data = CharacterData()
    if not data then return false end

    if observedLevel and level > observedLevel then
        local discount = LEVEL_REWARD_DISCOUNT ^ (level - observedLevel)
        for _, sample in ipairs(EnsureSamples(data)) do sample.xp = sample.xp * discount end
        if tonumber(data.experienceAverageXPPerKill) then
            data.experienceAverageXPPerKill = data.experienceAverageXPPerKill * discount
            data.experienceAverageXPPerKillUpdated = CurrentTime()
        end
        -- Existing points describe the previous level's kill value. Apply the
        -- same conservative adjustment so they remain useful until replaced.
        for _, point in ipairs(EnsureTable(data, "experienceMinutePoints")) do
            point.xp = point.xp * discount
        end
        for _, point in ipairs(EnsureTable(data, "experienceTenMinutePoints")) do
            point.xp = point.xp * discount
        end
    end

    observedLevel = level
    data.experienceObservedLevel = level
    return true
end

local function LoadHistory()
    local data = CharacterData()
    if not data then return end
    observedLevel = tonumber(data.experienceObservedLevel)
    EnsureSamples(data)
    EnsureTable(data, "experienceMinutePoints")
    EnsureTable(data, "experienceTenMinutePoints")
    ReconcileLevel()
    local now = CurrentTime()
    local samples = AdvanceHistory(data, now)
    UpdateAverageXPPerKill(data, samples, now)
end

local function RefreshVisibleExperienceDetails()
    if type(addon.ShowGroupModuleDetails) ~= "function" then return end
    for groupId, frame in pairs(addon.groupDetails or {}) do
        local module = frame and frame.detailModule
        if frame and frame:IsShown() and module and module.id == "experience" then
            addon:ShowGroupModuleDetails(groupId, module, frame.detailSource)
        end
    end
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

    local data = CharacterData()
    if data then
        local now = CurrentTime()
        if event == "PLAYER_LEVEL_UP" then
            ReconcileLevel()
            local samples = PruneSamples(data, now)
            UpdateAverageXPPerKill(data, samples, now)
            AdvanceHistory(data, now)
        elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
            local gained = ParseCreatureKillXP(message)
            if gained then
                -- Reconcile first so a kill received alongside a level-up is
                -- treated as a kill at the new level, not discounted as old XP.
                ReconcileLevel()
                local samples = PruneSamples(data, now)
                samples[#samples + 1] = { time = now, xp = gained, averageXP = gained }
                UpdateAverageXPPerKill(data, samples, now)
                AdvanceHistory(data, now)
            end
        else
            AdvanceHistory(data, now)
        end
    end

    if type(addon.RefreshAllGroups) == "function" then
        addon:RefreshAllGroups({ "experience" })
    end
    if event == "CHAT_MSG_COMBAT_XP_GAIN" or event == "PLAYER_LEVEL_UP" then
        RefreshVisibleExperienceDetails()
    end
end)

-- Advance idle zero-XP intervals even when no events occur. The saved cursors
-- also let login catch up cleanly if the game was closed between checkpoints.
if type(C_Timer) == "table" and type(C_Timer.NewTicker) == "function" then
    C_Timer.NewTicker(MINUTE_SECONDS, function()
        local data = CharacterData()
        if data then AdvanceHistory(data, CurrentTime()) end
        if type(addon.RefreshAllGroups) == "function" then
            addon:RefreshAllGroups({ "experience" })
        end
        RefreshVisibleExperienceDetails()
    end)
end

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then return string.format("%d h %d min", hours, minutes) end
    if minutes > 0 then return string.format("%d min", minutes) end
    return "less than 1 min"
end

local function AverageActiveMinuteRate(points, activeMinuteCount)
    local totalXP, activeMinutes = 0, 0
    for index = #points, 1, -1 do
        local xp = tonumber(points[index].xp) or 0
        if xp > 0 then
            totalXP = totalXP + xp
            activeMinutes = activeMinutes + 1
            if activeMinutes >= activeMinuteCount then break end
        end
    end
    if activeMinutes == 0 then return nil end
    return totalXP / (activeMinutes * MINUTE_SECONDS)
end

local function AddWeightedRate(total, totalWeight, points, activeMinuteCount, weight)
    local rate = AverageActiveMinuteRate(points, activeMinuteCount)
    if not rate then return total, totalWeight end
    return total + rate * weight, totalWeight + weight
end

local function GetDetails()
    local data = CharacterData()
    local now = CurrentTime()
    local samples = data and AdvanceHistory(data, now) or {}
    ReconcileLevel()

    local current = tonumber(UnitXP("player")) or 0
    local maximum = tonumber(UnitXPMax("player")) or 0
    if maximum <= 0 then return { "At max level" } end
    local remaining = math.max(0, maximum - current)
    local percent = current / maximum * 100
    local lines = {
        string.format("XP remaining: %d (%.1f%% complete)", remaining, percent),
    }

    local rate
    if data then
        local minutePoints = EnsureTable(data, "experienceMinutePoints")
        local weightedTotal, totalWeight = 0, 0
        -- Weight recent active minutes most; use longer active windows as they
        -- fill. Zero-XP minutes are skipped, so brief breaks do not dilute rate.
        weightedTotal, totalWeight = AddWeightedRate(weightedTotal, totalWeight,
            minutePoints, 1, 50)
        weightedTotal, totalWeight = AddWeightedRate(weightedTotal, totalWeight,
            minutePoints, FIVE_MINUTE_POINT_COUNT, 25)
        weightedTotal, totalWeight = AddWeightedRate(weightedTotal, totalWeight,
            minutePoints, TEN_MINUTE_POINT_COUNT, 15)
        weightedTotal, totalWeight = AddWeightedRate(weightedTotal, totalWeight,
            minutePoints, MINUTE_POINT_LIMIT, 10)
        if totalWeight > 0 then rate = weightedTotal / totalWeight end
    end

    if rate and rate > 0 then
        lines[#lines + 1] = string.format("Active rate: %.0f XP/hour", rate * 3600)
        lines[#lines + 1] = string.format("Active time to level: %s", FormatDuration(remaining / rate))
    elseif #samples > 0 then
        lines[#lines + 1] = "Rate: 0 XP/hour"
        lines[#lines + 1] = "Time to level: not currently gaining XP"
    else
        lines[#lines + 1] = "Kill XP rate: sampling"
        lines[#lines + 1] = "Time to level: sampling"
    end

    local averageXPPerKill = data and tonumber(data.experienceAverageXPPerKill)
    if averageXPPerKill and averageXPPerKill > 0 then
        lines[#lines + 1] = string.format("Estimated kills to level: %d",
            math.ceil(remaining / averageXPPerKill))
    else
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
