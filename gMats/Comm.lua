local SC = gMats

SC.Comm = {}
local Comm = SC.Comm

local ADDON_PREFIX = "gMats"
local MAX_PAYLOAD = 244
local THROTTLE_INTERVAL = 0.1
local BURST_LIMIT = 10
local REGEN_RATE = 1.0 -- messages per second

-- Send queue
local sendQueue = {}
local tokens = BURST_LIMIT
local lastRegen = 0
local throttleFrame = nil

-- Chunk reassembly: sender -> opcode -> { parts={}, total=0 }
local chunkBuffers = {}
local syncReceivedCount = 0

function Comm:Init()
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(ADDON_PREFIX)
    end
    self:StartThrottle()
end

-- ============ THROTTLED SEND ============

function Comm:StartThrottle()
    if throttleFrame then return end
    throttleFrame = CreateFrame("Frame")
    throttleFrame:SetScript("OnUpdate", function(_, elapsed)
        -- Regen tokens
        local now = GetTime()
        if now - lastRegen >= REGEN_RATE then
            tokens = math.min(tokens + 1, BURST_LIMIT)
            lastRegen = now
        end
        -- Send queued messages
        if #sendQueue > 0 and tokens > 0 then
            local msg = table.remove(sendQueue, 1)
            SendAddonMessage(ADDON_PREFIX, msg, "GUILD")
            tokens = tokens - 1
        end
    end)
end

