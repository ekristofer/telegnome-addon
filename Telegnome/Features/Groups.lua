-- Telegnome: group chats.
--
-- A group is a hidden, password-protected custom chat channel. People share a friendly
-- invite code ("sprocket-whistle-gizmo-42"); Telegnome hashes the code into the real
-- channel name ("TGN3fa91c0b7e2d") and its password, so nobody needs to see or type them,
-- and a random player can't stumble into the channel.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local G = {}
TG.Groups = G

G.EVENTS = {
    CHAT_MSG_CHANNEL = true, PLAYER_ENTERING_WORLD = true, CHANNEL_UI_UPDATE = true,
    CHAT_MSG_CHANNEL_JOIN = true, CHAT_MSG_CHANNEL_LEAVE = true, CHAT_MSG_CHANNEL_LIST = true,
}

local WORDS = {
    "cog", "gear", "sprocket", "gizmo", "widget", "rivet", "piston", "valve",
    "spring", "bolt", "gadget", "wrench", "spanner", "dynamo", "turbine", "boiler",
    "steam", "copper", "brass", "tinker", "fizzle", "sparkle", "whistle", "rocket",
    "mekka", "flux", "coil", "lever", "pulley", "crank", "gauge", "nozzle",
    "socket", "magnet", "circuit", "fuse", "spark", "thruster", "propeller", "gyro",
    "chrono", "zapper", "beacon", "goggles", "gnome", "kharanos", "morogh", "snowfall",
    "pretzel", "cogwheel", "clockwork", "doodad", "whirligig", "contraption", "blueprint", "schematic",
    "toolbox", "hammer", "anvil", "furnace", "gasket", "ratchet", "bellows", "dial",
}

-- Everything shared in chat carries "Telegnome code: <code>", which the receiving addon picks up.
G.CODE_TAG = "Telegnome code: "
local INVITE_FMT = 'Join my group chat "%s" - Telegnome code: %s'
local PENDING_MAX_AGE = 48 * 3600

---------------------------------------------------------------------------
-- Codes and hashing
---------------------------------------------------------------------------

-- 32-bit hashing done in 16-bit halves so every step stays exact in Lua's doubles.
local TWO32 = 4294967296

local function mul32(a, b)
    local ah, al = math.floor(a / 65536), a % 65536
    local bh, bl = math.floor(b / 65536), b % 65536
    return (((ah * bl + al * bh) % 65536) * 65536 + al * bl) % TWO32
end

local function mix(h)
    for _ = 1, 3 do
        h = (mul32(h, 2654435761) + math.floor(h / 65536) * 40503) % TWO32
    end
    return h
end

