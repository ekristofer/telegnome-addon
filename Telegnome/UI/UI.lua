-- Telegnome: messenger window (conversation list + conversation + message box).

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local num = S.Num
local UI = { rows = {}, offset = 0, tab = "all", selectedByTab = {} }
TG.UI = UI

local LIST_W = 216
local ROW_H = 40      -- a conversation in the list: name and time, preview and unread badge
local HEAD_H = 24     -- Pinned / Friends / Others
local HINT_H = 22     -- the grey line under an empty Pinned section
local SUB_H = 22      -- Friends / Others inside Direct messages on the All tab
local NAME_X = 22     -- every name starts here, with or without an online dot
local TOP = 74        -- where the list and the conversation start, below the header and the tabs
                      -- (set in UI:Create: the game's own frame has a lower title bar than the plain one)
UI.ROW_H = 26         -- the one-line rows of the New message picker
UI.MIN_W, UI.MIN_H = 700, 490

local function hex(c)
    return ("%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end
UI.hex = hex

-- Shared row look for the New message picker.
function UI:MakeRow(parent, top, i)
    local h = UI.ROW_H
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(h)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, top - (i - 1) * h)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, top - (i - 1) * h)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints()
    S.Paint(sel, "hi", 0.12)
    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(3)
    S.Paint(bar, "hi", 0.9)
    function row:SetSelected(v)
        sel:SetShown(v)
        bar:SetShown(v)
    end
    row:SetSelected(false)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    row.dot = S.Dot(row, 8)
    row.dot:SetPoint("LEFT", 8, 0)

    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.right:SetPoint("RIGHT", -22, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", NAME_X, 0)
    row.name:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

-- online: true / false, or nil when the game doesn't say (then there is no dot, and the name stays in line).
function UI.SetRowContact(row, name, color, online)
    row.name:SetText(name)
    row.name:SetTextColor(color[1], color[2], color[3])
    if online == nil then
        row.dot:Hide()
    else
        local c = online and S.ONLINE or S.OFFLINE
        row.dot:Show()
        row.dot:SetVertexColor(c[1], c[2], c[3])
    end
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------

local TABS = { { "all", "All" }, { "dm", "Direct" }, { "channels", "Channels" }, { "groups", "Groups" },
    { "requests", "Requests" }, { "business", "Business" } }

local function makeTab(parent, id, label)
    -- a boxed tab like the game's own: lit in the theme colour when it's the one you're on
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetHeight(26)
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tab.id, tab.baseText = id, label
    S.Flat(tab)
    local gloss = tab:CreateTexture(nil, "ARTWORK")
    gloss:SetPoint("TOPLEFT", 1, -1)
    gloss:SetPoint("RIGHT", -1, 0)
    gloss:SetHeight(11)
    gloss:SetColorTexture(1, 1, 1, 0.07)
    tab.gloss = gloss
    local fs = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", 12, 0)
    fs:SetText(label)
    tab.fs = fs
    tab.pill = S.Pill(tab, 16)
    tab.pill:SetPoint("LEFT", fs, "RIGHT", 6, 0)
    local hl = tab:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 1, 1, 0.05)
    -- Clicking a tab always leaves Settings and the other panels, also when it's the tab you're on.
    tab:SetScript("OnClick", function(s, button)
        if button == "RightButton" then
            UI:OpenTabMenu(s)
            return
        end
        UI:CloseOverlays()
        UI:SetTab(id)
    end)
    return tab
end

-- The game's own window frame: metal border, title bar, round medallion and the red close button.
-- Returns nil when this client doesn't have it (then the plain frame is used).
local function nativeFrame()
    local ok, f = pcall(CreateFrame, "Frame", nil, UIParent, "PortraitFrameTemplate")
    if ok and type(f) == "table" and f.SetPoint then return f end
    return nil
end

-- Telegnome's cog in the round medallion of the game's frame, on a dark disc. Returns the cog, or nil.
local function medallionCog(f)
    local holder = type(f.PortraitContainer) == "table" and f.PortraitContainer or nil
    local portrait = (holder and holder.portrait) or f.portrait or f.Portrait
    if type(portrait) ~= "table" or not portrait.SetTexture then return nil end
    portrait:SetTexture(S.ROUND)
    portrait:SetVertexColor(0.07, 0.05, 0.03, 1)
    local parent = (holder and holder.CreateTexture) and holder or f
    local layer, sub = "ARTWORK", 0
    if portrait.GetDrawLayer then
        local l, sl = portrait:GetDrawLayer()
        if type(l) == "string" then layer = l end
        if type(sl) == "number" then sub = sl end
    end
    local cog = parent:CreateTexture(nil, layer, nil, math.min(7, sub + 1))
    cog:SetTexture(S.COG)
    cog:SetPoint("TOPLEFT", portrait, "TOPLEFT", 7, -5)     -- 2 up: the ring's hole isn't centred on the portrait
    cog:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -7, 9)
    S.Paint(cog, "cog")
    return cog
end

