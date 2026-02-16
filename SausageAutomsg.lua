-- [[ SAUSAGE AUTOMSG - WRATH OF THE LICH KING 3.3.5a ]]
-- Author: Sausage Party / Kokotiar
-- Design System: Sausage Addon Design System

local SAUSAGE_VERSION = "1.1.1"
local ADDON_NAME = "SausageAutomsg"

-- Inicializácia globálnej tabuľky
SausageAutomsgDB = SausageAutomsgDB or {}

local currentTab = 1
local isMasterRunning = false
local timers = {0, 0, 0, 0}
local tabButtons = {}

-- Anti-Spam Fronta
local messageQueue = {}
local queueTimer = 0
local QUEUE_DELAY = 1.5 -- Čakanie 1.5 sekundy medzi jednotlivými správami

-- Helper funkcia na generovanie čistého slotu
local function GetDefaultSlot()
    return {
        enabled = false,
        text = "",
        interval = 60,
        channels = { SAY = false, YELL = false, CH1 = false, CH2 = false, CH3 = false, CH4 = false, CH5 = false, CH6 = false }
    }
end

-- Vizuálna funkcia na prefarbovanie Tabov
local function UpdateTabVisuals()
    if not SausageAutomsgDB.slots then return end
    for i = 1, 4 do
        if SausageAutomsgDB.slots[i] and SausageAutomsgDB.slots[i].enabled then
            tabButtons[i]:SetText("|cff00ff00Msg " .. i .. "|r")
        else
            tabButtons[i]:SetText("|cffffd200Msg " .. i .. "|r")
        end
    end
end

-- [[ UI UTILS ]]
local function CreateSausageBackdrop(frame, borderType)
    local borderColor = {0.6, 0.6, 0.6, 1}
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

local function GetActiveChannelName(index)
    local channels = {GetChannelList()}
    for i = 1, #channels, 2 do
        if channels[i] == index then
            return channels[i] .. ". " .. channels[i+1]
        end
    end
    return index .. ". (Not connected)"
end

-- [[ MAIN FRAME ]]
local MainFrame = CreateFrame("Frame", "SausageAutomsgFrame", UIParent)
MainFrame:SetSize(420, 500)
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
header:SetSize(320, 64)
header:SetPoint("TOP", 0, 12)

local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 0, -14)
title:SetText("SAUSAGE AUTOMSG")

local closeBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -8, -8)

-- [[ TABS ]]
for i = 1, 4 do
    local btn = CreateFrame("Button", "SausageTab"..i, MainFrame, "UIPanelButtonTemplate")
    btn:SetSize(80, 25)
    btn:SetPoint("TOPLEFT", 18 + ((i-1)*90), -40)
    btn:SetText("|cffffd200Msg " .. i .. "|r")
    btn:SetScript("OnClick", function() LoadTab(i) end)
    tabButtons[i] = btn
end

-- NEZÁVISLÝ VYPÍNAČ (Enable Checkbox)
local enableCheck = CreateFrame("CheckButton", "SausageEnableCheck", MainFrame, "UICheckButtonTemplate")
enableCheck:SetPoint("TOPLEFT", 25, -75)
local enableCheckText = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
enableCheckText:SetPoint("LEFT", enableCheck, "RIGHT", 5, 0)

enableCheck:SetScript("OnClick", function(self)
    if SausageAutomsgDB.slots and SausageAutomsgDB.slots[currentTab] then
        local isChecked = self:GetChecked() and true or false
        SausageAutomsgDB.slots[currentTab].enabled = isChecked
        
        UpdateTabVisuals()
        
        local stateText = isChecked and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
        print("|cffffd200Sausage:|r Broadcasting for Msg " .. currentTab .. " is " .. stateText)
    end
end)

-- [[ CONTENT BOXES ]]
-- Message Input Box
local msgContainer = CreateFrame("Frame", nil, MainFrame)
msgContainer:SetSize(370, 120)
msgContainer:SetPoint("TOP", 0, -110)
CreateSausageBackdrop(msgContainer, "BLUE")
msgContainer:EnableMouse(true)

