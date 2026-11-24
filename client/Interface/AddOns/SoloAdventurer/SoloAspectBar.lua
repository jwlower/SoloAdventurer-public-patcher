-- Solo Adventurer: a stance-style bar in the stance / pet bar row for the spells that replace each other:
-- hunter aspects, mage armors and warlock armors. One button per spell you know, the active one lit.
-- The buttons just cast the spell (the server already makes them exclusive), so Metamorphosis and the rest are untouched.

local SETS = {
    HUNTER = { "Aspect of the Hawk", "Aspect of the Monkey", "Aspect of the Cheetah", "Aspect of the Pack",
               "Aspect of the Wild", "Aspect of the Viper", "Aspect of the Beast", "Aspect of the Dragonhawk" },
    MAGE = { "Molten Armor", "Mage Armor", "Ice Armor", "Frost Armor" },
    WARLOCK = { "Fel Armor", "Demon Armor", "Demon Skin" },
}

local _, class = UnitClass("player")
local list = SETS[class]
if not list then return end

local SIZE, GAP = 30, 4
local bar = CreateFrame("Frame", "SoloAspectBar", UIParent)
bar:SetHeight(SIZE)
bar:SetWidth(SIZE)
bar:SetFrameStrata("MEDIUM")
bar:Hide()

local buttons = {}
local needsLayout = false

local needsAnchor = false

-- In the same row as the stance and pet bars, like Metamorphosis and the minion controls: right after whichever of
-- them ends furthest right (pet bar, then stance buttons, then totem bar), or where the stance bar would sit.
local function RowEnd()
    if PetActionBarFrame and PetActionBarFrame:IsShown() and PetActionButton10 then
        return PetActionButton10
    end
    local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    if forms > 0 and ShapeshiftBarFrame and ShapeshiftBarFrame:IsShown() then
        return _G["ShapeshiftButton" .. forms]
    end
    if MultiCastActionBarFrame and HasMultiCastActionBar and HasMultiCastActionBar() then
        return MultiCastActionBarFrame
    end
end

local function Anchor()
    if InCombatLockdown() then
        needsAnchor = true
        return
    end
    needsAnchor = false
    bar:ClearAllPoints()
    local edge = RowEnd()
    if edge then
        bar:SetPoint("LEFT", edge, "RIGHT", 20, 0)
        return
    end
    local point, relative, relativePoint, x, y
    if ShapeshiftBarFrame then
        point, relative, relativePoint, x, y = ShapeshiftBarFrame:GetPoint(1)
    end
    if point and relative then
        bar:SetPoint(point, relative, relativePoint, x or 0, y or 0)
    else
        bar:SetPoint("BOTTOMLEFT", MainMenuBar, "TOPLEFT", 30, 2)
    end
end

local function Button(i)
    if buttons[i] then return buttons[i] end
    local b = CreateFrame("CheckButton", "SoloAspectBarButton" .. i, bar, "SecureActionButtonTemplate")
    b:SetWidth(SIZE)
    b:SetHeight(SIZE)
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("type", "spell")

    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints(b)
    b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    b:GetNormalTexture():SetWidth(SIZE * 1.7)
    b:GetNormalTexture():SetHeight(SIZE * 1.7)
    b:GetNormalTexture():ClearAllPoints()
    b:GetNormalTexture():SetPoint("CENTER", b, "CENTER", 0, -1)
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")

    b.cooldown = CreateFrame("Cooldown", "SoloAspectBarButton" .. i .. "Cooldown", b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b)

    b:SetScript("OnEnter", function(self)
        if not self.spellIndex then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetSpell(self.spellIndex, BOOKTYPE_SPELL)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- a click must not leave the button checked: the aura decides
    b:SetScript("PostClick", function(self) SoloAspectBar_Update() end)
    buttons[i] = b
    return b
end

local function KnownSpells()
    local known = {}
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for i = offset + 1, offset + count do
            local name = GetSpellName(i, BOOKTYPE_SPELL)
            if name then known[name] = i end      -- later ranks overwrite earlier ones
        end
    end
    return known
end

local function Layout()
    if InCombatLockdown() then
        needsLayout = true
        return
    end
    needsLayout = false
    local known = KnownSpells()
    local shown = 0
    for _, name in ipairs(list) do
        if known[name] then
            shown = shown + 1
            local b = Button(shown)
            b.spellName = name
            b.spellIndex = known[name]
            b:SetAttribute("spell", name)
            b.icon:SetTexture(GetSpellTexture(known[name], BOOKTYPE_SPELL))
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", (shown - 1) * (SIZE + GAP), 0)
            b:Show()
        end
    end
    for i = shown + 1, #buttons do
        buttons[i]:Hide()
        buttons[i].spellName = nil
        buttons[i]:SetAttribute("spell", nil)
    end
    if shown > 0 then
        bar:SetWidth(shown * (SIZE + GAP) - GAP)
        Anchor()
        bar:Show()
    else
        bar:Hide()
    end
end

function SoloAspectBar_Update()
    for _, b in ipairs(buttons) do
        if b:IsShown() and b.spellName then
            b:SetChecked(UnitBuff("player", b.spellName) and 1 or 0)
            local start, duration, enable = GetSpellCooldown(b.spellIndex, BOOKTYPE_SPELL)
            if start and start > 0 and duration > 1.5 then
                CooldownFrame_SetTimer(b.cooldown, start, duration, enable)
            else
                CooldownFrame_SetTimer(b.cooldown, 0, 0, 0)
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("LEARNED_SPELL_IN_TAB")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("UNIT_PET")
events:RegisterEvent("PET_BAR_UPDATE")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" then
        if unit == "player" then SoloAspectBar_Update() end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        SoloAspectBar_Update()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if needsLayout then Layout() elseif needsAnchor and bar:IsShown() then Anchor() end
    elseif event == "UNIT_PET" or event == "PET_BAR_UPDATE" or event == "UPDATE_SHAPESHIFT_FORMS" then
        if bar:IsShown() then Anchor() end
    else
        Layout()
        SoloAspectBar_Update()
    end
end)

if UIParent_ManageFramePositions then
    hooksecurefunc("UIParent_ManageFramePositions", function()
        if bar:IsShown() then Anchor() end
    end)
end
if PetActionBarFrame then
    PetActionBarFrame:HookScript("OnShow", function() if bar:IsShown() then Anchor() end end)
    PetActionBarFrame:HookScript("OnHide", function() if bar:IsShown() then Anchor() end end)
end
