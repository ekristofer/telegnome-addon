-- Telegnome: Requests. While you (or your group) are listed in the group finder, whispers
-- from people you don't know are collected in their own tab, with class, level and an
-- Invite button, instead of piling up under Direct messages.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local R = { rows = {}, offset = 0 }
TG.Requests = R

local ROW_H = 54     -- a request card
local PITCH = 60     -- from one card to the next

---------------------------------------------------------------------------
-- When is it collecting?
---------------------------------------------------------------------------

-- Listed in the group finder (premade groups)?
function R:IsListed()
    if not (C_LFGList and C_LFGList.HasActiveEntryInfo) then return false end
    local ok, listed = pcall(C_LFGList.HasActiveEntryInfo)
    return ok and listed and true or false
end

-- Your listing to look after: listed, and alone or leading the group.
function R:IsHosting()
    if not TG.db.settings.requestsTab or not self:IsListed() then return false end
    if IsInGroup and IsInGroup() and UnitIsGroupLeader and not UnitIsGroupLeader("player") then return false end
    return true
end

-- Collecting: hosting with the tick in the Requests view on (the default), or /tg recruit.
function R:IsActive()
    local s = TG.db.settings
    return s.recruiting or (s.requestsCollect ~= false and self:IsHosting()) or false
end

function R:Keys()
    local threads, keys = TG.db.threads, {}
    for key, th in pairs(threads) do
        if th.req then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b) return (threads[a].order or 0) > (threads[b].order or 0) end)
    return keys
end

function R:TabVisible()
    if not TG.db then return false end
    if self:IsActive() or self:IsHosting() then return true end
    for _, th in pairs(TG.db.threads) do
        if th.req then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Level: from the whisper itself, from a group finder application, or /who
---------------------------------------------------------------------------

-- Words that say a nearby number is a character level ("70 mage", "prot 80").
local HINTS = {}
-- WoW Forever has the classic classes: warrior, paladin, hunter, rogue, priest, shaman, mage, warlock, druid.
for word in ([[warrior war warr paladin pala pally hunter hunt rogue priest shaman sham shammy
    mage warlock lock druid dudu tank healer heal heals dps holy prot ret fury arms frost fire
    arcane resto balance boomkin feral shadow disc bm mm surv ele enh enhance aff affli destro demo
    bear cat assa sub combat]]):gmatch("%a+") do
    HINTS[word] = true
end
-- ...and words that say it is something else ("480 ilvl", "2900 io").
local NOT_LEVEL = { ilvl = true, ilevel = true, io = true, gs = true, k = true, rio = true, score = true,
    cr = true, rating = true, g = true, gold = true, min = true, mins = true, sec = true, hp = true }

local function maxLevel()
    local m = GetMaxPlayerLevel and GetMaxPlayerLevel()
    return (type(m) == "number" and m > 0) and m or 60
end

-- "lvl 70", "level 45 priest", "70 mage here", "mage 70" -> the level, or nil.
function R.ParseLevel(text)
    if type(text) ~= "string" then return nil end
    local lower = " " .. text:lower() .. " "
    local cap = maxLevel()
    local function valid(n)
        n = tonumber(n)
        return n and n >= 1 and n <= cap and n or nil
    end
    for _, pat in ipairs({ "%f[%a]le?ve?l%s*[:%.]?%s*(%d+)", "%f[%a]lv%.?%s*(%d+)", "(%d+)%s*le?ve?l%f[%A]", "(%d+)%s*lv%f[%A]" }) do
        local n = valid(lower:match(pat))
        if n then return n end
    end
    for pos, num, after in lower:gmatch("()(%d+)()") do
        local prev, nxt = lower:sub(pos - 1, pos - 1), lower:sub(after, after)
        local decimal = nxt == "." and lower:sub(after + 1, after + 1):find("%d")
        if not prev:find("[%d%.%+,/:]") and not nxt:find("[%dk%%/:]") and not decimal then
            local before = lower:sub(1, pos - 1):match("(%a+)[%s,:%-%(]*$")
            local behind = lower:sub(after):match("^[%s,%)]*(%a+)")
            if not (behind and NOT_LEVEL[behind]) and ((before and HINTS[before]) or (behind and HINTS[behind])) then
                local n = valid(num)
                if n then return n end
            end
        end
    end
    return nil
end

local ROLE_NAMES = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }

-- The classes, in the order they're shown above the requests (WoW Forever has the classic ones).
R.CLASSES = { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "HUNTER", "WARLOCK" }

-- The class from the first whisper (or from Check), or "UNKNOWN".
function R.ClassOf(th)
    local c = th and th.class
    return (type(c) == "string" and c ~= "") and c or "UNKNOWN"
end

