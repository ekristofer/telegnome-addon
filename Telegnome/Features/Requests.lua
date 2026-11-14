-- Telegnome: Requests. While you (or your group) are listed in the group finder, whispers
-- from people you don't know are collected in their own tab, with class, level and an
-- Invite button, instead of piling up under Direct messages.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local R = { rows = {}, offset = 0 }
TG.Requests = R

local ROW_H = 48

---------------------------------------------------------------------------
-- When is it collecting?
---------------------------------------------------------------------------

-- Listed in the group finder (premade groups)?
function R:IsListed()
    if not (C_LFGList and C_LFGList.HasActiveEntryInfo) then return false end
    local ok, listed = pcall(C_LFGList.HasActiveEntryInfo)
    return ok and listed and true or false
end

-- Collecting: listed (if that option is on), or the manual switch.
function R:IsActive()
    local s = TG.db.settings
    return s.recruiting or (s.requestsTab and self:IsListed()) or false
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
    if self:IsActive() then return true end
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
for word in ([[warrior war warr paladin pala pally hunter hunt rogue priest dk deathknight shaman sham shammy
    mage warlock lock monk druid dudu dh evoker tank healer heal heals dps holy prot ret fury arms frost fire
    arcane resto balance boomkin feral shadow disc bm mm surv ele enh enhance aff affli destro demo guardian
    bear brew mw ww havoc vengeance blood unholy outlaw assa sub dev pres aug]]):gmatch("%a+") do
    HINTS[word] = true
end
-- ...and words that say it is something else ("480 ilvl", "2900 io").
local NOT_LEVEL = { ilvl = true, ilevel = true, io = true, gs = true, k = true, rio = true, score = true,
    cr = true, rating = true, g = true, gold = true, min = true, mins = true, sec = true, hp = true }

local function maxLevel()
    local m = GetMaxPlayerLevel and GetMaxPlayerLevel()
    return (type(m) == "number" and m > 0) and m or 90
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
        if not prev:find("[%d%.%+,/:]") and not nxt:find("[%d%.k%%/:]") then
            local before = lower:sub(1, pos - 1):match("(%a+)%s*$")
            local behind = lower:sub(after):match("^%s*(%a+)")
            if not (behind and NOT_LEVEL[behind]) and ((before and HINTS[before]) or (behind and HINTS[behind])) then
                local n = valid(num)
                if n then return n end
            end
        end
    end
    return nil
end

local ROLE_NAMES = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }

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

