local SC = gMats
SC.UI = SC.UI or {}

SC.UI.PostRequestForm = {}
local PRF = SC.UI.PostRequestForm

function PRF:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "gMatsPostForm", UIParent)
    f:SetWidth(420)
    f:SetHeight(420)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    f:SetFrameStrata("DIALOG")
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
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetText("Post New Request")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetTextColor(0.4, 0.8, 1.0)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Request type radio buttons
    local yPos = -44
    local typeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetText("Request Type:")
    typeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, yPos)

    local materialBtn = CreateFrame("CheckButton", "gMatsRadioMaterial", f, "UIRadioButtonTemplate")
    materialBtn:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -4)
    local matText = materialBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    matText:SetText("Material Request")
    matText:SetPoint("LEFT", materialBtn, "RIGHT", 4, 0)

    local craftBtn = CreateFrame("CheckButton", "gMatsRadioCraft", f, "UIRadioButtonTemplate")
    craftBtn:SetPoint("LEFT", matText, "RIGHT", 20, 0)
    local craftText = craftBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    craftText:SetText("Crafting Request")
    craftText:SetPoint("LEFT", craftBtn, "RIGHT", 4, 0)

    self.requestType = "material"
    materialBtn:SetChecked(true)

    materialBtn:SetScript("OnClick", function()
        materialBtn:SetChecked(true)
        craftBtn:SetChecked(false)
        self.requestType = "material"
        self:UpdateFormVisibility()
    end)

    craftBtn:SetScript("OnClick", function()
        craftBtn:SetChecked(true)
        materialBtn:SetChecked(false)
        self.requestType = "craft"
        self:UpdateFormVisibility()
    end)

    -- ============ MATERIAL SECTION ============
    local matSection = CreateFrame("Frame", nil, f)
    matSection:SetPoint("TOPLEFT", materialBtn, "BOTTOMLEFT", 0, -10)
    matSection:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    matSection:SetHeight(200)
    self.matSection = matSection

    local itemsLabel = matSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemsLabel:SetText("Items Needed:")
    itemsLabel:SetPoint("TOPLEFT", matSection, "TOPLEFT", 0, 0)

    -- Items list display
    self.itemsList = {}
    self.itemFrames = {}
    for i = 1, 5 do
        local row = CreateFrame("Frame", nil, matSection)
        row:SetHeight(22)
        row:SetPoint("TOPLEFT", matSection, "TOPLEFT", 0, -18 - (i - 1) * 24)
        row:SetPoint("RIGHT", matSection, "RIGHT", 0, 0)

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
        nameText:SetWidth(180)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        local countLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countLabel:SetText("x")
        countLabel:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
        row.countLabel = countLabel

        local countBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        countBox:SetWidth(40)
        countBox:SetHeight(20)
        countBox:SetPoint("LEFT", countLabel, "RIGHT", 2, 0)
        countBox:SetAutoFocus(false)
        countBox:SetMaxLetters(5)
        countBox:SetNumeric(true)
        countBox:SetText("1")
        countBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        row.countBox = countBox

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetWidth(20)
        removeBtn:SetHeight(20)
        removeBtn:SetPoint("LEFT", countBox, "RIGHT", 4, 0)
        removeBtn:SetText("X")
        local idx = i
        removeBtn:SetScript("OnClick", function()
            PRF:RemoveItem(idx, "items")
        end)
        row.removeBtn = removeBtn

        row:Hide()
        self.itemFrames[i] = row
    end

    -- Add item buttons
    local addItemBtn = CreateFrame("Button", nil, matSection, "UIPanelButtonTemplate")
    addItemBtn:SetWidth(100)
    addItemBtn:SetHeight(22)
    addItemBtn:SetPoint("TOPLEFT", matSection, "TOPLEFT", 0, -18)
    addItemBtn:SetText("Search Item")
    addItemBtn:SetScript("OnClick", function()
        SC.UI.ItemSearch:Show(function(itemID, itemName)
            PRF:AddItem(itemID, itemName, "items")
        end)
    end)
    self.addItemBtn = addItemBtn

    -- Hint: shift-click
    local hintText = matSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hintText:SetText("or Shift-click item in bags")
    hintText:SetPoint("LEFT", addItemBtn, "RIGHT", 8, 0)
    hintText:SetTextColor(0.5, 0.5, 0.5)
    self.matHintText = hintText

    -- ============ CRAFT SECTION ============
    local craftSection = CreateFrame("Frame", nil, f)
    craftSection:SetPoint("TOPLEFT", materialBtn, "BOTTOMLEFT", 0, -10)
    craftSection:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    craftSection:SetHeight(360)
    craftSection:Hide()
    self.craftSection = craftSection

    -- Crafted Item: icon + EditBox + Clear button
    local craftedLabel = craftSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    craftedLabel:SetText("Crafted Item:")
    craftedLabel:SetPoint("TOPLEFT", craftSection, "TOPLEFT", 0, 0)

    local craftedRow = CreateFrame("Frame", nil, craftSection)
    craftedRow:SetHeight(28)
    craftedRow:SetPoint("TOPLEFT", craftedLabel, "BOTTOMLEFT", 0, -2)
    craftedRow:SetPoint("RIGHT", craftSection, "RIGHT", 0, 0)

    local craftedIcon = craftedRow:CreateTexture(nil, "ARTWORK")
    craftedIcon:SetWidth(28)
    craftedIcon:SetHeight(28)
    craftedIcon:SetPoint("LEFT", craftedRow, "LEFT", 0, 0)
    craftedIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.craftedIcon = craftedIcon

    local craftedItemBox = CreateFrame("EditBox", "gMatsCraftedItemBox", craftedRow, "InputBoxTemplate")
    craftedItemBox:SetWidth(240)
    craftedItemBox:SetHeight(22)
    craftedItemBox:SetPoint("LEFT", craftedIcon, "RIGHT", 6, 0)
    craftedItemBox:SetAutoFocus(false)
    craftedItemBox:SetMaxLetters(100)
    craftedItemBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    craftedItemBox:SetScript("OnTextChanged", function()
        -- If user types manually, clear the itemID (icon stays as question mark)
        if not PRF.settingCraftedItem then
            PRF.craftedItemID = nil
            PRF.craftedIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end)
    self.craftedItemBox = craftedItemBox

    local craftedClearBtn = CreateFrame("Button", nil, craftedRow, "UIPanelButtonTemplate")
    craftedClearBtn:SetWidth(50)
    craftedClearBtn:SetHeight(22)
    craftedClearBtn:SetPoint("LEFT", craftedItemBox, "RIGHT", 4, 0)
    craftedClearBtn:SetText("Clear")
    craftedClearBtn:SetScript("OnClick", function()
        PRF:ClearCraftedItem()
    end)

    -- Tradeskill hint
    local tsHint = craftSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tsHint:SetText("Shift-click a recipe in your profession window to auto-fill")
    tsHint:SetPoint("TOPLEFT", craftedRow, "BOTTOMLEFT", 0, -2)
    tsHint:SetTextColor(0.5, 0.5, 0.5)

    -- Recipe name (optional)
    local recipeLabel = craftSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recipeLabel:SetText("Recipe Name (optional):")
    recipeLabel:SetPoint("TOPLEFT", tsHint, "BOTTOMLEFT", 0, -6)

    local recipeBox = CreateFrame("EditBox", "gMatsRecipeBox", craftSection, "InputBoxTemplate")
    recipeBox:SetWidth(250)
    recipeBox:SetHeight(22)
    recipeBox:SetPoint("TOPLEFT", recipeLabel, "BOTTOMLEFT", 0, -2)
    recipeBox:SetAutoFocus(false)
    recipeBox:SetMaxLetters(100)
    recipeBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.recipeBox = recipeBox

    -- Materials Needed label (anchored to recipeBox now)
    local needLabel = craftSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    needLabel:SetText("Materials Needed:")
    needLabel:SetPoint("TOPLEFT", recipeBox, "BOTTOMLEFT", 0, -8)
    self.needLabel = needLabel

    -- Mats needed rows (8 slots)
    self.matsNeededFrames = {}
    for i = 1, 8 do
        local row = CreateFrame("Frame", nil, craftSection)
        row:SetHeight(22)
        row:SetPoint("TOPLEFT", needLabel, "BOTTOMLEFT", 0, -2 - (i - 1) * 24)
        row:SetPoint("RIGHT", craftSection, "RIGHT", 0, 0)

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
        nameText:SetWidth(160)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        local countLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        countLabel:SetText("x")
        countLabel:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
        row.countLabel = countLabel

        local countBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        countBox:SetWidth(40)
        countBox:SetHeight(20)
        countBox:SetPoint("LEFT", countLabel, "RIGHT", 2, 0)
        countBox:SetAutoFocus(false)
        countBox:SetNumeric(true)
        countBox:SetText("1")
        countBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        row.countBox = countBox

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetWidth(20)
        removeBtn:SetHeight(20)
        removeBtn:SetPoint("LEFT", countBox, "RIGHT", 4, 0)
        removeBtn:SetText("X")
        local idx = i
        removeBtn:SetScript("OnClick", function()
            PRF:RemoveItem(idx, "matsNeeded")
        end)
        row.removeBtn = removeBtn

        row:Hide()
        self.matsNeededFrames[i] = row
    end

    -- Inline manual entry row: [item name EditBox] [count EditBox] [Add button]
    local addRow = CreateFrame("Frame", nil, craftSection)
    addRow:SetHeight(24)
    addRow:SetPoint("TOPLEFT", needLabel, "BOTTOMLEFT", 0, -2)
    addRow:SetPoint("RIGHT", craftSection, "RIGHT", 0, 0)
    self.addRow = addRow

    local addNameBox = CreateFrame("EditBox", "gMatsAddNeedName", addRow, "InputBoxTemplate")
    addNameBox:SetWidth(180)
    addNameBox:SetHeight(22)
    addNameBox:SetPoint("LEFT", addRow, "LEFT", 0, 0)
    addNameBox:SetAutoFocus(false)
    addNameBox:SetMaxLetters(80)
    addNameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    addNameBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        PRF:AddItemFromEntry()
    end)
    self.addNeedNameBox = addNameBox

    -- Placeholder text for the name box
    local addNamePlaceholder = addNameBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addNamePlaceholder:SetPoint("LEFT", addNameBox, "LEFT", 6, 0)
    addNamePlaceholder:SetText("Item name...")
    addNamePlaceholder:SetTextColor(0.5, 0.5, 0.5)
    addNameBox:SetScript("OnEditFocusGained", function()
        addNamePlaceholder:Hide()
    end)
    addNameBox:SetScript("OnEditFocusLost", function()
        if addNameBox:GetText() == "" then
            addNamePlaceholder:Show()
        end
    end)
    addNameBox:SetScript("OnTextChanged", function()
        if addNameBox:GetText() ~= "" then
            addNamePlaceholder:Hide()
        end
    end)

    local addCountLabel = addRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addCountLabel:SetText("x")
    addCountLabel:SetPoint("LEFT", addNameBox, "RIGHT", 4, 0)

    local addCountBox = CreateFrame("EditBox", "gMatsAddNeedCount", addRow, "InputBoxTemplate")
    addCountBox:SetWidth(40)
    addCountBox:SetHeight(22)
    addCountBox:SetPoint("LEFT", addCountLabel, "RIGHT", 2, 0)
    addCountBox:SetAutoFocus(false)
    addCountBox:SetNumeric(true)
    addCountBox:SetMaxLetters(5)
    addCountBox:SetText("1")
    addCountBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    addCountBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        PRF:AddItemFromEntry()
    end)
    self.addNeedCountBox = addCountBox

    local addNeedBtn = CreateFrame("Button", nil, addRow, "UIPanelButtonTemplate")
    addNeedBtn:SetWidth(50)
    addNeedBtn:SetHeight(22)
    addNeedBtn:SetPoint("LEFT", addCountBox, "RIGHT", 4, 0)
    addNeedBtn:SetText("Add")
    addNeedBtn:SetScript("OnClick", function()
        PRF:AddItemFromEntry()
    end)

    -- Hint for craft section
    local craftHint = craftSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    craftHint:SetText("Shift-click bag items or type item name above")
    craftHint:SetPoint("TOPLEFT", addRow, "BOTTOMLEFT", 0, -2)
    craftHint:SetTextColor(0.5, 0.5, 0.5)
    self.craftHint = craftHint

    -- ============ NOTE FIELD ============
    local noteLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteLabel:SetText("Note (optional):")
    noteLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 90)
    self.noteLabel = noteLabel

    local noteBox = CreateFrame("EditBox", "gMatsNoteBox", f, "InputBoxTemplate")
    noteBox:SetWidth(360)
    noteBox:SetHeight(22)
    noteBox:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 0, -2)
    noteBox:SetAutoFocus(false)
    noteBox:SetMaxLetters(100)
    noteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    self.noteBox = noteBox

    -- Submit button
    local submitBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    submitBtn:SetWidth(120)
    submitBtn:SetHeight(28)
    submitBtn:SetText("Submit")
    self.submitBtn = submitBtn
    submitBtn:SetScript("OnClick", function()
        PRF:Submit()
    end)

    -- Data storage
    self.items = {}         -- for material requests
    self.matsNeeded = {}    -- for craft requests
    self.craftedItemID = nil
    self.craftedItemName = nil

    tinsert(UISpecialFrames, "gMatsPostForm")

    self.frame = f

    -- Hook shift-click for item linking
    self:HookShiftClick()
