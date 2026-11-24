-- Telegnome: search messages, in all conversations or in one.
-- Results are newest first; clicking one opens the conversation and shows the message.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local num = S.Num
local F = { rows = {}, results = {}, offset = 0 }
TG.Search = F

local ROW_H = 40
local MAX_RESULTS = 200

-- The text without colours, links and icons, as it reads on screen.
local function plain(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "") -- also named colours (|cnIQ3:)
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return (text:gsub("[\r\n]+", " "))
end
F.Plain = plain

local function esc(s)
    return (s:gsub("|", "||"))
end

-- Moves a byte position off the middle of a multi-byte letter.
local function charStart(s, i)
    while i > 1 and i <= #s do
        local b = s:byte(i)
        if b < 128 or b >= 192 then break end
        i = i - 1
    end
    return i
end

-- About 90 characters around the match, with the match in gold.
function F.Snippet(text, pos, len)
    local from = charStart(text, math.max(1, pos - 30))
    local to = math.min(#text, pos + len + 60)
    if to < #text then to = charStart(text, to + 1) - 1 end
    local before = text:sub(from, pos - 1)
    local match = text:sub(pos, pos + len - 1)
    local after = text:sub(pos + len, to)
    return (from > 1 and "..." or "") .. esc(before) .. "|cffffd100" .. esc(match) .. "|r" .. esc(after)
        .. (to < #text and "..." or "")
end

-- Every message containing `query` (case doesn't matter), newest first. scope: a conversation key, or nil.
function F.Find(query, scope)
    local out = {}
    if type(query) ~= "string" then return out end
    local q = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if #q < 2 then return out end
    for key, th in pairs(TG.db.threads) do
        if (not scope or key == scope) and th.msgs then
            for i, m in ipairs(th.msgs) do
                if not m.sys and type(m.text) == "string" then
                    local text = plain(m.text)
                    local pos = text:lower():find(q, 1, true)
                    if pos then
                        out[#out + 1] = { key = key, idx = i, t = m.t or 0, out = m.out, from = m.from,
                            snippet = F.Snippet(text, pos, #q) }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    for i = #out, MAX_RESULTS + 1, -1 do out[i] = nil end
    return out
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local function createRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("RIGHT", 0, 0)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    S.Paint(hl, "hi", 0.10)

    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.time:SetPoint("TOPRIGHT", -8, -6)
    row.time:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 8, -5)
    row.name:SetPoint("RIGHT", row.time, "LEFT", -8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("BOTTOMLEFT", 8, 6)
    row.text:SetPoint("RIGHT", -8, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.text:SetTextColor(0.85, 0.80, 0.70)

    row:SetScript("OnClick", function(s)
        local r = s.result
        if not r or not TG.db.threads[r.key] then return end
        F:Close()
        UI:Select(r.key)
        UI.msgs:Reveal(r.idx)
    end)
    return row
end

function F:Create()
    if self.frame then return end
    UI:Create()

    local f = CreateFrame("Frame", nil, UI.right, "BackdropTemplate")
    f:SetAllPoints(UI.right)
    f:SetFrameLevel(UI.right:GetFrameLevel() + 30)
    S.Inset(f)
    S.Solid(f)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:Hide()
    self.frame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("Search")
    local cog = S.Cog(f, 18)
    cog:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -34)
    line:SetPoint("TOPRIGHT", -8, -34)

    local box = S.EditBox(f)
    box:SetPoint("TOPLEFT", 12, -44)
    box:SetPoint("TOPRIGHT", -12, -44)
    box:SetHeight(28)
    box:SetMaxLetters(60)
    local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", 9, 0)
    hint:SetText("Type at least two letters...")
    box:SetScript("OnTextChanged", function(b)
        hint:SetShown((b:GetText() or "") == "")
        -- search a moment after the last key, not on every letter
        F.pending = (F.pending or 0) + 1
        local mine = F.pending
        C_Timer.After(0.25, function() if F.pending == mine then F:Run() end end)
    end)
    box:SetScript("OnEnterPressed", function(b)
        b:ClearFocus()
        local r = F.results[1]
        if r and #F.results == 1 then
            F.rows[1]:Click()
        end
    end)
    box:SetScript("OnEscapePressed", function() F:Close() end)
    self.box = box

    local scopeText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    scopeText:SetPoint("TOPLEFT", 14, -80)
    scopeText:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    self.scopeText = scopeText
    local allLink = S.Link(f, "Search all conversations")
    allLink:SetPoint("LEFT", scopeText, "RIGHT", 10, 0)
    allLink:SetScript("OnClick", function()
        F.scope = nil
        F:Run()
    end)
    self.allLink = allLink

    local count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    count:SetPoint("TOPRIGHT", -14, -80)
    count:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    self.count = count

    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", 8, -98)
    list:SetPoint("BOTTOMRIGHT", -8, 42)
    if list.SetClipsChildren then list:SetClipsChildren(true) end
    self.list = list
    f:SetScript("OnMouseWheel", function(_, delta)
        F.offset = math.max(0, (F.offset or 0) - delta * 2)
        F:Fill()
    end)
    f:SetScript("OnSizeChanged", function() F:Fill() end)

    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 8, -8)
    empty:SetPoint("RIGHT", -8, 0)
    empty:SetJustifyH("LEFT")
    self.empty = empty

    local done = S.Button(f, "Close", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -26, 10)
    done:SetScript("OnClick", function() F:Close() end)
end

function F:Run()
    if not self:IsShown() then return end
    local query = self.box:GetText() or ""
    self.results = F.Find(query, self.scope)
    self.offset = 0
    if self.scope and TG.db.threads[self.scope] then
        self.scopeText:SetText("In " .. (TG:ThreadDisplay(self.scope)))
        self.allLink:Show()
    else
        self.scope = nil
        self.scopeText:SetText("In all conversations")
        self.allLink:Hide()
    end
    local q = query:gsub("^%s+", ""):gsub("%s+$", "")
    if #q < 2 then
        self.count:SetText("")
        self.empty:SetText("Search your saved messages: names of items, places, anything someone wrote.")
    elseif #self.results == 0 then
        self.count:SetText("")
        self.empty:SetText("No messages with \"" .. esc(q) .. "\".")
    else
        local n = #self.results
        self.count:SetText(n >= MAX_RESULTS and ("Newest %d matches"):format(n)
            or ("%d match%s"):format(n, n == 1 and "" or "es"))
    end
    self:Fill()
end

function F:Fill()
    if not self:IsShown() then return end
    local visible = math.max(1, math.floor(num(self.list:GetHeight(), 300) / ROW_H))
    self.offset = math.max(0, math.min(self.offset or 0, #self.results - visible))
    for i = 1, visible do
        local row = self.rows[i] or createRow(self.list, i)
        self.rows[i] = row
        local r = self.results[i + self.offset]
        if r and TG.db.threads[r.key] then
            local th = TG.db.threads[r.key]
            local name, color = TG:ThreadDisplay(r.key)
            local who = r.out and "You" or ((th.kind == "GROUP" or th.kind == "CHANNEL") and r.from) or nil
            row.name:SetText(who and (name .. "  |cff8a7a5c" .. esc(who) .. "|r") or name)
            row.name:SetTextColor(color[1], color[2], color[3])
            row.time:SetText(r.t > 0 and (UI.ShortTime(r.t) .. (date("%Y-%m-%d", r.t) == date("%Y-%m-%d") and ""
                or ("  " .. date("%H:%M", r.t)))) or "")
            row.text:SetText(r.snippet)
            row.result = r
            row:Show()
        else
            row.result = nil
            row:Hide()
        end
    end
    for i = visible + 1, #self.rows do
        self.rows[i].result = nil
        self.rows[i]:Hide()
    end
    self.empty:SetShown(#self.results == 0)
end

function F:IsShown()
    return self.frame and self.frame:IsShown() or false
end

-- scope: a conversation key to search only that one, or nil for all. query: text to start with.
function F:Open(scope, query)
    UI:Show()
    UI:CloseOverlays()
    self:Create()
    self.scope = scope
    self.frame:Show()
    self.box:SetText(query or "")
    self.box:SetFocus()
    self:Run()
end

function F:Close()
    if not self:IsShown() then return end
    self.frame:Hide()
    self.box:ClearFocus()
end

function F:Toggle()
    if self:IsShown() then self:Close() else self:Open() end
end
