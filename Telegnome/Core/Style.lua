-- Telegnome: shared classic-style widgets (dark panels, bronze borders, gold text, brass cogs).

local _, ns = ...
local TG = ns.TG
local S = {}
TG.Style = S

S.MEDIA = "Interface\\AddOns\\Telegnome\\Media\\"
S.ICON = S.MEDIA .. "Icon"
S.COG = S.MEDIA .. "Cog"
S.BUBBLE = S.MEDIA .. "Bubble"
S.WRENCH = S.MEDIA .. "Wrench"
S.STAR = S.MEDIA .. "Star"
S.GOLD = { 1, 0.82, 0 }            -- text; the same in every theme
S.BRONZE = { 0.62, 0.47, 0.24 }    -- borders and lines   (follows the theme)
S.BRASS = { 0.95, 0.74, 0.38 }     -- cogs                (follows the theme)
S.HI = { 1, 0.82, 0 }              -- selection highlight (follows the theme)
S.PANEL = { 0.11, 0.08, 0.05 }     -- panel background    (follows the theme)

local WHITE = "Interface\\Buttons\\WHITE8x8"
local TOOLTIP_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"

---------------------------------------------------------------------------
-- Colour themes (Settings > Window, or /tg theme <name>)
---------------------------------------------------------------------------

-- edge: borders, cog: cogs, panel: backgrounds, hi: selection.
-- frame: tint for the classic gold dialog border; themes without it use a plain border in the edge colour,
-- because the gold artwork turns muddy when tinted blue, green or purple.
S.THEMES = {
    { id = "brass", label = "Brass", edge = { 0.62, 0.47, 0.24 }, cog = { 0.95, 0.74, 0.38 },
      panel = { 0.11, 0.08, 0.05 }, hi = { 1, 0.82, 0 }, frame = { 1, 1, 1 } },
    { id = "orange", label = "Orange", edge = { 0.90, 0.48, 0.10 }, cog = { 1, 0.58, 0.12 },
      panel = { 0.13, 0.07, 0.03 }, hi = { 1, 0.55, 0.05 }, frame = { 1, 0.72, 0.42 } },
    { id = "horde", label = "Horde red", edge = { 0.72, 0.20, 0.15 }, cog = { 0.96, 0.38, 0.28 },
      panel = { 0.12, 0.045, 0.04 }, hi = { 1, 0.35, 0.25 }, frame = { 1, 0.55, 0.45 } },
    { id = "alliance", label = "Alliance blue", edge = { 0.27, 0.47, 0.82 }, cog = { 0.50, 0.72, 1 },
      panel = { 0.05, 0.07, 0.12 }, hi = { 0.45, 0.70, 1 } },
    { id = "arcane", label = "Arcane", edge = { 0.56, 0.38, 0.82 }, cog = { 0.78, 0.62, 1 },
      panel = { 0.085, 0.06, 0.12 }, hi = { 0.80, 0.60, 1 } },
    { id = "fel", label = "Fel green", edge = { 0.36, 0.66, 0.25 }, cog = { 0.62, 0.95, 0.35 },
      panel = { 0.05, 0.09, 0.045 }, hi = { 0.55, 1, 0.30 } },
    { id = "steel", label = "Steel", edge = { 0.56, 0.61, 0.67 }, cog = { 0.80, 0.85, 0.90 },
      panel = { 0.075, 0.085, 0.10 }, hi = { 0.75, 0.85, 1 } },
}
S.theme = S.THEMES[1]

function S.FindTheme(id)
    id = type(id) == "string" and id:lower() or ""
    for _, t in ipairs(S.THEMES) do
        if t.id == id or t.label:lower() == id then return t end
    end
    return nil
end

-- Everything themed registers here so a theme change can repaint it.
local painted = {}

local function shade(f)
    local p = S.PANEL
    return p[1] * f, p[2] * f, p[3] * f
end

