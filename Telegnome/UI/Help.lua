-- Telegnome: help for each tab.
--   The ? button next to Settings opens a card for the tab you're on, and a tab with nothing in it
--   shows the same text, so it explains itself the moment you wonder what it's for.

local _, ns = ...
local TG = ns.TG
local UI = TG.UI
local S = TG.Style
local H = {}
TG.Help = H

H.TEXT = {
    all = { "Chats", "Every conversation in one list: Pinned, Friends, Group chats, Channels and Others (people "
        .. "you don't know). Quiet direct messages move to Archive at the bottom.\n\n"
        .. "- + New chat starts a direct message, a group chat or a channel. Hover a section for its + shortcut.\n"
        .. "- Each section shows today's chats (up to 5); older ones wait behind Show earlier, one line each. Unread chats always show.\n"
        .. "- Click the star or drag a conversation onto Pinned to pin it; drag pinned ones to reorder them.\n"
        .. "- Drag a section header (or right-click > Move section up) to put the sections in your order.\n"
        .. "- Right-click a section for Show only this section, sorting and Mark all as read.\n"
        .. "- Right-click a conversation for a note, notifications, archive and more." },
    dm = { "Direct messages", "Whispers and Battle.net messages, one conversation per person. Friends, guild "
        .. "members and people you grouped with this week are under Friends, everyone else under Others.\n\n"
        .. "- + New message starts a conversation with anyone.\n"
        .. "- Right-click a person for a note, notifications, invite and archive.\n"
        .. "- Conversations with nothing new for a week move to Archive. Change the number of days in "
        .. "Settings > Chats." },
    channels = { "Channels", "Guild, Party, Trade or any other chat channel, followed into Telegnome so it "
        .. "doesn't flood the main chat.\n\n"
        .. "- + Follow channel picks which ones. Add a filtered copy to see only messages with certain words, "
        .. "like Trade with \"LFW\".\n"
        .. "- Right-click a channel for pop-ups, the unread count, alert words and renaming.\n"
        .. "- Alert words pop up even when the channel's pop-ups are off, and are picked out in gold." },
    groups = { "Group chats", "Private chat rooms for you and your friends. Everyone in the group needs "
        .. "Telegnome.\n\n"
        .. "- + New group creates one and gives you an invite code like sprocket-whistle-gizmo-427.\n"
        .. "- Share the code in any chat, or right-click the group > Invite. Friends with Telegnome get a "
        .. "pop-up and join with one click.\n"
        .. "- Right-click a group for Who's online, renaming, notifications and leaving." },
    requests = { "LFM", "Whispers from people you don't know, collected as cards while you're listed in "
        .. "the group finder, so they don't get lost among your friends' messages.\n\n"
        .. "- It starts by itself when you list a group (as its leader). Collect now collects at any time "
        .. "(also /tg lfm).\n"
        .. "- Each card shows the class and level. Invite, Reply with a quick reply, or Decline.\n"
        .. "- Filter by class with the icons at the top. Decline all answers everyone still waiting.\n"
        .. "- Quick replies and decline messages are in Settings > Lobby." },
    business = { "Business", "For crafters, sellers and guild ads: post an ad and collect the whispers you "
        .. "get back.\n\n"
        .. "- Write your ad (shift-click a profession or an item to add its link), choose where it goes and for "
        .. "how long, then press Start and Post.\n"
        .. "- The game needs a click for every post, so Post never repeats on its own.\n"
        .. "- Whispers from people you don't know land here as cards, with their own quick replies "
        .. "(Settings > Lobby).\n"
        .. "- Saved ads keeps ads you use again. Listing in the group finder pauses it." },
}

-- The Queue tab: both sides in one card.
H.TEXT.queue = { "Lobby", "Whispers from people you don't know, collected as cards so they don't get lost "
    .. "among your friends' messages. Switch side at the top - only one collects at a time, the one started last.\n\n"
    .. "LFM: while you're listed in the group finder (as the leader), or with Collect now. Each card shows the class "
    .. "and level; Invite, Reply or Decline. Filter by class with the icons. Auto-invite invites anyone who "
    .. "whispers your keyword, for a few minutes.\n\n"
    .. "Business: write an ad (shift-click a profession or item to link it), choose where and how long, press Start "
    .. "and Post. Saved ads keeps ads you use again.\n\n"
    .. "Quick replies and decline messages for both are in Settings > Lobby." }

-- Shown once, the first time the window opens after updating from an earlier version.
H.WHATS_NEW = { "Welcome to Telegnome 1.0", "Two tabs now instead of five.\n\n"
    .. "- Chats has every conversation in one list: Pinned, Friends, Group chats, Channels and Others. "
    .. "Nothing is gone - your direct messages, channels and groups are all in there.\n"
    .. "- Lobby is the old Queue tab: LFM and Business. The dot on it is green while one of them collects.\n"
    .. "- + New chat starts a direct message, a group chat or a channel. Hover a section header for its "
    .. "own + shortcut.\n"
    .. "- Drag a chat onto Pinned to pin it, and drag section headers to put them in your order.\n"
    .. "- Each section shows today's chats; older ones wait behind Show earlier. Right-click the Chats tab to mark everything as read." }

function H:ShowWhatsNew()
    UI:Show()
    self:Create()
    self.tab = "whatsnew"
    self.title:SetText(H.WHATS_NEW[1])
    self.body:SetText(H.WHATS_NEW[2])
    self.card:Show()
end

function H.Title(tab)
    local t = H.TEXT[tab]
    return t and t[1] or "Telegnome"
end

function H.Body(tab)
    local t = H.TEXT[tab]
    return t and t[2] or ""
end

---------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------

function H:Create()
    if self.card then return end
    UI:Create()
    local f = CreateFrame("Frame", nil, UI.frame, "BackdropTemplate")
    f:SetAllPoints(UI.body)
    f:SetFrameLevel(UI.body:GetFrameLevel() + 80)
    S.Flat(f)
    S.Paint(f, "cover")
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function() end)
    f:Hide()
    self.card = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -14)
    self.title = title
    local line = S.Line(f)
    line:SetPoint("TOPLEFT", 12, -40)
    line:SetPoint("TOPRIGHT", -12, -40)

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 18, -52)
    body:SetPoint("RIGHT", f, "RIGHT", -24, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    self.body = body

    local ok = S.Button(f, "Got it", 90, 24, true)
    ok:SetPoint("BOTTOMRIGHT", -30, 10) -- clear of the window's resize corner
    ok:SetScript("OnClick", function() H:Close() end)

    local more = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    more:SetPoint("BOTTOMLEFT", 18, 16)
    more:SetPoint("RIGHT", ok, "LEFT", -12, 0)
    more:SetJustifyH("LEFT")
    more:SetText("Every tab's help is in Settings > Help. Hover buttons and ticks for more.")
    more:SetTextColor(S.DIM[1], S.DIM[2], S.DIM[3])
end

function H:IsShown()
    return self.card and self.card:IsShown() or false
end

function H:Show(tab)
    tab = tab or UI.tab or "all"
    UI:Show()
    self:Create()
    self.tab = tab
    self.title:SetText(H.Title(tab))
    self.body:SetText(H.Body(tab))
    self.card:Show()
    if UI.helpBtn and UI.helpBtn.SetLit then UI.helpBtn:SetLit(true) end
end

function H:Close()
    if not self:IsShown() then return end
    self.card:Hide()
    if UI.helpBtn and UI.helpBtn.SetLit then UI.helpBtn:SetLit(false) end
end

function H:Toggle()
    if self:IsShown() and self.tab == UI.tab then self:Close() else self:Show(UI.tab) end
end