end

-- ============ CRAFTED ITEM SELECTOR ============

function PRF:SetCraftedItem(itemID, itemName)
    self.craftedItemID = itemID
    self.craftedItemName = itemName
    if self.craftedItemBox then
        self.settingCraftedItem = true
        self.craftedItemBox:SetText(itemName or "")
        self.settingCraftedItem = false
    end
    if self.craftedIcon then
        if itemID then
            local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
            self.craftedIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        else
            self.craftedIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
end

function PRF:ClearCraftedItem()
    self.craftedItemID = nil
    self.craftedItemName = nil
    if self.craftedItemBox then
        self.settingCraftedItem = true
        self.craftedItemBox:SetText("")
        self.settingCraftedItem = false
    end
    if self.craftedIcon then
        self.craftedIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
end

-- ============ INLINE ADD FROM ENTRY ============

function PRF:AddItemFromEntry()
    local name = self.addNeedNameBox and self.addNeedNameBox:GetText() or ""
    name = strtrim(name)
    if name == "" then
        SC:Print("Enter an item name to add.")
        return
    end

    local count = tonumber(self.addNeedCountBox and self.addNeedCountBox:GetText()) or 1
    if count < 1 then count = 1 end

    -- Reverse-lookup in gMatsItemDB (case-insensitive exact match)
    local foundID = nil
    local foundName = nil
    local lowerName = string.lower(name)
    if gMatsItemDB then
        for id, dbName in pairs(gMatsItemDB) do
            if string.lower(dbName) == lowerName then
                foundID = id
                foundName = dbName
                break
            end
        end
    end

    if foundID then
        self:AddItem(foundID, foundName, "matsNeeded")
    else
        -- Add with nil itemID - still works, just no tooltip/alert integration
        self:AddItem(nil, name, "matsNeeded")
    end

    -- Clear the entry fields
    if self.addNeedNameBox then self.addNeedNameBox:SetText("") end
    if self.addNeedCountBox then self.addNeedCountBox:SetText("1") end
