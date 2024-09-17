local addonName, ts = ...

local _G = _G
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local SetItemButtonTexture = SetItemButtonTexture
local UnitLevel = UnitLevel
local LearnTalent = LearnTalent
local CreateFrame = CreateFrame
local IsAddOnLoaded = IsAddOnLoaded
local StaticPopup_Show = StaticPopup_Show
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = FauxScrollFrame_Update
local hooksecurefunc = hooksecurefunc
local format = format
local ceil = ceil
local strfind = strfind
local GREEN_FONT_COLOR = GREEN_FONT_COLOR
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
local RED_FONT_COLOR = RED_FONT_COLOR
local GRAY_FONT_COLOR = GRAY_FONT_COLOR

local TALENT_ROW_HEIGHT = 38
local MAX_TALENT_ROWS = 7
local SEQUENCES_ROW_HEIGHT = 26
local MAX_SEQUENCE_ROWS = 5
local SCROLLING_WIDTH = 102
local NONSCROLLING_WIDTH = 84
local IMPORT_DIALOG = "TALENTSEQUENCEIMPORTDIALOG"
local LEVEL_WIDTH = 20
local UsingTalented = false

IsTalentSequenceExpanded = false
TalentSequenceTalents = {}

StaticPopupDialogs[IMPORT_DIALOG] = {
    text = ts.L.IMPORT_DIALOG,
    hasEditBox = true,
    button1 = ts.L.OK,
    button2 = ts.L.CANCEL,
    OnShow = function(self) _G[self:GetName() .. "EditBox"]:SetText("") end,
    OnAccept = function(self)
        local talentsString = self.editBox:GetText()
        ts:ImportTalents(talentsString)
    end,
    EditBoxOnEnterPressed = function(self)
        local talentsString =
            _G[self:GetParent():GetName() .. "EditBox"]:GetText()
        ts:ImportTalents(talentsString)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

-- tooltip object used when hovering over talents
local tooltip = CreateFrame("GameTooltip", "TalentSequenceTooltip", UIParent, "GameTooltipTemplate")

-- Saves a talent sequence
local function InsertSequence(talentSequence)
    local tabTotals = {0, 0, 0}
    for _, talent in ipairs(talentSequence) do
        tabTotals[talent.tab] = tabTotals[talent.tab] + 1
    end
    local points = string.format("%d/%d/%d", unpack(tabTotals))
    table.insert(TalentSequenceSavedSequences, {name = "<unnamed>", talents = talentSequence, points = points})
end

-- Loads the dictionary with all of the available talents for the user; used when parsing the wowhead / icyveins strings
local function GetTalentDictionary()
  local tabOne = {}
  local tabTwo = {}
  local tabThree = {}
  local dict = { tabOne, tabTwo, tabThree }
  for i = 1, GetNumTalentTabs() do
    for j = 1, GetNumTalents(i) do
      local name, icon, row, column, currentRank, maxRank = GetTalentInfo(i, j)
      talent = { name = name, icon = icon, currentRank = currentRank, maxRank = maxRank, index = j, tab = i, row = row, column = column }
      if talent.name then
        table.insert(dict[i], talent)
      end
    end
  end
  table.sort(dict[1], function (k1, k2) return (k1.row < k2.row or (k1.row == k2.row and k1.column < k2.column)) end)
  table.sort(dict[2], function (k1, k2) return (k1.row < k2.row or (k1.row == k2.row and k1.column < k2.column)) end)
  table.sort(dict[3], function (k1, k2) return (k1.row < k2.row or (k1.row == k2.row and k1.column < k2.column)) end)
  for i = 1, GetNumTalentTabs() do
    for j = 1, GetNumTalents(i) do
      talent = dict[i][j]
    end
  end
  return dict
end

-- Handles whena  user pastes in the talent string and imports them into the set of sequences
function ts:ImportTalents(talentsString)
    local talents = {}
    local isWowhead = strfind(talentsString,"wowhead")
    local talents = nil
    local talentDict = GetTalentDictionary()
    if (isWowhead) then 
        talents = ts.WowheadTalents.GetTalents(talentsString, talentDict)
    else
        talents = ts.IcyVeinsTalents.GetTalents(talentsString, talentDict)
    end
    if (talents == nil) then return end
    InsertSequence(talents)
    if (self.ImportFrame and self.ImportFrame:IsShown()) then
        local scrollBar = self.ImportFrame.scrollBar
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, SEQUENCES_ROW_HEIGHT)
        ts:UpdateSequencesFrame()
        ts.ImportFrame.rows[#TalentSequenceSavedSequences]:SetForRename()
    end
end

-- When the user clicks a specific sequence, this loads the talents and then updates the main frame icons
function ts:LoadTalentSequence(talents)
    if (talents == nil) then return end
    ts.Talents = talents
    TalentSequenceTalents = ts.Talents
    if (self.MainFrame and self.MainFrame:IsShown()) then
        local scrollBar = self.MainFrame.scrollBar
        local numTalents = #ts.Talents
        FauxScrollFrame_Update(scrollBar, numTalents, MAX_TALENT_ROWS, TALENT_ROW_HEIGHT)
        ts.MainFrame_RefreshTalents()
        ts.MainFrame_JumpToUnlearnedTalents()
    end
    ts.AddTalentCounts()
end

function ts:ResetTalentHints()
    for tab = 1, GetNumTalentTabs() do
        for index = 1, GetNumTalents(tab) do
            local prefix = "PlayerTalentFramePanel"..tab.."Talent"..index
            local talentRankText = _G[prefix.."Rank"]
            local talentRankBorder = _G[prefix.."RankBorder"]
            local talentRankBorderGreen = _G[prefix.."RankBorderGreen"]
            local talentHint = _G[prefix.."Hint"]

            talentRankBorder:SetSize(18,18)
            talentRankBorderGreen:SetSize(18,18)
        end
    end
end

-- funciton replaces the text on all the talents which normally show the current rank count, to reflect the current rank / desired count
-- future talents are in grey, maxed out talents are default color, talents which haven't been learned but should have are red, talents not maxed but in sync are green
function ts:AddTalentCounts()
    if PlayerTalentFrame.talentGroup ~= GetActiveTalentGroup(false, false) then
        ts:ResetTalentHints()
        return
    end
    local playerLevel = UnitLevel("player")
    local sumTalents = {}
    for index, talent in pairs(ts.Talents) do
        local k = "T"..talent.tab.."I"..talent.index
        if sumTalents[k] == nil then
            sumTalents[k] = { desiredCount = 1, talent = talent, counts = { talent.level }}
        else
            curCounts = sumTalents[k]
            curCounts.desiredCount = curCounts.desiredCount + 1
            tinsert(curCounts.counts, talent.level)
        end
    end

    for tab = 1, GetNumTalentTabs() do
        for index = 1, GetNumTalents(tab) do
            local name, _, _, _, currentRank, maxRank = GetTalentInfo(tab, index)

            local k = "T"..tab.."I"..index
            local prefix = "PlayerTalentFramePanel"..tab.."Talent"..index
            local talentRankText = _G[prefix.."Rank"]
            local talentRankBorder = _G[prefix.."RankBorder"]
            local talentRankBorderGreen = _G[prefix.."RankBorderGreen"]
            local talentHint = _G[prefix.."Hint"]

            if sumTalents[k] then
                local desiredTalent = sumTalents[k]
                local talent = sumTalents[k].talent
                local desiredCount = sumTalents[k].desiredCount
                -- talent rank is not at the max we want
                if desiredCount > 0 and currentRank < desiredCount then
                    local color = "cff999999"
                    if (currentRank == 0 and playerLevel > desiredTalent.counts[1]) or (currentRank > 0 and playerLevel > desiredTalent.counts[currentRank + 1]) then
                        color = "cffff3333"
                    elseif (currentRank > 0 and playerLevel < desiredTalent.counts[currentRank]) then
                        color = "cffaaaaaa"
                    elseif (currentRank > 0 and playerLevel >= desiredTalent.counts[currentRank]) then
                        color = "cff00ff00"
                    end
                    
                    if not talentRankText:IsVisible() then
                        talentRankText:SetText("|"..color..currentRank.."/"..desiredCount.."|r")
                        talentRankText:Show()
                        talentRankBorder:Show()
                    else
                        talentRankText:SetText("|"..color..currentRank.."/"..desiredCount.."|r")
                    end
                    talentRankBorder:SetSize(36,18)
                    talentRankBorderGreen:SetSize(36,18)
                -- talent rank is at the max we want
                elseif desiredCount > 0 and currentRank == desiredCount then
                    talentRankText:SetText("|cffffd700"..currentRank.."/"..desiredCount.."|r")
                    talentRankBorder:SetSize(36,18)
                    talentRankBorder:Show()
                    talentRankBorderGreen:Hide()
                -- talent rank exceeds the max we want
                elseif currentRank > desiredCount then
                    talentRankText:SetText(currentRank.."|cffaaaaaa/|r|cffff0000"..desiredCount.."|r")
                    talentRankBorder:SetSize(36,18)
                    talentRankBorderGreen:SetSize(36,18)
                else
                    --talentRankBorder:SetSize(18,18)
                    --talentRankBorderGreen:SetSize(18,18)
                end
            else
                if currentRank == 0 then
                    talentRankText:Hide()
                    talentRankBorder:Hide()
                    talentRankBorderGreen:Hide()
                else
                    talentRankBorder:SetSize(18,18)
                    talentRankBorderGreen:SetSize(18,18)
                    talentRankText:SetText("|cffff3333"..currentRank.."|r")
                    talentRankText:Show()
                    talentRankBorder:Show()
                    talentRankBorderGreen:Hide()
                end
            end
        end
    end
end

-- Updates the list of sequences available on the import frame
function ts:UpdateSequencesFrame()
    local frame = self.ImportFrame
    frame:ShowAllLoadButtons()
    FauxScrollFrame_Update(frame.scrollBar, #TalentSequenceSavedSequences, MAX_SEQUENCE_ROWS, SEQUENCES_ROW_HEIGHT, nil, nil, nil, nil, nil, nil, true)
    local offset = FauxScrollFrame_GetOffset(frame.scrollBar)
    for i = 1, MAX_SEQUENCE_ROWS do
        local index = i + offset
        local row = frame.rows[i]
        row:SetSequence(TalentSequenceSavedSequences[index])
    end
end

-- Creates the import frame
function ts.CreateImportFrame()
    local sequencesFrame = CreateFrame("Frame", "TalentSequences", UIParent, "BasicFrameTemplateWithInset")
    sequencesFrame:Hide()
    sequencesFrame:SetScript("OnShow", function() ts:UpdateSequencesFrame() end)
    sequencesFrame:SetSize(325, 312)
    sequencesFrame:SetPoint("CENTER")
    sequencesFrame:SetMovable(true)
    sequencesFrame:SetClampedToScreen(true)
    sequencesFrame:SetScript("OnMouseDown", sequencesFrame.StartMoving)
    sequencesFrame:SetScript("OnMouseUp", sequencesFrame.StopMovingOrSizing)
    sequencesFrame.TitleText:SetText("Talent Sequences")
    function sequencesFrame:ShowAllLoadButtons()
        for _, row in ipairs(self.rows) do row:SetForLoad() end
    end
    tinsert(UISpecialFrames, "TalentSequences")
    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", sequencesFrame, "FauxScrollFrameTemplate")
    scrollBar:SetPoint("TOPLEFT", sequencesFrame.InsetBg, "TOPLEFT", 5, -60)
    scrollBar:SetPoint("BOTTOMRIGHT", sequencesFrame.InsetBg, "BOTTOMRIGHT", -28, 28)

    sequencesFrame.scrollBar = scrollBar
    local sequenceNames = {} for _, obj in ipairs(TalentSequenceSavedSequences) do table.insert(sequenceNames, obj.name) end

    -- Create the dropdown for player's primary spec
    local talent1Label = sequencesFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
    talent1Label:SetPoint("TOPLEFT", sequencesFrame, "TOPLEFT", 10, -35)
    talent1Label:SetText("Active with Primary Spec:")
    local talent1opts = {
        ['name']='talent1dd',
        ['parent']=sequencesFrame,
        ['title']='',
        ['items']= sequenceNames,
        ['width']=135,
        ['defaultIndex']= (SpecSequenceIndex and SpecSequenceIndex[1] and SpecSequenceIndex[1] > 0 and SpecSequenceIndex[1] <= #TalentSequenceSavedSequences) and SpecSequenceIndex[1] or 0, 
        ['changeFunc']=function(dropdown_frame, dropdown_val, arg1)
            if not SpecSequenceIndex then SpecSequenceIndex = {} end
            SpecSequenceIndex[1] = arg1
        end
    }
    talent1DropDown = ts.CreateDropdown(talent1opts)
    talent1DropDown:SetPoint("TOPRIGHT", sequencesFrame, "TOPRIGHT", 0, -25)

    -- Create the dropdown for the player's secondary spec
    local talent2Label = sequencesFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite")
    talent2Label:SetPoint("TOPLEFT", sequencesFrame, "TOPLEFT", 10, -60)
    talent2Label:SetText("Active with Secondary Spec:")
    local talent2opts = {
        ['name']='talent2dd',
        ['parent']=sequencesFrame,
        ['title']='',
        ['items']= sequenceNames,
        ['width']=135,
        ['defaultIndex']= (SpecSequenceIndex and SpecSequenceIndex[2] and SpecSequenceIndex[2] > 0 and SpecSequenceIndex[2] <= #TalentSequenceSavedSequences) and SpecSequenceIndex[2] or 0, 
        ['changeFunc']=function(dropdown_frame, dropdown_val, arg1)
            if not SpecSequenceIndex then SpecSequenceIndex = {} end
            SpecSequenceIndex[2] = arg1
        end
    }
    local talent2DropDown = ts.CreateDropdown(talent2opts)
    talent2DropDown:SetPoint("TOPRIGHT", sequencesFrame, "TOPRIGHT", 0, -50)

    local importButton = CreateFrame("Button", nil, sequencesFrame, "UIPanelButtonTemplate")
    importButton:SetPoint("BOTTOM", 0, 8)
    importButton:SetSize(75, 24)
    importButton:SetText("Import")
    importButton:SetNormalFontObject("GameFontNormal")
    importButton:SetHighlightFontObject("GameFontHighlight")
    importButton:SetScript("OnClick", function() StaticPopup_Show(IMPORT_DIALOG) end)

    local rows = {}
    for i = 1, MAX_SEQUENCE_ROWS do
        local row = CreateFrame("Frame", "$parentRow" .. i, sequencesFrame)
        row.index = i
        row:SetPoint("RIGHT", scrollBar)
        row:SetPoint("LEFT", scrollBar)
        row:SetHeight(SEQUENCES_ROW_HEIGHT)

        local nameInput = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        nameInput:SetPoint("TOP")
        nameInput:SetPoint("BOTTOM")
        nameInput:SetPoint("LEFT")
        nameInput:SetWidth(150)
        nameInput:SetAutoFocus(false)

        local namedLoadButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        namedLoadButton:SetPoint("TOPLEFT", nameInput, "TOPLEFT", -6, 0)
        namedLoadButton:SetPoint("BOTTOMRIGHT", nameInput, "BOTTOMRIGHT")
        nameInput:Hide()

        local talentAmountString = row:CreateFontString(nil, "ARTWORK", "GameFontWhite")
        talentAmountString:SetPoint("LEFT", nameInput, "RIGHT")

        function row:SetSequence(sequence)
            if (sequence == nil) then
                self:Hide()
            else
                self:Show()
                namedLoadButton:SetText(sequence.name)
                talentAmountString:SetText(sequence.points)
            end
        end

        local deleteButton = CreateFrame("Button", nil, row)
        deleteButton:EnableMouse(true)
        deleteButton:SetPoint("RIGHT")
        deleteButton:SetPoint("TOP")
        deleteButton:SetPoint("BOTTOM")
        deleteButton:SetWidth(SEQUENCES_ROW_HEIGHT)

        local delete = row:CreateTexture(nil, "ARTWORK")
        delete:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        delete:SetAllPoints(deleteButton)
        delete:SetVertexColor(1, 1, 1, 0.5)

        local renameButton = CreateFrame("Button", nil, row)
        renameButton:EnableMouse(true)
        renameButton:SetPoint("TOP")
        renameButton:SetPoint("BOTTOM")
        renameButton:SetPoint("RIGHT", delete, "LEFT")
        renameButton:SetWidth(SEQUENCES_ROW_HEIGHT)

        talentAmountString:SetPoint("RIGHT", renameButton, "LEFT")

        local rename = row:CreateTexture(nil, "ARTWORK")
        rename:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        rename:SetAllPoints(renameButton)
        rename:SetVertexColor(1, 1, 1, 0.5)

        nameInput:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            self:Hide()
            namedLoadButton:Show()
        end)
        nameInput:SetScript("OnEnterPressed", function(self)
            local offset = FauxScrollFrame_GetOffset(scrollBar)
            local index = offset + self:GetParent().index
            local inputText = self:GetText()
            local newName = (inputText and inputText ~= "") and inputText or ts.L.UNNAMED
            TalentSequenceSavedSequences[index].name = newName

            namedLoadButton:Show()
            self:Hide()
            ts:UpdateSequencesFrame()
            sequenceNames = {} for _, obj in ipairs(TalentSequenceSavedSequences) do table.insert(sequenceNames, obj.name) end
            talent1DropDown:Update(sequenceNames)
            talent2DropDown:Update(sequenceNames)
        end)
        namedLoadButton:SetScript("OnEnter", function(self)
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
            tooltip:SetText(ts.L.LOAD_SEQUENCE_TIP)
            tooltip:Show()
        end)
        namedLoadButton:SetScript("OnLeave", function() tooltip:Hide() end)
        namedLoadButton:SetScript("OnClick", function(self)
            local offset = FauxScrollFrame_GetOffset(scrollBar)
            local index = offset + self:GetParent().index
            TalentSequenceTalentsIndex = index
            local sequence = TalentSequenceSavedSequences[index]
            ts:LoadTalentSequence(sequence.talents)
        end)
        local function onIconButtonEnter(tooltipText, button, icon)
            icon:SetVertexColor(1, 1, 1, 1)
            tooltip:SetOwner(button, "ANCHOR_RIGHT")
            tooltip:SetText(tooltipText)
            tooltip:Show()
        end
        local function onIconButtonLeave(icon)
            icon:SetVertexColor(1, 1, 1, 0.5)
            tooltip:Hide()
        end
        deleteButton:SetScript("OnEnter", function(self)
            onIconButtonEnter(ts.L.DELETE_TIP, self, delete)
        end)
        deleteButton:SetScript("OnLeave", function()
            onIconButtonLeave(delete)
        end)
        renameButton:SetScript("OnEnter", function(self)
            onIconButtonEnter(ts.L.RENAME_TIP, self, rename)
        end)
        renameButton:SetScript("OnLeave", function()
            onIconButtonLeave(rename)
        end)
        deleteButton:SetScript("OnClick", function(self)
            if (not IsShiftKeyDown()) then return end
            local offset = FauxScrollFrame_GetOffset(scrollBar)
            local index = offset + self:GetParent().index
            for i, si in ipairs(SpecSequenceIndex) do
                if si == index then SpecSequenceIndex[i] = nil end
                if si > index then SpecSequenceIndex[i] = si - 1 end
            end
            if TalentSequenceTalentsIndex and TalentSequenceTalentsIndex == index then TalentSequenceTalentsIndex = nil end
            if TalentSequenceTalentsIndex and TalentSequenceTalentsIndex > index then TalentSequenceTalentsIndex = TalentSequenceTalentsIndex - 1 end
            talent1DropDown:Remove(index)
            talent2DropDown:Remove(index)
            tremove(TalentSequenceSavedSequences, index)
            ts:UpdateSequencesFrame()
        end)
        renameButton:SetScript("OnClick", function(self)
            self:GetParent():SetForRename()
        end)

        function row:SetForRename()
            local offset = FauxScrollFrame_GetOffset(scrollBar)
            local index = offset + self.index
            namedLoadButton:Hide()
            nameInput:SetText(TalentSequenceSavedSequences[index].name)
            nameInput:Show()
            nameInput:SetFocus()
            nameInput:HighlightText()
        end
        function row:SetForLoad()
            nameInput:ClearFocus()
            nameInput:Hide()
            namedLoadButton:Show()
        end

        if (rows[i - 1] == nil) then
            row:SetPoint("TOPLEFT", scrollBar, 5, -6)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end
        rawset(rows, i, row)
    end
    sequencesFrame.rows = rows

    scrollBar:SetScript("OnVerticalScroll", 
        function(self, offset)
            FauxScrollFrame_OnVerticalScroll(self, offset, SEQUENCES_ROW_HEIGHT,
            function()
                ts:UpdateSequencesFrame()
            end)
        end)
    scrollBar:SetScript("OnShow", function() ts:UpdateSequencesFrame() end)

    ts.ImportFrame = sequencesFrame
end

-- Creates the sequence frame and attaches it to the talents frame
function ts.CreateMainFrame()
    local mainFrame = CreateFrame("Frame", nil, _G["PlayerTalentFrame"], BackdropTemplateMixin and "BackdropTemplate")
    mainFrame:EnableMouse(true)
    mainFrame:SetMouseClickEnabled(true)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetSize(128, 128)
    mainFrame:SetPoint("TOPLEFT", "PlayerTalentFrame", "TOPRIGHT", 0, -130)
    mainFrame:SetPoint("BOTTOMLEFT", "PlayerTalentFrame", "BOTTOMRIGHT", 0, 18)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })

    mainFrame:SetBackdropColor(0, 0, 0, 1)
    mainFrame:SetScript("OnShow", function(self)
        ts.MainFrame_JumpToUnlearnedTalents()
    end)
    mainFrame:SetScript("OnHide", function(self)
        if (ts.ImportFrame and ts.ImportFrame:IsShown()) then
            ts.ImportFrame:Hide()
        end
    end)

    mainFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    mainFrame:RegisterEvent("SPELLS_CHANGED")
    mainFrame:SetScript("OnEvent", function(self, event)
        if (((event == "CHARACTER_POINTS_CHANGED") or
            (event == "SPELLS_CHANGED")) and self:IsVisible()) then
            ts.MainFrame_JumpToUnlearnedTalents()
        end
    end)
    
    mainFrame:Hide()
    ts.MainFrame = mainFrame
end

-- Creates and anchors the scrollbar to the sequence/main frame
function ts.MainFrame_AddScrollBar()
    local scrollBar = CreateFrame("ScrollFrame", "$parentScrollBar", ts.MainFrame, "FauxScrollFrameTemplate")
    scrollBar:SetPoint("TOPLEFT", 0, -6)
    scrollBar:SetPoint("BOTTOMRIGHT", -26, 5)
    scrollBar:SetScript("OnVerticalScroll", ts.MainFrame_OnVerticalScroll)
    scrollBar:SetScript("OnShow", ts.MainFrame_RefreshTalents)
    ts.MainFrame.scrollBar = scrollBar
end

-- Handles the scroll event for the main frame
function ts.MainFrame_OnVerticalScroll(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, TALENT_ROW_HEIGHT, function() 
        ts.MainFrame_RefreshTalents() 
    end)
end

-- Adds the UI elements for showing the talent sequences to the main frame
function ts.MainFrame_AddTalentRows()
    local rows = {}
    for i = 1, MAX_TALENT_ROWS do
        local row = CreateFrame("Frame", "$parentRow" .. i, ts.MainFrame)
        row:SetWidth(110)
        row:SetHeight(TALENT_ROW_HEIGHT)

        local level = CreateFrame("Frame", "$parentLevel", row)
        level:SetWidth(LEVEL_WIDTH)
        level:SetPoint("LEFT", row, "LEFT")
        level:SetPoint("TOP", row, "TOP")
        level:SetPoint("BOTTOM", row, "BOTTOM")

        local levelLabel = level:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        levelLabel:SetPoint("TOPLEFT", level, "TOPLEFT")
        levelLabel:SetPoint("BOTTOMRIGHT", level, "BOTTOMRIGHT")
        level.label = levelLabel

        local icon = CreateFrame("Button", "$parentIcon", row, "ItemButtonTemplate")
        icon:SetWidth(37)
        icon:SetPoint("LEFT", level, "RIGHT", 4, 0)
        icon:SetPoint("TOP", level, "TOP")
        icon:SetPoint("BOTTOM", level, "BOTTOM")
        icon:EnableMouse(true)
        icon:SetScript("OnClick", ts.MainFrame_LearnTalent)
        icon:SetScript("OnEnter", ts.MainFrame_SetTalentTooltip)
        icon:SetScript("OnLeave", function() tooltip:Hide() end)

        local rankBorderTexture = icon:CreateTexture(nil, "OVERLAY")
        rankBorderTexture:SetWidth(32)
        rankBorderTexture:SetHeight(32)
        rankBorderTexture:SetPoint("CENTER", icon, "BOTTOMRIGHT")
        rankBorderTexture:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")
        
        local rankText = icon:CreateFontString(nil, "OVERLAY","GameFontNormalSmall")
        rankText:SetPoint("CENTER", rankBorderTexture)
        icon.rank = rankText
        row.icon = icon
        row.level = level

        if (rows[i - 1] == nil) then
            row:SetPoint("TOPLEFT", ts.MainFrame, 8, -8)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2)
        end

        function row:SetTalent(talent)
            if (not talent) then
                self:Hide()
                self.talent = nil
                return
            end

            self:Show()
            self.talent = talent
            local name, icon, _, _, currentRank, maxRank = GetTalentInfo(talent.tab, talent.index)

            SetItemButtonTexture(self.icon, icon)
            local tabName = GetTalentTabInfo(talent.tab)
            local link = GetTalentLink(talent.tab, talent.index, false, nil)
            self.icon.tooltip = format("Train %s to (%d/%d)", link, talent.rank, maxRank, tabName)
            self.icon.talentTab = talent.tab
            self.icon.talentIndex = talent.index
            self.icon.rank:SetText(talent.rank)

            if (talent.rank < maxRank) then
                self.icon.rank:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
            else
                self.icon.rank:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            end

            if (tooltip:IsOwned(self.icon) and self.icon.tooltip) then
                tooltip:SetTalent(talent.tab, talent.index)
                tooltip:AddLine(" ", nil, nil, nil)
                tooltip:AddLine(tooltip, nil, nil, nil)
            end

            local iconTexture = _G[self.icon:GetName() .. "IconTexture"]
            iconTexture:SetVertexColor(1.0, 1.0, 1.0, 1.0)

            self.level.label:SetText(talent.level)
            local playerLevel = UnitLevel("player")
            if (talent.level <= playerLevel) then
                self.level.label:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
            else
                self.level.label:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
            end

            if (talent.rank <= currentRank) then
                self.level.label:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
                self.icon.rank:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
                iconTexture:SetDesaturated(1)
            else
                iconTexture:SetDesaturated(nil)
            end
        end

        rawset(rows, i, row)
    end

    ts.MainFrame.rows = rows
