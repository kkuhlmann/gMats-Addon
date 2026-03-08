local SC = gMats
SC.UI = SC.UI or {}

SC.UI.MailIntegration = {}
local MI = SC.UI.MailIntegration

local mailboxOpen = false
local pendingRequest = nil
local pendingSendAmounts = nil
local dialogFrame = nil

-- ============ MAILBOX STATE ============

function MI:IsMailboxOpen()
    return mailboxOpen
end

-- ============ BAG SCANNING ============

-- Returns totalCount, slots = { {bag, slot, count}, ... } sorted largest-first
function MI:ScanBagsForItem(itemID)
    local total = 0
    local slots = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = SC.Util.GetItemID(link)
                if id == itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    count = count or 1
                    total = total + count
                    slots[#slots + 1] = { bag = bag, slot = slot, count = count }
                end
            end
        end
    end
    -- Sort largest stack first for efficient attachment
    table.sort(slots, function(a, b) return a.count > b.count end)
    return total, slots
end

-- ============ AMOUNT PROMPT DIALOG ============

local MAX_ATTACHMENTS = 12
local MAX_ITEM_ROWS = 8

local function CalcAttachmentSlots(itemRows)
    local totalSlots = 0
    for _, row in ipairs(itemRows) do
        local sendCount = tonumber(row.editBox:GetText()) or 0
        if sendCount > 0 then
            local _, bagSlots = MI:ScanBagsForItem(row.itemID)
            local remaining = sendCount
            for _, s in ipairs(bagSlots) do
                if remaining <= 0 then break end
                totalSlots = totalSlots + 1
                remaining = remaining - s.count
            end
        end
    end
    return totalSlots
end

local function UpdateComposeButton()
    if not dialogFrame then return end
    local slots = CalcAttachmentSlots(dialogFrame.itemRows)
    dialogFrame.slotText:SetText("Attachment slots: " .. slots .. "/" .. MAX_ATTACHMENTS)

    local anyItems = false
    for _, row in ipairs(dialogFrame.itemRows) do
        local v = tonumber(row.editBox:GetText()) or 0
        if v > 0 then anyItems = true end
    end

    if slots > MAX_ATTACHMENTS or not anyItems then
        dialogFrame.composeBtn:Disable()
        if slots > MAX_ATTACHMENTS then
            dialogFrame.slotText:SetTextColor(1, 0.2, 0.2)
        else
            dialogFrame.slotText:SetTextColor(0.7, 0.7, 0.7)
        end
    else
        dialogFrame.composeBtn:Enable()
        dialogFrame.slotText:SetTextColor(0.7, 0.7, 0.7)
    end
end

function MI:CreateDialog()
    if dialogFrame then return dialogFrame end

    local f = CreateFrame("Frame", "gMatsMailDialog", UIParent)
    f:SetWidth(420)
    f:SetHeight(100) -- will be resized dynamically
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropColor(0, 0, 0, 1)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetText("Mail Items")
    f.titleText = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    -- Slot count text
    local slotText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40)
    slotText:SetTextColor(0.7, 0.7, 0.7)
    f.slotText = slotText

    -- Compose button
    local composeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    composeBtn:SetWidth(120)
    composeBtn:SetHeight(24)
    composeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    composeBtn:SetText("Compose Mail")
    composeBtn:SetScript("OnClick", function()
        MI:ComposeMail()
    end)
    f.composeBtn = composeBtn

    f.itemRows = {}
    f:Hide()
    dialogFrame = f
    return f
end

