-- Telegnome: minimap button with unread badge.
-- Left-click: open/close. Right-click: new message. Shift-click: settings. Drag: move.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local M = {}
TG.Minimap = M

function M:UpdatePosition()
    local b = self.button
    if not b then return end
    local angle = math.rad(TG.db.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function M:Create()
    if self.button or not Minimap then return end

    local b = CreateFrame("Button", "TelegnomeMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    self.button = b

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(21, 21)
    icon:SetTexture(S.ICON)
    icon:SetPoint("TOPLEFT", 5, -4)
    self.spin = S.Spin(icon, 1.2, -144)
    self.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    -- Unread badge
    local badge = CreateFrame("Frame", nil, b)
    badge:SetSize(16, 16)
    badge:SetPoint("TOPRIGHT", 4, 2)
    badge:SetFrameLevel(b:GetFrameLevel() + 2)
    local dot = badge:CreateTexture(nil, "ARTWORK")
    dot:SetAllPoints()
    dot:SetColorTexture(0.85, 0.1, 0.1, 1)
    if badge.CreateMaskTexture then
        local mask = badge:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(dot)
        dot:AddMaskTexture(mask)
    end
    local count = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("CENTER", 0, 0)
    badge.count = count
    self.badge = badge

    b:SetScript("OnClick", function(_, button)
        if IsControlKeyDown() then
            TG:SetDND(not TG.db.settings.dnd)
        elseif button == "RightButton" then
            TG.UI:Show()
            TG.Picker:Open()
        elseif IsShiftKeyDown() then
            TG.Settings:Toggle()
        else
            TG.UI:Toggle()
        end
    end)

    b:SetScript("OnDragStart", function(s)
        s:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            TG.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            M:UpdatePosition()
        end)
    end)
    b:SetScript("OnDragStop", function(s) s:SetScript("OnUpdate", nil) end)

    b:SetScript("OnEnter", function(s)
        M.spin:Play()
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine("Telegnome")
        if TG.db.settings.dnd then GameTooltip:AddLine("Do not disturb is on", 1, 0.55, 0.3) end
        local n = TG:TotalUnread()
        if n > 0 then
            GameTooltip:AddLine(n .. " unread message" .. (n == 1 and "" or "s"), 1, 0.4, 0.4)
        end
        GameTooltip:AddLine("Left-click: open / close", 1, 1, 1)
        GameTooltip:AddLine("Right-click: new message", 1, 1, 1)
        GameTooltip:AddLine("Shift-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Ctrl-click: do not disturb on / off", 1, 1, 1)
        GameTooltip:AddLine("Drag: move", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self:UpdatePosition()
    self:Update()
end

function M:Update()
    if not self.button then return end
    self.button:SetShown(not TG.db.minimap.hide)
    if self.icon then
        if TG.db.settings.dnd then self.icon:SetVertexColor(1, 0.45, 0.4) else self.icon:SetVertexColor(1, 1, 1) end
    end
    local n = TG:TotalUnread()
    if n > 0 then
        self.badge.count:SetText(n > 9 and "9+" or tostring(n))
        self.badge:Show()
    else
        self.badge:Hide()
    end
end
