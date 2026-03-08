local SC = gMats
SC.UI = SC.UI or {}

SC.UI.BrowseBoard = {}
local BB = SC.UI.BrowseBoard

local ROW_HEIGHT = 70
local VISIBLE_ROWS = 5

function BB:Create()
    if self.created then return end

    local parent = SC.UI.MainWindow.contentFrame
    if not parent then return end

    -- Filter box
    local filterBox = CreateFrame("EditBox", "gMatsFilterBox", parent, "InputBoxTemplate")
    filterBox:SetWidth(200)
    filterBox:SetHeight(22)
    filterBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 50, -4)
    filterBox:SetAutoFocus(false)
    filterBox:SetMaxLetters(50)

    local filterLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetText("Filter:")
    filterLabel:SetPoint("RIGHT", filterBox, "LEFT", -4, 0)

    filterBox:SetScript("OnTextChanged", function()
        BB:Refresh()
    end)

    filterBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    self.filterBox = filterBox

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "gMatsBrowseScroll", parent, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 4)

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
            BB:UpdateRows()
        end)
    end)

    self.scrollFrame = scrollFrame

    -- Create row frames
    self.rows = {}
    for i = 1, VISIBLE_ROWS do
        self:CreateRow(i)
    end

    -- Empty state text
    local emptyText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyText:SetPoint("CENTER", parent, "CENTER", 0, -20)
    emptyText:SetText("No requests found.\nPost a new request to get started!")
    emptyText:SetTextColor(0.5, 0.5, 0.5)
    emptyText:Hide()
    self.emptyText = emptyText

    self.created = true
    self.cachedData = {}
end

function BB:CreateRow(index)
    local parent = SC.UI.MainWindow.contentFrame
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", self.scrollFrame, "RIGHT", 0, 0)

    row:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    row:SetBackdropColor(0.1, 0.1, 0.1, 1.0)

    -- Item icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(28)
    icon:SetHeight(28)
    icon:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)
    row.icon = icon

    -- Title line
    local titleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 2)
    titleText:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    titleText:SetJustifyH("LEFT")
    row.titleText = titleText

    -- Detail line (poster + time)
    local detailText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)
    detailText:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    detailText:SetJustifyH("LEFT")
    row.detailText = detailText

    -- Extra info line (note or mats)
    local extraText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    extraText:SetPoint("TOPLEFT", detailText, "BOTTOMLEFT", 0, -1)
    extraText:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    extraText:SetJustifyH("LEFT")
    extraText:SetTextColor(0.7, 0.7, 0.7)
    row.extraText = extraText

    -- Type badge
    local typeBadge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeBadge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)
    row.typeBadge = typeBadge

    -- Remove button (only shown on My Posts tab)
    local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    removeBtn:SetWidth(60)
    removeBtn:SetHeight(20)
    removeBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 6)
    removeBtn:SetText("Remove")
    removeBtn:Hide()
    row.removeBtn = removeBtn

    -- Mail button (shown when at mailbox, on others' requests)
    local mailBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    mailBtn:SetWidth(70)
    mailBtn:SetHeight(20)
    mailBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 6)
    mailBtn:SetText("Mail Items")
    mailBtn:Hide()
    row.mailBtn = mailBtn

    row:Hide()
    self.rows[index] = row
end