-- People who applied through the group finder come with level, class, role and item level.
function R:ScanApplicants()
    if not (C_LFGList and C_LFGList.GetApplicants and C_LFGList.GetApplicantInfo and C_LFGList.GetApplicantMemberInfo) then
        return
    end
    if self.scanning or not self:IsListed() then return end
    -- Applications are for the group leader (and raid assistants); ordinary members have none to read.
    if IsInGroup and IsInGroup() and UnitIsGroupLeader and not UnitIsGroupLeader("player")
        and not (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) then
        return
    end
    self.scanning = true
    local okScan, err = pcall(self.DoScanApplicants, self)
    self.scanning = false
    if not okScan then TG:Debug("Applicant scan failed: " .. tostring(err)) end
end

function R:DoScanApplicants()
    local ok, ids = pcall(C_LFGList.GetApplicants)
    if not ok or type(ids) ~= "table" then return end
    local changed = false
    for _, id in ipairs(ids) do
        local okInfo, info = pcall(C_LFGList.GetApplicantInfo, id)
        local members = okInfo and type(info) == "table" and info.numMembers or 0
        for i = 1, members do
            local okM, name, class, _, level, ilvl, _, _, _, _, role = pcall(C_LFGList.GetApplicantMemberInfo, id, i)
            if okM and type(name) == "table" then -- newer clients hand back one table
                local m = name
                name, class, level, ilvl, role = m.name, m.class or m.classFilename, m.level, m.itemLevel, m.assignedRole
            end
            if okM and type(name) == "string" and not TG.isSecret(name) then
                local full = TG.FullName(name)
                local th = full and TG.db.threads[TG.WhisperKey(full)]
                if th then
                    if type(level) == "number" and level > 0 and th.level ~= level then th.level, changed = level, true end
                    if type(class) == "string" and class ~= "" and not th.class then th.class, changed = class, true end
                    if type(ilvl) == "number" and ilvl > 0 and th.ilvl ~= math.floor(ilvl) then
                        th.ilvl, changed = math.floor(ilvl), true
                    end
                    if ROLE_NAMES[role] and th.role ~= role then th.role, changed = role, true end
                    if not th.applied then th.applied, changed = true, true end
                end
            end
        end
    end
    if changed then self:Refresh() end
end

-- The game only answers /who every few seconds. It doesn't say exactly how long, so this is a safe wait.
local WHO_COOLDOWN = 5

-- The Check buttons count down until the next look-up is possible.
function R:UpdateLookupButtons()
    local left = (self.whoReady or 0) - GetTime()
    for _, row in ipairs(self.rows) do
        if row.key then
            if left > 0 then
                row.lookup:SetText(math.ceil(left) .. "s")
                row.lookup:SetEnabled(false)
            else
                row.lookup:SetText("Check")
                row.lookup:SetEnabled(true)
            end
        end
    end
    if left > 0 then
        self:UpdateStatus()
    elseif self.panel and self.cooling then
        self.cooling = false
        self.checkNote = nil
        self.panel:SetScript("OnUpdate", nil)
        self:UpdateStatus()
    end
end

function R:StartCooldown()
    self.whoReady = GetTime() + WHO_COOLDOWN
    if self.panel then
        self.cooling = true
        local acc = 0
        self.panel:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + (elapsed or 0)
            if acc >= 0.2 then
                acc = 0
                R:UpdateLookupButtons()
            end
        end)
    end
    self:UpdateLookupButtons()
end

-- /who for one person (needs a click; the game limits how often it answers).
function R:LookUp(key)
    local th = TG.db.threads[key]
    if not th or th.kind ~= "WHISPER" then return end
    if TG.Demo and TG.Demo.on then return end
    if GetTime() < (self.whoReady or 0) then return end
    if not (C_FriendList and C_FriendList.SendWho) then
        TG:Print("This version of the game can't look players up.")
        return
    end
    local short = Ambiguate and Ambiguate(th.name, "short") or th.name
    local pending = { key = key, name = short:lower(), t = GetTime() }
    self.who = pending
    -- Take the answer ourselves instead of opening the game's Who window.
    if C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
    if FriendsFrame and FriendsFrame.UnregisterEvent then FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE") end
    pcall(C_FriendList.SendWho, 'n-"' .. short .. '"')
    self.checkNote = ("Checking %s..."):format(short)
    self:StartCooldown()
    C_Timer.After(WHO_COOLDOWN, function()
        if R.who == pending then
            R:EndWho()
            R.checkNote = nil
            TG:Print(("Couldn't look up %s - the game didn't answer. Try again."):format(short))
        end
    end)
end

function R:EndWho()
    self.who = nil
    if FriendsFrame and FriendsFrame.RegisterEvent then FriendsFrame:RegisterEvent("WHO_LIST_UPDATE") end
    if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, false) end
end

