-- Solo Adventurer: sell all grey (junk) items when a vendor window opens.
--   /junk on|off   turn automatic selling on or off (default on)
--   /junk now      sell the junk at the open vendor right now
--   /junk          shows the current setting
-- Hold Shift while opening the vendor to skip the automatic sale once.

SoloAdventurerSettings = SoloAdventurerSettings or {}

local function Money(c)
    return GetCoinTextureString and GetCoinTextureString(c) or (c .. " copper")
end

local function SellJunk(quiet)
    local total, count = 0, 0
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, itemCount, locked = GetContainerItemInfo(bag, slot)
                local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
                if quality == 0 and price and price > 0 and not locked then
                    total = total + price * (itemCount or 1)
                    count = count + 1
                    UseContainerItem(bag, slot)
                end
            end
        end
    end
    if count > 0 then
        print(("Sold %d junk item%s for %s."):format(count, count == 1 and "" or "s", Money(total)))
    elseif not quiet then
        print("No junk to sell.")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function()
    if SoloAdventurerSettings.autoSellJunk ~= false and not IsShiftKeyDown() then
        SellJunk(true)
    end
end)

SLASH_SOLOJUNK1 = "/junk"
SlashCmdList["SOLOJUNK"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "on" then
        SoloAdventurerSettings.autoSellJunk = true
    elseif msg == "off" then
        SoloAdventurerSettings.autoSellJunk = false
    elseif msg == "now" then
        if MerchantFrame and MerchantFrame:IsShown() then
            SellJunk(false)
        else
            print("Open a vendor first.")
        end
        return
    end
    print("Auto-sell junk at vendors: " .. (SoloAdventurerSettings.autoSellJunk ~= false and "on" or "off")
        .. " (/junk on|off|now, hold Shift to skip once)")
end