local function hash(str, seed, mult)
    local h = seed
    for i = 1, #str do
        h = mul32((h + str:byte(i) * 257) % TWO32, mult)
    end
    return mix((h + #str) % TWO32)
end

local function hex8(h)
    return ("%04x%04x"):format(math.floor(h / 65536), h % 65536)
end

function G.NormalizeCode(code)
    local c = strtrim(code or ""):lower()
    c = c:gsub("[%s_]+", "-"):gsub("[^%w%-]", ""):gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
    return c
end

-- invite code -> normalized code, channel name, channel password
function G.Derive(code)
    local c = G.NormalizeCode(code)
    local channel = "TGN" .. hex8(hash(c, 2166136261, 16777619)) .. hex8(hash(c, 52711, 2246822519)):sub(1, 4)
    local pass = hex8(hash(c, 7919, 3266489917))
    return c, channel, pass
end

-- New invite code, seeded from the date and time (down to the millisecond), your character
-- and the random generator, so two codes made anywhere, at any time, won't line up.
function G.NewCode(salt)
    local seed = table.concat({
        date and date("%Y%m%d%H%M%S") or "", ("%.3f"):format(GetTime and GetTime() or 0),
        tostring(UnitGUID and UnitGUID("player") or ""), tostring(math.random(1, 2147483646)), tostring(salt or ""),
    }, "|")
    local h = hash(seed, 2166136261, 16777619)
    local function pick(n)
        h = mix((h + 2654435769) % TWO32)
        return h % n
    end
    local w1, w2, w3 = WORDS[pick(#WORDS) + 1], WORDS[pick(#WORDS) + 1], WORDS[pick(#WORDS) + 1]
    return ("%s-%s-%s-%d"):format(w1, w2, w3, 100 + pick(900))
end

-- Finds "Telegnome code: <code>" anywhere in a message (any letter case). Also returns the
-- group name when the message is a Telegnome invite ('... group chat "Raid night" - Telegnome code: ...').
function G.FindCode(text)
    if type(text) ~= "string" then return nil end
    local code = text:lower():match("telegnome code:%s*([%w%-]+)")
    if not code then
        -- invites sent by Telegnome 0.4-0.5
        local _, old = text:match('^%[Telegnome%] Join my group chat "(.-)" %- code: (%S+)')
        code = old
    end
    if not code then return nil end
    code = G.NormalizeCode(code)
    if #code < 6 then return nil end
    local name = text:match('group chat "(.-)"')
    if name then name = strtrim((name:gsub("|", ""))) end
    if name == "" then name = nil end
    return code, name
end

-- A message with a Telegnome code, or just a bare code (typed or pasted into the code box).
function G.ParseInviteAny(text)
    if type(text) ~= "string" then return nil end
    text = strtrim(text)
    local code, name = G.FindCode(text)
    if code then return code, name end
    local bare = text:match("^(%a+%-%a+%-%a+%-%d+)$")
    if bare then return bare:lower(), nil end
    return nil
end

function G.KeyFor(channel)
    return "G:" .. channel:lower()
end

-- Telegnome group channels are "TGN" + 12 hex digits.
function G.IsTelegnomeChannel(name)
    return type(name) == "string" and #name == 15 and name:lower():match("^tgn%x+$") ~= nil
end

function G.ParseInvite(text)
    return G.FindCode(text)
end

---------------------------------------------------------------------------
-- Channels
---------------------------------------------------------------------------

local function channelID(channel)
    local id = GetChannelName and GetChannelName(channel)
    return tonumber(id) or 0
end

function G:HideFromChatFrames(channel)
    local remove = ChatFrame_RemoveChannel or (ChatFrameUtil and ChatFrameUtil.RemoveChannel)
    if not remove then return end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then pcall(remove, cf, channel) end
    end
end

function G:JoinChannel(th)
    if not th.channel or not th.pass or channelID(th.channel) > 0 then return end
    -- Temporary: left automatically at logout, so nothing lingers if Telegnome is disabled.
    local join = JoinTemporaryChannel or JoinChannelByName
    if not join then return end
    join(th.channel, th.pass)
    C_Timer.After(1, function() G:HideFromChatFrames(th.channel) end)
    C_Timer.After(4, function()
        if TG.db.threads[G.KeyFor(th.channel)] and channelID(th.channel) == 0 then
            TG:Print(("Couldn't join the group \"%s\". You might be in too many chat channels (the game allows 10)."):format(th.name))
        end
    end)
end

function G:RejoinAll()
    for _, th in pairs(TG.db.threads) do
        if th.kind == "GROUP" then self:JoinChannel(th) end
    end
end

function G:Send(th, text)
    local id = channelID(th.channel)
    if id == 0 then
        if not th.pass then
            TG:Print("You're no longer in that channel, and without its invite code Telegnome can't rejoin it.")
            return false
        end
        self:JoinChannel(th)
        TG:Print("Reconnecting to the group - try again in a moment.")
        return false
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    send(text, "CHANNEL", nil, id)
    return true -- our own message comes back through CHAT_MSG_CHANNEL
end

function G:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local initial, reload = ...
        -- Wait so General/Trade get their usual channel numbers first.
        if initial or reload then
            C_Timer.After(initial and 10 or 3, function() G:RejoinAll() end)
            C_Timer.After(initial and 16 or 8, function() G:ScanChannels(true) end)
        end
        return
    elseif event == "CHANNEL_UI_UPDATE" then
        if not self.scanQueued then
            self.scanQueued = true
            C_Timer.After(1, function()
                self.scanQueued = false
                G:ScanChannels()
                if TG.ChannelList then TG.ChannelList:Refresh() end
            end)
        end
        return
    end

    local text, sender = ...
    local base = select(9, ...)
    local guid = select(12, ...)
    if TG.isSecret(text) or TG.isSecret(sender) or TG.isSecret(base) or TG.isSecret(guid) then return end

    if event == "CHAT_MSG_CHANNEL_LIST" then
        self:OnMemberList(text)
        return
    end
    if type(base) ~= "string" then return end
    if event == "CHAT_MSG_CHANNEL_JOIN" or event == "CHAT_MSG_CHANNEL_LEAVE" then
        -- Group channels are left at logout, so this is also "came online" / "went offline".
        local jkey = G.KeyFor(base)
        if TG.db.threads[jkey] and TG.db.settings.groupJoinLeave and type(sender) == "string" and sender ~= "" then
            local who = Ambiguate and Ambiguate(sender, "short") or sender
            if not (type(guid) == "string" and guid == UnitGUID("player")) and who ~= UnitName("player") then
                TG:AddSystemLine(jkey, who .. (event == "CHAT_MSG_CHANNEL_JOIN" and " joined." or " left."))
            end
        end
        return
    end
    local key = G.KeyFor(base)
    if not TG.db.threads[key] then
        if not G.IsTelegnomeChannel(base) or not self:Adopt(base) then return end
    end

    local outgoing
    if type(guid) == "string" and guid ~= "" then
        outgoing = guid == UnitGUID("player")
    else
        outgoing = Ambiguate and Ambiguate(sender or "", "short") == UnitName("player") or false
    end
    local from = Ambiguate and Ambiguate(sender or "?", "short") or sender
    TG:AddMessage(key, { kind = "GROUP" }, outgoing, text, { from = from, cls = TG:ClassFromGUID(guid) })
end

function G:InstallChatFilter(add)
    local function filter(_, _, ...)
        local msg, sender = ...
        local base = select(9, ...)
        if TG.isSecret(msg) or TG.isSecret(sender) or TG.isSecret((select(12, ...))) then return false end
        if type(base) == "string" and not TG.isSecret(base) and TG.db
            and (TG.db.threads[G.KeyFor(base)] or G.IsTelegnomeChannel(base)) then
            return true
        end
        return false
    end
    for _, ev in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER",
        "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
        add(ev, filter)
    end
    -- The member list Telegnome asked for goes to the conversation, not the main chat.
    add("CHAT_MSG_CHANNEL_LIST", function()
        local lp = G.listPending
        return lp ~= nil and GetTime() - lp.t < 3
    end)
end

---------------------------------------------------------------------------
-- Who's online in a group
---------------------------------------------------------------------------

-- Asks the game who is in the group's channel. Members are only in it while they're
-- online, so this is the list of who is around right now.
function G:RequestMembers(key)
    local th = TG.db.threads[key]
    if not th or not th.channel then return end
    if channelID(th.channel) == 0 then
        TG:Print("You're not connected to that group right now.")
        return
    end
    local list = ListChannelByName or (C_ChatInfo and C_ChatInfo.ListChannelByName)
    if not list then
        TG:Print("This version of the game can't list who is in a channel.")
        return
    end
    local pending = { key = key, t = GetTime(), names = {}, seen = {} }
    self.listPending = pending
    list(th.channel)
    C_Timer.After(1.2, function()
        if G.listPending == pending then G:ShowMembers() end
    end)
end

-- One or more "Name, *Owner, @Moderator" lines in answer to RequestMembers.
function G:OnMemberList(text)
    local lp = self.listPending
    if not lp or GetTime() - lp.t > 3 or type(text) ~= "string" then return end
    for token in text:gmatch("[^,%s]+") do
        local name = token:gsub("^[%*@%+]+", "")
        name = Ambiguate and Ambiguate(name, "short") or name
        if name ~= "" and not name:find("[%[%]%.:]") and not lp.seen[name] then
            lp.seen[name] = true
            lp.names[#lp.names + 1] = name
        end
    end
end

function G:ShowMembers()
    local lp = self.listPending
    self.listPending = nil
    if not lp then return end
    local text
    if #lp.names == 0 then
        text = "Couldn't get the list of who is online."
    else
        table.sort(lp.names)
        text = ("Online now (%d): %s"):format(#lp.names, table.concat(lp.names, ", "))
    end
    if not UI:ShowNote(lp.key, text) then TG:Print(text) end
end

---------------------------------------------------------------------------
-- Create / join / leave / invite
---------------------------------------------------------------------------

local function systemLine(th, text)
    th.msgs[#th.msgs + 1] = { t = time(), sys = true, text = text }
end

function G:Join(code, name, created)
    local pcode, pname = G.ParseInviteAny(code)
    if pcode then
        code = pcode
        if not name or name == "" then name = pname end
    end
    local c, channel, pass = G.Derive(code)
    if #c < 6 then
        TG:Print("That invite code looks too short.")
        return nil
    end
    local key = G.KeyFor(channel)
    local th = TG.db.threads[key]
    if not th then
        name = TG.Utf8Left(strtrim(((name or ""):gsub("|", ""))), 40)
        if name == "" then name = "Group " .. (c:match("^[^%-]+") or c) end
        th = TG:EnsureThread(key, { kind = "GROUP", name = name, code = c, channel = channel, pass = pass })
        if created then
            systemLine(th, "Group created. " .. G.CODE_TAG .. c .. " - right-click the group name to invite people.")
        else
            systemLine(th, "You joined the group.")
        end
    end
    if th.unknown then -- a channel we found earlier, now with its code
        th.unknown, th.code, th.pass = nil, c, pass
        name = strtrim(((name or ""):gsub("|", "")))
        if name ~= "" then th.name = TG.Utf8Left(name, 40) end
        systemLine(th, "Invite code added - Telegnome knows this group now.")
    end
    local p = TG.db.pendingInvite
    if p and p.code == c then TG.db.pendingInvite = nil end
    self:JoinChannel(th)
    self:ClosePanel()
    UI:Show()
    UI:Select(key)
    return key, th
end

function G:Create(name)
    name = strtrim(((name or ""):gsub("|", "")))
    if name == "" then name = "Group chat" end
    local code = G.NewCode()
    for i = 1, 5 do -- never hand out a code for a group you're already in
        if not TG.db.threads[G.KeyFor(select(2, G.Derive(code)))] then break end
        code = G.NewCode(i)
    end
    local key = self:Join(code, name, true)
    if key then self:ShowCode(key) end
    return key
end

function G:Rename(key, name)
    local th = TG.db.threads[key]
    if not th or th.kind ~= "GROUP" then return end
    name = strtrim(((name or ""):gsub("|", "")))
    if name == "" then return end
    th.name = TG.Utf8Left(name, 40)
    UI:RefreshList()
    if UI.selected == key then UI:Select(key) end
end

---------------------------------------------------------------------------
-- Telegnome channels Telegnome doesn't know about
---------------------------------------------------------------------------

-- Every chat channel the character is in: { id, name, disabled, community }.
function G.ChannelList()
    local out = {}
    if not GetChannelList then return out end
    local raw = { GetChannelList() }
    for i = 1, #raw, 3 do
        local id, name, disabled = raw[i], raw[i + 1], raw[i + 2]
        if type(id) == "number" and type(name) == "string" then
            local community = select(4, GetChannelName(id))
            out[#out + 1] = { id = id, name = name, disabled = disabled and true or false, community = community and true or false }
        end
    end
    return out
end

-- A Telegnome channel with no group behind it (made on another computer, or the saved
-- data was reset): list it under Group chats so it can be seen, renamed or left.
G.leftAt = {}

-- Remember channels we just left, so the leave isn't mistaken for an unknown channel.
function G:NoteLeft(channel)
    if channel then self.leftAt[channel:lower()] = GetTime() end
end

function G:Adopt(channel)
    local key = G.KeyFor(channel)
    if TG.db.threads[key] then return key end
    local left = self.leftAt[channel:lower()]
    if left and GetTime() - left < 30 then return nil end
    local th = TG:EnsureThread(key, { kind = "GROUP", name = "Unknown group", channel = channel })
    th.unknown = true
    systemLine(th, "Telegnome found this group chat channel but doesn't know its name or invite code. "
        .. "Rename it, enter its invite code (right-click), or leave it.")
    self:HideFromChatFrames(channel)
    TG:Print("Found a Telegnome group chat channel it didn't know about - it's listed under Group chats as \"Unknown group\".")
    UI:RefreshList()
    return key
end

-- Finds unknown Telegnome channels. After login, unknown groups whose channel is gone are
-- removed (without the code there's no way back in).
function G:ScanChannels(afterLogin)
    if not TG.db then return end
    local present = {}
    for _, ch in ipairs(G.ChannelList()) do
        if G.IsTelegnomeChannel(ch.name) then
            present[G.KeyFor(ch.name)] = true
            if not TG.db.threads[G.KeyFor(ch.name)] then self:Adopt(ch.name) end
        end
    end
    if afterLogin then
        for key, th in pairs(TG.db.threads) do
            if th.kind == "GROUP" and th.unknown and not present[key] then TG:DeleteThread(key) end
        end
    end
end

---------------------------------------------------------------------------
-- Picking up codes from chat
---------------------------------------------------------------------------

-- Chat you can receive a code in. Your own messages are ignored.
local SCAN_EVENTS = {
    "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_SAY",
    "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL",
}
local SCAN_WHERE = {
    CHAT_MSG_WHISPER = "whisper", CHAT_MSG_BN_WHISPER = "Battle.net", CHAT_MSG_PARTY = "party",
    CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid",
    CHAT_MSG_RAID_WARNING = "raid", CHAT_MSG_INSTANCE_CHAT = "instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "instance",
    CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "officer", CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell",
    CHAT_MSG_CHANNEL = "channel",
}

local PUBLIC_EVENTS = { CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_CHANNEL = true }

function G.IsJoined(code)
    local _, channel = G.Derive(code)
    return TG.db.threads[G.KeyFor(channel)] ~= nil
end

-- The last code someone sent you, if it's recent and you're not in that group yet.
function G:Pending()
    local p = TG.db and TG.db.pendingInvite
    if not p then return nil end
    if (time() - (p.t or 0)) > PENDING_MAX_AGE or G.IsJoined(p.code) then
        TG.db.pendingInvite = nil
        return nil
    end
    return p
end

function G:OnScanEvent(event, ...)
    if not (TG.db and TG.db.settings.detectInvites) then return end
    local text, sender = ...
    local guid, bnID = select(12, ...)
    if TG.isSecret(text) or TG.isSecret(sender) or TG.isSecret(guid) or TG.isSecret(bnID) then return end
    if type(text) ~= "string" or not text:lower():find("telegnome code", 1, true) and not text:find("^%[Telegnome%]") then
        return
    end
    local short = Ambiguate and type(sender) == "string" and Ambiguate(sender, "short") or sender
    if type(guid) == "string" and guid ~= "" then
        if guid == UnitGUID("player") then return end
    elseif event ~= "CHAT_MSG_BN_WHISPER" and short == UnitName("player") then
        return
    end

    local code, name = G.FindCode(text)
    if not code or G.IsJoined(code) then return end
    local from = short
    if event == "CHAT_MSG_BN_WHISPER" then
        local _, info = TG:ResolveBN(bnID)
        from = info and info.name or "A Battle.net friend"
    end

    -- Say, yell and public channels (Trade...) are open to anyone, so codes seen there are
    -- remembered quietly: no chat line, and they never replace a code a friend sent you
    -- in the last hour. Your own group chats count as private.
    local public = PUBLIC_EVENTS[event] or false
    if event == "CHAT_MSG_CHANNEL" then
        local base = select(9, ...)
        if type(base) == "string" and not TG.isSecret(base) and TG.db.threads[G.KeyFor(base)] then public = false end
    end
    local p = TG.db.pendingInvite
    if public and p and not p.public and p.code ~= code and (time() - (p.t or 0)) < 3600 then return end
    local isNew = not (p and p.code == code and (public or not p.public))
    TG.db.pendingInvite = {
        code = code, name = name, from = from, where = SCAN_WHERE[event], t = time(), public = public or nil,
    }
    if isNew and not public then
        TG:Print(("%s sent a group chat code%s. Open Group chats > + New group in Telegnome - it's filled in for you.")
            :format(from or "Someone", name and (' ("' .. name .. '")') or ""))
    end
    if self:IsPanelShown() then self:FillPending() end
end

local scan = CreateFrame("Frame")
for _, ev in ipairs(SCAN_EVENTS) do scan:RegisterEvent(ev) end
scan:SetScript("OnEvent", function(_, event, ...) G:OnScanEvent(event, ...) end)

-- Puts the last received code into the join boxes.
function G:FillPending()
    if not self.panel then return false end
    local p = self:Pending()
    if not p then
        self.pendingInfo:SetText("")
        return false
    end
    self.codeBox:SetText(p.code)
    self.joinName:SetText(p.name or "")
    local mins = math.floor((time() - p.t) / 60)
    local ago = mins < 1 and "just now" or mins < 60 and (mins .. " min ago")
        or (math.floor(mins / 60) .. " h ago")
    self.pendingInfo:SetText(("|cff66dd66Code from %s%s, %s - press Join.|r")
        :format(p.from or "someone", p.where and (" (" .. p.where .. ")") or "", ago))
    return true
end

function G:Leave(key)
    local th = TG.db.threads[key]
    if not th then return end
    local leave = LeaveChannelByName or (C_ChatInfo and C_ChatInfo.LeaveChannelByName)
    if leave and th.channel then
        self:NoteLeft(th.channel)
        pcall(leave, th.channel)
    end
    if th.code then
        TG:Print(("Left the group \"%s\". Its invite code was: %s"):format(th.name, th.code))
    else
        TG:Print(("Left the group \"%s\"."):format(th.name))
    end
    TG:DeleteThread(key)
end

function G:InviteKey(groupKey, contactKey)
    local th = TG.db.threads[groupKey]
    if not th then return end
    if not th.code then
        TG:Print("Telegnome doesn't know this group's invite code, so it can't invite anyone.")
        return
    end
    TG:Send(contactKey, INVITE_FMT:format(th.name, th.code))
end

function G:InviteName(groupKey, name)
    name = strtrim(name or "")
    if name == "" then return end
    local key, info = TG:WhisperInfo(name)
    if not key then return end
    TG:RememberContact(key, info)
    self:InviteKey(groupKey, key)
end

---------------------------------------------------------------------------
-- Popups
---------------------------------------------------------------------------

local function editBoxOf(dialog)
    return (dialog.GetEditBox and dialog:GetEditBox()) or dialog.editBox or dialog.EditBox
end

local function ensurePopups()
    if StaticPopupDialogs.TELEGNOME_LEAVE then return end

    StaticPopupDialogs.TELEGNOME_LEAVE = {
        text = "Leave the group chat \"%s\"?\nYou can rejoin later with its invite code.",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function(self, data) G:Leave(data or self.data) end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs.TELEGNOME_RENAME = {
        text = "Rename the group \"%s\"\n\nThis only changes the name on your side.",
        button1 = ACCEPT or "OK",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 40,
        OnShow = function(self, data)
            local eb = editBoxOf(self)
            local th = TG.db.threads[data or self.data]
            if eb and th then
                eb:SetText(th.name or "")
                eb:HighlightText()
                eb:SetFocus()
            end
        end,
        OnAccept = function(self, data)
            local eb = editBoxOf(self)
            if eb then G:Rename(data or self.data, eb:GetText()) end
        end,
        EditBoxOnEnterPressed = function(self)
            local dialog = self:GetParent()
            G:Rename(dialog.data, self:GetText())
            dialog:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs.TELEGNOME_CODE = {
        text = "Invite code for \"%s\"\n\nPress Ctrl+C to copy, then paste it in a whisper, party or guild chat. "
            .. "Friends with Telegnome get it filled in when they click + New group.",
        button1 = OKAY or "OK",
        hasEditBox = true,
        editBoxWidth = 260,
        OnShow = function(self, data)
            local eb = editBoxOf(self)
            if eb then
                eb:SetText(data or self.data or "")
                eb:HighlightText()
                eb:SetFocus()
            end
        end,
        EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs.TELEGNOME_INVITE = {
        text = "Invite a player to \"%s\"\n\nThey'll get a whisper with the invite code.",
        button1 = "Invite",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        OnAccept = function(self, data)
            local eb = editBoxOf(self)
            if eb then G:InviteName(data or self.data, eb:GetText()) end
        end,
        EditBoxOnEnterPressed = function(self)
            local dialog = self:GetParent()
            G:InviteName(dialog.data, self:GetText())
            dialog:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
end

function G:ConfirmLeave(key)
    local th = TG.db.threads[key]
    if not th then return end
    ensurePopups()
    StaticPopup_Show("TELEGNOME_LEAVE", th.name, nil, key)
end

function G:ShowCode(key)
    local th = TG.db.threads[key]
    if not th then return end
    if not th.code then
        TG:Print("Telegnome doesn't know this group's invite code.")
        return
    end
    ensurePopups()
    StaticPopup_Show("TELEGNOME_CODE", th.name, nil, G.CODE_TAG .. th.code)
end

function G:AskRename(key)
    local th = TG.db.threads[key]
    if not th then return end
    ensurePopups()
    StaticPopup_Show("TELEGNOME_RENAME", th.name, nil, key)
end

function G:AskInvite(key)
    local th = TG.db.threads[key]
    if not th then return end
    ensurePopups()
    StaticPopup_Show("TELEGNOME_INVITE", th.name, nil, key)
end

-- Right-click menu for a group (list row or header).
function G:OpenMenu(key, anchor)
    local th = TG.db.threads[key]
    if not th then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        self:ShowCode(key)
        return
    end

    local recent = {}
    for ckey, c in pairs(TG.db.contacts) do recent[#recent + 1] = { key = ckey, c = c } end
    table.sort(recent, function(a, b) return (a.c.last or 0) > (b.c.last or 0) end)

    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(th.name)
        root:CreateButton("Who's online", function() G:RequestMembers(key) end)
        root:CreateButton(th.muted and "Unmute" or "Mute (no pop-ups or sound)", function()
            TG:SetMuted(key, not th.muted)
        end)
        root:CreateButton("Rename group", function() G:AskRename(key) end)
        if th.code then
            root:CreateButton("Show invite code", function() G:ShowCode(key) end)
        else
            root:CreateButton("Enter invite code...", function() G:OpenPanel() end)
        end
        root:CreateButton("Clear history", function() TG:ConfirmClearHistory(key) end)
        if th.code then
            local invite = root:CreateButton("Invite")
            for i = 1, math.min(#recent, 12) do
                local r = recent[i]
                local name = TG:DisplayFor(r.key, r.c)
                invite:CreateButton(name, function() G:InviteKey(key, r.key) end)
            end
            invite:CreateButton("Other player...", function() G:AskInvite(key) end)
        end
        root:CreateButton("Leave group", function() G:ConfirmLeave(key) end)
    end)
end

---------------------------------------------------------------------------
-- Create / join panel (opens over the conversation pane)
---------------------------------------------------------------------------

function G:CreatePanel()
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
    title:SetText("Group chats")
    local cog = S.Cog(f, 18)
    cog:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -34)
    line:SetPoint("TOPRIGHT", -8, -34)

    local intro = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 14, -44)
    intro:SetPoint("RIGHT", -14, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText("A group chat is a hidden, password-protected chat channel. "
        .. "When a friend sends you a Telegnome code in chat, it's filled in below automatically.")

    -- Create
    local h1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h1:SetPoint("TOPLEFT", 14, -90)
    h1:SetText("Create a group")
    local nameBox = S.EditBox(f)
    nameBox:SetPoint("TOPLEFT", 14, -112)
    nameBox:SetSize(220, 26)
    nameBox:SetMaxLetters(40)
    local nameHint = nameBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    nameHint:SetPoint("LEFT", 8, 0)
    nameHint:SetText("Group name, e.g. Raid night")
    nameBox:SetScript("OnTextChanged", function(s) nameHint:SetShown(s:GetText() == "") end)
    local createBtn = S.Button(f, "Create", 90, 26)
    createBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    local function doCreate()
        local n = nameBox:GetText()
        nameBox:SetText("")
        nameBox:ClearFocus()
        G:Create(n)
    end
    createBtn:SetScript("OnClick", doCreate)
    nameBox:SetScript("OnEnterPressed", doCreate)
    self.nameBox = nameBox

    -- Join
    local h2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h2:SetPoint("TOPLEFT", 14, -156)
    h2:SetText("Join a group")
    local codeBox = S.EditBox(f)
    codeBox:SetPoint("TOPLEFT", 14, -178)
    codeBox:SetSize(220, 26)
    codeBox:SetMaxLetters(200)
    local codeHint = codeBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    codeHint:SetPoint("LEFT", 8, 0)
    codeHint:SetText("Invite code")

    local joinName = S.EditBox(f)
    joinName:SetPoint("TOPLEFT", 14, -210)
    joinName:SetSize(220, 26)
    joinName:SetMaxLetters(40)
    local joinNameHint = joinName:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    joinNameHint:SetPoint("LEFT", 8, 0)
    joinNameHint:SetText("Name it (optional)")
    joinName:SetScript("OnTextChanged", function(s) joinNameHint:SetShown(s:GetText() == "") end)

    -- Pasting a whole invite line fills in both the code and the name.
    codeBox:SetScript("OnTextChanged", function(s, userInput)
        local text = s:GetText()
        codeHint:SetShown(text == "")
        if userInput then
            local c, n = G.ParseInviteAny(text)
            if c and c ~= text then
                s:SetText(c)
                if n and strtrim(joinName:GetText()) == "" then joinName:SetText(n) end
            end
        end
    end)
    self.codeBox, self.joinName = codeBox, joinName

    local pendingInfo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pendingInfo:SetPoint("LEFT", joinName, "RIGHT", 8, 0)
    pendingInfo:SetPoint("RIGHT", -14, 0)
    pendingInfo:SetJustifyH("LEFT")
    self.pendingInfo = pendingInfo

    local joinBtn = S.Button(f, "Join", 90, 26)
    joinBtn:SetPoint("LEFT", codeBox, "RIGHT", 8, 0)
    local function doJoin()
        local code, n = codeBox:GetText(), joinName:GetText()
        if strtrim(code) == "" then return end
        codeBox:SetText("")
        joinName:SetText("")
        pendingInfo:SetText("")
        codeBox:ClearFocus()
        joinName:ClearFocus()
        G:Join(code, n)
    end
    joinBtn:SetScript("OnClick", doJoin)
    codeBox:SetScript("OnEnterPressed", doJoin)
    joinName:SetScript("OnEnterPressed", doJoin)
    codeBox:SetScript("OnTabPressed", function() joinName:SetFocus() end)
    joinName:SetScript("OnTabPressed", function() codeBox:SetFocus() end)

    local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 14, -250)
    note:SetPoint("RIGHT", -14, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Members need to be able to join the same chat channels as you (usually the same realm and faction).")

    local done = S.Button(f, "Close", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    done:SetScript("OnClick", function() G:ClosePanel() end)

    local slots = S.Button(f, "Your chat channels", 150, 24)
    slots:SetPoint("BOTTOMLEFT", 10, 10)
    slots:SetScript("OnClick", function() TG.ChannelList:Open() end)
    S.Tooltip(slots, "Your chat channels", "Every chat channel your character is in (the game allows 10), with a Leave button.")
end

function G:IsPanelShown()
    return self.panel and self.panel:IsShown() or false
end

function G:OpenPanel()
    UI:Show()
    UI:SetTab("groups")
    self:CreatePanel()
    TG.Settings:Close()
    TG.Picker:Close()
    TG.Channels:ClosePanel()
    TG.ChannelList:Close()
    TG.Requests:ClosePanel()
    self.panel:Show()
    UI.newBtn:SetText("Cancel")
    if self:FillPending() then
        self.codeBox:SetFocus()
        self.codeBox:HighlightText(0, 0)
    else
        self.nameBox:SetFocus()
    end
end

function G:ClosePanel()
    if not self:IsPanelShown() then return end
    self.panel:Hide()
    UI:UpdateNewButton()
    if UI.frame:IsShown() and UI.selected then UI:Select(UI.selected) end
end

function G:TogglePanel()
    if self:IsPanelShown() then self:ClosePanel() else self:OpenPanel() end
end