function R:OnWhoList()
    local w = self.who
    if not w then return end
    local th = TG.db.threads[w.key]
    local found = false
    local n = (C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults()) or 0
    for i = 1, n do
        local info = C_FriendList.GetWhoInfo(i)
        local name = info and info.fullName
        if th and type(name) == "string" and (Ambiguate and Ambiguate(name, "short") or name):lower() == w.name then
            if type(info.level) == "number" and info.level > 0 then th.level = info.level end
            if type(info.filename) == "string" and info.filename ~= "" then th.class = info.filename end
            found = true
            self.checkNote = ("%s: %s."):format(Ambiguate and Ambiguate(th.name, "short") or th.name, R.Describe(th))
            break
        end
    end
    self:EndWho()
    if th and not found then
        local short = Ambiguate and Ambiguate(th.name, "short") or th.name
        self.checkNote = ("%s wasn't found - probably offline."):format(short)
        TG:Print(self.checkNote)
    end
    self:Refresh()
    if UI.frame and UI.frame:IsShown() then UI:RefreshList() end
end

---------------------------------------------------------------------------
-- Incoming whispers, invite, dismiss
---------------------------------------------------------------------------

-- Called for every incoming character whisper, before it is stored.
function R:OnWhisper(key, info, text)
    local th = TG.db.threads[key]
    if not (th and th.req) then
        if not self:IsActive() then return end
        th = TG:EnsureThread(key, info)
        if th.fav or TG:IsFriendly(th) then return end -- people you know stay in Direct messages
        th.req = true
        th.invited, th.joined = nil, nil
    end
    if not th.level then th.level = R.ParseLevel(text) end
    if not th.level or not th.class then self:ScanApplicants() end
end

function R:Invite(key)
    local th = TG.db.threads[key]
    if not th or th.kind ~= "WHISPER" then return end
    if not (TG.Demo and TG.Demo.on) then
        local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
        if not invite then
            TG:Print("This version of the game doesn't let addons send invites.")
            return
        end
        invite(TG.WhisperTarget(th.name))
    end
    th.invited = time()
    self:Refresh()
end

---------------------------------------------------------------------------
-- Quick replies
---------------------------------------------------------------------------

R.declined = {}

-- True for a moment after "decline with message": the echo of that whisper must not
-- bring the dismissed conversation back.
function R:WasDeclined(key)
    local t = self.declined[key]
    if t and GetTime() - t < 10 then return true end
    self.declined[key] = nil
    return false
end

function R:Reply(key, text)
    if type(text) ~= "string" or not text:match("%S") then return end
    TG:Send(key, TG.Social.Expand(text, key))
end

-- Sends the decline message, then dismisses the request.
function R:Decline(key)
    local text = TG.db.settings.declineReply
    if type(text) == "string" and text:match("%S") and TG.db.threads[key] then
        TG:Send(key, TG.Social.Expand(text, key))
        if not (TG.Demo and TG.Demo.on) then self.declined[key] = GetTime() end
    end
    self:Dismiss(key)
end

function R:OpenReplyMenu(key, anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) or not TG.db.threads[key] then return end
    local s = TG.db.settings
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle("Quick reply")
        local any = false
        for _, text in ipairs(s.quickReplies or {}) do
            if type(text) == "string" and text:match("%S") then
                any = true
                root:CreateButton(TG.Social.Expand(text, key), function() R:Reply(key, text) end)
            end
        end
        if not any then root:CreateTitle("|cff888888(none set - see Settings)|r") end
        if type(s.declineReply) == "string" and s.declineReply:match("%S") then
            root:CreateDivider()
            root:CreateButton("Decline: " .. TG.Social.Expand(s.declineReply, key), function() R:Decline(key) end)
        end
    end)
end

