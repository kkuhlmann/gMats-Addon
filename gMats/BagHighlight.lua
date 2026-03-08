local SC = gMats

SC.BagHighlight = {}
local BH = SC.BagHighlight

-- Cache of highlight textures keyed by button name
local highlightCache = {}

-- Debounce state for BAG_UPDATE
local bagUpdatePending = false
local bagUpdateTimer = 0

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

function BH:IsWantedByOthers(itemID)
    local entries = SC.DataModel:LookupItem(itemID)
    if not entries or #entries == 0 then return false end
    local myName = SC.Util.PlayerName()
    for _, entry in ipairs(entries) do
        if entry.poster ~= myName then
            return true
        end
    end
    return false
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
                if itemID and self:IsWantedByOthers(itemID) then
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

    -- BAG_UPDATE with debounce to catch item count changes
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_CLOSED")

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "BAG_UPDATE" then
            bagUpdatePending = true
            bagUpdateTimer = 0
        elseif event == "BAG_CLOSED" then
            -- Clear highlights for the closed bag
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
        end
    end)

    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        if not bagUpdatePending then return end
        bagUpdateTimer = bagUpdateTimer + elapsed
        if bagUpdateTimer < 0.1 then return end
        bagUpdatePending = false
        bagUpdateTimer = 0
        BH:UpdateAllVisibleBags()
    end)
end
