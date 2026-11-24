-- Solo Adventurer: world map fast travel pins, free respec button, Double Jump.
-- Server side: modules/mod-solo-adventurer (addon prefixes "SFT" and "SDJ").

local PREFIX = "SFT"
local function PlayerName() return UnitName("player") end

local ICONS = {
    C = "Interface\\Icons\\Spell_Arcane_TeleportStormWind",
    I = "Interface\\Minimap\\Tracking\\Innkeeper",
    D = "Interface\\Icons\\INV_Misc_Key_13",
    S = "Interface\\Icons\\INV_Misc_Rune_01",
}
local SIZES = { C = 26, I = 18, D = 22, S = 22 }
local TYPE_LABEL = { C = "Capital City", I = "Inn", D = "Dungeon Entrance", S = "Starting Zone" }

local destinations = {}   -- ["T^K"] = { type, key, map, x, y, unlocked, name }
local incoming = nil
local pins = {}
local pinCount = 0

local function Send(body)
    SendAddonMessage(PREFIX, body, "WHISPER", PlayerName())
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffSolo Adventurer:|r " .. msg)
end

-------------------------------------------------------------------------------
-- Popups (raised above the fullscreen world map while visible)
-------------------------------------------------------------------------------
local function RaiseOnShow(self) self:SetFrameStrata("FULLSCREEN_DIALOG") end
local function LowerOnHide(self) self:SetFrameStrata("DIALOG") end

StaticPopupDialogs["SOLOADV_TRAVEL"] = {
    text = "Fast travel to %s?",
    button1 = "Travel",
    button2 = CANCEL,
    OnAccept = function(self, dest)
        Send("GO^" .. dest.type .. "^" .. dest.key)
        if WorldMapFrame:IsShown() then
            ToggleFrame(WorldMapFrame)
        end
    end,
    OnShow = RaiseOnShow,
    OnHide = LowerOnHide,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
}

StaticPopupDialogs["SOLOADV_RESPEC"] = {
    text = "Reset all talents in your active spec?",
    button1 = YES,
    button2 = NO,
    OnAccept = function() Send("RESPEC") end,
    timeout = 0,
    hideOnEscape = true,
}

-------------------------------------------------------------------------------
-- World map pins
-------------------------------------------------------------------------------
local function Pin_OnEnter(self)
    local dest = self.dest
    WorldMapTooltip:SetOwner(self, "ANCHOR_RIGHT")
    WorldMapTooltip:AddLine(dest.name)
    WorldMapTooltip:AddLine(TYPE_LABEL[dest.type], 0.8, 0.8, 0.8)
    if dest.unlocked then
        WorldMapTooltip:AddLine("Click to fast travel", 0.2, 1, 0.2)
    else
        WorldMapTooltip:AddLine("Not discovered yet", 0.6, 0.6, 0.6)
    end
    WorldMapTooltip:Show()
end

local function Pin_OnLeave()
    WorldMapTooltip:Hide()
end

local function Pin_OnClick(self)
    if self.dest.unlocked then
        StaticPopup_Show("SOLOADV_TRAVEL", self.dest.name, nil, self.dest)
    else
        Print(self.dest.name .. " hasn't been discovered yet.")
    end
end

local function GetPin(index)
    local pin = pins[index]
    if not pin then
        pin = CreateFrame("Button", nil, WorldMapButton)
        pin.icon = pin:CreateTexture(nil, "OVERLAY")
        pin.icon:SetAllPoints()
        pin:RegisterForClicks("LeftButtonUp")
        pin:SetScript("OnEnter", Pin_OnEnter)
        pin:SetScript("OnLeave", Pin_OnLeave)
        pin:SetScript("OnClick", Pin_OnClick)
        pins[index] = pin
    end
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 10)
    return pin
end