-- Requests still waiting for an answer: not invited, not in your group.
function R:OpenKeys()
    local out = {}
    for _, key in ipairs(self:Keys()) do
        local th = TG.db.threads[key]
        if not th.invited and not th.joined then out[#out + 1] = key end
    end
    return out
end

-- Sends the decline message to everyone still waiting and dismisses them, a few a second.
function R:DeclineAll()
    for i, key in ipairs(self:OpenKeys()) do
        C_Timer.After((i - 1) * 0.4, function()
            local th = TG.db.threads[key]
            if th and th.req and not th.invited and not th.joined then R:Decline(key) end
        end)
    end
end

function R:ConfirmDeclineAll()
    local n = #self:OpenKeys()
    if n == 0 then return end
    local text = TG.db.settings.declineReply
    if type(text) ~= "string" or not text:match("%S") then
        TG:Print("There's no decline message. Write one in Settings > Requests first.")
        return
    end
    if not StaticPopupDialogs.TELEGNOME_DECLINE_ALL then
        StaticPopupDialogs.TELEGNOME_DECLINE_ALL = {
            text = "Decline %s requests?\n\nEach of them is sent \"%s\" and taken off the list. "
                .. "People you invited or who are in your group stay.",
            button1 = "Decline all",
            button2 = CANCEL or "Cancel",
            OnAccept = function() R:DeclineAll() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
    StaticPopup_Show("TELEGNOME_DECLINE_ALL", n, text)
end

-- Declined: the conversation and the remembered contact go.
function R:Dismiss(key)
    TG:ForgetContact(key)
    self:Refresh()
end

function R:ClearAll()
    for _, key in ipairs(self:Keys()) do TG:ForgetContact(key) end
    self:Refresh()
    TG:RefreshUnread()
end

function R:ConfirmClearAll()
    local n = #self:Keys()
    if n == 0 then return end
    if not StaticPopupDialogs.TELEGNOME_CLEAR_REQUESTS then
        StaticPopupDialogs.TELEGNOME_CLEAR_REQUESTS = {
            text = "Clear all %s requests?\n\nTheir conversations are closed and they're taken out of New message. "
                .. "To keep someone, open their conversation and click the star first.",
            button1 = "Clear all",
            button2 = CANCEL or "Cancel",
            OnAccept = function() R:ClearAll() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
    StaticPopup_Show("TELEGNOME_CLEAR_REQUESTS", n)
end

-- Who of them is in your group by now?
function R:CheckGroup()
    local changed = false
    for _, th in pairs(TG.db.threads) do
        if th.req and th.kind == "WHISPER" and not th.demo then
            local short = Ambiguate and Ambiguate(th.name, "short") or th.name
            local target = TG.WhisperTarget(th.name)
            local inGroup = (UnitInParty and (UnitInParty(target) or UnitInParty(short)))
                or (UnitInRaid and (UnitInRaid(target) or UnitInRaid(short))) or false
            inGroup = inGroup and true or false
            if (th.joined or false) ~= inGroup then th.joined, changed = inGroup or nil, true end
            -- in the group means invited, however it happened: Decline all leaves them alone, also if they leave
            if inGroup and not th.invited then th.invited, changed = time(), true end
        end
    end
    if changed then self:Refresh() end
end

---------------------------------------------------------------------------
-- Overview panel
---------------------------------------------------------------------------

-- "Level 70 Mage", "Mage - level unknown", ...
function R.Describe(th)
    local class = th.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[th.class]) or th.class)
    local text
    if th.level and class then text = ("Level %d %s"):format(th.level, class)
    elseif th.level then text = ("Level %d"):format(th.level)
    elseif class then text = class .. " - level unknown"
    else text = "Class and level unknown" end
    -- from a group finder application
    if ROLE_NAMES[th.role] then text = text .. " - " .. ROLE_NAMES[th.role] end
    return text
end

-- The same for the list, with the level in gold and the class in its own colour.
function R.DescribeColored(th)
    local class = th.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[th.class]) or th.class)
    local text = th.level and ("|cffffd100Level %d|r"):format(th.level) or "|cff999999Level ?|r"
    if class then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[th.class]
        local hex = c and ("%02x%02x%02x"):format(math.floor((c.r or 1) * 255 + 0.5), math.floor((c.g or 1) * 255 + 0.5),
            math.floor((c.b or 1) * 255 + 0.5)) or "ffffff"
        text = text .. " |cff" .. hex .. class .. "|r"
    end
    local extra = {}
    if ROLE_NAMES[th.role] then extra[#extra + 1] = ROLE_NAMES[th.role] end
    if #extra > 0 then text = text .. "  |cffdddddd" .. table.concat(extra, ", ") .. "|r" end
    if th.applied then text = text .. "  |cff88aaff(applied)|r" end
    return text
end

local function lastIncoming(th)
    for i = #th.msgs, 1, -1 do
        local m = th.msgs[i]
        if not m.out and not m.sys then return m end
    end
    return th.msgs[#th.msgs]
end

local function createRow(parent, i)
    -- a card: name, level, class on top; the message underneath; the buttons on the right
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * PITCH)
    row:SetPoint("RIGHT", 0, 0)
    S.Flat(row)
    S.Paint(row, "card")
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    S.Paint(hl, "hi", 0.06)

    local dismiss = CreateFrame("Button", nil, row)
    dismiss:SetSize(20, 20)
    dismiss:SetPoint("RIGHT", -8, 0)
    local xi = S.Icon(dismiss, S.CLOSE, 10)
    xi:SetPoint("CENTER")
    xi:SetVertexColor(S.DIM[1], S.DIM[2], S.DIM[3])
    dismiss:HookScript("OnEnter", function() xi:SetVertexColor(1, 0.91, 0.69) end)
    dismiss:HookScript("OnLeave", function() xi:SetVertexColor(S.DIM[1], S.DIM[2], S.DIM[3]) end)
    dismiss:SetScript("OnClick", function() if row.key then R:Dismiss(row.key) end end)
    S.Tooltip(dismiss, "Dismiss", "Closes this request and forgets the contact.")
    row.dismiss = dismiss

    row.invite = S.Button(row, "Invite", 64, 24, true)
    row.invite:SetPoint("RIGHT", dismiss, "LEFT", -8, 0)
    row.invite:SetScript("OnClick", function() if row.key then R:Invite(row.key) end end)

    row.reply = S.Button(row, "Reply", 56, 24)
    row.reply:SetPoint("RIGHT", row.invite, "LEFT", -6, 0)
    row.reply:SetScript("OnClick", function(b) if row.key then R:OpenReplyMenu(row.key, b) end end)
    S.Tooltip(row.reply, "Quick reply", "One-click answers, and \"Decline\" to send your decline message and "
        .. "dismiss the request. Edit them in Settings.")

    row.lookup = S.Button(row, "Check", 56, 24)
    row.lookup:SetPoint("RIGHT", row.reply, "LEFT", -6, 0)
    row.lookup:SetScript("OnClick", function() if row.key then R:LookUp(row.key) end end)
    S.Tooltip(row.lookup, "Check level", "Asks the game for this player's level and class (like /who). Use it when "
        .. "the level is missing or looks wrong. The game only answers every few seconds: the button counts "
        .. "down until you can ask again.")

    -- "Invited" / "In group", in place of the buttons that no longer apply
    row.state = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.state:SetTextColor(0.5, 0.83, 0.58)

    -- the class icon in front of the name
    row.classIcon = row:CreateTexture(nil, "ARTWORK")
    row.classIcon:SetSize(16, 16)
    row.classIcon:SetPoint("TOPLEFT", 10, -7)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 12, -9)
    row.name:SetJustifyH("LEFT")

    row.level = S.Pill(row, 16)
    row.level:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.level.fs:SetTextColor(1, 0.82, 0)
    S.Paint(row.level.parts[1], "shadetex", 2.3)
    S.Paint(row.level.parts[2], "shadetex", 2.3)
    S.Paint(row.level.parts[3], "shadetex", 2.3)

    row.class = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.class:SetPoint("LEFT", row.level, "RIGHT", 6, 0)

    row.extra = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.extra:SetPoint("LEFT", row.class, "RIGHT", 8, 0)
    row.extra:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])

    row.unread = S.Pill(row, 16)
    row.unread:SetPoint("LEFT", row.extra, "RIGHT", 8, 0)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("BOTTOMLEFT", 12, 10)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.text:SetTextColor(0.81, 0.76, 0.66)

    row:SetScript("OnClick", function(s)
        if not s.key then return end
        R:ClosePanel(true)
        UI:Select(s.key)
        UI:RefreshList()
    end)
    return row
