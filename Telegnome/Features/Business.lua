-- Telegnome: Open for business, in its own Business tab. For crafters, sellers and recruiters: write
-- an ad (with links) and post it, and while it's open, whispers from people you don't know are
-- collected in the tab with their own quick replies. It stops after the time you chose, or when you stop it.
--   Listing in the group finder pauses it (Requests collects group whispers then); it comes back by
--   itself when you stop listing.

local _, ns = ...
local TG = ns.TG
local B = {}
TG.Business = B

local function S() return TG.db.settings end

function B:IsOn()
    return S().business and not S().businessPaused and true or false
end

-- Minutes left, or nil when it runs until you stop it.
function B:MinutesLeft()
    local u = S().businessUntil
    if not (S().business and u) then return nil end
    return math.max(0, math.ceil((u - time()) / 60))
end

local function changed()
    TG:RefreshUnread()
    if TG.Toast and TG.Toast.Update then TG.Toast:Update() end
    TG.Requests:Refresh()
    if TG.UI.frame then TG.UI:UpdateTabs() end
    if TG.Settings and TG.Settings.Refresh then pcall(TG.Settings.Refresh, TG.Settings) end
end

-- "30 minutes" or "Until I stop it"
function B.DurationLabel()
    local s = S()
    if s.businessForever then return "Until I stop it" end
    return (tonumber(s.businessMinutes) or 30) .. " minutes"
end

-- minutes: from /tg business 45; otherwise the choice in the tab.
function B:Start(minutes)
    local s = S()
    local forever = minutes == nil and s.businessForever
    minutes = tonumber(minutes) or tonumber(s.businessMinutes) or 30
    s.business = true
    s.businessUntil = (not forever and minutes > 0) and (time() + minutes * 60) or nil
    s.businessPaused = TG.Requests:IsHosting() or nil
    if s.businessPaused then
        TG:Print("Open for business is on, but paused while you're listed in the group finder.")
    else
        TG:Print(("Open for business%s. Whispers from people you don't know go to the Business tab.")
            :format(s.businessUntil and (" for " .. minutes .. " minutes") or ""))
    end
    changed()
    TG.Requests:OpenPanel(nil, "business")
end

-- reason "time": it ran out.
function B:Stop(reason)
    local s = S()
    if not s.business then return end
    s.business, s.businessUntil, s.businessPaused = false, nil, nil
    changed()
    local waiting = #TG.Requests:OpenKeys("business")
    local body = waiting > 0 and (("%d whisper%s waiting in the Business tab."):format(waiting, waiting == 1 and "" or "s"))
        or "No whispers waiting."
    if reason == "time" then
        if TG.Toast then
            TG.Toast:Notice("|cffffd100Open for business has ended|r", body, function() TG.Requests:OpenPanel(nil, "business") end)
        end
    end
    TG:Print("Open for business is off. " .. body)
end

function B:Toggle(minutes)
    if S().business then self:Stop() else self:Start(minutes) end
end

-- Called when your group finder listing starts or stops. True when it showed its own pop-up.
function B:OnHostingChanged(hosting)
    local s = S()
    if not s.business then return false end
    if hosting and not s.businessPaused then
        s.businessPaused = true
        changed()
        if TG.Toast then
            TG.Toast:Notice("|cffffd100Open for business paused|r", "You're listed in the group finder, so Requests "
                .. "collects group whispers now. It comes back when you stop listing.",
                function() TG.Requests:OpenPanel(nil, "requests") end)
        end
        TG:Print("Open for business is paused while you're listed in the group finder.")
        return true
    elseif not hosting and s.businessPaused then
        s.businessPaused = nil
        if s.businessUntil and time() >= s.businessUntil then
            self:Stop("time")
        else
            changed()
            if TG.Toast then
                TG.Toast:Notice("|cffffd100Open for business is back on|r",
                    "Whispers from people you don't know go to the Business tab again.",
                    function() TG.Requests:OpenPanel(nil, "business") end)
            end
            TG:Print("Open for business is back on.")
        end
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Ads
---------------------------------------------------------------------------

local BUILTIN = { GUILD = "Guild", OFFICER = "Officer", SAY = "Say", YELL = "Yell", PARTY = "Party", RAID = "Raid" }

-- Where ads go: a chat type ("SAY") or a channel's name ("Trade").
function B.ChannelLabel()
    local c = S().adChannel or "Trade"
    return BUILTIN[c] or c
end