local scrollFrame = CreateFrame("ScrollFrame", "SausageAutomsgScroll", msgContainer, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 8, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)

local editBox = CreateFrame("EditBox", nil, scrollFrame)
editBox:SetMultiLine(true)
editBox:SetMaxLetters(255)
editBox:SetFontObject(ChatFontNormal)
editBox:SetWidth(330)
editBox:SetAutoFocus(false)
scrollFrame:SetScrollChild(editBox)

msgContainer:SetScript("OnMouseDown", function() editBox:SetFocus() end)
editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- Settings Box (Interval & Channels)
local settingsBox = CreateFrame("Frame", nil, MainFrame)
settingsBox:SetSize(370, 180)
settingsBox:SetPoint("TOP", msgContainer, "BOTTOM", 0, -10)
CreateSausageBackdrop(settingsBox, "GRAY")

-- Interval
local intervalLabel = settingsBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
intervalLabel:SetPoint("TOPLEFT", 15, -15)
intervalLabel:SetText("Interval (seconds):")

local intervalInput = CreateFrame("EditBox", "SausageIntervalInput", settingsBox, "InputBoxTemplate")
intervalInput:SetSize(60, 20)
intervalInput:SetPoint("LEFT", intervalLabel, "RIGHT", 10, 0)
intervalInput:SetNumeric(true)
intervalInput:SetAutoFocus(false)
intervalInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- Channels Checkboxes Setup
local function CreateChannelCheck(name, defaultLabel, x, y)
    local cb = CreateFrame("CheckButton", "SausageCB_"..name, settingsBox, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName().."Text"]:SetText(defaultLabel)
    return cb
end

-- 2 Stĺpce kanálov
local cbCh1 = CreateChannelCheck("CH1", "Channel 1", 15, -45)
local cbCh2 = CreateChannelCheck("CH2", "Channel 2", 15, -70)
local cbCh3 = CreateChannelCheck("CH3", "Channel 3", 15, -95)
local cbCh4 = CreateChannelCheck("CH4", "Channel 4", 15, -120)

local cbCh5 = CreateChannelCheck("CH5", "Channel 5", 180, -45)
local cbCh6 = CreateChannelCheck("CH6", "Channel 6", 180, -70)
local cbSay = CreateChannelCheck("SAY", "Say", 180, -95)
local cbYell = CreateChannelCheck("YELL", "Yell", 180, -120)

-- MASTER SAVE TLAČIDLO
local saveBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
saveBtn:SetSize(100, 25)
saveBtn:SetPoint("TOPRIGHT", msgContainer, "TOPRIGHT", 0, 30)
saveBtn:SetText("Save Text")

saveBtn:SetScript("OnClick", function()
    if SausageAutomsgDB.slots and SausageAutomsgDB.slots[currentTab] then
        local slot = SausageAutomsgDB.slots[currentTab]
        
        slot.text = editBox:GetText()
        slot.interval = tonumber(intervalInput:GetText()) or 60
        slot.channels.CH1 = cbCh1:GetChecked() and true or false
        slot.channels.CH2 = cbCh2:GetChecked() and true or false
        slot.channels.CH3 = cbCh3:GetChecked() and true or false
        slot.channels.CH4 = cbCh4:GetChecked() and true or false
        slot.channels.CH5 = cbCh5:GetChecked() and true or false
        slot.channels.CH6 = cbCh6:GetChecked() and true or false
        slot.channels.SAY = cbSay:GetChecked() and true or false
        slot.channels.YELL = cbYell:GetChecked() and true or false
        
        editBox:ClearFocus()
        intervalInput:ClearFocus()
        print("|cffffd200Sausage:|r Settings and text for Msg " .. currentTab .. " successfully saved.")
    end
end)

