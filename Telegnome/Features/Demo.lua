-- Telegnome: sample conversations for screenshots.
--   /tg demo        show them (your real conversations are put aside, untouched)
--   /tg demo msg    a sample friend writes, so the notifier pops up
--   /tg demo off    back to your real conversations (also happens on logout or /reload)
-- Nothing typed in demo mode is sent to anyone. Not listed in /tg help.

local _, ns = ...
local TG = ns.TG
local UI = TG.UI
local D = { on = false }
TG.Demo = D

local MIN = 60

-- { minutes ago, outgoing?, text, from, class }
local PEOPLE = {
    { key = "BN:Mirelle#2114", kind = "BN", name = "Mirelle", battleTag = "Mirelle#2114", fav = true, sec = "friends",
      online = true, msgs = {
        { 190, false, "Are you raiding tonight?" },
        { 188, true, "Yes! Invites go out at 20:00." },
        { 187, false, "Perfect. I'll bring flasks for everyone." },
        { 42, false, "Got the trinket from the weekly, finally" },
        { 41, true, "No way, grats!" },
        { 3, false, "Logging on in five, save me a spot" },
      } },
    { key = "W:tinkspark-gnomeregan", kind = "WHISPER", name = "Tinkspark-Gnomeregan", class = "MAGE", fav = true,
      sec = "friends", msgs = {
        { 300, false, "The portal to Gnomeregan is on cooldown again..." },
        { 298, true, "Classic. I'll take the tram." },
        { 55, false, "Can you craft me that goggles upgrade later?" },
        { 54, true, "Sure, send me the mats." },
      } },
    { key = "W:brakk-gnomeregan", kind = "WHISPER", name = "Brakk-Gnomeregan", class = "WARRIOR", sec = "friends",
      msgs = {
        { 120, false, "Tank here if you need one for the key" },
        { 118, true, "Yes please, forming up now" },
        { 20, false, "omw" },
      }, unread = 1 },
    { key = "BN:Elowen#1877", kind = "BN", name = "Elowen", battleTag = "Elowen#1877", sec = "friends", online = false,
      msgs = {
        { 1500, false, "Thanks for the run yesterday!" },
        { 1490, true, "Anytime. Same time next week?" },
      } },
    { key = "W:sprocketta-gnomeregan", kind = "WHISPER", name = "Sprocketta-Gnomeregan", class = "ROGUE", sec = "friends",
      msgs = {
        { 15, false, "Found a rare spawn in Mechagon, want in?" },
        { 14, false, "It's still up, hurry!" },
      }, unread = 2 },
    { key = "W:lootgobbler-gnomeregan", kind = "WHISPER", name = "Lootgobbler-Gnomeregan", class = "HUNTER", sec = "others",
      msgs = { { 9, false, "inv pls, 2.9k score" } }, unread = 1 },
    { key = "W:dungeonbob-gnomeregan", kind = "WHISPER", name = "Dungeonbob-Gnomeregan", class = "PALADIN", sec = "others",
      msgs = { { 11, false, "Still need a healer?" }, { 10, true, "We're full, sorry!" } } },
    { key = "W:pewpewlol-gnomeregan", kind = "WHISPER", name = "Pewpewlol-Gnomeregan", class = "WARLOCK", sec = "others",
      msgs = { { 12, false, "can i come" } } },
}

local GROUPS = {
    { key = "G:tgn0000000000a1", name = "Raid night", code = "cog-gear-flux-417", msgs = {
        { 95, false, "Who's bringing the feast?", "Mirelle", "PRIEST" },
        { 94, false, "Me. And repair bots, obviously.", "Tinkspark", "MAGE" },
        { 93, true, "Pull timer at 20:05, be on time this week" },
        { 92, false, "No promises", "Brakk", "WARRIOR" },
        { 6, false, "Summons are up at the stone", "Sprocketta", "ROGUE" },
      } },
    { key = "G:tgn0000000000b2", name = "Gnomeregan Reunion", code = "sprocket-whistle-gizmo-427", msgs = {
        { 400, false, "Old guild meetup on Saturday?", "Elowen", "DRUID" },
        { 398, false, "I'm in!", "Tinkspark", "MAGE" },
        { 30, false, "Bring your worst transmog", "Brakk", "WARRIOR" },
      }, unread = 3 },
}

local CHANNELS = {
    { key = "C:GUILD", name = "Guild", ctype = "GUILD", msgs = {
        { 70, false, "Guild bank has free flasks for raiders", "Mirelle", "PRIEST" },
        { 65, false, "ty!", "Brakk", "WARRIOR" },
        { 8, false, "LFM for a +12, need a healer", "Sprocketta", "ROGUE" },
      }, unread = 1 },
    { key = "C:PARTY", name = "Party", ctype = "PARTY", msgs = {
        { 25, false, "Skip the left pack", "Brakk", "WARRIOR" },
        { 24, true, "Got it" },
      } },
    { key = "C:CH:trade", name = "Trade", ctype = "CHANNEL", cname = "Trade", msgs = {
        { 5, false, "WTS gnomish army knife, cheap", "Lootgobbler", "HUNTER" },
        { 4, false, "LF enchanter, my mats + tip", "Dungeonbob", "PALADIN" },
      } },
}