end

function R:Create()
    if self.panel then return end
    UI:Create()

    -- covers the list and the conversation: the overview has the whole width
    local f = CreateFrame("Frame", nil, UI.right, "BackdropTemplate")
    f:SetAllPoints(UI.body)
    f:SetFrameLevel(UI.right:GetFrameLevel() + 30)
    S.Flat(f)
    S.Paint(f, "cover")
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:Hide()
    self.panel = f

    -- top: what is being collected, and the switch for it
    local manual = S.Check(f, "Collect whispers")
    manual:SetPoint("TOPRIGHT", -(S.Num(manual.label:GetStringWidth(), 100) + 16), -10)
    manual:SetScript("OnClick", function(s)
        TG.db.settings.requestsCollect = s:GetChecked() and true or false
        TG:RefreshUnread()
        R:Refresh()
    end)
    S.Tooltip(manual, "Collect whispers", "While you're listed in the group finder (alone, or as the group's "
        .. "leader), whispers from people who aren't friends, guild members or favorites land here. Untick to "
        .. "pause that and get them under Direct messages.")
    self.manual = manual

    local dot = S.Dot(f, 8)
    dot:SetPoint("TOPLEFT", 16, -18)
    self.statusDot = dot
    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", dot, "RIGHT", 8, 0)
    status:SetPoint("RIGHT", manual, "LEFT", -12, 0)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)
    self.status = status

    -- the classes waiting: All 6, then an icon and a count for each class that has requests. Click to filter.
    self.chips = {}
    local function underline(chip)
        local under = chip:CreateTexture(nil, "ARTWORK")
        under:SetPoint("BOTTOMLEFT", 1, -2)
        under:SetPoint("BOTTOMRIGHT", -1, -2)
        under:SetHeight(2)
        S.Paint(under, "hi", 1)
        chip.under = under
    end
    local function pick(chip)
        R.classFilter = chip.class
        R.offset = 0
        R:Refresh()
    end
    local all = S.Link(f, "All")
    all.fs:SetFontObject("GameFontNormal")
    all:SetHeight(18)
    all:SetPoint("TOPLEFT", 14, -38)
    underline(all)
    all:SetScript("OnClick", pick)
    S.Tooltip(all, "All requests", "Click a class icon to show only that class.")
    self.chips[1] = all
    local order = {}
    for _, c in ipairs(R.CLASSES) do order[#order + 1] = c end
    order[#order + 1] = "UNKNOWN"
    for _, class in ipairs(order) do
        local chip = CreateFrame("Button", nil, f)
        chip:SetHeight(18)
        chip.class = class
        local icon = chip:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", 0, 0)
        if not S.SetClassIcon(icon, class) then
            -- no class: a grey question mark
            icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:SetDesaturated(true)
        end
        chip.icon = icon
        local fs = chip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", icon, "RIGHT", 3, 0)
        chip.fs = fs
        local hl = chip:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)
        underline(chip)
        chip:SetScript("OnClick", pick)
        chip:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            if class == "UNKNOWN" then
                GameTooltip:SetText("Class unknown")
                GameTooltip:AddLine("The game didn't say which class they are. Click Check on their request to look "
                    .. "them up.", 1, 1, 1, true)
            else
                local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
                GameTooltip:SetText(name, c and c.r or 1, c and c.g or 1, c and c.b or 1)
                GameTooltip:AddLine(("%d waiting. Click to show only this class."):format(s.count or 0), 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.chips[#self.chips + 1] = chip
    end

    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", 14, -64)
    list:SetPoint("BOTTOMRIGHT", -20, 46)

    -- a thin scroll indicator, shown when there are more requests than fit
    local track = CreateFrame("Frame", nil, f)
    track:SetPoint("TOPRIGHT", -9, -64)
    track:SetPoint("BOTTOMRIGHT", -9, 52)
    track:SetWidth(4)
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0, 0, 0, 0.35)
    local thumb = track:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(4)
    S.Paint(thumb, "edgetex", 0.9)
    track:Hide()
    self.track, self.thumb = track, thumb
    if list.SetClipsChildren then list:SetClipsChildren(true) end
    self.list = list
    f:SetScript("OnMouseWheel", function(_, delta)
        R.offset = math.max(0, (R.offset or 0) - delta)
        R:Refresh()
    end)
    f:SetScript("OnSizeChanged", function() R:Refresh() end)

    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 4, -10)
    empty:SetPoint("RIGHT", -8, 0)
    empty:SetJustifyH("LEFT")
    self.empty = empty

    -- bottom: how many, and the two ways to empty the list
    local line = S.Line(f)
    line:SetPoint("BOTTOMLEFT", 14, 42)
    line:SetPoint("BOTTOMRIGHT", -14, 42)

    local counts = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    counts:SetPoint("BOTTOMLEFT", 16, 16)
    counts:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    self.counts = counts

    local decline = S.Button(f, "Decline all", 90, 24)
    decline:SetPoint("BOTTOMRIGHT", -30, 9) -- clear of the window's resize corner
    decline:SetScript("OnClick", function() R:ConfirmDeclineAll() end)
    S.Tooltip(decline, "Decline all", "Sends your decline message to everyone still on the list and takes them off "
        .. "it. People you invited or who are in your group stay. The message is in Settings > Requests.")
    self.declineBtn = decline

    local clear = S.Link(f, "Clear all", "GameFontNormal")
    clear:SetPoint("RIGHT", decline, "LEFT", -14, 0)
    clear:SetScript("OnClick", function() R:ConfirmClearAll() end)
    S.Tooltip(clear, "Clear all", "Closes every request and forgets those contacts. Star someone first to keep them.")
    self.clearBtn = clear
end

function R:Refresh()
    if UI.frame and UI.tabs then
        -- keeps the tab in step when listing starts or stops
        local shown = UI.tabs.requests:IsShown()
        if shown ~= self:TabVisible() and not self.inRefresh then
            self.inRefresh = true
            UI:UpdateTabs()
            self.inRefresh = false
        end
    end
    if not self:IsPanelShown() then return end

    self:UpdateStatus()
    self.manual:SetChecked(TG.db.settings.requestsCollect ~= false)
    self:FillRows()
end

-- The line at the top: what is being collected - or, right after a Check, its result and the wait.
function R:UpdateStatus()
    if not self.status then return end
    local s = TG.db.settings
    local function set(dot, text)
        self.statusDot:SetVertexColor(dot[1], dot[2], dot[3])
        self.status:SetText(text)
    end
    local left = (self.whoReady or 0) - GetTime()
    if left > 0 then
        set({ 1, 0.82, 0 }, ("|cffffd100%s|r  Next check in %d s (the game limits look-ups).")
            :format(self.checkNote or "", math.ceil(left)))
        return
    end
    local hosting = self:IsHosting() or (TG.Demo and TG.Demo.on) or false -- the samples look like a real listing
    if s.recruiting then
        set(S.ONLINE, "Collecting (/tg recruit). Whispers from people you don't know land here.")
    elseif hosting and s.requestsCollect ~= false then
        set(S.ONLINE, "You're listed in the group finder. Whispers from people you don't know land here.")
    elseif hosting then
        set({ 1, 0.67, 0.2 }, "Paused. Tick Collect whispers to collect them here again.")
    else
        set(S.OFFLINE, "Not collecting right now. It starts by itself when you list in the group finder.")
    end
end

local function classText(th)
    local class = th.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[th.class]) or th.class)
    local c = th.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[th.class]
    return class or "", c and (c.r or 1) or 0.85, c and (c.g or 1) or 0.82, c and (c.b or 1) or 0.75
