local _, addon = ...

local GROUP_CONTENT_PADDING = 8

local function CreateModuleContent(parent, id, label)
    local frame = CreateFrame("Frame", nil, parent)
    frame.moduleId = id
    frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.text:SetPoint("CENTER", frame, "CENTER")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")
    frame.text:SetText(label or "")
    return frame
end

function addon:CreateMainGroup()
    local ui = self.UI
    local window = ui.WindowFrame:Create({
        id = "main-group",
        owner = self.name,
        sizing = {
            mode = "consumer",
            initial = { width = 280, height = 40 },
            minimum = { width = 15, height = 15 },
            position = { x = 0, y = -180 },
        },
        interaction = {
            movable = true,
            hover = true,
            dragRegion = "border",
            resize = false,
        },
        surface = {
            frameBorder = "body",
            background = { color = "#080B10", opacity = 92 },
            border = { color = "#4B8DBD", opacity = 100 },
            hoverBorder = { color = "#86C8F2", opacity = 100 },
        },
        frameHeader = { visibility = "never" },
    })
    self.mainGroup = window
    self.mainGroupModuleContent = {}

    function self:RebuildMainGroupLayout(direction, spacing, showGroupName)
        local group = self.mainGroup
        if not group then return end

        if group.layoutContainer then group.layoutContainer:Hide() end

        local layout = self.UI.SettingsLayout
        local container = layout:Container(group.content, "hudcraft-main-group", { padding = 0 })
        container:SetAllPoints(group.content)
        local section = layout:Section(container, "hudcraft-main-group-content", {
            border = false,
            padding = 0,
            gap = 0,
        })

        local contentItems = {}
        if showGroupName then
            contentItems[#contentItems + 1] = {
                id = "group-name",
                frame = CreateModuleContent(section, "group-name", "Hudcraft"),
            }
        end
        for _, module in ipairs(self.Modules or {}) do
            contentItems[#contentItems + 1] = {
                id = module.id,
                module = module,
                frame = CreateModuleContent(section, module.id, ""),
            }
        end

        local row = layout:Row(section, "hudcraft-main-group-row", {
            flow = true,
            gap = 0,
            padding = 0,
            minHeight = 1,
        })
        layout:SetFlowChild(section, row, "row")

        local columnIds, widths = {}, {}
        if direction == "row" then
            for index, item in ipairs(contentItems) do
                columnIds[index] = item.id
                widths[index] = math.max(1, item.width or 1)
            end
            local columns = layout:Columns(row, #contentItems, columnIds, {
                columnGap = spacing,
                contentGap = 0,
                padding = 0,
                widths = widths,
                horizontalAlign = "CENTER",
                verticalAlign = "CENTER",
            })
            for index, item in ipairs(contentItems) do
                layout:AdoptChild(columns[index], item.frame, {
                    role = "module-content",
                    flow = true,
                })
                item.column = columns[index]
            end
        else
            columnIds[1] = "module-stack"
            widths[1] = 1
            local columns = layout:Columns(row, 1, columnIds, {
                columnGap = 0,
                contentGap = spacing,
                padding = 0,
                widths = widths,
                horizontalAlign = "CENTER",
                verticalAlign = "TOP",
            })
            for index, item in ipairs(contentItems) do
                layout:AdoptChild(columns[1], item.frame, {
                    role = "module-content",
                    flow = true,
                    gapBefore = index > 1 and spacing or 0,
                })
                item.column = columns[1]
            end
        end

        group.layoutContainer = container
        group.layoutSection = section
        group.layoutRow = row
        group.layoutDirection = direction
        group.layoutSpacing = spacing
        group.layoutShowsGroupName = showGroupName
        self.mainGroupModuleContent = contentItems
    end

    function self:RefreshMainGroup()
        if not self.mainGroup then return end

        local direction = HUDCraftDB.general.groupDirection == "column" and "column" or "row"
        local spacing = math.max(0, tonumber(HUDCraftDB.general.spacing) or 12)
        local showGroupName = HUDCraftDB.general.showGroupName == true
        if self.mainGroup.layoutDirection ~= direction
            or self.mainGroup.layoutSpacing ~= spacing
            or self.mainGroup.layoutShowsGroupName ~= showGroupName then
            self:RebuildMainGroupLayout(direction, spacing, showGroupName)
        end

        local totalWidth, totalHeight, maxWidth, maxHeight = 0, 0, 0, 16
        local visibleCount = 0
        for _, item in ipairs(self.mainGroupModuleContent) do
            local value = item.id == "group-name" and "Hudcraft" or ""
            if item.module then
                local ok, result = pcall(item.module.getText)
                value = ok and tostring(result) or "—"
            end
            item.frame.text:SetText(value)
            item.width = math.max(1, item.frame.text:GetStringWidth() or 0)
            item.height = math.max(16, item.frame.text:GetStringHeight() or 0)
            item.frame:SetSize(item.width, item.height)
            maxWidth = math.max(maxWidth, item.width)
            maxHeight = math.max(maxHeight, item.height)
            totalWidth = totalWidth + item.width
            totalHeight = totalHeight + item.height
            visibleCount = visibleCount + 1
        end

        local width, height
        if direction == "row" then
            totalWidth = totalWidth + spacing * math.max(0, visibleCount - 1)
            height = maxHeight + 2 * GROUP_CONTENT_PADDING
            width = totalWidth + 2 * GROUP_CONTENT_PADDING
        else
            totalHeight = totalHeight + spacing * math.max(0, visibleCount - 1)
            width = maxWidth + 2 * GROUP_CONTENT_PADDING
            height = totalHeight + 2 * GROUP_CONTENT_PADDING
        end

        local group = self.mainGroup
        group:SetExpandedSize(width + 2, height + 2)
        local contentWidth = math.max(1, group.content:GetWidth() - 2 * GROUP_CONTENT_PADDING)
        group.layoutSection:SetWidth(contentWidth)

        if direction == "row" then
            for index, item in ipairs(self.mainGroupModuleContent) do
                local column = item.column
                if column then column.layoutFixedWidth = item.width end
            end
        else
            local column = self.mainGroupModuleContent[1] and self.mainGroupModuleContent[1].column
            if column then column.layoutFixedWidth = contentWidth end
        end

        self.UI.SettingsLayout:ReflowSection(group.layoutSection)
        self.UI.SettingsLayout:StackSections(group.layoutContainer, { group.layoutSection }, {
            left = GROUP_CONTENT_PADDING,
            right = GROUP_CONTENT_PADDING,
            top = GROUP_CONTENT_PADDING,
            bottom = GROUP_CONTENT_PADDING,
        })
    end

    local updates = CreateFrame("Frame")
    local elapsed = 0
    updates:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        self:RefreshMainGroup()
    end)
    updates:RegisterEvent("BAG_UPDATE_DELAYED")
    updates:RegisterEvent("PLAYER_XP_UPDATE")
    updates:RegisterEvent("PLAYER_LEVEL_UP")
    updates:RegisterEvent("PLAYER_ENTERING_WORLD")
    updates:SetScript("OnEvent", function() self:RefreshMainGroup() end)

    window:HookScript("OnShow", function() self:RefreshMainGroup() end)
    self:RefreshMainGroup()
    window:Show()
end
