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

-- Whether a followed channel's unread messages count (red badge, tab and notifier totals), or only show a
-- quiet dot. Party, Raid and Instance count unless switched off; everything else is quiet unless switched on.
local COUNT_DEFAULT = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
function C.Counts(th)
    if not th or th.kind ~= "CHANNEL" then return true end
    if th.count ~= nil then return th.count and true or false end
    return COUNT_DEFAULT[th.ctype] or false
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

-- The game's own colour for each kind of chat, in case its colour table can't be read.
local DEFAULT_COLOR = {
    GUILD = { 0.25, 1, 0.25 }, OFFICER = { 0.25, 0.75, 0.25 }, PARTY = { 0.67, 0.67, 1 },
    RAID = { 1, 0.5, 0 }, INSTANCE_CHAT = { 1, 0.5, 0 }, SAY = { 1, 1, 1 }, YELL = { 1, 0.25, 0.25 },
    CHANNEL = { 1, 0.75, 0.75 },
}

-- A followed channel's colour, the same as in the game's chat (also when you've changed it there).
function C.Color(th)
    local info = ChatTypeInfo and ChatTypeInfo[C.ColorKey(th)]
    if type(info) == "table" and type(info.r) == "number" and type(info.g) == "number" and type(info.b) == "number" then
        return { info.r, info.g, info.b }
    end
    return DEFAULT_COLOR[th.ctype] or DEFAULT_COLOR.CHANNEL
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
    -- followed before, just for a dungeon or raid: its history comes back
    local archive = TG.db.archive
    if archive and type(archive[key]) == "table" then
        th.msgs = archive[key]
        archive[key] = nil
    end
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

-- Word lists ("enchant, ench") for alert words and filtered channels. A word also matches inside longer
-- words, so "ench" finds "enchanter".
local wordCache = {}
function C.Words(src)
    if type(src) ~= "string" or src == "" then return {} end
    local list = wordCache[src]
    if not list then
        list = {}
        for part in src:gmatch("[^,;]+") do
            local word = strtrim(part):lower()
            if #word >= 2 then list[#list + 1] = word end
        end
        wordCache[src] = list
    end
    return list
end

-- The first word of the list found in the text, or nil.
function C.MatchWords(src, text)
    if type(text) ~= "string" then return nil end
    local list = C.Words(src)
    if #list == 0 then return nil end
    local lower = text:lower()
    for _, word in ipairs(list) do
        if lower:find(word, 1, true) then return word end
    end
    return nil
end

-- Alert words: a followed-channel message containing one pops up and plays the sound even when that
-- channel's Pop-up tick is off. The words in Settings count for every channel; a channel can have its own too.
function C.MatchKeyword(text, th)
    return (C.MatchWords(TG.db.settings.keywords, text) or (th and C.MatchWords(th.alertWords, text))) and true or false
end

-- The words as you typed them (matching ignores upper and lower case; names keep yours).
function C.TypedWords(src)
    local list = {}
    if type(src) ~= "string" then return list end
    for part in src:gmatch("[^,;]+") do
        local word = strtrim(part)
        if #word >= 2 then list[#list + 1] = word end
    end
    return list
end

-- "LFW" or "enchant +1": the short label after a filtered channel's name.
function C.FilterLabel(th)
    local list = C.TypedWords(th and th.words)
    if #list == 0 then return nil end
    return #list > 1 and (list[1] .. " +" .. (#list - 1)) or list[1]
end

-- A filtered channel's own name: "Trade [LFW]", whatever you've renamed it to.
function C.AutoName(th)
    local label = C.FilterLabel(th)
    return (th.name or "Channel") .. (label and (" [" .. label .. "]") or "")
end

function C:Rename(key, name)
    local th = TG.db.threads[key]
    if not (th and th.base) then return end
    name = strtrim(name or "")
    th.customName = name ~= "" and name or nil
    UI:RefreshList()
    if UI.selected == key then UI:Select(key) end
    self:RefreshPanel()
end

-- The matching words picked out in gold in a channel message (not in messages with links or colours).
function C.Highlight(th, text)
    if type(text) ~= "string" or text:find("|", 1, true) then return text end
    local words = {}
    for _, src in ipairs({ th.words or "", th.alertWords or "", TG.db.settings.keywords or "" }) do
        for _, w in ipairs(C.Words(src)) do words[#words + 1] = w end
    end
    if #words == 0 then return text end
    local lower, marks = text:lower(), {}
    for _, w in ipairs(words) do
        local from = 1
        while true do
            local a, b = lower:find(w, from, true)
            if not a then break end
            marks[#marks + 1] = { a, b }
            from = b + 1
        end
    end
    if #marks == 0 then return text end
    table.sort(marks, function(x, y) return x[1] < y[1] end)
    local out, pos = {}, 1
    for _, m in ipairs(marks) do
        local a, b = math.max(m[1], pos), m[2]
        if b >= a then
            out[#out + 1] = text:sub(pos, a - 1)
            out[#out + 1] = "|cffffd100" .. text:sub(a, b) .. "|r"
            pos = b + 1
        end
    end
    out[#out + 1] = text:sub(pos)
    return table.concat(out)
end

---------------------------------------------------------------------------
-- Filtered channels: a copy of a channel that keeps only the messages with your words,
-- e.g. "Trade [Enchant]" next to "Trade [Boost]". Each is its own conversation.
---------------------------------------------------------------------------

-- The filtered copies of a channel (by the channel's own key).
function C:ViewsOf(baseKey)
    local out = {}
    for k, th in pairs(TG.db.threads) do
        if th.base == baseKey and th.kind == "CHANNEL" then out[#out + 1] = k end
    end
    return out
end

function C:AddView(from, words, stay)
    if #C.Words(words) == 0 then
        TG:Print("Give at least one word of two letters or more.")
        return
    end
    local base = from.base or from.key
    local n = 1
    while TG.db.threads[base .. "|f" .. n] do n = n + 1 end
    local key = base .. "|f" .. n
    local th = TG:EnsureThread(key, { kind = "CHANNEL", name = from.name })
    th.ctype, th.cname, th.base, th.words = from.ctype, from.cname, base, words
    th.notify = true -- the point of a filter: tell me when it matches
    th.count = true
    th.msgs[#th.msgs + 1] = { t = time(), sys = true,
        text = ("Showing only %s messages with: %s"):format(from.name or "channel", table.concat(C.TypedWords(words), ", ")) }
    UI:RefreshList()
    TG:RefreshUnread()
    if not stay and UI.frame and UI.frame:IsShown() then UI:Select(key) end
    return key
end

function C:SetViewWords(key, words)
    local th = TG.db.threads[key]
    if not (th and th.base) or #C.Words(words) == 0 then return end
    th.words = words
    TG:AddSystemLine(key, "Now showing messages with: " .. table.concat(C.TypedWords(words), ", "))
    UI:RefreshList()
    if UI.selected == key then UI:Select(key) end
end

-- A small box for typing words.
local WORDS_HINT = "\n|cff999999Separate words with commas, e.g. enchant, ench. Upper and lower case don't matter.|r"
function C:AskWords(prompt, current, done, noHint)
    if not noHint then prompt = prompt .. WORDS_HINT end
    if not StaticPopupDialogs.TELEGNOME_WORDS then
        StaticPopupDialogs.TELEGNOME_WORDS = {
            text = "%s",
            button1 = OKAY or "OK",
            button2 = CANCEL or "Cancel",
            hasEditBox = true,
            maxLetters = 200,
            OnShow = function(self, data)
                local box = self.editBox or self.EditBox
                if box then
                    box:SetText((data or self.data).current or "")
                    box:HighlightText()
                end
            end,
            OnAccept = function(self, data)
                local box = self.editBox or self.EditBox
                if box then (data or self.data).done(strtrim(box:GetText())) end
            end,
            EditBoxOnEnterPressed = function(box)
                local p = box:GetParent()
                p.data.done(strtrim(box:GetText()))
                p:Hide()
            end,
            EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
    StaticPopup_Show("TELEGNOME_WORDS", prompt, nil, { current = current, done = done })
end

-- Joining a new group: followed Party, Raid and Instance chat get a divider line, or are emptied (setting).
C.NEW_GROUP_LINE = "- New group -"
local GROUP_TYPES = { "PARTY", "RAID", "INSTANCE_CHAT" }

function C:OnNewGroup()
    local now = GetTime()
    if self.newGroupAt and now - self.newGroupAt < 3 then return end -- two events for one join
    self.newGroupAt = now
    for _, ctype in ipairs(GROUP_TYPES) do
        local key = C.KeyForType(ctype)
        local th = self:IsFollowedKey(key) and TG.db.threads[key]
        if th and #th.msgs > 0 then
            if TG.db.settings.clearGroupChat then
                TG:ClearHistory(key)
            elseif th.msgs[#th.msgs].text ~= C.NEW_GROUP_LINE then
                TG:AddSystemLine(key, C.NEW_GROUP_LINE)
            end
        end
    end
end

do
    local watch = CreateFrame("Frame")
    local wasInGroup
    for _, ev in ipairs({ "GROUP_JOINED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        pcall(watch.RegisterEvent, watch, ev)
    end
    watch:SetScript("OnEvent", function(_, event)
        if not TG.db then return end
        local inGroup = IsInGroup and IsInGroup() and true or false
        if event == "GROUP_JOINED" or (event == "GROUP_ROSTER_UPDATE" and wasInGroup == false and inGroup) then
            C:OnNewGroup()
        end
        wasInGroup = inGroup
    end)
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
    local followed = self:IsFollowedKey(key)
    local views = self:ViewsOf(key)
    if not followed and #views == 0 then return end
    if TG.isSecret(text) or TG.isSecret(sender) or TG.isSecret(guid) then return end

    local outgoing = guid and guid == UnitGUID("player") or false
    local from = Ambiguate and Ambiguate(sender or "?", "short") or sender
    local cls = TG:ClassFromGUID(guid)
    if event == "CHAT_MSG_RAID_WARNING" then text = "[Raid Warning] " .. text end
    if followed then
        TG:AddMessage(key, { kind = "CHANNEL" }, outgoing, text, {
            from = from, cls = cls, alert = (not outgoing) and C.MatchKeyword(text, TG.db.threads[key]) or nil,
        })
    end
    -- filtered copies: messages with their words, and what you sent from that copy
    local sent = self.sent
    for _, vk in ipairs(views) do
        local vt = TG.db.threads[vk]
        local mine = outgoing and sent and sent.th == vt and sent.text == text
        if mine or (not outgoing and C.MatchWords(vt.words, text)) then
            TG:AddMessage(vk, { kind = "CHANNEL" }, outgoing, text, { from = from, cls = cls })
        end
    end
end

function C:Send(th, text)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    self.sent = { th = th, text = text } -- so a filtered copy shows what you wrote from it
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
        root:CreateTitle(th.base and C.AutoName(th) or th.name)
        root:CreateButton(th.fav and "Unpin" or "Pin to the top", function() TG:SetFavorite(key, not th.fav) end)
        UI.AddPinMoveEntries(root, key)
        root:CreateCheckbox("Pop-up notifications",
            function() return th.notify and true or false end,
            function() th.notify = not th.notify end)
        root:CreateCheckbox("Count unread messages (red badge)",
            function() return C.Counts(th) end,
            function() th.count = not C.Counts(th); TG:RefreshUnread(); UI:RefreshList() end)
        root:CreateCheckbox("Show under Channels (off: under More channels)",
            function() return th.inAll ~= false end,
            function() th.inAll = (th.inAll == false) and nil or false; TG:RefreshUnread(); UI:RefreshList() end)
        root:CreateCheckbox("Mute everything (alert words too)",
            function() return th.muted and true or false end,
            function() TG:SetMuted(key, not th.muted) end)
        root:CreateDivider()
        if th.base then
            root:CreateButton("Rename...", function()
                C:AskWords("Name for " .. C.AutoName(th)
                    .. "\n|cff999999Empty: back to " .. C.AutoName(th) .. "|r", th.customName or "",
                    function(name) C:Rename(key, name) end, true)
            end)
            root:CreateButton("Change filter words...", function()
                C:AskWords("Show only " .. (th.name or "channel") .. " messages with these words:", th.words,
                    function(words) C:SetViewWords(key, words) end)
            end)
        else
            root:CreateButton("Alert words for this channel...", function()
                C:AskWords("Alert words for " .. (th.name or "this channel")
                    .. "\n|cff999999A message with one of them pops up, even with Pop-up off. Empty: none.|r"
                    .. WORDS_HINT,
                    th.alertWords, function(words) th.alertWords = words ~= "" and words or nil; UI:RefreshList() end, true)
            end)
        end
        root:CreateButton("New filtered copy...", function()
            C:AskWords("New filtered copy of " .. (th.name or "this channel")
                .. "\n|cff999999It keeps only the messages with these words.|r", "",
                function(words) C:AddView({ key = key, base = th.base, name = th.name, ctype = th.ctype, cname = th.cname }, words) end)
        end)
        root:CreateDivider()
        root:CreateButton("Clear history", function() TG:ConfirmClearHistory(key) end)
        root:CreateButton(th.base and "Remove this filtered copy" or "Unfollow channel", function() C:Unfollow(key) end)
        root:CreateButton("Choose channels...", function() C:OpenPanel("follow") end)
        root:CreateButton("Filtered channels...", function() C:OpenPanel("filter") end)
    end)
end

---------------------------------------------------------------------------
-- Picker panel (opens over the conversation pane)
---------------------------------------------------------------------------

local ROW = 22
local NOTIFY_X_LEFT = 122
local NOTIFY_INSET_RIGHT = 16 -- the right-hand Pop-up column hugs the panel's edge, whatever the window's width

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

    -- two pages, reached from New chat > Channel: Follow a channel and Filtered channels.
    -- Each shows its own title next to Back (they used to be tabs on one page).
    self.backBtn = TG.NewChat.BackButton(f, "follow")
    self.subTabs = {}
    local function subTab(text, id)
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(24)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("LEFT", 0, 0)
        fs:SetText(text)
        b.fs = fs
        b:SetWidth(S.Num(fs:GetStringWidth(), 150) + 4)
        local under = b:CreateTexture(nil, "ARTWORK")
        under:SetPoint("BOTTOMLEFT", 0, -4)
        under:SetPoint("BOTTOMRIGHT", 0, -4)
        under:SetHeight(2)
        S.Paint(under, "hi", 1)
        b.under = under
        b.id = id
        b:EnableMouse(false)
        self.subTabs[#self.subTabs + 1] = b
        return b
    end
    local t1 = subTab("Follow a channel", "follow")
    t1:SetPoint("LEFT", self.backBtn, "RIGHT", 12, 0)
    local t2 = subTab("Filtered channels", "filter")
    t2:SetPoint("LEFT", self.backBtn, "RIGHT", 12, 0)
    local cog = S.Cog(f, 18)
    self.subCog = cog
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -36)
    line:SetPoint("TOPRIGHT", -8, -36)

    local done = S.Button(f, "Close", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    done:SetScript("OnClick", function() C:ClosePanel() end)

    ------------------------------------------------------------ Followed channels
    local pa = CreateFrame("Frame", nil, f)
    pa:SetAllPoints(f)
    self.pageA = pa

    local intro = pa:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 14, -46)
    intro:SetPoint("RIGHT", -14, 0)
    intro:SetJustifyH("LEFT")
    intro:SetSpacing(2)
    intro:SetText("Tick a chat to follow it here, and Pop-up to get the notifier for it.\n"
        .. "Right-click a followed channel for more choices.")

    local function header(text, x, popX)
        local h = pa:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", x, -86)
        h:SetText(text)
        local p = pa:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if popX then
            p:SetPoint("TOP", pa, "TOPLEFT", popX + 12, -88)
        else
            p:SetPoint("TOP", pa, "TOPRIGHT", -(NOTIFY_INSET_RIGHT + 12), -88)
        end
        p:SetText("Pop-up")
    end
    header("Chat types", 14, NOTIFY_X_LEFT)
    header("Your channels", 230)

    for i, b in ipairs(BUILTIN) do
        local y = -106 - (i - 1) * ROW
        local c = S.Check(pa, b.name)
        c:SetPoint("TOPLEFT", 12, y)
        c.ctype = b.id
        c:SetScript("OnClick", function(s)
            local key = C.KeyForType(b.id)
            if s:GetChecked() then C:Follow(b.id) else C:Unfollow(key) end
            C:RefreshPanel()
        end)
        self.builtinChecks[i] = c

        local n = notifyCheck(pa, NOTIFY_X_LEFT, y)
        n:SetScript("OnClick", function(s) setNotify(C.KeyForType(b.id), s:GetChecked()) end)
        self.builtinNotify[i] = n
    end

    local none = pa:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    none:SetPoint("TOPLEFT", 232, -110)
    none:SetText("You're not in any channels.")
    self.noneText = none

    -- Pinned to the bottom so a long "Your channels" column can't run into it.
    local h3 = pa:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h3:SetPoint("BOTTOMLEFT", 14, 96)
    h3:SetText("Options")
    local clear = S.Check(pa, "Clear Party, Raid and Instance chat when I join a new group")
    clear:SetPoint("BOTTOMLEFT", 12, 42)
    clear:SetScript("OnClick", function(s) TG.db.settings.clearGroupChat = s:GetChecked() and true or false end)
    S.Tooltip(clear, "New group, clean chat", "Off: joining a new group adds a \"New group\" line to followed Party, "
        .. "Raid and Instance chat, and the older messages stay. On: those conversations are emptied instead.")
    self.clearCheck = clear
    local hide = S.Check(pa, "Hide followed channels from the main chat")
    hide:SetPoint("BOTTOMLEFT", 12, 68)
    hide:SetScript("OnClick", function(s) TG.db.settings.hideChannels = s:GetChecked() and true or false end)
    S.Tooltip(hide, "Hide from main chat", "Messages in followed channels only show up in Telegnome. "
        .. "Followed channels never count towards the missed-messages counter.")
    self.hideCheck = hide

    ------------------------------------------------------------ Filtered channels
    local pb = CreateFrame("Frame", nil, f)
    pb:SetAllPoints(f)
    pb:Hide()
    self.pageB = pb

    local fIntro = pb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fIntro:SetPoint("TOPLEFT", 14, -46)
    fIntro:SetPoint("RIGHT", -14, 0)
    fIntro:SetJustifyH("LEFT")
    fIntro:SetSpacing(2)
    fIntro:SetText("A filtered channel keeps only the messages with your words, e.g. Trade with enchant, ench.\n"
        .. "It's its own conversation - you don't need to follow the whole channel.")

    local addH = pb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addH:SetPoint("TOPLEFT", 14, -86)
    addH:SetText("Add a filtered channel")

    local chanL = pb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chanL:SetPoint("TOPLEFT", 16, -118)
    chanL:SetText("Channel")
    local pick = S.Button(pb, "", 200, 24)
    pick:SetPoint("TOPLEFT", 80, -111)
    pick.fs:ClearAllPoints()
    pick.fs:SetPoint("LEFT", 10, 0)
    pick.fs:SetPoint("RIGHT", -22, 0)
    pick.fs:SetJustifyH("LEFT")
    local arrow = pick:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetTexture(S.CHEV_DOWN)
    pick:SetScript("OnMouseDown", nil)
    pick:SetScript("OnMouseUp", nil)
    pick:SetScript("OnClick", function(s) C:OpenFilterChannelMenu(s) end)
    self.filterPick = pick

    local wordsL = pb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wordsL:SetPoint("TOPLEFT", 16, -150)
    wordsL:SetText("Words")
    local add = S.Button(pb, "Add", 70, 24, true)
    add:SetPoint("TOPRIGHT", -14, -143)
    local words = S.EditBox(pb)
    words:SetPoint("TOPLEFT", 80, -143)
    words:SetPoint("RIGHT", add, "LEFT", -8, 0)
    words:SetHeight(24)
    words:SetMaxLetters(200)
    S.Tooltip(words, "Words", "Separate them with commas, e.g. enchant, ench. A word also matches inside longer "
        .. "words, so ench finds enchanter.")
    self.filterWords = words
    local function doAdd()
        local opt = C.filterChoice
        local text = strtrim(words:GetText() or "")
        if not opt then
            TG:Print("Choose a channel first.")
            return
        end
        if #C.Words(text) == 0 then
            TG:Print("Type at least one word of two letters or more.")
            return
        end
        C:AddView({ key = opt.key, name = opt.name, ctype = opt.ctype, cname = opt.cname }, text, true)
        words:SetText("")
        words:ClearFocus()
        C:RefreshPanel()
    end
    add:SetScript("OnClick", doAdd)
    words:SetScript("OnEnterPressed", doAdd)

    local listH = pb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listH:SetPoint("TOPLEFT", 14, -190)
    listH:SetText("Your filtered channels")
    self.filterListTop = -212
    local noneF = pb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noneF:SetPoint("TOPLEFT", 16, -214)
    noneF:SetText("None yet.")
    self.filterNone = noneF
    self.filterRows = {}

    self:ShowSub(self.sub or "follow")
end

-- Switches between the Followed channels and Filtered channels pages.
function C:ShowSub(id)
    self.sub = id
    if not self.panel then return end
    self.pageA:SetShown(id == "follow")
    self.pageB:SetShown(id == "filter")
    for _, b in ipairs(self.subTabs) do
        local on = b.id == id
        b:SetShown(on)
        b.under:Hide()
        b.fs:SetTextColor(1, 0.82, 0)
        if on then
            self.subCog:ClearAllPoints()
            self.subCog:SetPoint("LEFT", b.fs, "RIGHT", 8, 0)
        end
    end
    self:RefreshPanel()
end

-- Every chat a filter can watch: the chat types, then the channels you're in.
function C:FilterOptions()
    local out = {}
    for _, b in ipairs(BUILTIN) do
        out[#out + 1] = { key = C.KeyForType(b.id), name = b.name, ctype = b.id }
    end
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local name = list[i + 1]
        if type(name) == "string" and not TG.Groups.IsTelegnomeChannel(name) then
            local n = baseName(name)
            out[#out + 1] = { key = C.KeyForChannel(n), name = n, ctype = "CHANNEL", cname = n }
        end
    end
    return out
end

function C:OpenFilterChannelMenu(anchor)
    local opts = self:FilterOptions()
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        -- no menus: step through the choices
        local cur = 0
        for i, o in ipairs(opts) do if self.filterChoice and o.key == self.filterChoice.key then cur = i end end
        self.filterChoice = opts[cur % #opts + 1]
        self:RefreshPanel()
        return
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle("Chat types")
        for i, o in ipairs(opts) do
            if i == #BUILTIN + 1 then root:CreateTitle("Your channels") end
            root:CreateRadio(o.name,
                function() return C.filterChoice and C.filterChoice.key == o.key end,
                function() C.filterChoice = o; C:RefreshPanel() end)
        end
    end)
end

local function setNotifyState(n, followed, key)
    local th = followed and TG.db.threads[key]
    n:SetChecked(th and th.notify and true or false)
    n:SetEnabled(followed and true or false)
    n:SetAlpha(followed and 1 or 0.4)
end

function C:RefreshFilterPage()
    -- the channel choice: Trade if you're in it, else the first channel, else Guild
    if not self.filterChoice then
        local opts = self:FilterOptions()
        for _, o in ipairs(opts) do
            if o.cname and o.cname:lower() == "trade" then self.filterChoice = o end
        end
        self.filterChoice = self.filterChoice or opts[#BUILTIN + 1] or opts[1]
    end
    self.filterPick:SetText(self.filterChoice and self.filterChoice.name or "Choose...")

    local keys = {}
    for k, th in pairs(TG.db.threads) do
        if th.kind == "CHANNEL" and th.base then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return (TG:ThreadDisplay(a)):lower() < (TG:ThreadDisplay(b)):lower() end)
    local pb = self.pageB
    for i, key in ipairs(keys) do
        local row = self.filterRows[i]
        if not row then
            row = CreateFrame("Button", nil, pb)
            row:SetHeight(22)
            row:SetPoint("TOPLEFT", 12, self.filterListTop - (i - 1) * 24)
            row:SetPoint("RIGHT", -14, 0)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.05)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetPoint("LEFT", 4, 0)
            row.words = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.words:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
            row.words:SetWordWrap(false)
            row.remove = S.Link(row, "Remove")
            row.remove:SetPoint("RIGHT", -2, 0)
            row.words:SetPoint("RIGHT", row.remove, "LEFT", -10, 0)
            row.words:SetJustifyH("LEFT")
            row.remove:SetScript("OnClick", function()
                C:Unfollow(row.key)
                C:RefreshPanel()
            end)
            row:SetScript("OnClick", function()
                local k = row.key
                C:ClosePanel()
                if TG.db.threads[k] then UI:Select(k) end
            end)
            S.Tooltip(row, "Open", "Click to open this filtered channel.")
            self.filterRows[i] = row
        end
        row.key = key
        local name, color = TG:ThreadDisplay(key)
        row.name:SetText(name)
        row.name:SetTextColor(color[1], color[2], color[3])
        local vt = TG.db.threads[key]
        row.words:SetText((vt.customName and (C.AutoName(vt) .. "  \194\183  ") or "")
            .. table.concat(C.TypedWords(vt.words), ", "))
        row:Show()
    end
    -- as many rows as fit above the Close button; the rest are in the conversation list anyway
    local fit = math.max(1, math.floor((S.Num(pb:GetHeight(), 430) + self.filterListTop - 44) / 24))
    for i = 1, #keys do self.filterRows[i]:SetShown(i <= fit) end
    for i = #keys + 1, #self.filterRows do self.filterRows[i]:Hide() end
    self.filterNone:ClearAllPoints()
    if #keys == 0 then
        self.filterNone:SetPoint("TOPLEFT", 16, self.filterListTop - 2)
        self.filterNone:SetText("None yet.")
        self.filterNone:Show()
    elseif #keys > fit then
        self.filterNone:SetPoint("TOPLEFT", 16, self.filterListTop - fit * 24 - 2)
        self.filterNone:SetText(("And %d more under Channels in Chats."):format(#keys - fit))
        self.filterNone:Show()
    else
        self.filterNone:Hide()
    end
end

function C:RefreshPanel()
    if not self.panel then return end
    if self.sub == "filter" then
        self:RefreshFilterPage()
        return
    end
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
        if th.kind == "CHANNEL" and th.ctype == "CHANNEL" and th.cname and not th.base and not seen[th.cname:lower()] then
            names[#names + 1] = th.cname
            seen[th.cname:lower()] = true
        end
    end

    local pa = self.pageA
    for i, name in ipairs(names) do
        local c = self.channelChecks[i]
        if not c then
            local y = -106 - (i - 1) * ROW
            c = S.Check(pa, "")
            c:SetPoint("TOPLEFT", 228, y)
            c.label:SetJustifyH("LEFT")
            c.label:SetWordWrap(false)
            c:SetScript("OnClick", function(s)
                if s:GetChecked() then C:Follow("CHANNEL", s.cname) else C:Unfollow(C.KeyForChannel(s.cname)) end
                C:RefreshPanel()
            end)
            self.channelChecks[i] = c

            local n = notifyCheck(pa, 0, y)
            n:ClearAllPoints()
            n:SetPoint("TOPRIGHT", -NOTIFY_INSET_RIGHT, y)
            c.label:SetPoint("RIGHT", n, "LEFT", -8, 0) -- long channel names are cut off before the Pop-up tick
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
    self.clearCheck:SetChecked(TG.db.settings.clearGroupChat and true or false)
end

function C:IsPanelShown()
    return self.panel and self.panel:IsShown() or false
end

function C:OpenPanel(sub)
    if sub then self.sub = sub end
    UI:Show()
    if UI.tab ~= "all" then UI:SetTab("all") end
    if TG.NewChat then TG.NewChat:Close() end
    self:CreatePanel()
    TG.Settings:Close()
    TG.Picker:Close()
    TG.Groups:ClosePanel()
    TG.ChannelList:Close()
    TG.Requests:ClosePanel()
    self:ShowSub(self.sub or "follow")
    self.panel:Show()
    UI.newBtn:SetText("Cancel")
end

function C:ClosePanel()
    if not self:IsPanelShown() then return end
    self.panel:Hide()
    UI:UpdateNewButton()
    if UI.frame:IsShown() then
        local key = UI.selected or UI:FirstKey()
        if key then UI:Select(key) end
    end
end

function C:TogglePanel()
    if self:IsPanelShown() then self:ClosePanel() else self:OpenPanel() end
end
