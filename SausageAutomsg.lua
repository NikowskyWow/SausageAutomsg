-- [[ SAUSAGE AUTOMSG - WRATH OF THE LICH KING 3.3.5a ]]
-- Author: Sausage Party / Kokotiar
-- Design System: Sausage Addon Design System

local SAUSAGE_VERSION = "1.0.3"
local ADDON_NAME = "SausageAutomsg"

-- Saved Variables Setup
SausageAutomsgDB = SausageAutomsgDB or {
    savedText = "",
    interval = 60,
    channels = {
        ["TRADE"] = true,
        ["LFG"] = false,
        ["GUILD"] = false,
        ["SAY"] = false,
    },
    minimapPos = 45
}

local isRunning = false
local lastSent = 0

-- [[ UI UTILS ]]
local function CreateSausageBackdrop(frame, borderType)
    local borderColor = {0.6, 0.6, 0.6, 1} -- Default Gray
    if borderType == "GOLD" then borderColor = {1, 0.8, 0, 1}
    elseif borderType == "BLUE" then borderColor = {0, 0.7, 1, 1} end

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(unpack(borderColor))
end

-- [[ MAIN FRAME ]]
local MainFrame = CreateFrame("Frame", "SausageAutomsgFrame", UIParent)
MainFrame:SetSize(400, 450)
MainFrame:SetPoint("CENTER")
MainFrame:SetMovable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
tinsert(UISpecialFrames, "SausageAutomsgFrame")
MainFrame:Hide()

-- Header
local header = MainFrame:CreateTexture(nil, "OVERLAY")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetSize(300, 64)
header:SetPoint("TOP", 0, 12)

local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 0, -14)
title:SetText("SAUSAGE AUTOMSG")

-- Close Button
local closeBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -8, -8)

-- [[ CONTENT BOXES ]]
-- Message Input Box
local msgContainer = CreateFrame("Frame", nil, MainFrame)
msgContainer:SetSize(360, 120)
msgContainer:SetPoint("TOP", 0, -60)
CreateSausageBackdrop(msgContainer, "BLUE")

local scrollFrame = CreateFrame("ScrollFrame", "SausageAutomsgScroll", msgContainer, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 8, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)

local editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetMultiLine(true)
editBox:SetMaxLetters(255)
editBox:SetFontObject(ChatFontNormal)
editBox:SetWidth(320)
scrollFrame:SetScrollChild(editBox)
editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- Settings Box (Interval & Channels)
local settingsBox = CreateFrame("Frame", nil, MainFrame)
settingsBox:SetSize(360, 140)
settingsBox:SetPoint("TOP", msgContainer, "BOTTOM", 0, -10)
CreateSausageBackdrop(settingsBox, "GRAY")

-- Interval Label & Input
local intervalLabel = settingsBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
intervalLabel:SetPoint("TOPLEFT", 15, -15)
intervalLabel:SetText("Interval (seconds):")

local intervalInput = CreateFrame("EditBox", "SausageIntervalInput", settingsBox, "InputBoxTemplate")
intervalInput:SetSize(60, 20)
intervalInput:SetPoint("LEFT", intervalLabel, "RIGHT", 10, 0)
intervalInput:SetNumeric(true)
intervalInput:SetAutoFocus(false)
intervalInput:SetScript("OnTextChanged", function(self)
    local val = tonumber(self:GetText())
    if val then SausageAutomsgDB.interval = val end
end)

-- Channels Checkboxes
local function CreateChannelCheck(name, label, x, y)
    local cb = CreateFrame("CheckButton", "SausageCB_"..name, settingsBox, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName().."Text"]:SetText(label)
    cb:SetScript("OnClick", function(self) SausageAutomsgDB.channels[name] = self:GetChecked() end)
    return cb
end

local cbTrade = CreateChannelCheck("TRADE", "Trade (2)", 15, -45)
local cbLFG = CreateChannelCheck("LFG", "LFG (4)", 100, -45)
local cbGuild = CreateChannelCheck("GUILD", "Guild", 15, -75)
local cbSay = CreateChannelCheck("SAY", "Say", 100, -75)

