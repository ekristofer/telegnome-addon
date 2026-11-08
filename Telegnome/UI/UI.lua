-- Telegnome: messenger window (contact list + conversation + input), classic style.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = { rows = {}, offset = 0, tab = "dm", selectedByTab = {} }
TG.UI = UI

local LIST_W = 180
local ROW_H = 26
UI.ROW_H = ROW_H

local function hex(c)
    return ("%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end
UI.hex = hex

local function chatColor(chatType)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if info then return info.r, info.g, info.b end
    return 1, 1, 1
end

-- Shared row look for the contact list and the New message picker.
function UI:MakeRow(parent, top, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, top - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, top - (i - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints()
    sel:SetColorTexture(1, 0.82, 0, 0.12)
    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(2)
    bar:SetColorTexture(1, 0.82, 0, 0.9)
    function row:SetSelected(v)
        sel:SetShown(v)
        bar:SetShown(v)
    end
    row:SetSelected(false)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(7, 7)
    row.dot:SetPoint("LEFT", 8, 0)

    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.right:SetPoint("RIGHT", -22, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.dot, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

function UI.SetRowContact(row, name, color, online)
    row.name:SetText(name)
    row.name:SetTextColor(color[1], color[2], color[3])
    if online == nil then
        row.dot:Hide()
    else
        row.dot:Show()
        if online then row.dot:SetColorTexture(0.3, 0.9, 0.3) else row.dot:SetColorTexture(0.4, 0.4, 0.4) end
    end
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------

function UI:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "TelegnomeFrame", UIParent, "BackdropTemplate")
    f:SetSize(700, 510)
    f:SetPoint("CENTER")
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    if f.SetResizeBounds then f:SetResizeBounds(640, 490, 1400, 1000) end
    f:EnableMouse(true)
    S.Outer(f)
    f:Hide()
    tinsert(UISpecialFrames, "TelegnomeFrame") -- Escape closes it
    self.frame = f

    -- Title bar (drag handle)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", 12, -12)
    bar:SetPoint("TOPRIGHT", -12, -12)
    bar:SetHeight(32)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); UI:SavePos() end)

    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", 0, 0)
    self.title = title

    local cogL = S.Cog(bar, 22)
    cogL:SetPoint("RIGHT", title, "LEFT", -8, 0)
    local cogR = S.Cog(bar, 22)
    cogR:SetPoint("LEFT", title, "RIGHT", 8, 0)
    self.cogSpins = { S.Spin(cogL, 1.2, 144), S.Spin(cogR, 1.2, -144) }

    local tagline = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tagline:SetPoint("LEFT", 6, 0)
    tagline:SetText("Gnomish Universal Messenger")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() f:Hide() end)

    local settingsBtn = S.CogButton(bar, 20, "Settings")
    settingsBtn:SetPoint("RIGHT", -30, 0)
    settingsBtn:SetScript("OnClick", function() TG.Settings:Toggle() end)

    local sep = S.Line(f)
    sep:SetPoint("TOPLEFT", 16, -46)
    sep:SetPoint("TOPRIGHT", -16, -46)

    -- Tabs
    self.tabs = {}
    local prevTab
    for _, def in ipairs({ { "dm", "Direct messages" }, { "groups", "Group chats" }, { "channels", "Followed channels" } }) do
        local tab = S.Button(f, def[2], 160, 26)
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", 16, -52)
        end
        tab.id, tab.baseText = def[1], def[2]
        tab:SetScript("OnClick", function() UI:SetTab(def[1]) end)
        self.tabs[def[1]] = tab
        prevTab = tab
    end

    -- Left panel: New message + contacts
    local left = S.Panel(f)
    left:SetPoint("TOPLEFT", 14, -82)
    left:SetPoint("BOTTOMLEFT", 14, 14)
    left:SetWidth(LIST_W)
    if left.SetClipsChildren then left:SetClipsChildren(true) end
    self.left = left

    local watermark = S.Cog(left, 160, "BACKGROUND")
    watermark:SetPoint("BOTTOMRIGHT", 50, -50)
    watermark:SetAlpha(0.07)

    local newBtn = S.Button(left, "+ New message", LIST_W - 12, 24)
    newBtn:SetPoint("TOP", 0, -6)
    newBtn:SetScript("OnClick", function()
        if UI.tab == "groups" then
            TG.Groups:TogglePanel()
        elseif UI.tab == "channels" then
            TG.Channels:TogglePanel()
        else
            TG.Picker:Toggle()
        end
    end)
    self.newBtn = newBtn

    local list = CreateFrame("Frame", nil, left)
    list:SetPoint("TOPLEFT", 4, -36)
    list:SetPoint("BOTTOMRIGHT", -4, 4)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        UI.offset = math.max(0, (UI.offset or 0) - delta)
        UI:RefreshList()
    end)
    self.list = list

    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 8, -8)
    empty:SetPoint("RIGHT", -8, 0)
    empty:SetJustifyH("LEFT")
    empty:SetText("No conversations yet.\nWhispers will show up here.")
    self.emptyText = empty

    -- Right panel: conversation
    local right = S.Panel(f)
    right:SetPoint("TOPLEFT", 14 + LIST_W + 6, -82)
    right:SetPoint("BOTTOMRIGHT", -14, 14)
    self.right = right

    local headerBtn = CreateFrame("Button", nil, right)
    headerBtn:SetPoint("TOPLEFT", 10, -6)
    headerBtn:SetPoint("TOPRIGHT", -10, -6)
    headerBtn:SetHeight(24)
    headerBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    headerBtn:SetScript("OnClick", function(s)
        if UI.selected then UI:OpenContactMenu(UI.selected, s) end
    end)
    local header = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    header:SetPoint("LEFT")
    header:SetPoint("RIGHT")
    header:SetJustifyH("LEFT")
    header:SetWordWrap(false)
    self.header = header

    local hsep = S.Line(right)
    hsep:SetPoint("TOPLEFT", 8, -32)
    hsep:SetPoint("TOPRIGHT", -8, -32)

    local msgs = CreateFrame("ScrollingMessageFrame", nil, right)
    msgs:SetPoint("TOPLEFT", 10, -38)
    msgs:SetPoint("BOTTOMRIGHT", -10, 42)
    msgs:SetFontObject(ChatFontNormal)
    msgs:SetJustifyH("LEFT")
    msgs:SetFading(false)
    msgs:SetMaxLines(1000)
    if msgs.SetIndentedWordWrap then msgs:SetIndentedWordWrap(true) end
    msgs:SetHyperlinksEnabled(true)
    msgs:SetScript("OnHyperlinkClick", function(_, link, text, button)
        local code, name = link:match("^telegnome:join:([^:]+):(.*)$")
        if code then
            TG.Groups:Join(code, name)
        elseif SetItemRef then
            SetItemRef(link, text, button)
        end
    end)
    msgs:EnableMouseWheel(true)
    msgs:SetScript("OnMouseWheel", function(s, delta)
        if delta > 0 then
            if IsShiftKeyDown() then s:ScrollToTop() else s:ScrollUp() end
        else
            if IsShiftKeyDown() then s:ScrollToBottom() else s:ScrollDown() end
        end
    end)
    self.msgs = msgs

    local input = S.EditBox(right)
    input:SetPoint("BOTTOMLEFT", 8, 8)
    input:SetPoint("BOTTOMRIGHT", -8, 8)
    input:SetHeight(26)
    input:SetMaxLetters(255)
    input:SetScript("OnEnterPressed", function(s)
        local text = s:GetText()
        if UI.selected and text and text:match("%S") then
            if TG:Send(UI.selected, text) then s:SetText("") end
        else
            s:ClearFocus()
        end
    end)
    self.input = input

    -- Resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -6, 6)
    grip:SetFrameLevel(right:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing(); UI:SavePos(); UI:RefreshList(); TG.Picker:Refresh()
    end)

    f:SetScript("OnSizeChanged", function() UI:RefreshList(); TG.Picker:Refresh() end)
    f:SetScript("OnShow", function() UI:OnShow() end)
    f:SetScript("OnHide", function()
        TG.Picker:Close(); TG.Settings:Close(); TG.Groups:ClosePanel(); TG.Channels:ClosePanel()
    end)

    self:RestorePos()
    self:UpdateTitle()