end

-- When a talent sequence is clicked, this function handles learning the talent
function ts.MainFrame_LearnTalent(self)
    local talent = self:GetParent().talent
    local _, _, _, _, currentRank =
        GetTalentInfo(talent.tab, talent.index)
    local playerLevel = UnitLevel("player")
    if (currentRank + 1 == talent.rank and playerLevel >= talent.level) then
        LearnTalent(talent.tab, talent.index)
    end
end

-- Adds tooltips to the rows / talent button which shows the talent information
function ts.MainFrame_SetTalentTooltip(self)
    if (not self.tooltip) then return end
    tooltip:SetOwner(self, "ANCHOR_RIGHT")
    tooltip:SetTalent(self.talentTab, self.talentIndex)
    tooltip:AddLine(" ", nil, nil, nil)
    tooltip:AddLine(self.tooltip, nil, nil, nil)
    tooltip:Show()
end

-- When we scroll nothing in the frame is actually moving, instead we have a fixed number of icons; this function updates to show the proper talents
function ts.MainFrame_RefreshTalents()
    local scrollBar = ts.MainFrame.scrollBar
    local numTalents = #ts.Talents
    FauxScrollFrame_Update(scrollBar, numTalents, MAX_TALENT_ROWS, TALENT_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollBar)
    for i = 1, MAX_TALENT_ROWS do
        local talentIndex = i + offset
        local talent = ts.Talents[talentIndex]
        local row = ts.MainFrame.rows[i]
        row:SetTalent(talent)
    end
    if (numTalents <= MAX_TALENT_ROWS) then
        ts.MainFrame:SetWidth(NONSCROLLING_WIDTH)
        ts.MainFrame.scrollBar:Hide()
    else
        ts.MainFrame:SetWidth(SCROLLING_WIDTH)
        ts.MainFrame.scrollBar:Show()
    end
