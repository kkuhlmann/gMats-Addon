local SC = gMats

SC.BagHighlight = {}
local BH = SC.BagHighlight

-- Cache of highlight textures keyed by button name
local highlightCache = {}

-- Debounce state for BAG_UPDATE
local bagUpdatePending = false
local bagUpdateTimer = 0

-- Bank / Guild Bank state
local bankOpen = false
local guildBankOpen = false
local bankUpdatePending = false
local bankUpdateTimer = 0
local guildBankUpdatePending = false
local guildBankUpdateTimer = 0

-- ============ HIGHLIGHT TEXTURES ============

-- Create 4 edge textures forming a purple border around a button
local function CreateHighlight(button)
    local name = button:GetName()
    if highlightCache[name] then return highlightCache[name] end

    local r, g, b = 0.6, 0.2, 0.9
    local thickness = 2

    local top = button:CreateTexture(nil, "OVERLAY")
    top:SetTexture(r, g, b, 1)
    top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    top:SetHeight(thickness)

    local bottom = button:CreateTexture(nil, "OVERLAY")
    bottom:SetTexture(r, g, b, 1)
    bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(thickness)

    local left = button:CreateTexture(nil, "OVERLAY")
    left:SetTexture(r, g, b, 1)
    left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    left:SetWidth(thickness)

    local right = button:CreateTexture(nil, "OVERLAY")
    right:SetTexture(r, g, b, 1)
    right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(thickness)

    local textures = { top, bottom, left, right }
    highlightCache[name] = textures
    return textures
end

local function ShowHighlight(button)
    local textures = CreateHighlight(button)
    for _, tex in ipairs(textures) do
        tex:Show()
    end
end

local function HideHighlight(button)
    local name = button:GetName()
    local textures = highlightCache[name]
    if textures then
        for _, tex in ipairs(textures) do
            tex:Hide()
        end
    end
end

-- ============ CORE LOGIC ============

function BH:IsWanted(itemID)
    local entries = SC.DataModel:LookupItem(itemID)
    return entries and #entries > 0
end

function BH:UpdateHighlightsForContainer(containerFrame)
    if not gMatsDB or not gMatsDB.settings or not gMatsDB.settings.bagHighlightsEnabled then
        return
    end
    if not containerFrame or not containerFrame:IsShown() then return end

    local bagID = containerFrame:GetID()
    local slots = GetContainerNumSlots(bagID)
    local frameName = containerFrame:GetName()

    for i = 1, slots do
        local button = _G[frameName .. "Item" .. i]
        if button then
            local bagSlot = button:GetID()
            local link = GetContainerItemLink(bagID, bagSlot)
            if link then
                local itemID = SC.Util.GetItemID(link)
                if itemID and self:IsWanted(itemID) then
                    ShowHighlight(button)
                else
                    HideHighlight(button)
                end
            else
                HideHighlight(button)
            end
        end
    end
end

function BH:UpdateAllVisibleBags()
    if not gMatsDB or not gMatsDB.settings or not gMatsDB.settings.bagHighlightsEnabled then
        return
    end
    for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then
            self:UpdateHighlightsForContainer(frame)
        end
    end
end

-- ============ BANK / GUILD BANK ============

function BH:UpdateBankMainSlots()
    if not bankOpen then return end
    if not gMatsDB or not gMatsDB.settings or not gMatsDB.settings.bagHighlightsEnabled then return end
    if not BankFrame or not BankFrame:IsShown() then return end

    for i = 1, 28 do
        local button = _G["BankFrameItem" .. i]
        if button then
            local link = GetContainerItemLink(-1, i)
            if link then
                local itemID = SC.Util.GetItemID(link)
                if itemID and self:IsWanted(itemID) then
                    ShowHighlight(button)
                else
                    HideHighlight(button)
                end
            else
                HideHighlight(button)
            end
        end
    end
end

function BH:UpdateGuildBankSlots()
    if not guildBankOpen then return end
    if not gMatsDB or not gMatsDB.settings or not gMatsDB.settings.bagHighlightsEnabled then return end
    if not GuildBankFrame or not GuildBankFrame:IsShown() then return end

    local tab = GetCurrentGuildBankTab()
    for col = 1, 7 do
        for row = 1, 14 do
            local button = _G["GuildBankColumn" .. col .. "Button" .. row]
            if button then
                local slot = (col - 1) * 14 + row
                local link = GetGuildBankItemLink(tab, slot)
                if link then
                    local itemID = SC.Util.GetItemID(link)
                    if itemID and self:IsWanted(itemID) then
                        ShowHighlight(button)
                    else
                        HideHighlight(button)
                    end
                else
                    HideHighlight(button)
                end
            end
        end
    end
