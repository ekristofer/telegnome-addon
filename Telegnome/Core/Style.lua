-- Telegnome: shared classic-style widgets (dark panels, bronze borders, gold text, brass cogs).

local _, ns = ...
local TG = ns.TG
local S = {}
TG.Style = S

S.MEDIA = "Interface\\AddOns\\Telegnome\\Media\\"
S.ICON = S.MEDIA .. "Icon"
S.COG = S.MEDIA .. "Cog"
S.BUBBLE = S.MEDIA .. "Bubble"
S.GOLD = { 1, 0.82, 0 }
S.BRONZE = { 0.62, 0.47, 0.24 }
S.BRASS = { 0.95, 0.74, 0.38 }

local WHITE = "Interface\\Buttons\\WHITE8x8"
local TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Main window: classic dialog border over dark brown.
function S.Outer(f)
    f:SetBackdrop({
        bgFile = WHITE,
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0.07, 0.05, 0.035, 0.97)
end

-- Inner panels: thin bronze edge.
function S.Inset(f, dark)
    f:SetBackdrop({
        bgFile = WHITE,
        edgeFile = TOOLTIP_EDGE,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    if dark then
        f:SetBackdropColor(0.035, 0.025, 0.015, 0.96)
    else
        f:SetBackdropColor(0.11, 0.08, 0.05, 0.95)
    end
    f:SetBackdropBorderColor(S.BRONZE[1], S.BRONZE[2], S.BRONZE[3], 1)
end

function S.Panel(parent, dark)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    S.Inset(f, dark)
    return f
end

function S.Line(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(S.BRONZE[1], S.BRONZE[2], S.BRONZE[3], 0.6)
    t:SetHeight(1)
    return t
end

function S.Cog(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(S.COG)
    t:SetVertexColor(S.BRASS[1], S.BRASS[2], S.BRASS[3])
    return t
end

-- Rotation animation. loop=true spins forever, otherwise turns `degrees` once.
function S.Spin(tex, seconds, degrees, loop)
    local ag = tex:CreateAnimationGroup()
    local r = ag:CreateAnimation("Rotation")
    r:SetDegrees(degrees)
    r:SetDuration(seconds)
    if loop then ag:SetLooping("REPEAT") end
    return ag
end

-- Dark button with bronze edge and gold text (like the Dungeon Journal buttons).
function S.Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop({
        bgFile = WHITE,
        edgeFile = TOOLTIP_EDGE,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    b:SetBackdropColor(0.15, 0.11, 0.07, 1)
    b:SetBackdropBorderColor(S.BRONZE[1], S.BRONZE[2], S.BRONZE[3], 1)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(text)
    b.fs = fs

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3)
    hl:SetPoint("BOTTOMRIGHT", -3, 3)
    hl:SetColorTexture(1, 0.82, 0, 0.12)

    b:SetScript("OnMouseDown", function(s) if s:IsEnabled() then s.fs:SetPoint("CENTER", 1, -1) end end)
    b:SetScript("OnMouseUp", function(s) s.fs:SetPoint("CENTER", 0, 0) end)
    b:HookScript("OnDisable", function(s) s.fs:SetTextColor(0.5, 0.5, 0.5) end)
    b:HookScript("OnEnable", function(s) s.fs:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3]) end)
    return b
end

-- Small cog-shaped icon button (e.g. settings).
function S.CogButton(parent, size, tooltip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local t = S.Cog(b, size)
    t:SetAllPoints()
    b.tex = t
    local spin = S.Spin(t, 0.6, -90)
    b:SetScript("OnEnter", function(s)
        t:SetVertexColor(1, 0.9, 0.55)
        spin:Play()
        if tooltip then
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function()
        t:SetVertexColor(S.BRASS[1], S.BRASS[2], S.BRASS[3])
        GameTooltip:Hide()
    end)
    return b
end

function S.EditBox(parent, withSearchIcon)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    S.Inset(e, true)
    e:SetFontObject(ChatFontNormal)
    e:SetTextInsets(withSearchIcon and 24 or 8, 8, 0, 0)
    e:SetAutoFocus(false)
    if withSearchIcon then
        local icon = e:CreateTexture(nil, "OVERLAY")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", 7, 0)
        icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
        icon:SetVertexColor(0.85, 0.75, 0.55)
    end
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    return e
end

local function labelled(widget, label, font)
    local fs = widget:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("LEFT", widget, "RIGHT", 2, 1)
    fs:SetText(label)
    widget.label = fs
    if widget.Text then widget.Text:SetText("") end
    if widget.text then widget.text:SetText("") end
    return widget
end

function S.Check(parent, label)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    return labelled(c, label)
end

function S.Radio(parent, label)
    local r = CreateFrame("CheckButton", nil, parent, "UIRadioButtonTemplate")
    r:SetSize(16, 16)
    return labelled(r, label, "GameFontHighlightSmall")
end

function S.SetWidgetEnabled(w, enabled)
    w:SetEnabled(enabled)
    if w.label then
        if enabled then w.label:SetTextColor(1, 1, 1) else w.label:SetTextColor(0.5, 0.5, 0.5) end
    end
end

function S.Tooltip(widget, title, text)
    widget:HookScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