function MI:ShowAmountDialog(req)
    local f = self:CreateDialog()

    -- Clear old item rows
    for _, row in ipairs(f.itemRows) do
        row.frame:Hide()
    end
    wipe(f.itemRows)

    -- Determine items list
    local items = req.items
    if req.requestType == "craft" then
        items = req.matsNeeded
    end
    if not items or #items == 0 then
        SC:Print("This request has no items to send.")
        return
    end

    f.titleText:SetText("Mail to " .. req.poster)
    f.req = req

    local yOffset = -40
    local rowCount = math.min(#items, MAX_ITEM_ROWS)

    for i = 1, rowCount do
        local item = items[i]
        local inBags, _ = self:ScanBagsForItem(item.itemID)
        local needed = item.count or 0

        local rowFrame = CreateFrame("Frame", nil, f)
        rowFrame:SetWidth(390)
        rowFrame:SetHeight(30)
        rowFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 14, yOffset)

        -- Item icon
        local icon = rowFrame:CreateTexture(nil, "ARTWORK")
        icon:SetWidth(22)
        icon:SetHeight(22)
        icon:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
        local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(item.itemID)
        icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- Item name
        local nameText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        nameText:SetWidth(120)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(item.itemName or "Unknown")

        -- Need/Have text
        local infoText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        infoText:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
        infoText:SetWidth(140)
        infoText:SetJustifyH("LEFT")
        local haveColor = inBags > 0 and "|cff00ff00" or "|cffff3333"
        infoText:SetText("Need: " .. needed .. "  " .. haveColor .. "Have: " .. inBags .. "|r")

        -- Amount edit box
        local editBox = CreateFrame("EditBox", nil, rowFrame, "InputBoxTemplate")
        editBox:SetWidth(40)
        editBox:SetHeight(20)
        editBox:SetPoint("RIGHT", rowFrame, "RIGHT", -4, 0)
        editBox:SetAutoFocus(false)
        editBox:SetMaxLetters(5)
        editBox:SetNumeric(true)
        editBox:SetText(tostring(math.min(needed, inBags)))
        editBox:SetScript("OnTextChanged", function()
            -- Clamp to what's in bags
            local val = tonumber(editBox:GetText()) or 0
            if val > inBags then
                editBox:SetText(tostring(inBags))
            end
            UpdateComposeButton()
        end)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        local sendLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sendLabel:SetPoint("RIGHT", editBox, "LEFT", -2, 0)
        sendLabel:SetText("Send:")

        local rowData = {
            frame = rowFrame,
            itemID = item.itemID,
            itemName = item.itemName,
            editBox = editBox,
            needed = needed,
        }
        f.itemRows[#f.itemRows + 1] = rowData

        yOffset = yOffset - 32
    end

    -- Resize dialog to fit rows
    local totalHeight = 40 + (rowCount * 32) + 60
    f:SetHeight(totalHeight)

    UpdateComposeButton()
    f:Show()
end

-- ============ MAIL COMPOSITION ============

function MI:ComposeMail()
    if not dialogFrame or not dialogFrame.req then return end
    local req = dialogFrame.req

    -- Build send amounts
    local sendAmounts = {}
    for _, row in ipairs(dialogFrame.itemRows) do
        local count = tonumber(row.editBox:GetText()) or 0
        if count > 0 then
            sendAmounts[#sendAmounts + 1] = {
                itemID = row.itemID,
                itemName = row.itemName,
                sendCount = count,
            }
        end
    end
    if #sendAmounts == 0 then return end

    -- Store pending state for post-send tracking
    pendingRequest = req
    pendingSendAmounts = sendAmounts

    -- Switch to Send Mail tab
    MailFrameTab_OnClick(nil, 2)

    -- Set recipient
    SendMailNameEditBox:SetText(req.poster)

    -- Build subject
    local subjectParts = {}
    for _, sa in ipairs(sendAmounts) do
        subjectParts[#subjectParts + 1] = (sa.itemName or "items") .. " x" .. sa.sendCount
    end
    SendMailSubjectEditBox:SetText("[gMats] " .. table.concat(subjectParts, ", "))

    -- Build attachment queue (one entry per bag slot to attach)
    local queue = {}
    local attachSlot = 1
    for _, sa in ipairs(sendAmounts) do
        local remaining = sa.sendCount
        local _, bagSlots = self:ScanBagsForItem(sa.itemID)
        for _, s in ipairs(bagSlots) do
            if remaining <= 0 or attachSlot > MAX_ATTACHMENTS then break end
            local toSend = math.min(remaining, s.count)
            queue[#queue + 1] = {
                srcBag = s.bag, srcSlot = s.slot,
                toSend = toSend, stackCount = s.count,
                needsSplit = (toSend < s.count),
                mailSlot = attachSlot,
            }
            attachSlot = attachSlot + 1
            remaining = remaining - toSend
        end
    end

    -- Find an empty bag slot (needed for pre-splitting partial stacks)
    local function FindEmptySlot()
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                if not GetContainerItemLink(bag, slot) then
                    return bag, slot
                end
            end
        end
    end

    -- Process queue via OnUpdate with per-phase time delays.
    -- Partial stacks: split → place → pickup → attach (4 phases)
    -- Full stacks:    pickup → attach              (2 phases)
    -- This avoids the 3.3.5a bug where ClickSendMailItemButton resolves
    -- a SplitContainerItem cursor back to the full source stack.
    local idx = 1
    local phase = nil
    local delay = 0
    local STEP_DELAY = 0.15  -- seconds between each phase
    local tmpBag, tmpSlot    -- temp bag slot for current partial-stack split

    local function initialPhase(entry)
        return entry.needsSplit and "split" or "pickup"
    end

    if #queue > 0 then
        phase = initialPhase(queue[1])
    end

    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(self, elapsed)
        if idx > #queue then
            self:SetScript("OnUpdate", nil)
            dialogFrame:Hide()
            SC:Print("Mail composed! Review and click Send.")
            return
        end

        delay = delay + elapsed
        if delay < STEP_DELAY then return end
        delay = 0

        local entry = queue[idx]

        if phase == "split" then
            -- Find a free bag slot to hold the split stack
            tmpBag, tmpSlot = FindEmptySlot()
            if not tmpBag then
                self:SetScript("OnUpdate", nil)
                SC:Print("No free bag slot to split stacks. Free a slot and try again.")
                return
            end
            ClearCursor()
            SplitContainerItem(entry.srcBag, entry.srcSlot, entry.toSend)
            phase = "place"

        elseif phase == "place" then
            -- Place the split items from cursor into the temp bag slot
            PickupContainerItem(tmpBag, tmpSlot)
            phase = "pickup"

        elseif phase == "pickup" then
            -- Pick up the stack (always a full stack now)
            ClearCursor()
            if entry.needsSplit then
                PickupContainerItem(tmpBag, tmpSlot)
            else
                PickupContainerItem(entry.srcBag, entry.srcSlot)
            end
            phase = "attach"

        elseif phase == "attach" then
            -- Attach cursor item to the mail slot
            ClickSendMailItemButton(entry.mailSlot)
            idx = idx + 1
            if idx <= #queue then
                phase = initialPhase(queue[idx])
            end
        end
    end)
end

-- ============ POST-SEND HANDLER ============

function MI:OnMailSent()
    if not pendingRequest or not pendingSendAmounts then return end

    SC.DataModel:UpdateItemCounts(pendingRequest.requestID, pendingSendAmounts)
    local req = SC.DataModel:GetRequest(pendingRequest.requestID)
    if req then
        SC.Comm:SendUpdate(req)
    end

    -- Build confirmation message
    local parts = {}
    for _, sa in ipairs(pendingSendAmounts) do
        parts[#parts + 1] = (sa.itemName or "items") .. " x" .. sa.sendCount
    end
    SC:Print("Sent " .. table.concat(parts, ", ") .. " to " .. pendingRequest.poster .. "! Counts updated.")

    pendingRequest = nil
    pendingSendAmounts = nil

    if SC.UI and SC.UI.BrowseBoard then
        SC.UI.BrowseBoard:Refresh()
    end
    if SC.BagHighlight then SC.BagHighlight:UpdateAllVisibleBags() end
end

function MI:OnMailClosed()
    pendingRequest = nil
    pendingSendAmounts = nil
    mailboxOpen = false
    if dialogFrame then
        dialogFrame:Hide()
    end
    if SC.UI and SC.UI.BrowseBoard then
        SC.UI.BrowseBoard:Refresh()
    end
end

-- ============ INIT ============

function MI:Init()
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MAIL_SHOW")
    eventFrame:RegisterEvent("MAIL_CLOSED")
    eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MAIL_SHOW" then
            mailboxOpen = true
            if SC.UI and SC.UI.BrowseBoard then
                SC.UI.BrowseBoard:Refresh()
            end
        elseif event == "MAIL_CLOSED" then
            MI:OnMailClosed()
        elseif event == "MAIL_SEND_SUCCESS" then
            MI:OnMailSent()
        end
    end)
end
