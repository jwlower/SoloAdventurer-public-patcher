-- Solo Adventurer: a tidier profession window.
--  - Expansions: recipes are grouped under Northrend, Outland and Azeroth headers (ReforgeRecipes.lua says which;
--    not listed means Azeroth), each holding the profession's usual headers, indented. Every header opens and
--    closes on its own and remembers it.
--  - "Dungeon Forged" and "Reforged": recipes that rework a piece of gear (any recipe that takes a weapon or armor
--    piece as a reagent, listed in ReforgeRecipes.lua; Reforged / Retooled / Restrung by name) are pulled out of
--    their usual headers into these two, at the end of their expansion and closed by default: Dungeon Forged when
--    the piece is a drop, Reforged when a profession makes it.
--  - "Skill-ups" checkbox: hide grey recipes that can no longer raise the skill.
-- Works by remapping the trade skill list indexes the Blizzard UI asks for, so the stock window draws it. The real
-- headers are kept open (a closed one hides its recipes from the list) and only the virtual ones are shown.

SoloAdventurerSettings = SoloAdventurerSettings or {}

local EXPANSIONS = {   -- newest first, like the stock list puts the highest skill first
    { id = 2, title = "Northrend" },
    { id = 1, title = "Outland" },
    { id = 0, title = "Azeroth" },
}
local GROUPS = {       -- after the usual headers of an expansion
    { key = "dungeon", title = "Dungeon Forged" },
    { key = "reforged", title = "Reforged" },
}
local SUB_INDENT = "   "
local OTHER = "Other"  -- recipes listed before the profession's first header

local Real = {}
for _, name in ipairs({ "GetNumTradeSkills", "GetTradeSkillInfo", "GetFirstTradeSkill", "GetTradeSkillSelectionIndex",
    "SelectTradeSkill", "ExpandTradeSkillSubClass", "CollapseTradeSkillSubClass", "GetTradeSkillIcon",
    "GetTradeSkillItemLink", "GetTradeSkillRecipeLink", "GetTradeSkillNumMade", "GetTradeSkillNumReagents",
    "GetTradeSkillReagentInfo", "GetTradeSkillReagentItemLink", "GetTradeSkillTools", "GetTradeSkillCooldown",
    "GetTradeSkillDescription", "DoTradeSkill" }) do
    Real[name] = _G[name]
end

local map = {}          -- shown index -> real index, or a virtual header { key, title }
local shown = {}        -- real index -> shown index
local headerKeys = {}   -- every virtual header key of the last build, for "expand / collapse all"
local builtFor = {}     -- profession and real list size the map was built from

local function Settings()
    return SoloAdventurerSettings
end

-- open/closed per virtual header key; groups start closed, everything else open
local function IsOpen(key, closedByDefault)
    local state = Settings().headerOpen and Settings().headerOpen[key]
    if state == nil then
        return not closedByDefault
    end
    return state
end

local function SetOpen(key, open)
    Settings().headerOpen = Settings().headerOpen or {}
    Settings().headerOpen[key] = open and true or false
end

-------------------------------------------------------------------------------
-- Building the shown list
-------------------------------------------------------------------------------
-- By name only: looking the reagents up (GetItemInfo) would send the server a query for every uncached item on
-- every list refresh, which floods and can crash the client while its item cache is empty.
local function GroupOf(name)
    local listed = SoloAdventurerReforgeRecipes and SoloAdventurerReforgeRecipes[name]
    if listed then
        return listed == "dungeon" and "dungeon" or "reforged"
    end
    if name:find(" Reforged$") or name:find("^Restrung ") or name:find("^Retooled ") or name:find(" Retooled$") then
        return "reforged"
    end
end

local function ExpansionOf(name)
    return SoloAdventurerRecipeExpansion and SoloAdventurerRecipeExpansion[name] or 0
end

