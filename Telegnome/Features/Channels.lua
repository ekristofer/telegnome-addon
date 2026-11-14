-- Telegnome: followed channels (guild, party, raid, say, General, Trade, custom channels...).
-- Messages are copied into the "Followed channels" tab and can be answered from there.
-- They stay in the main chat unless "Hide followed channels from the main chat" is on.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local C = { builtinChecks = {}, builtinNotify = {}, channelChecks = {}, channelNotify = {} }
TG.Channels = C

local BUILTIN = {
    { id = "GUILD", name = "Guild" },
    { id = "OFFICER", name = "Officer" },
    { id = "PARTY", name = "Party" },
    { id = "RAID", name = "Raid" },
    { id = "INSTANCE_CHAT", name = "Instance" },
    { id = "SAY", name = "Say" },
    { id = "YELL", name = "Yell" },
}
local BUILTIN_NAME = {}
for _, b in ipairs(BUILTIN) do BUILTIN_NAME[b.id] = b.name end

local EVENT_TYPE = {
    CHAT_MSG_GUILD = "GUILD",
    CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_RAID_WARNING = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_SAY = "SAY",
    CHAT_MSG_YELL = "YELL",
}

C.EVENTS = { CHAT_MSG_CHANNEL = true }
for ev in pairs(EVENT_TYPE) do C.EVENTS[ev] = true end

local function baseName(name)
    return name and (name:match("^(.-) %- ") or name) or "?"
end

function C.KeyForType(ctype)
    return "C:" .. ctype
end

function C.KeyForChannel(name)
    return "C:CH:" .. baseName(name):lower()
end

function C:IsFollowedKey(key)
    local th = TG.db.threads[key]
    return th and th.kind == "CHANNEL" or false
end

local function channelID(name)
    return tonumber((GetChannelName(name))) or 0
end

-- Chat color key (ChatTypeInfo) for a followed channel.
function C.ColorKey(th)
    if th.ctype == "CHANNEL" then
        local id = channelID(th.cname or "")
        return id > 0 and ("CHANNEL" .. id) or "CHANNEL"
    end
    return th.ctype or "SAY"
end

---------------------------------------------------------------------------
-- Follow / unfollow
---------------------------------------------------------------------------

function C:Follow(ctype, cname)
    local key, name
    if ctype == "CHANNEL" then
        name = baseName(cname)
        key = C.KeyForChannel(name)
    else
        name = BUILTIN_NAME[ctype] or ctype
        key = C.KeyForType(ctype)
    end
    if TG.db.threads[key] then return key end
    local th = TG:EnsureThread(key, { kind = "CHANNEL", name = name })
    th.ctype = ctype
    th.cname = (ctype == "CHANNEL") and name or nil
    th.notify = false -- pop-ups are chosen per channel
    th.msgs[#th.msgs + 1] = { t = time(), sys = true, text = "Following " .. name .. ". New messages will show up here." }
    UI:RefreshList()
    TG:RefreshUnread()
    return key
end

function C:Unfollow(key)
    if self:IsFollowedKey(key) then TG:DeleteThread(key) end
end

---------------------------------------------------------------------------
-- Events, sending, filtering
---------------------------------------------------------------------------

-- Alert words (Settings): a followed-channel message containing one pops up and plays the
-- sound even when that channel's Pop-up tick is off.
local kwSource, kwList
function C.MatchKeyword(text)
    local src = TG.db.settings.keywords or ""
    if src ~= kwSource then
        kwSource, kwList = src, {}
        for part in src:gmatch("[^,;]+") do
            local word = strtrim(part):lower()
            if #word >= 2 then kwList[#kwList + 1] = word end
        end
    end
    if #kwList == 0 or type(text) ~= "string" then return false end
    local lower = text:lower()
    for _, word in ipairs(kwList) do
        if lower:find(word, 1, true) then return true end
    end
    return false
end

function C:OnEvent(event, ...)
    local text, sender = ...
    local guid = select(12, ...)
    local key
    if event == "CHAT_MSG_CHANNEL" then
        local base = select(9, ...)
        if type(base) ~= "string" or TG.isSecret(base) then return end
        key = C.KeyForChannel(base)
    else
        key = C.KeyForType(EVENT_TYPE[event])
    end
    if not self:IsFollowedKey(key) then return end
    if TG.isSecret(text) or TG.isSecret(sender) or TG.isSecret(guid) then return end

    local outgoing = guid and guid == UnitGUID("player") or false
    local from = Ambiguate and Ambiguate(sender or "?", "short") or sender
    if event == "CHAT_MSG_RAID_WARNING" then text = "[Raid Warning] " .. text end
    TG:AddMessage(key, { kind = "CHANNEL" }, outgoing, text, {
        from = from, cls = TG:ClassFromGUID(guid), alert = (not outgoing) and C.MatchKeyword(text) or nil,
    })
end

function C:Send(th, text)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local t = th.ctype
    if t == "CHANNEL" then
        local id = channelID(th.cname or "")
        if id == 0 then
            TG:Print("You're not in the channel " .. (th.cname or "?") .. " right now.")
            return false
        end
        send(text, "CHANNEL", nil, id)
        return true
    end
    if (t == "GUILD" or t == "OFFICER") and IsInGuild and not IsInGuild() then
        TG:Print("You're not in a guild.")
        return false
    elseif t == "PARTY" and IsInGroup and not IsInGroup() then
        TG:Print("You're not in a party.")
        return false
    elseif t == "RAID" and IsInRaid and not IsInRaid() then
        TG:Print("You're not in a raid.")
        return false
    elseif t == "INSTANCE_CHAT" and IsInGroup and LE_PARTY_CATEGORY_INSTANCE
        and not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        TG:Print("You're not in an instance group.")
        return false
    end
    send(text, t)
    return true
end

function C:InstallChatFilter(add)
    local function filter(_, event, ...)
        if not (TG.db and TG.db.settings.hideChannels) then return false end
        -- Only hide what OnEvent can read and store.
        local msg, sender = ...
        if TG.isSecret(msg) or TG.isSecret(sender) or TG.isSecret((select(12, ...))) then return false end
        local key
        if event == "CHAT_MSG_CHANNEL" then
            local base = select(9, ...)
            if type(base) ~= "string" or TG.isSecret(base) then return false end
            key = C.KeyForChannel(base)
        else
            key = C.KeyForType(EVENT_TYPE[event])
        end
        return C:IsFollowedKey(key)
    end
    for ev in pairs(C.EVENTS) do add(ev, filter) end
end

function C:OpenMenu(key, anchor)
    local th = TG.db.threads[key]
    if not th then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(th.name)
        root:CreateCheckbox("Pop-up notifications",
            function() return th.notify and true or false end,
            function() th.notify = not th.notify end)
        root:CreateButton(th.muted and "Unmute" or "Mute (no pop-ups or sound, alert words included)", function()
            TG:SetMuted(key, not th.muted)
        end)
        root:CreateButton("Clear history", function() TG:ConfirmClearHistory(key) end)
        root:CreateButton("Unfollow channel", function() C:Unfollow(key) end)
        root:CreateButton("Choose channels...", function() C:OpenPanel() end)
    end)