end

function BH:ClearBankHighlights()
    for i = 1, 28 do
        local button = _G["BankFrameItem" .. i]
        if button then HideHighlight(button) end
    end
end

function BH:ClearGuildBankHighlights()
    for col = 1, 7 do
        for row = 1, 14 do
            local button = _G["GuildBankColumn" .. col .. "Button" .. row]
            if button then HideHighlight(button) end
        end
    end
end

function BH:UpdateAllVisible()
    self:UpdateAllVisibleBags()
    self:UpdateBankMainSlots()
    self:UpdateGuildBankSlots()
end

function BH:ClearAllHighlights()
    for _, textures in pairs(highlightCache) do
        for _, tex in ipairs(textures) do
            tex:Hide()
        end
    end
end

-- ============ INIT ============

function BH:Init()
    -- Post-hook ContainerFrame_Update to apply highlights after Blizzard updates bag frames
    hooksecurefunc("ContainerFrame_Update", function(frame)
        BH:UpdateHighlightsForContainer(frame)
    end)

    -- Events with debounce
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_CLOSED")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("BANKFRAME_CLOSED")
    eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
    eventFrame:RegisterEvent("GUILDBANKFRAME_CLOSED")
    eventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "BAG_UPDATE" then
            bagUpdatePending = true
            bagUpdateTimer = 0
        elseif event == "BAG_CLOSED" then
            for i = 1, NUM_CONTAINER_FRAMES do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame:GetID() == arg1 then
                    local frameName = frame:GetName()
                    local slots = GetContainerNumSlots(arg1)
                    for slot = 1, slots do
                        local button = _G[frameName .. "Item" .. slot]
                        if button then
                            HideHighlight(button)
                        end
                    end
                end
            end
        elseif event == "BANKFRAME_OPENED" then
            bankOpen = true
            bankUpdatePending = true
            bankUpdateTimer = 0
        elseif event == "BANKFRAME_CLOSED" then
            bankOpen = false
            BH:ClearBankHighlights()
        elseif event == "PLAYERBANKSLOTS_CHANGED" then
            if bankOpen then
                bankUpdatePending = true
                bankUpdateTimer = 0
            end
        elseif event == "GUILDBANKFRAME_OPENED" then
            guildBankOpen = true
            guildBankUpdatePending = true
            guildBankUpdateTimer = 0
        elseif event == "GUILDBANKFRAME_CLOSED" then
            guildBankOpen = false
            BH:ClearGuildBankHighlights()
        elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
            if guildBankOpen then
                guildBankUpdatePending = true
                guildBankUpdateTimer = 0
            end
        end
    end)

    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        if bagUpdatePending then
            bagUpdateTimer = bagUpdateTimer + elapsed
            if bagUpdateTimer >= 0.1 then
                bagUpdatePending = false
                bagUpdateTimer = 0
                BH:UpdateAllVisibleBags()
            end
        end
        if bankUpdatePending then
            bankUpdateTimer = bankUpdateTimer + elapsed
            if bankUpdateTimer >= 0.1 then
                bankUpdatePending = false
                bankUpdateTimer = 0
                BH:UpdateBankMainSlots()
            end
        end
        if guildBankUpdatePending then
            guildBankUpdateTimer = guildBankUpdateTimer + elapsed
            if guildBankUpdateTimer >= 0.1 then
                guildBankUpdatePending = false
                guildBankUpdateTimer = 0
                BH:UpdateGuildBankSlots()
            end
        end
    end)

    -- Hook Blizzard bank/guild bank update functions
    if BankFrame_UpdateSlots then
        hooksecurefunc("BankFrame_UpdateSlots", function()
            BH:UpdateBankMainSlots()
        end)
    end
    if GuildBankFrame_Update then
        hooksecurefunc("GuildBankFrame_Update", function()
            BH:UpdateGuildBankSlots()
        end)
    end
end
