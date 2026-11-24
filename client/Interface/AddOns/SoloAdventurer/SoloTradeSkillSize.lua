-- Solo Adventurer: a bigger profession window, with optional bigger text.
--   /tsw big        the blown-up preset (16 rows, scale 1.25, text 13); /tsw small = stock again
--   /tsw auto on|off  shrink back to stock while another panel (character, spellbook, merchant...) is open
--   /tsw rows N     recipe rows in the list (8 = stock, up to 30; the window grows taller)
--   /tsw scale X    size of the whole window, 0.8 to 1.6 (1 = stock); text grows with it
--   /tsw text N     font size of the recipe list and the recipe details (0 = stock)
--   /tsw reset      stock window again
--   /tsw            shows the current values
-- Everything is saved in SoloAdventurerSettings and applied each time the window loads. Every step is wrapped in
-- pcall: if something in the stock layout is not as expected, the stock window is left as it was.

SoloAdventurerSettings = SoloAdventurerSettings or {}

local STOCK_ROWS = 8
local ROW_HEIGHT = 16
local STOCK_HEIGHT = 512
local STOCK_DETAIL_Y = -234
local STOCK_LIST_HEIGHT = 130

local made = false         -- extra rows created
local gap                  -- backdrop that fills the gap the taller window leaves between the two art halves

local function Settings()
    return SoloAdventurerSettings
end

local function Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and Settings().debug then
        print("|cffff8080Solo tradeskill window:|r " .. tostring(err))
    end
    return ok
end

local function CreateRows(count)
    for i = STOCK_ROWS + 1, count do
        if not _G["TradeSkillSkill" .. i] then
            local button = CreateFrame("Button", "TradeSkillSkill" .. i, TradeSkillFrame, "TradeSkillSkillButtonTemplate")
            button:SetID(i)
            button:SetPoint("TOPLEFT", _G["TradeSkillSkill" .. (i - 1)], "BOTTOMLEFT", 0, 0)
        end
    end
end

local function ApplyText(size)
    local names = { "TradeSkillSkillName", "TradeSkillRequirementText", "TradeSkillDescription", "TradeSkillReagentLabel",
        "TradeSkillSkillCooldown" }
    for i = 1, 8 do
        table.insert(names, "TradeSkillReagent" .. i .. "Name")
        table.insert(names, "TradeSkillReagent" .. i .. "Count")
    end
    for i = 1, 40 do
        table.insert(names, "TradeSkillSkill" .. i .. "Text")
    end
    for _, name in ipairs(names) do
        local fs = _G[name]
        if fs and fs.GetFont and fs.SetFont then
            local path, stock, flags = fs:GetFont()
            fs.soloStockFont = fs.soloStockFont or { path, stock, flags }
            local base = fs.soloStockFont
            if size and size > 0 then
                fs:SetFont(base[1], size, base[3])
            else
                fs:SetFont(base[1], base[2], base[3])
            end
        end
    end
end

-- Panels that sit beside the profession window. While one of them is open the window falls back to stock size
-- (unless /tsw auto is off) and grows again when it is the only one left. Bags and bars are not listed.
local OTHER_WINDOWS = { "CharacterFrame", "SpellBookFrame", "PlayerTalentFrame", "QuestLogFrame", "FriendsFrame",
    "AchievementFrame", "LFDParentFrame", "PVPFrame", "GuildFrame", "MerchantFrame", "AuctionFrame", "BankFrame",
    "MailFrame", "TradeFrame", "GossipFrame", "QuestFrame", "InspectFrame", "GlyphFrame", "WorldMapFrame",
    "ClassTrainerFrame", "TaxiFrame", "ItemSocketingFrame", "GuildBankFrame", "CalendarFrame", "ReforgingFrame" }

local function OtherWindowOpen()
    for _, name in ipairs(OTHER_WINDOWS) do
        local frame = _G[name]
        if frame and frame.IsShown and frame:IsShown() then
            return true
        end
    end
    return false
end

