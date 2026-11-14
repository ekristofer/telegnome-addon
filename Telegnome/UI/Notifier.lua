-- Telegnome: on-screen notifier (missed-messages counter that grows into a message preview).
-- Collapsed: a small cog with the number of unread messages.
-- On a new message it grows to show who wrote and the start of the message, then shrinks back.
-- Click: open conversation. Right-click: mark all as read. Shift-drag: move.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local T = { count = 0, expanded = false, remaining = 0 }
TG.Toast = T

local PILL_W, PILL_H = 66, 32
local FULL_W, FULL_H = 300, 60
local SHOW_TIME = 6
local ANIM_TIME = 0.18

-- The saved position is the top-left corner of the collapsed counter. When the notifier
-- grows to the left it is anchored by its right edge instead, so the counter stays put.
function T:PillPos()
    local p = TG.db.toastPos
    if p and p.left and p.top then return p.left, p.top end
    return UIParent:GetWidth() / 2 - PILL_W / 2, UIParent:GetHeight() - 120
end

function T:ApplyAnchor()
    local f = self.frame
    if not f then return end
    local l, t = self:PillPos()
    f:ClearAllPoints()
    self.full:ClearAllPoints()
    if TG.db.settings.toastGrow == "left" then
        f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", l + PILL_W, t)
        self.full:SetPoint("TOPRIGHT")
    else
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
        self.full:SetPoint("TOPLEFT")
    end
end