local function RefreshPins()
    for i = 1, pinCount do
        pins[i]:Hide()
    end
    pinCount = 0

    if not WorldMapFrame:IsShown() then
        return
    end

    local area = SoloAdventurerMapData[GetMapInfo() or ""]
    if not area or (GetCurrentMapDungeonLevel() or 0) > 0 then
        return
    end

    local mapId, left, right, top, bottom = area[1], area[2], area[3], area[4], area[5]
    local continentView = GetCurrentMapZone() == 0
    local width, height = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()

    for _, dest in pairs(destinations) do
        if dest.map == mapId and not (continentView and dest.type == "I") then
            local px = (left - dest.y) / (left - right)
            local py = (top - dest.x) / (top - bottom)
            if px >= 0 and px <= 1 and py >= 0 and py <= 1 then
                pinCount = pinCount + 1
                local pin = GetPin(pinCount)
                local size = SIZES[dest.type]
                pin.dest = dest
                pin:SetWidth(size)
                pin:SetHeight(size)
                pin.icon:SetTexture(ICONS[dest.type])
                pin.icon:SetDesaturated(not dest.unlocked)
                pin:SetAlpha(dest.unlocked and 1 or 0.55)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", px * width, -py * height)
                pin:Show()
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Server messages
-------------------------------------------------------------------------------
local function ParseEntry(text)
    local t, key, map, x, y, unlocked, name = strsplit("^", text, 7)
    if not name then
        return
    end
    return {
        type = t,
        key = tonumber(key),
        map = tonumber(map),
        x = tonumber(x),
        y = tonumber(y),
        unlocked = unlocked == "1",
        name = name,
    }
end

local function OnServerMessage(msg)
    if msg == "BEGIN" then
        incoming = {}
    elseif msg == "END" then
        if incoming then
            destinations = incoming
            incoming = nil
            RefreshPins()
        end
    elseif strsub(msg, 1, 2) == "L~" then
        if not incoming then
            return
        end
        for entry in string.gmatch(strsub(msg, 3), "[^~]+") do
            local dest = ParseEntry(entry)
            if dest then
                incoming[dest.type .. "^" .. dest.key] = dest
            end
        end
    elseif strsub(msg, 1, 4) == "NEW^" then
        local _, t, key = strsplit("^", msg)
        local dest = destinations[t .. "^" .. key]
        if dest then
            dest.unlocked = true
            RefreshPins()
        end
    end
end

-------------------------------------------------------------------------------
-- Talent frame respec button
-------------------------------------------------------------------------------
local function CreateRespecButton()
    if not PlayerTalentFrame or SoloAdventurerRespecButton then
        return
    end
    local button = CreateFrame("Button", "SoloAdventurerRespecButton", PlayerTalentFrame, "UIPanelButtonTemplate")
    button:SetWidth(90)
    button:SetHeight(22)
    button:SetText("Respec")
    button:SetPoint("TOPRIGHT", PlayerTalentFrame, "TOPRIGHT", -40, -44)
    button:SetScript("OnClick", function() StaticPopup_Show("SOLOADV_RESPEC") end)
end

-------------------------------------------------------------------------------
-- Talents from level 1: the stock UI hides the talent button/keybind below level 10.
-------------------------------------------------------------------------------
SHOW_TALENT_LEVEL = 1
if UpdateMicroButtons then
    hooksecurefunc("UpdateMicroButtons", function()
        if TalentMicroButton and UnitLevel("player") < 10 then
            TalentMicroButton:Show()
            TalentMicroButton:Enable()
        end
    end)
end

-------------------------------------------------------------------------------
-- Auto-loot fishing catches (the server hooks the fish automatically)
-------------------------------------------------------------------------------
local function LootFishing()
    if not IsFishingLoot() then
        return
    end
    for slot = GetNumLootItems(), 1, -1 do
        LootSlot(slot)
    end
end

-------------------------------------------------------------------------------
-- Double Jump (rogue passive, hunter passive, druid in Cat Form, a mage drifting down from Updraft): the client
-- sends nothing for a jump pressed in mid-air, so tell the server (prefix "SDJ"). One air jump per jump, one more
-- at levels 20, 40, 60 and 80 (hunters: always one); the server checks the passive and does the jump.
-- Druids also report jumps from the ground ("LEAP"): in Cat Form the server makes them 50% higher and farther.
-- Both carry the movement keys held ("JUMP:1" = holding forward), which set the jump's direction.
-------------------------------------------------------------------------------
local DOUBLE_JUMP_PREFIX = "SDJ"
local DOUBLE_JUMP_ROGUE, DOUBLE_JUMP_DRUID = 200026, 200054
local DOUBLE_JUMP_HUNTER = 200097   -- a single air jump at any level
local CLINGING = "Clinging"         -- hanging from a grappling hook (200098)
local UPDRAFT, GENTLE_DESCENT = 200037, "Gentle Descent"   -- mages: one air jump while drifting down from Updraft
local airborne = false       -- as of the last frame, so the first jump's own key press doesn't count
local airJumps = 0          -- air jumps since leaving the ground
local lastAirJump = 0
local AIR_JUMP_GAP = 0.35    -- seconds; the server refuses air jumps closer together