-- The ads you've written (numbered as in Settings).
function B:Ads()
    local out = {}
    for i, text in ipairs(S().ads or {}) do
        if type(text) == "string" and text:match("%S") then out[#out + 1] = { i = i, text = text } end
    end
    return out
end

-- Posts an ad. Must come from a click: the game doesn't let addons post in channels on their own.
function B:Post(i)
    local text = (S().ads or {})[i]
    if type(text) ~= "string" or not text:match("%S") then
        TG:Print("Your ad is empty. Write it in the Business tab first.")
        return
    end
    local now = GetTime()
    if self.lastPost and now - self.lastPost < 15 then
        TG:Print("You just posted. Wait a few seconds before posting again.")
        return
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local c = S().adChannel or "Trade"
    if BUILTIN[c] then
        send(text, c)
    else
        local id = tonumber((GetChannelName(c))) or 0
        if id == 0 then
            TG:Print("You're not in the channel " .. c .. " right now. Choose another one next to the ad.")
            return
        end
        send(text, "CHANNEL", nil, id)
    end
    self.lastPost = now
end

---------------------------------------------------------------------------
-- Saved ads
---------------------------------------------------------------------------

B.MAX_SAVED = 15

-- An ad as plain text, for menus: links become their names.
function B.PlainAd(text, max)
    local t = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    max = max or 60
    if #t > max then t = TG.Utf8Left(t, max - 3) .. "..." end
    return t
end

function B:SaveAd(text)
    text = strtrim(text or "")
    if text == "" then
        TG:Print("Write the ad first, then save it.")
        return
    end
    local list = S().savedAds or {}
    S().savedAds = list
    for i, a in ipairs(list) do
        if a == text then table.remove(list, i) break end -- saved again: moves to the top
    end
    table.insert(list, 1, text)
    while #list > B.MAX_SAVED do table.remove(list) end
    TG:Print("Ad saved.")
end

function B:DeleteSaved(i)
    local list = S().savedAds or {}
    if list[i] then table.remove(list, i) end
end

-- Saved: use one of them, save the current ad, or delete one.
function B:OpenSavedMenu(anchor, current, use)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local list = S().savedAds or {}
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateButton("Save this ad", function() B:SaveAd(current()) end)
        root:CreateDivider()
        if #list == 0 then
            root:CreateTitle("|cff888888No saved ads yet|r")
            return
        end
        root:CreateTitle("Use a saved ad")
        for _, a in ipairs(list) do
            root:CreateButton(B.PlainAd(a), function() use(a) end)
        end
        root:CreateDivider()
        local del = root:CreateButton("Delete a saved ad")
        for i, a in ipairs(list) do
            del:CreateButton(B.PlainAd(a), function() B:DeleteSaved(i) end)
        end
    end)
end

-- How long it stays open. Changing it while open starts the clock again.
function B:OpenDurationMenu(anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local function set(minutes)
        local s = S()
        s.businessForever = minutes == nil
        if minutes then s.businessMinutes = minutes end
        if s.business then s.businessUntil = minutes and (time() + minutes * 60) or nil end
        changed()
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle("Stay open for")
        for _, m in ipairs({ 15, 30, 60, 120 }) do
            root:CreateRadio(m .. " minutes",
                function() return not S().businessForever and tonumber(S().businessMinutes) == m end,
                function() set(m) end)
        end
        root:CreateRadio("Until I stop it", function() return S().businessForever and true or false end,
            function() set(nil) end)
    end)
end

-- The Business tab: shown unless you've hidden it (Settings > Open for business), and while it's in use.
function B:TabVisible()
    if not TG.db then return false end
    local s = S()
    if s.businessTab ~= false or s.business then return true end
    for _, th in pairs(TG.db.threads) do
        if th.req and th.biz then return true end
    end
    return false
end

-- The channels an ad can go to: Say, Yell, Guild, then the channels you're in.
function B:ChannelOptions()
    local out = { { id = "SAY", label = "Say" }, { id = "YELL", label = "Yell" }, { id = "GUILD", label = "Guild" } }
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local name = list[i + 1]
        if type(name) == "string" and not TG.Groups.IsTelegnomeChannel(name) then
            local n = name:match("^(.-) %- ") or name
            out[#out + 1] = { id = n, label = n }
        end
    end
    return out
end

function B:OpenChannelMenu(anchor, after)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        for _, o in ipairs(B:ChannelOptions()) do
            root:CreateRadio(o.label, function() return (S().adChannel or "Trade") == o.id end,
                function() S().adChannel = o.id; if after then after() end end)
        end
    end)
end

---------------------------------------------------------------------------
-- Shift-clicked links go into the ad boxes in Settings
---------------------------------------------------------------------------

B.linkBoxes = {}
local function insertLink(link)
    if type(link) ~= "string" then return end
    for _, box in ipairs(B.linkBoxes) do
        if box:IsVisible() and box:HasFocus() then
            box:Insert(link)
            return
        end
    end
end
if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", insertLink)
elseif ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", insertLink)
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------

local function tick()
    if not TG.db then return end
    local s = S()
    if s.business and s.businessUntil and time() >= s.businessUntil and not s.businessPaused then
        B:Stop("time")
    elseif s.business then
        if TG.Requests:IsPanelShown() then TG.Requests:UpdateStatus() end -- the minutes left
        if TG.Toast and TG.Toast.Update then TG.Toast:Update() end
    end
end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(20, tick) end