function T:Create()
    if self.frame then return end

    local f = CreateFrame("Button", "TelegnomeNotifier", UIParent, "BackdropTemplate")
    f:SetSize(PILL_W, PILL_H)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    if f.SetClipsChildren then f:SetClipsChildren(true) end
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    S.Paint(f, "toast")
    f:Hide()
    self.frame = f

    -- Collapsed content
    local pill = CreateFrame("Frame", nil, f)
    pill:SetAllPoints()
    local pcog = S.Cog(pill, 20)
    pcog:SetPoint("LEFT", 9, 0)
    pill.cog = pcog
    local count = pill:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    count:SetPoint("LEFT", pcog, "RIGHT", 7, 0)
    pill.count = count
    self.pill = pill

    -- Expanded content (fixed size; the frame's clipping reveals it while growing)
    local full = CreateFrame("Frame", nil, f)
    full:SetPoint("TOPLEFT")
    full:SetSize(FULL_W, FULL_H)
    local cog = S.Cog(full, 40)
    cog:SetPoint("LEFT", 9, 0)
    self.fullSpin = S.Spin(cog, 3, -360, true)
    local bubble = full:CreateTexture(nil, "OVERLAY")
    bubble:SetAllPoints(cog)
    bubble:SetTexture(S.BUBBLE)
    local title = full:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", cog, "TOPRIGHT", 8, 0)
    title:SetPoint("RIGHT", -10, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    full.title = title
    local text = full:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    text:SetPoint("RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    if text.SetMaxLines then text:SetMaxLines(2) end
    full.text = text
    full:Hide()
    self.full = full

    f:SetScript("OnClick", function(_, button)
        if IsControlKeyDown() then
            TG:SetDND(not TG.db.settings.dnd)
            return
        end
        if button == "RightButton" then
            TG:MarkAllRead()
            T:Collapse()
            return
        end
        -- a notice (e.g. "Requests are on") leads to its own place
        local action = T.expanded and T.action
        if action then
            T.action = nil
            T:Collapse()
            action()
            return
        end
        local key = (T.expanded and T.key and TG.db.threads[T.key] and T.key) or TG:MostRecentUnread()
        T:Collapse()
        if key then
            UI:Show()
            TG.Picker:Close()
            TG.Settings:Close()
            TG.Groups:ClosePanel()
            TG.Channels:ClosePanel()
            TG.ChannelList:Close()
            TG.Requests:ClosePanel()
            UI:Select(key)
            UI.input:SetFocus()
        else
            UI:Toggle()
        end
    end)
    f:SetScript("OnDragStart", function() if IsShiftKeyDown() then f:StartMoving() end end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local l = (TG.db.settings.toastGrow == "left") and (f:GetRight() - PILL_W) or f:GetLeft()
        TG.db.toastPos = { left = l, top = f:GetTop() }
        T:ApplyAnchor()
    end)
    f:SetScript("OnEnter", function() T:ShowTooltip() end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnUpdate", function(_, elapsed) T:OnUpdate(elapsed) end)

    self:ApplyAnchor()
end

function T:ShowTooltip()
    local f = self.frame
    GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Telegnome")
    if TG.db.settings.dnd then GameTooltip:AddLine("Do not disturb is on", 1, 0.55, 0.3) end
    local unread = {}
    for key, th in pairs(TG.db.threads) do
        if (th.unread or 0) > 0 and th.kind ~= "CHANNEL" then unread[#unread + 1] = { key = key, th = th } end
    end
    table.sort(unread, function(a, b) return (a.th.order or 0) > (b.th.order or 0) end)
    if #unread == 0 then
        GameTooltip:AddLine("No unread messages", 0.7, 0.7, 0.7)
    end
    for i = 1, math.min(#unread, 8) do
        local name, color = TG:ThreadDisplay(unread[i].key)
        GameTooltip:AddDoubleLine(name, unread[i].th.unread, color[1], color[2], color[3], 1, 0.4, 0.4)
    end
    if #unread > 8 then GameTooltip:AddLine("...and " .. (#unread - 8) .. " more", 0.7, 0.7, 0.7) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: open", 1, 1, 1)
    GameTooltip:AddLine("Right-click: mark all as read", 1, 1, 1)
    GameTooltip:AddLine("Ctrl-click: do not disturb on / off", 1, 1, 1)
    GameTooltip:AddLine("Shift-drag: move", 1, 1, 1)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------------

function T:AnimateTo(w, h, after)
    local f = self.frame
    self.fromW, self.fromH = f:GetWidth(), f:GetHeight()
    self.toW, self.toH = w, h
    self.animT = 0
    self.animating = true
    self.afterAnim = after
end

function T:OnUpdate(elapsed)
    local f = self.frame
    if self.animating then
        self.animT = math.min(1, self.animT + elapsed / ANIM_TIME)
        local e = 1 - (1 - self.animT) ^ 2
        f:SetSize(self.fromW + (self.toW - self.fromW) * e, self.fromH + (self.toH - self.fromH) * e)
        if self.animT >= 1 then
            self.animating = false
            local after = self.afterAnim
            self.afterAnim = nil
            if after then after() end
        end
    end
    if self.expanded then
        if f:IsMouseOver() then
            self.remaining = math.max(self.remaining, 2)
        else
            self.remaining = self.remaining - elapsed
            if self.remaining <= 0 then self:Collapse() end
        end
    end
end

function T:Expand()
    self:Create()
    local f = self.frame
    self.expanded = true
    self.remaining = SHOW_TIME
    self.pill:Hide()
    self.full:Show()
    self.fullSpin:Play()
    f:Show()
    self:AnimateTo(FULL_W, FULL_H)
end

function T:Collapse()
    if not self.frame or not self.expanded then return end
    self.expanded = false
    self.count = 0
    self.action = nil
    self.full:Hide()
    self.fullSpin:Stop()
    local keep = self:ShouldShowPill()
    self:AnimateTo(PILL_W, PILL_H, function()
        if keep then T.pill:Show() else T.frame:Hide() end
        T:Update()
    end)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

function T:ShouldShowPill()
    local s = TG.db.settings
    if not s.counter then return false end
    if s.counterHideEmpty and TG:TotalUnread() == 0 then return false end
    return true
end

function T:Update()
    if not TG.db then return end
    if not self.frame then
        if not self:ShouldShowPill() then return end
        self:Create()
    end
    local n = TG:TotalUnread()
    local pill = self.pill
    pill.count:SetText(n > 99 and "99+" or tostring(n))
    if n > 0 then
        pill.count:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3])
        pill.cog:SetDesaturated(false)
    else
        pill.count:SetTextColor(0.5, 0.5, 0.5)
        pill.cog:SetDesaturated(true)
    end
    if TG.db.settings.dnd then -- red cog = do not disturb
        pill.cog:SetVertexColor(0.95, 0.4, 0.3)
    else
        pill.cog:SetVertexColor(S.BRASS[1], S.BRASS[2], S.BRASS[3])
    end
    if not self.expanded and not self.animating then
        if self:ShouldShowPill() then
            self.frame:SetSize(PILL_W, PILL_H)
            pill:Show()
            self.frame:Show()
        else
            self.frame:Hide()
        end
    end
end

function T:Show(titleText, bodyText)
    self:Create()
    self.full.title:SetText(titleText)
    self.full.text:SetText(bodyText or "")
    self:Expand()
end

-- force: an alert word matched, so it pops up even for a channel without the Pop-up tick.
function T:OnIncoming(key, text, from, force)
    local s = TG.db.settings
    if s.dnd or not s.notify or not (force or TG:PassesNotifyFilter(key)) then return end
    if from then text = from .. ": " .. (text or "") end
    self.count = (self.expanded and not self.action and self.count or 0) + 1
    self.key = key
    self.action = nil
    local name, color = TG:ThreadDisplay(key)
    local more = self.count > 1 and ("  |cff888888(" .. self.count .. " new)|r") or ""
    self:Show(("|cff%s%s|r%s"):format(UI.hex(color), name, more), text)
end

-- A pop-up that isn't a message. Clicking it runs `action`.
function T:Notice(title, body, action)
    local s = TG.db.settings
    if s.dnd or not s.notify then return false end
    self.key = nil
    self.count = 0
    self.action = action
    self:Show(title, body)
    return true
end

function T:Preview()
    self.key = nil
    self.count = 0
    self.action = nil
    self:Show("Telegnome", "This is how new messages will appear. Click to open, right-click to mark all as read.")
end

function T:ResetPosition()
    TG.db.toastPos = nil
    self:ApplyAnchor()
end
