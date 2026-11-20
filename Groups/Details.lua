local _, addon = ...

local DETAIL_MIN_WIDTH = 120
local DETAIL_MIN_HEIGHT = 30
local DETAIL_GAP = 2
local DETAIL_TEXT_INSET = 8
local HIDE_DELAY = 0.15

local DETAIL_POSITIONS = {
    bottom = true,
    right = true,
    top = true,
    left = true,
}

function addon:GetGroupDetailsPosition(groupId)
    local group = HUDCraftDB and HUDCraftDB.groups and HUDCraftDB.groups.byId
        and HUDCraftDB.groups.byId[groupId]
    local position = group and group.detailsPosition
    if DETAIL_POSITIONS[position] then return position end

    -- Keep the established below-group placement for horizontal Groups, and
    -- place vertical Group details beside the Group by default.
    return self:GetGroupDirection(groupId) == "column" and "right" or "bottom"
end

local function AnchorDetailsFrame(frame, groupFrame, position)
    frame:ClearAllPoints()
    if position == "right" then
        frame:SetPoint("TOPLEFT", groupFrame, "TOPRIGHT", DETAIL_GAP, 0)
    elseif position == "top" then
        frame:SetPoint("BOTTOMLEFT", groupFrame, "TOPLEFT", 0, DETAIL_GAP)
    elseif position == "left" then
        frame:SetPoint("TOPRIGHT", groupFrame, "TOPLEFT", -DETAIL_GAP, 0)
    else
        frame:SetPoint("TOPLEFT", groupFrame, "BOTTOMLEFT", 0, -DETAIL_GAP)
    end
end

local function IsPointerOverDetails(frame)
    if frame:IsMouseOver() then return true end
    local content = frame.content
    return content and content:IsMouseOver() or false
end

local function CancelHide(frame)
    if frame.hideTimer then frame.hideTimer:Hide() end
end

