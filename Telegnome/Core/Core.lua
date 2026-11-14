-- Telegnome: Gnomish Universal Messenger
-- Core: event capture, storage, contacts, sending, chat filter and slash commands.

local ADDON, ns = ...
local TG = {}
ns.TG = TG
_G.Telegnome = TG

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
TG.version = (getMeta and getMeta(ADDON, "Version")) or "dev"

local DEFAULTS = {
    settings = {
        hideFromChat = false, -- remove whispers from the normal chat frames
        debug = false,        -- print raw event info to chat
        sound = false,        -- Telegnome's own sound for new messages (off until turned on)
        soundChoice = "bnet", -- which sound (see TG.SOUNDS)
        notify = true,        -- notifier grows to show new messages
        notifyFrom = "all",   -- "all" | "friendsguild" | "friends"
        counter = true,       -- show the on-screen missed-messages counter
        counterHideEmpty = false, -- hide the counter when nothing is unread
        notifyGroups = true,  -- notifier also pops up for group chat messages
        dnd = false,          -- do not disturb: no pop-up previews or sounds
        dndReply = false,     -- auto-reply to whispers while do not disturb is on
        dndMessage = "I'm busy right now and will get back to you soon.",
        detectInvites = true, -- pick up "Telegnome code: ..." from incoming chat
        hideChannels = false, -- hide followed channels from the main chat
        -- group chats are always kept out of the main chat
        toastGrow = "right",  -- notifier grows "right" or "left"
        maxPerThread = 200,   -- messages kept per conversation
        opacity = 100,        -- main window opacity in percent (30-100)
        opacityHover = true,  -- a see-through window turns solid under the mouse or while typing
        keywords = "",        -- alert words for followed channels, comma-separated
        groupJoinLeave = true, -- "X joined / left" lines in group chats
        enterToTelegnome = true, -- Enter puts the cursor in Telegnome while its window is open
        slay = false,         -- /tg slaay-mode
        theme = "brass",      -- colour theme (see Style.THEMES)
        textSize = "normal",  -- message text: small / normal / large
        -- one-click answers for requests (Settings > Requests)
        quickReplies = { "Inviting you now.", "What level and role are you?", "One moment, checking the group." },
        declineReply = "Sorry, the group is full.",
        requestsTab = true,   -- collect strangers' whispers under Requests while listed in the group finder
        recruiting = false,   -- manual switch for the same (/tg recruit)
    },
    collapsed = {}, -- folded sections of the Direct messages list
    minimap = { hide = false, angle = 200 },
    threads = {},  -- open conversations with history
    contacts = {}, -- everyone you've talked to (kept when a conversation is closed)
    seq = 0,
}

local WHISPER_EVENTS = { CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true }
-- What the game says back when a whisper doesn't get through (or the other side is away).
local FEEDBACK_EVENTS = {
    CHAT_MSG_SYSTEM = true, CHAT_MSG_AFK = true, CHAT_MSG_DND = true, CHAT_MSG_IGNORED = true,
    CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE = true,
}
local BN_EVENTS = { CHAT_MSG_BN_WHISPER = true, CHAT_MSG_BN_WHISPER_INFORM = true }
local OUTGOING = { CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_BN_WHISPER_INFORM = true }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function copyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- The modern client can hide chat contents from addons during combat/encounters.
local function isSecret(v)
    if issecretvalue then return issecretvalue(v) and true or false end
    return false
end
TG.isSecret = isSecret

local function show(v)
    if isSecret(v) then return "<secret>" end
    return tostring(v)
end

-- First maxChars characters of a string, never cutting a UTF-8 character (a, o with dots...) in half.
function TG.Utf8Left(s, maxChars)
    local i, chars, len = 1, 0, #s
    while i <= len and chars < maxChars do
        local b = s:byte(i)
        i = i + (b >= 240 and 4 or b >= 224 and 3 or b >= 192 and 2 or 1)
        chars = chars + 1
    end
    return s:sub(1, i - 1)
end

function TG.FullName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if not name:find("-", 1, true) then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName()
        if realm and realm ~= "" then name = name .. "-" .. realm end
    end
    return name
end

-- Who to address a whisper to: people on your own realm by their bare name (as you would
-- type after /w), people on other realms as Name-Realm.
function TG.WhisperTarget(fullName)
    if type(fullName) ~= "string" then return fullName end
    local name, realm = fullName:match("^(.+)%-([^%-]+)$")
    if not name then return fullName end
    local mine = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(mine) == "string" and mine ~= "" and realm:lower() == mine:lower() then return name end
    return fullName
end

function TG.WhisperKey(fullName)
    return "W:" .. fullName:lower()
end

function TG:Print(...)
    print("|cff33ccffTelegnome|r:", ...)
end

function TG:Debug(...)
    if self.db and self.db.settings.debug then
        print("|cff33ccffTelegnome|r |cff888888[debug]|r", ...)
    end
