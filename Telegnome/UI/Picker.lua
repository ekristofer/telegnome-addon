-- Telegnome: the player search on New chat > Direct message.
--   Shows people you might want to whisper and don't have a conversation with yet: people you talked to in
--   the last two days, your group, friends, people you grouped with this week and guild members online.
--   A row of filters picks one kind; typing searches everyone (open conversations too). Typing a name nobody
--   matches offers to start a whisper to it.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local P = { rows = {}, offset = 0, results = {}, cat = "all" }
TG.Picker = P

local SEARCH_H = 28
local CHIPS_H = 30
local TOP = SEARCH_H + CHIPS_H
local RECENT_DAYS = 2

-- The filters along the top.
P.CATS = {
    { id = "all", label = "All", tip = "Everyone below who isn't in your chats yet. Offline friends are under Friends." },
    { id = "recent", label = "Recent", tip = "People you've talked to in the last two days." },
    { id = "group", label = "Group", tip = "Your group or raid right now." },
    { id = "friends", label = "Friends", tip = "Battle.net and character friends. Online first, offline last." },
    { id = "grouped", label = "Grouped", tip = "People you were in a group with this week." },
    { id = "guild", label = "Guild", tip = "Guild members who are online." },
}

function P:Create()
    if self.frame then return end
    UI:Create()

    -- placed inside New chat > Direct message by ShowIn
    local f = CreateFrame("Frame", nil, UI.frame)
    f:EnableMouse(true)
    f:SetScript("OnSizeChanged", function() P:Refresh() end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        P.offset = math.max(0, P.offset - delta * 2)
        P:Refresh()
    end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    S.Paint(bg, "paneltex")
    f:Hide()
    self.frame = f

    local search = TG.Style.EditBox(f, true)
    search:SetPoint("TOPLEFT", 2, 0)
    search:SetPoint("TOPRIGHT", -2, 0)
    search:SetHeight(24)
    search:SetMaxLetters(64)
    search:SetScript("OnTextChanged", function()
        P.offset = 0
        P:Refresh()
    end)
    search:SetScript("OnEnterPressed", function() P:ChooseFirst() end)
    search:SetScript("OnEscapePressed", function() TG.NewChat:Close() end)
    search:SetScript("OnEditFocusGained", function() P.placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function(s) P.placeholder:SetShown(s:GetText() == "") end)
    self.search = search

    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 24, 0)
    placeholder:SetText("Character name, BattleTag or friend")
    self.placeholder = placeholder

    -- filter chips: one kind of people at a time
    self.chips = {}
    local prev
    for _, c in ipairs(P.CATS) do
        local b = S.Button(f, c.label, 40, 22)
        b.fs:SetFontObject("GameFontNormalSmall")
        b:SetWidth(math.floor(S.Num(b.fs:GetStringWidth(), 30) + 18))
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 2, -SEARCH_H - 2) end
        local bar = b:CreateTexture(nil, "OVERLAY")
        bar:SetHeight(2)
        bar:SetPoint("BOTTOMLEFT", 2, 2)
        bar:SetPoint("BOTTOMRIGHT", -2, 2)
        bar:SetColorTexture(1, 0.82, 0, 1)
        b.bar = bar
        b.cat = c.id
        b:SetScript("OnClick", function() P.cat = c.id; P.offset = 0; P:Refresh() end)
        S.Tooltip(b, c.label, c.tip)
        self.chips[#self.chips + 1] = b
        prev = b
    end

    local none = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    none:SetPoint("TOPLEFT", 8, -TOP - 6)
    none:SetPoint("RIGHT", -8, 0)
    none:SetJustifyH("LEFT")
    self.none = none

    -- a thin scroll indicator at the right edge, shown when not everything fits
    local track = CreateFrame("Frame", nil, f)
    track:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -TOP)
    track:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 2)
    track:SetWidth(3)
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0, 0, 0, 0.35)
    local thumb = track:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(3)
    thumb:SetColorTexture(S.BRONZE[1], S.BRONZE[2], S.BRONZE[3], 0.9)
    track:Hide()
    self.track, self.thumb = track, thumb
end

---------------------------------------------------------------------------
-- Gathering people
---------------------------------------------------------------------------

