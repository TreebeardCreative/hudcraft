local _, addon = ...

local function GetReputationAPI()
    local api = _G.C_Reputation
    return type(api) == "table" and api or nil
end

local function GetWatchedFaction()
    local api = GetReputationAPI()
    local getter = api and api.GetWatchedFactionData
    if type(getter) ~= "function" then return nil end

    local ok, data = pcall(getter)
    if not ok or type(data) ~= "table" or type(data.name) ~= "string" or data.name == "" then
        return nil
    end
    return data
end

local function GetFactionDataByID(factionID)
    local api = GetReputationAPI()
    local getter = api and api.GetFactionDataByID
    if type(getter) ~= "function" then return nil end
    local ok, data = pcall(getter, factionID)
    return ok and type(data) == "table" and data or nil
end

local function GetSettings()
    if type(HUDCraftCharDB) ~= "table" then return nil end
    HUDCraftCharDB.moduleSettings = type(HUDCraftCharDB.moduleSettings) == "table"
        and HUDCraftCharDB.moduleSettings or {}
    local config = HUDCraftCharDB.moduleSettings.reputation
    if type(config) ~= "table" then
        config = {}
        HUDCraftCharDB.moduleSettings.reputation = config
    end
    if type(config.selected) ~= "table" then config.selected = {} end
    if type(config.order) ~= "table" then config.order = {} end

    -- Preserve the first-pass behavior by starting with WoW's watched faction.
    -- After initialization, the user's HUDCraft selection is independent.
    if config.initialized ~= true then
        local watched = GetWatchedFaction()
        local factionID = watched and tonumber(watched.factionID)
        if factionID and factionID > 0 then
            config.selected[factionID] = true
            config.order[#config.order + 1] = factionID
        end
        config.initialized = true
    end
    return config
end

local function GetFactionEntries()
    local api = GetReputationAPI()
    if not api or type(api.GetNumFactions) ~= "function"
        or type(api.GetFactionDataByIndex) ~= "function" then
        return {}
    end

    local ok, count = pcall(api.GetNumFactions)
    if not ok then return {} end
    local entries, seen = {}, {}
    for index = 1, tonumber(count) or 0 do
        local success, data = pcall(api.GetFactionDataByIndex, index)
        local factionID = success and type(data) == "table" and tonumber(data.factionID)
        local validRow = type(data) == "table" and (data.isHeader ~= true or data.isHeaderWithRep == true)
        if validRow and factionID and factionID > 0 and type(data.name) == "string"
            and data.name ~= "" and not seen[factionID] then
            entries[#entries + 1] = { id = factionID, name = data.name }
            seen[factionID] = true
        end
    end
    return entries
end

local function GetSettingsEntries()
    GetSettings()
    return GetFactionEntries()
end

local function GetSelectedFactions()
    local config = GetSettings()
    if not config then return {}, {} end

    local entries = GetFactionEntries()
    local byID = {}
    for _, entry in ipairs(entries) do byID[entry.id] = entry end

    local selected, seen = {}, {}
    for _, id in ipairs(config.order) do
        id = tonumber(id)
        if id and config.selected[id] == true and byID[id] and not seen[id] then
            selected[#selected + 1] = byID[id]
            seen[id] = true
        end
    end
    for _, entry in ipairs(entries) do
        if config.selected[entry.id] == true and not seen[entry.id] then
            selected[#selected + 1] = entry
            seen[entry.id] = true
        end
    end
    return selected, entries
end

local function GetStandingLabel(reaction)
    reaction = tonumber(reaction)
    if not reaction then return nil end
    local index = math.floor(reaction)
    return _G["FACTION_STANDING_LABEL" .. tostring(index)] or ("Standing " .. tostring(index))
end

local function FormatStanding(value)
    value = math.floor(tonumber(value) or 0)
    if type(BreakUpLargeNumbers) == "function" then
        return BreakUpLargeNumbers(value)
    end
    return tostring(value)
end

local function GetProgress(faction)
    local standing = tonumber(faction.currentStanding)
    local minimum = tonumber(faction.currentReactionThreshold)
    local maximum = tonumber(faction.nextReactionThreshold)
    if standing and minimum and maximum and maximum > minimum then
        return math.max(0, standing - minimum), maximum - minimum
    end
    return nil, nil
end

local function GetFactionLine(faction)
    local current, maximum = GetProgress(faction)
    if current and maximum then
        return string.format("%s %s/%s", faction.name,
            FormatStanding(current), FormatStanding(maximum))
    end
    local standing = GetStandingLabel(faction.reaction)
    return standing and string.format("%s %s", faction.name, standing) or faction.name
end

local function GetFactionDetails(factionID)
    local faction = GetFactionDataByID(factionID)
    if not faction then return { "Faction reputation unavailable" } end

    local lines = { faction.name }
    local standing = GetStandingLabel(faction.reaction)
    if standing then lines[#lines + 1] = standing end

    local current, maximum = GetProgress(faction)
    if current and maximum then
        lines[#lines + 1] = string.format("Progress: %s / %s",
            FormatStanding(current), FormatStanding(maximum))
        local reaction = tonumber(faction.reaction)
        local nextStanding = reaction and reaction < 8 and GetStandingLabel(reaction + 1)
        local remaining = math.max(0, maximum - current)
        if remaining > 0 and nextStanding then
            lines[#lines + 1] = string.format("To %s: %s", nextStanding, FormatStanding(remaining))
        elseif remaining <= 0 then
            lines[#lines + 1] = "Maximum standing"
        end
    else
        lines[#lines + 1] = "Maximum standing"
    end
    return lines
end

local reputationModule = {
    id = "reputation",
    label = "Reputation",
    hasSettingsPage = true,
    -- Keeps the label right-clickable for Settings without opening Details on hover.
    interaction = { getDetails = function() return nil end },
}

local function GetReputationText(showLabel)
    local selected = GetSelectedFactions()
    local prefix = showLabel == false and "" or "Reputation: "
    if #selected == 0 then return prefix .. "None Tracked" end
    return prefix .. GetFactionLine(GetFactionDataByID(selected[1].id) or selected[1])
end

local function GetReputationGroupItems(_, showLabel)
    local selected = GetSelectedFactions()
    local items = {}
    if showLabel then
        items[#items + 1] = {
            key = "label",
            text = "Reputation:",
            module = reputationModule,
        }
    end
    if #selected == 0 then
        items[#items + 1] = { key = "status", text = "None Tracked" }
        return items
    end

    for _, entry in ipairs(selected) do
        local faction = GetFactionDataByID(entry.id)
        if faction then
            items[#items + 1] = {
                key = tostring(entry.id),
                text = GetFactionLine(faction),
                module = {
                    id = "reputation-faction-" .. tostring(entry.id),
                    label = faction.name,
                    interaction = {
                        getDetails = function() return GetFactionDetails(entry.id) end,
                    },
                },
                showDetails = true,
            }
        else
            items[#items + 1] = { key = tostring(entry.id), text = entry.name .. " unavailable" }
        end
    end
    return items
end

reputationModule.settingsDescription = "Choose the factions shown in each Group, then drag to set their display order. The main module shows current standing progress toward the next rank."
reputationModule.showLabelSetting = true
reputationModule.updateEvents = { "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" }
reputationModule.getText = GetReputationText
reputationModule.getGroupItems = GetReputationGroupItems
reputationModule.getSettingsEntries = GetSettingsEntries

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = reputationModule