local function paint(e)
    local o, kind, x = e[1], e[2], e[3]
    local edge = S.BRONZE
    if kind == "outer" then
        local frame = S.theme.frame
        if frame then
            o:SetBackdrop({
                bgFile = WHITE, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
            o:SetBackdropBorderColor(frame[1], frame[2], frame[3], 1)
        else
            o:SetBackdrop({
                bgFile = WHITE, edgeFile = TOOLTIP_EDGE, edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            o:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
        end
        local r, g, b = shade(0.64)
        o:SetBackdropColor(r, g, b, 0.97)
        return
    elseif kind == "line" then
        o:SetColorTexture(edge[1], edge[2], edge[3], 0.6)
        return
    elseif kind == "edgetex" then
        o:SetColorTexture(edge[1], edge[2], edge[3], x or 1)
        return
    elseif kind == "cog" then
        o:SetVertexColor(S.BRASS[1], S.BRASS[2], S.BRASS[3])
        return
    elseif kind == "hi" then
        o:SetColorTexture(S.HI[1], S.HI[2], S.HI[3], x or 0.12)
        return
    elseif kind == "paneltex" then
        o:SetColorTexture(S.PANEL[1], S.PANEL[2], S.PANEL[3], 1)
        return
    end
    -- backdrop frames with the thin border
    local f, a = 1, 0.95
    if kind == "dark" then f, a = 0.32, 0.96
    elseif kind == "solid" then f, a = 1, 1
    elseif kind == "button" then f, a = 1.36, 1
    elseif kind == "toast" then f, a = 0.82, 0.95 end
    local r, g, b = shade(f)
    o:SetBackdropColor(r, g, b, a)
    o:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

-- kind: outer, inset, dark, solid, button, toast (frames); line, edgetex, cog, hi, paneltex (textures)
function S.Paint(obj, kind, extra)
    local e = { obj, kind, extra }
    painted[#painted + 1] = e
    paint(e)
    return obj
end

function S.Repaint()
    for _, e in ipairs(painted) do paint(e) end
end

-- Colours for the tabs above the lists: selected / not selected.
function S.TabColors(selected)
    if selected then
        local r, g, b = shade(2.1)
        return r, g, b, S.HI
    end
    local r, g, b = shade(0.82)
    return r, g, b, S.BRONZE
end

function S.SetTheme(id)
    local t = S.FindTheme(id) or S.THEMES[1]
    S.theme = t
    -- the shared colour tables are changed in place, so everything that reads them follows
    for i = 1, 3 do
        S.BRONZE[i], S.BRASS[i], S.PANEL[i], S.HI[i] = t.edge[i], t.cog[i], t.panel[i], t.hi[i]
    end
    S.Repaint()
    if TG.db then
        if TG.UI then TG.UI:UpdateTabs() end
        if TG.Toast then TG.Toast:Update() end
        if TG.Minimap then TG.Minimap:Update() end
        if TG.Slay and TG.Slay:IsOn() then TG.Slay:Apply() end
    end
    return t
end

-- Main window: classic dialog border over a dark background.
function S.Outer(f)
    S.Paint(f, "outer")
end

-- Inner panels: thin edge in the theme colour.
function S.Inset(f, dark)
    f:SetBackdrop({
        bgFile = WHITE,
        edgeFile = TOOLTIP_EDGE,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    S.Paint(f, dark and "dark" or "inset")
end

-- An opaque panel that covers the conversation (settings, new group...).
function S.Solid(f)
    S.Paint(f, "solid")
end

function S.Panel(parent, dark)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    S.Inset(f, dark)
    return f
end

function S.Line(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    S.Paint(t, "line")
    t:SetHeight(1)
    return t
end

function S.Cog(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(S.COG)
    S.Paint(t, "cog")
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
    S.Paint(b, "button")

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(text)
    b.fs = fs

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 3, -3)
    hl:SetPoint("BOTTOMRIGHT", -3, 3)
    S.Paint(hl, "hi", 0.12)

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

-- Horizontal slider in the classic options style.
function S.Slider(parent, width, minV, maxV, step)
    local sl = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    sl:SetOrientation("HORIZONTAL")
    sl:SetSize(width, 17)
    sl:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = sl:GetThumbTexture()
    if thumb then thumb:SetSize(32, 32) end
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step or 1)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    -- No mouse wheel on purpose: the wheel scrolls the panel the slider sits in.
    return sl
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