-- Linkovanie itemov (Shift-Click do EditBoxu)
hooksecurefunc("ChatEdit_InsertLink", function(text)
    if MainFrame:IsShown() and editBox:HasFocus() then
        editBox:Insert(text)
        return true
    end
end)

-- Obnova UI pri prepnutí Tabu
function LoadTab(index)
    if type(SausageAutomsgDB.slots) ~= "table" or not SausageAutomsgDB.slots[index] then return end

    currentTab = index
    local slot = SausageAutomsgDB.slots[index]
    
    for i=1, 4 do
        if i == index then tabButtons[i]:LockHighlight() else tabButtons[i]:UnlockHighlight() end
    end
    
    enableCheckText:SetText("|cffffd200Msg " .. index .. "|r - Enable broadcasting")
    enableCheck:SetChecked(slot.enabled)
    
    editBox:SetText(slot.text or "")
    intervalInput:SetText(slot.interval or 60)
    
    _G["SausageCB_CH1Text"]:SetText(GetActiveChannelName(1))
    _G["SausageCB_CH2Text"]:SetText(GetActiveChannelName(2))
    _G["SausageCB_CH3Text"]:SetText(GetActiveChannelName(3))
    _G["SausageCB_CH4Text"]:SetText(GetActiveChannelName(4))
    _G["SausageCB_CH5Text"]:SetText(GetActiveChannelName(5))
    _G["SausageCB_CH6Text"]:SetText(GetActiveChannelName(6))
    
    cbCh1:SetChecked(slot.channels.CH1)
    cbCh2:SetChecked(slot.channels.CH2)
    cbCh3:SetChecked(slot.channels.CH3)
    cbCh4:SetChecked(slot.channels.CH4)
    cbCh5:SetChecked(slot.channels.CH5)
    cbCh6:SetChecked(slot.channels.CH6)
    cbSay:SetChecked(slot.channels.SAY)
    cbYell:SetChecked(slot.channels.YELL)
end

MainFrame:SetScript("OnShow", function() LoadTab(currentTab) end)

-- [[ ENGINE - LOGIKA ODOSIELANIA (ANTI-SPAM QUEUE) ]]
local function EnqueueMessage(msgText, chatType, channelIndex)
    table.insert(messageQueue, {
        text = msgText,
        chatType = chatType,
        channelIndex = channelIndex
    })
end

local function SendSlotAdvert(slotIndex)
    local slot = SausageAutomsgDB.slots[slotIndex]
    local text = slot.text
    if text == "" then return end

    -- Namiesto okamžitého odoslania, zaradíme správy do fronty
    if slot.channels.SAY then EnqueueMessage(text, "SAY") end
    if slot.channels.YELL then EnqueueMessage(text, "YELL") end
    
    local activeChannels = {GetChannelList()}
    for chNum = 1, 6 do
        if slot.channels["CH"..chNum] then
            for i = 1, #activeChannels, 2 do
                if activeChannels[i] == chNum then
                    EnqueueMessage(text, "CHANNEL", chNum)
                    break
                end
            end
        end
    end
end

local EngineFrame = CreateFrame("Frame")
EngineFrame:SetScript("OnUpdate", function(self, elapsed)
    -- 1. Spracovanie Queue (Odosielanie s oneskorením 1.5s)
    if #messageQueue > 0 then
        queueTimer = queueTimer + elapsed
        if queueTimer >= QUEUE_DELAY then
            local msg = table.remove(messageQueue, 1)
            -- msg.channelIndex je nil pre SAY/YELL, inak číslo kanálu
            SendChatMessage(msg.text, msg.chatType, nil, msg.channelIndex)
            queueTimer = 0
        end
    else
        queueTimer = 0
    end

    -- 2. Kontrola intervalov a pridávanie do Queue
    if not isMasterRunning or type(SausageAutomsgDB.slots) ~= "table" then return end
    
    for i = 1, 4 do
        local slot = SausageAutomsgDB.slots[i]
        if slot and slot.enabled and slot.text ~= "" then
            timers[i] = timers[i] + elapsed
            local interval = tonumber(slot.interval) or 60
            
            if timers[i] >= interval then
                SendSlotAdvert(i)
                timers[i] = 0
            end
        end
    end
end)

