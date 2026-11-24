-- Solo Adventurer: the control panel of the hunter's second pet (Beast Mastery's Call Second Pet), stacked above the normal
-- pet bar: a health bar with its name, then buttons for Attack, Follow, Stay, Passive / Defensive / Aggressive and Dismiss.
-- The game has one pet bar, so the server (src/SoloSecondPet.cpp) talks to this file through addon whispers to self with the
-- prefix "SCP": we send ATK, FOLLOW, STAY, MODE^0|1|2, DISMISS, HELLO; it sends ST^name^health%^stay^mode^level and OFF.
-- The buttons are plain buttons (they only send a message), so they work in combat.

local _, class = UnitClass("player")
if class ~= "HUNTER" then return end

local PREFIX = "SCP"
local SIZE, GAP = 30, 4
local BUTTONS = 7
local WIDTH = BUTTONS * SIZE + (BUTTONS - 1) * GAP
local BAR_HEIGHT = 14

local panel = CreateFrame("Frame", "SoloSecondPetBar", UIParent)
panel:SetWidth(WIDTH)
panel:SetHeight(BAR_HEIGHT + GAP + SIZE)
panel:SetFrameStrata("MEDIUM")
panel:Hide()

local state = { stay = false, mode = 2 }

local function Send(body)
    SendAddonMessage(PREFIX, body, "WHISPER", UnitName("player"))
end

-- anchored above the pet bar (which sits above the action bars). The hidden pet bar still has a place (after a death,
-- say), but the aspect bar then moves into that spot, so with the pet bar hidden the panel goes above the aspect bar.
local function Anchor()
    panel:ClearAllPoints()
    if PetActionBarFrame and PetActionBarFrame:IsShown() then
        panel:SetPoint("BOTTOMLEFT", PetActionBarFrame, "TOPLEFT", 0, 4)
    elseif SoloAspectBar and SoloAspectBar:IsShown() then
        panel:SetPoint("BOTTOMLEFT", SoloAspectBar, "TOPLEFT", 0, 8)
    elseif ShapeshiftBarFrame and ShapeshiftBarFrame:GetLeft() then
        panel:SetPoint("BOTTOMLEFT", ShapeshiftBarFrame, "TOPLEFT", 0, 4)
    else
        panel:SetPoint("BOTTOMLEFT", MainMenuBar, "TOPLEFT", 30, 50)
    end
end

-- health bar with the name over it
local bar = CreateFrame("StatusBar", "SoloSecondPetBarHealth", panel)
bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
bar:SetWidth(WIDTH)
bar:SetHeight(BAR_HEIGHT)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.1, 0.8, 0.1)
bar:SetMinMaxValues(0, 100)
bar:SetValue(100)
bar.bg = bar:CreateTexture(nil, "BACKGROUND")
bar.bg:SetAllPoints(bar)
bar.bg:SetTexture(0, 0, 0, 0.6)
bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)

local ICONS = {
    attack = PET_ATTACK_TEXTURE or "Interface\\Icons\\Ability_GhoulFrenzy",
    follow = PET_FOLLOW_TEXTURE or "Interface\\Icons\\Ability_Tracking",
    stay = PET_WAIT_TEXTURE or "Interface\\Icons\\Spell_Nature_TimeStop",
    passive = PET_PASSIVE_TEXTURE or "Interface\\Icons\\Ability_Seal",
    defensive = PET_DEFENSIVE_TEXTURE or "Interface\\Icons\\Ability_Defend",
    aggressive = PET_AGGRESSIVE_TEXTURE or "Interface\\Icons\\Ability_Racial_BloodRage",
    dismiss = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}

local buttons = {}
local function AddButton(index, key, label, onClick)
    local b = CreateFrame("CheckButton", "SoloSecondPetBarButton" .. index, panel)
    b:SetWidth(SIZE)
    b:SetHeight(SIZE)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", (index - 1) * (SIZE + GAP), -(BAR_HEIGHT + GAP))
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints(b)
    b.icon:SetTexture(ICONS[key])
    b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    b:GetNormalTexture():SetWidth(SIZE * 1.7)
    b:GetNormalTexture():SetHeight(SIZE * 1.7)
    b:GetNormalTexture():ClearAllPoints()
    b:GetNormalTexture():SetPoint("CENTER", b, "CENTER", 0, -1)
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(self)
        onClick()
        SoloSecondPetBar_Refresh()          -- the server's answer sets the real state; until then keep the old one
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetText(label)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[key] = b
    return b
end

AddButton(1, "attack", "Attack", function() Send("ATK") end)
AddButton(2, "follow", "Follow", function() Send("FOLLOW") end)
AddButton(3, "stay", "Stay", function() Send("STAY") end)
AddButton(4, "passive", "Passive: attacks only when ordered to", function() Send("MODE^0") end)
AddButton(5, "defensive", "Defensive: fights what attacks you or it", function() Send("MODE^1") end)
AddButton(6, "aggressive", "Aggressive: also fights what you attack", function() Send("MODE^2") end)
AddButton(7, "dismiss", "Send the second pet away", function() Send("DISMISS") end)

function SoloSecondPetBar_Refresh()
    buttons.follow:SetChecked(not state.stay)
    buttons.stay:SetChecked(state.stay)
    buttons.passive:SetChecked(state.mode == 0)
    buttons.defensive:SetChecked(state.mode == 1)
    buttons.aggressive:SetChecked(state.mode == 2)
    buttons.attack:SetChecked(false)
    buttons.dismiss:SetChecked(false)
end

local function Show(name, health, stay, mode, level)
    state.stay = stay == "1"
    state.mode = tonumber(mode) or 2
    local percent = tonumber(health) or 0
    bar:SetValue(percent)
    if percent > 50 then
        bar:SetStatusBarColor(0.1, 0.8, 0.1)
    elseif percent > 25 then
        bar:SetStatusBarColor(0.9, 0.8, 0.1)
    else
        bar:SetStatusBarColor(0.9, 0.2, 0.1)
    end
    bar.text:SetText((name or "?") .. (level and (" (" .. level .. ")") or "") .. "  " .. percent .. "%")
    SoloSecondPetBar_Refresh()
    Anchor()
    panel:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix ~= PREFIX or not message then return end
        if message == "OFF" then
            panel:Hide()
            return
        end
        local kind, name, health, stay, mode, level = strsplit("^", message)
        if kind == "ST" then Show(name, health, stay, mode, level) end
    else
        panel:Hide()
        Send("HELLO")                      -- after a reload or login: is a second pet out?
    end
end)

if UIParent_ManageFramePositions then
    hooksecurefunc("UIParent_ManageFramePositions", function()
        if panel:IsShown() then Anchor() end
    end)
end
if PetActionBarFrame then
    PetActionBarFrame:HookScript("OnShow", function() if panel:IsShown() then Anchor() end end)
    PetActionBarFrame:HookScript("OnHide", function() if panel:IsShown() then Anchor() end end)
end
if SoloAspectBar then
    SoloAspectBar:HookScript("OnShow", function() if panel:IsShown() then Anchor() end end)
    SoloAspectBar:HookScript("OnHide", function() if panel:IsShown() then Anchor() end end)
end