end

-- ============ TRADESKILL IMPORT ============

function PRF:ImportFromTradeSkill(index)
    -- Get crafted item
    local itemLink = GetTradeSkillItemLink(index)
    if itemLink then
        local itemID, itemName = SC.Util.ParseItemLink(itemLink)
        if itemID then
            self:SetCraftedItem(itemID, itemName)
        end
    end

    -- Get recipe name
    local skillName = GetTradeSkillInfo(index)
    if skillName and self.recipeBox then
        self.recipeBox:SetText(skillName)
    end

    -- Clear and populate matsNeeded from reagents
    self.matsNeeded = {}
    local numReagents = GetTradeSkillNumReagents(index)
    for i = 1, numReagents do
        local reagentName, _, reagentCount = GetTradeSkillReagentInfo(index, i)
        local reagentLink = GetTradeSkillReagentItemLink(index, i)
        local reagentID
        if reagentLink then
            reagentID = SC.Util.ParseItemLink(reagentLink)
        end
        if reagentID and reagentName then
            self.matsNeeded[#self.matsNeeded + 1] = {
                itemID = reagentID,
                itemName = reagentName,
                count = reagentCount or 1,
            }
        end
    end
    self:RefreshItemList(self.matsNeeded, self.matsNeededFrames)
    self:UpdateCraftLayout()