function UI:Create()
    if self.frame then return end

    local f = nativeFrame()
    local native = f ~= nil
    if not f then f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate") end
    _G.TelegnomeFrame = f
    self.native = native
    TOP = native and 62 or 74
    f:SetSize(760, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    if f.SetResizeBounds then f:SetResizeBounds(UI.MIN_W, UI.MIN_H, 1400, 1000) end
    f:EnableMouse(true)
    if not native then S.Outer(f) end
    f:Hide()
    tinsert(UISpecialFrames, "TelegnomeFrame") -- Escape closes it
    self.frame = f
    self:ApplyOpacity()

    -- Drag handle over the title bar. It sits above the frame's own art, and the title and its cogs are on it.
    local bar = CreateFrame("Frame", nil, f)
    if native then
        bar:SetPoint("TOPLEFT", 60, -1)
        bar:SetPoint("TOPRIGHT", -54, -1)
        bar:SetHeight(20)
    else
        bar:SetPoint("TOPLEFT", 10, -8)
        bar:SetPoint("TOPRIGHT", -10, -8)
        bar:SetHeight(32)
    end
    -- above the frame's own pieces (border, title bar, close button), or its art covers what is on the bar
    local topLevel = f:GetFrameLevel() + 20
    if native then
        for _, key in ipairs({ "NineSlice", "TitleContainer", "CloseButton", "PortraitContainer" }) do
            local piece = f[key]
            local level = type(piece) == "table" and piece.GetFrameLevel and piece:GetFrameLevel()
            if type(level) == "number" and level + 2 > topLevel then topLevel = level + 2 end
        end
    end
    bar:SetFrameLevel(topLevel)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); UI:SavePos() end)
    self.bar = bar

    local title, logoOver
    self.cogs, self.cogSpins = {}, {}
    local function addCog(cog, duration, degrees)
        self.cogs[#self.cogs + 1] = cog
        self.cogSpins[#self.cogSpins + 1] = S.Spin(cog, duration, degrees)
    end
    if native then
        -- the name, large, centred in the title bar
        title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", f, "TOP", 0, -11)
        -- the cog in the medallion turns when a message arrives
        local ok, big = pcall(medallionCog, f)
        if ok and big then
            addCog(big, 1.6, 72)
            logoOver = big
        end
        local tc = f.TitleContainer
        if type(tc) == "table" and type(tc.TitleText) == "table" and tc.TitleText.SetText then tc.TitleText:SetText("") end
    else
        local cog = S.Cog(bar, 24)
        cog:SetPoint("LEFT", 6, 0)
        addCog(cog, 1.2, 144)
        title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("LEFT", cog, "RIGHT", 8, 0)
        logoOver = cog
    end
    self.title = title

    -- the tagline lives in a tooltip on the logo
    if logoOver then
        local logo = CreateFrame("Frame", nil, bar)
        logo:SetPoint("TOPLEFT", logoOver, "TOPLEFT", -2, 2)
        logo:SetPoint("BOTTOMRIGHT", logoOver, "BOTTOMRIGHT", 2, -2)
        logo:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:SetText("Telegnome")
            GameTooltip:AddLine("Gnomish Universal Messenger", 1, 1, 1)
            GameTooltip:Show()
        end)
        logo:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Close: the game's red X when the frame has one, otherwise a plain icon button.
    local close = native and type(f.CloseButton) == "table" and f.CloseButton.SetScript and f.CloseButton or nil
    local settingsBtn
    if close then
        close:SetScript("OnClick", function() f:Hide() end)
        -- Settings: a cog at the right end of the tab row, where there is room for a proper size
        settingsBtn = S.CogButton(f, 24)
        settingsBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -(TOP - 27))
        settingsBtn:SetFrameLevel(f:GetFrameLevel() + 3)
        function settingsBtn:SetLit(lit)
            self.lit = lit
            if lit then
                self.tex:SetVertexColor(1, 0.9, 0.55)
            else
                self.tex:SetVertexColor(S.BRASS[1], S.BRASS[2], S.BRASS[3])
            end
        end
        settingsBtn:HookScript("OnLeave", function(s) if s.lit then s:SetLit(true) end end)
    else
        close = S.IconButton(bar, S.CLOSE, 26, 12)
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, native and -30 or -11)
        close:SetScript("OnClick", function() f:Hide() end)
        S.Tooltip(close, "Close", "Escape closes the window too.")
        settingsBtn = S.IconButton(bar, S.WRENCH, 26, 15)
        settingsBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)
    end
    settingsBtn:HookScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Settings")
        GameTooltip:AddLine("Notifications, Do not disturb, window, chat options.", 1, 1, 1, true)
        GameTooltip:AddLine("Shift-click the minimap button also opens this.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    settingsBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    settingsBtn:SetScript("OnClick", function() TG.Settings:Toggle() end)
    self.settingsBtn = settingsBtn

    -- Tabs: plain labels, an unread badge, and a line under the one you're on.
    self.tabs = {}
    self.tabOrder = {}
    for i, def in ipairs(TABS) do
        local tab = makeTab(f, def[1], def[2])
        self.tabs[def[1]] = tab
        self.tabOrder[i] = tab
    end
    -- How far the content keeps from the window's edge: the game's frame has a thicker border.
    local mx = native and 8 or 2
    local baseLevel = f:GetFrameLevel() + 3
    if native then
        -- the game's dark inset with its thin inner border, behind the list and the conversation
        local ok, inset = pcall(CreateFrame, "Frame", nil, f, "InsetFrameTemplate")
        if ok and type(inset) == "table" and inset.SetPoint then
            inset:SetPoint("TOPLEFT", mx - 3, -(TOP - 3))
            inset:SetPoint("BOTTOMRIGHT", -(mx - 3), mx - 3)
            inset:SetFrameLevel(f:GetFrameLevel() + 1)
        end
    else
        local sep = S.Line(f)
        sep:SetPoint("TOPLEFT", 2, -(TOP - 1))
        sep:SetPoint("TOPRIGHT", -2, -(TOP - 1))
    end

    -- Everything below the tabs. Requests and Settings cover all of it.
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", mx, -TOP)
    body:SetPoint("BOTTOMRIGHT", -mx, mx)
    body:SetFrameLevel(baseLevel)
    self.body = body

    -- Left: New message + the list
    local left = S.Strip(f)
    left:SetPoint("TOPLEFT", mx, -TOP)
    left:SetPoint("BOTTOMLEFT", mx, mx)
    left:SetFrameLevel(baseLevel)
    left:SetWidth(LIST_W)
    if left.SetClipsChildren then left:SetClipsChildren(true) end
    self.left = left

    local vline = f:CreateTexture(nil, "ARTWORK")
    S.Paint(vline, "line")
    vline:SetWidth(1)
    vline:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    vline:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
    self.vline = vline

    local watermark = S.Cog(left, 160, "BACKGROUND")
    watermark:SetPoint("BOTTOMRIGHT", 50, -50)
    watermark:SetAlpha(0.05)

    local newBtn = S.Button(left, "+ New message", LIST_W - 52, 26)
    newBtn:SetPoint("TOPLEFT", 10, -10)
    local searchBtn = S.IconButton(left, S.SEARCH, 26, 15)
    searchBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)
    searchBtn:SetScript("OnClick", function() TG.Search:Toggle() end)
    S.Tooltip(searchBtn, "Search", "Find a message in any conversation. Also: /tg search <text>")
    self.searchBtn = searchBtn
    newBtn:SetScript("OnClick", function()
        if UI.tab == "requests" or UI.tab == "business" then
            TG.Requests:TogglePanel()
        elseif UI.tab == "groups" then
            TG.Groups:TogglePanel()
        elseif UI.tab == "channels" then
            TG.Channels:TogglePanel()
        elseif UI.tab == "all" and MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(newBtn, function(_, root)
                root:CreateButton("New message", function() TG.Picker:Open() end)
                root:CreateButton("New group chat", function() TG.Groups:OpenPanel() end)
                root:CreateButton("Follow a channel", function() TG.Channels:OpenPanel("follow") end)
                root:CreateButton("Add a filtered channel", function() TG.Channels:OpenPanel("filter") end)
                root:CreateButton("Open for business", function() UI:SetTab("business") end)
            end)
        else
            TG.Picker:Toggle()
        end
    end)
    self.newBtn = newBtn

    local list = CreateFrame("Frame", nil, left)
    list:SetPoint("TOPLEFT", 6, -44)
    list:SetPoint("BOTTOMRIGHT", -6, 6)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        UI.offset = math.max(0, (UI.offset or 0) - delta)
        UI:RefreshList()
    end)
    self.list = list

    -- a thin scroll indicator at the list's right edge, shown when not everything fits
    local track = CreateFrame("Frame", nil, left)
    track:SetPoint("TOPRIGHT", left, "TOPRIGHT", -1, -44)
    track:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -1, 6)
    track:SetWidth(3)
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0, 0, 0, 0.35)
    local thumb = track:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(3)
    S.Paint(thumb, "edgetex", 0.9)
    track:Hide()
    self.track, self.thumb = track, thumb

    local empty = list:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOPLEFT", 8, -8)
    empty:SetPoint("RIGHT", -8, 0)
    empty:SetJustifyH("LEFT")
    empty:SetText("No conversations yet.\nWhispers will show up here.")
    self.emptyText = empty

    -- Right: the conversation
    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPLEFT", mx + LIST_W + 1, -TOP)
    right:SetPoint("BOTTOMRIGHT", -mx, mx)
    right:SetFrameLevel(baseLevel)
    self.right = right

    -- The conversation itself sits in its own frame, so it can be hidden while a panel covers it:
    -- with a see-through window it would otherwise show through the panel.
    local conv = CreateFrame("Frame", nil, right)
    conv:SetAllPoints(right)
    self.conv = conv

    -- More: the conversation's menu (mute, clear history, close...)
    local moreBtn = S.IconButton(conv, S.DOTS, 24, 16)
    moreBtn:SetPoint("TOPRIGHT", -12, -11)
    moreBtn:SetScript("OnClick", function(s)
        if UI.selected then UI:OpenContactMenu(UI.selected, s) end
    end)
    S.Tooltip(moreBtn, "More", "Mute, clear history, close the conversation and more.")
    moreBtn:Hide()
    self.moreBtn = moreBtn

    -- Direct messages: favorite star (favorites stay in their own section at the top)
    local favBtn = S.IconButton(conv, S.STAR, 24, 15)
    favBtn:SetPoint("RIGHT", moreBtn, "LEFT", -6, 0)
    favBtn.star = favBtn.icon
    favBtn:SetScript("OnClick", function()
        local th = UI.selected and TG.db.threads[UI.selected]
        if th then TG:SetFavorite(UI.selected, not th.fav) end
    end)
    favBtn:SetScript("OnEnter", function(s)
        local th = UI.selected and TG.db.threads[UI.selected]
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(th and th.fav and "Unpin" or "Pin to the top")
        GameTooltip:AddLine(th and th.req and "Keeps this person: they move from Requests to your Direct messages."
            or "Pinned conversations stay at the top of the All tab (and of Direct messages, for people).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    favBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    favBtn:Hide()
    self.favBtn = favBtn

    -- Requests: invite to your group
    local inviteBtn = S.Button(conv, "Invite", 64, 24, true)
    inviteBtn:SetPoint("RIGHT", favBtn, "LEFT", -6, 0)
    inviteBtn:SetScript("OnClick", function()
        if UI.selected then TG.Requests:Invite(UI.selected) end
    end)
    S.Tooltip(inviteBtn, "Invite", "Invites this player to your group.")
    inviteBtn:Hide()
    self.inviteBtn = inviteBtn

    local renameBtn = S.Button(conv, "Rename", 70, 24)
    renameBtn:SetPoint("RIGHT", favBtn, "LEFT", -6, 0)
    renameBtn:SetScript("OnClick", function()
        if UI.selected then TG.Groups:AskRename(UI.selected) end
    end)
    S.Tooltip(renameBtn, "Rename group", "Changes the name on your side only.")
    renameBtn:Hide()
    self.renameBtn = renameBtn

    -- Groups: who's in the channel right now
    local whoBtn = S.Button(conv, "Online", 64, 24)
    whoBtn:SetPoint("RIGHT", renameBtn, "LEFT", -6, 0)
    whoBtn:SetScript("OnClick", function()
        if UI.selected then TG.Groups:RequestMembers(UI.selected) end
    end)
    S.Tooltip(whoBtn, "Who's online", "Lists the members who are in this group chat right now.")
    whoBtn:Hide()
    self.whoBtn = whoBtn

    -- Name on top, the details (realm, level, class, invite code) small underneath. Click for the menu.
    local headerBtn = CreateFrame("Button", nil, conv)
    headerBtn:SetPoint("TOPLEFT", 14, -6)
    headerBtn:SetPoint("TOPRIGHT", -120, -6)
    headerBtn:SetHeight(38)
    headerBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    headerBtn:SetScript("OnClick", function(s)
        if UI.selected then UI:OpenContactMenu(UI.selected, s) end
    end)
    self.headerBtn = headerBtn
    local header = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 0, -2)
    header:SetPoint("RIGHT")
    header:SetJustifyH("LEFT")
    header:SetWordWrap(false)
    self.header = header
    local sub = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
    sub:SetPoint("RIGHT")
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(false)
    sub:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    self.subHeader = sub

    local hsep = S.Line(conv)
    hsep:SetPoint("TOPLEFT", 12, -48)
    hsep:SetPoint("TOPRIGHT", -12, -48)

    local msgs = TG.MessageView.New(conv)
    msgs.frame:SetPoint("TOPLEFT", 12, -56)
    msgs.frame:SetPoint("BOTTOMRIGHT", -12, 52)
    msgs.compact = TG.db.settings.compactChat and true or false
    msgs.onLink = function(link, text, button)
        local code, name = link:match("^telegnome:join:([^:]+):(.*)$")
        if code then
            TG.Groups:Join(code, name)
        elseif SetItemRef then
            SetItemRef(link, text, button)
        end
    end
    self.msgs = msgs
    self:ApplyTextSize()

    local input = S.EditBox(conv)
    input:SetPoint("BOTTOMLEFT", 12, 12)
    input:SetPoint("BOTTOMRIGHT", -12, 12)
    input:SetHeight(30)
    input:SetMaxLetters(255)
    if input.SetMaxBytes then input:SetMaxBytes(255) end -- the game's limit is in bytes; a, o with dots take two
    input:SetScript("OnEnterPressed", function(s)
        local text = s:GetText()
        if UI.selected and text and text:match("%S") then
            if TG:Send(UI.selected, text) then
                s:SetText("")
                -- like the game's chat: the box lets go after sending, unless you'd rather keep typing
                if TG.db.settings.keepTyping == false then s:ClearFocus() end
            end
        else
            -- Enter on an empty box hands the keyboard to the game's own chat.
            s:ClearFocus()
            if TG.db.settings.enterToTelegnome then
                UI.skipCapture = GetTime()
                local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
                if open then pcall(open, "") end
            end
        end
    end)
    self.input = input

    -- Grey hint in the empty message box: who you're writing to, and how to send.
    local placeholder = input:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    placeholder:SetPoint("LEFT", 9, 0)
    placeholder:SetJustifyH("LEFT")
    self.placeholder = placeholder
    local sendHint = input:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    sendHint:SetPoint("RIGHT", -9, 0)
    sendHint:SetText("Enter to send")
    self.sendHint = sendHint
    placeholder:SetPoint("RIGHT", sendHint, "LEFT", -8, 0)
    placeholder:SetWordWrap(false)
    input:HookScript("OnTextChanged", function() UI:UpdatePlaceholder() end)

    -- While the window is open on a conversation, Enter (the "open chat" key) puts the
    -- cursor in Telegnome's message box instead of the game's chat box.
    local function onOpenChat(text)
        if not (TG.db and TG.db.settings.enterToTelegnome) then return end
        if text ~= nil and text ~= "" then return end -- "/" or a prepared command: leave it
        if UI.skipCapture and GetTime() - UI.skipCapture < 0.5 then return end
        if not (f:IsShown() and UI.selected and input:IsVisible()) or UI:OverlayShown() then return end
        local active = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow())
            or (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
        if active then
            if (active:GetText() or "") ~= "" then return end
            if ChatFrameUtil and ChatFrameUtil.DeactivateChat then
                ChatFrameUtil.DeactivateChat(active)
            elseif ChatEdit_DeactivateChat then
                ChatEdit_DeactivateChat(active)
            else
                active:ClearFocus()
            end
        end
        input:SetFocus()
    end
    if ChatFrameUtil and ChatFrameUtil.OpenChat then hooksecurefunc(ChatFrameUtil, "OpenChat", onOpenChat) end
    if ChatFrame_OpenChat then hooksecurefunc("ChatFrame_OpenChat", onOpenChat) end

    -- Shift-clicked items, quests, achievements... go into this box while it has the cursor.
    local function insertLink(link)
        if type(link) ~= "string" or not input:IsVisible() or not input:HasFocus() then return end
        local now = GetTime()
        if UI.lastLink == link and now - (UI.lastLinkAt or 0) < 0.2 then return end
        UI.lastLink, UI.lastLinkAt = link, now
        input:Insert(link)
    end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", insertLink)
    elseif ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", insertLink)
    end

    -- Resize grip
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", native and -7 or -3, native and 7 or 3)
    grip:SetFrameLevel(right:GetFrameLevel() + 40)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing(); UI:SavePos(); UI:RefreshList(); TG.Picker:Refresh()
    end)

    f:SetScript("OnSizeChanged", function() UI:RefreshList(); TG.Picker:Refresh() end)
    f:SetScript("OnUpdate", function(_, elapsed)
        UI:UpdateAlpha(elapsed)
        UI:UpdateCovered()
    end)
    f:SetScript("OnShow", function() UI:OnShow() end)
    f:SetScript("OnHide", function()
        TG.Picker:Close(); TG.Settings:Close(); TG.Groups:ClosePanel(); TG.Channels:ClosePanel(); TG.ChannelList:Close(); TG.Requests:ClosePanel()
        TG.Search:Close()
    end)

    self:RestorePos()
    self:UpdateTitle()
