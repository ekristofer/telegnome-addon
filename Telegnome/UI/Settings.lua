-- Telegnome: settings panel (opens over the conversation pane). Scrolls when it doesn't fit.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local O = { checks = {}, radios = {} }
TG.Settings = O

local NOTIFY_FROM = {
    { "all", "Everyone" },
    { "friendsguild", "Friends & guild" },
    { "friends", "Friends only" },
}

-- Refreshes the title, minimap button and notifier after a change.
local function applyAll()
    TG:RefreshUnread()
end

function O:Create()
    if self.frame then return end
    UI:Create()

    local f = CreateFrame("Frame", nil, UI.right, "BackdropTemplate")
    f:SetAllPoints(UI.right)
    f:SetFrameLevel(UI.right:GetFrameLevel() + 30)
    S.Inset(f)
    f:SetBackdropColor(0.11, 0.08, 0.05, 1)
    f:EnableMouse(true)
    f:Hide()
    self.frame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText("Settings")
    local wrench = f:CreateTexture(nil, "ARTWORK")
    wrench:SetSize(18, 18)
    wrench:SetPoint("LEFT", title, "RIGHT", 6, 0)
    wrench:SetTexture(S.WRENCH)
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -34)
    line:SetPoint("TOPRIGHT", -8, -34)

    -- Scrolling body (mouse wheel), with a thin scroll indicator.
    local clip = CreateFrame("ScrollFrame", nil, f)
    clip:SetPoint("TOPLEFT", 4, -38)
    clip:SetPoint("BOTTOMRIGHT", -14, 40)
    clip:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, clip)
    content:SetSize(440, 400)
    clip:SetScrollChild(content)
    clip:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    self.clip = clip

    local track = CreateFrame("Frame", nil, f)
    track:SetPoint("TOPRIGHT", -5, -40)
    track:SetPoint("BOTTOMRIGHT", -5, 42)
    track:SetWidth(5)
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0, 0, 0, 0.35)
    local thumb = track:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(5)
    thumb:SetColorTexture(S.BRONZE[1], S.BRONZE[2], S.BRONZE[3], 0.9)
    local function updateThumb()
        local range = clip:GetVerticalScrollRange() or 0
        local trackH = track:GetHeight() or 0
        if range <= 1 or trackH <= 0 then
            track:Hide()
            return
        end
        track:Show()
        local visible = clip:GetHeight()
        local h = math.max(24, trackH * visible / (visible + range))
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -(clip:GetVerticalScroll() / range) * (trackH - h))
        thumb:SetHeight(h)
    end
    clip:SetScript("OnVerticalScroll", updateThumb)
    clip:SetScript("OnScrollRangeChanged", updateThumb)
    clip:SetScript("OnMouseWheel", function(s, delta)
        local range = s:GetVerticalScrollRange() or 0
        s:SetVerticalScroll(math.max(0, math.min(range, s:GetVerticalScroll() - delta * 36)))
    end)

    local y = -8
    local function section(text)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 14, y)
        fs:SetText(text)
        y = y - 22
    end
    local function gap(n) y = y - n end
    local function check(label, indent, get, set, tipTitle, tip)
        local c = S.Check(content, label)
        c:SetPoint("TOPLEFT", 12 + indent, y)
        y = y - 24
        c.get = get
        c:SetScript("OnClick", function(s)
            set(s:GetChecked() and true or false)
            applyAll()
            O:Refresh()
        end)
        if tipTitle then S.Tooltip(c, tipTitle, tip) end
        self.checks[#self.checks + 1] = c
        return c
    end
    local s = function() return TG.db.settings end

    ---------------------------------------------------------------- Do not disturb
    section("Do not disturb")
    self.dnd = check("Do not disturb", 0,
        function() return s().dnd end, function(v) TG:SetDND(v, true) end,
        "Do not disturb",
        "No pop-up previews and no sounds. Messages still arrive in Telegnome and the counter keeps counting. "
        .. "Also: /tg dnd, or Ctrl-click the notifier or minimap button.")
    self.dndReply = check("Auto-reply to whispers while it's on", 30,
        function() return s().dndReply end, function(v) s().dndReply = v end,
        "Auto-reply",
        "Answers whispers and Battle.net whispers with the message below, at most once per person every 30 minutes. "
        .. "Replies start with [Auto-reply] so two Telegnome users never answer each other forever.")

    local msgBox = S.EditBox(content)
    msgBox:SetPoint("TOPLEFT", 44, y - 2)
    msgBox:SetPoint("TOPRIGHT", -12, y - 2)
    msgBox:SetHeight(26)
    msgBox:SetMaxLetters(200)
    if msgBox.SetMaxBytes then msgBox:SetMaxBytes(240) end -- chat messages hold 255 bytes, prefix included
    msgBox:SetScript("OnTextChanged", function(box, userInput)
        if userInput then TG.db.settings.dndMessage = box:GetText() end
    end)
    msgBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    S.Tooltip(msgBox, "Auto-reply message", "Sent as \"[Auto-reply] <your message>\".")
    self.dndMessage = msgBox
    y = y - 36

    ---------------------------------------------------------------- Notifications
    section("Notifications")
    self.notify = check("Show a pop-up for new messages", 0,
        function() return s().notify end, function(v) s().notify = v end,
        "Pop-up", "The notifier grows to show who wrote and the start of the message, then shrinks back.")

    local from = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    from:SetPoint("TOPLEFT", 44, y - 3)
    from:SetText("From:")
    self.fromLabel = from
    local prev = from
    for _, opt in ipairs(NOTIFY_FROM) do
        local r = S.Radio(content, opt[2])
        r:SetPoint("LEFT", prev, "RIGHT", prev == from and 8 or 12, 0)
        r.value = opt[1]
        r:SetScript("OnClick", function()
            TG.db.settings.notifyFrom = opt[1]
            O:Refresh()
        end)
        prev = r.label
        self.radios[#self.radios + 1] = r
    end
    S.Tooltip(self.radios[3], "Friends only", "Battle.net friends and your in-game friends list.")
    y = y - 24
    self.notifyGroups = check("Also pop up for group chat messages", 30,
        function() return s().notifyGroups end, function(v) s().notifyGroups = v end,
        "Group chats", "Followed channels have their own Pop-up tick in the Followed channels tab.")

    check("Show who joins and leaves group chats", 30,
        function() return s().groupJoinLeave end, function(v) s().groupJoinLeave = v end,
        "Joined / left", "A grey line in the group when a member comes online (joins) or goes offline (leaves).")

    local kwLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    kwLabel:SetPoint("TOPLEFT", 44, y - 8)
    kwLabel:SetText("Alert words:")
    local kwBox = S.EditBox(content)
    kwBox:SetPoint("LEFT", kwLabel, "RIGHT", 8, 0)
    kwBox:SetPoint("RIGHT", content, "RIGHT", -12, 0)
    kwBox:SetHeight(24)
    kwBox:SetMaxLetters(200)
    kwBox:SetScript("OnTextChanged", function(box, userInput)
        if userInput then TG.db.settings.keywords = box:GetText() end
    end)
    kwBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    S.Tooltip(kwBox, "Alert words for followed channels",
        "Words separated by commas, e.g. LFM, tank, your name. A message in a followed channel that contains one "
        .. "pops up (and plays the sound) even if that channel's Pop-up box isn't ticked.")
    self.keywords = kwBox
    y = y - 32

    self.counter = check("Show the missed-messages counter on screen", 0,
        function() return s().counter end, function(v) s().counter = v end,
        "Counter", "A small cog with the number of unread messages. Click it to open Telegnome.")
    self.hideEmpty = check("Only when there are unread messages", 30,
        function() return s().counterHideEmpty end, function(v) s().counterHideEmpty = v end)

    local grow = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    grow:SetPoint("TOPLEFT", 44, y - 3)
    grow:SetText("Grows to the:")
    local prevG = grow
    self.growRadios = {}
    for _, opt in ipairs({ { "right", "Right" }, { "left", "Left" } }) do
        local r = S.Radio(content, opt[2])
        r:SetPoint("LEFT", prevG, "RIGHT", prevG == grow and 8 or 12, 0)
        r.value = opt[1]
        r:SetScript("OnClick", function()
            TG.db.settings.toastGrow = opt[1]
            TG.Toast:ApplyAnchor()
            O:Refresh()
        end)
        prevG = r.label
        self.growRadios[#self.growRadios + 1] = r
    end
    S.Tooltip(self.growRadios[2], "Grow to the left", "Handy if the counter sits near the right edge of the screen.")
    y = y - 24
    self.sound = check("Play a sound for new messages", 0,
        function() return s().sound end, function(v) s().sound = v end,
        "Sound", "For the same messages that can pop up: whispers from the people chosen under From, group chats "
        .. "(if they pop up) and followed channels with their Pop-up tick. Works with pop-ups switched off, and "
        .. "plays even when game sound effects are off. If whispers also show in the main chat you may hear the "
        .. "game's own whisper sound too.")
    local sndLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sndLabel:SetPoint("TOPLEFT", 44, y - 3)
    sndLabel:SetText("Sound:")
    self.soundLabel = sndLabel
    local prevS = sndLabel
    self.soundRadios = {}
    for _, snd in ipairs(TG.SOUNDS) do
        local r = S.Radio(content, snd.label)
        r:SetPoint("LEFT", prevS, "RIGHT", prevS == sndLabel and 8 or 12, 0)
        r.value = snd.id
        r:SetScript("OnClick", function()
            TG.db.settings.soundChoice = snd.id
            TG:PlayAlert(snd.id)
            O:Refresh()
        end)
        prevS = r.label
        self.soundRadios[#self.soundRadios + 1] = r
    end
    local test = S.Button(content, "Test", 56, 20)
    test:SetPoint("LEFT", prevS, "RIGHT", 12, 0)
    test:SetScript("OnClick", function() TG:PlayAlert() end)
    self.soundTest = test
    y = y - 26

    local preview = S.Button(content, "Preview", 90, 22)
    preview:SetPoint("TOPLEFT", 44, y - 2)
    preview:SetScript("OnClick", function() TG.Toast:Preview() end)
    self.preview = preview
    local reset = S.Button(content, "Reset position", 120, 22)
    reset:SetPoint("LEFT", preview, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function() TG.Toast:ResetPosition() end)
    S.Tooltip(reset, "Reset position", "Moves the notifier back to the top of the screen. Shift-drag it to move it yourself.")
    y = y - 34

    ---------------------------------------------------------------- Window
    section("Window")
    local opLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    opLabel:SetPoint("TOPLEFT", 18, y - 2)
    opLabel:SetText("Opacity")
    local opacity = S.Slider(content, 200, UI.MIN_OPACITY, 100, 5)
    opacity:SetPoint("LEFT", opLabel, "RIGHT", 12, 0)
    local opValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    opValue:SetPoint("LEFT", opacity, "RIGHT", 10, 0)
    opacity:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        opValue:SetText(v .. "%")
        if not O.refreshing then
            UI:SetOpacity(v)
            S.SetWidgetEnabled(O.opacityHover, v < 100)
        end
    end)
    -- While the handle is held, the window shows the chosen opacity even under the mouse.
    opacity:HookScript("OnMouseDown", function() O.dragging = true end)
    opacity:HookScript("OnMouseUp", function() O.dragging = false end)
    opacity:HookScript("OnHide", function() O.dragging = false end)
    S.Tooltip(opacity, "Window opacity", "Make the Telegnome window see-through, so you can keep it open and still "
        .. "see the game behind it. The notifier and minimap button stay as they are. Also: /tg opacity 30-100")
    self.opacity = opacity
    y = y - 28
    self.opacityHover = check("Solid while the mouse is over it or you're typing", 30,
        function() return s().opacityHover end, function(v) s().opacityHover = v; UI:ApplyOpacity() end,
        "Solid on hover", "A see-through window fades back to solid when you move the mouse over it or type in it. "
        .. "(While you drag the slider it stays see-through, so you can see what you're choosing.)")
    gap(6)

    ---------------------------------------------------------------- Chat
    section("Chat")
    self.only = check("Only in Telegnome (keep it all out of the main chat)", 0,
        TG.IsTelegnomeOnly and function() return TG:IsTelegnomeOnly() end, function(v) TG:SetTelegnomeOnly(v) end,
        "Only in Telegnome", "Whispers, Battle.net whispers, followed channels and group chats only show up in "
        .. "Telegnome. Or pick below. Also: /tg only")
    check("Whispers and Battle.net whispers", 30,
        function() return s().hideFromChat end, function(v) s().hideFromChat = v end,
        "Hide whispers", "Whispers and Battle.net whispers only show up in Telegnome. R (reply) still works.")
    check("Followed channels", 30,
        function() return s().hideChannels end, function(v) s().hideChannels = v end,
        "Hide followed channels", "Messages in followed channels (Guild, Party, Trade...) only show up in Telegnome.")
    self.groupsHidden = check("Group chats (always)", 30,
        function() return true end, function() end,
        "Group chats", "Group chats are hidden channels, so they always stay in Telegnome.")
    check("Enter types in Telegnome while its window is open", 0,
        function() return s().enterToTelegnome end, function(v) s().enterToTelegnome = v end,
        "Enter key", "With a conversation open, pressing Enter puts the cursor in Telegnome's message box "
        .. "instead of the game's chat. Press Enter again on the empty box to get the game's chat.")
    check("Pick up group codes from chat", 0,
        function() return s().detectInvites end, function(v) s().detectInvites = v end,
        "Group codes",
        "When someone sends \"Telegnome code: ...\" in a whisper, party, guild or other chat, "
        .. "it's filled in the next time you click + New group.")
    check("Show minimap button", 0,
        function() return not TG.db.minimap.hide end, function(v) TG.db.minimap.hide = not v end)
    gap(8)
    local slots = S.Button(content, "Your chat channels...", 160, 22)
    slots:SetPoint("TOPLEFT", 16, y)
    slots:SetScript("OnClick", function() TG.ChannelList:Open() end)
    S.Tooltip(slots, "Your chat channels",
        "Every chat channel your character is in - Blizzard, custom and Telegnome group chats - with a Leave button. "
        .. "The game allows 10.")
    y = y - 30

    ---------------------------------------------------------------- Your data
    gap(4)
    section("Your data")
    local info = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 18, y)
    info:SetPoint("RIGHT", content, "RIGHT", -14, 0)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")
    info:SetSpacing(2)
    info:SetText("What Telegnome saves: your conversations (the last 200 messages of each), the people you've "
        .. "talked to, your group chats with their invite codes, followed channels and these settings.\n\n"
        .. "Where: in one file on this computer, shared by all your characters -\n"
        .. "|cffd8b46aWTF > Account > (your account) > SavedVariables > Telegnome.lua|r\n\n"
        .. "Nothing is sent to anyone or uploaded anywhere. Deleting that file resets Telegnome.")
    y = y - 112
    local counts = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    counts:SetPoint("TOPLEFT", 18, y)
    counts:SetTextColor(0.85, 0.7, 0.4)
    self.dataCounts = counts
    y = y - 20
    local wipe = S.Button(content, "Delete all messages...", 170, 22)
    wipe:SetPoint("TOPLEFT", 16, y)
    wipe:SetScript("OnClick", function() TG:ConfirmClearAllHistory() end)
    S.Tooltip(wipe, "Delete all messages", "Empties every conversation after asking. Conversations, groups, "
        .. "contacts and settings stay. To remove one conversation's messages, use Clear history in it.")
    y = y - 30

    content:SetHeight(-y + 8)

    local done = S.Button(f, "Done", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -10, 10)
    done:SetScript("OnClick", function() O:Close() end)

    local ver = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("BOTTOMLEFT", 14, 16)
    ver:SetText("Telegnome v" .. TG.version)
end

function O:Refresh()
    if not self.frame then return end
    for _, c in ipairs(self.checks) do c:SetChecked(c.get()) end

    local st = TG.db.settings
    local notifyOn = st.notify
    for _, r in ipairs(self.radios) do
        r:SetChecked(r.value == (st.notifyFrom or "all"))
        S.SetWidgetEnabled(r, notifyOn)
    end
    local shade = notifyOn and 1 or 0.5
    self.fromLabel:SetTextColor(shade, shade, shade)
    self.preview:SetEnabled(notifyOn)
    S.SetWidgetEnabled(self.notifyGroups, notifyOn)
    S.SetWidgetEnabled(self.hideEmpty, st.counter)
    S.SetWidgetEnabled(self.groupsHidden, false)
    for _, r in ipairs(self.soundRadios) do
        r:SetChecked(r.value == (st.soundChoice or "bnet"))
        S.SetWidgetEnabled(r, st.sound)
    end
    self.soundTest:SetEnabled(st.sound)
    local sshade = st.sound and 1 or 0.5
    self.soundLabel:SetTextColor(sshade, sshade, sshade)
    for _, r in ipairs(self.growRadios) do r:SetChecked(r.value == (st.toastGrow or "right")) end

    self.refreshing = true
    self.opacity:SetValue(st.opacity or 100)
    self.refreshing = false
    S.SetWidgetEnabled(self.opacityHover, (st.opacity or 100) < 100)
    local nThreads, nMsgs, nContacts = TG:DataCounts()
    self.dataCounts:SetText(("Saved right now: %d conversations, %d messages, %d remembered contacts.")
        :format(nThreads, nMsgs, nContacts))
    if not self.keywords:HasFocus() then self.keywords:SetText(st.keywords or "") end

    -- Do not disturb
    S.SetWidgetEnabled(self.dndReply, st.dnd)
    local replyOn = st.dnd and st.dndReply
    if not self.dndMessage:HasFocus() then self.dndMessage:SetText(st.dndMessage or "") end
    self.dndMessage:SetEnabled(replyOn and true or false)
    self.dndMessage:SetAlpha(replyOn and 1 or 0.5)
end

function O:IsShown()
    return self.frame and self.frame:IsShown() or false
end

function O:Open()
    UI:Show()
    self:Create()
    TG.Picker:Close()
    TG.Groups:ClosePanel()
    TG.Channels:ClosePanel()
    TG.ChannelList:Close()
    self:Refresh()
    self.frame:Show()
    self.clip:SetVerticalScroll(0)
end

function O:Close()
    if not self:IsShown() then return end
    self.frame:Hide()
    -- Messages that arrived while settings covered the conversation are now seen.
    if UI.frame:IsShown() and UI.selected then UI:Select(UI.selected) end
end

function O:Toggle()
    if self:IsShown() then self:Close() else self:Open() end
end
