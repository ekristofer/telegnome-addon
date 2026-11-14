-- Telegnome: "New message" picker. Lists remembered contacts, Battle.net friends
-- and character friends, with a search box. Typing an unknown name starts a whisper to it.

local _, ns = ...
local TG = ns.TG
local UI = TG.UI
local P = { rows = {}, offset = 0, results = {} }
TG.Picker = P

local SEARCH_H = 28

function P:Create()
    if self.frame then return end
    UI:Create()

    local f = CreateFrame("Frame", nil, UI.frame)
    f:SetPoint("TOPLEFT", UI.list, "TOPLEFT", 0, 0)
    f:SetPoint("BOTTOMRIGHT", UI.list, "BOTTOMRIGHT", 0, 0)
    f:SetFrameLevel(UI.list:GetFrameLevel() + 20)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        P.offset = math.max(0, P.offset - delta)
        P:Refresh()
    end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.11, 0.08, 0.05, 1)
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
    search:SetScript("OnEscapePressed", function() P:Close() end)
    search:SetScript("OnEditFocusGained", function() P.placeholder:Hide() end)
    search:SetScript("OnEditFocusLost", function(s) P.placeholder:SetShown(s:GetText() == "") end)
    self.search = search

    local placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 24, 0)
    placeholder:SetText("Name or BattleTag")
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
        if filter ~= "" and not match:find(filter, 1, true) then return end
        seen[key] = true
        if match == filter or shortMatch == filter then exact = true end
        local name, color, online = TG:DisplayFor(key, info)
        out[#out + 1] = { key = key, info = info, name = name, color = color, online = online, sub = sub }
    end

    -- 1. People you've talked to, most recent first
    local recent = {}
    for key, c in pairs(TG.db.contacts) do recent[#recent + 1] = { key = key, c = c } end
    table.sort(recent, function(a, b) return (a.c.last or 0) > (b.c.last or 0) end)
    for _, r in ipairs(recent) do
        local c = r.c
        local info = { kind = c.kind, name = c.name, battleTag = c.battleTag, class = c.class, guid = c.guid }
        local match = ((c.kind == "BN" and c.battleTag) or c.name or ""):lower()
        local short = (c.name or ""):lower():match("^[^%-#]+")
        add(r.key, info, match, "recent", short)
    end

    -- 2. Battle.net friends, online first
    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local online, offline = {}, {}
        for i = 1, (BNGetNumFriends() or 0) do
            local a = C_BattleNet.GetFriendAccountInfo(i)
            if a and a.battleTag then
                local isOn = a.gameAccountInfo and a.gameAccountInfo.isOnline
                table.insert(isOn and online or offline, a)
            end
        end
        for _, list in ipairs({ online, offline }) do
            for _, a in ipairs(list) do
                local key, info = TG:BNInfoFromAccount(a)
                TG.bnIDs[key] = a.bnetAccountID
                add(key, info, a.battleTag:lower(), "Battle.net", a.battleTag:lower():match("^[^#]+"))
            end
        end
    end

    -- 3. Character friends
    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, (C_FriendList.GetNumFriends() or 0) do
            local fi = C_FriendList.GetFriendInfoByIndex(i)
            if fi and fi.name then
                local key, info = TG:WhisperInfo(fi.name, fi.guid)
                if key then
                    add(key, info, info.name:lower(), "friend", fi.name:lower():match("^[^%-]+"))
                end
            end
        end
    end

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

    local h = (self.frame:GetHeight() or 0) - SEARCH_H
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
            row.sel:SetShown(i + self.offset == 1 and filter ~= "") -- Enter picks this one
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
    self:Close()
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

function P:Open()
    if UI.tab ~= "dm" then UI:SetTab("dm") end
    self:Create()
    TG.Settings:Close()
    TG.Groups:ClosePanel()
    TG.Channels:ClosePanel()
    TG.ChannelList:Close()
    self.offset = 0
    self.frame:Show()
    self.search:SetText("")
    self.placeholder:Hide()
    self.search:SetFocus()
    UI.newBtn:SetText("Cancel")
    self:Refresh()
end

function P:Close()
    if not self.frame then return end
    self.frame:Hide()
    self.search:ClearFocus()
    UI:UpdateNewButton()
end

function P:Toggle()
    if self.frame and self.frame:IsShown() then self:Close() else self:Open() end
end
