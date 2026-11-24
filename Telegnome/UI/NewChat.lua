-- Telegnome: the New chat page (+ New chat on the Chats tab).
--   Three cards - Direct message, Group chat, Channel - so the page never shows everything at once.
--   Direct message shows the player search right here; Group chat opens the create / join panel; Channel
--   has a second step: follow a channel, a filtered channel, or your chat channels. Every page along the
--   way has a Back button, so you can look around without starting over.

local _, ns = ...
local TG = ns.TG
local UI = TG.UI
local S = TG.Style
local N = {}
TG.NewChat = N

local CARDS = {
    { id = "dm", title = "Direct message", text = "Whisper a player or a Battle.net friend." },
    { id = "group", title = "Group chat", text = "A private room for friends: create or join." },
    { id = "channel", title = "Channel", text = "Follow channels, or only messages with your words." },
}

local CHANNEL_STEPS = {
    { id = "follow", title = "Follow a channel", text = "Guild, Party, Trade or any channel you're in." },
    { id = "filter", title = "Filtered channel", text = "Only messages with your words, like \"enchant\"." },
    { id = "mine", title = "Your chat channels", text = "Every channel you're in." },
}

-- Where Back goes from each page.
N.BACK_TO = { dm = "start", channel = "start", group = "start", follow = "channel", filter = "channel", mine = "channel" }

-- What each choice opens.
function N.Go(id)
    if id == "dm" or id == "channel" or id == "start" then
        N:Open(id)
        return
    end
    N:Close(true)
    if id == "group" then
        TG.Groups:OpenPanel()
    elseif id == "follow" or id == "filter" then
        TG.Channels:OpenPanel(id)
    elseif id == "mine" then
        TG.ChannelList:Open()
    end
end

-- A "< Back" button in the top left corner of a panel; from: the page it sits on (see BACK_TO).
function N.BackButton(parent, from)
    local b = S.Button(parent, "< Back", 76, 24)
    b:SetPoint("TOPLEFT", 10, -6)
    b:SetScript("OnClick", function() N:Open(N.BACK_TO[from] or "start") end)
    S.Tooltip(b, "Back", "Back to New chat.")
    return b
end

-- A card: an icon, a title and one line, the whole card clickable.
local function card(parent, def)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(62)
    S.Flat(b)
    S.Paint(b, "button")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    S.Paint(hl, "hi", 0.12)
    if def.id == "dm" or def.id == "group" then
        local t = S.Icon(b, def.id == "dm" and S.BUBBLE or S.GROUP, 20)
        t:SetPoint("LEFT", 20, 0)
        t:SetVertexColor(0.85, 0.71, 0.42)
    else
        local ico = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        ico:SetPoint("LEFT", 22, 0)
        ico:SetText("#")
    end
    local title = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 56, -13)
    title:SetText(def.title)
    local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    text:SetPoint("RIGHT", -30, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(def.text)
    local chev = S.Icon(b, S.CHEV_RIGHT, 12)
    chev:SetPoint("RIGHT", -12, 0)
    chev:SetVertexColor(S.DIM[1], S.DIM[2], S.DIM[3])
    b:SetScript("OnClick", function() N.Go(def.id) end)
    return b
end

function N:Create()
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

    local back = S.Button(f, "< Back", 76, 24)
    back:SetPoint("TOPLEFT", 10, -6)
    back:SetScript("OnClick", function() N:Open(N.BACK_TO[N.page] or "start") end)
    self.back = back

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title = title
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 8, -36)
    line:SetPoint("TOPRIGHT", -8, -36)
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 14, -46)
    sub:SetPoint("RIGHT", -14, 0)
    sub:SetJustifyH("LEFT")
    self.sub = sub

    self.pages = {}
    for _, step in ipairs({ { "start", CARDS }, { "channel", CHANNEL_STEPS } }) do
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", 14, -70)
        page:SetPoint("RIGHT", -14, 0)
        page:SetHeight(#step[2] * 72)
        local prev
        for _, def in ipairs(step[2]) do
            local c = card(page, def)
            if prev then c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10) else c:SetPoint("TOPLEFT") end
            c:SetPoint("RIGHT")
            prev = c
        end
        page:Hide()
        self.pages[step[1]] = page
    end
    -- Direct message: the player search fills this space
    local dm = CreateFrame("Frame", nil, f)
    dm:SetPoint("TOPLEFT", 10, -68)
    dm:SetPoint("BOTTOMRIGHT", -10, 42)
    dm:Hide()
    self.pages.dm = dm

    local tip = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip:SetPoint("BOTTOMLEFT", 14, 12)
    tip:SetPoint("RIGHT", -100, 0)
    tip:SetJustifyH("LEFT")
    tip:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    tip:SetText("Tip: hover a section in the list for its + shortcut. Recruiting or selling? That's the Lobby tab.")
    self.tip = tip

    local close = S.Button(f, "Close", 80, 24)
    close:SetPoint("BOTTOMRIGHT", -10, 10)
    close:SetScript("OnClick", function() N:Close() end)
end

function N:IsShown()
    return self.panel and self.panel:IsShown() or false
end

local TITLES = {
    start = { "New chat", "What would you like to start?" },
    channel = { "Channel", "Follow a channel, or keep only the messages you care about." },
    dm = { "Direct message", "Search for a friend, someone you've talked to, or type any character name and press Enter." },
}

-- page: "start" (the three cards), "channel" (the channel step) or "dm" (the player search).
function N:Open(page)
    page = page or "start"
    UI:Show()
    if UI.tab ~= "all" then UI:SetTab("all") end
    self:Create()
    TG.Settings:Close()
    TG.Picker:Close()
    TG.Groups:ClosePanel(true)
    TG.Channels:ClosePanel(true)
    TG.ChannelList:Close()
    TG.Requests:ClosePanel()
    TG.Search:Close()
    self.page = page
    for id, p in pairs(self.pages) do p:SetShown(id == page) end
    self.back:SetShown(page ~= "start")
    self.title:ClearAllPoints()
    if page == "start" then
        self.title:SetPoint("TOPLEFT", 14, -12)
    else
        self.title:SetPoint("LEFT", self.back, "RIGHT", 12, 0)
    end
    self.title:SetText(TITLES[page][1])
    self.sub:SetText(TITLES[page][2])
    self.tip:SetShown(page == "start")
    self.panel:Show()
    UI.newBtn:SetText("Cancel")
    if page == "dm" then TG.Picker:ShowIn(self.pages.dm) end
end

-- quiet: another panel is about to open, so don't jump back to a conversation first.
function N:Close(quiet)
    if not self:IsShown() then return end
    TG.Picker:Close()
    self.panel:Hide()
    UI:UpdateNewButton()
    if not quiet and UI.frame and UI.frame:IsShown() then
        local key = UI.selected or UI:FirstKey()
        if key then UI:Select(key) else UI:ShowEmpty() end
    end
end

function N:Toggle()
    if self:IsShown() then self:Close() else self:Open("start") end
end