local function Apply()
    if not TradeSkillFrame then
        return
    end
    local rows = math.max(STOCK_ROWS, math.min(30, tonumber(Settings().tradeSkillRows) or STOCK_ROWS))
    local scale = math.max(0.8, math.min(1.6, tonumber(Settings().tradeSkillScale) or 1))
    local text = tonumber(Settings().tradeSkillText) or 0
    if Settings().tradeSkillAuto ~= false and OtherWindowOpen() then
        rows, scale, text = STOCK_ROWS, 1, 0
    end
    local extra = (rows - STOCK_ROWS) * ROW_HEIGHT

    Safe(function()
        if rows > STOCK_ROWS and not made then
            CreateRows(30)
            made = true
        end
        TRADE_SKILLS_DISPLAYED = rows
        for i = STOCK_ROWS + 1, 30 do
            local button = _G["TradeSkillSkill" .. i]
            if button and i > rows then
                button:Hide()
            end
        end

        TradeSkillFrame:SetHeight(STOCK_HEIGHT + extra)
        TradeSkillListScrollFrame:SetHeight(STOCK_LIST_HEIGHT + extra)
        TradeSkillDetailScrollFrame:ClearAllPoints()
        TradeSkillDetailScrollFrame:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 22, STOCK_DETAIL_Y - extra)

        -- the stock art is two 256-high halves; paint the gap between them
        if not gap then
            gap = CreateFrame("Frame", nil, TradeSkillFrame)
            gap:SetFrameLevel(TradeSkillFrame:GetFrameLevel())
            gap:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32 })
        end
        if extra > 0 then
            gap:ClearAllPoints()
            gap:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 8, -250)
            gap:SetPoint("BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -32, 250)
            gap:Show()
        else
            gap:Hide()
        end
    end)

    Safe(TradeSkillFrame.SetScale, TradeSkillFrame, scale)
    Safe(ApplyText, text)
    if TradeSkillFrame:IsShown() and TradeSkillFrame_Update then
        Safe(TradeSkillFrame_Update)
    end
end

-- while the window is open, look every 0.3 s whether another panel opened or closed
local watcher = CreateFrame("Frame")
local lastOther, elapsed = nil, 0
watcher:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed < 0.3 then
        return
    end
    elapsed = 0
    local other = OtherWindowOpen()
    if other ~= lastOther then
        lastOther = other
        Apply()
    end
end)
watcher:Hide()

local function Hook()
    Apply()
    TradeSkillFrame:HookScript("OnShow", function()
        lastOther = OtherWindowOpen()
        Apply()
        watcher:Show()
    end)
    TradeSkillFrame:HookScript("OnHide", function()
        watcher:Hide()
    end)
    if TradeSkillFrame:IsShown() then
        watcher:Show()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_TradeSkillUI" then
        Hook()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
if IsAddOnLoaded("Blizzard_TradeSkillUI") then
    Hook()
    loader:UnregisterEvent("ADDON_LOADED")
end

SLASH_SOLOTSW1 = "/tsw"
SlashCmdList["SOLOTSW"] = function(msg)
    local cmd, value = (msg or ""):match("^(%S*)%s*(%S*)")
    cmd = cmd:lower()
    local s = Settings()
    if cmd == "rows" and tonumber(value) then
        s.tradeSkillRows = math.max(STOCK_ROWS, math.min(30, math.floor(tonumber(value))))
    elseif cmd == "scale" and tonumber(value) then
        s.tradeSkillScale = math.max(0.8, math.min(1.6, tonumber(value)))
    elseif cmd == "text" and tonumber(value) then
        s.tradeSkillText = math.max(0, math.min(24, math.floor(tonumber(value))))
    elseif cmd == "big" then
        s.tradeSkillRows, s.tradeSkillScale, s.tradeSkillText = 16, 1.25, 13
    elseif cmd == "auto" then
        s.tradeSkillAuto = (value == "off") and false or true
        print("Shrink to stock size while another window is open: " .. (s.tradeSkillAuto and "on" or "off"))
    elseif cmd == "reset" or cmd == "small" then
        s.tradeSkillRows, s.tradeSkillScale, s.tradeSkillText = nil, nil, nil
    elseif cmd == "debug" then
        s.debug = not s.debug
        print("Solo tradeskill window debug " .. (s.debug and "on" or "off"))
    elseif cmd ~= "" then
        print("/tsw big, /tsw small, /tsw rows N (8-30), /tsw scale X (0.8-1.6), /tsw text N (0 = stock), "
            .. "/tsw auto on|off (shrink while another window is open)")
        return
    end
    print(("Profession window: rows %d, scale %.2f, text %s. Reopen the window to see it."):format(
        s.tradeSkillRows or STOCK_ROWS, s.tradeSkillScale or 1, (s.tradeSkillText or 0) > 0 and s.tradeSkillText or "stock"))
    Apply()
end