end

function UI:PulseCogs()
    if not self.cogSpins then return end
    for _, ag in ipairs(self.cogSpins) do
        if not ag:IsPlaying() then ag:Play() end
    end
end

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------

function UI:SavePos()
    local f = self.frame
    local point, _, relPoint, x, y = f:GetPoint()
    TG.db.pos = { point = point, relPoint = relPoint, x = x, y = y, w = f:GetWidth(), h = f:GetHeight() }
end

function UI:RestorePos()
    local p = TG.db.pos
    if not p or not p.point then return end
    local f = self.frame
    f:ClearAllPoints()
    f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    if p.w and p.h then f:SetSize(math.max(p.w, 640), math.max(p.h, 490)) end
end

---------------------------------------------------------------------------
-- Right-click player menu
---------------------------------------------------------------------------

-- Uses the game's own player/friend menu (invite, add friend, ignore, report...),
-- like right-clicking a name in chat. Falls back to a small menu of our own.
function UI:OpenContactMenu(key, anchor)
    local rec = TG.db.threads[key] or TG.db.contacts[key]
    if not rec then return end

    if rec.kind == "GROUP" then
        TG.Groups:OpenMenu(key, anchor)
        return
    elseif rec.kind == "CHANNEL" then
        TG.Channels:OpenMenu(key, anchor)
        return
    elseif rec.kind == "BN" then
        local id, acct = TG:LookupBN(key)
        if id and acct and FriendsFrame_ShowBNDropdown then
            local online = acct.gameAccountInfo and acct.gameAccountInfo.isOnline or false
            if pcall(FriendsFrame_ShowBNDropdown, acct.accountName, online, nil, "BN_WHISPER", nil, nil, id) then
                return
            end
        end
    elseif FriendsFrame_ShowDropdown then
        if pcall(FriendsFrame_ShowDropdown, rec.name, true, nil, "WHISPER", nil, nil, nil,
            nil, nil, nil, nil, rec.guid) then
            return
        end
    end
    self:OpenFallbackMenu(key, rec, anchor)
