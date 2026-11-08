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

G.EVENTS = { CHAT_MSG_CHANNEL = true, PLAYER_ENTERING_WORLD = true }

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

local INVITE_FMT = '[Telegnome] Join my group chat "%s" - code: %s'

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

function G.NewCode()
    local w1, w2, w3 = WORDS[math.random(#WORDS)], WORDS[math.random(#WORDS)], WORDS[math.random(#WORDS)]
    return ("%s-%s-%s-%d"):format(w1, w2, w3, math.random(10, 99))
end

function G.KeyFor(channel)
    return "G:" .. channel:lower()
end

function G.ParseInvite(text)
    if type(text) ~= "string" then return nil end
    local name, code = text:match('^%[Telegnome%] Join my group chat "(.-)" %- code: (%S+)')
    return code, name
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
    if not th.channel or channelID(th.channel) > 0 then return end
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
        if initial or reload then C_Timer.After(initial and 10 or 3, function() G:RejoinAll() end) end
        return
    end

    local text, sender = ...
    local base = select(9, ...)
    local guid = select(12, ...)
    if TG.isSecret(text) or TG.isSecret(sender) or TG.isSecret(base) or TG.isSecret(guid) then return end
    if type(base) ~= "string" then return end
    local key = G.KeyFor(base)
    if not TG.db.threads[key] then return end

    local outgoing = (guid and guid == UnitGUID("player"))
        or (Ambiguate and Ambiguate(sender or "", "short") == UnitName("player"))
    local from = Ambiguate and Ambiguate(sender or "?", "short") or sender
    TG:AddMessage(key, { kind = "GROUP" }, outgoing, text, { from = from, cls = TG:ClassFromGUID(guid) })
end

function G:InstallChatFilter(add)
    local function filter(_, _, ...)
        local base = select(9, ...)
        if type(base) == "string" and not TG.isSecret(base) and TG.db and TG.db.threads[G.KeyFor(base)] then
            return true
        end
        return false
    end
    for _, ev in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER",
        "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
        add(ev, filter)
    end
end

---------------------------------------------------------------------------
-- Create / join / leave / invite
---------------------------------------------------------------------------

local function systemLine(th, text)
    th.msgs[#th.msgs + 1] = { t = time(), sys = true, text = text }
end

function G:Join(code, name, created)
    local c, channel, pass = G.Derive(code)
    if #c < 6 then
        TG:Print("That invite code looks too short.")
        return nil
    end
    local key = G.KeyFor(channel)
    local th = TG.db.threads[key]
    if not th then
        name = strtrim(((name or ""):gsub("|", "")))
        if name == "" then name = "Group " .. (c:match("^[^%-]+") or c) end
        th = TG:EnsureThread(key, { kind = "GROUP", name = name, code = c, channel = channel, pass = pass })
        if created then
            systemLine(th, "Group created. Invite code: " .. c .. " - right-click the group name to invite people.")
        else
            systemLine(th, "You joined the group.")
        end
    end
    self:JoinChannel(th)
    self:ClosePanel()
    UI:Show()
    UI:Select(key)
    return key, th
end

function G:Create(name)
    name = strtrim(((name or ""):gsub("|", "")))
    if name == "" then name = "Group chat" end
    local key = self:Join(G.NewCode(), name, true)
    if key then self:ShowCode(key) end
    return key
end

function G:Leave(key)
    local th = TG.db.threads[key]
    if not th then return end
    local leave = LeaveChannelByName or (C_ChatInfo and C_ChatInfo.LeaveChannelByName)
    if leave and th.channel then pcall(leave, th.channel) end
    TG:Print(("Left the group \"%s\". Its invite code was: %s"):format(th.name, th.code or "?"))
    TG:DeleteThread(key)
end

function G:InviteKey(groupKey, contactKey)
    local th = TG.db.threads[groupKey]
    if not th then return end
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

    StaticPopupDialogs.TELEGNOME_CODE = {
        text = "Invite code for \"%s\"\n\nPress Ctrl+C to copy it and share it with friends who use Telegnome.",
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
    ensurePopups()
    StaticPopup_Show("TELEGNOME_CODE", th.name, nil, th.code)
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
        root:CreateButton("Show invite code", function() G:ShowCode(key) end)
        local invite = root:CreateButton("Invite")
        for i = 1, math.min(#recent, 12) do
            local r = recent[i]
            local name = TG:DisplayFor(r.key, r.c)
            invite:CreateButton(name, function() G:InviteKey(key, r.key) end)
        end
        invite:CreateButton("Other player...", function() G:AskInvite(key) end)
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
    f:SetBackdropColor(0.11, 0.08, 0.05, 1)
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
        .. "Share its invite code with friends who use Telegnome - they join by entering the code below.")

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
    codeBox:SetMaxLetters(60)
    local codeHint = codeBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    codeHint:SetPoint("LEFT", 8, 0)
    codeHint:SetText("Invite code")
    codeBox:SetScript("OnTextChanged", function(s) codeHint:SetShown(s:GetText() == "") end)

    local joinName = S.EditBox(f)
    joinName:SetPoint("TOPLEFT", 14, -210)
    joinName:SetSize(220, 26)
    joinName:SetMaxLetters(40)
    local joinNameHint = joinName:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    joinNameHint:SetPoint("LEFT", 8, 0)
    joinNameHint:SetText("Name it (optional)")
    joinName:SetScript("OnTextChanged", function(s) joinNameHint:SetShown(s:GetText() == "") end)

    local joinBtn = S.Button(f, "Join", 90, 26)
    joinBtn:SetPoint("LEFT", codeBox, "RIGHT", 8, 0)
    local function doJoin()
        local code, n = codeBox:GetText(), joinName:GetText()
        if strtrim(code) == "" then return end
        codeBox:SetText("")
        joinName:SetText("")
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
    note:SetPoint("TOPLEFT", 14, -248)
    note:SetPoint("RIGHT", -14, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Members need to be able to join the same chat channels as you (usually the same realm and faction).")

    local done = S.Button(f, "Close", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    done:SetScript("OnClick", function() G:ClosePanel() end)
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
    self.panel:Show()
    UI.newBtn:SetText("Cancel")
    self.nameBox:SetFocus()
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