function BB:Refresh()
    if not self.created then
        self:Create()
    end
    if not self.created then return end

    local tab = SC.UI.MainWindow:GetActiveTab()
    local filterType, filterPoster

    if tab == "materials" then
        filterType = "material"
    elseif tab == "crafting" then
        filterType = "craft"
    elseif tab == "myposts" then
        filterPoster = SC.Util.PlayerName()
    end

    local allRequests = SC.DataModel:GetActiveRequests(filterType, filterPoster)

    -- Apply text filter
    local filterText = self.filterBox and self.filterBox:GetText() or ""
    filterText = filterText:lower()

    if filterText ~= "" then
        local filtered = {}
        for _, req in ipairs(allRequests) do
            local match = false
            if req.poster and req.poster:lower():find(filterText, 1, true) then match = true end
            if req.note and req.note:lower():find(filterText, 1, true) then match = true end
            if req.recipeName and req.recipeName:lower():find(filterText, 1, true) then match = true end
            if req.craftedItemName and req.craftedItemName:lower():find(filterText, 1, true) then match = true end
            if req.items then
                for _, item in ipairs(req.items) do
                    if item.itemName and item.itemName:lower():find(filterText, 1, true) then
                        match = true
                        break
                    end
                end
            end
            if req.matsNeeded then
                for _, item in ipairs(req.matsNeeded) do
                    if item.itemName and item.itemName:lower():find(filterText, 1, true) then
                        match = true
                        break
                    end
                end
            end
            if match then
                filtered[#filtered + 1] = req
            end
        end
        allRequests = filtered
    end

    self.cachedData = allRequests

    -- Show/hide empty state
    if #allRequests == 0 then
        self.emptyText:Show()
    else
        self.emptyText:Hide()
    end

    self:UpdateRows()
end

function BB:UpdateRows()
    local offset = FauxScrollFrame_GetOffset(self.scrollFrame)
    local numItems = #self.cachedData
    local showRemove = (SC.UI.MainWindow:GetActiveTab() == "myposts")

    for i = 1, VISIBLE_ROWS do
        local idx = offset + i
        local row = self.rows[i]
        if idx <= numItems then
            local req = self.cachedData[idx]
            self:PopulateRow(row, req, showRemove)
            row:Show()
        else
            row:Hide()
        end
    end

    FauxScrollFrame_Update(self.scrollFrame, numItems, VISIBLE_ROWS, ROW_HEIGHT)
end

function BB:PopulateRow(row, req, showRemove)
    if req.requestType == "material" then
        -- Build item summary
        local itemNames = {}
        local firstItemID
        for _, item in ipairs(req.items or {}) do
            itemNames[#itemNames + 1] = (item.itemName or "?") .. " x" .. (item.count or 1)
            if not firstItemID then firstItemID = item.itemID end
        end
        row.titleText:SetText(table.concat(itemNames, ", "))

        -- Set icon from first item
        if firstItemID then
            local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(firstItemID)
            row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        row.typeBadge:SetText("MATERIAL")
        row.typeBadge:SetTextColor(0.2, 0.8, 0.2)

    elseif req.requestType == "craft" then
        -- Title: prefer craftedItemName, fall back to recipeName
        local craftTitle = (req.craftedItemName and req.craftedItemName ~= "") and req.craftedItemName
            or (req.recipeName and req.recipeName ~= "") and req.recipeName
            or "Unknown Recipe"
        row.titleText:SetText(craftTitle .. " (CRAFT)")

        -- Icon: use craftedItemID texture if available
        local craftTexture = nil
        if req.craftedItemID then
            local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(req.craftedItemID)
            craftTexture = tex
        end
        row.icon:SetTexture(craftTexture or "Interface\\Icons\\Trade_BlackSmithing")

        -- Build mats info
        local matsInfo = {}
        if req.matsProvided and #req.matsProvided > 0 then
            local names = {}
            for _, m in ipairs(req.matsProvided) do
                names[#names + 1] = (m.itemName or "?") .. " x" .. (m.count or 1)
            end
            matsInfo[#matsInfo + 1] = "Providing: " .. table.concat(names, ", ")
        end
        if req.matsNeeded and #req.matsNeeded > 0 then
            local names = {}
            for _, m in ipairs(req.matsNeeded) do
                names[#names + 1] = (m.itemName or "?") .. " x" .. (m.count or 1)
            end
            matsInfo[#matsInfo + 1] = "Need: " .. table.concat(names, ", ")
        end

        row.typeBadge:SetText("CRAFT")
        row.typeBadge:SetTextColor(1.0, 0.6, 0.2)

        if #matsInfo > 0 then
            row.extraText:SetText(table.concat(matsInfo, " | "))
        end
    end

    -- Detail line
    local timeStr = SC.Util.ShortTime(req.timestamp or 0)
    row.detailText:SetText("Posted by: |cff69CCF0" .. (req.poster or "?") .. "|r  " .. timeStr)

    -- Note / extra text for material requests
    if req.requestType == "material" then
        if req.note and req.note ~= "" then
            row.extraText:SetText('"' .. req.note .. '"')
        else
            row.extraText:SetText("")
        end
    elseif req.requestType == "craft" then
        -- Already set above for craft mats, append note if exists
        if req.note and req.note ~= "" then
            local current = row.extraText:GetText() or ""
            if current ~= "" then
                row.extraText:SetText(current .. ' | "' .. req.note .. '"')
            else
                row.extraText:SetText('"' .. req.note .. '"')
            end
        end
    end

    -- Fulfilled badge override
    if req.fulfilled then
        row.typeBadge:SetText("FULFILLED")
        row.typeBadge:SetTextColor(0.2, 1.0, 0.2)
    end

    -- Remove button
    if showRemove then
        row.removeBtn:Show()
        row.removeBtn:SetScript("OnClick", function()
            StaticPopup_Show("GMATS_CONFIRM_REMOVE", nil, nil, req.requestID)
        end)
    else
        row.removeBtn:Hide()
    end

    -- Mail button (mutually exclusive with remove button)
    local showMail = not showRemove
        and SC.UI.MailIntegration and SC.UI.MailIntegration:IsMailboxOpen()
        and req.poster ~= SC.Util.PlayerName()
        and not req.fulfilled
    if showMail then
        row.mailBtn:Show()
        row.mailBtn:SetScript("OnClick", function()
            SC.UI.MailIntegration:ShowAmountDialog(req)
        end)
    else
        row.mailBtn:Hide()
    end
end

-- Confirmation dialog for removing a request
StaticPopupDialogs["GMATS_CONFIRM_REMOVE"] = {
    text = "Remove this request from the guild board?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, requestID)
        local req = SC.DataModel:GetRequest(requestID)
        if req then
            SC.DataModel:RemoveRequest(requestID)
            SC.Comm:SendRemove(requestID, req.poster, req.removedAt)
            SC:Print("Request removed.")
            BB:Refresh()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