end

local function extraText(th, key)
    local extra = {}
    local note = TG.Social:GetNote(key)
    if note then
        local short = TG.Utf8Left(note, 32)
        extra[#extra + 1] = "|cffd9b56a" .. (short ~= note and short .. "..." or short):gsub("|", "||") .. "|r"
    end
    if ROLE_NAMES[th.role] then extra[#extra + 1] = ROLE_NAMES[th.role] end
    if th.applied then extra[#extra + 1] = "applied" end
    return table.concat(extra, "  \194\183  ")
end

-- The chips: how many waiting requests there are of each class, and which filter is on. Classes with no
-- waiting requests are left out, so the row stays short.
function R:UpdateChips()
    if not self.chips then return end
    local counts = {}
    local open = self:OpenKeys()
    for _, key in ipairs(open) do
        local c = R.ClassOf(TG.db.threads[key])
        counts[c] = (counts[c] or 0) + 1
    end
    local prev
    for i, chip in ipairs(self.chips) do
        local on = chip.class == self.classFilter
        local n = chip.class and (counts[chip.class] or 0) or #open
        chip.count = n
        if i == 1 then
            chip.fs:SetText(("All |cffffffff%d|r"):format(n))
            chip:SetWidth(S.Num(chip.fs:GetStringWidth(), 40) + 6)
            if on then chip.fs:SetTextColor(1, 0.82, 0) else chip.fs:SetTextColor(0.72, 0.66, 0.53) end
            prev = chip
        else
            chip.fs:SetText(tostring(n))
            if on then chip.fs:SetTextColor(1, 0.82, 0) else chip.fs:SetTextColor(1, 1, 1) end
            chip:SetWidth(19 + S.Num(chip.fs:GetStringWidth(), 8) + 2)
            local shown = n > 0 or on
            chip:SetShown(shown)
            if shown then
                chip:ClearAllPoints()
                chip:SetPoint("LEFT", prev, "RIGHT", 12, 0)
                prev = chip
            end
        end
        chip.under:SetShown(on)
    end
end

-- Requests shown under the current class filter.
function R:FilteredKeys()
    local keys = self:Keys()
    local want = self.classFilter
    if not want then return keys end
    local out = {}
    for _, key in ipairs(keys) do
        if R.ClassOf(TG.db.threads[key]) == want then out[#out + 1] = key end
    end
    return out
end

function R:FillRows()
    self:UpdateChips()
    local keys = self:FilteredKeys()
    local visible = math.max(1, math.floor((S.Num(self.list:GetHeight(), 300) + (PITCH - ROW_H)) / PITCH))
    self.offset = math.min(self.offset or 0, math.max(0, #keys - visible))
    if #keys > visible then
        local trackH = S.Num(self.track:GetHeight(), 200)
        local h = math.max(20, trackH * visible / #keys)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(self.offset / (#keys - visible)) * (trackH - h))
        self.thumb:SetHeight(h)
        self.track:Show()
    else
        self.track:Hide()
    end
    local waiting, invited, joined = 0, 0, 0
    for _, key in ipairs(keys) do
        local th = TG.db.threads[key]
        if th.joined then joined = joined + 1 elseif th.invited then invited = invited + 1 else waiting = waiting + 1 end
    end
    for i = 1, visible do
        local row = self.rows[i] or createRow(self.list, i)
        self.rows[i] = row
        local key = keys[i + self.offset]
        local th = key and TG.db.threads[key]
        if th then
            row.key = key
            local name, color = TG:ThreadDisplay(key)
            row.name:SetText(name)
            row.name:SetTextColor(color[1], color[2], color[3])
            local hasIcon = S.SetClassIcon(row.classIcon, th.class)
            row.classIcon:SetShown(hasIcon)
            row.name:SetPoint("TOPLEFT", hasIcon and 30 or 12, -9)
            row.level:SetLabel(th.level and tostring(th.level) or "?")
            local class, cr, cg, cb = classText(th)
            row.class:SetText(class)
            row.class:SetTextColor(cr, cg, cb)
            row.extra:SetText(extraText(th, key))
            row.unread:SetCount(th.unread or 0)
            local m = lastIncoming(th)
            row.text:SetText(m and m.text or "")

            -- waiting: Check, Reply, Invite. Invited: the word, and Invite to try again. In group: just the word.
            local open = not th.joined and not th.invited
            row.lookup:SetShown(open)
            row.reply:SetShown(open)
            row.invite:SetShown(not th.joined)
            row.state:SetText(th.joined and "In group" or th.invited and "Invited" or "")
            row.state:ClearAllPoints()
            local leftmost
            if th.joined then
                row.state:SetPoint("RIGHT", row.dismiss, "LEFT", -10, 0)
                leftmost = row.state
            elseif th.invited then
                row.state:SetPoint("RIGHT", row.invite, "LEFT", -10, 0)
                leftmost = row.state
            else
                row.state:SetPoint("RIGHT", row.lookup, "LEFT", -10, 0)
                leftmost = row.lookup
            end
            row.text:SetPoint("RIGHT", leftmost, "LEFT", -10, 0)
            row:Show()
        else
            row.key = nil
            row:Hide()
        end
    end
    for i = visible + 1, #self.rows do
        self.rows[i].key = nil
        self.rows[i]:Hide()
    end
    self:UpdateLookupButtons()
    self.counts:SetText(("%d waiting  \194\183  %d invited  \194\183  %d in group"):format(waiting, invited, joined))
    self.counts:SetShown(#keys > 0)
    self.declineBtn:SetEnabled(#self:OpenKeys() > 0)
    self.empty:SetShown(#keys == 0)
    self.empty:SetText(self:IsActive() and "No requests yet. Whispers from people who aren't friends, guild members "
        .. "or favorites will show up here with their class and level."
        or "No requests.")
    self.clearBtn:SetEnabled(#keys > 0)
end

function R:IsPanelShown()
    return self.panel and self.panel:IsShown() or false
end

-- fromTab: called by UI:SetTab, which has already switched to the Requests tab.
function R:OpenPanel(fromTab)
    if not self:TabVisible() then return end
    UI:Show()
    self:Create()
    if UI.tab ~= "requests" then
        if fromTab then return end -- never bounce back and forth with SetTab
        UI:SetTab("requests") -- which opens this panel
        return
    end
    TG.Settings:Close()
    TG.Picker:Close()
    TG.Groups:ClosePanel()
    TG.Channels:ClosePanel()
    TG.ChannelList:Close()
    self.panel:Show()
    self:ScanApplicants()
    self:CheckGroup()
    self:Refresh()
end

-- quiet: a conversation is about to be selected anyway
function R:ClosePanel(quiet)
    if not self:IsPanelShown() then return end
    self.panel:Hide()
    if not quiet and UI.frame:IsShown() and UI.selected and UI.tab == "requests" then UI:Select(UI.selected) end
end

function R:TogglePanel()
    if self:IsPanelShown() then self:ClosePanel() else self:OpenPanel() end
end

-- Tells you once when your listing starts (or you become the leader of a listed group).
function R:CheckHosting()
    local hosting = self:IsHosting()
    if hosting and not self.wasHosting and self:IsActive() then
        TG:Print("You're listed in the group finder. Whispers from people you don't know go to Requests.")
        if TG.Toast then
            TG.Toast:Notice("|cffffd100Requests are on|r", "Whispers from strangers go to Requests. Click to open.",
                function() R:OpenPanel() end)
        end
    end
    local changed = hosting ~= (self.wasHosting or false)
    self.wasHosting = hosting
    if changed or not self.checkedOnce then
        self.checkedOnce = true
        self:Refresh()
        if changed then TG:RefreshUnread() end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Invited from anywhere (the game's menus, /invite, another addon): the request is marked Invited, so
-- Decline all doesn't send them the decline message.
local function onInvite(name)
    if not TG.db or type(name) ~= "string" or TG.isSecret(name) or name == "" then return end
    local full = TG.FullName(name)
    local th = full and TG.db.threads[TG.WhisperKey(full)]
    if th and th.req and not th.invited and not th.joined then
        th.invited = time()
        R:Refresh()
    end
end
if C_PartyInfo and C_PartyInfo.InviteUnit then pcall(hooksecurefunc, C_PartyInfo, "InviteUnit", onInvite) end
if InviteUnit then pcall(hooksecurefunc, "InviteUnit", onInvite) end

local f = CreateFrame("Frame")
for _, ev in ipairs({ "LFG_LIST_ACTIVE_ENTRY_UPDATE", "LFG_LIST_APPLICANT_UPDATED", "LFG_LIST_APPLICANT_LIST_UPDATED",
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "WHO_LIST_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    pcall(f.RegisterEvent, f, ev)
end
f:SetScript("OnEvent", function(_, event)
    if not TG.db then return end
    if event == "WHO_LIST_UPDATE" then
        R:OnWhoList()
    elseif event == "GROUP_ROSTER_UPDATE" then
        R:CheckGroup()
        R:CheckHosting() -- joining a group, or being made leader, changes whose listing it is
    elseif event == "LFG_LIST_APPLICANT_UPDATED" or event == "LFG_LIST_APPLICANT_LIST_UPDATED" then
        -- these can arrive in bursts: look once, a moment later
        if not R.scanQueued then
            R.scanQueued = true
            C_Timer.After(0.5, function()
                R.scanQueued = false
                R:ScanApplicants()
            end)
        end
    else
        R:CheckHosting()
    end
end)
