local SC = gMats
SC.UI = SC.UI or {}

SC.UI.MinimapButton = {}
local MB = SC.UI.MinimapButton

function MB:Create()
    local button = CreateFrame("Button", "gMatsMinimapButton", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetMovable(true)

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetWidth(56)
    overlay:SetHeight(56)
    overlay:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    -- Apply circular mask for minimap
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    self.button = button
    self.isDragging = false

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" then
            SC:ToggleMainWindow()
        end
    end)

    button:SetScript("OnDragStart", function()
        MB.isDragging = true
    end)

    button:SetScript("OnDragStop", function()
        MB.isDragging = false
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        xpos = xpos / scale
        ypos = ypos / scale
        local cx, cy = Minimap:GetCenter()
        local angle = math.atan2(ypos - cy, xpos - cx)
        local degrees = math.deg(angle)
        gMatsDB.settings.minimapPos = degrees
        MB:UpdatePosition()
    end)

    button:SetScript("OnUpdate", function()
        if MB.isDragging then
            local xpos, ypos = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            xpos = xpos / scale
            ypos = ypos / scale
            local cx, cy = Minimap:GetCenter()
            local angle = math.atan2(ypos - cy, xpos - cx)
            local degrees = math.deg(angle)
            gMatsDB.settings.minimapPos = degrees
            MB:UpdatePosition()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("gMats", 0.2, 0.8, 1.0)
        GameTooltip:AddLine("Guild Bounty Board", 1, 1, 1)
        local count = SC.DataModel:CountActive()
        GameTooltip:AddLine(count .. " active request(s)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Left-click to open", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:UpdatePosition()
end

function MB:UpdatePosition()
    local angle = math.rad(gMatsDB.settings.minimapPos or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
