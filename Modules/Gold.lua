local _, addon = ...

local function GetBalance()
    return type(GetMoney) == "function" and (GetMoney() or 0) or 0
end

local DISPLAY_TYPES = {
    gold_silver_copper = true,
    gold_silver = true,
    gold = true,
}

local function GetConfig()
    if type(HUDCraftCharDB) ~= "table" then return nil end
    HUDCraftCharDB.moduleSettings = type(HUDCraftCharDB.moduleSettings) == "table"
        and HUDCraftCharDB.moduleSettings or {}
    local config = HUDCraftCharDB.moduleSettings.gold
    if type(config) ~= "table" then
        config = {}
        HUDCraftCharDB.moduleSettings.gold = config
    end
    if not DISPLAY_TYPES[config.displayType] then config.displayType = "gold_silver" end
    return config
end

local function FormatBalance(copper, displayType)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local remainder = copper % 100
    if displayType == "gold" then return string.format("%dg", gold) end
    local parts = {}
    if gold > 0 then parts[#parts + 1] = string.format("%dg", gold) end
    if silver > 0 then parts[#parts + 1] = string.format("%ds", silver) end
    if displayType == "gold_silver_copper" and remainder > 0 then
        parts[#parts + 1] = string.format("%dc", remainder)
    end
    return table.concat(parts, " ")
end

local function GetGoldText(showLabel)
    local config = GetConfig()
    local displayType = config and config.displayType or "gold_silver"
    local balance = FormatBalance(GetBalance(), displayType)
    if balance == "" then return "" end
    local label = showLabel == false and "" or "Gold: "
    return label .. balance
end

local function GetGoldGroupItems(_, showLabel)
    local text = GetGoldText(showLabel)
    return {
        {
            key = "balance",
            text = text,
            showDetails = text ~= "",
        },
    }
end

local function GetGoldDetails()
    local copper = GetBalance()
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local remainder = copper % 100
    return { string.format("%d gold, %d silver, %d copper", gold, silver, remainder) }
end

local function BuildSettings(flow, services)
    local layout, controls = services.layout, services.controls
    local config = GetConfig()
    local section = layout:Section(flow, "hudcraft-module-gold")
    layout:AddContent(flow, section, { fillWidth = true })
    layout:AreaHeader(section, "Gold")

    local showLabel = controls.AddCheckbox(section, "Show label",
        function() return HUDCraftCharDB.moduleLabels.gold ~= false end,
        function(enabled)
            HUDCraftCharDB.moduleLabels.gold = enabled and true or false
            services.addon:RefreshAllGroups({ "gold" })
        end)
    layout:AddContent(section, showLabel, { role = "control", fillWidth = true })

    local displayTypeOptions = {
        { name = "Gold Silver Copper", value = "gold_silver_copper" },
        { name = "Gold Silver", value = "gold_silver" },
        { name = "Gold", value = "gold" },
    }
    local displayType = controls.AddDropdownContent(section, "Display type", displayTypeOptions,
        function() return config.displayType end,
        function(value)
            if not DISPLAY_TYPES[value] then return end
            config.displayType = value
            services.addon:RefreshAllGroups({ "gold" })
        end)
    layout:AddContent(section, displayType, { role = "control", fillWidth = true })
end

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "gold",
    label = "Gold",
    updateEvents = { "PLAYER_MONEY", "PLAYER_ENTERING_WORLD" },
    getText = GetGoldText,
    getGroupItems = GetGoldGroupItems,
    interaction = { getDetails = GetGoldDetails },
    hasSettingsPage = true,
    buildSettingsPage = BuildSettings,
}