local function GetDetailLines(module)
    local interaction = module and module.interaction
    local getter = type(interaction) == "table" and interaction.getDetails
    if type(getter) ~= "function" then return nil end

    local ok, value = pcall(getter, module)
    if not ok then return nil end
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return nil end

    local lines = {}
    for _, line in ipairs(value) do
        if line ~= nil then lines[#lines + 1] = tostring(line) end
    end
    return #lines > 0 and table.concat(lines, "\n") or nil
end

local function CreateDetailsFrame(groupId, owner)
    local frame = addon.UI.WindowFrame:Create({
        id = "details-" .. tostring(groupId),
        title = "",
        owner = owner,
        sizing = {
            mode = "consumer",
            initial = { width = DETAIL_MIN_WIDTH, height = DETAIL_MIN_HEIGHT },
            minimum = { width = DETAIL_MIN_WIDTH, height = DETAIL_MIN_HEIGHT },
            position = { x = 0, y = 0 },
        },
        interaction = { movable = false, hover = false, borderHover = false },
        surface = { frameBorder = "body" },
    })
    frame:SetExpandedSize(DETAIL_MIN_WIDTH, DETAIL_MIN_HEIGHT)

    local text = frame.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", frame.content, "TOPLEFT", DETAIL_TEXT_INSET, -DETAIL_TEXT_INSET)
    text:SetWordWrap(true)
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(true) end
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    frame.detailsText = text

    local function ApplyTextColor(target)
        local styles = addon.UI.WindowStyles
        local style = styles:GetForFrame(target)
        local color = style and style.groupContentTextColor
            and styles:ResolveColor(style.groupContentTextColor, style)
            or styles:GetTextColor("textMainColor", target)
        if color then target:SetTextColor(unpack(color)) end
    end
    addon.UI.WindowStyles:RegisterVisual(text, ApplyTextColor)
    ApplyTextColor(text)

    frame:Hide()
    local function HookPointerRegion(region)
        if not region or type(region.HookScript) ~= "function" then return end
        region:HookScript("OnEnter", function() CancelHide(frame) end)
        region:HookScript("OnLeave", function() addon:ScheduleGroupDetailsHide(groupId) end)
    end
    HookPointerRegion(frame)
    HookPointerRegion(frame.content)
    return frame
end

function addon:EnsureGroupDetailsFrame(groupId)
    self.groupDetails = self.groupDetails or {}
    if self.groupDetails[groupId] then return self.groupDetails[groupId] end

    local owner = self.groupStyleOwners and self.groupStyleOwners[groupId]
    if not owner or not self.UI or not self.UI.WindowFrame then return nil end
    local frame = CreateDetailsFrame(groupId, owner)
    self.groupDetails[groupId] = frame

    local timer = CreateFrame("Frame")
    timer:Hide()
    timer.elapsed = 0
    timer:SetScript("OnUpdate", function(check, elapsed)
        check.elapsed = check.elapsed + elapsed
        if check.elapsed < HIDE_DELAY then return end
        check:Hide()
        local source = frame.detailSource
        if (source and source:IsMouseOver()) or IsPointerOverDetails(frame) then return end
        frame:Hide()
        frame.detailSource = nil
        frame.detailModule = nil
    end)
    frame.hideTimer = timer
    return frame
end

function addon:ShowGroupModuleDetails(groupId, module, source)
    local group = HUDCraftDB and HUDCraftDB.groups and HUDCraftDB.groups.byId
        and HUDCraftDB.groups.byId[groupId]
    if not group or group.detailsEnabled == false then
        local existing = self.groupDetails and self.groupDetails[groupId]
        if existing then
            if existing.hideTimer then existing.hideTimer:Hide() end
            existing:Hide()
            existing.detailSource = nil
            existing.detailModule = nil
        end
        return false
    end
    local details = GetDetailLines(module)
    local frame = self:EnsureGroupDetailsFrame(groupId)
    local groupFrame = self.groupFrames and self.groupFrames[groupId]
    if not details or not frame or not groupFrame then
        if frame then frame:Hide() end
        return false
    end

    frame.hideTimer:Hide()
    frame.hideTimer.elapsed = 0
    frame.detailSource = source
    frame.detailModule = module
    frame.detailsText:SetText(details)
    -- This FontString is reused between modules. Clear the previous content's
    -- explicit height before asking WoW to measure a potentially taller string;
    -- otherwise the prior (often three-line Performance) height can constrain
    -- the next measurement and clip longer details such as Weapon Skills.
    if frame.detailsText.SetMaxLines then frame.detailsText:SetMaxLines(0) end
    frame.detailsText:SetHeight(0)
    -- Match SettingsLayout's content measurement: set the usable width first,
    -- then measure the FontString's actual wrapped/multiline height. A manual
    -- newline count and GetLineHeight can disagree with the rendered region.
    local contentWidth = frame.detailsText:GetUnboundedStringWidth()
        or frame.detailsText:GetStringWidth() or 0
    local availableWidth = math.max(DETAIL_MIN_WIDTH,
        (UIParent and UIParent:GetWidth() or contentWidth) - 20)
    local width = math.min(availableWidth, math.max(DETAIL_MIN_WIDTH,
        math.ceil(contentWidth + (DETAIL_TEXT_INSET * 2) + 2)))
    local textWidth = math.max(1, width - (DETAIL_TEXT_INSET * 2) - 2)
    frame.detailsText:SetWidth(textWidth)
    local textHeight = frame.detailsText:GetStringHeight()
        or frame.detailsText:GetHeight() or 1
    local height = math.max(DETAIL_MIN_HEIGHT,
        math.ceil(textHeight + (DETAIL_TEXT_INSET * 2) + 2))
    frame.detailsText:SetHeight(math.max(1, textHeight))
    frame:SetExpandedSize(width, height)
    -- SetExpandedSize snaps a TreebeardUI window to UIParent. Apply the
    -- Group-relative Details placement after sizing so the snap cannot replace it.
    AnchorDetailsFrame(frame, groupFrame, self:GetGroupDetailsPosition(groupId))
    frame:Show()
    return true
end

function addon:ScheduleGroupDetailsHide(groupId)
    local frame = self.groupDetails and self.groupDetails[groupId]
    if not frame or not frame:IsShown() or not frame.hideTimer then return end
    frame.hideTimer.elapsed = 0
    frame.hideTimer:Show()
end