end

-- ============ SHIFT-CLICK HOOKS ============

function PRF:HookShiftClick()
    -- Hook container item clicks for shift-click linking
    local origContainerFrameItemButton_OnModifiedClick = ContainerFrameItemButton_OnModifiedClick
    ContainerFrameItemButton_OnModifiedClick = function(self, button, ...)
        if IsShiftKeyDown() and PRF.frame and PRF.frame:IsShown() then
            local bag = self:GetParent():GetID()
            local slot = self:GetID()
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemID, itemName = SC.Util.ParseItemLink(link)
                if itemID then
                    if PRF.requestType == "material" then
                        PRF:AddItem(itemID, itemName, "items")
                        return
                    else
                        -- In craft mode, check if it's a recipe item
                        local _, _, _, _, _, itemType = GetItemInfo(link)
                        if itemType == "Recipe" then
                            -- Strip prefix (Pattern: , Plans: , Schematic: , Design: , Formula: , Manual: , etc.)
                            local stripped = itemName:gsub("^%w+:%s*", "")
                            if PRF.recipeBox then
                                PRF.recipeBox:SetText(stripped)
                            end
                        else
                            PRF:AddItem(itemID, itemName, "matsNeeded")
                        end
                        return
                    end
                end
            end
        end
        if origContainerFrameItemButton_OnModifiedClick then
            origContainerFrameItemButton_OnModifiedClick(self, button, ...)
        end
    end

    -- Hook ChatEdit_InsertLink for tradeskill shift-click
    local origChatEdit_InsertLink = ChatEdit_InsertLink
    ChatEdit_InsertLink = function(link)
        if PRF.frame and PRF.frame:IsShown() and PRF.requestType == "craft" then
            if TradeSkillFrame and TradeSkillFrame:IsShown() then
                local index = GetTradeSkillSelectionIndex()
                if index then
                    PRF:ImportFromTradeSkill(index)
                    return true
                end
            end
        end
        return origChatEdit_InsertLink(link)
    end