-- true when a real header is closed: open them all, since a closed one hides its recipes
local function OpenRealHeaders()
    for i = 1, Real.GetNumTradeSkills() do
        local _, kind, _, expanded = Real.GetTradeSkillInfo(i)
        if kind == "header" and not expanded then
            Real.ExpandTradeSkillSubClass(0)
            return true
        end
    end
end

local function Rebuild()
    OpenRealHeaders()
    wipe(map)
    wipe(shown)
    wipe(headerKeys)
    builtFor.line = GetTradeSkillLine()
    builtFor.count = Real.GetNumTradeSkills()

    local skillUpsOnly = Settings().skillUpsOnly
    -- sections[expansion id] = ordered list of { key, title, closedByDefault, recipes = { real indexes } }
    local sections, byKey = {}, {}
    local header = OTHER

    local function Section(exp, subKey, title, closedByDefault)
        local key = exp .. ":" .. subKey
        local section = byKey[key]
        if not section then
            section = { key = key, title = title, closedByDefault = closedByDefault, recipes = {} }
            byKey[key] = section
            sections[exp] = sections[exp] or {}
            table.insert(sections[exp], section)
        end
        return section
    end

    for i = 1, Real.GetNumTradeSkills() do
        local name, kind = Real.GetTradeSkillInfo(i)
        if kind == "header" then
            header = name or OTHER
        elseif name and not (skillUpsOnly and kind == "trivial") then
            local exp = ExpansionOf(name)
            local group = GroupOf(name)
            local section = group and Section(exp, group, group == "dungeon" and GROUPS[1].title or GROUPS[2].title, true)
                or Section(exp, "h:" .. header, header)
            table.insert(section.recipes, i)
        end
    end

    for _, expansion in ipairs(EXPANSIONS) do
        local list = sections[expansion.id]
        if list then
            -- the profession's own headers first, then Dungeon Forged and Reforged
            local ordered = {}
            for _, section in ipairs(list) do
                if not section.closedByDefault then
                    table.insert(ordered, section)
                end
            end
            for _, group in ipairs(GROUPS) do
                local section = byKey[expansion.id .. ":" .. group.key]
                if section then
                    table.insert(ordered, section)
                end
            end

            local expKey = "exp:" .. expansion.id
            headerKeys[#headerKeys + 1] = expKey
            map[#map + 1] = { key = expKey, title = expansion.title }
            local expOpen = IsOpen(expKey)
            for _, section in ipairs(ordered) do
                headerKeys[#headerKeys + 1] = section.key
                if expOpen then
                    map[#map + 1] = { key = section.key, title = SUB_INDENT .. section.title, closedByDefault = section.closedByDefault }
                    if IsOpen(section.key, section.closedByDefault) then
                        for _, real in ipairs(section.recipes) do
                            map[#map + 1] = real
                        end
                    end
                end
            end
        end
    end

    for index, real in ipairs(map) do
        if type(real) == "number" then
            shown[real] = index
        end
    end
end

-- A different profession opened, or the real list changed (filters, search, learned recipes), since the last build.
local function EnsureFresh()
    if builtFor.line ~= GetTradeSkillLine() or builtFor.count ~= Real.GetNumTradeSkills() then
        Rebuild()
    end
end

local function RealIndex(index)
    EnsureFresh()
    local real = map[index]
    if type(real) == "number" then
        return real
    end
end

-- the virtual header at this shown index, if it is one
local function HeaderAt(index)
    local entry = map[index]
    if type(entry) == "table" then
        return entry
    end
end

-------------------------------------------------------------------------------
-- Remapped trade skill API (used by the Blizzard trade skill window)
-------------------------------------------------------------------------------
function GetNumTradeSkills()
    Rebuild()
    return #map
end

function GetTradeSkillInfo(index)
    EnsureFresh()
    local header = HeaderAt(index)
    if header then
        return header.title, "header", 0, IsOpen(header.key, header.closedByDefault) and 1 or nil
    end
    local real = RealIndex(index)
    if real then
        return Real.GetTradeSkillInfo(real)
    end
end

function GetFirstTradeSkill()
    Rebuild()
    for index, real in ipairs(map) do
        if type(real) == "number" then
            return index
        end
    end
    return 0
end

function GetTradeSkillSelectionIndex()
    EnsureFresh()
    return shown[Real.GetTradeSkillSelectionIndex()] or 0
end

-- The window redraws itself after a real header changes (TRADE_SKILL_UPDATE); a virtual one needs asking.
local function Redraw()
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        TradeSkillFrame_Update()
    end
end

-- index 0 is the window's "expand / collapse all" button
local function SetAll(open)
    for _, key in ipairs(headerKeys) do
        SetOpen(key, open)
    end
end

function ExpandTradeSkillSubClass(index)
    EnsureFresh()
    if index == 0 then
        SetAll(true)
    elseif HeaderAt(index) then
        SetOpen(HeaderAt(index).key, true)
    end
    Rebuild()
    Redraw()
end

function CollapseTradeSkillSubClass(index)
    EnsureFresh()
    if index == 0 then
        SetAll(false)
    elseif HeaderAt(index) then
        SetOpen(HeaderAt(index).key, false)
    end
    Rebuild()
    Redraw()
end

-- Everything else that takes a list index just gets the real one.
for _, name in ipairs({ "SelectTradeSkill", "GetTradeSkillIcon", "GetTradeSkillItemLink", "GetTradeSkillRecipeLink",
    "GetTradeSkillNumMade", "GetTradeSkillNumReagents", "GetTradeSkillReagentInfo", "GetTradeSkillReagentItemLink",
    "GetTradeSkillTools", "GetTradeSkillCooldown", "GetTradeSkillDescription", "DoTradeSkill" }) do
    local real = Real[name]
    _G[name] = function(index, ...)
        local realIndex = RealIndex(index)
        if realIndex then
            return real(realIndex, ...)
        end
    end
end

local tooltipSetTradeSkillItem = GameTooltip.SetTradeSkillItem
GameTooltip.SetTradeSkillItem = function(self, index, ...)
    local realIndex = RealIndex(index)
    if realIndex then
        return tooltipSetTradeSkillItem(self, realIndex, ...)
    end
end

-------------------------------------------------------------------------------
-- "Skill-ups" checkbox
-------------------------------------------------------------------------------
local function Refresh()
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        TradeSkillFrame_SetSelection(GetFirstTradeSkill())
        FauxScrollFrame_SetOffset(TradeSkillListScrollFrame, 0)
        TradeSkillListScrollFrameScrollBar:SetValue(0)
        TradeSkillFrame_Update()
    end
end

local function CreateSkillUpCheckButton()
    local check = CreateFrame("CheckButton", "SoloAdvSkillUpCheckButton", TradeSkillFrame, "UICheckButtonTemplate")
    check:SetWidth(24)
    check:SetHeight(24)
    check:SetPoint("LEFT", TradeSkillFrameAvailableFilterCheckButtonText, "RIGHT", 4, 0)
    SoloAdvSkillUpCheckButtonText:SetText("Skill-ups")
    check:SetHitRectInsets(0, -50, 0, 0)
    check:SetChecked(Settings().skillUpsOnly)
    check:SetScript("OnClick", function(self)
        Settings().skillUpsOnly = self:GetChecked() and true or nil
        Refresh()
    end)
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Only show recipes that can still raise your skill (hide grey ones).", nil, nil, nil, nil, 1)
    end)
    check:SetScript("OnLeave", GameTooltip_Hide)

    -- make room: the search box sits right of "Have Materials"
    TradeSkillFrameEditBox:SetWidth(90)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_TradeSkillUI" then
        CreateSkillUpCheckButton()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
if IsAddOnLoaded("Blizzard_TradeSkillUI") then
    CreateSkillUpCheckButton()
    loader:UnregisterEvent("ADDON_LOADED")
end
