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
        sound = true,         -- play the tell sound when whispers are hidden from chat
        notify = true,        -- notifier grows to show new messages
        notifyFrom = "all",   -- "all" | "friendsguild" | "friends"
        counter = true,       -- show the on-screen missed-messages counter
        counterHideEmpty = false, -- hide the counter when nothing is unread
        notifyGroups = true,  -- notifier also pops up for group chat messages
        notifyChannels = false, -- notifier pops up for followed channels
        hideChannels = false, -- hide followed channels from the main chat
        toastGrow = "right",  -- notifier grows "right" or "left"
        maxPerThread = 200,   -- messages kept per conversation
    },
    minimap = { hide = false, angle = 200 },
    threads = {},  -- open conversations with history
    contacts = {}, -- everyone you've talked to (kept when a conversation is closed)
    seq = 0,
}

local WHISPER_EVENTS = { CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true }
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

function TG.FullName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if not name:find("-", 1, true) then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName()
        if realm and realm ~= "" then name = name .. "-" .. realm end
    end
    return name
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
            class = c and c.class, guid = c and c.guid, msgs = {}, unread = 0,
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
    msgs[#msgs + 1] = {
        t = time(), out = outgoing or nil, text = text,
        from = extra and extra.from, cls = extra and extra.cls,
    }
    local max = db.settings.maxPerThread or 200
    while #msgs > max do table.remove(msgs, 1) end

    if outgoing then
        th.unread = 0
    elseif not self.UI:IsViewing(key) then
        th.unread = (th.unread or 0) + 1
        if th.kind ~= "GROUP" and th.kind ~= "CHANNEL" and db.settings.sound and db.settings.hideFromChat
            and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
            PlaySound(SOUNDKIT.TELL_MESSAGE)
        end
        self.Toast:OnIncoming(key, text, extra and extra.from)
    end

    self.UI:OnThreadUpdated(key, not outgoing)
    self:RefreshUnread()
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
    if th and th.kind == "GROUP" then return self.db.settings.notifyGroups end
    if th and th.kind == "CHANNEL" then return self.db.settings.notifyChannels end
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
        send(text, "WHISPER", nil, th.name)
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

    self:AddMessage(key, info, outgoing, text)

    -- Hidden messages skip the default handler, so keep R (reply) working.
    if not outgoing and self.db.settings.hideFromChat and ChatEdit_SetLastTellTarget then
        pcall(ChatEdit_SetLastTellTarget, sender, BN_EVENTS[event] and "BN_WHISPER" or "WHISPER")
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

local function chatFilter(_, _, msg)
    if TG.db and TG.db.settings.hideFromChat and not isSecret(msg) then
        return true
    end
    return false
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
        for ev in pairs(WHISPER_EVENTS) do self:RegisterEvent(ev) end
        for ev in pairs(BN_EVENTS) do self:RegisterEvent(ev) end
        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("BN_FRIEND_INFO_CHANGED")
        self:RegisterEvent("FRIENDLIST_UPDATE")
        for ev in pairs(TG.Groups.EVENTS) do self:RegisterEvent(ev) end
        for ev in pairs(TG.Channels.EVENTS) do self:RegisterEvent(ev) end
        TG:InstallChatFilter()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        TG.Minimap:Create()
        TG.Toast:Update()
    elseif event == "BN_FRIEND_INFO_CHANGED" or event == "FRIENDLIST_UPDATE" then
        TG:QueueRefresh()
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
        TG:Print("Sound for hidden whispers: " .. onOff(s.sound))
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
        print("  /tg config - settings")
        print("  /tg counter - on-screen missed-messages counter (" .. onOff(s.counter) .. ")")
        print("  /tg hide - hide whispers from the main chat (" .. onOff(s.hideFromChat) .. ")")
        print("  /tg notify - pop-up notifications (" .. onOff(s.notify) .. ")")
        print("  /tg sound - sound for hidden whispers (" .. onOff(s.sound) .. ")")
        print("  /tg minimap - minimap button (" .. onOff(not TG.db.minimap.hide) .. ")")
        print("  /tg clear - close the selected conversation")
        print("  /tg test - add a fake incoming whisper")
        print("  /tg debug - print raw event info (" .. onOff(s.debug) .. ")")
    end
end
