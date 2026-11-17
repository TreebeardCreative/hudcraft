local _, addon = ...

local Renderer = {}
Renderer.__index = Renderer

local DEFAULTS = {
    padding = 5,
    horizontalGap = 6,
    verticalGap = 2,
    iconSize = 14,
    iconTextGap = 4,
    fontSize = 14,
    fontObject = "GameFontNormal",
}

local HIGHLIGHT_TEXTURES = {
    soft_white_band = {
        name = "Soft white band",
        effect = {
            fill = { texture = "Interface\\AddOns\\HUDCraft\\Textures\\ModuleHoverFill" },
            line = { texture = "Interface\\AddOns\\HUDCraft\\Textures\\ModuleHoverAccents" },
            fillBlendMode = "BLEND",
            lineBlendMode = "BLEND",
            fillOpacity = 0.9,
            lineOpacity = 0.7,
            sizeScale = 1.05,
            fillWidthScale = 1.05,
            lineWidthScale = 1.05,
            verticalPadding = 12,
            fillGap = 2,
        },
    },
}

local function ApplyModuleHighlight(frame, module, orientation)
    if not frame or not addon.UI or not addon.UI.HoverEffects then return end
    local option = HIGHLIGHT_TEXTURES.soft_white_band
    local effectOptions = {}
    for key, value in pairs(option.effect) do effectOptions[key] = value end
    -- Modules may request orientation-specific adjustments while reusing the
    -- shared hover treatment and lifecycle.
    local moduleEffect = module and module.hoverEffect and module.hoverEffect[orientation]
    if type(moduleEffect) == "table" then
        for key, value in pairs(moduleEffect) do effectOptions[key] = value end
    end
    local tint = addon.UI.WindowStyles:ResolveColor("white", frame)
    effectOptions.tint = tint and { tint[1], tint[2], tint[3] } or nil
    if not frame.moduleHoverEffect then
        frame.moduleHoverEffect = addon.UI.HoverEffects:Attach(frame, effectOptions)
    else
        frame.moduleHoverEffect:SetOptions(effectOptions)
    end
end

local function HasValidInteraction(module)
    local interaction = module and module.interaction
    if type(interaction) == "function" then return true end
    if type(interaction) ~= "table" then return false end
    return type(interaction.onClick) == "function"
        or type(interaction.onRightClick) == "function"
        or type(interaction.getDetails) == "function"
end

local function MeasureText(fontString)
    return math.max(0, fontString:GetStringWidth() or 0),
        math.max(0, fontString:GetStringHeight() or 0)
end

local function CreateVisual(parent, options, isModule)
    local visual = CreateFrame(isModule and "Button" or "Frame", nil, parent)
    visual.text = visual:CreateFontString(nil, "ARTWORK", options.fontObject)
    local fontPath, _, fontFlags = visual.text:GetFont()
    if fontPath then visual.text:SetFont(fontPath, options.fontSize, fontFlags or "") end
    visual.text:SetPoint("LEFT", visual, "LEFT", 0, 0)
    visual.text:SetJustifyH("LEFT")
    visual.text:SetJustifyV("MIDDLE")
    visual.text:SetWordWrap(false)

    if addon.UI and addon.UI.WindowStyles then
        local function ApplyTextColor(target)
            target:SetTextColor(unpack(addon.UI.WindowStyles:GetTextColor("textInteractionAccentColor", target)))
        end
        addon.UI.WindowStyles:RegisterVisual(visual.text, ApplyTextColor)
        ApplyTextColor(visual.text)
    end
    return visual
end

local function SetVisualDisplay(visual, display, options)
    if type(display) == "string" then display = { text = display } end
    if type(display) ~= "table" then display = {} end

    local text = display.text == nil and "" or tostring(display.text)
    local icon = display.icon
    local iconSize = math.max(1, tonumber(display.iconSize) or options.iconSize)
    local textWidth, textHeight = 0, 0

    visual.text:SetText(text)
    if text ~= "" then textWidth, textHeight = MeasureText(visual.text) end

    if icon then
        if not visual.icon then
            visual.icon = visual:CreateTexture(nil, "ARTWORK")
        end
        visual.icon:SetTexture(icon)
        visual.icon:ClearAllPoints()
        visual.icon:SetSize(iconSize, iconSize)
        visual.icon:SetPoint("LEFT", visual, "LEFT", 0, 0)
        visual.text:ClearAllPoints()
        if text ~= "" then
            visual.text:SetPoint("LEFT", visual.icon, "RIGHT", options.iconTextGap, 0)
        end
    else
        if visual.icon then visual.icon:Hide() end
        visual.text:ClearAllPoints()
        visual.text:SetPoint("LEFT", visual, "LEFT", 0, 0)
    end

    if visual.icon then
        if icon then visual.icon:Show() else visual.icon:Hide() end
    end
    local width = textWidth + (icon and (iconSize + (text ~= "" and options.iconTextGap or 0)) or 0)
    local height = math.max(textHeight, icon and iconSize or 0, 16)
    visual:SetSize(math.max(1, width), height)
    visual:Show()
    return width, height