end

-- Gets the index of the first unlearned talent
function ts.FindFirstUnlearnedIndex()
    for index, talent in pairs(ts.Talents) do
        local _, _, _, _, currentRank = GetTalentInfo(talent.tab, talent.index)
        if (talent.rank > currentRank) then return index end
    end
end

-- Scrolls the talent sequences to the first unlearned talent
function ts.MainFrame_JumpToUnlearnedTalents()
    local scrollBar = ts.MainFrame.scrollBar
    local numTalents = #ts.Talents
    if (numTalents <= MAX_TALENT_ROWS) then
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, TALENT_ROW_HEIGHT)
        return
    end

    local nextTalentIndex = ts.FindFirstUnlearnedIndex()
    if (not nextTalentIndex) then
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, TALENT_ROW_HEIGHT)
        return
    end

    if (nextTalentIndex == 1) then
        FauxScrollFrame_SetOffset(scrollBar, 0)
        FauxScrollFrame_OnVerticalScroll(scrollBar, 0, TALENT_ROW_HEIGHT)
        return
    end

    local nextTalentOffset = nextTalentIndex - 1
    if (nextTalentOffset > numTalents - MAX_TALENT_ROWS) then
        nextTalentOffset = numTalents - MAX_TALENT_ROWS
    end
    
    FauxScrollFrame_SetOffset(scrollBar, nextTalentOffset)
    FauxScrollFrame_OnVerticalScroll(scrollBar, ceil(nextTalentOffset * TALENT_ROW_HEIGHT - 0.5), TALENT_ROW_HEIGHT)
