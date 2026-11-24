-- Telegnome: the player search on New chat > Direct message. Lists remembered contacts, Battle.net friends
-- and character friends, with a search box. Typing an unknown name starts a whisper to it.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local P = { rows = {}, offset = 0, results = {} }
TG.Picker = P

local SEARCH_H = 28

function P:Create()
    if self.frame then return end
    UI:Create()

    -- placed inside New chat > Direct message by ShowIn
    local f = CreateFrame("Frame", nil, UI.frame)
    f:EnableMouse(true)
    f:SetScript("OnSizeChanged", function() P:Refresh() end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        P.offset = math.max(0, P.offset - delta)
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

    local none = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    none:SetPoint("TOPLEFT", 8, -SEARCH_H - 6)
    none:SetPoint("RIGHT", -8, 0)
    none:SetJustifyH("LEFT")
    none:SetText("No contacts yet. Type a character name and press Enter.")
    self.none = none
end

---------------------------------------------------------------------------
-- Gathering contacts
---------------------------------------------------------------------------

function P:Gather(filter)
    local out, seen = {}, {}
    local exact = false

    local function add(key, info, match, sub, shortMatch)
        if seen[key] then return end
        local name, color, online = TG:DisplayFor(key, info)
        if filter ~= "" then
            -- the name you see too, when the game lets addons read it (Battle.net real names it doesn't)
            local shown = (type(name) == "string" and not name:find("|K", 1, true)) and name:lower() or ""
            if not match:find(filter, 1, true) and not shown:find(filter, 1, true) then return end
        end
        seen[key] = true
        if match == filter or shortMatch == filter then exact = true end
        out[#out + 1] = { key = key, info = info, name = name, color = color, online = online, sub = sub }
    end

    local function addName(fullName, sub, class)
        if type(fullName) ~= "string" or fullName == "" or (TG.isSecret and TG.isSecret(fullName)) then return end
        local key, info = TG:WhisperInfo(fullName)
        if not key then return end
        info.class = info.class or class
        add(key, info, info.name:lower(), sub, fullName:lower():match("^[^%-]+"))
    end
    local myName = UnitName and UnitName("player")

    -- 1. People you've talked to, most recent first (people only: no channels or groups)
    local recent = {}
    for key, c in pairs(TG.db.contacts) do
        if c.kind == "WHISPER" or c.kind == "BN" then recent[#recent + 1] = { key = key, c = c } end
    end
    table.sort(recent, function(a, b) return (a.c.last or 0) > (b.c.last or 0) end)
    for _, r in ipairs(recent) do
        local c = r.c
        local info = { kind = c.kind, name = c.name, battleTag = c.battleTag, class = c.class, guid = c.guid }
        local match = ((c.kind == "BN" and c.battleTag) or c.name or ""):lower()
        local short = (c.name or ""):lower():match("^[^%-#]+")
        add(r.key, info, match, "recent", short)
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
                    "in your group", class)
            end
        end
    end

    -- 3. Battle.net friends and character friends who are online
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
    local function addBN(list)
        for _, acct in ipairs(list) do
            local key, info = TG:BNInfoFromAccount(acct)
            TG.bnIDs[key] = acct.bnetAccountID
            -- BattleTag, and the character they're playing if they're in WoW
            local g = acct.gameAccountInfo
            local char = g and type(g.characterName) == "string" and g.characterName or ""
            add(key, info, (acct.battleTag .. " " .. char):lower(), "Battle.net", acct.battleTag:lower():match("^[^#]+"))
        end
    end
    local friendsOn, friendsOff = {}, {}
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, (C_FriendList.GetNumFriends() or 0) do
            local fi = C_FriendList.GetFriendInfoByIndex(i)
            if fi and fi.name then table.insert(fi.connected and friendsOn or friendsOff, fi) end
        end
    end
    local function addFriends(list)
        for _, fi in ipairs(list) do
            local key, info = TG:WhisperInfo(fi.name, fi.guid)
            if key then add(key, info, info.name:lower(), "friend", fi.name:lower():match("^[^%-]+")) end
        end
    end
    addBN(bnOnline)
    addFriends(friendsOn)

    -- 4. People you were in a group with this week
    local grouped = {}
    for key, t in pairs(TG.db.grouped or {}) do
        if type(t) == "number" and time() - t < 7 * 86400 then grouped[#grouped + 1] = { key = key, t = t } end
    end
    table.sort(grouped, function(a, b) return a.t > b.t end)
    for _, g in ipairs(grouped) do
        local name = g.key:gsub("^W:", ""):gsub("^%l", string.upper):gsub("%-(%l)", function(c) return "-" .. c:upper() end)
        addName(name, "grouped " .. UI.ShortTime(g.t))
    end

    -- 5. Guild members online
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        local total = GetNumGuildMembers() or 0
        for i = 1, math.min(total, 1000) do
            local name, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
            if online and type(name) == "string" and Ambiguate and Ambiguate(name, "short") ~= myName then
                addName(name, "guild", class)
            end
        end
    end

    -- 6. Everyone else on your friends lists (offline)
    addBN(bnOffline)
    addFriends(friendsOff)

    -- 4. Start a whisper to whatever was typed
    if filter ~= "" and not exact and not filter:find("#", 1, true) and not filter:find("%s") then
        local typed = strtrim(self.search:GetText()):gsub("^%l", string.upper)
        local key, info = TG:WhisperInfo(typed)
        if key and not seen[key] then
            out[#out + 1] = { key = key, info = info, name = "Whisper " .. typed, color = { 1, 0.82, 0 }, sub = "new" }
        end
    end

    return out
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------

function P:GetRow(i)
    local row = self.rows[i]
    if row then return row end
    row = UI:MakeRow(self.frame, -SEARCH_H, i)
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", -6, 0)
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

function P:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local filter = strtrim(self.search:GetText() or ""):lower()
    local results = self:Gather(filter)
    self.results = results

    -- right after the page opens the game may not have sized the frame yet: assume a full page then
    local fh = S.Num(self.frame:GetHeight(), 0)
    if fh < SEARCH_H + UI.ROW_H then fh = 360 end
    local h = fh - SEARCH_H
    local visible = math.max(1, math.floor(h / UI.ROW_H))
    self.offset = math.min(self.offset, math.max(0, #results - visible))
    self.none:SetShown(#results == 0 and filter == "")

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
