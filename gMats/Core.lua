local SC = gMats

-- ============ PRINT HELPER ============

function SC:Print(msg, r, g, b)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33aaff[gMats]|r " .. (msg or ""), r or 1, g or 1, b or 1)
end

-- ============ MAIN EVENT FRAME ============

local eventFrame = CreateFrame("Frame", "gMatsEventFrame", UIParent)
local syncTimer = nil
local syncDelay = 5 -- seconds after login before requesting sync

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "gMats" then
            SC:OnAddonLoaded()
        end
    elseif event == "PLAYER_LOGIN" then
        SC:OnPlayerLogin()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        SC.Comm:OnAddonMessage(prefix, message, channel, sender)
    end
end)

-- ============ INITIALIZATION ============

function SC:OnAddonLoaded()
    SC.DataModel:Init()
    SC.Comm:Init()
    SC:Print("v1.0 loaded. Type /gmat to open the guild bounty board.")
end

function SC:OnPlayerLogin()
    -- Create UI components
    SC.UI.MinimapButton:Create()
    SC.UI.MainWindow:Create()
    SC.UI.BrowseBoard:Create()
    SC.Tooltips:Init()
    SC.BagHighlight:Init()
    SC.UI.MailIntegration:Init()

    -- Request sync after delay
    syncTimer = 0
    eventFrame:SetScript("OnUpdate", function(self, elapsed)
        if not syncTimer then return end
        syncTimer = syncTimer + elapsed
        if syncTimer >= syncDelay then
            syncTimer = nil
            SC.Comm:RequestSync()
        end
    end)
end

-- ============ TOGGLE WINDOW ============

function SC:ToggleMainWindow()
    SC.UI.MainWindow:Toggle()
end

-- ============ SLASH COMMANDS ============

SLASH_GMATS1 = "/gmat"
SLASH_GMATS2 = "/gmats"

SlashCmdList["GMATS"] = function(msg)
    msg = SC.Util.Trim(msg or "")

    if msg == "" or msg == "open" then
        SC:ToggleMainWindow()
    elseif msg == "status" then
        local count = SC.DataModel:CountActive()
        SC:Print("Active requests on the board: " .. count)
        SC:Print("Tooltips: " .. (gMatsDB.settings.tooltipsEnabled and "ON" or "OFF"))
        SC:Print("Alerts: " .. (gMatsDB.settings.alertsEnabled and "ON" or "OFF"))
        SC:Print("Bag highlights: " .. (gMatsDB.settings.bagHighlightsEnabled and "ON" or "OFF"))
    elseif msg == "tooltips" then
        gMatsDB.settings.tooltipsEnabled = not gMatsDB.settings.tooltipsEnabled
        SC:Print("Tooltips " .. (gMatsDB.settings.tooltipsEnabled and "enabled" or "disabled"))
    elseif msg == "alerts" then
        gMatsDB.settings.alertsEnabled = not gMatsDB.settings.alertsEnabled
        SC:Print("Alerts " .. (gMatsDB.settings.alertsEnabled and "enabled" or "disabled"))
    elseif msg == "highlights" then
        gMatsDB.settings.bagHighlightsEnabled = not gMatsDB.settings.bagHighlightsEnabled
        SC:Print("Bag highlights " .. (gMatsDB.settings.bagHighlightsEnabled and "enabled" or "disabled"))
        if gMatsDB.settings.bagHighlightsEnabled then
            SC.BagHighlight:UpdateAllVisible()
        else
            SC.BagHighlight:ClearAllHighlights()
        end
    elseif msg == "sync" then
        SC.Comm:RequestSync()
    elseif msg == "help" then
        SC:Print("Commands:")
        SC:Print("  /gmat - Toggle bounty board window")
        SC:Print("  /gmat status - Show addon status")
        SC:Print("  /gmat tooltips - Toggle tooltip notifications")
        SC:Print("  /gmat alerts - Toggle loot alert notifications")
        SC:Print("  /gmat highlights - Toggle bag item highlights")
        SC:Print("  /gmat sync - Force board sync from guild")
        SC:Print("  /gmat help - Show this help")
    else
        SC:Print("Unknown command. Type /gmat help for options.")
    end
end
