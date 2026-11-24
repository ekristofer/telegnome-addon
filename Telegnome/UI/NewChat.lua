-- Telegnome: the New chat page (+ New chat on the Chats tab).
--   Three cards - Direct message, Group chat, Channel - so the page never shows everything at once.
--   Direct message opens the player search, Group chat the create / join panel, and Channel a short
--   second step: follow a channel, a filtered channel, or your chat channels.

local _, ns = ...
local TG = ns.TG
local UI = TG.UI
local S = TG.Style
local N = {}
TG.NewChat = N

local CARDS = {
    { id = "dm", title = "Direct message", text = "Whisper a player or a Battle.net friend." },
    { id = "group", title = "Group chat", text = "A private room for your friends. Create one, or join with a code." },
    { id = "channel", title = "Channel", text = "Follow Guild, Party, Trade... or keep only the messages with your words." },
}

local CHANNEL_STEPS = {
    { id = "follow", title = "Follow a channel", text = "Bring Guild, Party, Trade or any channel you're in into Telegnome." },
    { id = "filter", title = "Filtered channel", text = "Only the messages with your words, e.g. Trade with \"enchant\"." },
    { id = "mine", title = "Your chat channels", text = "Every channel your character is in, with a Leave button." },
}

-- What each choice opens.
function N.Go(id)
    N:Close()
    if id == "dm" then
        TG.Picker:Open()
    elseif id == "group" then
        TG.Groups:OpenPanel()
    elseif id == "channel" then
        N:Open("channel")
    elseif id == "follow" or id == "filter" then
        TG.Channels:OpenPanel(id)
    elseif id == "mine" then
        TG.ChannelList:Open()
    end
end

-- A card: a round icon, a title and one line, the whole card clickable.
local function card(parent, def, icon)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetHeight(62)
    S.Flat(b)
    S.Paint(b, "button")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    S.Paint(hl, "hi", 0.12)
    local ico = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ico:SetPoint("LEFT", 16, 0)
    ico:SetWidth(28)
    ico:SetText(icon or "")
    if def.id == "dm" then
        ico:SetText("")
        local t = S.Icon(b, S.BUBBLE, 20)
        t:SetPoint("CENTER", ico, "CENTER")
        t:SetVertexColor(0.85, 0.71, 0.42)
    elseif def.id == "group" then
        ico:SetText("")
        local t = S.Icon(b, S.GROUP, 20)
        t:SetPoint("CENTER", ico, "CENTER")
        t:SetVertexColor(0.85, 0.71, 0.42)
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

    local back = S.Link(f, "< New chat")
    back:SetPoint("TOPLEFT", 14, -8)
    back:SetScript("OnClick", function() N:Open("start") end)
    self.back = back

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -26)
    self.title = title
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    self.sub = sub

    self.pages = {}
    for _, step in ipairs({ { "start", CARDS }, { "channel", CHANNEL_STEPS } }) do
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", 14, -72)
        page:SetPoint("RIGHT", -14, 0)
        page:SetHeight(#step[2] * 72)
        local prev
        for _, def in ipairs(step[2]) do
            local c = card(page, def, def.id == "channel" and "#" or def.id == "follow" and "#"
                or def.id == "filter" and "#" or def.id == "mine" and "#" or nil)
            if prev then c:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10) else c:SetPoint("TOPLEFT") end
            c:SetPoint("RIGHT")
            prev = c
        end
        page:Hide()
        self.pages[step[1]] = page
    end

    local tip = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip:SetPoint("BOTTOMLEFT", 14, 12)
    tip:SetPoint("RIGHT", -30, 0)
    tip:SetJustifyH("LEFT")
    tip:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
    tip:SetText("Tip: hover a section in the list for its + shortcut. Recruiting or selling? That's the Lobby tab.")
end

function N:IsShown()
    return self.panel and self.panel:IsShown() or false
end

-- page: "start" (the three cards) or "channel" (the channel step).
function N:Open(page)
    page = page or "start"
    UI:Show()
    if UI.tab ~= "all" then UI:SetTab("all") end
    self:Create()
    TG.Settings:Close()
    TG.Picker:Close()
    TG.Groups:ClosePanel()
    TG.Channels:ClosePanel()
    TG.ChannelList:Close()
    TG.Requests:ClosePanel()
    TG.Search:Close()
    for id, p in pairs(self.pages) do p:SetShown(id == page) end
    self.back:SetShown(page ~= "start")
    if page == "channel" then
        self.title:SetText("Channel")
        self.sub:SetText("Follow a channel, or keep only the messages you care about.")
    else
        self.title:SetText("New chat")
        self.sub:SetText("What would you like to start?")
    end
    self.panel:Show()
    UI.newBtn:SetText("Cancel")
end

function N:Close()
    if not self:IsShown() then return end
    self.panel:Hide()
    UI:UpdateNewButton()
    if UI.frame and UI.frame:IsShown() then
        local key = UI.selected or UI:FirstKey()
        if key then UI:Select(key) else UI:ShowEmpty() end
    end
end

function N:Toggle()
    if self:IsShown() then self:Close() else self:Open("start") end
end