-- Incoming messages for /tg demo msg, in turn.
local PINGS = {
    { "W:sprocketta-gnomeregan", "The rare just dropped a mount!!" },
    { "BN:Mirelle#2114", "On my way - two minutes." },
    { "G:tgn0000000000a1", "Ready check in 5", "Mirelle", "PRIEST" },
    { "W:brakk-gnomeregan", "Key's in, ready when you are" },
    { "W:tinkspark-gnomeregan", "Mats sent, check your mail" },
}

local function build()
    local now = time()
    local threads, contacts, seq = {}, {}, 0
    local function add(key, th, list)
        th.demo, th.msgs, th.unread = true, {}, th.unread or 0
        local newest = 0
        for _, m in ipairs(list) do
            local t = now - m[1] * MIN
            th.msgs[#th.msgs + 1] = { t = t, out = m[2] or nil, text = m[3], from = m[4], cls = m[5] }
            if t > newest then newest = t end
        end
        th.last = newest
        threads[key] = th
    end
    for _, p in ipairs(PEOPLE) do
        add(p.key, { kind = p.kind, name = p.name, battleTag = p.battleTag, class = p.class, fav = p.fav or nil,
            demoSec = p.sec, demoOnline = p.online, unread = p.unread }, p.msgs)
        contacts[p.key] = { kind = p.kind, name = p.name, battleTag = p.battleTag, class = p.class, last = now,
            fav = p.fav or nil, demo = true, demoOnline = p.online }
    end
    for _, g in ipairs(GROUPS) do
        add(g.key, { kind = "GROUP", name = g.name, code = g.code, channel = g.key:sub(3), unread = g.unread }, g.msgs)
    end
    for _, c in ipairs(CHANNELS) do
        add(c.key, { kind = "CHANNEL", name = c.name, ctype = c.ctype, cname = c.cname, notify = false, unread = c.unread }, c.msgs)
    end
    -- newest conversation first
    local keys = {}
    for k in pairs(threads) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return threads[a].last < threads[b].last end)
    for _, k in ipairs(keys) do
        seq = seq + 1
        threads[k].order = seq
    end
    return threads, contacts, seq
end

function D:Start()
    if self.on then return end
    local db = TG.db
    self.saved = {
        threads = db.threads, contacts = db.contacts, seq = db.seq, collapsed = db.collapsed,
        pendingInvite = db.pendingInvite,
    }
    db.threads, db.contacts, db.seq = build()
    db.collapsed, db.pendingInvite = {}, nil
    self.on, self.ping = true, 0
    UI.selected = nil
    UI:Show()
    UI:CloseOverlays()
    UI:SetTab("dm")
    UI:Select("W:tinkspark-gnomeregan")
    TG:RefreshUnread()
    TG:Print("Demo on: sample conversations for screenshots. Your own conversations are put aside and come back "
        .. "with /tg demo off (or when you log out). /tg demo msg makes a sample friend write. "
        .. "Real whispers that arrive meanwhile are not saved in Telegnome.")
end

-- quiet: on logout, when there is nobody to tell and no window to refresh
function D:Stop(quiet)
    if not self.on then return end
    local db, s = TG.db, self.saved
    db.threads, db.contacts, db.seq, db.collapsed, db.pendingInvite = s.threads, s.contacts, s.seq, s.collapsed, s.pendingInvite
    self.on, self.saved = false, nil
    if quiet then return end
    UI.selected = nil
    if UI.frame then
        UI:ShowEmpty()
        UI:RefreshList()
        local first = UI:SortedKeys()[1]
        if first and UI.frame:IsShown() then UI:Select(first) end
    end
    TG:RefreshUnread()
    TG:Print("Demo off: your own conversations are back.")
end

-- A sample friend writes (someone other than the open conversation, so the notifier shows).
function D:Ping()
    if not self.on then self:Start() end
    for _ = 1, #PINGS do
        self.ping = self.ping % #PINGS + 1
        local p = PINGS[self.ping]
        if TG.db.threads[p[1]] and not UI:IsViewing(p[1]) then
            TG:AddMessage(p[1], { kind = TG.db.threads[p[1]].kind }, false, p[2], p[3] and { from = p[3], cls = p[4] } or nil)
            return
        end
    end
end

function D:Command(arg)
    if arg == "msg" or arg == "message" or arg == "ping" then
        self:Ping()
    elseif arg == "off" or arg == "stop" then
        self:Stop()
    elseif arg == "on" or arg == "start" then
        self:Start()
    elseif self.on then
        self:Stop()
    else
        self:Start()
    end
end

-- Never let the samples reach the saved file.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function() D:Stop(true) end)
