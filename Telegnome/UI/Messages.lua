-- Telegnome: the message area of a conversation.
-- Every message has its own bubble. The first in a run from one person carries the name and the time; the
-- ones that follow are just the text, close underneath. Your own sit on the right in a warmer colour; days
-- are separated by a centred line. (A plain scrolling chat frame can't do any of that.)

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local num = S.Num
local MV = {}
TG.MessageView = MV

local PAD_X, PAD_Y = 10, 5   -- inside a bubble
local PAD_Y_CONT = 4         -- top and bottom of a follow-up bubble (no name line)
local GAP_CONT = 2           -- between the bubbles of one run
local GAP = 8                -- between blocks
local GAP_COMPACT = 3        -- between lines in compact mode
local NAME_H = 14
local GROUP_SECONDS = 300    -- the name is shown again after five quiet minutes
local WHEEL_STEP = 44

local View = {}
View.__index = View

local function hex(c)
    return ("%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

-- compact (Settings > Look): every message is one line, "12:30 Name: text", without bubbles or grouping.
function View:GapBefore(item)
    if self.compact then return GAP_COMPACT end
    return item.cont and GAP_CONT or GAP
end

function MV.New(parent)
    local v = setmetatable({ items = {}, frames = {}, total = 0, topPad = 0 }, View)

    local sf = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(200, 10)
    sf:SetScrollChild(content)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(_, delta)
        if IsShiftKeyDown and IsShiftKeyDown() then
            if delta > 0 then v:ScrollTo(0) else v:ScrollToBottom() end
        else
            v:ScrollTo(v:Scroll() - delta * WHEEL_STEP)
        end
    end)
    sf:SetScript("OnSizeChanged", function() v:QueueRelayout() end)
    v.frame, v.content = sf, content
    return v
end

---------------------------------------------------------------------------
-- Scrolling
---------------------------------------------------------------------------

function View:ViewSize()
    return math.max(50, num(self.frame:GetWidth(), 300)), math.max(20, num(self.frame:GetHeight(), 200))
end

function View:Range()
    local _, h = self:ViewSize()
    return math.max(0, self.total - h)
end

function View:Scroll()
    return num(self.frame:GetVerticalScroll(), 0)
end

function View:ScrollTo(y)
    self.frame:SetVerticalScroll(math.max(0, math.min(self:Range(), y)))
end

function View:ScrollToBottom()
    self:ScrollTo(self:Range())
end

function View:AtBottom()
    return self:Scroll() >= self:Range() - 4
end

---------------------------------------------------------------------------
-- Blocks
---------------------------------------------------------------------------

local function newBlock(v)
    local f = CreateFrame("Frame", nil, v.content)
    f.bg = S.Rounded(f, 8)
    f.bg:SetShown(false)

    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.name:SetPoint("TOPLEFT", PAD_X, -PAD_Y)
    f.name:SetJustifyH("LEFT")

    f.time = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.time:SetPoint("LEFT", f.name, "RIGHT", 8, 0)
    f.time:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])

    f.body = f:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    f.body:SetJustifyH("LEFT")
    f.body:SetJustifyV("TOP")
    if f.body.SetWordWrap then f.body:SetWordWrap(true) end
    if f.body.SetNonSpaceWrap then f.body:SetNonSpaceWrap(true) end

    -- the date between two days: small and dim
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.label:SetPoint("CENTER", 0, 0)
    f.label:SetTextColor(S.DIM[1] * 0.85, S.DIM[2] * 0.85, S.DIM[3] * 0.85)
    f.label:Hide()

    f.lineL = f:CreateTexture(nil, "ARTWORK")
    f.lineL:SetHeight(1)
    S.Paint(f.lineL, "line")
    f.lineR = f:CreateTexture(nil, "ARTWORK")
    f.lineR:SetHeight(1)
    S.Paint(f.lineR, "line")

    -- item, quest and player links, and the [Join group] link. A frame needs the mouse for links to work,
    -- so it also passes the mouse wheel on to the list it sits in.
    f:EnableMouse(true)
    -- when it was sent: every bubble tells on hover, also the ones without a name line
    f:SetScript("OnEnter", function(s)
        local item = s.item
        if item and item.kind == "msg" and item.t then
            GameTooltip:SetOwner(s, item.out and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
            GameTooltip:SetText(date("%A %d %B, %H:%M", item.t), 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        local onWheel = v.frame:GetScript("OnMouseWheel")
        if onWheel then onWheel(v.frame, delta) end
    end)
    if f.SetHyperlinksEnabled then
        f:SetHyperlinksEnabled(true)
        f:SetScript("OnHyperlinkClick", function(_, link, text, button)
            if v.onLink then v.onLink(link, text, button) end
        end)
    end
    if v.font then f.body:SetFont(v.font[1], v.font[2], v.font[3]) end
    return f
end

-- Fills one block from its item and sizes it. Returns its height.
function View:Fill(f, item)
    local viewW = self:ViewSize()
    f.item = item
    f.body:ClearAllPoints()
    if item.kind == "divider" then
        -- a centred date between two thin lines
        f.bg:SetShown(false)
        f.name:Hide()
        f.time:Hide()
        f.body:SetText("")
        f.body:SetPoint("TOPLEFT", 0, 0)
        f.label:SetText(item.text)
        f.label:Show()
        f.lineL:ClearAllPoints()
        f.lineL:SetPoint("LEFT", 2, 0)
        f.lineL:SetPoint("RIGHT", f.label, "LEFT", -10, 0)
        f.lineR:ClearAllPoints()
        f.lineR:SetPoint("LEFT", f.label, "RIGHT", 10, 0)
        f.lineR:SetPoint("RIGHT", -2, 0)
        f.lineL:Show()
        f.lineR:Show()
        f:SetSize(viewW, 14)
        return 14
    end
    f.label:Hide()
    f.lineL:Hide()
    f.lineR:Hide()

    if item.kind == "note" then
        -- a line that isn't a chat message: who joined, "not delivered", hints, who is online
        f.bg:SetShown(false)
        f.name:Hide()
        f.time:Hide()
        local w = viewW - 2 * PAD_X
        f.body:SetWidth(w)
        f.body:SetText(item.text)
        f.body:SetTextColor(item.r or S.DIM[1], item.g or S.DIM[2], item.b or S.DIM[3])
        f.body:SetJustifyH(item.center and "CENTER" or "LEFT")
        f.body:SetPoint("TOPLEFT", PAD_X, -1)
        local h = num(f.body:GetStringHeight(), 14) + 2
        f:SetSize(viewW, h)
        return h
    end

    if self.compact then
        -- one line per message: time, name, text
        local c = item.color or S.GOLD
        f.bg:SetShown(false)
        f.name:Hide()
        f.time:Hide()
        f.body:SetWidth(viewW - 8)
        f.body:SetText(("|cff8a7a5c%s|r  |cff%s%s:|r %s"):format(item.time or "", hex(c), item.who or "?", item.text))
        f.body:SetTextColor(S.TEXT[1], S.TEXT[2], S.TEXT[3])
        f.body:SetJustifyH("LEFT")
        f.body:SetPoint("TOPLEFT", 4, 0)
        local h = num(f.body:GetStringHeight(), 14)
        f:SetSize(viewW, h)
        return h
    end

    -- a block of chat messages from one person
    local maxW = math.max(120, math.floor(viewW * 0.78) - 2 * PAD_X)
    local cont = item.cont and true or false   -- a follow-up: no name line
    local top = cont and PAD_Y_CONT or (PAD_Y + NAME_H + 2)
    local bottom = cont and PAD_Y_CONT or PAD_Y
    f.name:SetShown(not cont)
    f.time:SetShown(not cont)
    f.name:SetText(item.who or "?")
    local c = item.color or S.GOLD
    f.name:SetTextColor(c[1], c[2], c[3])
    f.time:SetText(item.time or "")
    f.body:SetWidth(maxW)
    f.body:SetText(item.text)
    f.body:SetTextColor(S.TEXT[1], S.TEXT[2], S.TEXT[3])
    f.body:SetJustifyH("LEFT")
    f.body:SetPoint("TOPLEFT", PAD_X, -top)

    local bodyW = f.body.GetWrappedWidth and num(f.body:GetWrappedWidth(), 0) or 0
    if bodyW < 8 then bodyW = math.min(num(f.body:GetStringWidth(), maxW), maxW) end
    if bodyW < 8 then bodyW = maxW end
    local headW = cont and 0 or (num(f.name:GetStringWidth(), 40) + 8 + num(f.time:GetStringWidth(), 30))
    local w = math.min(maxW, math.max(bodyW, headW)) + 2 * PAD_X
    local h = top + num(f.body:GetStringHeight(), 14) + bottom
    f:SetSize(w, h)
    -- both sides get a bubble: yours warmer (a touch of the theme colour) on the right, theirs neutral on the left
    local p, e = S.PANEL, S.BRONZE
    f.bg:SetShown(true)
    if item.out then
        f.bg:SetColor(p[1] * 1.2 + e[1] * 0.2, p[2] * 1.2 + e[2] * 0.2, p[3] * 1.2 + e[3] * 0.2, 1)
    else
        f.bg:SetColor(p[1] * 1.45, p[2] * 1.45, p[3] * 1.45, 1)
    end
    return h
end

function View:Place(f, item)
    f:ClearAllPoints()
    local y = -(self.topPad + item.y)
    if item.kind == "msg" and item.out and not self.compact then
        f:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -2, y)
    else
        f:SetPoint("TOPLEFT", self.content, "TOPLEFT", (item.kind == "msg") and 2 or 0, y)
    end
    f:Show()
end

-- Short conversations sit at the bottom, like in any messenger.
function View:Finish(replaceAll)
    local viewW, viewH = self:ViewSize()
    local n = #self.items
    local last = self.items[n]
    self.total = last and (last.y + last.h) or 0
    local topPad = math.max(0, viewH - self.total)
    self.content:SetSize(viewW, math.max(self.total, viewH))
    if replaceAll or topPad ~= self.topPad then
        self.topPad = topPad
        for i = 1, n do self:Place(self.frames[i], self.items[i]) end
    elseif last then
        self:Place(self.frames[n], last)
    end
end

function View:Relayout(keepBottom)
    local prev
    for i, item in ipairs(self.items) do
        local f = self.frames[i]
        if not f then
            f = newBlock(self)
            self.frames[i] = f
        end
        item.y = prev and (prev.y + prev.h + self:GapBefore(item)) or 0
        item.h = self:Fill(f, item)
        prev = item
    end
    for i = #self.items + 1, #self.frames do
        self.frames[i]:Hide()
        self.frames[i].item = nil
    end
    self:Finish(true)
    if keepBottom then self:ScrollToBottom() end
end

function View:QueueRelayout()
    if self.pending or #self.items == 0 then return end
    self.pending = true
    local bottom = self:AtBottom()
    C_Timer.After(0.05, function()
        self.pending = false
        self:Relayout(bottom)
    end)
end

---------------------------------------------------------------------------
-- Content
---------------------------------------------------------------------------

function View:Clear()
    self.items = {}
    for _, f in ipairs(self.frames) do
        f:Hide()
        f.item = nil
    end
    self.total, self.topPad = 0, 0
    self.frame:SetVerticalScroll(0)
end

-- Adds one item at the end and lays out just that one.
function View:Append(item)
    local n = #self.items + 1
    if self.bulk then
        self.items[n] = item
        return
    end
    local bottom = self:AtBottom()
    local prev = self.items[n - 1]
    local f = self.frames[n]
    if not f then
        f = newBlock(self)
        self.frames[n] = f
    end
    self.items[n] = item
    item.y = prev and (prev.y + prev.h + self:GapBefore(item)) or 0
    item.h = self:Fill(f, item)
    self:Finish(false)
    if bottom then self:ScrollToBottom() end
end

-- Between Begin and End nothing is laid out: a whole conversation is added, then drawn once.
function View:Begin()
    self.bulk = true
end

function View:End()
    self.bulk = false
    self:Relayout(true)
end

function View:AddDivider(text)
    self:Append({ kind = "divider", text = text })
end

function View:AddNote(text, r, g, b, center, idx)
    self:Append({ kind = "note", text = text, r = r, g = g, b = b, center = center, idx = idx })
end

-- Scrolls to the message with this number in the conversation and lights it up for a moment (search).
function View:Reveal(idx)
    if not idx then return end
    for i, item in ipairs(self.items) do
        if item.idx == idx then
            self:ScrollTo(self.topPad + item.y - 30)
            local f = self.frames[i]
            if f and f.bg then
                f.bg:SetShown(true)
                f.bg:SetColor(S.HI[1] * 0.45, S.HI[2] * 0.45, S.HI[3] * 0.45, 1)
                C_Timer.After(1.6, function()
                    if f.item == item then self:Fill(f, item) end
                end)
            end
            return
        end
    end
end

-- msg: { sender = id, who = name, color = { r, g, b }, out = bool, t = time, text = string }
-- A message from the same person within a few minutes gets a bubble without the name line (cont).
function View:AddMessage(msg)
    local last = self.items[#self.items]
    local cont = not self.compact and last and last.kind == "msg" and last.sender == msg.sender
        and (msg.t or 0) - (last.t or 0) < GROUP_SECONDS and (msg.t or 0) >= (last.t or 0)
    self:Append({
        kind = "msg", sender = msg.sender, who = msg.who, color = msg.color, out = msg.out,
        time = msg.t and date("%H:%M", msg.t) or "", t = msg.t, text = msg.text, cont = cont or nil, idx = msg.idx,
    })
end

function View:SetBodyFont(path, size, flags)
    self.font = { path, size, flags or "" }
    for _, f in ipairs(self.frames) do f.body:SetFont(path, size, flags or "") end
    if #self.items > 0 then self:Relayout(true) end
end