-- [[ LOGIC ]]
local function SendAdvert()
    local text = editBox:GetText()
    if text == "" then return end

    local channels = SausageAutomsgDB.channels
    if channels.SAY then SendChatMessage(text, "SAY") end
    if channels.GUILD and IsInGuild() then SendChatMessage(text, "GUILD") end
    
    -- Warmane Global Channels (Dynamic ID search)
    if channels.TRADE then
        local id = GetChannelName("Trade - City")
        if id > 0 then SendChatMessage(text, "CHANNEL", nil, id) end
    end
    if channels.LFG then
        local id = GetChannelName("LookingForGroup")
        if id > 0 then SendChatMessage(text, "CHANNEL", nil, id) end
    end
end

-- Engine
local EngineFrame = CreateFrame("Frame")
EngineFrame:SetScript("OnUpdate", function(self, elapsed)
    if not isRunning then return end
    lastSent = lastSent + elapsed
    local interval = tonumber(SausageAutomsgDB.interval) or 60
    
    if lastSent >= interval then
        SendAdvert()
        lastSent = 0
    end
end)

-- [[ BUTTONS ]]
local startBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
startBtn:SetSize(120, 30)
startBtn:SetPoint("BOTTOMLEFT", 25, 50)
startBtn:SetText("START")
startBtn:SetScript("OnClick", function(self)
    isRunning = not isRunning
    self:SetText(isRunning and "STOP" or "START")
    lastSent = 999 -- Okamžité odoslanie pri štarte
    print("|cffffd200Sausage:|r Automsg is now " .. (isRunning and "|cff00ff00Running|r" or "|cffff0000Stopped|r"))
end)

local saveBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
saveBtn:SetSize(100, 25)
saveBtn:SetPoint("TOPRIGHT", msgContainer, "TOPRIGHT", 0, 30)
saveBtn:SetText("Save Text")
saveBtn:SetScript("OnClick", function()
    SausageAutomsgDB.savedText = editBox:GetText()
    print("|cffffd200Sausage:|r Text uložený.")
end)

-- [[ FOOTER ]]
local verText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
verText:SetPoint("BOTTOMLEFT", 20, 15)
verText:SetText("v" .. SAUSAGE_VERSION)

local creditText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
creditText:SetPoint("BOTTOM", 0, 15)
creditText:SetText("by Sausage Party")

local updateBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
updateBtn:SetSize(110, 25)
updateBtn:SetPoint("BOTTOMRIGHT", -20, 15)
updateBtn:SetText("Check Updates")

-- [[ MINIMAP ICON ]]
local MinimapBtn = CreateFrame("Button", "SausageAutomsgMinimap", Minimap)
MinimapBtn:SetSize(31, 31)
MinimapBtn:SetFrameLevel(8)
MinimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = MinimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Inv_Misc_Food_54")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 0)

local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT", 0, 0)

local function UpdateMinimapPos()
    local angle = rad(SausageAutomsgDB.minimapPos or 45)
    MinimapBtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * cos(angle)), (80 * sin(angle)) - 52)
end

MinimapBtn:RegisterForDrag("RightButton")
MinimapBtn:SetScript("OnDragStart", function(self) self.isDragging = true end)
MinimapBtn:SetScript("OnDragStop", function(self) self.isDragging = false end)
MinimapBtn:SetScript("OnUpdate", function(self)
    if self.isDragging then
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        xpos = xmin - xpos / Minimap:GetEffectiveScale() + 70
        ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70
        SausageAutomsgDB.minimapPos = deg(atan2(ypos, xpos))
        UpdateMinimapPos()
    end
end)
MinimapBtn:SetScript("OnClick", function(self, btn)
    if btn == "LeftButton" then
        if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
    end
end)

-- [[ INITIALIZATION ]]
MainFrame:RegisterEvent("ADDON_LOADED")
MainFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == ADDON_NAME then
        intervalInput:SetText(SausageAutomsgDB.interval or 60)
        cbTrade:SetChecked(SausageAutomsgDB.channels.TRADE)
        cbLFG:SetChecked(SausageAutomsgDB.channels.LFG)
        cbGuild:SetChecked(SausageAutomsgDB.channels.GUILD)
        cbSay:SetChecked(SausageAutomsgDB.channels.SAY)
        if SausageAutomsgDB.savedText then editBox:SetText(SausageAutomsgDB.savedText) end
        UpdateMinimapPos()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- [[ SLASH COMMANDS ]]
SLASH_SAUSAGEAUTOMSG1 = "/sam"
SLASH_SAUSAGEAUTOMSG2 = "/automsg"
SlashCmdList["SAUSAGEAUTOMSG"] = function()
    if MainFrame:IsShown() then MainFrame:Hide() else MainFrame:Show() end
end