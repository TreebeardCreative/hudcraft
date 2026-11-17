local _, addon = ...

local WEAPON_SKILLS = {
    ["Axes"] = true,
    ["Two-Handed Axes"] = true,
    ["Bows"] = true,
    ["Crossbows"] = true,
    ["Daggers"] = true,
    ["Fist Weapons"] = true,
    ["Guns"] = true,
    ["Maces"] = true,
    ["Two-Handed Maces"] = true,
    ["Polearms"] = true,
    ["Staves"] = true,
    ["Swords"] = true,
    ["Two-Handed Swords"] = true,
    ["Thrown"] = true,
    ["Unarmed"] = true,
    ["Wands"] = true,
    ["Defense"] = true,
    ["Feral Combat"] = true,
}

local function GetLearnedWeaponSkills()
    local skillInfo = C_SkillInfo
    if type(skillInfo) ~= "table"
        or type(skillInfo.GetNumSkillLines) ~= "function"
        or type(skillInfo.GetSkillLineInfo) ~= "function" then
        return nil
    end

    local rows, seen = {}, {}
    for index = 1, skillInfo.GetNumSkillLines() do
        local info = skillInfo.GetSkillLineInfo(index)
        if type(info) == "table" and not info.isHeader and WEAPON_SKILLS[info.name]
            and type(info.rank) == "number" and type(info.maxRank) == "number"
            and info.maxRank > 0 then
            local previous = seen[info.name]
            if not previous or info.maxRank > previous.maxRank
                or (info.maxRank == previous.maxRank and info.rank > previous.rank) then
                local row = { id = info.name, name = info.name, rank = info.rank, maxRank = info.maxRank }
                if previous then
                    for rowIndex, existing in ipairs(rows) do
                        if existing == previous then rows[rowIndex] = row break end
                    end
                else
                    rows[#rows + 1] = row
                end
                seen[info.name] = row
            end
        end
    end
    table.sort(rows, function(left, right) return left.name < right.name end)
    return rows
end

local function GetTrackingConfig()
    local allSettings = HUDCraftCharDB and HUDCraftCharDB.moduleSettings
    local config = type(allSettings) == "table" and allSettings.weaponSkills
    return type(config) == "table" and config or nil
end

local function GetOrderedRows(rows, selectedOnly)
    local config = GetTrackingConfig()
    local byId, ordered, seen = {}, {}, {}
    for _, row in ipairs(rows or {}) do byId[row.id] = row end

    if config and type(config.order) == "table" then
        for _, id in ipairs(config.order) do
            local row = byId[id]
            if row and not seen[id] and (not selectedOnly
                or (type(config.selected) == "table" and config.selected[id] == true)) then
                ordered[#ordered + 1] = row
                seen[id] = true
            end
        end
    end
    for _, row in ipairs(rows or {}) do
        local selected = not config or type(config.selected) ~= "table" or config.selected[row.id] == true
        if not seen[row.id] and (not selectedOnly or selected) then
            ordered[#ordered + 1] = row
            seen[row.id] = true
        end
    end
    return ordered
end

local function GetWeaponSkillLabel(orientation)
    local rows = GetLearnedWeaponSkills()
    if not rows then return "Weapon Skills: unavailable" end
    local tracked = GetOrderedRows(rows, true)
    if #tracked == 0 then return "Weapon Skills: None Tracked" end
    local labels = {}
    for _, row in ipairs(tracked) do
        labels[#labels + 1] = string.format("%s %d/%d", row.name, row.rank, row.maxRank)
    end
    if orientation == "column" then
        return "Weapon Skills:\n" .. table.concat(labels, "\n")
    end
    return "Weapon Skills: " .. table.concat(labels, "  |  ")
end

local function GetWeaponSkillGroupItems(orientation, showLabel)
    showLabel = showLabel ~= false
    local rows = GetLearnedWeaponSkills()
    local items = {}
    if showLabel then items[#items + 1] = { key = "label", text = "Weapon Skills:", showDetails = true } end
    if not rows then
        items[#items + 1] = { key = "status", text = "Unavailable" }
        return items
    end

    local tracked = GetOrderedRows(rows, true)
    if #tracked == 0 then
        items[#items + 1] = { key = "status", text = "None Tracked" }
        return items
    end

    for _, row in ipairs(tracked) do
        items[#items + 1] = {
            key = row.id,
            text = string.format("%s %d/%d", row.name, row.rank, row.maxRank),
        }
    end
    return items
end

local function GetWeaponSkillDetails()
    local rows = GetLearnedWeaponSkills()
    if not rows then return nil end
    local untracked = GetOrderedRows(rows, false)
    local config = GetTrackingConfig()
    local extras = {}
    for _, row in ipairs(untracked) do
        if config and type(config.selected) == "table" and config.selected[row.id] ~= true then
            extras[#extras + 1] = row
        end
    end
    if #extras == 0 then return nil end
    local lines = {}
    for _, row in ipairs(extras) do
        lines[#lines + 1] = string.format("%s  %d/%d", row.name, row.rank, row.maxRank)
    end
    return lines
end

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "weaponSkills",
    label = "Weapon Skills",
    hoverEffect = {
        column = {
            fillWidthScale = 1.0,
            lineWidthScale = 1.0,
        },
    },
    updateEvents = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" },
    getText = GetWeaponSkillLabel,
    getGroupItems = GetWeaponSkillGroupItems,
    getSettingsEntries = GetLearnedWeaponSkills,
    interaction = { getDetails = GetWeaponSkillDetails },
}
