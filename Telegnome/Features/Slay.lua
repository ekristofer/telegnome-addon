-- Telegnome: slaay mode (/tg slaay-mode). Rainbows. Not listed in /tg help.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local Y = { bars = {} }
TG.Slay = Y

local FLAG = {
    { 0.90, 0.10, 0.12 }, { 1.00, 0.55, 0.00 }, { 1.00, 0.93, 0.00 },
    { 0.00, 0.62, 0.20 }, { 0.14, 0.40, 1.00 }, { 0.62, 0.20, 0.82 },
}

function Y:IsOn()
    return TG.db and TG.db.settings.slay or false
end

-- hue 0..1 -> bright r, g, b
local function hue(h)
    h = (h % 1) * 6
    local x = 1 - math.abs(h % 2 - 1)
    local r, g, b
    if h < 1 then r, g, b = 1, x, 0
    elseif h < 2 then r, g, b = x, 1, 0
    elseif h < 3 then r, g, b = 0, 1, x
    elseif h < 4 then r, g, b = 0, x, 1
    elseif h < 5 then r, g, b = x, 0, 1
    else r, g, b = 1, 0, x end
    -- soften a little so it glows rather than burns
    return 0.25 + r * 0.75, 0.25 + g * 0.75, 0.25 + b * 0.75
end

-- "Telegnome" with every letter in the next colour of the rainbow.
function Y.Text(text)
    local out, n, i = {}, #text, 0
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local r, g, b = hue(i / math.max(n, 1) * 0.85)
        out[#out + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), ch)
        i = i + 1
    end
    return table.concat(out)
end

-- A six-stripe flag bar that fills `holder`.
local function flagBar(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder.stripes = {}
    for i, c in ipairs(FLAG) do
        local t = holder:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(c[1], c[2], c[3], 1)
        holder.stripes[i] = t
    end
    local function layout(self)
        local w = (self:GetWidth() or 0) / #FLAG
        for i, t in ipairs(self.stripes) do
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", (i - 1) * w, 0)
            t:SetPoint("BOTTOMLEFT", (i - 1) * w, 0)
            t:SetWidth(math.max(1, w))
        end
    end
    holder:SetScript("OnSizeChanged", layout)
    holder:SetScript("OnShow", layout)
    holder:Hide()
    return holder
end

function Y:EnsureBars()
    if UI.frame and not self.bars.window then
        local b = flagBar(UI.frame)
        b:SetPoint("TOPLEFT", 16, -44)
        b:SetPoint("TOPRIGHT", -16, -44)
        b:SetHeight(4)
        self.bars.window = b
    end
    local toast = TG.Toast and TG.Toast.frame
    if toast and not self.bars.toast then
        local b = flagBar(toast)
        b:SetPoint("BOTTOMLEFT", 4, 3)
        b:SetPoint("BOTTOMRIGHT", -4, 3)
        b:SetHeight(3)
        self.bars.toast = b
    end
end

-- The cogs, borders and the minimap icon drift through the rainbow.
local function tick(_, elapsed)
    Y.t = (Y.t or 0) + elapsed
    Y.acc = (Y.acc or 0) + elapsed
    if Y.acc < 0.04 then return end
    Y.acc = 0
    Y:EnsureBars()
    local base = Y.t * 0.12
    if UI.frame and UI.frame:IsShown() then
        if UI.cogs then
            for i, cog in ipairs(UI.cogs) do cog:SetVertexColor(hue(base + i * 0.5)) end
        end
        UI.frame:SetBackdropBorderColor(hue(base + 0.25))
    end
    local toast = TG.Toast
    if toast and toast.frame and toast.frame:IsShown() then
        toast.frame:SetBackdropBorderColor(hue(base + 0.6))
        if toast.pill and toast.pill.cog and not TG.db.settings.dnd then toast.pill.cog:SetVertexColor(hue(base)) end
    end
    local mm = TG.Minimap
    if mm and mm.icon and not TG.db.settings.dnd then mm.icon:SetVertexColor(hue(base + 0.4)) end
end

function Y:Apply()
    local on = self:IsOn()
    if not self.ticker then self.ticker = CreateFrame("Frame") end
    self.ticker:SetScript("OnUpdate", on and tick or nil)
    self:EnsureBars()
    for _, b in pairs(self.bars) do b:SetShown(on) end
    if not on then
        -- back to brass and bronze
        if UI.frame then
            UI.frame:SetBackdropBorderColor(1, 1, 1, 1)
            for _, cog in ipairs(UI.cogs or {}) do cog:SetVertexColor(S.BRASS[1], S.BRASS[2], S.BRASS[3]) end
        end
        local toast = TG.Toast
        if toast and toast.frame then
            toast.frame:SetBackdropBorderColor(S.BRONZE[1], S.BRONZE[2], S.BRONZE[3], 1)
        end
    end
    if TG.Toast then TG.Toast:Update() end
    if TG.Minimap then TG.Minimap:Update() end
    UI:UpdateTitle()
    if UI.frame and UI.frame:IsShown() and UI.selected then UI:Select(UI.selected) end
end

function Y:Toggle()
    TG.db.settings.slay = not TG.db.settings.slay
    self:Apply()
    if TG.db.settings.slay then
        TG:Print(Y.Text("Slaay mode on.") .. " Same command to turn it off.")
    else
        TG:Print("Slaay mode off. Back to brass.")
    end
end

-- Switch it on at login if it was left on, and whenever the window is first built.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if Y:IsOn() then Y:Apply() end
end)
if hooksecurefunc then
    hooksecurefunc(UI, "Create", function()
        if Y:IsOn() and not Y.bars.window then Y:Apply() end
    end)
end