end

-- v0.1 keyed character threads case-sensitively; v0.2 uses lowercase keys.
local function migrate(db)
    -- 0.6.0: the sound now plays for every message, so start everyone with it off once.
    if not db.soundReset060 then
        db.settings.sound = false
        db.soundReset060 = true
    end
    local moves = {}
    for key in pairs(db.threads) do
        if key:sub(1, 2) == "W:" and key ~= key:lower() then moves[#moves + 1] = key end
    end
    for _, key in ipairs(moves) do
        local nk = key:lower()
        if not db.threads[nk] then db.threads[nk] = db.threads[key] end
        db.threads[key] = nil
    end
    for key, th in pairs(db.threads) do
        if not db.contacts[key] then
            local last = th.msgs and th.msgs[#th.msgs]
            db.contacts[key] = {
                kind = th.kind, name = th.name, battleTag = th.battleTag, class = th.class,
                last = last and last.t or 0,
            }
        end
    end
    -- v0.5 had one pop-up switch for all followed channels; v0.6 has one per channel.
    if db.settings.notifyChannels ~= nil then
        if db.settings.notifyChannels then
            for _, th in pairs(db.threads) do
                if th.kind == "CHANNEL" then th.notify = true end
            end
        end
        db.settings.notifyChannels = nil
    end
end

---------------------------------------------------------------------------
-- Contact resolution
---------------------------------------------------------------------------

-- Battle.net account IDs change between sessions, so BN contacts are keyed by BattleTag.
function TG:ResolveBN(bnID)
    if not bnID or bnID == 0 then return nil end
    local acct = C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(bnID)
    local tag = acct and acct.battleTag
    if tag and tag ~= "" then
        return "BN:" .. tag, { kind = "BN", battleTag = tag, name = tag:match("^[^#]+") or tag, bnID = bnID }
    end
    return "BNID:" .. tostring(bnID), { kind = "BN", name = "Battle.net friend", bnID = bnID }
end

function TG:BNInfoFromAccount(acct)
    local tag = acct.battleTag
    return "BN:" .. tag, { kind = "BN", battleTag = tag, name = tag:match("^[^#]+") or tag, bnID = acct.bnetAccountID }
end

-- Current session's bnetAccountID and account info for a BN contact.
function TG:LookupBN(key, battleTag)
    if not battleTag then
        local rec = self.db.threads[key] or self.db.contacts[key]
        battleTag = rec and rec.battleTag
    end
    local id = self.bnIDs[key]
    local acct = id and C_BattleNet and C_BattleNet.GetAccountInfoByID(id)
    if acct and (not battleTag or acct.battleTag == battleTag) then
        return id, acct
    end
    if battleTag and BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local total = BNGetNumFriends() or 0
        for i = 1, total do
            local a = C_BattleNet.GetFriendAccountInfo(i)
            if a and a.battleTag == battleTag then
                self.bnIDs[key] = a.bnetAccountID
                return a.bnetAccountID, a
            end
        end
    end
    return nil
end

function TG:ClassFromGUID(guid)
    if type(guid) ~= "string" or guid == "" or not GetPlayerInfoByGUID then return nil end
    local ok, _, cls = pcall(GetPlayerInfoByGUID, guid)
    if ok then return cls end
    return nil
end

function TG:WhisperInfo(name, guid)
    local full = TG.FullName(name)
    if not full then return nil end
    return TG.WhisperKey(full), { kind = "WHISPER", name = full, guid = guid, class = self:ClassFromGUID(guid) }
end

-- Name, {r,g,b}, online (true/false, or nil when unknown) for any thread/contact record.
function TG:DisplayFor(key, rec)
    if not rec then return "?", { 1, 1, 1 }, nil end
    if rec.kind == "GROUP" then
        return rec.name or "Group", { 1.0, 0.72, 0.42 }, nil
    end
    if rec.kind == "BN" and rec.demo then
        return rec.name or "Friend", { 0.51, 0.77, 1.0 }, rec.demoOnline or false
    end
    if rec.kind == "BN" then
        local _, acct = self:LookupBN(key, rec.battleTag)
        local name = (acct and acct.accountName) or rec.name or "Battle.net friend"
        local online = acct and acct.gameAccountInfo and acct.gameAccountInfo.isOnline or false
        return name, { 0.51, 0.77, 1.0 }, online
    end
    local short = (Ambiguate and rec.name) and Ambiguate(rec.name, "short") or rec.name or "?"
    local c = rec.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[rec.class]
    return short, c and { c.r, c.g, c.b } or { 1.0, 0.5, 1.0 }, nil
end

function TG:ThreadDisplay(key)
    return self:DisplayFor(key, self.db.threads[key] or self.db.contacts[key])
end

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------

function TG:RememberContact(key, info)
    local c = self.db.contacts[key] or {}
    c.kind = info.kind or c.kind
    if info.name then c.name = info.name end
    c.battleTag = info.battleTag or c.battleTag
    c.class = info.class or c.class
    c.guid = info.guid or c.guid
    c.last = time()
    self.db.contacts[key] = c
end

function TG:EnsureThread(key, info)
    local db = self.db
    local th = db.threads[key]
    if not th then
        local c = db.contacts[key]
        th = {
            kind = info.kind, name = info.name, battleTag = info.battleTag or (c and c.battleTag),
            class = c and c.class, guid = c and c.guid, fav = c and c.fav or nil,
            muted = c and c.muted or nil, msgs = {}, unread = 0,
            code = info.code, channel = info.channel, pass = info.pass,
        }
        db.threads[key] = th
    elseif info.kind == "WHISPER" and info.name then
        th.name = info.name -- keep the server's capitalisation
    end
    if info.class then th.class = info.class end
    if info.guid then th.guid = info.guid end
    if info.bnID then self.bnIDs[key] = info.bnID end

    db.seq = (db.seq or 0) + 1
    th.order = db.seq
    if info.kind ~= "GROUP" and info.kind ~= "CHANNEL" then self:RememberContact(key, info) end
    return th
end

-- extra (group chats): { from = "Name", cls = "MAGE" }
function TG:AddMessage(key, info, outgoing, text, extra)
    local db = self.db
    local th = self:EnsureThread(key, info)

    local msgs = th.msgs
    -- an alert word matched (followed channels); a muted conversation stays quiet regardless
    local alert = extra and extra.alert and not th.muted or false
    msgs[#msgs + 1] = {
        t = time(), out = outgoing or nil, text = text,
        from = extra and extra.from, cls = extra and extra.cls, hl = alert or nil,
    }
    local max = db.settings.maxPerThread or 200
    while #msgs > max do table.remove(msgs, 1) end

    if outgoing then
        th.unread = 0
    elseif not self.UI:IsViewing(key) then
        th.unread = (th.unread or 0) + 1
        if not db.settings.dnd then -- do not disturb: no sound, no pop-up preview
            self:MaybePlaySound(key, alert)
            self.Toast:OnIncoming(key, text, extra and extra.from, alert)
        end
    end

    self.UI:OnThreadUpdated(key, not outgoing)
    self:RefreshUnread()
end

---------------------------------------------------------------------------
-- Sound
---------------------------------------------------------------------------

-- Played on the Master channel, so it's heard even with game sound effects turned off.
TG.SOUNDS = {
    { id = "bnet", label = "Chime", kit = "UI_BNET_TOAST", fallback = 18019 },
    { id = "whisper", label = "Whisper", kit = "TELL_MESSAGE", fallback = 3081 },
    { id = "ping", label = "Ping", kit = "MAP_PING", fallback = 3175 },
}

function TG:PlayAlert(choice)
    local pick = self.SOUNDS[1]
    for _, snd in ipairs(self.SOUNDS) do
        if snd.id == (choice or self.db.settings.soundChoice) then pick = snd end
    end
    local kit = (SOUNDKIT and SOUNDKIT[pick.kit]) or pick.fallback
    if PlaySound then
        local ok, willPlay = pcall(PlaySound, kit, "Master")
        if ok and willPlay ~= false then return true end
        if kit ~= pick.fallback then pcall(PlaySound, pick.fallback, "Master") end
    end
end

-- Plays for the same messages that may pop up: whispers from the people chosen under
-- "From", group chats when they pop up, followed channels with their Pop-up tick.
-- At most one sound every 1.5 seconds.
function TG:MaybePlaySound(key, force)
    local s = self.db.settings
    if not s.sound or s.dnd or not (force or self:PassesNotifyFilter(key)) then return end
    local now = GetTime()
    if self.lastSound and now - self.lastSound < 1.5 then return end
    self.lastSound = now
    self:PlayAlert()
end

-- "Only in Telegnome": whispers, Battle.net whispers and followed channels kept out of the main chat.
function TG:IsTelegnomeOnly()
    local s = self.db.settings
    return s.hideFromChat and s.hideChannels
end

function TG:SetTelegnomeOnly(on)
    self.db.settings.hideFromChat = on and true or false
    self.db.settings.hideChannels = on and true or false
end

-- Notification filter: Battle.net friends always count as friends.
function TG:IsCharacterFriend(th)
    if th.guid then
        if C_FriendList and C_FriendList.IsFriend then
            local ok, res = pcall(C_FriendList.IsFriend, th.guid)
            if ok and res then return true end
        end
        if C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID then
            local ok, res = pcall(C_BattleNet.GetGameAccountInfoByGUID, th.guid)
            if ok and res then return true end
        end
    end
    if th.name and C_FriendList and C_FriendList.GetFriendInfo then
        local short = Ambiguate and Ambiguate(th.name, "none") or th.name
        local ok, res = pcall(C_FriendList.GetFriendInfo, short)
        if ok and res then return true end
    end
    return false
end

function TG:PassesNotifyFilter(key)
    local th = self.db.threads[key]
    if th and th.muted then return false end
    if th and th.kind == "GROUP" then return self.db.settings.notifyGroups end
    if th and th.kind == "CHANNEL" then return th.notify and true or false end
    if th and th.demo then return true end
    local mode = self.db.settings.notifyFrom or "all"
    if mode == "all" then return true end
    if not th or th.kind == "BN" then return true end
    if self:IsCharacterFriend(th) then return true end
    if mode == "friendsguild" and IsGuildMember then
        local ok, res = pcall(IsGuildMember, th.guid or th.name)
        if ok and res then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Sections of the Direct messages list: favorites, friends, others
---------------------------------------------------------------------------

-- Battle.net friends, your friends list and guild members.
function TG:IsFriendly(th)
    if th.kind == "BN" then return true end
    if self:IsCharacterFriend(th) then return true end
    if th.guid and IsGuildMember then
        local ok, res = pcall(IsGuildMember, th.guid)
        if ok and res then return true end
    end
    return false
end

function TG:SectionOf(th)
    if th.fav then return "fav" end
    if th.demoSec then return th.demoSec end
    return self:IsFriendly(th) and "friends" or "others"
end

-- Muted: no pop-up and no sound for this conversation. Messages still arrive and count.
function TG:SetMuted(key, on)
    local th = self.db.threads[key]
    if th then th.muted = on and true or nil end
    local c = self.db.contacts[key]
    if c then c.muted = on and true or nil end
    self.UI:RefreshList()
end

function TG:SetFavorite(key, on)
    local th = self.db.threads[key]
    if th then
        th.fav = on and true or nil
        if on then th.req = nil end -- starring a request keeps the person: they move to Direct messages
    end
    local c = self.db.contacts[key]
    if c then c.fav = on and true or nil end
    self.UI:OnFavoriteChanged(key)
end

-- Removes someone from the New message list, with their conversation.
function TG:ForgetContact(key)
    self.db.contacts[key] = nil
    if self.db.threads[key] then
        self:DeleteThread(key)
    else
        self.UI:RefreshList()
    end
    if self.Picker then self.Picker:Refresh() end
end

function TG:OtherKeys()
    local keys = {}
    for key, th in pairs(self.db.threads) do
        if (th.kind == "WHISPER" or th.kind == "BN") and not th.req and self:SectionOf(th) == "others" then
            keys[#keys + 1] = key
        end
    end
    return keys
end

-- "Close all" on the Others section: conversations, history and remembered contacts.
function TG:CloseOthers()
    local keys = self:OtherKeys()
    for _, key in ipairs(keys) do
        self.db.contacts[key] = nil
        self:DeleteThread(key)
    end
    if self.Picker then self.Picker:Refresh() end
    return #keys
end

function TG:ConfirmCloseOthers()
    local n = #self:OtherKeys()
    if n == 0 then return end
    if not StaticPopupDialogs.TELEGNOME_CLOSE_OTHERS then
        StaticPopupDialogs.TELEGNOME_CLOSE_OTHERS = {
            text = "Close all %s conversations under Others?\n\nTheir history is removed and they're taken out of "
                .. "New message. Favorites and friends are not touched.",
            button1 = "Close all",
            button2 = CANCEL or "Cancel",
            OnAccept = function() TG:CloseOthers() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
    StaticPopup_Show("TELEGNOME_CLOSE_OTHERS", n)
end

-- A grey note in a conversation (not a message: no unread count, no pop-up).
function TG:AddSystemLine(key, text)
    local th = self.db.threads[key]
    if not th then return end
    local last = th.msgs[#th.msgs]
    if last and last.sys and last.text == text and time() - (last.t or 0) < 60 then return end
    th.msgs[#th.msgs + 1] = { t = time(), sys = true, text = text }
    local max = self.db.settings.maxPerThread or 200
    while #th.msgs > max do table.remove(th.msgs, 1) end
    self.UI:OnThreadUpdated(key, false)
end

---------------------------------------------------------------------------
-- Do not disturb
---------------------------------------------------------------------------

TG.AUTO_PREFIX = "[Auto-reply] "
local AUTO_COOLDOWN = 1800 -- seconds before the same person gets another auto-reply

function TG:SetDND(on, silent)
    self.db.settings.dnd = on and true or false
    if not silent then
        self:Print("Do not disturb: " .. (on and "|cff55ff55on|r" or "|cffff5555off|r"))
    end
    self:RefreshUnread()
    if self.Settings:IsShown() then self.Settings:Refresh() end
end

-- Answers a whisper while do not disturb + auto-reply are on. Never answers another
-- auto-reply (two Telegnome users would otherwise answer each other forever) and
-- replies to each person at most once per AUTO_COOLDOWN.
function TG:MaybeAutoReply(key, text)
    local s = self.db.settings
    if not (s.dnd and s.dndReply) then return end
    if type(text) ~= "string" or text:sub(1, #TG.AUTO_PREFIX) == TG.AUTO_PREFIX then return end
    local msg = strtrim(s.dndMessage or "")
    if msg == "" then return end

    self.autoReplied = self.autoReplied or {}
    local now = GetTime()
    local last = self.autoReplied[key]
    if last and now - last < AUTO_COOLDOWN then return end
    self.autoReplied[key] = now

    C_Timer.After(1, function()
        if self.db.settings.dnd and self.db.settings.dndReply then
            self:Send(key, TG.AUTO_PREFIX .. msg)
        end
    end)
end

---------------------------------------------------------------------------
-- Clearing history
---------------------------------------------------------------------------

function TG:ClearHistory(key)
    local th = self.db.threads[key]
    if not th then return end
    th.msgs = {}
    th.unread = 0
    if self.UI.selected == key then self.UI:Select(key) else self.UI:RefreshList() end
    self:RefreshUnread()
end

-- Settings > Your data
function TG:DataCounts()
    local threads, msgs, contacts = 0, 0, 0
    for _, th in pairs(self.db.threads) do
        threads = threads + 1
        msgs = msgs + #th.msgs
    end
    for _ in pairs(self.db.contacts) do contacts = contacts + 1 end
    return threads, msgs, contacts
end

function TG:ClearAllHistory()
    for _, th in pairs(self.db.threads) do
        th.msgs = {}
        th.unread = 0
    end
    self:RefreshUnread()
    self.UI:RefreshList()
    if self.UI.selected then self.UI:Select(self.UI.selected) end
end

function TG:ConfirmClearAllHistory()
    if not StaticPopupDialogs.TELEGNOME_CLEAR_ALL then
        StaticPopupDialogs.TELEGNOME_CLEAR_ALL = {
            text = "Delete every saved message in Telegnome?\n\nConversations, groups, contacts and settings stay. "
                .. "This can't be undone.",
            button1 = "Delete messages",
            button2 = CANCEL or "Cancel",
            OnAccept = function()
                TG:ClearAllHistory()
                if TG.Settings then TG.Settings:Refresh() end
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
    StaticPopup_Show("TELEGNOME_CLEAR_ALL")
end

function TG:ConfirmClearHistory(key)
    if not self.db.threads[key] then return end
    if not StaticPopupDialogs.TELEGNOME_CLEAR then
        StaticPopupDialogs.TELEGNOME_CLEAR = {
            text = "Clear the saved history in \"%s\"?\nThe conversation stays open.",
            button1 = "Clear history",
            button2 = CANCEL or "Cancel",
            OnAccept = function(dialog, data) TG:ClearHistory(data or dialog.data) end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
    local name = self:ThreadDisplay(key)
    StaticPopup_Show("TELEGNOME_CLEAR", name, nil, key)
end

function TG:MarkAllRead()
    for _, th in pairs(self.db.threads) do th.unread = 0 end
    self.UI:RefreshList()
    self:RefreshUnread()
end

function TG:MostRecentUnread()
    local best, bestOrder
    for key, th in pairs(self.db.threads) do
        if (th.unread or 0) > 0 and th.kind ~= "CHANNEL" and (not bestOrder or (th.order or 0) > bestOrder) then
            best, bestOrder = key, th.order or 0
        end
    end
    return best
end

-- Open (or create) a conversation without a message, e.g. from the New message picker.
function TG:OpenConversation(key, info)
    self:EnsureThread(key, info)
    self.UI:Show()
    self.UI:Select(key)
    self.UI.input:SetFocus()
end

function TG:DeleteThread(key)
    self.db.threads[key] = nil
    self.UI:OnThreadDeleted(key)
    self:RefreshUnread()
end

function TG:TotalUnread()
    local n = 0
    -- Followed channels are excluded: busy chats would drown out real missed messages.
    for _, th in pairs(self.db.threads) do
        if th.kind ~= "CHANNEL" then n = n + (th.unread or 0) end
    end
    return n
end

function TG:RefreshUnread()
    self.UI:UpdateTitle()
    if self.Requests then self.Requests:Refresh() end
    if self.Minimap then self.Minimap:Update() end
    if self.Toast then self.Toast:Update() end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

-- Works for open conversations and remembered contacts (used for group invites).
function TG:Send(key, text)
    local th = self.db.threads[key] or self.db.contacts[key]
    if not th or not text or not text:match("%S") then return false end

    if self.Demo and self.Demo.on then -- sample conversations: nothing leaves the computer
        self:AddMessage(key, { kind = th.kind }, true, text)
        return true
    end

    if th.kind == "GROUP" then
        return self.Groups:Send(th, text)
    elseif th.kind == "CHANNEL" then
        return self.Channels:Send(th, text)
    elseif th.kind == "BN" then
        local id = self:LookupBN(key)
        local sendBN = BNSendWhisper or (C_BattleNet and C_BattleNet.SendWhisper)
        if not id or not sendBN then
            self:Print("That Battle.net friend can't be reached right now.")
            return false
        end
        sendBN(id, text)
    else
        local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        local target = TG.WhisperTarget(th.name)
        self.lastWhisper = { key = key, t = GetTime(), text = text, target = target, full = th.name }
        send(text, "WHISPER", nil, target)
    end
    -- The outgoing copy is stored when the *_INFORM event arrives.
    return true
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

function TG:OnChatEvent(event, ...)
    local text, sender = ...
    local guid, bnID = select(12, ...)
    self:Debug(event, "who:", show(sender), "text:", show(text), "guid:", show(guid), "bnID:", show(bnID))

    if isSecret(text) or isSecret(sender) or isSecret(bnID) or isSecret(guid) then
        self:Debug("Message is restricted right now; left in the main chat.")
        return
    end

    local outgoing = OUTGOING[event]
    local key, info
    if BN_EVENTS[event] then
        key, info = self:ResolveBN(bnID)
    else
        key, info = self:WhisperInfo(sender, (not outgoing) and guid or nil)
    end
    if not key then
        self:Debug("Could not work out who this is; ignored.")
        return
    end

    if not BN_EVENTS[event] then
        if outgoing then
            if self.Requests:WasDeclined(key) then return end -- our "sorry, full" to a dismissed request
        else
            self.Requests:OnWhisper(key, info, text)
        end
    end
    self:AddMessage(key, info, outgoing, text)
    if not outgoing then self:MaybeAutoReply(key, text) end

    -- Hidden messages skip the default handler, so keep R (reply) working.
    if not outgoing and self.db.settings.hideFromChat and ChatEdit_SetLastTellTarget then
        pcall(ChatEdit_SetLastTellTarget, sender, BN_EVENTS[event] and "BN_WHISPER" or "WHISPER")
    end
end

-- "No player named 'X' is currently playing." in the game's own language, as a pattern.
local notFoundPattern
local function notFoundName(text)
    if type(ERR_CHAT_PLAYER_NOT_FOUND_S) ~= "string" then return nil end
    if not notFoundPattern then
        local p = ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        p = p:gsub("%%%%s", "(.+)")
        notFoundPattern = "^" .. p .. "$"
    end
    return text:match(notFoundPattern)
end

-- Shows in the conversation what the game otherwise only says in the main chat:
-- the whisper didn't arrive, or the other person is away / busy / ignoring you.
function TG:OnFeedbackEvent(event, ...)
    local text, sender = ...
    if isSecret(text) or isSecret(sender) then return end
    local threads = self.db.threads

    if event == "CHAT_MSG_SYSTEM" then
        if type(text) ~= "string" then return end
        local name = notFoundName(text)
        if not name then return end
        local lw = self.lastWhisper
        if lw and GetTime() - lw.t >= 5 then lw = nil end
        -- Servers differ on whether they want "Name" or "Name-Realm" for someone on your own
        -- realm. If the first form wasn't found, try the other one once before giving up.
        if lw and not lw.retried and lw.target ~= lw.full and name:lower() == lw.target:lower() then
            lw.retried = true
            lw.target = lw.full
            lw.t = GetTime()
            local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
            send(lw.text, "WHISPER", nil, lw.full)
            return
        end
        local full = TG.FullName(name)
        local key = full and TG.WhisperKey(full)
        if not (key and threads[key]) then key = lw and lw.key or nil end
        name = Ambiguate and Ambiguate(name, "short") or name
        if key then self:AddSystemLine(key, "Not delivered - " .. name .. " is offline or doesn't exist.") end
        return
    end

    if event == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE" then
        local bnID = select(13, ...)
        if isSecret(bnID) then return end
        local key = self:ResolveBN(bnID)
        if key and threads[key] then self:AddSystemLine(key, "Not delivered - this friend is offline.") end
        return
    end

    local full = TG.FullName(sender)
    local key = full and TG.WhisperKey(full)
    if not (key and threads[key]) then return end
    local short = Ambiguate and Ambiguate(sender, "short") or sender
    local note = (type(text) == "string" and text ~= "") and (": " .. text) or "."
    if event == "CHAT_MSG_AFK" then
        self:AddSystemLine(key, short .. " is away" .. note)
    elseif event == "CHAT_MSG_DND" then
        self:AddSystemLine(key, short .. " does not want to be disturbed" .. note)
    elseif event == "CHAT_MSG_IGNORED" then
        self:AddSystemLine(key, short .. " is ignoring you. Your message wasn't delivered.")
    end
end

-- Friend online status changes: refresh lists, at most once a second.
function TG:QueueRefresh()
    if self.refreshPending or not C_Timer then return end
    self.refreshPending = true
    C_Timer.After(1, function()
        self.refreshPending = false
        self.UI:RefreshList()
        if self.Picker then self.Picker:Refresh() end
    end)
end

-- Only hides what OnChatEvent can read and store; restricted messages stay in the main chat.
local function chatFilter(_, _, ...)
    if not (TG.db and TG.db.settings.hideFromChat) then return false end
    local msg, author = ...
    local guid, bnID = select(12, ...)
    if isSecret(msg) or isSecret(author) or isSecret(guid) or isSecret(bnID) then return false end
    return true
end

function TG:InstallChatFilter()
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if not add then
        self:Print("Could not hook the chat filter; whispers will also stay in the main chat.")
        return
    end
    for ev in pairs(WHISPER_EVENTS) do add(ev, chatFilter) end
    for ev in pairs(BN_EVENTS) do add(ev, chatFilter) end
    self.Groups:InstallChatFilter(add)
    self.Channels:InstallChatFilter(add)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        TelegnomeDB = TelegnomeDB or {}
        copyDefaults(TelegnomeDB, DEFAULTS)
        TG.db = TelegnomeDB
        TG.bnIDs = {}
        migrate(TG.db)
        TG.Style.SetTheme(TG.db.settings.theme)
        for ev in pairs(WHISPER_EVENTS) do self:RegisterEvent(ev) end
        for ev in pairs(BN_EVENTS) do self:RegisterEvent(ev) end
        for ev in pairs(FEEDBACK_EVENTS) do pcall(self.RegisterEvent, self, ev) end
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("BN_FRIEND_INFO_CHANGED")
        self:RegisterEvent("FRIENDLIST_UPDATE")
        for ev in pairs(TG.Groups.EVENTS) do pcall(self.RegisterEvent, self, ev) end
        for ev in pairs(TG.Channels.EVENTS) do self:RegisterEvent(ev) end
        TG:InstallChatFilter()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        TG.Minimap:Create()
        TG.Toast:Update()
    elseif event == "BN_FRIEND_INFO_CHANGED" or event == "FRIENDLIST_UPDATE" then
        TG:QueueRefresh()
    elseif FEEDBACK_EVENTS[event] then
        TG:OnFeedbackEvent(event, ...)
    elseif TG.Groups.EVENTS[event] or TG.Channels.EVENTS[event] then
        if TG.Groups.EVENTS[event] then TG.Groups:OnEvent(event, ...) end
        if TG.Channels.EVENTS[event] then TG.Channels:OnEvent(event, ...) end
    else
        TG:OnChatEvent(event, ...)
    end
end)

-- Addon compartment (the addons button by the minimap), set in the TOC.
function Telegnome_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then
        TG.UI:Show()
        TG.Picker:Open()
    elseif IsShiftKeyDown() then
        TG.Settings:Toggle()
    else
        TG.UI:Toggle()
    end
end

---------------------------------------------------------------------------
-- Key bindings (Bindings.xml; set them under Options > Keybindings > AddOns)
---------------------------------------------------------------------------

BINDING_HEADER_TELEGNOME = "Telegnome"
BINDING_NAME_TELEGNOME_TOGGLE = "Open or close Telegnome"
BINDING_NAME_TELEGNOME_UNREAD = "Open the newest unread message"

function Telegnome_ToggleBinding()
    if TG.db then TG.UI:Toggle() end
end

function Telegnome_OpenUnreadBinding()
    if not TG.db then return end
    local key = TG:MostRecentUnread()
    if not key then
        TG.UI:Toggle()
        return
    end
    TG.UI:Show()
    TG.UI:CloseOverlays()
    TG.UI:Select(key)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function onOff(v) return v and "|cff55ff55on|r" or "|cffff5555off|r" end

SLASH_TELEGNOME1 = "/telegnome"
SLASH_TELEGNOME2 = "/tg"
SlashCmdList.TELEGNOME = function(input)
    local raw = strtrim(input or "")
    local cmd = raw:lower()
    local verb, rest = raw:match("^(%S+)%s+(.+)$")
    verb = verb and verb:lower()
    local s = TG.db.settings
    if cmd == "" then
        TG.UI:Toggle()
    elseif verb == "join" then
        TG.Groups:Join(rest)
    elseif verb == "group" or verb == "create" then
        TG.Groups:Create(rest)
    elseif cmd == "groups" or cmd == "group" then
        TG.Groups:OpenPanel()
    elseif cmd == "channels" or cmd == "follow" then
        TG.Channels:OpenPanel()
    elseif cmd == "mychannels" or cmd == "slots" then
        TG.ChannelList:Open()
    elseif verb == "opacity" or cmd == "opacity" then
        local n = tonumber(rest or "")
        if n then
            TG.UI:SetOpacity(n)
            TG:Print(("Window opacity: %d%%"):format(s.opacity))
        else
            TG:Print(("Window opacity is %d%%. Use /tg opacity 30-100."):format(s.opacity or 100))
        end
    elseif cmd == "theme" or verb == "theme" then
        local t = rest and TG.Style.FindTheme(strtrim(rest))
        if t then
            s.theme = t.id
            TG.Style.SetTheme(t.id)
            if TG.Settings then TG.Settings:Refresh() end
            TG:Print("Theme: " .. t.label)
        else
            local names = {}
            for _, th in ipairs(TG.Style.THEMES) do names[#names + 1] = th.id end
            TG:Print("Theme is " .. TG.Style.theme.label .. ". Choose with /tg theme " .. table.concat(names, " | "))
        end
    elseif cmd == "recruit" or cmd == "requests" then
        s.recruiting = not s.recruiting
        TG:Print("Collecting whispers under Requests (manual switch): " .. onOff(s.recruiting))
        TG:RefreshUnread()
        if s.recruiting then TG.Requests:OpenPanel() end
    elseif cmd == "dnd" then
        TG:SetDND(not s.dnd)
    elseif cmd == "new" then
        TG.UI:Show()
        TG.Picker:Open()
    elseif cmd == "config" or cmd == "settings" or cmd == "options" then
        TG.Settings:Open()
    elseif cmd == "hide" then
        s.hideFromChat = not s.hideFromChat
        TG:Print("Hide whispers from main chat: " .. onOff(s.hideFromChat))
    elseif cmd == "notify" then
        s.notify = not s.notify
        TG:Print("Pop-up notifications: " .. onOff(s.notify))
    elseif cmd == "counter" then
        s.counter = not s.counter
        TG.Toast:Update()
        TG:Print("Missed-messages counter: " .. onOff(s.counter))
    elseif cmd == "sound" then
        s.sound = not s.sound
        TG:Print("Sound for new messages: " .. onOff(s.sound))
        if s.sound then TG:PlayAlert() end
    elseif cmd == "only" then
        TG:SetTelegnomeOnly(not TG:IsTelegnomeOnly())
        TG:Print("Only in Telegnome (whispers, Battle.net, followed channels and groups hidden from the main chat): "
            .. onOff(TG:IsTelegnomeOnly()))
    elseif cmd == "minimap" then
        TG.db.minimap.hide = not TG.db.minimap.hide
        TG.Minimap:Update()
        TG:Print("Minimap button: " .. onOff(not TG.db.minimap.hide))
    elseif cmd == "debug" then
        s.debug = not s.debug
        TG:Print("Debug: " .. onOff(s.debug))
    elseif cmd == "clear" then
        local key = TG.UI.selected
        if key and TG.db.threads[key] and TG.db.threads[key].kind == "GROUP" then
            TG.Groups:ConfirmLeave(key)
        elseif key then
            TG:DeleteThread(key)
            TG:Print("Conversation closed.")
        else
            TG:Print("No conversation selected.")
        end
    elseif cmd == "demo" or verb == "demo" then -- not in the help: sample conversations for screenshots
        TG.Demo:Command(rest and rest:lower() or "")
    elseif cmd == "slaay-mode" or cmd == "slay-mode" or cmd == "slaay" then -- not in the help either
        TG.Slay:Toggle()
    elseif cmd == "test" then
        TG:AddMessage("W:testgnome-gnomeregan",
            { kind = "WHISPER", name = "Testgnome-Gnomeregan", class = "MAGE" },
            false, "Greetings from Gnomeregan! This is a Telegnome test message.")
    else
        TG:Print("v" .. TG.version .. " commands:")
        print("  /tg - open or close the window")
        print("  /tg new - start a new conversation")
        print("  /tg group <name> - create a group chat")
        print("  /tg join <code> - join a group chat")
        print("  /tg channels - choose followed channels")
        print("  /tg mychannels - every chat channel you're in, with Leave buttons")
        print("  /tg opacity <30-100> - main window opacity (" .. (s.opacity or 100) .. "%)")
        print("  /tg dnd - do not disturb (" .. onOff(s.dnd) .. ")")
        print("  /tg theme <name> - colour theme (" .. TG.Style.theme.label .. ")")
        print("  /tg recruit - collect strangers' whispers under Requests (" .. onOff(s.recruiting) .. ")")
        print("  /tg config - settings")
        print("  /tg counter - on-screen missed-messages counter (" .. onOff(s.counter) .. ")")
        print("  /tg hide - hide whispers from the main chat (" .. onOff(s.hideFromChat) .. ")")
        print("  /tg notify - pop-up notifications (" .. onOff(s.notify) .. ")")
        print("  /tg sound - sound for new messages (" .. onOff(s.sound) .. ")")
        print("  /tg only - keep everything out of the main chat (" .. onOff(TG:IsTelegnomeOnly()) .. ")")
        print("  /tg minimap - minimap button (" .. onOff(not TG.db.minimap.hide) .. ")")
        print("  /tg clear - close the selected conversation")
        print("  /tg test - add a fake incoming whisper")
        print("  /tg debug - print raw event info (" .. onOff(s.debug) .. ")")
    end
end