end

-- Adds the Toggle button to the talent frame
function ts.ShowButton_AddToPanel()
    local showButton = CreateFrame("Button", "ShowTalentOrderButton", _G["PlayerTalentFrame"], "UIPanelButtonTemplate")
    showButton:SetPoint("TOPLEFT", 60, -32)
    showButton:SetHeight(18)
    showButton:SetText("  Talent Sequence >>  ")

    if (IsTalentSequenceExpanded) then
        showButton:SetText("  Talent Sequence <<  ")
        ts.MainFrame:Show()
    end

    showButton.tooltip = ts.L.TOGGLE
    showButton:SetScript("OnClick", ts.ShowButton_OnClick)
    showButton:SetScript("OnEnter", ts.ShowButton_OnEnter)
    showButton:SetScript("OnLeave", function() tooltip:Hide() end)
    showButton:SetWidth(showButton:GetTextWidth() + 10)
end

-- Handles when the load button is being clicked; this opens the import frame where sequences are managed
function ts.LoadButton_AddToPanel()
    local loadButton = CreateFrame("Button", "$parentloadButton", ts.MainFrame, "UIPanelButtonTemplate")
    loadButton:SetPoint("TOP", ts.MainFrame, "BOTTOM", 0, 4)
    loadButton:SetPoint("RIGHT", ts.MainFrame)
    loadButton:SetPoint("LEFT", ts.MainFrame)
    loadButton:SetText(ts.L.LOAD)
    loadButton:SetHeight(22)
    loadButton:SetScript("OnClick", function()
        if (ts.ImportFrame == nil) then ts.CreateImportFrame() end
        ts.ImportFrame:Show()
        if (UsingTalented) then
            ts.ImportFrame:SetFrameLevel(4)
            ts.ImportFrame:Raise()
        end
    end)