end

function PRF:UpdateFormVisibility()
    if self.requestType == "material" then
        self.matSection:Show()
        self.craftSection:Hide()
        -- Anchor note below matSection for material mode
        self.noteLabel:ClearAllPoints()
        self.noteLabel:SetPoint("TOPLEFT", self.matSection, "BOTTOMLEFT", 0, -8)
        self.submitBtn:ClearAllPoints()
        self.submitBtn:SetPoint("TOP", self.noteBox, "BOTTOM", 0, -10)
        self:UpdateMaterialLayout()
    else
        self.matSection:Hide()
        self.craftSection:Show()
        self:UpdateCraftLayout()
    end
end

function PRF:UpdateMaterialLayout()
    local visibleCount = #self.items

    -- Reposition addItemBtn below the last visible item row
    self.addItemBtn:ClearAllPoints()
    self.addItemBtn:SetPoint("TOPLEFT", self.matSection, "TOPLEFT", 0, -18 - visibleCount * 24)

    -- matHintText is already anchored relative to addItemBtn, follows automatically

    -- Adjust matSection height to fit content
    local sectionHeight = 18 + visibleCount * 24 + 24 + 8
    self.matSection:SetHeight(sectionHeight)

    -- noteLabel is anchored to matSection BOTTOMLEFT, follows automatically
    -- submitBtn is anchored to noteBox, follows automatically

    -- Adjust frame height
    local height = 140 + sectionHeight + 40 + 42 + 20
    if height < 300 then height = 300 end
    self.frame:SetHeight(height)
end

function PRF:UpdateCraftLayout()
    -- Count visible matsNeeded items
    local visibleCount = #self.matsNeeded

    -- Reposition addRow below the last visible item (or below needLabel if none)
    self.addRow:ClearAllPoints()
    self.addRow:SetPoint("TOPLEFT", self.needLabel, "BOTTOMLEFT", 0, -2 - visibleCount * 24)
    self.addRow:SetPoint("RIGHT", self.craftSection, "RIGHT", 0, 0)

    -- Reposition craftHint below addRow
    self.craftHint:ClearAllPoints()
    self.craftHint:SetPoint("TOPLEFT", self.addRow, "BOTTOMLEFT", 0, -2)

    -- Reposition noteLabel below craftHint
    self.noteLabel:ClearAllPoints()
    self.noteLabel:SetPoint("TOPLEFT", self.craftHint, "BOTTOMLEFT", 0, -8)

    -- submitBtn below noteBox
    self.submitBtn:ClearAllPoints()
    self.submitBtn:SetPoint("TOP", self.noteBox, "BOTTOM", 0, -10)

    -- Adjust frame height: base craft header ~200 + materials + addRow + hint + note + submit + padding
    local height = 200 + visibleCount * 24 + 24 + 16 + 40 + 42 + 30
    if height < 360 then height = 360 end
    self.frame:SetHeight(height)