-- /who for one person (needs a click; the game limits how often it answers).
function R:LookUp(key)
    local th = TG.db.threads[key]
    if not th or th.kind ~= "WHISPER" then return end
    if TG.Demo and TG.Demo.on then return end
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
    C_Timer.After(5, function()
        if R.who == pending then
            R:EndWho()
            TG:Print(("Couldn't look up %s - the game only answers this every few seconds. Try again shortly."):format(short))
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
            break
        end
    end
    self:EndWho()
    if th and not found then
        TG:Print(("%s wasn't found - probably offline."):format(Ambiguate and Ambiguate(th.name, "short") or th.name))
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
    TG:Send(key, text)
end

-- Sends the decline message, then dismisses the request.
function R:Decline(key)
    local text = TG.db.settings.declineReply
    if type(text) == "string" and text:match("%S") and TG.db.threads[key] then
        TG:Send(key, text)
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
                root:CreateButton(text, function() R:Reply(key, text) end)
            end
        end
        if not any then root:CreateTitle("|cff888888(none set - see Settings)|r") end
        if type(s.declineReply) == "string" and s.declineReply:match("%S") then
            root:CreateDivider()
            root:CreateButton("Decline: " .. s.declineReply, function() R:Decline(key) end)
        end
    end)
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
        if th.req and th.kind == "WHISPER" then
            local short = Ambiguate and Ambiguate(th.name, "short") or th.name
            local target = TG.WhisperTarget(th.name)
            local inGroup = (UnitInParty and (UnitInParty(target) or UnitInParty(short)))
                or (UnitInRaid and (UnitInRaid(target) or UnitInRaid(short))) or false
            inGroup = inGroup and true or false
            if (th.joined or false) ~= inGroup then th.joined, changed = inGroup or nil, true end
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
    if th.ilvl then text = text .. (" - item level %d"):format(th.ilvl) end
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
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("RIGHT", 0, 0)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    S.Paint(hl, "hi", 0.08)

    row.dismiss = S.Button(row, "x", 22, 22)
    row.dismiss:SetPoint("RIGHT", -6, 0)
    row.dismiss:SetScript("OnClick", function() if row.key then R:Dismiss(row.key) end end)
    S.Tooltip(row.dismiss, "Dismiss", "Closes this request and forgets the contact.")

    row.invite = S.Button(row, "Invite", 64, 22)
    row.invite:SetPoint("RIGHT", row.dismiss, "LEFT", -6, 0)
    row.invite:SetScript("OnClick", function() if row.key then R:Invite(row.key) end end)

    row.lookup = S.Button(row, "Level?", 60, 22)
    row.lookup:SetPoint("RIGHT", row.invite, "LEFT", -6, 0)
    row.lookup:SetScript("OnClick", function() if row.key then R:LookUp(row.key) end end)
    S.Tooltip(row.lookup, "Look up level", "Asks the game for this player's level and class (like /who). "
        .. "The game only answers every few seconds.")

    row.reply = S.Button(row, "Reply", 56, 22)
    row.reply:SetPoint("RIGHT", row.lookup, "LEFT", -6, 0)
    row.reply:SetScript("OnClick", function(b) if row.key then R:OpenReplyMenu(row.key, b) end end)
    S.Tooltip(row.reply, "Quick reply", "One-click answers, and \"Decline\" to send your decline message and "
        .. "dismiss the request. Edit them in Settings.")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 10, -7)
    row.name:SetJustifyH("LEFT")

    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.info:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.info:SetPoint("RIGHT", row.reply, "LEFT", -8, 0)
    row.info:SetJustifyH("LEFT")
    row.info:SetWordWrap(false)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", 10, -27)
    row.text:SetPoint("RIGHT", row.reply, "LEFT", -8, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.text:SetTextColor(0.85, 0.82, 0.75)

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

    local f = CreateFrame("Frame", nil, UI.right, "BackdropTemplate")
    f:SetAllPoints(UI.right)
    f:SetFrameLevel(UI.right:GetFrameLevel() + 30)
    S.Inset(f)
    S.Solid(f)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:Hide()
    self.panel = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("Requests")
    local cog = S.Cog(f, 18)
    cog:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -34)
    line:SetPoint("TOPRIGHT", -8, -34)

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 14, -42)
    status:SetPoint("RIGHT", -14, 0)
    status:SetJustifyH("LEFT")
    self.status = status

    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", 8, -62)
    list:SetPoint("BOTTOMRIGHT", -8, 42)
    if list.SetClipsChildren then list:SetClipsChildren(true) end
    self.list = list
    f:SetScript("OnMouseWheel", function(_, delta)
        R.offset = math.max(0, (R.offset or 0) - delta)
        R:Refresh()
    end)
    f:SetScript("OnSizeChanged", function() R:Refresh() end)

    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 8, -10)
    empty:SetPoint("RIGHT", -8, 0)
    empty:SetJustifyH("LEFT")
    self.empty = empty

    local clear = S.Button(f, "Clear all", 84, 24)
    clear:SetPoint("BOTTOMLEFT", 10, 10)
    clear:SetScript("OnClick", function() R:ConfirmClearAll() end)
    S.Tooltip(clear, "Clear all", "Closes every request and forgets those contacts. Star someone first to keep them.")
    self.clearBtn = clear

    local manual = S.Check(f, "Collect whispers here now")
    manual:SetPoint("LEFT", clear, "RIGHT", 12, 0)
    manual:SetScript("OnClick", function(s)
        TG.db.settings.recruiting = s:GetChecked() and true or false
        TG:RefreshUnread()
    end)
    S.Tooltip(manual, "Manual switch", "Telegnome collects whispers here by itself while you're listed in the group "
        .. "finder. Tick this to collect them at any other time (for example when recruiting in a chat channel). "
        .. "Also: /tg recruit")
    self.manual = manual

    local done = S.Button(f, "Close", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    done:SetScript("OnClick", function() R:ClosePanel() end)
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

    local s = TG.db.settings
    local listed = self:IsListed()
    if listed and s.requestsTab then
        self.status:SetText("|cff66dd66You're listed in the group finder.|r Whispers from people you don't know land here.")
    elseif s.recruiting then
        self.status:SetText("|cff66dd66Collecting (manual switch).|r Whispers from people you don't know land here.")
    else
        self.status:SetText("|cffaaaaaaNot collecting right now.|r It starts by itself when you list in the group finder.")
    end
    self.manual:SetChecked(s.recruiting and true or false)

    local keys = self:Keys()
    local visible = math.max(1, math.floor((self.list:GetHeight() or 0) / ROW_H))
    self.offset = math.min(self.offset or 0, math.max(0, #keys - visible))
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
            local info = R.Describe(th)
            if th.applied then info = info .. "  |cff88aaff(applied)|r" end
            row.info:SetText(info)
            local m = lastIncoming(th)
            local unread = (th.unread or 0) > 0 and ("|cffff5555(" .. th.unread .. ")|r ") or ""
            row.text:SetText(unread .. (m and m.text or ""))
            -- the Level? button gives up its place to Reply when the level is known
            row.lookup:SetShown(not th.level)
            row.reply:ClearAllPoints()
            if th.level then
                row.reply:SetPoint("RIGHT", row.invite, "LEFT", -6, 0)
            else
                row.reply:SetPoint("RIGHT", row.lookup, "LEFT", -6, 0)
            end
            if th.joined then
                row.invite:SetText("In group")
                row.invite:SetEnabled(false)
            elseif th.invited then
                row.invite:SetText("Invited")
                row.invite:SetEnabled(true)
            else
                row.invite:SetText("Invite")
                row.invite:SetEnabled(true)
            end
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

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
for _, ev in ipairs({ "LFG_LIST_ACTIVE_ENTRY_UPDATE", "LFG_LIST_APPLICANT_UPDATED", "LFG_LIST_APPLICANT_LIST_UPDATED",
    "GROUP_ROSTER_UPDATE", "WHO_LIST_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    pcall(f.RegisterEvent, f, ev)
end
f:SetScript("OnEvent", function(_, event)
    if not TG.db then return end
    if event == "WHO_LIST_UPDATE" then
        R:OnWhoList()
    elseif event == "GROUP_ROSTER_UPDATE" then
        R:CheckGroup()
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
        local listed = R:IsListed()
        if listed and not R.wasListed and TG.db.settings.requestsTab then
            TG:Print("You're listed in the group finder: whispers from people you don't know are collected under "
                .. "Requests in Telegnome.")
            if TG.Toast then
                TG.Toast:Notice("|cffffd100Requests are on|r",
                    "You're listed in the group finder. Whispers from people you don't know are collected under "
                    .. "Requests. Click to open it.",
                    function() R:OpenPanel() end)
            end
        end
        R.wasListed = listed
        R:Refresh()
    end
end)
