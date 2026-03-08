local SC = gMats
SC.UI = SC.UI or {}

SC.UI.MainWindow = {}
local MW = SC.UI.MainWindow

local WINDOW_WIDTH = 500
local WINDOW_HEIGHT = 500

function MW:Create()
    if self.frame then return end

    -- Main frame
    local f = CreateFrame("Frame", "gMatsMainFrame", UIParent)
    f:SetWidth(WINDOW_WIDTH)
    f:SetHeight(WINDOW_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Background
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0, 0, 0, 1.0)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(40)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    titleBar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    })
    titleBar:SetBackdropColor(0.1, 0.1, 0.3, 1.0)

    -- Title icon
    local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
    titleIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
    titleIcon:SetWidth(24)
    titleIcon:SetHeight(24)
    titleIcon:SetPoint("LEFT", titleBar, "LEFT", 8, 0)

    -- Title text
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetText("gMats - Guild Bounty Board")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    titleText:SetTextColor(0.4, 0.8, 1.0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 4, 4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Tab system
    self.activeTab = "materials"
    local tabY = -52

    local function CreateTab(name, label, xOff)
        local tab = CreateFrame("Button", "gMatsTab_" .. name, f)
        tab:SetWidth(120)
        tab:SetHeight(28)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", xOff, tabY)

        tab:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })

        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetText(label)
        text:SetPoint("CENTER")
        tab.text = text

        tab:SetScript("OnClick", function()
            MW:SetTab(name)
        end)

        return tab
    end

    self.tabs = {}
    self.tabs.materials = CreateTab("materials", "Materials", 16)
    self.tabs.crafting = CreateTab("crafting", "Crafting", 140)
    self.tabs.myposts = CreateTab("myposts", "My Posts", 264)

    -- Content area
    local content = CreateFrame("Frame", "gMatsContentFrame", f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 12, tabY - 32)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 42)
    self.contentFrame = content

    -- Post button
    local postBtn = CreateFrame("Button", "gMatsPostButton", f, "UIPanelButtonTemplate")
    postBtn:SetWidth(160)
    postBtn:SetHeight(28)
    postBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    postBtn:SetText("+ Post New Request")
    postBtn:SetScript("OnClick", function()
        if SC.UI.PostRequestForm then
            SC.UI.PostRequestForm:Show()
        end
    end)

    -- ESC to close
    tinsert(UISpecialFrames, "gMatsMainFrame")

    self.frame = f
    self:SetTab("materials")
end

function MW:SetTab(tabName)
    self.activeTab = tabName
    -- Update tab appearance
    for name, tab in pairs(self.tabs) do
        if name == tabName then
            tab:SetBackdropColor(0.2, 0.4, 0.8, 1.0)
            tab.text:SetTextColor(1, 1, 1)
        else
            tab:SetBackdropColor(0.15, 0.15, 0.15, 1.0)
            tab.text:SetTextColor(0.6, 0.6, 0.6)
        end
    end
    -- Refresh browse board
    if SC.UI.BrowseBoard then
        SC.UI.BrowseBoard:Refresh()
    end
end

function MW:GetActiveTab()
    return self.activeTab
end

function MW:Show()
    if not self.frame then
        self:Create()
    end
    self.frame:Show()
    if SC.UI.BrowseBoard then
        SC.UI.BrowseBoard:Refresh()
    end
end

function MW:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MW:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
