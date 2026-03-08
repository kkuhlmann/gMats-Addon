local SC = gMats

SC.Tooltips = {}
local TT = SC.Tooltips

-- Previous bag snapshot for diff-based detection
local prevBags = {}

function TT:Init()
    self:HookTooltip()
    self:RegisterLootEvent()
    self:RegisterBagScan()
    self:SnapshotBags()
end

-- ============ TOOLTIP HOOK ============

function TT:HookTooltip()
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        if not gMatsDB or not gMatsDB.settings or not gMatsDB.settings.tooltipsEnabled then
            return
        end

        local _, link = tooltip:GetItem()
        if not link then return end

        local itemID = SC.Util.GetItemID(link)
        if not itemID then return end

        local entries = SC.DataModel:LookupItem(itemID)
        if not entries or #entries == 0 then return end

        tooltip:AddLine(" ")
        tooltip:AddLine("gMats - Guild Needs:", 0.2, 0.8, 1.0)
        for _, entry in ipairs(entries) do
            local label
            if entry.requestType == "craft" then
                label = entry.poster .. " needs " .. entry.count .. " (crafting)"
            else
                label = entry.poster .. " needs " .. entry.count
            end
            tooltip:AddLine("  " .. label, 0.2, 1.0, 0.2)
        end
        tooltip:Show()
    end)
end

-- ============ LOOT ALERT ============

function TT:RegisterLootEvent()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:SetScript("OnEvent", function(_, event, msg)
        if not gMatsDB or not gMatsDB.settings or not gMatsDB.settings.alertsEnabled then
            return
        end
        -- Match self-loot pattern: "You receive loot: [Item Link]xCount." or "You receive loot: [Item Link]."
        local link = msg:match("You receive loot: (|c.-|h|r)")
        if not link then
            -- Try the LOOT_ITEM_SELF pattern
            link = msg:match("You receive item: (|c.-|h|r)")
        end
        if not link then return end

        local itemID, itemName = SC.Util.ParseItemLink(link)
        if not itemID then return end

        local entries = SC.DataModel:LookupItem(itemID)
        if not entries or #entries == 0 then return end

        for _, entry in ipairs(entries) do
            SC:Print("You just looted [" .. (itemName or "item") .. "] -- "
                .. entry.poster .. " needs " .. entry.count .. "!", 1.0, 0.8, 0.2)
        end
    end)
end

-- ============ BAG SCAN FALLBACK ============

function TT:RegisterBagScan()
    local frame = CreateFrame("Frame")
    local timer = 0
    local pending = false

    frame:RegisterEvent("BAG_UPDATE")
    frame:SetScript("OnEvent", function()
        pending = true
        timer = 0
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        if not pending then return end
        timer = timer + elapsed
        if timer < 0.5 then return end
        pending = false
        timer = 0
        TT:DiffBags()
    end)
end

function TT:SnapshotBags()
    wipe(prevBags)
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemID = SC.Util.GetItemID(link)
                if itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    local key = itemID
                    prevBags[key] = (prevBags[key] or 0) + (count or 1)
                end
            end
        end
    end
end

function TT:DiffBags()
    if not gMatsDB or not gMatsDB.settings or not gMatsDB.settings.alertsEnabled then
        self:SnapshotBags()
        return
    end

    local current = {}
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemID = SC.Util.GetItemID(link)
                if itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    current[itemID] = (current[itemID] or 0) + (count or 1)
                end
            end
        end
    end

    -- Find items that increased
    for itemID, newCount in pairs(current) do
        local oldCount = prevBags[itemID] or 0
        if newCount > oldCount then
            local entries = SC.DataModel:LookupItem(itemID)
            if entries and #entries > 0 then
                local name = gMatsItemDB[itemID] or ("item:" .. itemID)
                for _, entry in ipairs(entries) do
                    SC:Print("You received [" .. name .. "] -- "
                        .. entry.poster .. " needs " .. entry.count .. "!", 1.0, 0.8, 0.2)
                end
            end
        end
    end

    prevBags = current
end
