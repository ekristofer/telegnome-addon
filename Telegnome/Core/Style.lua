-- Telegnome: shared widgets (flat dark panels, thin borders in the theme colour, gold text, brass cogs).

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
S.ROUND = S.MEDIA .. "Round"         -- a filled circle: dots, badge ends, rounded corners
S.CLOSE = S.MEDIA .. "Close"
S.CHEV_DOWN = S.MEDIA .. "ChevDown"
S.CHEV_RIGHT = S.MEDIA .. "ChevRight"
S.DOTS = S.MEDIA .. "Dots"
S.SEARCH = S.MEDIA .. "Search"
S.GROUP = S.MEDIA .. "Group"
S.TEXT = { 0.94, 0.90, 0.82 }      -- message and body text
S.DIM = { 0.66, 0.59, 0.48 }       -- secondary text: times, previews, captions
S.BADGE = { 0.70, 0.15, 0.12 }     -- unread badges
S.ONLINE = { 0.31, 0.77, 0.42 }
S.OFFLINE = { 0.44, 0.39, 0.32 }
S.GOLD = { 1, 0.82, 0 }            -- text; the same in every theme
S.BRONZE = { 0.62, 0.47, 0.24 }    -- borders and lines   (follows the theme)
S.BRASS = { 0.95, 0.74, 0.38 }     -- cogs                (follows the theme)
S.HI = { 1, 0.82, 0 }              -- selection highlight (follows the theme)
S.PANEL = { 0.11, 0.08, 0.05 }     -- panel background    (follows the theme)

local WHITE = "Interface\\Buttons\\WHITE8x8"

---------------------------------------------------------------------------
-- Colour themes (Settings > Look, or /tg theme <name>)
---------------------------------------------------------------------------

-- edge: borders, cog: cogs, panel: backgrounds, hi: selection.
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

-- How strongly each kind of frame shows its border, and how light its background is against the panel colour.
local FRAME_KINDS = {
    outer = { 0.82, 0.97, 1 },    -- { background shade, background alpha, border alpha }
    inset = { 1, 0.95, 0.35 },
    plain = { 0.64, 1, 0 },       -- the list column: a darker strip, no border
    dark = { 0.45, 0.96, 0.5 },   -- text boxes
    solid = { 1, 1, 0.35 },
    button = { 1.3, 1, 0.6 },
    card = { 1.25, 1, 0.25 },     -- rows that stand on their own, like requests
    toast = { 0.82, 0.95, 0.9 },
    cover = { 0.82, 1, 0 },       -- a view that takes over the whole body: the window's own colour, no border
}

local function paint(e)
    local o, kind, x = e[1], e[2], e[3]
    local edge = S.BRONZE
    if kind == "line" then
        o:SetColorTexture(edge[1], edge[2], edge[3], x or 0.35)
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
    elseif kind == "hivertex" then -- a white texture (icon, rounded shape) in the highlight colour
        o:SetVertexColor(S.HI[1], S.HI[2], S.HI[3], x or 1)
        return
    elseif kind == "paneltex" then
        o:SetColorTexture(S.PANEL[1], S.PANEL[2], S.PANEL[3], 1)
        return
    elseif kind == "shadetex" then -- a white texture tinted with a shade of the panel colour
        local r, g, b = shade(x or 1)
        o:SetVertexColor(r, g, b, 1)
        return
    elseif kind == "primary" then  -- the one button that matters in a row
        o:SetBackdropColor(edge[1] * 0.55, edge[2] * 0.55, edge[3] * 0.55, 1)
        o:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
        return
    end
    local k = FRAME_KINDS[kind] or FRAME_KINDS.inset
    local r, g, b = shade(k[1])
    o:SetBackdropColor(r, g, b, k[2])
    o:SetBackdropBorderColor(edge[1], edge[2], edge[3], k[3])
end

-- kind: outer, inset, plain, dark, solid, button, primary, card, toast, cover (frames);
--       line, edgetex, cog, hi, hivertex, paneltex, shadetex (textures)
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

-- One-pixel square border, the same on every frame.
local function flat(f, edgeSize)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = edgeSize or 1 })
end
S.Flat = flat