end

-- Hides whatever a panel is covering, and shows where you are: while Settings is open its button is lit
-- and no tab is marked.
function UI:UpdateCovered()
    local settings = TG.Settings:IsShown() and true or false
    local whole = settings or TG.Requests:IsPanelShown() or false          -- these cover the list too
    local otherPanel = TG.Groups:IsPanelShown() or TG.Channels:IsPanelShown() or TG.ChannelList:IsShown() or false
    local picker = TG.Picker.frame and TG.Picker.frame:IsShown() or false  -- this one covers just the list
    -- Search gives way when another panel opens on top of it
    if TG.Search:IsShown() and (whole or otherPanel or picker) then TG.Search:Close() end
    local convCovered = whole or otherPanel or TG.Search:IsShown() or false
    local state = (settings and 1 or 0) + (whole and 2 or 0) + (convCovered and 4 or 0) + (picker and 8 or 0)
    if state == self.coveredState then return end
    self.coveredState = state
    self.left:SetShown(not whole)
    self.vline:SetShown(not whole)
    self.conv:SetShown(not convCovered)
    self.list:SetShown(not picker)
    self.settingsBtn:SetLit(settings)
    self:UpdateTabs()
end

function UI:UpdatePlaceholder()
    if not self.placeholder then return end
    local empty = (self.input:GetText() or "") == ""
    local th = self.selected and TG.db.threads[self.selected]
    self.placeholder:SetText(th and ("Message " .. (TG:ThreadDisplay(self.selected)) .. "...") or "")
    self.placeholder:SetShown(empty)
    self.sendHint:SetShown(empty and th ~= nil)
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
    if p.w and p.h then f:SetSize(math.max(p.w, UI.MIN_W), math.max(p.h, UI.MIN_H)) end
end

---------------------------------------------------------------------------
-- Right-click player menu
---------------------------------------------------------------------------

-- Uses the game's own player/friend menu (invite, add friend, ignore, report...),
-- like right-clicking a name in chat. Falls back to a small menu of our own.
function UI:OpenContactMenu(key, anchor)
    local rec = TG.db.threads[key] or TG.db.contacts[key]
    if not rec then return end
    -- Lets the game's player menu pick up Telegnome's entries (people only).
    self.menuKey, self.menuAt = (rec.kind == "WHISPER" or rec.kind == "BN") and key or nil, GetTime()

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
            local name = acct.accountName
            if type(name) ~= "string" or TG.isSecret(name) then name = acct.battleTag end
            -- The game's menu sometimes opens nothing (seen for offline friends): then ours is used.
            if pcall(FriendsFrame_ShowBNDropdown, name, online, nil, "BN_WHISPER", nil, nil, id)
                and UI.MenuOpened(not online) then
                return
            end
        end
    elseif FriendsFrame_ShowDropdown then
        if pcall(FriendsFrame_ShowDropdown, TG.WhisperTarget(rec.name), true, nil, "WHISPER", nil, nil, nil,
            nil, nil, nil, nil, rec.guid) and UI.MenuOpened(false) then
            return
        end
    end
    self:OpenFallbackMenu(key, rec, anchor)