end

function PRF:AddItem(itemID, itemName, listKey)
    local list
    local frames
    if listKey == "items" then
        list = self.items
        frames = self.itemFrames
    elseif listKey == "matsNeeded" then
        list = self.matsNeeded
        frames = self.matsNeededFrames
    else
        return
    end

    local maxItems = #frames
    if #list >= maxItems then
        SC:Print("Maximum items reached for this list.")
        return
    end

    list[#list + 1] = { itemID = itemID, itemName = itemName, count = 1 }
    self:RefreshItemList(list, frames)
end

function PRF:RemoveItem(index, listKey)
    local list
    local frames
    if listKey == "items" then
        list = self.items
        frames = self.itemFrames
    elseif listKey == "matsNeeded" then
        list = self.matsNeeded
        frames = self.matsNeededFrames
    else
        return
    end

    if list[index] then
        table.remove(list, index)
        self:RefreshItemList(list, frames)
    end
end

function PRF:RefreshItemList(list, frames)
    for i = 1, #frames do
        local row = frames[i]
        if list[i] then
            row.nameText:SetText(list[i].itemName or "?")
            row.countBox:SetText(tostring(list[i].count or 1))
            row:Show()
        else
            row:Hide()
        end
    end
    -- Update layout if we just refreshed a dynamic list
    if frames == self.matsNeededFrames and self.addRow then
        self:UpdateCraftLayout()
    elseif frames == self.itemFrames and self.addItemBtn then
        self:UpdateMaterialLayout()
    end
end

function PRF:Submit()
    if self.requestType == "material" then
        if #self.items == 0 then
            SC:Print("Please add at least one item.")
            return
        end
        -- Read counts from edit boxes
        for i, item in ipairs(self.items) do
            local frame = self.itemFrames[i]
            if frame and frame.countBox then
                item.count = tonumber(frame.countBox:GetText()) or 1
            end
        end
        local note = self.noteBox:GetText() or ""
        local req = SC.DataModel:AddMaterialRequest(self.items, note)
        SC.Comm:SendAdd(req)
        SC:Print("Material request posted!")
    else
        local craftedName = self.craftedItemBox and strtrim(self.craftedItemBox:GetText()) or ""
        if craftedName == "" then
            SC:Print("Please enter a crafted item name.")
            return
        end
        -- Read counts from matsNeeded edit boxes
        for i, item in ipairs(self.matsNeeded) do
            local frame = self.matsNeededFrames[i]
            if frame and frame.countBox then
                item.count = tonumber(frame.countBox:GetText()) or 1
            end
        end
        local recipeName = self.recipeBox:GetText() or ""
        local note = self.noteBox:GetText() or ""
        local craftedItemID = self.craftedItemID  -- may be nil if typed manually
        local req = SC.DataModel:AddCraftRequest(craftedItemID, craftedName, recipeName, {}, self.matsNeeded, note)
        SC.Comm:SendCraft(req)
        SC:Print("Crafting request posted!")
    end

    -- Reset form
    self:Reset()
    self.frame:Hide()

    -- Refresh board
    if SC.UI.BrowseBoard then
        SC.UI.BrowseBoard:Refresh()
    end
end

function PRF:Reset()
    self.items = {}
    self.matsNeeded = {}
    self.requestType = "material"

    self:ClearCraftedItem()
    if self.recipeBox then self.recipeBox:SetText("") end
    if self.noteBox then self.noteBox:SetText("") end
    if self.addNeedNameBox then self.addNeedNameBox:SetText("") end
    if self.addNeedCountBox then self.addNeedCountBox:SetText("1") end

    -- Reset radio buttons
    if gMatsRadioMaterial then gMatsRadioMaterial:SetChecked(true) end
    if gMatsRadioCraft then gMatsRadioCraft:SetChecked(false) end

    -- Hide all item rows
    for _, row in ipairs(self.itemFrames or {}) do row:Hide() end
    for _, row in ipairs(self.matsNeededFrames or {}) do row:Hide() end

    self:UpdateFormVisibility()
end

function PRF:Show()
    if not self.frame then
        self:Create()
    end
    self:Reset()
    self.frame:Show()
end

function PRF:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
