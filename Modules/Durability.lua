local _, addon = ...

local EQUIPMENT_GROUPS = {
    {
        id = "armor",
        label = "Armor",
        slots = {
            { id = 1, name = "Head" },
            { id = 3, name = "Shoulders" },
            { id = 5, name = "Chest" },
            { id = 6, name = "Waist" },
            { id = 7, name = "Legs" },
            { id = 8, name = "Feet" },
            { id = 9, name = "Wrists" },
            { id = 10, name = "Hands" },
        },
    },
    {
        id = "weapons",
        label = "Weapons",
        slots = {
            { id = 16, name = "Main Hand" },
            { id = 17, name = "Off Hand" },
            { id = 18, name = "Ranged" },
        },
    },
}

local EQUIPMENT_SLOTS = {}
for _, group in ipairs(EQUIPMENT_GROUPS) do
    for _, slot in ipairs(group.slots) do
        EQUIPMENT_SLOTS[#EQUIPMENT_SLOTS + 1] = slot
    end
end

local function GetConfig()
    local db = HUDCraftCharDB
    if type(db) ~= "table" then return nil end
    db.moduleSettings = type(db.moduleSettings) == "table" and db.moduleSettings or {}
    local config = db.moduleSettings.durability
    if type(config) ~= "table" then
        config = {}
        db.moduleSettings.durability = config
    end
    config.excludedSlots = type(config.excludedSlots) == "table" and config.excludedSlots or {}
    if config.mode ~= "lowest" then config.mode = "average" end
    return config
end

local function ReadEquippedSlots()
    local rows = {}
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local current, maximum
        if type(GetInventoryItemDurability) == "function" then
            current, maximum = GetInventoryItemDurability(slot.id)
        end
        if type(current) == "number" and type(maximum) == "number" and maximum > 0 then
            local row = {
                id = slot.id,
                name = slot.name,
                current = math.max(0, current),
                maximum = maximum,
                percent = math.floor(math.max(0, math.min(1, current / maximum)) * 100 + 0.5),
            }
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function GetIncludedRows(rows)
    local config = GetConfig()
    local included = {}
    for _, row in ipairs(rows or {}) do
        if not config or config.excludedSlots[row.id] ~= true then
            included[#included + 1] = row
        end
    end
    return included
end

local function GetSummary()
    local rows = ReadEquippedSlots()
    local included = GetIncludedRows(rows)
    if #included == 0 then return nil, rows end
    local config = GetConfig()
    if config and config.mode == "lowest" then
        local lowest = included[1]
        for index = 2, #included do
            if included[index].percent < lowest.percent then lowest = included[index] end
        end
        return string.format("%s %d%%", lowest.name, lowest.percent), rows
    end

    local totalPercent = 0
    for _, row in ipairs(included) do
        totalPercent = totalPercent + row.percent
    end
    return string.format("%d%%", math.floor(totalPercent / #included + 0.5)), rows
end

local function GetDurabilityText()
    local summary = GetSummary()
    return summary and ("Durability: " .. summary) or "Durability: —"
end

local function GetEstimatedRepairCost()
    local tooltipInfo = C_TooltipInfo
    if type(tooltipInfo) ~= "table" or type(tooltipInfo.GetInventoryItem) ~= "function" then
        return 0
    end

    local total = 0
    for _, slot in ipairs(EQUIPMENT_SLOTS) do
        local data = tooltipInfo.GetInventoryItem("player", slot.id)
        local cost = type(data) == "table" and tonumber(data.repairCost)
        if cost and cost > 0 then total = total + cost end
    end
    return math.max(0, math.floor(total + 0.5))
end

local function GetDurabilityDetails()
    local rows = ReadEquippedSlots()
    local config = GetConfig()
    local lines = {}
    if #rows == 0 then
        lines[#lines + 1] = "No equipped items with durability"
    else
        for _, row in ipairs(rows) do
            local suffix = config and config.excludedSlots[row.id] == true and " (excluded)" or ""
            lines[#lines + 1] = string.format("%s %d%% (%d/%d)%s",
                row.name, row.percent, row.current, row.maximum, suffix)
        end
    end
    local copper = GetEstimatedRepairCost()
    lines[#lines + 1] = string.format("Estimated Repair Cost: %dg %ds %dc",
        math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
    return lines
end

local function BuildSettings(flow, services)
    local layout, controls = services.layout, services.controls
    local config = GetConfig()
    local section = layout:Section(flow, "hudcraft-module-durability")
    layout:AddContent(flow, section, { fillWidth = true })
    layout:AreaHeader(section, "Durability")
    local note = layout:Note(section,
        "Choose how the Group summary is calculated and exclude slots that should not affect it. Neck, shirt, back, rings, trinkets, and tabard do not have durability and are not listed. Details still shows excluded equipped items.",
        { justifyH = "LEFT" })
    layout:AddContent(section, note, { fillWidth = true, wrap = true })

    local modeOptions = {
        { name = "Average durability", value = "average" },
        { name = "Lowest item", value = "lowest" },
    }
    local mode = controls.AddDropdownContent(section, "Group summary", modeOptions,
        function() return config.mode end,
        function(value)
            if value ~= "average" and value ~= "lowest" then return end
            config.mode = value
            services.addon:RefreshAllGroups({ "durability" })
        end)
    layout:AddContent(section, mode, { role = "control", fillWidth = true })

    layout:AreaHeader(section, "Excluded Equipment Slots")
    for _, group in ipairs(EQUIPMENT_GROUPS) do
        local options = {}
        for _, slot in ipairs(group.slots) do
            local slotId = slot.id
            options[#options + 1] = {
                name = slot.name,
                shortLabel = slot.name,
                getter = function() return config.excludedSlots[slotId] == true end,
                setter = function(excluded)
                    config.excludedSlots[slotId] = excluded and true or nil
                    services.addon:RefreshAllGroups({ "durability" })
                end,
            }
        end
        local control = controls.AddMultiDropdownContent(section, group.label, options,
            nil, { emptyText = "None excluded" })
        layout:AddContent(section, control, { role = "control", fillWidth = true })
    end
end

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "durability",
    label = "Durability",
    updateEvents = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" },
    getText = GetDurabilityText,
    interaction = { getDetails = GetDurabilityDetails },
    hasSettingsPage = true,
    buildSettingsPage = BuildSettings,
}