-- Everyone worth listing, each person once, in this order: recent, group, online friends, grouped with,
-- guild, offline friends. Each entry has cat (its filter) and sub (the label on the right).
-- Without a search, people who already have a conversation are left out: they're in the list on the left.
function P:Gather(filter)
    filter = filter or ""
    local searching = filter ~= ""
    local out, seen, seenName = {}, {}, {}
    local exact = false
    local threads = TG.db.threads or {}
    local myName = UnitName and UnitName("player")
    local myRealm = GetNormalizedRealmName and GetNormalizedRealmName()
    local myKey = type(myName) == "string" and TG.FullName(myName) and TG.WhisperKey(TG.FullName(myName)) or nil
    -- never list yourself (your guild roster includes you)
    if type(myName) == "string" then seenName[myName:lower()] = true end

    local function add(key, info, match, cat, sub, shortMatch, offline)
        if seen[key] or key == myKey then return end
        local th = threads[key]
        local hasChat = th and not th.req
        if hasChat and not searching then return end
        local name, color, online = TG:DisplayFor(key, info)
        -- someone from another realm: show the realm too, so you know who it is
        if info.kind == "WHISPER" and type(info.name) == "string" and type(name) == "string" then
            local realm = info.name:match("%-([^%-]+)$")
            if realm and myRealm and realm:lower() ~= myRealm:lower() and not name:find("-", 1, true) then
                name = name .. "|cff8a7a5c-" .. realm .. "|r"
            end
        end
        local readable = type(name) == "string" and not name:find("|K", 1, true)
        local plainName = readable and name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower() or nil
        if searching then
            if not match:find(filter, 1, true) and not (plainName or ""):find(filter, 1, true) then return end
        end
        -- the same character twice (a contact and a guild member with the realm written differently): once
        local nameKey = (plainName and info.kind ~= "BN") and plainName:gsub("[%s%-']", "") or nil
        if nameKey and seenName[nameKey] then return end
        seen[key] = true
        if nameKey then seenName[nameKey] = true end
        if match == filter or shortMatch == filter then exact = true end
        out[#out + 1] = { key = key, info = info, name = name, color = color, online = online,
            sub = hasChat and "in your chats" or sub, cat = cat, offline = offline }
    end
    local function addName(fullName, cat, sub, class)
        if type(fullName) ~= "string" or fullName == "" or (TG.isSecret and TG.isSecret(fullName)) then return end
        local key, info = TG:WhisperInfo(fullName)
        if not key then return end
        info.class = info.class or class
        add(key, info, info.name:lower(), cat, sub, fullName:lower():match("^[^%-]+"))
    end
    local now = time()

    -- 1. People you've talked to in the last two days (when searching: anyone you've ever talked to)
    local recent = {}
    for key, c in pairs(TG.db.contacts or {}) do
        if (c.kind == "WHISPER" or c.kind == "BN") and (searching or now - (c.last or 0) < RECENT_DAYS * 86400) then
            recent[#recent + 1] = { key = key, c = c }
        end
    end
    table.sort(recent, function(a, b) return (a.c.last or 0) > (b.c.last or 0) end)
    for _, r in ipairs(recent) do
        local c = r.c
        local info = { kind = c.kind, name = c.name, battleTag = c.battleTag, class = c.class, guid = c.guid }
        local match = ((c.kind == "BN" and c.battleTag) or c.name or ""):lower()
        local short = (c.name or ""):lower():match("^[^%-#]+")
        local recentNow = now - (c.last or 0) < RECENT_DAYS * 86400
        add(r.key, info, match, recentNow and "recent" or "older", "talked " .. UI.ShortTime(c.last or now), short)
    end

    -- 2. Your group right now
    if IsInGroup and IsInGroup() then
        local raid = IsInRaid and IsInRaid()
        local n = raid and (GetNumGroupMembers and GetNumGroupMembers() or 0)
            or (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0)
        for i = 1, n do
            local unit = (raid and "raid" or "party") .. i
            local ok, name, realm = pcall(UnitName, unit)
            if ok and type(name) == "string" and name ~= myName and name ~= UNKNOWNOBJECT then
                local _, class = UnitClass(unit)
                addName((type(realm) == "string" and realm ~= "") and (name .. "-" .. realm:gsub("[%s%-]", "")) or name,
                    "group", "in your group", class)
            end
        end
    end

    -- 3. Friends who are online (Battle.net, then characters)
    local bnOnline, bnOffline = {}, {}
    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        for i = 1, (BNGetNumFriends() or 0) do
            local acct = C_BattleNet.GetFriendAccountInfo(i)
            if acct and acct.battleTag then
                local isOn = acct.gameAccountInfo and acct.gameAccountInfo.isOnline
                table.insert(isOn and bnOnline or bnOffline, acct)
            end
        end
    end
    local function addBN(list, offline)
        for _, acct in ipairs(list) do
            local key, info = TG:BNInfoFromAccount(acct)
            TG.bnIDs[key] = acct.bnetAccountID
            -- BattleTag, and the character they're playing if they're in WoW
            local g = acct.gameAccountInfo
            local char = g and type(g.characterName) == "string" and g.characterName or ""
            add(key, info, (acct.battleTag .. " " .. char):lower(), "friends",
                offline and "Battle.net, offline" or "Battle.net", acct.battleTag:lower():match("^[^#]+"), offline)
        end
    end
    local friendsOn, friendsOff = {}, {}
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, (C_FriendList.GetNumFriends() or 0) do
            local fi = C_FriendList.GetFriendInfoByIndex(i)
            if fi and fi.name then table.insert(fi.connected and friendsOn or friendsOff, fi) end
        end
    end
    local function addFriends(list, offline)
        for _, fi in ipairs(list) do
            local key, info = TG:WhisperInfo(fi.name, fi.guid)
            if key then
                add(key, info, info.name:lower(), "friends", offline and "friend, offline" or "friend",
                    fi.name:lower():match("^[^%-]+"), offline)
            end
        end
    end
    addBN(bnOnline)
    addFriends(friendsOn)

    -- 4. People you were in a group with this week
    local grouped = {}
    for key, t in pairs(TG.db.grouped or {}) do
        if type(t) == "number" and now - t < 7 * 86400 then grouped[#grouped + 1] = { key = key, t = t } end
    end
    table.sort(grouped, function(a, b) return a.t > b.t end)
    local ginfo = TG.db.groupedInfo or {}
    for _, g in ipairs(grouped) do
        local saved = ginfo[g.key]
        -- saved before 1.0: only the lowercase key is known, so guess the capitals
        local name = saved and saved.name or g.key:gsub("^W:", ""):gsub("^%l", string.upper)
            :gsub("%-(%l)", function(c) return "-" .. c:upper() end)
        addName(name, "grouped", "grouped " .. UI.ShortTime(g.t), saved and saved.class)
    end

    -- 5. Guild members online
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        local total = GetNumGuildMembers() or 0
        for i = 1, math.min(total, 1000) do
            local name, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
            if online and type(name) == "string" then
                addName(name, "guild", "guild", class)
            end
        end
    end

    -- 6. Friends who are offline (last)
    addBN(bnOffline, true)
    addFriends(friendsOff, true)

    -- 7. Start a whisper to whatever was typed
    if searching and not exact and not filter:find("#", 1, true) and not filter:find("%s") then
        local typed = strtrim(self.search and self.search:GetText() or filter):gsub("^%l", string.upper)
        local key, info = TG:WhisperInfo(typed)
        if key and not seen[key] then
            out[#out + 1] = { key = key, info = info, name = "Whisper " .. typed, color = { 1, 0.82, 0 },
                sub = "new", cat = "new" }
        end
    end

    return out
end

-- The entries the chosen filter shows. All leaves out offline friends, unless you're searching.
function P:Filtered(all, searching)
    local out = {}
    for _, e in ipairs(all) do
        local keep
        if e.cat == "new" then keep = true
        elseif self.cat == "all" then keep = searching or not e.offline
        elseif self.cat == "recent" then keep = e.cat == "recent" or (searching and e.cat == "older")
        else keep = e.cat == self.cat end
        if keep then out[#out + 1] = e end
    end
    return out
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------

function P:GetRow(i)
    local row = self.rows[i]
    if row then return row end
    row = UI:MakeRow(self.frame, -TOP, i)
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", -10, 0)
    row.right:SetFontObject("GameFontDisableSmall")
    row:SetScript("OnClick", function(s, button)
        local e = s.entry
        if not e then return end
        -- Right-click someone you've talked to: take them off this list.
        if button == "RightButton" then
            if TG.db.contacts[e.key] and MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(s, function(_, root)
                    root:CreateTitle(e.name)
                    root:CreateButton("Forget contact", function() TG:ForgetContact(e.key) end)
                end)
            end
            return
        end
        P:Choose(e)
    end)
    self.rows[i] = row
    return row
end

P.NONE = {
    all = "Nobody new to show. Type a character name and press Enter to whisper anyone.",
    recent = "Nobody from the last two days who isn't already in your chats.",
    group = "You're not in a group, or everyone in it is already in your chats.",
    friends = "No friends to show: they're all in your chats already.",
    grouped = "Nobody you grouped with this week who isn't already in your chats.",
    guild = "No guild members online who aren't already in your chats.",
}

function P:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local filter = strtrim(self.search:GetText() or ""):lower()
    local results = self:Filtered(self:Gather(filter), filter ~= "")
    self.results = results

    for _, b in ipairs(self.chips or {}) do
        local on = b.cat == self.cat
        b.bar:SetShown(on)
        if on then b.fs:SetTextColor(1, 0.95, 0.8) else b.fs:SetTextColor(0.62, 0.57, 0.48) end
    end

    -- right after the page opens the game may not have sized the frame yet: assume a full page then
    local fh = S.Num(self.frame:GetHeight(), 0)
    if fh < TOP + UI.ROW_H then fh = 360 end
    local h = fh - TOP
    local visible = math.max(1, math.floor(h / UI.ROW_H))
    local maxOffset = math.max(0, #results - visible)
    self.offset = math.min(self.offset, maxOffset)
    self.none:SetText(filter ~= "" and "Nobody matches here. Try All, or press Enter to whisper that name."
        or P.NONE[self.cat] or "")
    self.none:SetShown(#results == 0)

    for i = 1, visible do
        local row = self:GetRow(i)
        local e = results[i + self.offset]
        if e then
            row.entry = e
            UI.SetRowContact(row, e.name, e.color, e.online)
            row.right:SetText(e.sub or "")
            row:SetSelected(i + self.offset == 1 and filter ~= "") -- Enter picks this one
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end
    for i = visible + 1, #self.rows do
        self.rows[i].entry = nil
        self.rows[i]:Hide()
    end

    if maxOffset > 0 then
        local trackH = S.Num(self.track:GetHeight(), 0)
        if trackH < 20 then trackH = h end
        local th = math.max(16, trackH * visible / #results)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(self.offset / maxOffset) * (trackH - th))
        self.thumb:SetHeight(th)
        self.track:Show()
    else
        self.track:Hide()
    end
end

function P:Choose(entry)
    TG.NewChat:Close(true)
    TG:OpenConversation(entry.key, entry.info)
end

function P:ChooseFirst()
    local first = self.results[1]
    if first and strtrim(self.search:GetText() or "") ~= "" then
        self:Choose(first)
    end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- New chat > Direct message.
function P:Open()
    TG.NewChat:Open("dm")
end

-- Called by the New chat page: the search fills `area`.
function P:ShowIn(area)
    self:Create()
    self.frame:SetParent(area)
    self.frame:ClearAllPoints()
    self.frame:SetAllPoints(area)
    self.frame:SetFrameLevel(area:GetFrameLevel() + 2)
    self.offset = 0
    self.cat = "all"
    self.frame:Show()
    self.search:SetText("")
    self.placeholder:Hide()
    self.search:SetFocus()
    self:Refresh()
    C_Timer.After(0, function() P:Refresh() end) -- once the frame has its size
end

function P:Close()
    if not self.frame then return end
    self.frame:Hide()
    self.search:ClearFocus()
end

function P:Toggle()
    if self.frame and self.frame:IsShown() then TG.NewChat:Close() else self:Open() end
end
