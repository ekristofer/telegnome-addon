-- Telegnome: followed channels (guild, party, raid, say, General, Trade, custom channels...).
-- Messages are copied into the "Followed channels" tab and can be answered from there.
-- They stay in the main chat unless "Hide followed channels from the main chat" is on.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local C = { builtinChecks = {}, channelChecks = {} }
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
    TG:AddMessage(key, { kind = "CHANNEL" }, outgoing, text, { from = from, cls = TG:ClassFromGUID(guid) })
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
        local msg = ...
        if TG.isSecret(msg) then return false end
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
        root:CreateButton("Unfollow channel", function() C:Unfollow(key) end)
        root:CreateButton("Choose channels...", function() C:OpenPanel() end)
    end)
end

---------------------------------------------------------------------------
-- Picker panel (opens over the conversation pane)
---------------------------------------------------------------------------

local ROW = 22

function C:CreatePanel()
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
    intro:SetText("Tick the chats you want in Telegnome. You can read and reply to them in this tab.")

    local h1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h1:SetPoint("TOPLEFT", 14, -68)
    h1:SetText("Chat types")
    for i, b in ipairs(BUILTIN) do
        local c = S.Check(f, b.name)
        c:SetPoint("TOPLEFT", 12, -86 - (i - 1) * ROW)
        c.ctype = b.id
        c:SetScript("OnClick", function(s)
            local key = C.KeyForType(b.id)
            if s:GetChecked() then C:Follow(b.id) else C:Unfollow(key) end
        end)
        self.builtinChecks[i] = c
    end

    local h2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h2:SetPoint("TOPLEFT", 230, -68)
    h2:SetText("Your channels")
    local none = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    none:SetPoint("TOPLEFT", 232, -90)
    none:SetText("You're not in any channels.")
    self.noneText = none

    local optY = -86 - #BUILTIN * ROW - 10
    local h3 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h3:SetPoint("TOPLEFT", 14, optY)
    h3:SetText("Options")
    local hide = S.Check(f, "Hide followed channels from the main chat")
    hide:SetPoint("TOPLEFT", 12, optY - 18)
    hide:SetScript("OnClick", function(s) TG.db.settings.hideChannels = s:GetChecked() and true or false end)
    S.Tooltip(hide, "Hide from main chat", "Messages in followed channels only show up in Telegnome.")
    self.hideCheck = hide
    local notify = S.Check(f, "Pop up for followed channel messages")
    notify:SetPoint("TOPLEFT", 12, optY - 18 - ROW)
    notify:SetScript("OnClick", function(s) TG.db.settings.notifyChannels = s:GetChecked() and true or false end)
    S.Tooltip(notify, "Pop-ups", "Off by default - busy channels like Trade can get noisy. "
        .. "Followed channels never count towards the missed-messages counter.")
    self.notifyCheck = notify

    local done = S.Button(f, "Close", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    done:SetScript("OnClick", function() C:ClosePanel() end)
end

function C:RefreshPanel()
    if not self.panel then return end
    for _, c in ipairs(self.builtinChecks) do
        c:SetChecked(self:IsFollowedKey(C.KeyForType(c.ctype)))
    end

    -- Joined numbered channels (General, Trade, custom...), excluding Telegnome group channels.
    local list = { GetChannelList() }
    local names = {}
    for i = 1, #list, 3 do
        local name = list[i + 1]
        if type(name) == "string" and not name:lower():find("^tgn") then
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
            c = S.Check(self.panel, "")
            c:SetPoint("TOPLEFT", 228, -86 - (i - 1) * ROW)
            c:SetScript("OnClick", function(s)
                if s:GetChecked() then C:Follow("CHANNEL", s.cname) else C:Unfollow(C.KeyForChannel(s.cname)) end
            end)
            self.channelChecks[i] = c
        end
        c.cname = name
        c.label:SetText(name)
        c:SetChecked(self:IsFollowedKey(C.KeyForChannel(name)))
        c:Show()
    end
    for i = #names + 1, #self.channelChecks do self.channelChecks[i]:Hide() end
    self.noneText:SetShown(#names == 0)

    self.hideCheck:SetChecked(TG.db.settings.hideChannels)
    self.notifyCheck:SetChecked(TG.db.settings.notifyChannels)
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
