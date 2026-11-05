local _, addon = ...

function addon:CreateOutputWindow()
    local ui = self.UI
    local window = ui.WindowFrame:Create({
        id = "output",
        title = "Hudcraft — Debug",
        owner = self.name,
        sizing = {
            mode = "user",
            initial = { width = 520, height = 320 },
            minimum = { width = 420, height = 220 },
            position = { x = 290, y = 0 },
        },
        frameHeader = {
            visibility = "always",
            controls = { close = true, minimize = true },
        },
    })
    self.outputWindow = window

    local scroll = CreateFrame("ScrollFrame", nil, window.content)
    scroll:SetPoint("TOPLEFT", window.content, "TOPLEFT", 14, -14)
    scroll:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", -14, 14)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local text = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", content, "TOPLEFT")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    if text.SetNonSpaceWrap then
        text:SetNonSpaceWrap(true)
    end

    self.outputScroll = scroll
    self.outputContent = content
    self.outputText = text

    function self:RefreshOutput()
        if not self.outputText then return end
        local width = math.max(1, self.outputScroll:GetWidth() or 1)
        self.outputContent:SetWidth(width)
        self.outputText:SetWidth(width)
        self.outputText:SetText(table.concat(self.outputLines, "\n"))
        self.outputContent:SetHeight(math.max(1, self.outputText:GetStringHeight() or 1))
        self.outputScroll:SetVerticalScroll(self.outputScroll:GetVerticalScrollRange() or 0)
    end

    scroll:SetScript("OnMouseWheel", function(frame, delta)
        local current = frame:GetVerticalScroll() or 0
        local range = frame:GetVerticalScrollRange() or 0
        frame:SetVerticalScroll(math.max(0, math.min(range, current - delta * 32)))
    end)
    scroll:HookScript("OnSizeChanged", function()
        self:RefreshOutput()
    end)
    self:RefreshOutput()
end

function addon:ShowOutput()
    if self.outputWindow then
        self.outputWindow:Show()
    end
end