local function MaxAirJumps()
    if IsSpellKnown(DOUBLE_JUMP_HUNTER) then
        return 1
    end
    return 1 + math.min(4, math.floor(UnitLevel("player") / 20))
end

-- Whether to ask at all; the server checks the rest (druids must be in Cat Form).
local function CanDoubleJump()
    return IsSpellKnown(DOUBLE_JUMP_ROGUE) or IsSpellKnown(DOUBLE_JUMP_DRUID) or IsSpellKnown(DOUBLE_JUMP_HUNTER)
        or (IsSpellKnown(UPDRAFT) and UnitBuff("player", GENTLE_DESCENT) ~= nil)
end

-- Movement keys held right now. The server's view of them goes stale in mid-air (a knockback, like the Cat Form
-- jump boost, clears them), so each jump message carries them: forward 1, back 2, strafe left 4, strafe right 8.
local held = { forward = false, back = false, left = false, right = false, steer = false, autorun = false }
local mouseCamera, mouseTurn = false, false

local function Track(func, key, value)
    hooksecurefunc(func, function() held[key] = value end)
end
Track("MoveForwardStart", "forward", true)
Track("MoveForwardStop", "forward", false)
Track("MoveBackwardStart", "back", true)
Track("MoveBackwardStop", "back", false)
Track("StrafeLeftStart", "left", true)
Track("StrafeLeftStop", "left", false)
Track("StrafeRightStart", "right", true)
Track("StrafeRightStop", "right", false)
Track("MoveAndSteerStart", "steer", true)
Track("MoveAndSteerStop", "steer", false)
hooksecurefunc("ToggleAutoRun", function() held.autorun = not held.autorun end)
hooksecurefunc("MoveForwardStart", function() held.autorun = false end)
hooksecurefunc("MoveBackwardStart", function() held.autorun = false end)
-- Both mouse buttons held moves forward too.
hooksecurefunc("CameraOrSelectOrMoveStart", function() mouseCamera = true end)
hooksecurefunc("CameraOrSelectOrMoveStop", function() mouseCamera = false end)
hooksecurefunc("TurnOrActionStart", function() mouseTurn = true end)
hooksecurefunc("TurnOrActionStop", function() mouseTurn = false end)

local function MovementMask()
    local forward = held.forward or held.steer or held.autorun or (mouseCamera and mouseTurn)
    return (forward and 1 or 0) + (held.back and 2 or 0) + (held.left and 4 or 0) + (held.right and 8 or 0)
end

hooksecurefunc("JumpOrAscendStart", function()
    -- hanging from a grappling hook (Clinging): jump lets go, hopping the way the keys point
    -- (the client lists a root as a debuff)
    if UnitBuff("player", CLINGING) or UnitDebuff("player", CLINGING) then
        SendAddonMessage(DOUBLE_JUMP_PREFIX, "WALL:" .. MovementMask(), "WHISPER", PlayerName())
        return
    end
    if IsFlying() or IsSwimming() then
        return
    end
    if airborne then
        if airJumps < MaxAirJumps() and GetTime() - lastAirJump >= AIR_JUMP_GAP and CanDoubleJump() then
            airJumps = airJumps + 1
            lastAirJump = GetTime()
            SendAddonMessage(DOUBLE_JUMP_PREFIX, "JUMP:" .. MovementMask(), "WHISPER", PlayerName())
        end
    elseif IsSpellKnown(DOUBLE_JUMP_DRUID) then
        -- a jump from the ground: in Cat Form the server makes it 50% higher and farther
        SendAddonMessage(DOUBLE_JUMP_PREFIX, "LEAP:" .. MovementMask(), "WHISPER", PlayerName())
    end
end)

