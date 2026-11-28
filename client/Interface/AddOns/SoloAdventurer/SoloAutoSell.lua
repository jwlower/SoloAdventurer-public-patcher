-- Solo Adventurer: a "Sell Junk" button in the vendor window that sells every grey (junk) item in your bags.
-- Nothing is sold automatically. The button sits at the top right of the vendor window on the Merchant tab (it is
-- hidden on the Buyback tab), shows how many junk items you carry and is greyed out when there are none. Hover it
-- for their total vendor value.
--   /junk   sells your junk at the open vendor, same as clicking the button
-- The bag slot already tells us an item's quality, so only grey items are priced with GetItemInfo: a bag full of
-- gear never triggers item queries.

SoloAdventurerSettings = SoloAdventurerSettings or {}

local function Money(c)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    if GetCoinText then return GetCoinText(c, " ") end
    return c .. " copper"
end

-- Counts the sellable junk (grey, vendor price above zero, not locked) and, when sell is true, sells it.
-- Returns the number of stacks and their total vendor value in copper.
local function ScanJunk(sell)
    local total, count = 0, 0
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local _, itemCount, locked, quality = GetContainerItemInfo(bag, slot)
            if quality == 0 and not locked then
                local link = GetContainerItemLink(bag, slot)
                local price = link and select(11, GetItemInfo(link))
                if price and price > 0 then
                    total = total + price * (itemCount or 1)
                    count = count + 1
                    if sell then UseContainerItem(bag, slot) end
                end
            end
        end
    end
    return count, total
end

local function SellJunk()
    local count, total = ScanJunk(true)
    if count > 0 then
        print(("Sold %d junk item%s for %s."):format(count, count == 1 and "" or "s", Money(total)))
    else
        print("No junk to sell.")
    end
end

local button = CreateFrame("Button", "SoloSellJunkButton", MerchantFrame, "UIPanelButtonTemplate")
button:SetHeight(22)
button:SetWidth(84)
button:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -48, -46)   -- the free band between the title and the first row
button:SetText("Sell Junk")

local junkCount, junkTotal = 0, 0
local dirty, waited = true, 0

local function ShowTooltip()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("Sell Junk")
    if junkCount > 0 then
        GameTooltip:AddLine(("Sells %d grey item%s for %s."):format(junkCount, junkCount == 1 and "" or "s", Money(junkTotal)), 1, 1, 1)
    else
        GameTooltip:AddLine("You have no grey items to sell.", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function Refresh()
    dirty = false
    if MerchantFrame.selectedTab ~= 1 then
        button:Hide()
        return
    end
    button:Show()
    junkCount, junkTotal = ScanJunk(false)
    if junkCount > 0 then
        button:SetText(("Sell Junk (%d)"):format(junkCount))
        button:Enable()
    else
        button:SetText("Sell Junk")
        button:Disable()
    end
    button:SetWidth(math.max(84, button:GetFontString():GetStringWidth() + 28))
    if GameTooltip:IsOwned(button) then ShowTooltip() end
end

button:SetScript("OnClick", function()
    SellJunk()
    dirty = true
end)
button:SetScript("OnEnter", ShowTooltip)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Bag changes (each sale fires one) only mark the count stale; it is recounted at most four times a second.
button:SetScript("OnUpdate", function(_, elapsed)
    waited = waited + elapsed
    if dirty and waited >= 0.25 then
        waited = 0
        Refresh()
    end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function()
    if MerchantFrame:IsShown() then dirty = true end
end)

-- Runs when the vendor window opens, changes tab or page, so the button follows the Merchant / Buyback tab.
hooksecurefunc("MerchantFrame_Update", Refresh)

SLASH_SOLOJUNK1 = "/junk"
SlashCmdList["SOLOJUNK"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "on" or msg == "off" then
        print("Junk is no longer sold automatically. Use the Sell Junk button in the vendor window, or /junk.")
    elseif MerchantFrame:IsShown() and MerchantFrame.selectedTab == 1 then
        SellJunk()
    else
        print("Open a vendor first.")
    end
end
