local SC = gMats
SC.UI = SC.UI or {}

SC.UI.ItemSearch = {}
local IS = SC.UI.ItemSearch

local MAX_RESULTS = 50
local DEBOUNCE_TIME = 0.3
local ROW_HEIGHT = 18
local VISIBLE_ROWS = 12

function IS:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "gMatsItemSearchFrame", UIParent)
    f:SetWidth(320)
    f:SetHeight(310)
    f:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0, 0, 0, 1.0)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetText("Search Items")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetTextColor(0.4, 0.8, 1.0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Search box
    local searchBox = CreateFrame("EditBox", "gMatsSearchBox", f, "InputBoxTemplate")
    searchBox:SetWidth(260)
    searchBox:SetHeight(24)
    searchBox:SetPoint("TOP", title, "BOTTOM", 0, -8)
    searchBox:SetAutoFocus(true)
    searchBox:SetMaxLetters(50)

    -- Debounce timer
    local debounceTimer = 0
    local pendingSearch = false

    searchBox:SetScript("OnTextChanged", function()
        pendingSearch = true
        debounceTimer = 0
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)

    searchBox:SetScript("OnEnterPressed", function(self)
        -- Select first result if available
        if IS.results and #IS.results > 0 then
            IS:SelectItem(IS.results[1])
        end
    end)

    -- Results scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "gMatsItemSearchScroll", f, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -4, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 12)

    -- Result rows
    self.rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, f)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 4, -((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", scrollFrame, "RIGHT", -4, 0)

        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(16)
        icon:SetHeight(16)
        icon:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.icon = icon

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        row.text = text

        row:SetScript("OnClick", function()
            if row.itemData then
                IS:SelectItem(row.itemData)
            end
        end)

        row:SetScript("OnEnter", function(self)
            if self.itemData then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.itemData.itemID)
                GameTooltip:Show()
            end
        end)

        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:Hide()
        self.rows[i] = row
    end

    -- OnUpdate for debounce
    f:SetScript("OnUpdate", function(_, elapsed)
        if pendingSearch then
            debounceTimer = debounceTimer + elapsed
            if debounceTimer >= DEBOUNCE_TIME then
                pendingSearch = false
                debounceTimer = 0
                IS:DoSearch(searchBox:GetText())
            end
        end
    end)

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            IS:UpdateRows()
        end)
    end)

    self.frame = f
    self.searchBox = searchBox
    self.scrollFrame = scrollFrame
    self.results = {}
    self.callback = nil
end

function IS:DoSearch(query)
    self.results = {}
    if not query or query == "" then
        self:UpdateRows()
        return
    end

    query = query:lower()
    local count = 0
    for itemID, itemName in pairs(gMatsItemDB) do
        if string.find(itemName:lower(), query, 1, true) then
            self.results[#self.results + 1] = {
                itemID = itemID,
                itemName = itemName,
            }
            count = count + 1
            if count >= MAX_RESULTS then break end
        end
    end

    -- Sort alphabetically
    table.sort(self.results, function(a, b)
        return a.itemName < b.itemName
    end)

    self:UpdateRows()
end

function IS:UpdateRows()
    local offset = FauxScrollFrame_GetOffset(self.scrollFrame)
    local numResults = #self.results

    for i = 1, VISIBLE_ROWS do
        local idx = offset + i
        local row = self.rows[i]
        if idx <= numResults then
            local item = self.results[idx]
            row.text:SetText(item.itemName .. " (" .. item.itemID .. ")")
            row.itemData = item
            -- Try to show item icon
            local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(item.itemID)
            if texture then
                row.icon:SetTexture(texture)
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            row:Show()
        else
            row:Hide()
            row.itemData = nil
        end
    end

    FauxScrollFrame_Update(self.scrollFrame, numResults, VISIBLE_ROWS, ROW_HEIGHT)
end

function IS:SelectItem(itemData)
    if self.callback then
        self.callback(itemData.itemID, itemData.itemName)
    end
    self.frame:Hide()
end

-- Show the search popup with a callback for when an item is selected
function IS:Show(callback)
    if not self.frame then
        self:Create()
    end
    self.callback = callback
    self.results = {}
    self.searchBox:SetText("")
    self:UpdateRows()
    self.frame:Show()
    self.frame:Raise()
    self.searchBox:SetFocus()
end

function IS:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
