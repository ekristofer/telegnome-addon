-- Telegnome: a pop-up when new mail arrives.
--   The game only tells addons that there is new mail and who sent the latest (up to three senders);
--   what's in it can only be read at a mailbox. So this is a notification, not a conversation.

local _, ns = ...
local TG = ns.TG
local M = {}
TG.Mail = M

M.DEFAULT_TEXT = "New mail from {from}"

local function clean(v)
    if type(v) ~= "string" or v == "" or TG.isSecret(v) then return nil end
    return v
end

-- The latest senders of unread mail, each once, with how many of the latest three they sent:
-- { { name = "Stormwind Auction House", n = 2 }, { name = "Thrall", n = 1 } }
function M.Senders()
    local out, byName = {}, {}
    if not GetLatestThreeSenders then return out end
    local ok, a, b, c = pcall(GetLatestThreeSenders)
    if not ok then return out end
    for _, v in ipairs({ clean(a) or false, clean(b) or false, clean(c) or false }) do
        if v then
            local e = byName[v]
            if e then
                e.n = e.n + 1
            else
                e = { name = v, n = 1 }
                byName[v] = e
                out[#out + 1] = e
            end
        end
    end
    return out
end

-- "Thrall", "Thrall and Jaina", "Stormwind Auction House (2) and Thrall"
function M.FromText(list)
    local names, total = {}, 0
    for i, e in ipairs(list) do
        names[i] = e.n > 1 and ("%s (%d)"):format(e.name, e.n) or e.name
        total = total + e.n
    end
    if #names == 0 then return "someone" end
    local s = #names == 1 and names[1] or (table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names])
    if total >= 3 then s = s .. " and maybe more" end -- the game names the latest three only
    return s
end

function M.Text(list)
    local tmpl = TG.db.settings.mailText
    if type(tmpl) ~= "string" or strtrim(tmpl) == "" then tmpl = M.DEFAULT_TEXT end
    local from = M.FromText(list):gsub("%%", "%%%%")
    return (tmpl:gsub("{from}", from))
end

local function inCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

-- Shows the pop-up (and the sound, if sounds are on). In combat it follows Settings > Notifications > In combat.
function M:Notify(list, test)
    local s = TG.db.settings
    if not test then
        if s.mailNotify == false or s.dnd then return end
        local how = s.combatNotify or "summary"
        if inCombat() and how ~= "all" then
            if how == "summary" then self.pending = list end
            return
        end
    end
    if TG.Toast and TG.Toast.Notice then
        TG.Toast:Notice("|cffffd100New mail|r", M.Text(list), nil)
    end
    TG:MaybePlaySound(nil, true)
end

-- Called when the game says the mail changed. Only tells you when something is new.
function M:Check()
    if not TG.db then return end
    local has = HasNewMail and HasNewMail()
    if not has then
        self.lastSig = nil
        return
    end
    local list = M.Senders()
    local parts = {}
    for i, e in ipairs(list) do parts[i] = e.name .. "#" .. e.n end
    local sig = #parts > 0 and table.concat(parts, "\1") or "?"
    if sig == self.lastSig then return end
    self.lastSig = sig
    if self.quiet then return end -- after a /reload: you've been told already
    self:Notify(list)
end

local f = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_PENDING_MAIL", "PLAYER_REGEN_ENABLED" }) do
    pcall(f.RegisterEvent, f, ev)
end
f:SetScript("OnEvent", function(_, event, isLogin, isReload)
    if not TG.db then return end
    if event == "PLAYER_ENTERING_WORLD" then
        if M.ready ~= nil then return end -- loading screens later on
        M.ready = false
        -- the mail info settles a few seconds after logging in
        C_Timer.After(5, function()
            M.ready = true
            M.quiet = isReload and true or nil
            M:Check()
            M.quiet = nil
        end)
    elseif event == "UPDATE_PENDING_MAIL" then
        if M.ready then M:Check() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local list = M.pending
        M.pending = nil
        if list then M:Notify(list) end
    end
end)
