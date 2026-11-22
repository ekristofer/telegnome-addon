-- Telegnome: dungeons, raids and combat.
--   Entering a dungeon or raid offers to follow its group chat (Party or Raid, and Instance) until you
--   leave; it's pinned at the top of the All tab while you're inside, with an "Entered ..." line.
--   In combat, pop-ups and sounds wait; one summary pop-up comes when the fight is over.

local _, ns = ...
local TG = ns.TG
local D = {}
TG.Instances = D

-- The chats that belong to each kind of instance. Group finder groups use Instance chat, premade groups
-- use Party or Raid, so both are followed.
local CHATS = { party = { "PARTY", "INSTANCE_CHAT" }, raid = { "RAID", "INSTANCE_CHAT" } }
local WORD = { party = "dungeon", raid = "raid" }
local MAIN = { party = "Party", raid = "Raid" }

local function clean(v)
    if type(v) ~= "string" or v == "" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- "party" or "raid" and the instance's name while you're inside one, else nil.
function D.Where()
    if not IsInInstance then return nil end
    local ok, inside, itype = pcall(IsInInstance)
    if not ok or not inside or not CHATS[itype] then return nil end
    local name = GetInstanceInfo and clean((GetInstanceInfo()))
    return itype, name
end

---------------------------------------------------------------------------
-- Entering and leaving
---------------------------------------------------------------------------

function D:Check()
    if not TG.db then return end
    local itype, name = D.Where()
    local cur = TG.db.instance
    if itype then
        if cur and cur.type == itype and cur.name == name then return end -- same place (a reload, a new zone inside)
        if cur then self:Leave() end
        TG.db.instance = { type = itype, name = name, keys = {} }
        self:Entered()
    elseif cur then
        self:Leave()
    end
end

local function enteredLine(inst)
    return "Entered " .. (inst.name or ("the " .. WORD[inst.type]))
end

function D:Entered()
    local inst = TG.db.instance
    local C = TG.Channels
    local missing = false
    for _, ctype in ipairs(CHATS[inst.type]) do
        local key = C.KeyForType(ctype)
        local th = TG.db.threads[key]
        if th and th.kind == "CHANNEL" then
            -- already followed: pinned while you're inside, and the line marks where the run starts
            inst.keys[key] = "pin"
            th.tempPin = true
            TG:AddSystemLine(key, enteredLine(inst))
        else
            missing = true
        end
    end
    if missing then
        local how = TG.db.settings.instanceChat or "ask"
        if how == "always" then
            self:Start()
        elseif how == "ask" and TG.Toast then
            local shown = TG.Toast:Notice(("|cffffd100In a %s|r"):format(WORD[inst.type]),
                ("Click to follow %s chat until you leave."):format(MAIN[inst.type]),
                function() D:Start() end)
            if not shown then
                TG:Print(("In a %s. Type /tg follow-instance to follow %s chat until you leave.")
                    :format(WORD[inst.type], MAIN[inst.type]))
            end
        end
    end
    TG.UI:RefreshList()
end

-- Follows the instance's chats for as long as you're inside.
function D:Start()
    local inst = TG.db.instance
    if not inst then
        TG:Print("You're not in a dungeon or raid.")
        return
    end
    local C = TG.Channels
    local first
    for _, ctype in ipairs(CHATS[inst.type]) do
        local key = C.KeyForType(ctype)
        if not TG.db.threads[key] then
            C:Follow(ctype)
            inst.keys[key] = "temp"
            local th = TG.db.threads[key]
            if th then
                th.tempPin = true
                TG:AddSystemLine(key, enteredLine(inst))
                first = first or key
            end
        end
    end
    TG.UI:RefreshList()
    TG:RefreshUnread()
    if first and TG.UI.frame and TG.UI.frame:IsShown() and TG.UI.tab == "all" then TG.UI:Select(first) end
end

-- Leaving: the pins go; chats followed just for this instance are unfollowed. With "clear on new group"
-- off, their history is kept for next time.
function D:Leave()
    local inst = TG.db.instance
    TG.db.instance = nil
    if not inst then return end
    for key, mode in pairs(inst.keys or {}) do
        local th = TG.db.threads[key]
        if th then
            th.tempPin = nil
            -- pinned while inside: you want to keep it, so it stays followed
            if mode == "temp" and not th.fav then
                if not TG.db.settings.clearGroupChat then
                    TG.db.archive = TG.db.archive or {}
                    TG.db.archive[key] = th.msgs
                end
                TG:DeleteThread(key)
            end
        end
    end
    TG.UI:RefreshList()
    TG:RefreshUnread()
end

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------

local function inCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

-- Called instead of the pop-up and sound for a new message. True: no pop-up or sound now.
-- Settings > Notifications, In combat: "all" as usual, "summary" one pop-up when the fight is over,
-- "count" nothing but the numbers (notifier, minimap button, badges).
function D:Hold(key, alert)
    if not TG.db or not inCombat() then return false end
    local how = TG.db.settings.combatNotify or "summary"
    if how == "all" then return false end
    if how == "count" then return true end
    if not (alert or TG:PassesNotifyFilter(key)) then return true end -- would have stayed quiet anyway
    local held = self.held or { count = 0, keys = {}, seen = {} }
    self.held = held
    held.count = held.count + 1
    if not held.seen[key] then
        held.seen[key] = true
        held.keys[#held.keys + 1] = key
    end
    return true
end

function D:AfterCombat()
    local held = self.held
    self.held = nil
    if not held or held.count == 0 then return end
    local names = {}
    for i = 1, math.min(3, #held.keys) do
        local name, color = TG:ThreadDisplay(held.keys[i])
        names[i] = ("|cff%s%s|r"):format(TG.UI.hex(color), name)
    end
    local who = table.concat(names, ", ")
    if #held.keys > 3 then who = who .. (" and %d more"):format(#held.keys - 3) end
    local first = held.keys[1]
    TG:MaybePlaySound(first, true)
    if TG.Toast then
        TG.Toast:Notice(("|cffffd100%d new message%s|r"):format(held.count, held.count == 1 and "" or "s"),
            "From " .. who .. ". Click to open.", function()
                TG.UI:Show()
                if TG.db.threads[first] then TG.UI:Select(first) end
            end)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local f = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do
    pcall(f.RegisterEvent, f, ev)
end
f:SetScript("OnEvent", function(_, event)
    if not TG.db then return end
    if event == "PLAYER_REGEN_ENABLED" then
        D:AfterCombat()
        return
    end
    -- the instance info settles a moment after the loading screen
    if not D.queued then
        D.queued = true
        C_Timer.After(2, function()
            D.queued = false
            D:Check()
        end)
    end
end)
