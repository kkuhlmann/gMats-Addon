local SC = gMats

SC.DataModel = {}
local DM = SC.DataModel

-- Sequence counter for unique request IDs
local seqCounter = 0

-- Reverse index: itemID -> list of {requestID, poster, count}
DM.itemIndex = {}

-- Initialize SavedVariables
function DM:Init()
    if not gMatsDB then
        gMatsDB = {}
    end
    if not gMatsDB.board then
        gMatsDB.board = {}
    end
    if not gMatsDB.settings then
        gMatsDB.settings = {
            minimapPos = 220,
            alertsEnabled = true,
            tooltipsEnabled = true,
            bagHighlightsEnabled = true,
        }
    end
    self:GarbageCollectTombstones()
    self:RebuildIndex()
end

-- Generate a unique request ID
function DM:NewRequestID()
    seqCounter = seqCounter + 1
    return SC.Util.PlayerName() .. "-" .. time() .. "-" .. seqCounter
end

-- Rebuild the reverse item index from the entire board
function DM:RebuildIndex()
    wipe(self.itemIndex)
    for reqID, req in pairs(gMatsDB.board) do
        if not req.removed and not req.fulfilled then
            self:IndexRequest(req)
        end
    end
end

-- Add a single request's items to the index
function DM:IndexRequest(req)
    if req.fulfilled then return end -- fulfilled items don't appear in tooltip/loot-alert
    local items = req.items
    if req.requestType == "craft" then
        items = req.matsNeeded
    end
    if not items then return end
    for _, item in ipairs(items) do
        if item.itemID then
            if not self.itemIndex[item.itemID] then
                self.itemIndex[item.itemID] = {}
            end
            table.insert(self.itemIndex[item.itemID], {
                requestID = req.requestID,
                poster = req.poster,
                count = item.count or 1,
                requestType = req.requestType,
            })
        end
    end
end

-- Remove a single request's items from the index
function DM:UnindexRequest(req)
    local items = req.items
    if req.requestType == "craft" then
        items = req.matsNeeded
    end
    if not items then return end
    for _, item in ipairs(items) do
        if item.itemID and self.itemIndex[item.itemID] then
            local list = self.itemIndex[item.itemID]
            for i = #list, 1, -1 do
                if list[i].requestID == req.requestID then
                    table.remove(list, i)
                end
            end
            if #list == 0 then
                self.itemIndex[item.itemID] = nil
            end
        end
    end
end

-- Add a material request
function DM:AddMaterialRequest(items, note)
    local req = {
        requestID = self:NewRequestID(),
        poster = SC.Util.PlayerName(),
        requestType = "material",
        timestamp = time(),
        items = items,
        note = note or "",
    }
    gMatsDB.board[req.requestID] = req
    self:IndexRequest(req)
    return req
end

-- Add a crafting request
function DM:AddCraftRequest(craftedItemID, craftedItemName, recipeName, matsProvided, matsNeeded, note)
    local req = {
        requestID = self:NewRequestID(),
        poster = SC.Util.PlayerName(),
        requestType = "craft",
        timestamp = time(),
        craftedItemID = craftedItemID,
        craftedItemName = craftedItemName or "",
        recipeName = recipeName,
        matsProvided = matsProvided or {},
        matsNeeded = matsNeeded or {},
        note = note or "",
    }
    gMatsDB.board[req.requestID] = req
    self:IndexRequest(req)
    return req
end

-- Remove a request (tombstone it)
function DM:RemoveRequest(requestID)
    local req = gMatsDB.board[requestID]
    if req then
        self:UnindexRequest(req)
        req.removed = true
        req.removedAt = time()
    end
end

-- Merge a received request into the board (from sync)
function DM:MergeRequest(req)
    if not req or not req.requestID then return end
    local existing = gMatsDB.board[req.requestID]

    if req.removed then
        if existing and not existing.removed then
            self:UnindexRequest(existing)
        end
        gMatsDB.board[req.requestID] = req
        return
    end

    if existing then
        if existing.removed then
            return -- tombstone wins
        end
        if req.timestamp > existing.timestamp then
            self:UnindexRequest(existing)
            gMatsDB.board[req.requestID] = req
            if not req.fulfilled then
                self:IndexRequest(req)
            end
        end
    else
        gMatsDB.board[req.requestID] = req
        if not req.fulfilled then
            self:IndexRequest(req)
        end
    end
end

-- Update item counts after mailing items
-- sendAmounts = { {itemID=N, sendCount=N}, ... }
function DM:UpdateItemCounts(requestID, sendAmounts)
    local req = gMatsDB.board[requestID]
    if not req then return end

    self:UnindexRequest(req)

    local items = req.items
    if req.requestType == "craft" then
        items = req.matsNeeded
    end
    if not items then return end

    for _, sa in ipairs(sendAmounts) do
        for _, item in ipairs(items) do
            if item.itemID == sa.itemID then
                item.count = math.max(0, (item.count or 0) - sa.sendCount)
                break
            end
        end
    end

    -- Check if all counts are zero -> fulfilled
    local allZero = true
    for _, item in ipairs(items) do
        if (item.count or 0) > 0 then
            allZero = false
            break
        end
    end
    if allZero then
        req.fulfilled = true
        req.fulfilledAt = time()
    end

    req.timestamp = time()
    self:IndexRequest(req)
end

-- Get all active (non-removed) requests as a sorted list
function DM:GetActiveRequests(filterType, filterPoster)
    local list = {}
    for _, req in pairs(gMatsDB.board) do
        if not req.removed then
            local pass = true
            if filterType and req.requestType ~= filterType then
                pass = false
            end
            if filterPoster and req.poster ~= filterPoster then
                pass = false
            end
            if pass then
                list[#list + 1] = req
            end
        end
    end
    -- Sort newest first
    table.sort(list, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)
    return list
end

-- Get a single request
function DM:GetRequest(requestID)
    return gMatsDB.board[requestID]
end

-- Look up item in the index
function DM:LookupItem(itemID)
    return self.itemIndex[itemID]
end

-- Garbage-collect tombstones older than 7 days
function DM:GarbageCollectTombstones()
    local cutoff = time() - (7 * 24 * 60 * 60)
    for reqID, req in pairs(gMatsDB.board) do
        if req.removed and req.removedAt and req.removedAt < cutoff then
            gMatsDB.board[reqID] = nil
        end
    end
end

-- Count active requests
function DM:CountActive()
    local count = 0
    for _, req in pairs(gMatsDB.board) do
        if not req.removed then
            count = count + 1
        end
    end
    return count
end