end

local function CreateSeparator(parent, text, options)
    local visual = CreateVisual(parent, options)
    SetVisualDisplay(visual, text, options)
    return visual
end

local function SameDisplay(left, right)
    if left == right then return true end
    if type(left) == "string" then left = { text = left } end
    if type(right) == "string" then right = { text = right } end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    return left.text == right.text and left.icon == right.icon
        and left.iconSize == right.iconSize
end

function Renderer:Create(parent, options)
    options = options or {}
    local renderer = setmetatable({}, self)
    renderer.parent = parent
    renderer.options = {
        orientation = options.orientation == "column" and "column" or "row",
        padding = math.max(0, tonumber(options.padding) or DEFAULTS.padding),
        horizontalGap = math.max(0, tonumber(options.horizontalGap or options.gap) or DEFAULTS.horizontalGap),
        verticalGap = math.max(0, tonumber(options.verticalGap) or DEFAULTS.verticalGap),
        horizontalSeparator = options.horizontalSeparator or options.separator or "",
        verticalSeparator = options.verticalSeparator or "",
        iconSize = math.max(1, tonumber(options.iconSize) or DEFAULTS.iconSize),
        iconTextGap = math.max(0, tonumber(options.iconTextGap) or DEFAULTS.iconTextGap),
        fontSize = math.max(1, tonumber(options.fontSize) or DEFAULTS.fontSize),
        fontObject = options.fontObject or DEFAULTS.fontObject,
    }
    renderer.items = {}
    renderer.nodes = {}
    renderer.width = 0
    renderer.height = 0
    renderer.onSizeChanged = options.onSizeChanged
    renderer.onModuleEnter = options.onModuleEnter
    renderer.onModuleLeave = options.onModuleLeave
    return renderer
end