end

-- Handles the show button being clicked; toggles frame's visibility
function ts.ShowButton_OnClick(self)
    IsTalentSequenceExpanded = not IsTalentSequenceExpanded
    if (IsTalentSequenceExpanded) then
        ts.MainFrame:Show()
        self:SetText("  Talent Sequence <<  ")
    else
        ts.MainFrame:Hide()
        self:SetText("  Talent Sequence >>  ")
    end
end

-- Display a tooltip for the toggle button
function ts.ShowButton_OnEnter(self)
    tooltip:SetOwner(self, "ANCHOR_RIGHT")
    tooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
    tooltip:Show()
end

-- Hook into talent events
local function HookTalentTabs()
    -- Register an event listener for when the user changes specs so we can refresh the talent info
    ts.MainFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    ts.MainFrame:SetScript("OnEvent", function(self, event)
        local currentSpecIndex = GetActiveTalentGroup(false, false)
        if SpecSequenceIndex and SpecSequenceIndex[currentSpecIndex] then
            ts:LoadTalentSequence(TalentSequenceSavedSequences[SpecSequenceIndex[currentSpecIndex]].talents)
        end

        ts:AddTalentCounts()
        ts.MainFrame_JumpToUnlearnedTalents()
    end)

    -- when user swaps between their spec1 and spec2 tabs, only fresh the talent info if its the currently active spec
    _G["PlayerSpecTab1"]:HookScript("OnClick", ts.AddTalentCounts)
    _G["PlayerSpecTab2"]:HookScript("OnClick", ts.AddTalentCounts)
    -- Update talent count info when the user swaps to the talents tab
    _G["PlayerTalentFrameTab1"]:HookScript("OnClick", function() 
        ts.AddTalentCounts()
    end)
