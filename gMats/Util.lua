gMats = gMats or {}
local SC = gMats

SC.Util = {}

function SC.Util.Split(str, sep)
    local parts = {}
    local pattern = "([^" .. sep .. "]*)" .. sep .. "?"
    str:gsub(pattern, function(c)
        if #c > 0 or #parts > 0 then
            parts[#parts + 1] = c
        end
    end)
    return parts
end

function SC.Util.Trim(str)
    return str:match("^%s*(.-)%s*$") or ""
end

-- Extract itemID from an item link like "|cff9d9d9d|Hitem:7073:0:...|h[Broken Fang]|h|r"
function SC.Util.ParseItemLink(link)
    if not link then return nil, nil end
    local itemID = link:match("|Hitem:(%d+):")
    local itemName = link:match("|h%[(.-)%]|h")
    if itemID then
        return tonumber(itemID), itemName
    end
    return nil, nil
end

-- Get itemID from a link or plain ID
function SC.Util.GetItemID(input)
    if type(input) == "number" then return input end
    if type(input) == "string" then
        local id = tonumber(input)
        if id then return id end
        local parsed = SC.Util.ParseItemLink(input)
        return parsed
    end
    return nil
end

function SC.Util.EscapePipe(str)
    if not str then return "" end
    return str:gsub("|", "||")
end

function SC.Util.UnescapePipe(str)
    if not str then return "" end
    return str:gsub("||", "|")
end

function SC.Util.ClassColor(class)
    local colors = {
        WARRIOR = "C79C6E", PALADIN = "F58CBA", HUNTER = "ABD473",
        ROGUE = "FFF569", PRIEST = "FFFFFF", DEATHKNIGHT = "C41F3B",
        SHAMAN = "0070DE", MAGE = "69CCF0", WARLOCK = "9482C9",
        DRUID = "FF7D0A",
    }
    return colors[class] or "FFFFFF"
end

function SC.Util.ShortTime(timestamp)
    local diff = time() - timestamp
    if diff < 60 then return "just now" end
    if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
    if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
    return math.floor(diff / 86400) .. "d ago"
end

function SC.Util.PlayerName()
    return UnitName("player")
end
