local _, addon = ...

local PROFESSION_SKILL_LINES = {
    { id = 171, name = "Alchemy", primary = true },
    { id = 164, name = "Blacksmithing", primary = true },
    { id = 333, name = "Enchanting", primary = true },
    { id = 202, name = "Engineering", primary = true },
    { id = 182, name = "Herbalism", primary = true },
    { id = 773, name = "Inscription", primary = true },
    { id = 755, name = "Jewelcrafting", primary = true },
    { id = 165, name = "Leatherworking", primary = true },
    { id = 186, name = "Mining", primary = true },
    { id = 393, name = "Skinning", primary = true },
    { id = 197, name = "Tailoring", primary = true },
    { id = 185, name = "Cooking", primary = false },
    { id = 129, name = "First Aid", primary = false },
    { id = 356, name = "Fishing", primary = false },
}

local function GetProfessionEntries()
    local skillInfo = C_SkillInfo
    if type(skillInfo) ~= "table" or type(skillInfo.GetSkillLineInfoByID) ~= "function" then
        return nil
    end

    local primary, secondary = {}, {}
    for _, profession in ipairs(PROFESSION_SKILL_LINES) do
        local info = skillInfo.GetSkillLineInfoByID(profession.id)
        if type(info) == "table" and type(info.rank) == "number"
            and type(info.maxRank) == "number" and info.maxRank > 0 then
            local entry = {
                id = profession.id,
                name = info.name or profession.name,
                rank = info.rank,
                maxRank = info.maxRank,
            }
            local target = profession.primary and primary or secondary
            target[#target + 1] = entry
        end
    end

    local entries = {}
    for _, entry in ipairs(primary) do entries[#entries + 1] = entry end
    for _, entry in ipairs(secondary) do entries[#entries + 1] = entry end
    return entries
end

local function GetTrackingConfig()
    local allSettings = HUDCraftCharDB and HUDCraftCharDB.moduleSettings
    local config = type(allSettings) == "table" and allSettings.professions
    return type(config) == "table" and config or nil
end

local function GetOrderedEntries(entries, selectedOnly)
    local config = GetTrackingConfig()
    local byId, ordered, seen = {}, {}, {}
    for _, entry in ipairs(entries or {}) do byId[entry.id] = entry end
    if config and type(config.order) == "table" then
        for _, id in ipairs(config.order) do
            local entry = byId[id]
            if entry and not seen[id] and (not selectedOnly
                or (type(config.selected) == "table" and config.selected[id] == true)) then
                ordered[#ordered + 1] = entry
                seen[id] = true
            end
        end
    end
    for _, entry in ipairs(entries or {}) do
        local selected = not config or type(config.selected) ~= "table" or config.selected[entry.id] == true
        if not seen[entry.id] and (not selectedOnly or selected) then
            ordered[#ordered + 1] = entry
            seen[entry.id] = true
        end
    end
    return ordered
end

local function GetProfessionText()
    local entries = GetProfessionEntries()
    if not entries then return "Professions: unavailable" end
    local tracked = GetOrderedEntries(entries, true)
    if #tracked == 0 then return "Professions: none tracked" end
    local labels = {}
    for _, entry in ipairs(tracked) do
        labels[#labels + 1] = string.format("%s %d/%d", entry.name, entry.rank, entry.maxRank)
    end
    return "Professions: " .. table.concat(labels, "  |  ")
end

local function GetProfessionGroupItems(orientation, showLabel)
    showLabel = showLabel ~= false
    local entries = GetProfessionEntries()
    local items = {}
    if showLabel then items[#items + 1] = { key = "label", text = "Professions:", showDetails = true } end
    if not entries then
        items[#items + 1] = { key = "status", text = "Unavailable" }
        return items
    end

    local tracked = GetOrderedEntries(entries, true)
    if #tracked == 0 then
        items[#items + 1] = { key = "status", text = "None Tracked" }
        return items
    end

    for _, entry in ipairs(tracked) do
        items[#items + 1] = {
            key = entry.id,
            text = string.format("%s %d/%d", entry.name, entry.rank, entry.maxRank),
        }
    end
    return items
end

local function GetProfessionDetails()
    local entries = GetProfessionEntries()
    if not entries then return nil end
    local config = GetTrackingConfig()
    local extras = {}
    for _, entry in ipairs(GetOrderedEntries(entries, false)) do
        if config and type(config.selected) == "table" and config.selected[entry.id] ~= true then
            extras[#extras + 1] = entry
        end
    end
    if #extras == 0 then return nil end
    local lines = {}
    for _, entry in ipairs(extras) do
        lines[#lines + 1] = string.format("%s  %d/%d", entry.name, entry.rank, entry.maxRank)
    end
    return lines
end

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "professions",
    label = "Professions",
    updateEvents = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_ENTERING_WORLD" },
    getText = GetProfessionText,
    getGroupItems = GetProfessionGroupItems,
    getSettingsEntries = GetProfessionEntries,
    interaction = { getDetails = GetProfessionDetails },
}