end

local initRun = false
local function init()
    if (initRun) then return end
    if (not TalentSequenceSavedSequences) then
        TalentSequenceSavedSequences = {}
    end
    local currentSpecIndex = GetActiveTalentGroup(false, false)

    if (TalentSequenceTalentsIndex and TalentSequenceTalentsIndex > 0 and TalentSequenceTalentsIndex <= #TalentSequenceSavedSequences) then
        TalentSequenceTalents = TalentSequenceSavedSequences[TalentSequenceTalentsIndex].talents
    elseif SpecSequenceIndex and SpecSequenceIndex[currentSpecIndex] and TalentSequenceSavedSequences[SpecSequenceIndex[currentSpecIndex]] then
        TalentSequenceTalents = TalentSequenceSavedSequences[SpecSequenceIndex[currentSpecIndex]].talents
    end
    if (not TalentSequenceTalents) then TalentSequenceTalents = {} end
    ts.Talents = TalentSequenceTalents
    if (IsTalentSequenceExpanded == 0) then IsTalentSequenceExpanded = false end
    if (ts.MainFrame == nil) then 
        ts.CreateMainFrame()
        ts.MainFrame_AddScrollBar()
        ts.MainFrame_AddTalentRows()
        ts.ShowButton_AddToPanel()
        ts.LoadButton_AddToPanel()
        ts.AddTalentCounts()
        HookTalentTabs()
    end
    initRun = true
end

hooksecurefunc("ToggleTalentFrame", function(...)
    if (PlayerTalentFrame == nil) then return end
    if (initRun) then
        if PlayerTalentFrame.selectedTab == 1 and GetActiveTalentGroup(false, false) == PlayerTalentFrame.talentGroup then
            ts.AddTalentCounts()
        end
        return
    end
    init()
end)
