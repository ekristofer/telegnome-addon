-- Telegnome: settings (covers the list and the conversation). Categories on the left, one page at a time.

local _, ns = ...
local TG = ns.TG
local S = TG.Style
local UI = TG.UI
local O = { checks = {}, radios = {}, pages = {}, catButtons = {} }
TG.Settings = O

-- The order of the categories on the left.
local CATEGORIES = { "notify", "window", "chat", "requests", "data", "help" }
-- Where the cog opens from each tab: page, and the section on it.
local TAB_PAGE = {
    all = { "chat" },
    queue = { "requests" }, -- the LFM or Business section, whichever side is showing (O:Open)
}
local LIST_W = 216

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
    f:SetAllPoints(UI.body)
    f:SetFrameLevel(UI.right:GetFrameLevel() + 30)
    S.Flat(f)
    S.Paint(f, "cover")
    f:EnableMouse(true)
    f:Hide()
    self.frame = f

    -- Left: the categories
    local side = S.Strip(f)
    side:SetPoint("TOPLEFT", 0, 0)
    side:SetPoint("BOTTOMLEFT", 0, 0)
    side:SetWidth(LIST_W)
    self.side = side
    local vline = f:CreateTexture(nil, "ARTWORK")
    S.Paint(vline, "line")
    vline:SetWidth(1)
    vline:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
    vline:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 0, 0)
    local title = side:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Settings")
    local ver = side:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("BOTTOMLEFT", 16, 12)
    ver:SetText("Telegnome v" .. TG.version)

    -- Search: type a word and every matching setting is listed, whatever page it's on.
    local search = S.EditBox(side, true)
    search:SetPoint("TOPLEFT", 12, -40)
    search:SetPoint("RIGHT", -12, 0)
    search:SetHeight(24)
    search:SetMaxLetters(40)
    local ph = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ph:SetPoint("LEFT", 24, 0)
    ph:SetText("Search settings")
    search:SetScript("OnTextChanged", function(box)
        ph:SetShown(box:GetText() == "")
        if not O.jumping then O:Search(box:GetText()) end
    end)
    search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    search:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)
    S.Tooltip(search, "Search settings", "Type a word - sound, archive, combat, reply... - to list every setting "
        .. "that has it, whatever page it's on. Click one to go there.")
    self.search = search

    -- Right: the chosen page. It scrolls (mouse wheel) when it doesn't fit, with a thin scroll indicator.
    local clip = CreateFrame("ScrollFrame", nil, f)
    clip:SetPoint("TOPLEFT", LIST_W + 10, -8)
    clip:SetPoint("BOTTOMRIGHT", -14, 44)
    clip:EnableMouseWheel(true)
    clip:SetScript("OnSizeChanged", function(_, w)
        for _, pg in ipairs(O.pages) do pg.frame:SetWidth(w) end
    end)
    self.clip = clip

    local track = CreateFrame("Frame", nil, f)
    track:SetPoint("TOPRIGHT", -5, -10)
    track:SetPoint("BOTTOMRIGHT", -5, 46)
    track:SetWidth(5)
    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0, 0, 0, 0.35)
    local thumb = track:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(5)
    S.Paint(thumb, "edgetex", 0.9)
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


    -- Everything below is built onto `content`, which is the page being filled; page() starts the next one,
    -- section() a heading on it. Every setting is also added to the search index.
    local content
    local y = -8
    local curPage, curLabel, curSection
    self.index, self.sections = {}, {}
    local function page(id, label, blurb)
        if content then content:SetHeight(-y + 8) end
        content = CreateFrame("Frame", nil, clip)
        content:SetSize(440, 400)
        content:Hide()
        self.pages[#self.pages + 1] = { id = id, label = label, frame = content }
        curPage, curLabel, curSection = id, label, nil
        self.sections[id] = {}
        y = -10
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", 14, y)
        fs:SetText(label)
        y = y - 24
        local sub = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        sub:SetPoint("TOPLEFT", 14, y)
        sub:SetText(blurb or "")
        sub:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
        y = y - 22
    end
    local function gap(n) y = y - n end
    local function section(title, key)
        gap(8)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 14, y)
        fs:SetText(title)
        local line = S.Line(content)
        line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", content, "RIGHT", -12, 0)
        self.sections[curPage][key or title] = y
        curSection = title
        y = y - 22
    end
    -- text: what the setting is called; tip: its longer explanation (also searched)
    local function index(text, tip, at)
        self.index[#self.index + 1] = { text = text, tip = tip, page = curPage, pageLabel = curLabel,
            section = curSection, y = at or y }
    end
    local function check(label, indent, get, set, tipTitle, tip)
        index(label, tip, y)
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
    self.replyBoxes = {}
    local function replyBox(label, get, set, what)
        index(label .. " (" .. (curSection or curLabel) .. ")", what, y)
        local l = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l:SetPoint("TOPLEFT", 18, y - 7)
        l:SetWidth(62)
        l:SetJustifyH("LEFT")
        l:SetText(label)
        local box = S.EditBox(content)
        box:SetPoint("TOPLEFT", 84, y)
        box:SetPoint("RIGHT", content, "RIGHT", -12, 0)
        box:SetHeight(24)
        box:SetMaxLetters(120)
        if box.SetMaxBytes then box:SetMaxBytes(240) end
        box.get = get
        box:SetScript("OnTextChanged", function(b, userInput) if userInput then set(b:GetText()) end end)
        box:SetScript("OnEnterPressed", function(b) b:ClearFocus() end)
        self.replyBoxes[#self.replyBoxes + 1] = box
        y = y - 28
        return box
    end

    ---------------------------------------------------------------- Notifications
    page("notify", "Notifications", "How Telegnome tells you about new messages, mail and more.")
    section("Pop-ups")
    self.notify = check("Show a pop-up for new messages", 0,
        function() return s().notify end, function(v) s().notify = v end,
        "Pop-up", "The notifier grows to show who wrote and the start of the message, then shrinks back.")

    index("Pop-ups from: Everyone, Friends & guild, Friends only", "Who can make a pop-up and a sound.")
    local from = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    from:SetPoint("TOPLEFT", 44, y - 3)
    from:SetText("From:")
    self.fromLabel = from
    local prev = from
    for _, opt in ipairs(NOTIFY_FROM) do
        local r = S.Radio(content, opt[2])
        r:SetPoint("LEFT", prev, "RIGHT", prev == from and 8 or 12, prev == from and 0 or -1)
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
    check("Tell me about unread messages when I log in", 30,
        function() return s().loginSummary ~= false end, function(v) s().loginSummary = v end,
        "On login", "A line in chat a few seconds after you log in, when messages from last time are still unread.")
    index("Preview the pop-up", "Shows a sample pop-up.")
    local preview = S.Button(content, "Preview", 90, 22)
    preview:SetPoint("TOPLEFT", 16, y - 2)
    preview:SetScript("OnClick", function() TG.Toast:Preview() end)
    self.preview = preview
    y = y - 30

    section("Sound")
    self.sound = check("Play a sound for new messages", 0,
        function() return s().sound end, function(v) s().sound = v end,
        "Sound", "For the same messages that can pop up: whispers from the people chosen under From, group chats "
        .. "(if they pop up) and followed channels with their Pop-up tick. Works with pop-ups switched off, and "
        .. "plays even when game sound effects are off. If whispers also show in the main chat you may hear the "
        .. "game's own whisper sound too.")
    index("Sound to play: choose and test", "Pick the sound for new messages and test it.")
    local sndLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sndLabel:SetPoint("TOPLEFT", 44, y - 3)
    sndLabel:SetText("Sound:")
    self.soundLabel = sndLabel
    local prevS = sndLabel
    self.soundRadios = {}
    for _, snd in ipairs(TG.SOUNDS) do
        local r = S.Radio(content, snd.label)
        r:SetPoint("LEFT", prevS, "RIGHT", prevS == sndLabel and 8 or 12, prevS == sndLabel and 0 or -1)
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

    section("In combat")
    index("In combat: show everything, summary afterwards, only the count",
        "What happens with pop-ups and sounds during a fight.")
    local cbLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbLabel:SetPoint("TOPLEFT", 44, y - 3)
    cbLabel:SetText("In combat:")
    local prevC = cbLabel
    self.combatRadios = {}
    local combatTips = {
        all = "Pop-ups and sounds as usual, also in the middle of a fight.",
        summary = "No pop-ups or sounds during the fight. When it's over, one pop-up says what came in.",
        count = "No pop-ups or sounds, and no summary. The notifier, the minimap button and the badges still count "
            .. "the new messages.",
    }
    for _, opt in ipairs({ { "all", "Show everything" }, { "summary", "Summary afterwards" }, { "count", "Only the count" } }) do
        local r = S.Radio(content, opt[2])
        r:SetPoint("LEFT", prevC, "RIGHT", prevC == cbLabel and 8 or 12, prevC == cbLabel and 0 or -1)
        r.value = opt[1]
        r:SetScript("OnClick", function()
            TG.db.settings.combatNotify = opt[1]
            O:Refresh()
        end)
        S.Tooltip(r, opt[2], combatTips[opt[1]])
        prevC = r.label
        self.combatRadios[#self.combatRadios + 1] = r
    end
    y = y - 24

    section("Do not disturb", "dnd")
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
    index("Auto-reply message", "The message sent while Do not disturb is on.")
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

    section("Group chats and channels", "groups")
    self.notifyGroups = check("Also pop up for group chat messages", 30,
        function() return s().notifyGroups end, function(v) s().notifyGroups = v end,
        "Group chats", "Followed channels have their own Pop-up tick (right-click a channel).")

    check("Show who joins and leaves group chats", 30,
        function() return s().groupJoinLeave end, function(v) s().groupJoinLeave = v end,
        "Joined / left", "A grey line in the group when a member comes online (joins) or goes offline (leaves). "
        .. "Off by default: the \"N online\" button in each group shows who's around without filling the chat.")
    index("Alert words for followed channels", "Words that make a message in a followed channel pop up.")
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

    section("Mail")
    check("Tell me when new mail arrives", 0,
        function() return s().mailNotify ~= false end, function(v) s().mailNotify = v end,
        "New mail", "A pop-up (and your sound, if sounds are on) when mail arrives, and when you log in with "
        .. "unread mail. The game only says who sent the latest three; open a mailbox to read them. Follows "
        .. "Do not disturb and the In combat choice under Notifications.")
    gap(8)
    local mailHint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    mailHint:SetPoint("TOPLEFT", 18, y)
    mailHint:SetText("{from} is filled in with who sent it, e.g. \"Thrall and Stormwind Auction House (2)\".")
    mailHint:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    y = y - 18
    local mailBox = replyBox("Text", function() return s().mailText or TG.Mail.DEFAULT_TEXT end,
        function(v) s().mailText = v end, "What the new mail pop-up says.")
    S.Tooltip(mailBox, "Notification text", "What the pop-up says. Leave it empty for the standard text: "
        .. TG.Mail.DEFAULT_TEXT)
    gap(4)
    local mailTest = S.Link(content, "Show an example")
    mailTest:SetPoint("TOPLEFT", 18, y)
    mailTest:SetScript("OnClick", function()
        TG.Mail:Notify({ { name = "Stormwind Auction House", n = 2 }, { name = "Thrall", n = 1 } }, true)
    end)
    y = y - 24

    ---------------------------------------------------------------- Look
    page("window", "Look", "How the window, the on-screen counter and the minimap button look.")
    section("Window")
    index("Theme (colours)", "The colour theme of the window.")
    local thLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    thLabel:SetPoint("TOPLEFT", 18, y - 4)
    thLabel:SetText("Theme")
    self.swatches = {}
    local prevSw
    for _, th in ipairs(S.THEMES) do
        local sw = CreateFrame("Button", nil, content, "BackdropTemplate")
        sw:SetSize(24, 24)
        if prevSw then sw:SetPoint("LEFT", prevSw, "RIGHT", 5, 0) else sw:SetPoint("LEFT", thLabel, "RIGHT", 14, 0) end
        sw:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        sw:SetBackdropColor(th.cog[1], th.cog[2], th.cog[3], 1)
        sw.theme = th
        sw:SetScript("OnClick", function()
            TG.db.settings.theme = th.id
            S.SetTheme(th.id)
            O:Refresh()
        end)
        S.Tooltip(sw, th.label)
        self.swatches[#self.swatches + 1] = sw
        prevSw = sw
    end
    local thName = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    thName:SetPoint("LEFT", prevSw, "RIGHT", 10, 0)
    self.themeName = thName
    y = y - 32
    index("Message text size: small, normal, large", "How big the text in conversations is.")
    local tsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tsLabel:SetPoint("TOPLEFT", 18, y - 2)
    tsLabel:SetText("Message text")
    self.sizeRadios = {}
    local prevT = tsLabel
    for _, opt in ipairs({ { "small", "Small" }, { "normal", "Normal" }, { "large", "Large" } }) do
        local r = S.Radio(content, opt[2])
        r:SetPoint("LEFT", prevT, "RIGHT", prevT == tsLabel and 14 or 12, prevT == tsLabel and 0 or -1)
        r.value = opt[1]
        r:SetScript("OnClick", function()
            TG.db.settings.textSize = opt[1]
            UI:ApplyTextSize()
            O:Refresh()
        end)
        prevT = r.label
        self.sizeRadios[#self.sizeRadios + 1] = r
    end
    y = y - 28
    index("Sort list by", "How conversations are sorted in the lists.")
    local soLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    soLabel:SetPoint("TOPLEFT", 18, y - 2)
    soLabel:SetText("Sort list by")
    self.sortRadios = {}
    local prevO = soLabel
    for _, how in ipairs(UI.SORT_ORDER) do
        local r = S.Radio(content, UI.SORTS[how])
        r:SetPoint("LEFT", prevO, "RIGHT", prevO == soLabel and 14 or 12, prevO == soLabel and 0 or -1)
        r.value = how
        r:SetScript("OnClick", function() UI:SetSort(how) end)
        S.Tooltip(r, "Sort list by", "How conversations are sorted inside each section (Pinned, Friends, "
            .. "Others) and in Group chats and Followed channels. Also: right-click a section header.")
        prevO = r.label
        self.sortRadios[#self.sortRadios + 1] = r
    end
    y = y - 28
    check("Compact chat: one line per message, no bubbles", 0,
        function() return s().compactChat end, function(v) s().compactChat = v; UI:ApplyChatStyle() end,
        "Compact chat", "Shows every message as one line - time, name, text - like the game's own chat. "
        .. "More messages fit on screen. Off: messages are grouped in bubbles, yours on the right.")
    gap(4)
    index("Opacity (see-through window)", "Make the window see-through. Also: /tg opacity 30-100")

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

    section("On-screen counter", "counter")
    self.counter = check("Show the missed-messages counter on screen", 0,
        function() return s().counter end, function(v) s().counter = v end,
        "Counter", "A small cog with the number of unread messages. Click it to open Telegnome.")
    self.hideEmpty = check("Only when there are unread messages", 30,
        function() return s().counterHideEmpty end, function(v) s().counterHideEmpty = v end)
    index("Counter grows to the left or right", "Which way the notifier grows.")
    local grow = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    grow:SetPoint("TOPLEFT", 44, y - 3)
    grow:SetText("Grows to the:")
    local prevG = grow
    self.growRadios = {}
    for _, opt in ipairs({ { "right", "Right" }, { "left", "Left" } }) do
        local r = S.Radio(content, opt[2])
        r:SetPoint("LEFT", prevG, "RIGHT", prevG == grow and 8 or 12, prevG == grow and 0 or -1)
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
    index("Reset the counter's position", "Moves the notifier back to the top of the screen.")
    local reset = S.Button(content, "Reset position", 120, 22)
    reset:SetPoint("TOPLEFT", 16, y - 2)
    reset:SetScript("OnClick", function() TG.Toast:ResetPosition() end)
    S.Tooltip(reset, "Reset position", "Moves the notifier back to the top of the screen. Shift-drag it to move it yourself.")
    y = y - 32
    section("Minimap")
    check("Show minimap button", 0,
        function() return not TG.db.minimap.hide end, function(v) TG.db.minimap.hide = not v end)

    ---------------------------------------------------------------- Chats
    page("chat", "Chats", "What shows up in Telegnome, and how the lists and typing work.")
    section("Keep out of the main chat", "out")
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
        "Group chats (always)", "Can't be turned off. A group chat is a hidden channel with a scrambled name and "
        .. "password worked out from its invite code, so in the main chat it would show up as something like "
        .. "[8. tg4f9k2x] instead of the group's name. Its messages only show up in Telegnome.")
    if self.groupsHidden.SetMotionScriptsWhileDisabled then
        self.groupsHidden:SetMotionScriptsWhileDisabled(true) -- so the explanation shows even though it's greyed out
    end

    section("Typing")
    check("Enter types in Telegnome while its window is open", 0,
        function() return s().enterToTelegnome end, function(v) s().enterToTelegnome = v end,
        "Enter key", "With a conversation open, pressing Enter puts the cursor in Telegnome's message box "
        .. "instead of the game's chat. Press Enter again on the empty box to get the game's chat.")
    check("Keep typing after sending a message", 0,
        function() return s().keepTyping ~= false end, function(v) s().keepTyping = v end,
        "Keep typing", "On: the cursor stays in the message box after you send, so you can write the next "
        .. "message straight away. Off: the box lets go after each message, like the game's chat, and you "
        .. "click it (or press Enter) to write again.")

    section("Lists")
    check("Count people I grouped with in the last week as friends", 0,
        function() return s().groupedFriends ~= false end, function(v) s().groupedFriends = v; TG:QueueRefresh() end,
        "Grouped with", "Players you were in a group with in the last seven days are listed under Friends, and their "
        .. "whispers don't go to the Lobby. The conversation says when you last grouped.")
    local archTip = "Direct messages with no new messages for this many days move to Archive, a folded section at "
        .. "the bottom of Chats. A new message brings them back. Right-click any conversation "
        .. "to archive it yourself, or to move it out."
    local arch = check("Archive direct messages after", 0,
        function() return s().archiveOn ~= false end, function(v) s().archiveOn = v; UI:RefreshList() end,
        "Archive", archTip)
    local days = S.EditBox(content)
    days:SetPoint("LEFT", arch.label, "RIGHT", 8, -1)
    days:SetSize(44, 22)
    days:SetNumeric(true)
    days:SetMaxLetters(3)
    days:SetJustifyH("CENTER")
    days:SetScript("OnTextChanged", function(box, userInput)
        if not userInput then return end
        local n = tonumber(box:GetText())
        if n and n >= 1 then
            s().archiveDays = n
            UI:RefreshList()
        end
    end)
    local function settle(box)
        box:SetText(tostring(s().archiveDays or 7))
        box:ClearFocus()
    end
    days:SetScript("OnEnterPressed", settle)
    days:SetScript("OnEditFocusLost", function(box) box:SetText(tostring(s().archiveDays or 7)) end)
    S.Tooltip(days, "Archive", archTip)
    local daysLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    daysLabel:SetPoint("LEFT", days, "RIGHT", 6, 1)
    daysLabel:SetText("days without new messages")
    self.archiveDays = days
    gap(4)
    -- small number settings: a label, a box, and a word after it
    self.numBoxes = self.numBoxes or {}
    local function numBox(label, key, default, min, after, tip)
        index(label .. " " .. after, tip, y)
        local l = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        l:SetPoint("TOPLEFT", 40, y - 4)
        l:SetText(label)
        local box = S.EditBox(content)
        box:SetPoint("LEFT", l, "RIGHT", 8, -1)
        box:SetSize(44, 22)
        box:SetNumeric(true)
        box:SetMaxLetters(3)
        box:SetJustifyH("CENTER")
        box.get = function() return tostring(s()[key] or default) end
        box:SetScript("OnTextChanged", function(b, userInput)
            if not userInput then return end
            local n = tonumber(b:GetText())
            if n and n >= min then s()[key] = n; UI:RefreshList() end
        end)
        box:SetScript("OnEnterPressed", function(b) b:SetText(b.get()); b:ClearFocus() end)
        box:SetScript("OnEditFocusLost", function(b) b:SetText(b.get()) end)
        S.Tooltip(box, label, tip)
        local a = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        a:SetPoint("LEFT", box, "RIGHT", 6, 1)
        a:SetText(after)
        self.numBoxes[#self.numBoxes + 1] = box
        y = y - 28
        return box
    end
    numBox("Others (people you don't know) after", "archiveOthersDays", 1, 1, "days",
        "People who aren't friends, guild members or people you grouped with go to Archive sooner, so strangers "
        .. "you whispered once tidy themselves away. Friends use the number above.")
    gap(4)
    numBox("Show up to", "sectionLimit", 5, 0, "of today's chats per section",
        "Each section in Chats shows up to this many of today's conversations. Older ones wait behind "
        .. "Show earlier and then show as one line each. Pinned, unread and open conversations always show. "
        .. "0 shows everything.")
    gap(4)

    section("Dungeons and raids")
    index("In dungeons and raids: ask, always follow, never", "Follow Party or Raid chat while you're inside.")
    local inLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    inLabel:SetPoint("TOPLEFT", 18, y - 2)
    inLabel:SetText("Follow Party or Raid chat")
    self.instRadios = {}
    local prevI = inLabel
    for _, opt in ipairs({ { "ask", "Ask" }, { "always", "Always follow" }, { "never", "Never" } }) do
        local r = S.Radio(content, opt[2])
        r:SetPoint("LEFT", prevI, "RIGHT", prevI == inLabel and 14 or 12, prevI == inLabel and 0 or -1)
        r.value = opt[1]
        r:SetScript("OnClick", function()
            TG.db.settings.instanceChat = opt[1]
            O:Refresh()
        end)
        S.Tooltip(r, "Dungeons and raids", "Follow Party chat in a dungeon, or Raid chat in a raid (and Instance "
            .. "chat), until you leave. It's pinned at the top of Chats while you're inside. Ask: a pop-up "
            .. "you click when you enter.")
        prevI = r.label
        self.instRadios[#self.instRadios + 1] = r
    end
    y = y - 28
    check("Pop-up notifications for the dungeon or raid chat", 30,
        function() return s().instancePopups ~= false end, function(v) s().instancePopups = v end,
        "Dungeon and raid chat", "For Party or Raid chat that Telegnome follows just while you're inside. "
        .. "Off: it still counts unread messages. A chat you already follow keeps its own settings.")

    section("Group chats and channels")
    check("Pick up group codes from chat", 0,
        function() return s().detectInvites end, function(v) s().detectInvites = v end,
        "Group codes",
        "When someone sends \"Telegnome code: ...\" in a whisper, party, guild or other chat, "
        .. "a pop-up offers to join, and it's filled in the next time you click + New group.")
    gap(6)
    index("Your chat channels (leave channels)", "Every chat channel your character is in, with a Leave button.")
    local slots = S.Button(content, "Your chat channels...", 160, 22)
    slots:SetPoint("TOPLEFT", 16, y)
    slots:SetScript("OnClick", function() TG.ChannelList:Open() end)
    S.Tooltip(slots, "Your chat channels",
        "Every chat channel your character is in - Blizzard, custom and Telegnome group chats - with a Leave button. "
        .. "The game allows 10.")
    y = y - 30

    ---------------------------------------------------------------- Queue
    page("requests", "Lobby", "The Lobby tab: whispers from people you don't know, for your group (LFM) or your ad (Business).")
    check("Show the Lobby tab", 0,
        function() return s().showRequestsTab ~= false end, function(v) s().showRequestsTab = v; UI:UpdateTabs() end,
        "Lobby tab", "On: the tab is always there, with a grey dot while nothing is collecting. Off: it only shows up "
        .. "while LFM or Business is collecting, and while requests are waiting on it.")
    section("LFM")
    check("Collect strangers' whispers in LFM while I'm listed", 0,
        function() return s().requestsTab end, function(v) s().requestsTab = v end,
        "LFM", "While you or your group are listed in the group finder, whispers from people who aren't "
        .. "friends, guild members or favorites go to Lobby > LFM, as cards with their class and level and an "
        .. "Invite button. In a group, only the leader collects. To collect at other times: Collect now, or /tg lfm")
    gap(8)
    local qrHint = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qrHint:SetPoint("TOPLEFT", 18, y)
    qrHint:SetText("Quick replies (the Reply button on a request):")
    y = y - 16
    local blanks = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    blanks:SetPoint("TOPLEFT", 18, y)
    blanks:SetText("{name}, {class} and {level} are filled in for the person you answer.")
    blanks:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    y = y - 18
    for i = 1, 3 do
        replyBox("Reply " .. i, function() return (s().quickReplies or {})[i] or "" end,
            function(v) s().quickReplies = s().quickReplies or {}; s().quickReplies[i] = v end)
    end
    local dBox = replyBox("Decline", function() return s().declineReply or "" end, function(v) s().declineReply = v end)
    S.Tooltip(dBox, "Decline message", "\"Decline\" in the Reply menu sends this and dismisses the request, "
        .. "and Decline all sends it to everyone still waiting. Leave it empty to dismiss without a message.")

    section("Business", "business")
    local brHint = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    brHint:SetPoint("TOPLEFT", 18, y)
    brHint:SetText("Quick replies for whispers to your ad ({name}, {class}, {level} work here too):")
    y = y - 20
    for i = 1, 3 do
        replyBox("Reply " .. i, function() return (s().bizReplies or {})[i] or "" end,
            function(v) s().bizReplies = s().bizReplies or {}; s().bizReplies[i] = v end)
    end
    replyBox("Decline", function() return s().bizDecline or "" end, function(v) s().bizDecline = v end)
    local bdaBox = replyBox("Decline all", function() return s().bizDeclineAll or "" end,
        function(v) s().bizDeclineAll = v end)
    S.Tooltip(bdaBox, "Decline all message", "The Decline all button in Lobby > Business sends this to everyone "
        .. "still waiting. Leave it empty to clear the list without a message.")
    gap(4)
    local bizNote = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bizNote:SetPoint("TOPLEFT", 18, y)
    bizNote:SetPoint("RIGHT", content, "RIGHT", -12, 0)
    bizNote:SetJustifyH("LEFT")
    bizNote:SetText("Your ad, Start / Stop and how long it stays open are in Lobby > Business. Only one of LFM "
        .. "and Business collects at a time, and the one started last wins: listing in the group finder or Collect "
        .. "now pauses Business, and starting Business pauses Collect now. Also: /tg business [minutes|off]")
    bizNote:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    y = y - 44

    ---------------------------------------------------------------- Your data
    page("data", "Your data", "What is saved, and where.")
    index("Where Telegnome saves your data", "One file on this computer. Nothing is uploaded.")
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
    index("Delete all messages", "Empties every conversation after asking.")
    local wipe = S.Button(content, "Delete all messages...", 170, 22)
    wipe:SetPoint("TOPLEFT", 16, y)
    wipe:SetScript("OnClick", function() TG:ConfirmClearAllHistory() end)
    S.Tooltip(wipe, "Delete all messages", "Empties every conversation after asking. Conversations, groups, "
        .. "contacts and settings stay. To remove one conversation's messages, use Clear history in it.")
    y = y - 30

    ---------------------------------------------------------------- Help
    page("help", "Help", "What each tab is for. The ? next to the cog shows the same for the tab you're on.")
    for _, tab in ipairs({ "all", "queue" }) do
        local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 18, y)
        h:SetText(TG.Help.Title(tab))
        y = y - 18
        local body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        body:SetPoint("TOPLEFT", 18, y)
        body:SetWidth(400)
        body:SetJustifyH("LEFT")
        body:SetSpacing(2)
        body:SetText(TG.Help.Body(tab))
        y = y - S.Num(body:GetStringHeight(), 110) - 16
    end

    content:SetHeight(-y + 8)


    -- Search results: a page of its own, filled by O:Search
    local res = CreateFrame("Frame", nil, clip)
    res:SetSize(440, 400)
    res:Hide()
    self.resultsFrame = res
    local rtitle = res:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rtitle:SetPoint("TOPLEFT", 14, -10)
    self.resultsTitle = rtitle
    local none = res:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    none:SetPoint("TOPLEFT", 14, -40)
    none:SetText("Nothing found. Try another word, like sound, reply or archive.")
    self.resultsNone = none
    self.resultRows = {}

    local done = S.Button(f, "Done", 80, 24)
    done:SetPoint("BOTTOMRIGHT", -30, 10) -- clear of the window's resize corner
    done:SetScript("OnClick", function() O:Close() end)

    -- The category buttons, in their own order (the pages above are built in the order of the code).
    local byId = {}
    for _, pg in ipairs(self.pages) do byId[pg.id] = pg end
    local n = 0
    for _, id in ipairs(CATEGORIES) do
        local pg = byId[id]
        if pg then
            n = n + 1
            local b = CreateFrame("Button", nil, side)
            b:SetHeight(30)
            b:SetPoint("TOPLEFT", 6, -76 - (n - 1) * 32)
            b:SetPoint("RIGHT", -6, 0)
            local sel = S.Rounded(b, 5)
            for _, t in ipairs(sel.parts) do S.Paint(t, "hivertex", 0.13) end
            local bar = b:CreateTexture(nil, "ARTWORK")
            bar:SetPoint("TOPLEFT", 0, -4)
            bar:SetPoint("BOTTOMLEFT", 0, 4)
            bar:SetWidth(3)
            S.Paint(bar, "hi", 0.95)
            local hl = b:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.05)
            local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("LEFT", 14, 0)
            fs:SetText(pg.label)
            b.id, b.fs = id, fs
            function b:SetSelected(v)
                sel:SetShown(v)
                bar:SetShown(v)
                if v then self.fs:SetTextColor(1, 0.82, 0) else self.fs:SetTextColor(0.81, 0.76, 0.66) end
            end
            b:SetScript("OnClick", function() O:ShowPage(id) end)
            self.catButtons[n] = b
        end
    end
    self:ShowPage(self.page or CATEGORIES[1])
end

-- One page at a time on the right.
-- at: a y position on the page (a section or a setting) to scroll to, instead of the top.
function O:ShowPage(id, at)
    local shown
    for _, pg in ipairs(self.pages) do
        if pg.id == id then shown = pg end
    end
    shown = shown or self.pages[1]
    if not shown then return end
    if self.search and self.search:GetText() ~= "" and not self.jumping then
        self.jumping = true
        self.search:SetText("") -- a category click leaves the search
        self.jumping = false
    end
    if self.resultsFrame then self.resultsFrame:Hide() end
    self.page = shown.id
    for _, pg in ipairs(self.pages) do pg.frame:SetShown(pg == shown) end
    self.clip:SetScrollChild(shown.frame)
    shown.frame:SetWidth(S.Num(self.clip:GetWidth(), 440))
    local top = at and math.max(0, -at - 12) or 0
    self.clip:SetVerticalScroll(0)
    if top > 0 then
        C_Timer.After(0, function() -- once the scroll range knows the page's height
            local range = S.Num(self.clip:GetVerticalScrollRange(), 0)
            self.clip:SetVerticalScroll(math.min(top, range))
        end)
    end
    for _, b in ipairs(self.catButtons) do b:SetSelected(b.id == shown.id) end
end

-- A short glow behind the setting you jumped to from the search.
function O:Flash(id, at)
    local pg
    for _, p in ipairs(self.pages) do if p.id == id then pg = p end end
    if not pg then return end
    if not pg.flash then
        local t = pg.frame:CreateTexture(nil, "BACKGROUND")
        t:SetHeight(26)
        S.Paint(t, "hivertex", 0.22)
        pg.flash = t
    end
    pg.flash:ClearAllPoints()
    pg.flash:SetPoint("TOPLEFT", pg.frame, "TOPLEFT", 6, at + 2)
    pg.flash:SetPoint("RIGHT", pg.frame, "RIGHT", -6, 0)
    pg.flash:Show()
    local mark = {}
    self.flashMark = mark
    C_Timer.After(1.8, function() if O.flashMark == mark then pg.flash:Hide() end end)
end

-- The settings whose name, explanation, section or page has every word typed.
function O:Find(text)
    local words = {}
    for w in (text or ""):lower():gmatch("%S+") do words[#words + 1] = w end
    if #words == 0 then return {} end
    local found = {}
    for _, e in ipairs(self.index or {}) do
        local hay = (e.text .. " " .. (e.tip or "") .. " " .. (e.section or "") .. " " .. (e.pageLabel or "")):lower()
        local all = true
        for _, w in ipairs(words) do
            if not hay:find(w, 1, true) then all = false break end
        end
        if all then found[#found + 1] = e end
    end
    return found
end

function O:Search(text)
    if not self.resultsFrame then return end
    if not text or not text:match("%S") then
        self:ShowPage(self.page or CATEGORIES[1])
        return
    end
    local found = self:Find(text)
    for _, pg in ipairs(self.pages) do pg.frame:Hide() end
    for _, b in ipairs(self.catButtons) do b:SetSelected(false) end
    local res = self.resultsFrame
    res:Show()
    self.clip:SetScrollChild(res)
    res:SetWidth(S.Num(self.clip:GetWidth(), 440))
    self.clip:SetVerticalScroll(0)
    self.resultsTitle:SetText(("%d setting%s found"):format(#found, #found == 1 and "" or "s"))
    self.resultsNone:SetShown(#found == 0)
    for i, e in ipairs(found) do
        local row = self.resultRows[i]
        if not row then
            row = CreateFrame("Button", nil, res)
            row:SetHeight(36)
            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetPoint("TOPLEFT", 8, -3)
            row.name:SetPoint("RIGHT", -8, 0)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)
            row.path = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.path:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
            row.path:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
            row:SetScript("OnClick", function(r) O:Jump(r.entry) end)
            self.resultRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", res, "TOPLEFT", 6, -38 - (i - 1) * 38)
        row:SetPoint("RIGHT", res, "RIGHT", -6, 0)
        row.entry = e
        row.name:SetText(e.text)
        row.path:SetText(e.pageLabel .. (e.section and (" > " .. e.section) or ""))
        row:Show()
    end
    for i = #found + 1, #self.resultRows do self.resultRows[i]:Hide() end
    res:SetHeight(48 + #found * 38)
end

-- From a search result to the setting: its page, scrolled to it, with a short glow.
function O:Jump(e)
    if not e then return end
    self.jumping = true
    self.search:SetText("")
    self.search:ClearFocus()
    self.jumping = false
    self:ShowPage(e.page, e.y)
    self:Flash(e.page, e.y)
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
    for _, r in ipairs(self.combatRadios or {}) do r:SetChecked(r.value == (st.combatNotify or "summary")) end

    for _, sw in ipairs(self.swatches) do
        if sw.theme == S.theme then
            sw:SetBackdropBorderColor(1, 1, 1, 1)
        else
            sw:SetBackdropBorderColor(0, 0, 0, 0.8)
        end
    end
    self.themeName:SetText(S.theme.label)
    for _, r in ipairs(self.sizeRadios) do r:SetChecked(r.value == (st.textSize or "normal")) end
    for _, r in ipairs(self.sortRadios) do r:SetChecked(r.value == (st.listSort or "recent")) end
    for _, r in ipairs(self.instRadios) do r:SetChecked(r.value == (st.instanceChat or "ask")) end
    if self.archiveDays then
        if not self.archiveDays:HasFocus() then self.archiveDays:SetText(tostring(st.archiveDays or 7)) end
        self.archiveDays:SetAlpha(st.archiveOn == false and 0.5 or 1)
    end
    for _, box in ipairs(self.replyBoxes) do
        if not box:HasFocus() then box:SetText(box.get()) end
    end
    for _, box in ipairs(self.numBoxes or {}) do
        if not box:HasFocus() then box:SetText(box.get()) end
    end
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

-- page / section: where to open. Without them it opens where the tab you're on is set up (TAB_PAGE).
function O:Open(page, section)
    UI:Show()
    self:Create()
    if not page then
        local t = TAB_PAGE[UI.tab or "all"] or {}
        page, section = t[1], t[2]
        if UI.tab == "queue" and TG.Requests:View() == "business" then section = "business" end
    end
    if TG.Help then TG.Help:Close() end
    -- closing Settings goes back to the Lobby overview if that was open
    if not self:IsShown() then
        self.backTo = TG.Requests:IsPanelShown() and UI.tab or nil
    end
    TG.Picker:Close()
    TG.Groups:ClosePanel()
    TG.Channels:ClosePanel()
    TG.ChannelList:Close()
    TG.Requests:ClosePanel()
    self:Refresh()
    self.frame:Show()
    if self.search and self.search:GetText() ~= "" then
        self.jumping = true
        self.search:SetText("")
        self.jumping = false
    end
    local at = section and self.sections[page or ""] and self.sections[page][section]
    self:ShowPage(page or CATEGORIES[1], at)
end

function O:Close()
    if not self:IsShown() then return end
    self.frame:Hide()
    local back = self.backTo
    self.backTo = nil
    if back and back == UI.tab and UI.frame:IsShown() then
        TG.Requests:OpenPanel(true, back)
        return
    end
    -- Messages that arrived while settings covered the conversation are now seen.
    if UI.frame:IsShown() and UI.selected then UI:Select(UI.selected) end
end

function O:Toggle()
    if self:IsShown() then self:Close() else self:Open() end
end