-- [[ MASTER START/STOP BUTTON ]]
local startBtn = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
startBtn:SetSize(140, 35)
startBtn:SetPoint("BOTTOMLEFT", 25, 45)
startBtn:SetText("MASTER START")

startBtn:SetScript("OnClick", function(self)
    isMasterRunning = not isMasterRunning
    if isMasterRunning then
        self:SetText("|cff00ff00MASTER STOP|r")
        self:LockHighlight()
        for i=1, 4 do timers[i] = 999 end
        print("|cffffd200Sausage:|r Automsg Engine |cff00ff00STARTED|r")
    else
        self:SetText("MASTER START")
        self:UnlockHighlight()
        messageQueue = {} -- Fail-safe: Vycistí frontu akonáhle zastavíš engine
        print("|cffffd200Sausage:|r Automsg Engine |cffff0000STOPPED|r")
    end
end)

-- [[ UPDATE / GITHUB CUSTOM FRAME ]]
local GitFrame = CreateFrame("Frame", "SausageAutomsgGitFrame", UIParent)
GitFrame:SetSize(320, 130)
GitFrame:SetPoint("CENTER")
GitFrame:SetFrameStrata("DIALOG")
GitFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
tinsert(UISpecialFrames, "SausageAutomsgGitFrame")
GitFrame:Hide()

local gitHeader = GitFrame:CreateTexture(nil, "OVERLAY")
gitHeader:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
gitHeader:SetSize(250, 64)
gitHeader:SetPoint("TOP", 0, 12)

local gitTitle = GitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gitTitle:SetPoint("TOP", gitHeader, "TOP", 0, -14)
gitTitle:SetText("UPDATE LINK")

local gitClose = CreateFrame("Button", nil, GitFrame, "UIPanelCloseButton")
gitClose:SetPoint("TOPRIGHT", -8, -8)

local gitDesc = GitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gitDesc:SetPoint("TOP", 0, -35)
gitDesc:SetText("Press Ctrl+C to copy the GitHub link:")

local gitEditBox = CreateFrame("EditBox", nil, GitFrame, "InputBoxTemplate")
gitEditBox:SetSize(260, 20)
gitEditBox:SetPoint("TOP", gitDesc, "BOTTOM", 0, -15)
gitEditBox:SetAutoFocus(true)

local GITHUB_LINK = "https://github.com/NikowskyWow/SausageAutomsg/releases"

gitEditBox:SetScript("OnTextChanged", function(self)
    if self:GetText() ~= GITHUB_LINK then
        self:SetText(GITHUB_LINK)
        self:HighlightText()
    end
end)

gitEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    GitFrame:Hide()
end)

GitFrame:SetScript("OnShow", function()
    gitEditBox:SetText(GITHUB_LINK)
    gitEditBox:SetFocus()
    gitEditBox:HighlightText()
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
updateBtn:SetScript("OnClick", function()
    GitFrame:Show()
end)

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
        SausageAutomsgDB.minimapPos = SausageAutomsgDB.minimapPos or 45
        
        if type(SausageAutomsgDB.slots) ~= "table" then
            SausageAutomsgDB.slots = { GetDefaultSlot(), GetDefaultSlot(), GetDefaultSlot(), GetDefaultSlot() }
        else
            for i = 1, 4 do
                if type(SausageAutomsgDB.slots[i]) ~= "table" then
                    SausageAutomsgDB.slots[i] = GetDefaultSlot()
                else
                    if type(SausageAutomsgDB.slots[i].channels) ~= "table" then
                        SausageAutomsgDB.slots[i].channels = GetDefaultSlot().channels
                    end
                end
            end
        end

        UpdateMinimapPos()
        UpdateTabVisuals()
        LoadTab(1)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)