end

function UI:OpenFallbackMenu(key, rec, anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local name = TG:ThreadDisplay(key)
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(name)
        if rec.kind == "WHISPER" then
            root:CreateButton("Invite to group", function()
                local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
                if invite then invite(rec.name) end
            end)
            root:CreateButton("Add friend", function()
                if C_FriendList then C_FriendList.AddFriend(rec.name) end
            end)
        end
        if TG.db.threads[key] then
            root:CreateButton("Close conversation", function() TG:DeleteThread(key) end)
        end
    end)
end

---------------------------------------------------------------------------
-- Contact list
---------------------------------------------------------------------------

function UI:GetRow(i)
    local row = self.rows[i]
    if row then return row end

    row = self:MakeRow(self.list, 0, i)

    -- Close (x) shown on the selected row
    local x = CreateFrame("Button", nil, row)
    x:SetSize(14, 14)
    x:SetPoint("RIGHT", -5, 0)
    x:SetNormalTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    x:SetAlpha(0.6)
    x:SetScript("OnEnter", function(s)
        s:SetAlpha(1)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        if UI.tab == "groups" then
            GameTooltip:SetText("Leave group")
        elseif UI.tab == "channels" then
            GameTooltip:SetText("Unfollow channel")
        else
            GameTooltip:SetText("Close conversation")
            GameTooltip:AddLine("History is removed; the contact is kept for New message.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    x:SetScript("OnLeave", function(s) s:SetAlpha(0.6); GameTooltip:Hide() end)
    x:SetScript("OnClick", function()
        local th = row.key and TG.db.threads[row.key]
        if not th then return end
        if th.kind == "GROUP" then
            TG.Groups:ConfirmLeave(row.key)
        elseif th.kind == "CHANNEL" then
            TG.Channels:Unfollow(row.key)
        else
            TG:DeleteThread(row.key)
        end
    end)
    row.close = x

    row:SetScript("OnClick", function(s, button)
        if not s.key then return end
        if button == "RightButton" then
            UI:OpenContactMenu(s.key, s)
        else
            TG.Settings:Close()
            TG.Groups:ClosePanel()
            TG.Channels:ClosePanel()
            UI:Select(s.key)
            UI.input:SetFocus()
        end
    end)

    self.rows[i] = row
    return row
end

function UI.TabOf(th)
    if th.kind == "GROUP" then return "groups" end
    if th.kind == "CHANNEL" then return "channels" end
    return "dm"
end

function UI:SortedKeys(tab)
    tab = tab or self.tab
    local threads = TG.db.threads
    local keys = {}
    for k, th in pairs(threads) do
        if UI.TabOf(th) == tab then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return (threads[a].order or 0) > (threads[b].order or 0) end)
    return keys
end

function UI:RefreshList()
    if not self.frame or not self.frame:IsShown() then return end
    local keys = self:SortedKeys()
    local visible = math.max(1, math.floor((self.list:GetHeight() or 0) / ROW_H))
    self.offset = math.min(self.offset or 0, math.max(0, #keys - visible))
    local empties = {
        dm = "No conversations yet.\nWhispers will show up here.",
        groups = "No group chats yet.\nClick + New group to create\none or join with a code.",
        channels = "No followed channels yet.\nClick + Follow channel to\npick guild, party, Trade...",
    }
    self.emptyText:SetText(empties[self.tab] or "")
    self.emptyText:SetShown(#keys == 0)

    for i = 1, visible do
        local row = self:GetRow(i)
        local key = keys[i + self.offset]
        if key then
            local th = TG.db.threads[key]
            UI.SetRowContact(row, TG:ThreadDisplay(key))
            row.key = key
            local selected = key == self.selected
            local unread = th.unread or 0
            row.right:SetText((unread > 0 and not selected) and ("|cffff5555" .. unread .. "|r") or "")
            row:SetSelected(selected)
            row.close:SetShown(selected)
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
end

function UI:UpdateTabs()
    if not self.tabs then return end
    local counts = { dm = 0, groups = 0, channels = 0 }
    for _, th in pairs(TG.db.threads) do
        local t = UI.TabOf(th)
        counts[t] = counts[t] + (th.unread or 0)
    end
    for id, tab in pairs(self.tabs) do
        local n = counts[id]
        tab:SetText(n > 0 and ("%s |cffff5555(%d)|r"):format(tab.baseText, n) or tab.baseText)
        if id == self.tab then
            tab:SetBackdropColor(0.24, 0.17, 0.08, 1)
            tab:SetBackdropBorderColor(1, 0.82, 0, 1)
            tab.fs:SetTextColor(1, 0.82, 0)
        else
            tab:SetBackdropColor(0.09, 0.065, 0.04, 1)
            tab:SetBackdropBorderColor(S.BRONZE[1], S.BRONZE[2], S.BRONZE[3], 1)
            tab.fs:SetTextColor(0.65, 0.6, 0.5)
        end
    end
end

function UI:UpdateNewButton()
    if not self.newBtn then return end
    local labels = { dm = "+ New message", groups = "+ New group", channels = "+ Follow channel" }
    self.newBtn:SetText(labels[self.tab] or "+ New message")
end

function UI:SetTab(tab)
    self:Create()
    if self.tab ~= tab then
        TG.Picker:Close()
        TG.Groups:ClosePanel()
        TG.Channels:ClosePanel()
    end
    self.tab = tab
    self.offset = 0
    self:UpdateNewButton()
    self:UpdateTabs()
    local key = self.selectedByTab[tab]
    if not key or not TG.db.threads[key] then key = self:SortedKeys(tab)[1] end
    if key then self:Select(key) else self:ShowEmpty() end
    self:RefreshList()
end

function UI:UpdateTitle()
    self:UpdateTabs()
    if not self.title then return end
    local n = TG:TotalUnread()
    if n > 0 then
        self.title:SetText(("Telegnome |cffff5555(%d)|r"):format(n))
    else
        self.title:SetText("Telegnome")
    end
end

---------------------------------------------------------------------------
-- Conversation
---------------------------------------------------------------------------

function UI:RenderMessage(th, m, name, color)
    local day = date("%Y-%m-%d", m.t)
    if day ~= self.lastDay then
        self.lastDay = day
        self.msgs:AddMessage(date("- %A %d %B -", m.t), 0.55, 0.47, 0.32)
    end
    local ts = date("%H:%M", m.t)
    if m.sys then
        self.msgs:AddMessage(("|cff777777%s|r %s"):format(ts, m.text), 0.55, 0.47, 0.32)
        return
    end
    if th.kind == "GROUP" or th.kind == "CHANNEL" then
        local r, g, b = chatColor(th.kind == "GROUP" and "CHANNEL" or TG.Channels.ColorKey(th))
        if m.out then
            self.msgs:AddMessage(("|cff777777%s|r |cffaaaaaaYou:|r %s"):format(ts, m.text), r, g, b)
        else
            local c = m.cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.cls]
            local who = c and { c.r, c.g, c.b } or { 0.9, 0.9, 0.9 }
            self.msgs:AddMessage(("|cff777777%s|r |cff%s%s:|r %s"):format(ts, hex(who), m.from or "?", m.text), r, g, b)
        end
        return
    end
    local isBN = th.kind == "BN"
    if m.out then
        local r, g, b = chatColor(isBN and "BN_WHISPER_INFORM" or "WHISPER_INFORM")
        self.msgs:AddMessage(("|cff777777%s|r |cffaaaaaaYou:|r %s"):format(ts, m.text), r, g, b)
    else
        local r, g, b = chatColor(isBN and "BN_WHISPER" or "WHISPER")
        self.msgs:AddMessage(("|cff777777%s|r |cff%s%s:|r %s"):format(ts, hex(color), name, m.text), r, g, b)
        local code, gname = TG.Groups.ParseInvite(m.text)
        if code then
            self.msgs:AddMessage(("      |Htelegnome:join:%s:%s|h|cffffd100[Join %s]|r|h"):format(code, gname or "", gname or "group"))
        end
    end
end

function UI:Select(key)
    local th = TG.db.threads[key]
    if not th then return end
    local tab = UI.TabOf(th)
    if tab ~= self.tab then
        self.tab = tab
        self.offset = 0
        self:UpdateNewButton()
    end
    self.selectedByTab[tab] = key
    self.selected = key
    th.unread = 0

    local name, color = TG:ThreadDisplay(key)
    local sub = ""
    if th.kind == "GROUP" then
        sub = "  |cff777777code: " .. (th.code or "?") .. "|r"
    elseif th.kind == "BN" and th.battleTag then
        sub = "  |cff777777" .. th.battleTag .. "|r"
    elseif th.kind == "WHISPER" and th.name and th.name:find("-", 1, true) then
        sub = "  |cff777777" .. th.name .. "|r"
    end
    self.header:SetText(("|cff%s%s|r%s"):format(hex(color), name, sub))

    self.msgs:Clear()
    self.lastDay = nil
    if #th.msgs == 0 then
        self.msgs:AddMessage("New conversation - type below and press Enter.", 0.55, 0.47, 0.32)
    end
    for _, m in ipairs(th.msgs) do self:RenderMessage(th, m, name, color) end
    self.msgs:ScrollToBottom()

    self:RefreshList()
    TG:RefreshUnread()
end

function UI:ShowEmpty()
    self.selected = nil
    self.header:SetText("|cff777777No conversation selected|r")
    self.msgs:Clear()
    self.lastDay = nil
    local hints = {
        dm = "Click + New message to start a conversation.",
        groups = "Click + New group to create a group chat or join one with an invite code.",
        channels = "Click + Follow channel to bring guild, party or other channels into Telegnome.",
    }
    self.msgs:AddMessage(hints[self.tab] or "", 0.55, 0.47, 0.32)
end

---------------------------------------------------------------------------
-- Hooks from Core
---------------------------------------------------------------------------

function UI:IsViewing(key)
    return self.frame and self.frame:IsShown() and self.selected == key
        and not TG.Settings:IsShown() and not TG.Groups:IsPanelShown()
        and not TG.Channels:IsPanelShown() or false
end

function UI:OnThreadUpdated(key, incoming)
    if not self.frame or not self.frame:IsShown() then return end
    if incoming then self:PulseCogs() end
    local th = TG.db.threads[key]
    local sameTab = th and UI.TabOf(th) == self.tab
    if (not self.selected or not TG.db.threads[self.selected]) and sameTab then
        self:Select(key)
        return
    end
    if key == self.selected and th then
        if #th.msgs == 1 then
            self:Select(key) -- clears the "New conversation" hint
        else
            local name, color = TG:ThreadDisplay(key)
            self:RenderMessage(th, th.msgs[#th.msgs], name, color)
        end
    end
    self:RefreshList()
end

function UI:OnThreadDeleted(key)
    if not self.frame then return end
    if self.selected == key then
        local first = self:SortedKeys()[1]
        if first then self:Select(first) else self:ShowEmpty() end
    end
    self:RefreshList()
end

function UI:OnShow()
    local key = self.selected
    if not key or not TG.db.threads[key] then key = self:SortedKeys()[1] end
    self:UpdateNewButton()
    if key then self:Select(key) else self:ShowEmpty() end
    self:RefreshList()
    TG:RefreshUnread()
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function UI:Show()
    self:Create()
    self.frame:Show()
end

function UI:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end
