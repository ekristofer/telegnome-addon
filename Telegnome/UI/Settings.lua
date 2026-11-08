-- Telegnome: settings panel (opens over the conversation pane).

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

local function applyAll()
    TG.Toast:Update()
    TG.Minimap:Update()
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
    local cog = S.Cog(f, 18)
    cog:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -34)
    line:SetPoint("TOPRIGHT", -8, -34)

    local y = -44
    local function section(text)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 14, y)
        fs:SetText(text)
        y = y - 22
    end
    local function check(label, indent, get, set, tipTitle, tip)
        local c = S.Check(f, label)
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

    section("Notifications")
    self.notify = check("Show a pop-up for new messages", 0,
        function() return s().notify end, function(v) s().notify = v end,
        "Pop-up", "The notifier grows to show who wrote and the start of the message, then shrinks back.")

    local from = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    from:SetPoint("TOPLEFT", 44, y - 3)
    from:SetText("From:")
    self.fromLabel = from
    local prev = from
    for _, opt in ipairs(NOTIFY_FROM) do
        local r = S.Radio(f, opt[2])
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
        function() return s().notifyGroups end, function(v) s().notifyGroups = v end)

    self.counter = check("Show the missed-messages counter on screen", 0,
        function() return s().counter end, function(v) s().counter = v end,
        "Counter", "A small cog with the number of unread messages. Click it to open Telegnome.")
    self.hideEmpty = check("Only when there are unread messages", 30,
        function() return s().counterHideEmpty end, function(v) s().counterHideEmpty = v end)

    local grow = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    grow:SetPoint("TOPLEFT", 44, y - 3)
    grow:SetText("Grows to the:")
    local prevG = grow
    self.growRadios = {}
    for _, opt in ipairs({ { "right", "Right" }, { "left", "Left" } }) do
        local r = S.Radio(f, opt[2])
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
    check("Play a sound for new whispers", 0,
        function() return s().sound end, function(v) s().sound = v end,
        "Sound", "The normal chat already plays a sound, so this only applies when whispers are hidden from the main chat.")

    local preview = S.Button(f, "Preview", 90, 22)
    preview:SetPoint("TOPLEFT", 44, y - 2)
    preview:SetScript("OnClick", function() TG.Toast:Preview() end)
    self.preview = preview
    local reset = S.Button(f, "Reset position", 120, 22)
    reset:SetPoint("LEFT", preview, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function() TG.Toast:ResetPosition() end)
    S.Tooltip(reset, "Reset position", "Moves the notifier back to the top of the screen. Shift-drag it to move it yourself.")
    y = y - 34

    section("Chat")
    check("Hide whispers from the main chat", 0,
        function() return s().hideFromChat end, function(v) s().hideFromChat = v end,
        "Hide from main chat", "Whispers and Battle.net whispers only show up in Telegnome. R (reply) still works.")
    check("Show minimap button", 0,
        function() return not TG.db.minimap.hide end, function(v) TG.db.minimap.hide = not v end)

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
    self.fromLabel:SetTextColor(notifyOn and 1 or 0.5, notifyOn and 1 or 0.5, notifyOn and 1 or 0.5)
    self.preview:SetEnabled(notifyOn)
    S.SetWidgetEnabled(self.notifyGroups, notifyOn)
    S.SetWidgetEnabled(self.hideEmpty, st.counter)
    for _, r in ipairs(self.growRadios) do r:SetChecked(r.value == (st.toastGrow or "right")) end
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
    self:Refresh()
    self.frame:Show()
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