function Renderer:SetItems(items, options)
    items = items or {}
    options = options or {}
    if options.orientation ~= nil then
        self.options.orientation = options.orientation == "column" and "column" or "row"
    end
    if options.gap ~= nil then
        local gap = math.max(0, tonumber(options.gap) or 0)
        self.options.horizontalGap, self.options.verticalGap = gap, gap
    end
    if options.horizontalGap ~= nil then
        self.options.horizontalGap = math.max(0, tonumber(options.horizontalGap) or 0)
    end
    if options.verticalGap ~= nil then
        self.options.verticalGap = math.max(0, tonumber(options.verticalGap) or 0)
    end
    if options.fontSize ~= nil then
        self.options.fontSize = math.max(1, tonumber(options.fontSize) or DEFAULTS.fontSize)
    end
    if options.separator ~= nil then
        self.options.horizontalSeparator = tostring(options.separator)
        self.options.verticalSeparator = tostring(options.separator)
    end
    if options.horizontalSeparator ~= nil then
        self.options.horizontalSeparator = tostring(options.horizontalSeparator)
    end
    if options.verticalSeparator ~= nil then
        self.options.verticalSeparator = tostring(options.verticalSeparator)
    end
    for _, node in ipairs(self.nodes) do node.frame:Hide() end
    self.items = {}
    self.nodes = {}

    for index, item in ipairs(items or {}) do
        local interactive = HasValidInteraction(item.module)
        local module = item.module
        local visual = CreateVisual(self.parent, self.options, interactive)
        local entry = {
            id = item.id,
            moduleId = item.moduleId or item.id,
            module = item.module,
            frame = visual,
            display = item.display,
            showDetails = item.showDetails == true,
        }
        if interactive then
            ApplyModuleHighlight(visual, module, self.options.orientation)
            visual:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            visual:SetScript("OnClick", function(frame, button)
                local interaction = module and module.interaction
                if button == "RightButton" and addon.ShowModuleContextMenu then
                    addon:ShowModuleContextMenu(module, frame)
                elseif button == "LeftButton" then
                    local action = type(interaction) == "function" and interaction
                        or type(interaction) == "table" and interaction.onClick
                    if type(action) == "function" then action(frame) end
                end
            end)
        end
        if item.module and item.showDetails and self.onModuleEnter then
            visual:HookScript("OnEnter", function(frame)
                self.onModuleEnter(module, frame)
            end)
        end
        if item.module and item.showDetails and self.onModuleLeave then
            visual:HookScript("OnLeave", function(frame)
                self.onModuleLeave(module, frame)
            end)
        end
        if item.display ~= nil then
            entry.width, entry.height = SetVisualDisplay(visual, item.display, self.options)
        end
        self.items[#self.items + 1] = entry
        self.nodes[#self.nodes + 1] = { frame = visual, entry = entry }

        local separatorText = self.options.orientation == "row"
            and self.options.horizontalSeparator or self.options.verticalSeparator
        if index < #items and separatorText ~= "" then
            local separator = CreateSeparator(self.parent, separatorText, self.options)
            self.nodes[#self.nodes + 1] = { frame = separator, separator = true, display = separatorText }
        end
    end

    self:Draw(false)
end

function Renderer:SetOptions(options)
    options = options or {}
    local orientation = options.orientation == "column" and "column" or "row"
    local horizontalGap = options.horizontalGap == nil and self.options.horizontalGap
        or math.max(0, tonumber(options.horizontalGap) or 0)
    local verticalGap = options.verticalGap == nil and self.options.verticalGap
        or math.max(0, tonumber(options.verticalGap) or 0)
    if options.gap ~= nil then
        horizontalGap, verticalGap = math.max(0, tonumber(options.gap) or 0), math.max(0, tonumber(options.gap) or 0)
    end
    local horizontalSeparator = self.options.horizontalSeparator
    if options.horizontalSeparator ~= nil then horizontalSeparator = tostring(options.horizontalSeparator) end
    local verticalSeparator = self.options.verticalSeparator
    if options.verticalSeparator ~= nil then verticalSeparator = tostring(options.verticalSeparator) end
    local fontSize = options.fontSize == nil and self.options.fontSize
        or math.max(1, tonumber(options.fontSize) or self.options.fontSize)
    if options.separator ~= nil then
        horizontalSeparator, verticalSeparator = tostring(options.separator), tostring(options.separator)
    end
    local orientationChanged = orientation ~= self.options.orientation
    local separatorsChanged = horizontalSeparator ~= self.options.horizontalSeparator
        or verticalSeparator ~= self.options.verticalSeparator
    local fontSizeChanged = fontSize ~= self.options.fontSize
    if not orientationChanged and not separatorsChanged
        and not fontSizeChanged
        and horizontalGap == self.options.horizontalGap and verticalGap == self.options.verticalGap then
        return false
    end
    self.options.orientation = orientation
    self.options.horizontalGap, self.options.verticalGap = horizontalGap, verticalGap
    self.options.horizontalSeparator, self.options.verticalSeparator = horizontalSeparator, verticalSeparator
    self.options.fontSize = fontSize
    if fontSizeChanged then
        for _, node in ipairs(self.nodes) do
            local visual = node.frame
            local fontPath, _, fontFlags = visual.text:GetFont()
            if fontPath then visual.text:SetFont(fontPath, fontSize, fontFlags or "") end
            if node.entry then
                node.entry.width, node.entry.height = SetVisualDisplay(visual, node.entry.display, self.options)
            elseif node.separator then
                SetVisualDisplay(visual, node.display, self.options)
            end
        end
        self:Draw(false)
    end
    if orientationChanged or separatorsChanged then self:SetItems(self.items) else self:Draw(false) end
    return true
end

function Renderer:UpdateItem(id, display)
    return self:UpdateItems({ [id] = display })
end

function Renderer:UpdateItems(updates)
    local sizeChanged = false
    for _, item in ipairs(self.items) do
        local display = updates[item.id]
        if display ~= nil and not SameDisplay(item.display, display) then
            local width, height = SetVisualDisplay(item.frame, display, self.options)
            if math.abs(width - (item.width or -1)) > 0.5
                or math.abs(height - (item.height or -1)) > 0.5 then
                sizeChanged = true
            end
            item.width, item.height, item.display = width, height, display
        end
    end
    if sizeChanged then self:Draw(false) end
    return sizeChanged
end

function Renderer:Draw(forceResize)
    local horizontal = self.options.orientation == "row"
    local padding = self.options.padding
    local gap = horizontal and self.options.horizontalGap or self.options.verticalGap
    local contentWidth, contentHeight = 0, 0

    for _, node in ipairs(self.nodes) do
        local frame = node.frame
        local width = math.max(1, node.entry and node.entry.width or frame:GetWidth() or 1)
        local height = math.max(1, node.entry and node.entry.height or frame:GetHeight() or 1)
        if horizontal then
            contentWidth = contentWidth + width
            contentHeight = math.max(contentHeight, height)
        else
            contentWidth = math.max(contentWidth, width)
            contentHeight = contentHeight + height
        end
    end

    local nodeCount = #self.nodes
    if nodeCount > 1 then
        if horizontal then contentWidth = contentWidth + gap * (nodeCount - 1)
        else contentHeight = contentHeight + gap * (nodeCount - 1) end
    end

    local width = contentWidth + padding * 2
    local height = contentHeight + padding * 2
    local sizeChanged = math.abs(width - self.width) > 0.5 or math.abs(height - self.height) > 0.5
    local cursor = padding

    for _, node in ipairs(self.nodes) do
        local frame = node.frame
        local nodeWidth = math.max(1, node.entry and node.entry.width or frame:GetWidth() or 1)
        local nodeHeight = math.max(1, node.entry and node.entry.height or frame:GetHeight() or 1)
        frame:ClearAllPoints()
        if horizontal then
            frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", cursor, -(padding + (contentHeight - nodeHeight) / 2))
            cursor = cursor + nodeWidth + gap
        else
            frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", padding + (contentWidth - nodeWidth) / 2, -cursor)
            cursor = cursor + nodeHeight + gap
        end
        frame:Show()
    end

    self.width, self.height = width, height
    if forceResize or sizeChanged then
        if self.onSizeChanged then self.onSizeChanged(width, height) end
    end
    return sizeChanged
end

addon.GroupRenderer = Renderer
