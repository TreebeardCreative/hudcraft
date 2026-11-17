local _, addon = ...

local ICON = "Interface\\AddOns\\HUDCraft\\Textures\\hudcraft_icon.tga"
local DEFAULT_ANGLE = 225

local function PlaceButton(button, angle)
    local minimap = Minimap
    local radians = math.rad(angle)
    local radius = (minimap:GetWidth() or 140) * 0.5 + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", minimap, "CENTER",
        math.cos(radians) * radius, math.sin(radians) * radius)
end

local function CursorAngle(minimap)
    local cursorX, cursorY = GetCursorPosition()
    local scale = minimap:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local centerX, centerY = minimap:GetCenter()
    return math.deg(math.atan2(cursorY - centerY, cursorX - centerX)) % 360
end

function addon:CreateMinimapButton()
    if self.minimapButton or not Minimap then return self.minimapButton end

    local button = CreateFrame("Button", "HUDCraftMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 5)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetClampedToScreen(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture(ICON)
    button.icon = icon

    button:SetScript("OnClick", function()
        addon:ToggleSettings()
    end)
    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    button:SetScript("OnUpdate", function(self)
        if self.isDragging then
            self.currentAngle = CursorAngle(Minimap)
            PlaceButton(self, self.currentAngle)
        end
    end)
    button:SetScript("OnDragStop", function(self)
        self.isDragging = false
        local angle = self.currentAngle or CursorAngle(Minimap)
        HUDCraftDB.minimap.angle = angle
        PlaceButton(self, angle)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("hudcraft", 1, 0.82, 0.48)
        GameTooltip:AddLine("Click to open Settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = button
    PlaceButton(button, tonumber(HUDCraftDB.minimap.angle) or DEFAULT_ANGLE)
    button:SetShown(HUDCraftDB.minimap.hide ~= true)
    return button
end

function addon:SetMinimapButtonShown(shown)
    HUDCraftDB.minimap.hide = not shown
    if self.minimapButton then self.minimapButton:SetShown(shown) end
end

function addon:ToggleMinimapButton()
    local shown = HUDCraftDB.minimap.hide == true
    self:SetMinimapButtonShown(shown)
    return shown
end

function addon:ToggleSettings()
    if self.settingsWindow and self.settingsWindow:IsShown() then
        self.settingsWindow:Hide()
    else
        self:ShowSettings()
    end
end