end

-- Whether the game's menu really opened. When the game can't tell us, `guess` is the answer.
function UI.MenuOpened(guessNot)
    local mgr = Menu and Menu.GetManager and Menu.GetManager()
    if mgr and mgr.GetOpenMenu then
        local ok, open = pcall(mgr.GetOpenMenu, mgr)
        if ok then return open ~= nil end
    end
    return not guessNot
end

-- "Move up" / "Move down" for a pinned conversation.
function UI.AddPinMoveEntries(root, key)
    local th = TG.db.threads[key]
    if not (th and th.fav) then return end
    root:CreateButton("Move up in Pinned", function() UI:MovePinned(key, -1) end)
    root:CreateButton("Move down in Pinned", function() UI:MovePinned(key, 1) end)
end

-- Section headers with "Close all".
UI.CLOSE_ALL = { others = "others", all_others = "others", archive = "archive", all_archive = "archive" }

-- "Archive" / "Move out of Archive" (direct messages).
function UI.AddArchiveEntry(root, key)
    local th = TG.db.threads[key]
    if not th or th.fav or th.tempPin or (th.kind ~= "WHISPER" and th.kind ~= "BN") then return end
    if TG:IsArchived(th) then
        root:CreateButton("Move out of Archive", function() TG:SetArchived(key, false) end)
    else
        root:CreateButton("Archive", function() TG:SetArchived(key, true) end)
    end
end

-- Telegnome's own entries for a person's right-click menu.
function UI.AddMenuEntries(root, key)
    local th = TG.db.threads[key]
    root:CreateButton(TG.Social:GetNote(key) and "Edit note..." or "Add note...", function() TG.Social:EditNote(key) end)
    if th then
        root:CreateButton("Search in this conversation", function() TG.Search:Open(key) end)
        root:CreateButton(th.muted and "Unmute" or "Mute (no pop-ups or sound)", function()
            TG:SetMuted(key, not th.muted)
        end)
        root:CreateButton(th.fav and "Unpin" or "Pin to the top", function()
            TG:SetFavorite(key, not th.fav)
        end)
        UI.AddPinMoveEntries(root, key)
        UI.AddArchiveEntry(root, key)
        root:CreateButton("Clear history", function() TG:ConfirmClearHistory(key) end)
        root:CreateButton("Close conversation", function() TG:DeleteThread(key) end)
    end
    root:CreateButton("Forget contact", function() TG:ForgetContact(key) end)
end

function UI:OpenFallbackMenu(key, rec, anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local name = TG:ThreadDisplay(key)
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(name)
        if rec.kind == "WHISPER" then
            root:CreateButton("Invite to group", function()
                local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
                if invite then invite(TG.WhisperTarget(rec.name)) end
            end)
            root:CreateButton("Add friend", function()
                if C_FriendList then C_FriendList.AddFriend(TG.WhisperTarget(rec.name)) end
            end)
        end
        UI.AddMenuEntries(root, key)
    end)
end

-- When the game's own player menu is opened from Telegnome, add our entries to the end of it.
if Menu and Menu.ModifyMenu then
    local function extend(_, root)
        local key = UI.menuKey
        if not key or GetTime() - (UI.menuAt or 0) > 1 then return end
        if not (TG.db and (TG.db.threads[key] or TG.db.contacts[key])) then return end
        root:CreateDivider()
        root:CreateTitle("Telegnome")
        UI.AddMenuEntries(root, key)
    end
    for _, tag in ipairs({ "MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_BN_FRIEND", "MENU_UNIT_BN_FRIEND_OFFLINE" }) do
        pcall(Menu.ModifyMenu, tag, extend)
    end
end

---------------------------------------------------------------------------
-- Conversation list
---------------------------------------------------------------------------