function Comm:QueueSend(message)
    -- Split into chunks if needed
    if #message > MAX_PAYLOAD then
        local chunks = self:SplitChunks(message)
        for _, chunk in ipairs(chunks) do
            sendQueue[#sendQueue + 1] = chunk
        end
    else
        sendQueue[#sendQueue + 1] = message
    end
end

function Comm:SplitChunks(message)
    -- Find opcode (everything before first |)
    local pipePos = message:find("|", 1, true)
    local opcode = message:sub(1, pipePos - 1)
    local body = message:sub(pipePos + 1)

    -- Calculate max body size per chunk (subtract header like "ADD#1/3|")
    local chunks = {}
    local totalChunks = math.ceil(#body / (MAX_PAYLOAD - #opcode - 6))

    local pos = 1
    local chunkIdx = 1
    local bodyPerChunk = MAX_PAYLOAD - #opcode - 6
    while pos <= #body do
        local piece = body:sub(pos, pos + bodyPerChunk - 1)
        chunks[#chunks + 1] = opcode .. "#" .. chunkIdx .. "/" .. totalChunks .. "|" .. piece
        pos = pos + bodyPerChunk
        chunkIdx = chunkIdx + 1
    end
    return chunks
end

-- ============ SERIALIZATION ============

-- Serialize an item list: "itemID~itemName~count,itemID~itemName~count"
local function SerializeItems(items)
    if not items or #items == 0 then return "" end
    local parts = {}
    for _, item in ipairs(items) do
        parts[#parts + 1] = (item.itemID or 0) .. "~" .. (item.itemName or "") .. "~" .. (item.count or 1)
    end
    return table.concat(parts, ",")
end

-- Deserialize an item list
local function DeserializeItems(str)
    if not str or str == "" then return {} end
    local items = {}
    for entry in str:gmatch("[^,]+") do
        local parts = SC.Util.Split(entry, "~")
        if #parts >= 3 then
            items[#items + 1] = {
                itemID = tonumber(parts[1]),
                itemName = parts[2],
                count = tonumber(parts[3]) or 1,
            }
        end
    end
    return items
end

-- ============ MESSAGE BUILDERS ============

-- ADD|requestID|poster|timestamp|items|note
function Comm:SendAdd(req)
    local msg = "ADD|" .. req.requestID .. "|" .. req.poster .. "|" .. req.timestamp
        .. "|" .. SerializeItems(req.items) .. "|" .. (req.note or "")
    self:QueueSend(msg)
end

-- CRAFT|requestID|poster|timestamp|craftedItemID|craftedItemName|recipeName|matsProvided|matsNeeded|note
function Comm:SendCraft(req)
    local msg = "CRAFT|" .. req.requestID .. "|" .. req.poster .. "|" .. req.timestamp
        .. "|" .. (req.craftedItemID or 0) .. "|" .. (req.craftedItemName or "")
        .. "|" .. (req.recipeName or "") .. "|" .. SerializeItems(req.matsProvided)
        .. "|" .. SerializeItems(req.matsNeeded) .. "|" .. (req.note or "")
    self:QueueSend(msg)
end

-- REMOVE|requestID|poster|removedAt
function Comm:SendRemove(requestID, poster, removedAt)
    local msg = "REMOVE|" .. requestID .. "|" .. poster .. "|" .. (removedAt or time())
    self:QueueSend(msg)
end

-- UPDATE|requestID|poster|timestamp|items[|fulfilled|fulfilledAt]
function Comm:SendUpdate(req)
    local items = req.items
    if req.requestType == "craft" then
        items = req.matsNeeded
    end
    local msg = "UPDATE|" .. req.requestID .. "|" .. req.poster .. "|" .. req.timestamp
        .. "|" .. SerializeItems(items)
    if req.fulfilled then
        msg = msg .. "|fulfilled|" .. (req.fulfilledAt or 0)
    end
    self:QueueSend(msg)
end

-- SYNCREQ|senderName
function Comm:SendSyncReq()
    local msg = "SYNCREQ|" .. SC.Util.PlayerName()
    self:QueueSend(msg)
end

-- SYNCDATA|<full serialized request>
function Comm:SendSyncData(req)
    if req.requestType == "craft" then
        local msg = "SYNCDATA|craft|" .. req.requestID .. "|" .. req.poster .. "|" .. req.timestamp
            .. "|" .. (req.craftedItemID or 0) .. "|" .. (req.craftedItemName or "")
            .. "|" .. (req.recipeName or "") .. "|" .. SerializeItems(req.matsProvided)
            .. "|" .. SerializeItems(req.matsNeeded) .. "|" .. (req.note or "")
        if req.removed then
            msg = msg .. "|removed|" .. (req.removedAt or 0)
        elseif req.fulfilled then
            msg = msg .. "|fulfilled|" .. (req.fulfilledAt or 0)
        end
        self:QueueSend(msg)
    else
        local msg = "SYNCDATA|material|" .. req.requestID .. "|" .. req.poster .. "|" .. req.timestamp
            .. "|" .. SerializeItems(req.items) .. "|" .. (req.note or "")
        if req.removed then
            msg = msg .. "|removed|" .. (req.removedAt or 0)
        elseif req.fulfilled then
            msg = msg .. "|fulfilled|" .. (req.fulfilledAt or 0)
        end
        self:QueueSend(msg)
    end
end

-- SYNCEND|senderName
function Comm:SendSyncEnd()
    local msg = "SYNCEND|" .. SC.Util.PlayerName()
    self:QueueSend(msg)
end

-- ============ MESSAGE PARSING ============

function Comm:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end
    if channel ~= "GUILD" then return end

    -- Ignore our own messages
    local myName = SC.Util.PlayerName()
    if sender == myName then return end

    -- Handle chunked messages
    local opcode, chunkInfo, rest = message:match("^(%u+)#(%d+/%d+)|(.*)$")
    if opcode and chunkInfo then
        local chunkNum, totalChunks = chunkInfo:match("(%d+)/(%d+)")
        chunkNum = tonumber(chunkNum)
        totalChunks = tonumber(totalChunks)

        if not chunkBuffers[sender] then chunkBuffers[sender] = {} end
        if not chunkBuffers[sender][opcode] then
            chunkBuffers[sender][opcode] = { parts = {}, total = totalChunks }
        end
        local buf = chunkBuffers[sender][opcode]
        buf.parts[chunkNum] = rest

        -- Check if complete
        local complete = true
        for i = 1, totalChunks do
            if not buf.parts[i] then
                complete = false
                break
            end
        end
        if complete then
            local fullBody = table.concat(buf.parts)
            chunkBuffers[sender][opcode] = nil
            self:HandleMessage(opcode .. "|" .. fullBody, sender)
        end
        return
    end

    self:HandleMessage(message, sender)
end

function Comm:HandleMessage(message, sender)
    local parts = SC.Util.Split(message, "|")
    local opcode = parts[1]

    if opcode == "ADD" then
        self:HandleAdd(parts, sender)
    elseif opcode == "CRAFT" then
        self:HandleCraft(parts, sender)
    elseif opcode == "REMOVE" then
        self:HandleRemove(parts, sender)
    elseif opcode == "UPDATE" then
        self:HandleUpdate(parts, sender)
    elseif opcode == "SYNCREQ" then
        self:HandleSyncReq(parts, sender)
    elseif opcode == "SYNCDATA" then
        self:HandleSyncData(parts, sender)
    elseif opcode == "SYNCEND" then
        if syncReceivedCount > 0 then
            SC:Print("Board sync complete: received " .. syncReceivedCount .. " entries from " .. sender .. ".")
        else
            SC:Print("Board sync complete from " .. sender .. ". No new entries.")
        end
        syncReceivedCount = 0
        if SC.UI and SC.UI.BrowseBoard then
            SC.UI.BrowseBoard:Refresh()
        end
        if SC.BagHighlight then SC.BagHighlight:UpdateAllVisibleBags() end
    end
end

function Comm:HandleAdd(parts, sender)
    -- ADD|requestID|poster|timestamp|items|note
    local req = {
        requestID = parts[2],
        poster = parts[3] or sender,
        requestType = "material",
        timestamp = tonumber(parts[4]) or time(),
        items = DeserializeItems(parts[5]),
        note = parts[6] or "",
    }
    SC.DataModel:MergeRequest(req)
    if SC.UI and SC.UI.BrowseBoard then
        SC.UI.BrowseBoard:Refresh()
    end
    if SC.BagHighlight then SC.BagHighlight:UpdateAllVisibleBags() end
    SC:Print(req.poster .. " posted a material request!")
end

function Comm:HandleCraft(parts, sender)
    -- CRAFT|requestID|poster|timestamp|craftedItemID|craftedItemName|recipeName|matsProvided|matsNeeded|note
    local req = {
        requestID = parts[2],
        poster = parts[3] or sender,
        requestType = "craft",
        timestamp = tonumber(parts[4]) or time(),
        craftedItemID = tonumber(parts[5]) or nil,
        craftedItemName = parts[6] or "",
        recipeName = parts[7] or "",
        matsProvided = DeserializeItems(parts[8]),
        matsNeeded = DeserializeItems(parts[9]),
        note = parts[10] or "",
    }
    SC.DataModel:MergeRequest(req)
    if SC.UI and SC.UI.BrowseBoard then
        SC.UI.BrowseBoard:Refresh()
    end
    if SC.BagHighlight then SC.BagHighlight:UpdateAllVisibleBags() end
    local displayName = (req.craftedItemName and req.craftedItemName ~= "") and req.craftedItemName or req.recipeName
    SC:Print(req.poster .. " posted a crafting request for " .. (displayName or "a recipe") .. "!")
end

function Comm:HandleRemove(parts, sender)
    -- REMOVE|requestID|poster|removedAt
    local requestID = parts[2]
    local removedAt = tonumber(parts[4]) or time()
    local existing = SC.DataModel:GetRequest(requestID)
    if existing and not existing.removed then
        SC.DataModel:RemoveRequest(requestID)
        existing.removedAt = removedAt
        if SC.UI and SC.UI.BrowseBoard then
            SC.UI.BrowseBoard:Refresh()
        end
        if SC.BagHighlight then SC.BagHighlight:UpdateAllVisibleBags() end
    elseif not existing then
        -- Create tombstone so we don't re-add it from another sync
        gMatsDB.board[requestID] = {
            requestID = requestID,
            poster = parts[3] or sender,
            removed = true,
            removedAt = removedAt,
            timestamp = 0,
            requestType = "material",
            items = {},
        }
    end
end

function Comm:HandleUpdate(parts, sender)
    -- UPDATE|requestID|poster|timestamp|items[|fulfilled|fulfilledAt]
    local requestID = parts[2]
    local poster = parts[3] or sender
    local timestamp = tonumber(parts[4]) or 0
    local existing = SC.DataModel:GetRequest(requestID)

    -- Only apply if newer timestamp and not tombstoned
    if existing and existing.removed then return end
    if existing and existing.timestamp >= timestamp then return end

    -- Update item counts on the existing request
    if existing then
        SC.DataModel:UnindexRequest(existing)
        local items = existing.items
        if existing.requestType == "craft" then
            items = existing.matsNeeded
        end
        -- Replace item counts from the update
        local newItems = DeserializeItems(parts[5])
        if items and newItems then
            for _, ni in ipairs(newItems) do
                for _, oi in ipairs(items) do
                    if oi.itemID == ni.itemID then
                        oi.count = ni.count
                        break
                    end
                end
            end
        end
        existing.timestamp = timestamp
        if parts[6] == "fulfilled" then
            existing.fulfilled = true
            existing.fulfilledAt = tonumber(parts[7]) or time()
        end
        if not existing.fulfilled then
            SC.DataModel:IndexRequest(existing)
        end
    end

    if SC.UI and SC.UI.BrowseBoard then
        SC.UI.BrowseBoard:Refresh()
    end
    if SC.BagHighlight then SC.BagHighlight:UpdateAllVisibleBags() end
end

function Comm:HandleSyncReq(parts, sender)
    -- Someone wants the full board. Send all entries.
    for _, req in pairs(gMatsDB.board) do
        self:SendSyncData(req)
    end
    self:SendSyncEnd()
end

function Comm:HandleSyncData(parts, sender)
    -- SYNCDATA|type|requestID|poster|timestamp|...
    local reqType = parts[2]
    local req

    if reqType == "material" then
        -- SYNCDATA|material|requestID|poster|timestamp|items|note[|removed|removedAt]
        req = {
            requestID = parts[3],
            poster = parts[4] or sender,
            requestType = "material",
            timestamp = tonumber(parts[5]) or 0,
            items = DeserializeItems(parts[6]),
            note = parts[7] or "",
        }
        if parts[8] == "removed" then
            req.removed = true
            req.removedAt = tonumber(parts[9]) or time()
        elseif parts[8] == "fulfilled" then
            req.fulfilled = true
            req.fulfilledAt = tonumber(parts[9]) or 0
        end
    elseif reqType == "craft" then
        -- SYNCDATA|craft|requestID|poster|timestamp|craftedItemID|craftedItemName|recipeName|matsProvided|matsNeeded|note[|removed|removedAt]
        req = {
            requestID = parts[3],
            poster = parts[4] or sender,
            requestType = "craft",
            timestamp = tonumber(parts[5]) or 0,
            craftedItemID = tonumber(parts[6]) or nil,
            craftedItemName = parts[7] or "",
            recipeName = parts[8] or "",
            matsProvided = DeserializeItems(parts[9]),
            matsNeeded = DeserializeItems(parts[10]),
            note = parts[11] or "",
        }
        if parts[12] == "removed" then
            req.removed = true
            req.removedAt = tonumber(parts[13]) or time()
        elseif parts[12] == "fulfilled" then
            req.fulfilled = true
            req.fulfilledAt = tonumber(parts[13]) or 0
        end
    end

    if req then
        SC.DataModel:MergeRequest(req)
        syncReceivedCount = syncReceivedCount + 1
    end
end

-- Request sync on login (called from Core after delay)
function Comm:RequestSync()
    self:SendSyncReq()
    SC:Print("Requesting board sync from guild...")
end
