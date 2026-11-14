-- Telegnome: "Your chat channels" - every chat channel the character is in, with Leave buttons.
-- The game allows 10 channels, and group chats share them with General, Trade and the rest.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local L = { rows = {} }
TG.ChannelList = L

local MAX_CHANNELS = 10
local ROW_H = 26

-- Blizzard's own channels, in case EnumerateServerChannels isn't available.
local BLIZZARD = {
    general = true, trade = true, localdefense = true, worlddefense = true, lookingforgroup = true,
    guildrecruitment = true, services = true, newcomerchat = true,
}

local function baseName(name)
    return (name:match("^(.-)%s+%-%s+") or name)
end

local function serverChannels()
    local set = {}
    if EnumerateServerChannels then
        for _, n in ipairs({ EnumerateServerChannels() }) do
            if type(n) == "string" then set[n:lower()] = true end
        end
    end
    return set
end

-- Each channel with what it is: { id, name, kind = "telegnome"|"blizzard"|"community"|"custom", label, key }
function L.Collect()
    local server = serverChannels()
    local out = {}
    for _, ch in ipairs(TG.Groups.ChannelList()) do
        local e = { id = ch.id, name = ch.name }
        local base = baseName(ch.name):lower()
        if TG.Groups.IsTelegnomeChannel(ch.name) then
            e.kind = "telegnome"
            e.key = TG.Groups.KeyFor(ch.name)
            local th = TG.db.threads[e.key]
            e.label = th and th.name or "Unknown group"
            e.unknown = not th or th.unknown
        elseif ch.community then
            e.kind = "community"
            e.label = ch.name
        elseif server[base] or BLIZZARD[base] then
            e.kind = "blizzard"
            e.label = ch.name
        else
            e.kind = "custom"
            e.label = ch.name
        end
        out[#out + 1] = e
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local KIND_TEXT = {
    telegnome = "|cffffd100Telegnome group|r",
    blizzard = "|cff88aaffBlizzard|r",
    community = "|cff66ccccCommunity|r",
    custom = "|cffccccccCustom channel|r",
}

---------------------------------------------------------------------------
-- Leaving
---------------------------------------------------------------------------

local function leaveByName(name)
    local leave = LeaveChannelByName or (C_ChatInfo and C_ChatInfo.LeaveChannelByName)
    TG.Groups:NoteLeft(name)
    -- "General - Elwynn Forest" is left as "General", the way /leave does it.
    if leave then pcall(leave, baseName(name)) end
    C_Timer.After(0.5, function() L:Refresh() end)
end

local function ensurePopup()
    if StaticPopupDialogs.TELEGNOME_LEAVE_CHANNEL then return end
    StaticPopupDialogs.TELEGNOME_LEAVE_CHANNEL = {
        text = "Leave the chat channel \"%s\"?%s",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function(self, data)
            data = data or self.data
            if not data then return end
            if data.key and TG.db.threads[data.key] then TG:DeleteThread(data.key) end
            leaveByName(data.name)
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
end

function L:Leave(e)
    local th = e.key and TG.db.threads[e.key]
    if th and not th.unknown then
        -- A group Telegnome knows: the usual leave (shows the code so you can come back).
        TG.Groups:ConfirmLeave(e.key)
        return
    end
    ensurePopup()
    local extra = ""
    if e.kind == "telegnome" then
        extra = "\n\nTelegnome doesn't know this group's invite code, so you can't rejoin it unless someone sends it again."
    elseif e.kind == "blizzard" or e.kind == "custom" then
        extra = "\n\nYou can rejoin later with /join " .. baseName(e.name)
    end
    StaticPopup_Show("TELEGNOME_LEAVE_CHANNEL", e.label, extra, { name = e.name, key = e.key })
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local function createRow(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("RIGHT", 0, 0)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)

    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    row.num:SetPoint("LEFT", 6, 0)
    row.num:SetWidth(22)
    row.num:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 34, 0)
    row.name:SetWidth(190)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.kind = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.kind:SetPoint("LEFT", 230, 0)
    row.kind:SetJustifyH("LEFT")

    row.leave = S.Button(row, "Leave", 64, 20)
    row.leave:SetPoint("RIGHT", -6, 0)
    row.leave:SetScript("OnClick", function() if row.entry then L:Leave(row.entry) end end)

    row.open = S.Button(row, "Open", 56, 20)
    row.open:SetPoint("RIGHT", row.leave, "LEFT", -6, 0)
    row.open:SetScript("OnClick", function()
        if row.entry and row.entry.key and TG.db.threads[row.entry.key] then
            L:Close()
            UI:Select(row.entry.key)
        end
    end)
    return row
end

function L:Create()
    if self.frame then return end
    UI:Create()

    local f = CreateFrame("Frame", nil, UI.right, "BackdropTemplate")
    f:SetAllPoints(UI.right)
    f:SetFrameLevel(UI.right:GetFrameLevel() + 30)
    S.Inset(f)
    S.Solid(f)
    f:EnableMouse(true)
    f:Hide()
    self.frame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("Your chat channels")
    local cog = S.Cog(f, 18)
    cog:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -34)
    line:SetPoint("TOPRIGHT", -8, -34)

    local count = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    count:SetPoint("TOPLEFT", 14, -44)
    self.count = count

    local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 14, -64)
    intro:SetPoint("RIGHT", -14, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText("Every chat channel this character is in. Telegnome group chats are hidden channels and "
        .. "share the game's limit of " .. MAX_CHANNELS .. " with General, Trade and the rest.")

    local clip = CreateFrame("ScrollFrame", nil, f)
    clip:SetPoint("TOPLEFT", 8, -98)
    clip:SetPoint("BOTTOMRIGHT", -8, 42)
    clip:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, clip)
    content:SetSize(440, ROW_H)
    clip:SetScrollChild(content)
    clip:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    clip:SetScript("OnMouseWheel", function(sf, delta)
        local range = sf:GetVerticalScrollRange() or 0
        sf:SetVerticalScroll(math.max(0, math.min(range, sf:GetVerticalScroll() - delta * ROW_H * 2)))
    end)
    self.clip, self.content = clip, content

    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 8, -6)
    empty:SetText("You're not in any chat channels.")
    self.empty = empty

    local refresh = S.Button(f, "Refresh", 80, 24)
    refresh:SetPoint("BOTTOMLEFT", 10, 10)
    refresh:SetScript("OnClick", function() TG.Groups:ScanChannels(); L:Refresh() end)

    local done = S.Button(f, "Close", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    done:SetScript("OnClick", function() L:Close() end)
end

function L:Refresh()
    if not self:IsShown() then return end
    local list = L.Collect()
    local used = 0
    for _, e in ipairs(list) do
        if e.kind ~= "community" then used = used + 1 end
    end
    local color = used >= MAX_CHANNELS and "|cffff5555" or used >= MAX_CHANNELS - 1 and "|cffffaa33" or "|cff66dd66"
    self.count:SetText(("%s%d|r of %d channels used"):format(color, used, MAX_CHANNELS))

    for i, e in ipairs(list) do
        local row = self.rows[i] or createRow(self.content, i)
        self.rows[i] = row
        row.entry = e
        row.num:SetText(e.id .. ".")
        if e.kind == "telegnome" then
            row.name:SetText(e.unknown and ("|cffaaaaaa" .. e.label .. "|r") or e.label)
        else
            row.name:SetText(e.label)
        end
        row.kind:SetText(KIND_TEXT[e.kind] or "")
        row.open:SetShown(e.kind == "telegnome" and TG.db.threads[e.key] ~= nil)
        row:Show()
    end
    for i = #list + 1, #self.rows do
        self.rows[i]:Hide()
        self.rows[i].entry = nil
    end
    self.empty:SetShown(#list == 0)
    self.content:SetHeight(math.max(ROW_H, #list * ROW_H))
end

function L:IsShown()
    return self.frame and self.frame:IsShown() or false
end

function L:Open()
    UI:Show()
    self:Create()
    TG.Settings:Close()
    TG.Picker:Close()
    TG.Groups:ClosePanel()
    TG.Channels:ClosePanel()
    TG.Requests:ClosePanel()
    TG.Groups:ScanChannels()
    self.frame:Show()
    self.clip:SetVerticalScroll(0)
    self:Refresh()
end

function L:Close()
    if not self:IsShown() then return end
    self.frame:Hide()
    if UI.frame:IsShown() and UI.selected then UI:Select(UI.selected) end
end

function L:Toggle()
    if self:IsShown() then self:Close() else self:Open() end
end
