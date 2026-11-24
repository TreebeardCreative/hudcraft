local _, addon = ...

local INTERNAL_PREFIX = "__HUDCRAFT_GROUP_OVERRIDE_"
local FAMILY_BY_OVERRIDE = {
    border = "neutralAccent",
    interaction = "interactionAccent",
    background = "canvas",
}

function addon:IsGroupStyleOverridePreset(name)
    return type(name) == "string" and name:sub(1, #INTERNAL_PREFIX) == INTERNAL_PREFIX
end

local function ValidHex(value)
    return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

local function Opacity(override, field)
    local value = tonumber(override and override.opacity and override.opacity[field])
    if not value or value ~= value then return 1 end
    return math.max(0, math.min(100, value)) / 100
end

local function CopyRGBA(factory, value, alpha)
    local red, green, blue = factory.ToRGBA(value)
    if not red then return nil end
    return { red, green, blue, alpha }
end

local function GetBaseColor(styles, baseStyle, family)
    local bases = baseStyle.colorFactoryBases
    if type(bases) == "table" and ValidHex(bases[family]) then
        return bases[family]:upper()
    end

    local factory = styles.ColorFactory
    local color
    if family == "baseText" then
        local slot = baseStyle.textMainColor
        color = baseStyle.colorFactoryColors and baseStyle.colorFactoryColors[slot] or slot
    elseif family == "neutralAccent" then
        color = styles:GetWindowBorderColor(baseStyle)
    elseif family == "interactionAccent" then
        color = styles:GetWindowInteractionColor(baseStyle)
    else
        color = styles:GetMainCanvasColor(baseStyle)
    end
    return factory.ToHex(color) or factory.ToHex(factory.white)
end

function addon:GetGroupStylePreset(baseName)
    local styles = self.UI and self.UI.WindowStyles
    local factory = self.UI and self.UI.ColorFactory
    local baseStyle = styles and styles.Presets[baseName]
    if not styles or not factory or not baseStyle then return baseName end

    local override = HUDCraftDB and HUDCraftDB.styles and HUDCraftDB.styles.groupOverrides
    if type(override) ~= "table" then return baseName end
    override.colors = type(override.colors) == "table" and override.colors or {}
    override.opacity = type(override.opacity) == "table" and override.opacity or {}

    local hasOverride = false
    for _, field in ipairs({ "text", "border", "interaction", "hover", "background" }) do
        local opacity = tonumber(override.opacity[field])
        if ValidHex(override.colors[field]) or (opacity and opacity ~= 100) then
            hasOverride = true
            break
        end
    end
    if not hasOverride then return baseName end

    local safeName = tostring(baseName):gsub("[^%w_%-]", "_")
    local presetName = INTERNAL_PREFIX .. safeName
    local preset = styles.Presets[presetName]
    if not preset then
        preset = styles:RegisterPreset(presetName,
            baseStyle.allEverythingTestVariable, baseName)
    end
    if not preset then return baseName end

    local bases = {}
    for key, value in pairs(baseStyle.colorFactoryBases or {}) do bases[key] = value end
    for overrideField, family in pairs(FAMILY_BY_OVERRIDE) do
        local selected = override.colors[overrideField]
        bases[family] = ValidHex(selected) and selected:upper()
            or GetBaseColor(styles, baseStyle, family)
    end
    local interactionOpacity = tonumber(override.opacity.interaction)
    local hasInteractionOverride = ValidHex(override.colors.interaction)
        or (interactionOpacity and interactionOpacity ~= 100)

    local colors, families = factory.BuildFamilies(bases)
    if not colors then return baseName end
    for overrideField, family in pairs(FAMILY_BY_OVERRIDE) do
        local alpha = Opacity(override, overrideField)
        local familyTable = families[family]
        if familyTable then
            familyTable["base"] = CopyRGBA(factory, colors[family .. "_base"], alpha)
            colors[family .. "_base"] = familyTable["base"]
            for index = 1, 5 do
                local token = family .. "_" .. index
                familyTable[index] = CopyRGBA(factory, colors[token], alpha)
                colors[token] = familyTable[index]
            end
        end
    end

    preset.colorFactoryBases = bases
    preset.colorFactoryColors = colors
    preset.colorFactoryFamilies = families
    if hasInteractionOverride then
        -- Use factory tokens even when the source style stores fixed hexes.
        preset.windowInteractionColor = "interactionAccent_4"
    else
        preset.windowInteractionColor = baseStyle.windowInteractionColor
    end
    local hoverOpacity = tonumber(override.opacity.hover)
    local hasHoverOverride = ValidHex(override.colors.hover)
        or (hoverOpacity and hoverOpacity ~= 100)
    if hasHoverOverride then
        local hoverBase = ValidHex(override.colors.hover)
            and override.colors.hover or styles:GetWindowHighlightColor(baseStyle)
        preset.windowHighlightColor = CopyRGBA(factory, hoverBase, Opacity(override, "hover"))
    else
        preset.windowHighlightColor = styles:GetWindowHighlightColor(baseStyle)
    end
    -- ColorFactory-derived canvas shades now feed both the body and active
    -- frame-header surface while retaining this preset's original geometry.
    preset.mainCanvasColor = "canvas_1"

    local sourceMap = baseStyle.textColorRoleMap or {}
    preset.textColorRoleMap = {}
    for role, slot in pairs(sourceMap) do preset.textColorRoleMap[role] = slot end
    if hasInteractionOverride then
        -- Interaction-family edits must not recolor the Group content text
        -- role when the user has no explicit text override.
        preset.textInteractionAccentColor = styles:ResolveColor(
            baseStyle.textInteractionAccentColor, baseStyle)
    end

    -- Keep Group text overrides scoped to HUD content. Window titles,
    -- navigation labels, and control headers retain their style roles.
    preset.groupContentTextColor = nil
    local hasTextOverride = ValidHex(override.colors.text)
        or (tonumber(override.opacity.text) and tonumber(override.opacity.text) ~= 100)
    if hasTextOverride then
        local value = override.colors.text
        if not ValidHex(value) then
            value = styles:ResolveColor(baseStyle.textInteractionAccentColor, baseStyle)
        end
        preset.groupContentTextColor = CopyRGBA(factory, value, Opacity(override, "text"))
    end

    return presetName
end
