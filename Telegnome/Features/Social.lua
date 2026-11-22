-- Telegnome: people around you.
--   Recently grouped with: players you were in a group with in the last week count as friends, so their
--   whispers sort under Friends (and don't land in Requests).
--   Notes: a short line per contact, shown under their name and on their request.
--   Reply blanks: {name}, {class} and {level} in quick replies are filled in for the person you answer.
--   Login summary: a line in chat on login when unread messages are waiting.

local _, ns = ...
local TG = ns.TG
local X = {}
TG.Social = X

local WEEK = 7 * 86400

local function clean(v)
    if type(v) ~= "string" or v == "" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function myRealm()
    local r = GetNormalizedRealmName and GetNormalizedRealmName()
    return clean(r)
end

---------------------------------------------------------------------------
-- Recently grouped with
---------------------------------------------------------------------------

-- Remembers everyone in your group right now (party or raid), with today's date.
function X:NoteGroup()
    if not (TG.db and IsInGroup and IsInGroup()) then return end
    local db = TG.db
    db.grouped = db.grouped or {}
    local raid = IsInRaid and IsInRaid()
    local n = raid and (GetNumGroupMembers and GetNumGroupMembers() or 0)
        or (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0)
    local now, added = time(), false
    for i = 1, n do
        local unit = (raid and "raid" or "party") .. i
        local isMe = UnitIsUnit and UnitIsUnit(unit, "player")
        if not isMe then
            local ok, name, realm = pcall(UnitName, unit)
            name, realm = ok and clean(name), ok and clean(realm)
            if name and name ~= UNKNOWNOBJECT then
                -- whisper names use the realm without spaces or dashes ("Azjol-Nerub" -> "AzjolNerub")
                realm = realm and realm:gsub("[%s%-]", "") or myRealm()
                if realm and realm ~= "" then
                    local key = TG.WhisperKey(name .. "-" .. realm)
                    if not db.grouped[key] then added = true end
                    db.grouped[key] = now
                end
            end
        end
    end
    if added then TG:QueueRefresh() end
end

function X:Prune()
    local g = TG.db and TG.db.grouped
    if not g then return end
    local now = time()
    for key, t in pairs(g) do
        if type(t) ~= "number" or now - t > WEEK then g[key] = nil end
    end
end

-- When you last grouped with this person (within the last week), or nil.
function X:GroupedAt(th)
    if not (TG.db and th and th.kind == "WHISPER" and type(th.name) == "string") then return nil end
    if TG.db.settings.groupedFriends == false then return nil end
    local g = TG.db.grouped
    if not g then return nil end
    local name = th.name
    if not name:find("-", 1, true) then
        local realm = myRealm()
        if not realm then return nil end
        name = name .. "-" .. realm
    end
    local t = g[TG.WhisperKey(name)]
    if type(t) == "number" and time() - t < WEEK then return t end
    return nil
end

---------------------------------------------------------------------------
-- Notes
---------------------------------------------------------------------------

function X:GetNote(key)
    local c = key and TG.db.contacts[key]
    local note = c and c.note
    if type(note) == "string" and note:match("%S") then return note end
    return nil
end

function X:SetNote(key, text)
    local db = TG.db
    local c = db.contacts[key]
    if not c then
        local th = db.threads[key]
        if not th then return end
        c = { kind = th.kind, name = th.name, battleTag = th.battleTag, class = th.class, last = time() }
        db.contacts[key] = c
    end
    text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    c.note = text ~= "" and text or nil
    local UI = TG.UI
    if UI.frame and UI.frame:IsShown() and UI.selected == key then UI:Select(key) end
    if TG.Requests:IsPanelShown() then TG.Requests:Refresh() end
end

function X:EditNote(key)
    if not (TG.db.threads[key] or TG.db.contacts[key]) then return end
    if not StaticPopupDialogs.TELEGNOME_NOTE then
        StaticPopupDialogs.TELEGNOME_NOTE = {
            text = "Note for %s\n|cff999999Only you see it. Leave it empty to remove it.|r",
            button1 = SAVE or "Save",
            button2 = CANCEL or "Cancel",
            hasEditBox = true,
            maxLetters = 80,
            OnShow = function(self, data)
                local box = self.editBox or self.EditBox
                if box then
                    box:SetText(X:GetNote(data or self.data) or "")
                    box:HighlightText()
                end
            end,
            OnAccept = function(self, data)
                local box = self.editBox or self.EditBox
                if box then X:SetNote(data or self.data, box:GetText()) end
            end,
            EditBoxOnEnterPressed = function(box)
                local p = box:GetParent()
                X:SetNote(p.data, box:GetText())
                p:Hide()
            end,
            EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
    StaticPopup_Show("TELEGNOME_NOTE", (TG:ThreadDisplay(key)), nil, key)
end

---------------------------------------------------------------------------
-- Reply blanks
---------------------------------------------------------------------------

-- "Hi {name}, we need a {class}!" -> "Hi Brakk, we need a Warrior!"
function X.Expand(text, key)
    if type(text) ~= "string" or not text:find("{", 1, true) then return text end
    local th = key and (TG.db.threads[key] or TG.db.contacts[key])
    local values = {}
    if th then
        local name = th.name
        if type(name) == "string" then
            values.name = Ambiguate and Ambiguate(name, "short") or name:gsub("%-.*$", "")
        else
            values.name = (TG:ThreadDisplay(key))
        end
        if th.class then
            values.class = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[th.class]) or th.class
        end
        if th.level then values.level = tostring(th.level) end
    end
    values.name = values.name or "there"
    values.class = values.class or "player"
    values.level = values.level or "?"
    return (text:gsub("{(%a+)}", function(word)
        local v = values[word:lower()]
        return v or ("{" .. word .. "}")
    end))
end

---------------------------------------------------------------------------
-- Login summary
---------------------------------------------------------------------------

function X:LoginSummary()
    if not TG.db or TG.db.settings.loginSummary == false then return end
    local list, total = {}, 0
    for key, th in pairs(TG.db.threads) do
        if th.kind ~= "CHANNEL" and (th.unread or 0) > 0 then
            list[#list + 1] = key
            total = total + th.unread
        end
    end
    if total == 0 then return end
    table.sort(list, function(a, b) return (TG.db.threads[a].order or 0) > (TG.db.threads[b].order or 0) end)
    local names = {}
    for i = 1, math.min(4, #list) do
        local name, color = TG:ThreadDisplay(list[i])
        names[i] = ("|cff%s%s|r"):format(TG.UI.hex(color), name)
    end
    local who = table.concat(names, ", ")
    if #list > 4 then who = who .. (" and %d more"):format(#list - 4) end
    TG:Print(("%d unread message%s waiting from %s. Type /tg to open."):format(total, total == 1 and "" or "s", who))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    pcall(f.RegisterEvent, f, ev)
end
f:SetScript("OnEvent", function(_, event)
    if not TG.db then return end
    if event == "PLAYER_LOGIN" then
        X:Prune()
        C_Timer.After(6, function() X:LoginSummary() end)
    end
    -- the roster arrives in bursts: look once, a moment later
    if not X.queued then
        X.queued = true
        C_Timer.After(1, function()
            X.queued = false
            X:NoteGroup()
        end)
    end
end)