-- Main window: a plain border in the theme colour over a dark background.
function S.Outer(f)
    flat(f, 2)
    S.Paint(f, "outer")
end

-- Inner panels: thin edge in the theme colour.
function S.Inset(f, dark)
    flat(f)
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

-- A darker strip without a border (the list column).
function S.Strip(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    flat(f)
    S.Paint(f, "plain")
    return f
end

---------------------------------------------------------------------------
-- Round things: dots, badges, rounded backgrounds
---------------------------------------------------------------------------

local function num(v, default)
    return type(v) == "number" and v or default
end
S.Num = num

function S.Dot(parent, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(S.ROUND)
    return t
end

-- A white icon from the Media folder, tinted.
function S.Icon(parent, tex, size, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(tex)
    return t
end

-- Unread badge: a rounded pill with a number. Hidden when there is nothing to count.
function S.Pill(parent, height)
    local h = height or 16
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(h, h)
    local c = S.BADGE
    local left = p:CreateTexture(nil, "ARTWORK")
    left:SetTexture(S.ROUND)
    left:SetTexCoord(0, 0.5, 0, 1)
    left:SetSize(h / 2, h)
    left:SetPoint("LEFT")
    local right = p:CreateTexture(nil, "ARTWORK")
    right:SetTexture(S.ROUND)
    right:SetTexCoord(0.5, 1, 0, 1)
    right:SetSize(h / 2, h)
    right:SetPoint("RIGHT")
    local mid = p:CreateTexture(nil, "ARTWORK")
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    mid:SetColorTexture(1, 1, 1, 1)
    p.parts = { left, right, mid }
    function p:SetColor(r, g, b, a)
        for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b, a or 1) end
    end
    p:SetColor(c[1], c[2], c[3])
    local fs = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetTextColor(1, 1, 1)
    p.fs = fs
    function p:SetLabel(text)
        self.fs:SetText(text or "")
        self:SetWidth(math.max(h, num(self.fs:GetStringWidth(), 6) + 10))
        self:SetShown(text ~= nil and text ~= "")
    end
    function p:SetCount(n)
        n = num(n, 0)
        self:SetLabel(n > 0 and (n > 99 and "99+" or tostring(n)) or nil)
    end
    p:Hide()
    return p
end

-- A rounded background behind everything else in `frame`. Returns it; :SetColor(r, g, b, a) paints it.
function S.Rounded(frame, radius, layer)
    layer = layer or "BACKGROUND"
    local r = radius or 6
    local bg = { parts = {} }
    local function corner(point, l, rt, t, b)
        local tex = frame:CreateTexture(nil, layer)
        tex:SetTexture(S.ROUND)
        tex:SetTexCoord(l, rt, t, b)
        tex:SetSize(r, r)
        tex:SetPoint(point)
        bg.parts[#bg.parts + 1] = tex
        return tex
    end
    local tl = corner("TOPLEFT", 0, 0.5, 0, 0.5)
    local tr = corner("TOPRIGHT", 0.5, 1, 0, 0.5)
    local bl = corner("BOTTOMLEFT", 0, 0.5, 0.5, 1)
    local br = corner("BOTTOMRIGHT", 0.5, 1, 0.5, 1)
    local function fill(p1, rel1, rp1, p2, rel2, rp2)
        local tex = frame:CreateTexture(nil, layer)
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetPoint(p1, rel1, rp1)
        tex:SetPoint(p2, rel2, rp2)
        bg.parts[#bg.parts + 1] = tex
    end
    fill("TOPLEFT", tl, "TOPRIGHT", "BOTTOMRIGHT", tr, "BOTTOMLEFT")   -- top edge
    fill("TOPLEFT", bl, "TOPRIGHT", "BOTTOMRIGHT", br, "BOTTOMLEFT")   -- bottom edge
    fill("TOPLEFT", tl, "BOTTOMLEFT", "BOTTOMRIGHT", br, "TOPRIGHT")   -- middle
    function bg:SetColor(cr, cg, cb, ca)
        for _, t in ipairs(self.parts) do t:SetVertexColor(cr, cg, cb, ca or 1) end
    end
    function bg:SetShown(v)
        for _, t in ipairs(self.parts) do t:SetShown(v) end
    end
    return bg
end

-- Small, dim, upper-case label above a group of things.
function S.Caption(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetText((text or ""):upper())
    fs:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    return fs
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

-- Flat dark button with a thin edge and gold text. primary = true fills it: the one that matters in a row.
function S.Button(parent, text, w, h, primary)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    flat(b)
    S.Paint(b, primary and "primary" or "button")

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(text)
    b.fs = fs

    -- a lighter upper half and a dark line at the bottom: a hint of the game's bevelled buttons
    local gloss = b:CreateTexture(nil, "BORDER")
    gloss:SetPoint("TOPLEFT", 1, -1)
    gloss:SetPoint("RIGHT", -1, 0)
    gloss:SetHeight(math.max(2, math.floor(h / 2) - 1))
    gloss:SetColorTexture(1, 1, 1, 0.06)
    local shadow = b:CreateTexture(nil, "BORDER")
    shadow:SetPoint("BOTTOMLEFT", 1, 1)
    shadow:SetPoint("RIGHT", -1, 0)
    shadow:SetHeight(1)
    shadow:SetColorTexture(0, 0, 0, 0.35)

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    S.Paint(hl, "hi", 0.12)

    b:SetScript("OnMouseDown", function(s) if s:IsEnabled() then s.fs:SetPoint("CENTER", 1, -1) end end)
    b:SetScript("OnMouseUp", function(s) s.fs:SetPoint("CENTER", 0, 0) end)
    b:HookScript("OnDisable", function(s) s.fs:SetTextColor(0.5, 0.5, 0.5) end)
    b:HookScript("OnEnable", function(s) s.fs:SetTextColor(S.GOLD[1], S.GOLD[2], S.GOLD[3]) end)
    return b
end

-- Square button with a white icon from the Media folder (settings, close, more).
function S.IconButton(parent, tex, size, iconSize)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(size, size)
    flat(b)
    S.Paint(b, "button")
    local icon = S.Icon(b, tex, iconSize or math.floor(size * 0.55))
    icon:SetPoint("CENTER")
    icon:SetVertexColor(0.85, 0.71, 0.42)
    b.icon = icon
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    S.Paint(hl, "hi", 0.14)
    -- lit = true: the panel this button opens is showing
    function b:SetLit(lit)
        if lit then
            self.icon:SetVertexColor(1, 0.91, 0.69)
            self:SetBackdropBorderColor(S.HI[1], S.HI[2], S.HI[3], 1)
        else
            self.icon:SetVertexColor(0.85, 0.71, 0.42)
            self:SetBackdropBorderColor(S.BRONZE[1], S.BRONZE[2], S.BRONZE[3], 0.6)
        end
    end
    return b
end

-- Text that acts as a button ("Close all", "Clear all").
-- Class icons (the round ones from character creation). Sets the texture; false when the class is unknown.
S.CLASS_ICONS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_COORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
    PALADIN = { 0, 0.25, 0.5, 0.75 },
}
function S.SetClassIcon(tex, class)
    local c = class and ((CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]) or CLASS_COORDS[class])
    if type(c) ~= "table" then return false end
    tex:SetTexture(S.CLASS_ICONS)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
    return true
end

function S.Link(parent, text, font)
    local b = CreateFrame("Button", nil, parent)
    local fs = b:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(0.85, 0.71, 0.42)
    b.fs = fs
    b:SetSize(S.Num(fs:GetStringWidth(), 40) + 6, 16)
    b:SetScript("OnEnter", function(s) if s:IsEnabled() then s.fs:SetTextColor(1, 0.91, 0.69) end end)
    b:SetScript("OnLeave", function(s) if s:IsEnabled() then s.fs:SetTextColor(0.85, 0.71, 0.42) end end)
    b:HookScript("OnDisable", function(s) s.fs:SetTextColor(0.45, 0.42, 0.36) end)
    b:HookScript("OnEnable", function(s) s.fs:SetTextColor(0.85, 0.71, 0.42) end)
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