-- One line of the newest message, for under the name.
function UI.PreviewOf(th)
    local m = th.msgs and th.msgs[#th.msgs]
    if not m or type(m.text) ~= "string" then return "" end
    local text = (m.text:gsub("[\r\n]+", " "))
    if m.sys then return text end
    if m.out then return "You: " .. text end
    if (th.kind == "GROUP" or th.kind == "CHANNEL") and m.from then return m.from .. ": " .. text end
    return text
end

-- 09:52 today, a weekday within the last week, a date before that.
function UI.ShortTime(t)
    if type(t) ~= "number" then return "" end
    local now = time()
    if date("%Y-%m-%d", t) == date("%Y-%m-%d", now) then return date("%H:%M", t) end
    if now - t < 6 * 86400 then return date("%a", t) end
    return date("%d %b", t)
end

function UI:GetRow(i)
    local row = self.rows[i]
    if row then return row end

    row = CreateFrame("Button", nil, self.list)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- selected: a rounded tint with a bar in the theme colour on the left
    local sel = S.Rounded(row, 5)
    for _, t in ipairs(sel.parts) do S.Paint(t, "hivertex", 0.13) end
    local bar = row:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 0, -4)
    bar:SetPoint("BOTTOMLEFT", 0, 4)
    bar:SetWidth(3)
    S.Paint(bar, "hi", 0.95)
    function row:SetSelected(v)
        sel:SetShown(v)
        bar:SetShown(v)
    end
    row:SetSelected(false)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)

    -- a conversation: [dot] name ........ time
    --                       preview ..... (badge)
    row.dot = S.Dot(row, 8)
    row.dot:SetPoint("TOPLEFT", 8, -10)

    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.time:SetPoint("TOPRIGHT", -8, -8)
    row.time:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", NAME_X, -6)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.preview = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.preview:SetPoint("BOTTOMLEFT", NAME_X, 7)
    row.preview:SetJustifyH("LEFT")
    row.preview:SetWordWrap(false)
    row.preview:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])

    row.pill = S.Pill(row, 16)
    row.pill:SetPoint("BOTTOMRIGHT", -8, 5)

    -- what kind of conversation: people have the online dot, groups a two-people icon, channels a #
    row.groupIcon = S.Icon(row, S.GROUP, 14)
    row.groupIcon:SetPoint("TOPLEFT", 5, -7)
    row.groupIcon:SetVertexColor(0.79, 0.64, 0.29)
    row.hash = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.hash:SetPoint("TOPLEFT", 7, -6)
    row.hash:SetText("#")
    row.hash:SetTextColor(0.56, 0.65, 0.79)
    -- a quiet channel's new messages: a dot instead of a number
    row.quiet = S.Dot(row, 7)
    row.quiet:SetPoint("BOTTOMRIGHT", -12, 10)
    row.quiet:SetVertexColor(0.79, 0.64, 0.29)
    -- the grey line under an empty Pinned section
    row.hint = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.hint:SetPoint("LEFT", NAME_X - 2, 0)
    row.hint:SetPoint("RIGHT", -6, 0)
    row.hint:SetJustifyH("LEFT")
    row.hint:SetTextColor(0.55, 0.50, 0.42)

    -- Close (x) on the selected row, where the time is on the others
    local x = CreateFrame("Button", nil, row)
    x:SetSize(16, 16)
    x:SetPoint("TOPRIGHT", -6, -5)
    local xi = S.Icon(x, S.CLOSE, 10)
    xi:SetPoint("CENTER")
    xi:SetVertexColor(S.DIM[1], S.DIM[2], S.DIM[3])
    x:SetScript("OnEnter", function(s)
        xi:SetVertexColor(1, 0.91, 0.69)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        if UI.tab == "groups" then
            GameTooltip:SetText("Leave group")
        elseif UI.tab == "channels" then
            GameTooltip:SetText("Unfollow channel")
        else
            GameTooltip:SetText("Close conversation")
            GameTooltip:AddLine("Closing removes the saved history; the contact stays in New message. "
                .. "Clear history (in the ... menu) keeps the conversation open.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    x:SetScript("OnLeave", function()
        xi:SetVertexColor(S.DIM[1], S.DIM[2], S.DIM[3])
        GameTooltip:Hide()
    end)
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

    -- a section header: [v] FAVORITES 2 ------------- (badge)
    row.chevDown = S.Icon(row, S.CHEV_DOWN, 10)
    row.chevDown:SetPoint("LEFT", 5, 0)
    row.chevDown:SetVertexColor(S.DIM[1], S.DIM[2], S.DIM[3])
    row.chevRight = S.Icon(row, S.CHEV_RIGHT, 10)
    row.chevRight:SetPoint("LEFT", 5, 0)
    row.chevRight:SetVertexColor(S.DIM[1], S.DIM[2], S.DIM[3])
    row.caption = S.Caption(row, "")
    row.caption:SetPoint("LEFT", NAME_X - 2, 0)
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    S.Paint(row.rule, "line")
    row.headPill = S.Pill(row, 16)
    row.headPill:SetPoint("RIGHT", -6, 0)

    -- "Close all" on the Others and Archive headers, while the mouse is over it
    local closeAll = S.Link(row, "Close all")
    closeAll:SetPoint("RIGHT", -6, 0)
    closeAll:SetScript("OnClick", function()
        if UI.CLOSE_ALL[row.header] == "archive" then TG:ConfirmCloseArchived() else TG:ConfirmCloseOthers() end
    end)
    closeAll:HookScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Close all")
        if UI.CLOSE_ALL[row.header] == "archive" then
            GameTooltip:AddLine("Closes every archived conversation and its history. The people stay in New message.",
                1, 1, 1, true)
        else
            GameTooltip:AddLine("Closes every conversation under Others and forgets those contacts. "
                .. "Pinned conversations and friends are not touched.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    closeAll:HookScript("OnLeave", function() GameTooltip:Hide() end)
    closeAll:Hide()
    row.closeAll = closeAll
    local function hover()
        if not UI.CLOSE_ALL[row.header] then return end
        local over = row:IsMouseOver() and true or false
        closeAll:SetShown(over)
        row.headPill:SetShown(not over and (row.headUnread or 0) > 0)
        UI:LayoutHeaderRule(row)
    end
    row:HookScript("OnEnter", hover)
    row:HookScript("OnLeave", hover)
    closeAll:HookScript("OnLeave", hover)

    -- drag a pinned conversation onto another pinned one to reorder Pinned
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(s)
        local th = s.key and TG.db.threads[s.key]
        if not (th and th.fav) then return end
        UI.dragKey = s.key
        s:SetAlpha(0.5)
    end)
    row:SetScript("OnDragStop", function(s)
        s:SetAlpha(1)
        local key = UI.dragKey
        UI.dragKey = nil
        if not key then return end
        for _, r in ipairs(UI.rows) do
            if r ~= s and r:IsShown() and r.key and r:IsMouseOver() then
                local th = TG.db.threads[r.key]
                if th and th.fav then UI:MovePinned(key, r.key) end
                return
            end
        end
    end)
    row:SetScript("OnClick", function(s, button)
        if s.header and button == "RightButton" then
            UI:OpenHeaderMenu(s)
            return
        end
        if s.header then
            TG.db.collapsed[s.header] = not TG.db.collapsed[s.header] or nil
            UI:RefreshList()
            return
        end
        if not s.key then return end
        if button == "RightButton" then
            UI:OpenContactMenu(s.key, s)
        else
            UI:CloseOverlays()
            UI:Select(s.key)
            UI.input:SetFocus()
        end
    end)

    self.rows[i] = row
    return row
end

-- The thin line of a section header runs from the label to whatever sits on the right.
function UI:LayoutHeaderRule(row)
    local reserve = 6
    if row.closeAll:IsShown() then
        reserve = reserve + num(row.closeAll:GetWidth(), 50) + 6
    elseif row.headPill:IsShown() then
        reserve = reserve + num(row.headPill:GetWidth(), 16) + 6
    end
    row.rule:ClearAllPoints()
    row.rule:SetPoint("LEFT", row.caption, "RIGHT", 8, 0)
    row.rule:SetPoint("RIGHT", row, "RIGHT", -reserve, 0)
end

local function showHint(row, e)
    row.key, row.headUnread, row.sectionKeys = nil, nil, nil
    row.dot:Hide(); row.name:Hide(); row.time:Hide(); row.preview:Hide(); row.pill:Hide(); row.close:Hide()
    row.chevDown:Hide(); row.chevRight:Hide(); row.caption:Hide(); row.rule:Hide(); row.headPill:Hide(); row.closeAll:Hide()
    row.groupIcon:Hide(); row.hash:Hide(); row.quiet:Hide()
    row:SetSelected(false)
    row.hint:SetText(e.hint)
    row.hint:Show()
end

local function showHeader(row, e)
    row.key = nil
    row.headUnread = e.unread
    row.sectionKeys = e.keys
    row.dot:Hide(); row.name:Hide(); row.time:Hide(); row.preview:Hide(); row.pill:Hide(); row.close:Hide()
    row.groupIcon:Hide(); row.hash:Hide(); row.quiet:Hide(); row.hint:Hide()
    row:SetSelected(false)
    -- Friends / Others inside Direct messages sit a step in, a little quieter
    local indent = e.sub and 12 or 0
    row.chevDown:SetPoint("LEFT", 5 + indent, 0)
    row.chevRight:SetPoint("LEFT", 5 + indent, 0)
    row.caption:SetPoint("LEFT", NAME_X - 2 + indent, 0)
    row.caption:SetAlpha(e.sub and 0.8 or 1)
    row.rule:SetAlpha(e.sub and 0.5 or 1)
    row.chevDown:SetShown(not e.collapsed)
    row.chevRight:SetShown(e.collapsed)
    row.caption:Show()
    row.caption:SetText(("%s  |cff8a7a5c%d|r"):format(e.label:upper(), e.count))
    row.rule:Show()
    local over = UI.CLOSE_ALL[e.header] and row:IsMouseOver() and true or false
    row.closeAll:SetShown(over)
    row.headPill:SetCount(over and 0 or e.unread)
    UI:LayoutHeaderRule(row)
end

local function showChat(row, key, selected, width)
    local th = TG.db.threads[key]
    row.key, row.headUnread = key, nil
    row.chevDown:Hide(); row.chevRight:Hide(); row.caption:Hide(); row.rule:Hide(); row.headPill:Hide(); row.closeAll:Hide()
    row.hint:Hide()
    row.sectionKeys = nil
    local name, color, online = TG:ThreadDisplay(key)
    UI.SetRowContact(row, name, color, online)
    if th.muted then row.name:SetText(name .. " |cff888888(muted)|r") end
    row.name:Show()
    row.groupIcon:SetShown(th.kind == "GROUP")
    row.hash:SetShown(th.kind == "CHANNEL")
    if th.kind == "GROUP" or th.kind == "CHANNEL" then row.dot:Hide() end

    local last = th.msgs[#th.msgs]
    row.time:SetText(last and UI.ShortTime(last.t) or "")
    row.time:SetShown(not selected)
    row.close:SetShown(selected)
    row.name:SetWidth(math.max(40, width - NAME_X - 8 - (selected and 18 or num(row.time:GetStringWidth(), 30) + 6)))

    local unread = th.unread or 0
    local counted = TG.Channels.Counts(th)
    row.pill:SetCount((selected or not counted) and 0 or unread)
    row.quiet:SetShown(not selected and not counted and unread > 0)
    row.preview:SetText(UI.PreviewOf(th))
    row.preview:Show()
    row.preview:SetWidth(math.max(40, width - NAME_X - 8 - (row.pill:IsShown() and num(row.pill:GetWidth(), 16) + 6 or 0)))
    row:SetSelected(selected)
end

-- The All tab: everything except requests, and except channels set not to show there (unless pinned).
function UI.InAll(th)
    if th.req then return false end
    if th.kind == "CHANNEL" and th.inAll == false and not th.fav and not th.tempPin then return false end
    return true
end

function UI.Belongs(th, tab)
    if tab == "all" then return UI.InAll(th) end
    return UI.TabOf(th) == tab
end

-- Unread messages that count: a quiet channel's don't.
function UI.UnreadOf(th)
    if not TG.Channels.Counts(th) then return 0 end
    return th.unread or 0
end

function UI.TabOf(th)
    if th.req then return th.biz and "business" or "requests" end
    if th.kind == "GROUP" then return "groups" end
    if th.kind == "CHANNEL" then return "channels" end
    return "dm"
end

-- How the list is sorted inside each section (Settings > Window, right-click a section header, /tg sort).
UI.SORTS = { recent = "Most recent", name = "Name", unread = "Unread first" }
UI.SORT_ORDER = { "recent", "name", "unread" }

function UI:SetSort(how)
    if not UI.SORTS[how] then return end
    TG.db.settings.listSort = how
    self.offset = 0
    self:RefreshList()
    if TG.Settings and TG.Settings:IsShown() then TG.Settings:Refresh() end
end

function UI:SortedKeys(tab)
    tab = tab or self.tab
    local threads = TG.db.threads
    local keys = {}
    for k, th in pairs(threads) do
        if UI.Belongs(th, tab) then keys[#keys + 1] = k end
    end
    local how = TG.db.settings.listSort or "recent"
    local function recent(a, b) return (threads[a].order or 0) > (threads[b].order or 0) end
    if how == "name" then
        local names = {}
        for _, k in ipairs(keys) do names[k] = tostring((TG:ThreadDisplay(k))):lower() end
        table.sort(keys, function(a, b)
            if names[a] ~= names[b] then return names[a] < names[b] end
            return recent(a, b)
        end)
    elseif how == "unread" then
        table.sort(keys, function(a, b)
            local ua, ub = (threads[a].unread or 0) > 0, (threads[b].unread or 0) > 0
            if ua ~= ub then return ua end
            return recent(a, b)
        end)
    else
        table.sort(keys, recent)
    end
    return keys
end

-- Right-click a section header: mark it as read, or choose how the list is sorted.
function UI:OpenHeaderMenu(row)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local keys = row.sectionKeys or {}
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateButton("Mark all as read", function() TG:MarkRead(keys) end)
        root:CreateDivider()
        root:CreateTitle("Sort conversations")
        for _, how in ipairs(UI.SORT_ORDER) do
            root:CreateRadio(UI.SORTS[how], function() return (TG.db.settings.listSort or "recent") == how end,
                function() UI:SetSort(how) end)
        end
    end)
end

-- Right-click a tab: mark everything in it as read.
function UI:OpenTabMenu(tab)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(tab, function(_, root)
        root:CreateTitle(tab.baseText)
        root:CreateButton("Mark all as read", function()
            TG:MarkRead((tab.id == "requests" or tab.id == "business") and TG.Requests:Keys(tab.id)
                or UI:SortedKeys(tab.id))
        end)
    end)
end

-- Choose how the list is sorted.
function UI:OpenSortMenu(anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle("Sort conversations")
        for _, how in ipairs(UI.SORT_ORDER) do
            root:CreateRadio(UI.SORTS[how], function() return (TG.db.settings.listSort or "recent") == how end,
                function() UI:SetSort(how) end)
        end
    end)
end

local SECTIONS = {
    { id = "fav", label = "Pinned" },
    { id = "friends", label = "Friends" },
    { id = "others", label = "Others" },
    { id = "archive", label = "Archive" },
}

-- What the list shows, top to bottom: { key = ... } rows and, on the Direct messages tab,
local ALL_SECTIONS = {
    { id = "all_pinned", label = "Pinned" },
    { id = "all_dm", label = "Direct messages" },
    { id = "all_channels", label = "Channels" },
    { id = "all_groups", label = "Group chats" },
    { id = "all_archive", label = "Archive" },
}

-- Pinned is in your own order: a dungeon's chat first while you're inside, then by pinOrder (drag to change),
-- then pins from before 0.9 in the list's sort order.
local function sortPinned(b, threads)
    local pos = {}
    for i, k in ipairs(b) do pos[k] = i end
    table.sort(b, function(x, y)
        local a, c = threads[x], threads[y]
        local ta, tc = (a.tempPin and not a.fav) and true or false, (c.tempPin and not c.fav) and true or false
        if ta ~= tc then return ta end
        local pa, pc = a.pinOrder or math.huge, c.pinOrder or math.huge
        if pa ~= pc then return pa < pc end
        return pos[x] < pos[y]
    end)
end

-- Every pinned conversation (any kind), in Pinned's order.
function UI:PinnedKeys()
    local threads, b = TG.db.threads, {}
    for k, th in pairs(threads) do
        if th.fav then b[#b + 1] = k end
    end
    table.sort(b, function(x, y) return (threads[x].order or 0) > (threads[y].order or 0) end)
    sortPinned(b, threads)
    return b
end

-- Moves a pinned conversation: by a step (-1 up, 1 down), or onto another pinned one (dragging).
function UI:MovePinned(key, target)
    local order = self:PinnedKeys()
    local from
    for i, k in ipairs(order) do if k == key then from = i end end
    if not from then return end
    local to
    if type(target) == "number" then
        to = math.max(1, math.min(#order, from + target))
    else
        for i, k in ipairs(order) do if k == target then to = i end end
        if not to then return end
    end
    if to == from then return end
    table.remove(order, from)
    table.insert(order, to, key)
    for i, k in ipairs(order) do TG.db.threads[k].pinOrder = i end
    self:RefreshList()
end

-- Direct messages on the All tab, split into Friends and Others like the Direct tab.
local DM_SUBS = { { id = "all_friends", sec = "friends", label = "Friends" }, { id = "all_others", sec = "others", label = "Others" } }

function UI:AddDMSubsections(entries, keys)
    local threads, collapsed = TG.db.threads, TG.db.collapsed
    local parts = { friends = {}, others = {} }
    for _, k in ipairs(keys) do
        local p = TG:SectionOf(threads[k]) == "friends" and parts.friends or parts.others
        p[#p + 1] = k
    end
    for _, sub in ipairs(DM_SUBS) do
        local b = parts[sub.sec]
        if #b > 0 then
            local unread = 0
            for _, k in ipairs(b) do
                if k ~= self.selected then unread = unread + UI.UnreadOf(threads[k]) end
            end
            entries[#entries + 1] = {
                header = sub.id, sub = true, label = sub.label, count = #b, unread = unread, keys = b,
                collapsed = collapsed[sub.id] and true or false,
            }
            if not collapsed[sub.id] then
                for _, k in ipairs(b) do entries[#entries + 1] = { key = k } end
            end
        end
    end
end

-- The All tab: Pinned (anything starred, and a dungeon's chat while you're inside), then each kind.
function UI:BuildAllEntries(keys)
    local entries = {}
    if #keys == 0 then return entries end
    local threads = TG.db.threads
    local buckets = { all_pinned = {}, all_dm = {}, all_groups = {}, all_channels = {}, all_archive = {} }
    for _, k in ipairs(keys) do
        local th = threads[k]
        local id = (th.fav or th.tempPin) and "all_pinned" or TG:IsArchived(th) and "all_archive"
            or th.kind == "GROUP" and "all_groups"
            or th.kind == "CHANNEL" and "all_channels" or "all_dm"
        local b = buckets[id]
        b[#b + 1] = k
    end
    sortPinned(buckets.all_pinned, threads)
    local collapsed = TG.db.collapsed
    for _, sec in ipairs(ALL_SECTIONS) do
        local b = buckets[sec.id]
        if #b > 0 or sec.id == "all_pinned" then
            local unread = 0
            for _, k in ipairs(b) do
                if k ~= self.selected then unread = unread + UI.UnreadOf(threads[k]) end
            end
            entries[#entries + 1] = {
                header = sec.id, label = sec.label, count = #b, unread = unread, keys = b,
                collapsed = collapsed[sec.id] and true or false,
            }
            if not collapsed[sec.id] then
                if #b == 0 then
                    entries[#entries + 1] = { hint = "Star a person, group or channel to pin it here." }
                end
                if sec.id == "all_dm" then
                    self:AddDMSubsections(entries, b)
                else
                    for _, k in ipairs(b) do entries[#entries + 1] = { key = k } end
                end
            end
        end
    end
    return entries
end

-- The conversation at the top of the list as you see it (not inside a folded section), for picking
-- what to show when the open one closes or you switch tabs.
function UI:FirstKey()
    for _, e in ipairs(self:BuildEntries()) do
        if e.key then return e.key end
    end
    return self:SortedKeys()[1]
end

-- { header = id, ... } rows for Pinned / Friends / Others (sorted inside each).
function UI:BuildEntries()
    local keys = self:SortedKeys()
    if self.tab == "all" then return self:BuildAllEntries(keys) end
    local entries = {}
    if self.tab ~= "dm" then
        for i, k in ipairs(keys) do entries[i] = { key = k } end
        return entries
    end
    local threads = TG.db.threads
    local buckets = { fav = {}, friends = {}, others = {}, archive = {} }
    for _, k in ipairs(keys) do
        local th = threads[k]
        local b = buckets[TG:IsArchived(th) and "archive" or TG:SectionOf(th)]
        b[#b + 1] = k
    end
    sortPinned(buckets.fav, threads)
    local collapsed = TG.db.collapsed
    for _, sec in ipairs(SECTIONS) do
        local b = buckets[sec.id]
        if #b > 0 then
            local unread = 0
            for _, k in ipairs(b) do
                if k ~= self.selected then unread = unread + (threads[k].unread or 0) end
            end
            entries[#entries + 1] = {
                header = sec.id, label = sec.label, count = #b, unread = unread, keys = b,
                collapsed = collapsed[sec.id] and true or false,
            }
            if not collapsed[sec.id] then
                for _, k in ipairs(b) do entries[#entries + 1] = { key = k } end
            end
        end
    end
    return entries
end

function UI:RefreshList()
    if not self.frame or not self.frame:IsShown() then return end
    local entries = self:BuildEntries()
    local listH = math.max(ROW_H, num(self.list:GetHeight(), 300))
    local width = math.max(120, num(self.list:GetWidth(), LIST_W - 12))
    local function heightOf(e) return e.header and (e.sub and SUB_H or HEAD_H) or e.hint and HINT_H or ROW_H end

    -- don't scroll past the point where the last entries fill the list
    local fit, maxOffset = 0, #entries
    for i = #entries, 1, -1 do
        fit = fit + heightOf(entries[i])
        if fit > listH then break end
        maxOffset = i - 1
    end
    self.offset = math.max(0, math.min(self.offset or 0, maxOffset))

    local empties = {
        all = "No conversations yet.\nWhispers, group chats and followed\nchannels will show up here.",
        dm = "No conversations yet.\nWhispers will show up here.",
        groups = "No group chats yet.\nClick + New group to create\none or join with a code.",
        channels = "No followed channels yet.\nClick + Follow channel to\npick guild, party, Trade...",
    }
    self.emptyText:SetText(empties[self.tab] or "")
    self.emptyText:SetShown(#entries == 0)

    local y, used = 0, 0
    for idx = self.offset + 1, #entries do
        local e = entries[idx]
        local h = heightOf(e)
        if y + h > listH then break end
        used = used + 1
        local row = self:GetRow(used)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.list, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", 0, -y)
        row:SetHeight(h)
        row.header = e.header or nil
        if e.header then
            showHeader(row, e)
        elseif e.hint then
            showHint(row, e)
        else
            showChat(row, e.key, e.key == self.selected, width)
        end
        row:Show()
        y = y + h
    end
    for i = used + 1, #self.rows do
        self.rows[i].key = nil
        self.rows[i].header = nil
        self.rows[i]:Hide()
    end

    -- the scroll indicator: how much of the list shows, and where
    if self.track then
        if maxOffset > 0 then
            local trackH = num(self.track:GetHeight(), listH)
            local h = math.max(16, trackH * used / math.max(1, #entries))
            self.thumb:ClearAllPoints()
            self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(self.offset / maxOffset) * (trackH - h))
            self.thumb:SetHeight(h)
            self.track:Show()
        else
            self.track:Hide()
        end
    end
end

function UI:OnFavoriteChanged(key)
    if not self.frame then return end
    if self.selected == key then self:UpdateHeaderButtons(TG.db.threads[key]) end
    self:RefreshList()
end

-- Buttons to the right of the conversation's name.
function UI:UpdateHeaderButtons(th)
    local isGroup = th and th.kind == "GROUP" or false
    local isDM = th and (th.kind == "WHISPER" or th.kind == "BN") or false
    local isReq = th and th.req and true or false
    self.moreBtn:SetShown(th ~= nil)
    self.renameBtn:SetShown(isGroup)
    self.whoBtn:SetShown(isGroup)
    self.favBtn:SetShown(th ~= nil)
    self.inviteBtn:SetShown(isReq)
    if th then
        if th.fav then
            self.favBtn.star:SetVertexColor(1, 0.82, 0.1)
            self.favBtn.star:SetAlpha(1)
        else
            self.favBtn.star:SetVertexColor(0.6, 0.6, 0.6)
            self.favBtn.star:SetAlpha(0.55)
        end
    end
    -- the name gets whatever the buttons leave
    self.headerBtn:SetPoint("TOPRIGHT", -(isGroup and 226 or isReq and 148 or th and 78 or 48), -6)
end

-- Closes whatever panel is open over the conversation.
function UI:CloseOverlays()
    TG.Picker:Close()
    TG.Settings:Close()
    TG.Groups:ClosePanel()
    TG.Channels:ClosePanel()
    TG.ChannelList:Close()
    TG.Requests:ClosePanel()
    TG.Search:Close()
end

-- A passing note in the open conversation (not saved), e.g. who is online in a group.
function UI:ShowNote(key, text)
    if not self.frame or not self.frame:IsShown() or self.selected ~= key then return false end
    self.msgs:AddNote(text, 0.55, 0.75, 0.55)
    return true
end

function UI:UpdateTabs()
    if not self.tabs then return end
    local counts = { all = 0, dm = 0, groups = 0, channels = 0, requests = 0, business = 0 }
    for _, th in pairs(TG.db.threads) do
        local t = UI.TabOf(th)
        local n = UI.UnreadOf(th)
        counts[t] = counts[t] + n
        if UI.InAll(th) then counts.all = counts.all + n end
    end
    -- The Requests tab only exists while you're recruiting or still have requests.
    local showReq = TG.Requests:TabVisible()
    self.tabs.requests:SetShown(showReq)
    if self.tab == "requests" and not showReq then
        TG.Requests:ClosePanel()
        self:SetTab("all")
        return
    end
    local showBiz = TG.Business:TabVisible()
    self.tabs.business:SetShown(showBiz)
    if self.tab == "business" and not showBiz then
        TG.Requests:ClosePanel()
        self:SetTab("all")
        return
    end
    local prev
    local e = S.BRONZE
    local settings = TG.Settings and TG.Settings:IsShown()
    for _, tab in ipairs(self.tabOrder or {}) do
        local on = tab.id == self.tab and not settings
        tab.pill:SetCount(counts[tab.id])
        tab.gloss:SetShown(on)
        if on then
            tab:SetBackdropColor(e[1] * 0.5, e[2] * 0.5, e[3] * 0.5, 1)
            tab:SetBackdropBorderColor(e[1], e[2], e[3], 1)
            tab.fs:SetTextColor(1, 0.95, 0.8)
        else
            tab:SetBackdropColor(S.PANEL[1] * 0.9, S.PANEL[2] * 0.9, S.PANEL[3] * 0.9, 1)
            tab:SetBackdropBorderColor(e[1], e[2], e[3], 0.35)
            tab.fs:SetTextColor(0.62, 0.57, 0.48)
        end
        tab:SetWidth(num(tab.fs:GetStringWidth(), 90) + 24
            + (tab.pill:IsShown() and num(tab.pill:GetWidth(), 16) + 6 or 0))
        if tab:IsShown() then -- hidden tabs leave no gap
            tab:ClearAllPoints()
            if prev then
                tab:SetPoint("LEFT", prev, "RIGHT", 4, 0)
            else
                -- next to the medallion in the game's frame
                tab:SetPoint("TOPLEFT", self.frame, "TOPLEFT", self.native and 66 or 14, -(TOP - 28))
            end
            prev = tab
        end
    end
end

function UI:UpdateNewButton()
    if not self.newBtn then return end
    local labels = { all = "+ New", dm = "+ New message", groups = "+ New group", channels = "+ Follow channel",
        requests = "All requests", business = "All whispers" }
    self.newBtn:SetText(labels[self.tab] or "+ New message")
end

function UI:SetTab(tab)
    self:Create()
    if self.tab ~= tab then
        TG.Picker:Close()
        TG.Groups:ClosePanel()
        TG.Channels:ClosePanel()
        TG.ChannelList:Close()
        TG.Requests:ClosePanel()
    end
    self.tab = tab
    self.offset = 0
    if tab ~= "requests" and tab ~= "business" then TG.db.lastTab = tab end
    self:UpdateNewButton()
    self:UpdateTabs()
    if self.tab ~= tab then return end -- the tab isn't available (no requests); UpdateTabs moved on
    -- The conversation last open in this tab - unless it has moved to another tab since
    -- (a request that was starred, a stranger who became a request...).
    local key = self.selectedByTab[tab]
    local th = key and TG.db.threads[key]
    if not th or not UI.Belongs(th, tab) then
        key = self:FirstKey()
        self.selectedByTab[tab] = key
    end
    if key then self:Select(key) else self:ShowEmpty() end
    self.tab = tab
    self:RefreshList()
    if tab == "requests" or tab == "business" then TG.Requests:OpenPanel(true, tab) end -- start on the overview
end

-- The window's name. Unread counts are on the tabs, so there is none here.
function UI:UpdateTitle()
    self:UpdateTabs()
    if not self.title then return end
    local text = TG.Slay and TG.Slay:IsOn() and TG.Slay.Text("Telegnome") or "Telegnome"
    if TG.db.settings.dnd then text = text .. "  |cffff9944Do not disturb|r" end
    self.title:SetText(text)
end

---------------------------------------------------------------------------
-- Conversation
---------------------------------------------------------------------------

function UI.YouColor()
    return TG.Slay and TG.Slay:IsOn() and "|cffff69b4" or "|cffaaaaaa"
end

local YOU = { 0.96, 0.82, 0.48 }
local YOU_SLAY = { 1, 0.41, 0.71 }
local OTHER = { 0.9, 0.9, 0.9 }

function UI:RenderMessage(th, m, name, color, idx)
    local view = self.msgs
    local day = date("%Y-%m-%d", m.t)
    if day ~= self.lastDay then
        self.lastDay = day
        view:AddDivider(date("%A %d %B", m.t))
    end
    if m.sys then
        view:AddNote(("%s  %s"):format(date("%H:%M", m.t), m.text), nil, nil, nil, true, idx)
        return
    end
    if m.out then
        view:AddMessage({ sender = "\1me", who = "You", out = true, t = m.t, text = m.text, idx = idx,
            color = TG.Slay and TG.Slay:IsOn() and YOU_SLAY or YOU })
        return
    end
    if th.kind == "GROUP" or th.kind == "CHANNEL" then
        local c = m.cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.cls]
        view:AddMessage({ sender = m.from or "?", who = m.from or "?", t = m.t, idx = idx,
            color = c and { c.r, c.g, c.b } or OTHER,
            text = (m.hl and "|cffffd100>>|r " or "")
                .. (th.kind == "CHANNEL" and TG.Channels.Highlight(th, m.text) or m.text) })
        return
    end
    local text = m.text
    local code, gname = TG.Groups.ParseInvite(m.text)
    if code then
        text = text .. ("\n|Htelegnome:join:%s:%s|h|cffffd100[Join %s]|r|h"):format(code, gname or "", gname or "group")
    end
    view:AddMessage({ sender = "\1them", who = name, color = color, t = m.t, text = text, idx = idx })
end

-- The small line under the name.
local function subLine(th, key)
    local parts = {}
    if th.kind == "GROUP" then
        parts[1] = th.code and ("Code: " .. th.code) or "Invite code unknown"
    elseif th.kind == "CHANNEL" then
        local C = TG.Channels
        if th.base then
            parts[1] = (th.customName and (C.AutoName(th) .. ", ") or "Filtered: ")
                .. "only messages with " .. table.concat(C.TypedWords(th.words), ", ")
        else
            parts[1] = "Followed channel"
            local own = C.Words(th.alertWords)
            if #own > 0 then parts[2] = "Alert words: " .. table.concat(own, ", ") end
        end
    elseif th.kind == "BN" then
        parts[1] = th.battleTag or "Battle.net"
    elseif th.kind == "WHISPER" then
        local realm = type(th.name) == "string" and th.name:match("%-(.+)$")
        if realm then parts[#parts + 1] = realm end
        if th.level or th.class then
            local class = th.class and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[th.class]) or th.class)
            parts[#parts + 1] = (th.level and ("Level " .. th.level) or "") .. (th.level and class and " " or "")
                .. (class or "")
        end
    end
    if th.muted then parts[#parts + 1] = "Muted" end
    local grouped = TG.Social and TG.Social:GroupedAt(th)
    if grouped then parts[#parts + 1] = "Grouped " .. UI.ShortTime(grouped) end
    local note = TG.Social and TG.Social:GetNote(key)
    if note then parts[#parts + 1] = "|cffd9b56a" .. note:gsub("|", "||") .. "|r" end
    return table.concat(parts, "  \194\183  ")
end

function UI:Select(key)
    local th = TG.db.threads[key]
    if not th then return end
    local tab = UI.TabOf(th)
    if self.tab == "all" and UI.InAll(th) then tab = "all" end
    if tab ~= self.tab then
        self.tab = tab
        self.offset = 0
        self:UpdateNewButton()
    end
    self.selectedByTab[tab] = key
    self.selected = key
    th.unread = 0

    local name, color = TG:ThreadDisplay(key)
    self.header:SetText(name)
    self.header:SetTextColor(color[1], color[2], color[3])
    self.subHeader:SetText(subLine(th, key))
    self:UpdateHeaderButtons(th)

    local view = self.msgs
    view:Clear()
    self.lastDay = nil
    view:Begin()
    if #th.msgs == 0 then
        view:AddNote("New conversation - type below and press Enter.", nil, nil, nil, true)
    end
    for i, m in ipairs(th.msgs) do self:RenderMessage(th, m, name, color, i) end
    view:End()

    self:UpdatePlaceholder()
    self:RefreshList()
    TG:RefreshUnread()
end

function UI:ShowEmpty()
    self.selected = nil
    self.header:SetText("No conversation selected")
    self.header:SetTextColor(0.47, 0.47, 0.47)
    self.subHeader:SetText("")
    self:UpdateHeaderButtons(nil)
    self.msgs:Clear()
    self.lastDay = nil
    local hints = {
        all = "Click + New to start a conversation, make a group chat or follow a channel.",
        dm = "Click + New message to start a conversation.",
        groups = "Click + New group to create a group chat or join one with an invite code.",
        channels = "Click + Follow channel to bring guild, party or other channels into Telegnome.",
    }
    self.msgs:AddNote(hints[self.tab] or "", nil, nil, nil, true)
    self:UpdatePlaceholder()
end

---------------------------------------------------------------------------
-- Hooks from Core
---------------------------------------------------------------------------

-- A panel (settings, new group, follow channels, your channels) covers the conversation.
function UI:OverlayShown()
    return TG.Settings:IsShown() or TG.Groups:IsPanelShown() or TG.Channels:IsPanelShown()
        or TG.ChannelList:IsShown() or TG.Requests:IsPanelShown() or TG.Search:IsShown() or false
end

function UI:IsViewing(key)
    return self.frame and self.frame:IsShown() and self.selected == key and not self:OverlayShown() or false
end

function UI:OnThreadUpdated(key, incoming)
    if not self.frame or not self.frame:IsShown() then return end
    if incoming then self:PulseCogs() end
    local th = TG.db.threads[key]
    local sameTab = th and UI.Belongs(th, self.tab)
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
        local first = self:FirstKey()
        if first then self:Select(first) else self:ShowEmpty() end
    end
    self:RefreshList()
end

function UI:OnShow()
    if not self.tabRestored then
        self.tabRestored = true
        local last = TG.db.lastTab
        if last and last ~= "requests" and self.tabs and self.tabs[last] then self.tab = last end
    end
    local key = self.selected
    if not key or not TG.db.threads[key] then key = self:FirstKey() end
    self:UpdateNewButton()
    if key then self:Select(key) else self:ShowEmpty() end
    self:RefreshList()
    TG:RefreshUnread()
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- Bubbles or compact lines (Settings > Window).
function UI:ApplyChatStyle()
    if not self.msgs then return end
    self.msgs.compact = TG.db.settings.compactChat and true or false
    if self.selected and TG.db.threads[self.selected] then self:Select(self.selected) end
end

-- Message text size (Settings > Window): the chat font, two points smaller or larger.
local TEXT_SIZES = { small = -2, normal = 0, large = 2 }

function UI:ApplyTextSize()
    if not self.msgs or not ChatFontNormal then return end
    local path, size, flags = ChatFontNormal:GetFont()
    if type(path) ~= "string" or type(size) ~= "number" then return end
    local delta = TEXT_SIZES[TG.db and TG.db.settings.textSize or "normal"] or 0
    self.msgs:SetBodyFont(path, math.max(8, math.floor(size + 0.5) + delta), flags or "")
end

-- Main window opacity (Settings > Window). The notifier and minimap button aren't affected.
UI.MIN_OPACITY = 30

function UI:SetOpacity(percent)
    percent = math.floor((tonumber(percent) or 100) + 0.5)
    percent = math.max(self.MIN_OPACITY, math.min(100, percent))
    TG.db.settings.opacity = percent
    self:ApplyOpacity()
end

-- The chosen opacity - or solid while the mouse is over the window or you're typing in it.
-- (Not while the opacity slider is being dragged, so you see what you're choosing.)
function UI:TargetAlpha()
    local s = TG.db and TG.db.settings
    if not s then return 1 end
    local base = math.max(self.MIN_OPACITY, math.min(100, s.opacity or 100)) / 100
    if TG.Demo and TG.Demo.on then return 1 end -- sample conversations are for screenshots: always solid
    if base >= 1 or not s.opacityHover or TG.Settings.dragging then return base end
    if self.frame:IsMouseOver() or (self.input and self.input:HasFocus()) then return 1 end
    return base
end

function UI:ApplyOpacity()
    if not self.frame then return end
    self.frame:SetAlpha(self:TargetAlpha())
end

-- Fades between see-through and solid.
function UI:UpdateAlpha(elapsed)
    local target = self:TargetAlpha()
    local a = self.frame:GetAlpha()
    if a == target then return end
    if math.abs(a - target) < 0.02 then
        self.frame:SetAlpha(target)
    else
        self.frame:SetAlpha(a + (target - a) * math.min(1, (elapsed or 0) * 12))
    end
end

function UI:Show()
    self:Create()
    self.frame:Show()
end

function UI:Toggle()
    self:Create()
    self.frame:SetShown(not self.frame:IsShown())
end