end

---------------------------------------------------------------------------
-- Picker panel (opens over the conversation pane)
---------------------------------------------------------------------------

local ROW = 22
local NOTIFY_X_LEFT, NOTIFY_X_RIGHT = 122, 410

local function setNotify(key, on)
    local th = TG.db.threads[key]
    if th then th.notify = on and true or false end
end

local function notifyCheck(parent, x, y)
    local c = S.Check(parent, "")
    c:SetPoint("TOPLEFT", x, y)
    S.Tooltip(c, "Pop-up notifications",
        "Tick to get the on-screen notifier for this channel. Leave it off to only read it in the chat window.")
    return c
end

function C:CreatePanel()
    if self.panel then return end
    UI:Create()

    local f = CreateFrame("Frame", nil, UI.right, "BackdropTemplate")
    f:SetAllPoints(UI.right)
    f:SetFrameLevel(UI.right:GetFrameLevel() + 30)
    S.Inset(f)
    S.Solid(f)
    f:EnableMouse(true)
    f:Hide()
    self.panel = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("Followed channels")
    local cog = S.Cog(f, 18)
    cog:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -34)
    line:SetPoint("TOPRIGHT", -8, -34)

    local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 14, -42)
    intro:SetPoint("RIGHT", -14, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText("Tick a chat to follow it in this tab. Also tick Pop-up to get the notifier for it; otherwise it stays quiet.")

    local function header(text, x, popX)
        local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", x, -68)
        h:SetText(text)
        local p = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        p:SetPoint("TOP", f, "TOPLEFT", popX + 12, -70)
        p:SetText("Pop-up")
    end
    header("Chat types", 14, NOTIFY_X_LEFT)
    header("Your channels", 230, NOTIFY_X_RIGHT)

    for i, b in ipairs(BUILTIN) do
        local y = -86 - (i - 1) * ROW
        local c = S.Check(f, b.name)
        c:SetPoint("TOPLEFT", 12, y)
        c.ctype = b.id
        c:SetScript("OnClick", function(s)
            local key = C.KeyForType(b.id)
            if s:GetChecked() then C:Follow(b.id) else C:Unfollow(key) end
            C:RefreshPanel()
        end)
        self.builtinChecks[i] = c

        local n = notifyCheck(f, NOTIFY_X_LEFT, y)
        n:SetScript("OnClick", function(s) setNotify(C.KeyForType(b.id), s:GetChecked()) end)
        self.builtinNotify[i] = n
    end

    local none = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    none:SetPoint("TOPLEFT", 232, -90)
    none:SetText("You're not in any channels.")
    self.noneText = none

    -- Pinned to the bottom so a long "Your channels" column can't run into it.
    local h3 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h3:SetPoint("BOTTOMLEFT", 14, 66)
    h3:SetText("Options")
    local hide = S.Check(f, "Hide followed channels from the main chat")
    hide:SetPoint("BOTTOMLEFT", 12, 38)
    hide:SetScript("OnClick", function(s) TG.db.settings.hideChannels = s:GetChecked() and true or false end)
    S.Tooltip(hide, "Hide from main chat", "Messages in followed channels only show up in Telegnome. "
        .. "Followed channels never count towards the missed-messages counter.")
    self.hideCheck = hide

    local done = S.Button(f, "Close", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    done:SetScript("OnClick", function() C:ClosePanel() end)
end

local function setNotifyState(n, followed, key)
    local th = followed and TG.db.threads[key]
    n:SetChecked(th and th.notify and true or false)
    n:SetEnabled(followed and true or false)
    n:SetAlpha(followed and 1 or 0.4)
end

function C:RefreshPanel()
    if not self.panel then return end
    for i, c in ipairs(self.builtinChecks) do
        local key = C.KeyForType(c.ctype)
        local followed = self:IsFollowedKey(key)
        c:SetChecked(followed)
        setNotifyState(self.builtinNotify[i], followed, key)
    end

    -- Joined numbered channels (General, Trade, custom...), excluding Telegnome group channels.
    local list = { GetChannelList() }
    local names = {}
    for i = 1, #list, 3 do
        local name = list[i + 1]
        if type(name) == "string" and not TG.Groups.IsTelegnomeChannel(name) then
            names[#names + 1] = baseName(name)
        end
    end
    -- Also keep followed channels you're not currently in, so they can be unfollowed.
    local seen = {}
    for _, n in ipairs(names) do seen[n:lower()] = true end
    for _, th in pairs(TG.db.threads) do
        if th.kind == "CHANNEL" and th.ctype == "CHANNEL" and th.cname and not seen[th.cname:lower()] then
            names[#names + 1] = th.cname
            seen[th.cname:lower()] = true
        end
    end

    for i, name in ipairs(names) do
        local c = self.channelChecks[i]
        if not c then
            local y = -86 - (i - 1) * ROW
            c = S.Check(self.panel, "")
            c:SetPoint("TOPLEFT", 228, y)
            c.label:SetWidth(150)
            c.label:SetJustifyH("LEFT")
            c.label:SetWordWrap(false)
            c:SetScript("OnClick", function(s)
                if s:GetChecked() then C:Follow("CHANNEL", s.cname) else C:Unfollow(C.KeyForChannel(s.cname)) end
                C:RefreshPanel()
            end)
            self.channelChecks[i] = c

            local n = notifyCheck(self.panel, NOTIFY_X_RIGHT, y)
            n:SetScript("OnClick", function(s) setNotify(C.KeyForChannel(c.cname), s:GetChecked()) end)
            self.channelNotify[i] = n
        end
        c.cname = name
        c.label:SetText(name)
        local key = C.KeyForChannel(name)
        local followed = self:IsFollowedKey(key)
        c:SetChecked(followed)
        c:Show()
        setNotifyState(self.channelNotify[i], followed, key)
        self.channelNotify[i]:Show()
    end
    for i = #names + 1, #self.channelChecks do
        self.channelChecks[i]:Hide()
        self.channelNotify[i]:Hide()
    end
    self.noneText:SetShown(#names == 0)

    self.hideCheck:SetChecked(TG.db.settings.hideChannels)
end

function C:IsPanelShown()
    return self.panel and self.panel:IsShown() or false
end

function C:OpenPanel()
    UI:Show()
    UI:SetTab("channels")
    self:CreatePanel()
    TG.Settings:Close()
    TG.Picker:Close()
    TG.Groups:ClosePanel()
    TG.ChannelList:Close()
    TG.Requests:ClosePanel()
    self:RefreshPanel()
    self.panel:Show()
    UI.newBtn:SetText("Cancel")
end

function C:ClosePanel()
    if not self:IsPanelShown() then return end
    self.panel:Hide()
    UI:UpdateNewButton()
    if UI.frame:IsShown() then
        local key = UI.selected or UI:SortedKeys()[1]
        if key then UI:Select(key) end
    end
end

function C:TogglePanel()
    if self:IsPanelShown() then self:ClosePanel() else self:OpenPanel() end
end