local warnedNoIsFalling = false

local function UpdateAirborne()
    if not IsFalling then
        if not warnedNoIsFalling then
            warnedNoIsFalling = true
            Print("Double Jump can't work: this game client has no IsFalling().")
        end
        return
    end
    airborne = IsFalling()
    if not airborne then
        airJumps = 0
    end
end

-------------------------------------------------------------------------------
-- Sacrifice Eye: while you control the Eye of Kilrogg, a button beside the possession bar dismisses the eye and
-- teleports you to it (the server does it: addon message "EYE"). The eye's own pet bar carries the same spell, but the
-- game does not always show that bar for a possessed creature.
-------------------------------------------------------------------------------
local EYE_OF_KILROGG = 126
local sacrificeButton

local function ControllingEye()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then
            return false
        end
        if spellId == EYE_OF_KILROGG then
            return true
        end
    end
    return false
end

local function CreateSacrificeEyeButton()
    local button = CreateFrame("Button", "SoloAdvSacrificeEyeButton", UIParent)
    button:SetWidth(40)
    button:SetHeight(40)
    button:SetFrameStrata("HIGH")
    if PossessButton2 then
        button:SetPoint("LEFT", PossessButton2, "RIGHT", 12, 0)
    else
        button:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 200)
    end

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(GetSpellTexture(EYE_OF_KILROGG) or "Interface\\Icons\\Spell_Shadow_EvilEye")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", button, "BOTTOM", 0, -2)
    label:SetText("Sacrifice")

    button:SetScript("OnClick", function()
        SendAddonMessage(DOUBLE_JUMP_PREFIX, "EYE", "WHISPER", PlayerName())
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sacrifice Eye", 1, 1, 1)
        GameTooltip:AddLine("Dismiss the Eye of Kilrogg and teleport to where it is.", nil, nil, nil, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()
    return button
end

local function RefreshSacrificeEye()
    sacrificeButton = sacrificeButton or CreateSacrificeEyeButton()
    if ControllingEye() then
        sacrificeButton:Show()
    else
        sacrificeButton:Hide()
    end
end

local eyeFrame = CreateFrame("Frame")
eyeFrame:RegisterEvent("UNIT_AURA")
eyeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eyeFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" or unit == "player" then
        RefreshSacrificeEye()
    end
end)
local eyeElapsed = 0
eyeFrame:SetScript("OnUpdate", function(_, elapsed)   -- a safety net in case the aura event is missed
    eyeElapsed = eyeElapsed + elapsed
    if eyeElapsed >= 0.5 then
        eyeElapsed = 0
        RefreshSacrificeEye()
    end
end)

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local requestIn = nil

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("WORLD_MAP_UPDATE")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LOOT_OPENED")

frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "CHAT_MSG_ADDON" then
        if arg1 == PREFIX and arg4 == PlayerName() then
            OnServerMessage(arg2)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        requestIn = 2
    elseif event == "WORLD_MAP_UPDATE" then
        RefreshPins()
    elseif event == "LOOT_OPENED" then
        LootFishing()
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_TalentUI" then
        CreateRespecButton()
    end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    UpdateAirborne()
    if requestIn then
        requestIn = requestIn - elapsed
        if requestIn <= 0 then
            requestIn = nil
            Send("LIST")
        end
    end
end)

WorldMapFrame:HookScript("OnShow", RefreshPins)
WorldMapButton:HookScript("OnSizeChanged", RefreshPins)
CreateRespecButton()

SLASH_SOLOADVENTURER1 = "/solo"
SlashCmdList["SOLOADVENTURER"] = function(cmd)
    cmd = strlower(strtrim(cmd or ""))
    if cmd == "respec" then
        StaticPopup_Show("SOLOADV_RESPEC")
    elseif cmd == "refresh" then
        Send("LIST")
        Print("Refreshing fast travel locations.")
    else
        local unlocked, total = 0, 0
        for _, dest in pairs(destinations) do
            total = total + 1
            if dest.unlocked then
                unlocked = unlocked + 1
            end
        end
        Print(string.format("%d of %d fast travel locations unlocked. Open your map and click a marker to travel.", unlocked, total))
        Print("/solo respec - reset talents, /solo refresh - reload locations")
    end
end
