local ADDON_NAME = "ForgedMapNotes"

ForgedMapNotesDB = ForgedMapNotesDB or {}

ForgedMapNotes = ForgedMapNotes or CreateFrame("Frame", "ForgedMapNotesFrame")
local addon = ForgedMapNotes

addon.noteFrames = addon.noteFrames or {}
addon.pendingX = nil
addon.pendingY = nil
addon.editMapKey = nil
addon.editNoteIndex = nil
addon.dialogDefaultName = ""
addon.deleteMapKey = nil
addon.deleteNoteIndex = nil
addon.originalWorldMapButtonOnClick = nil
addon.worldMapButtonOnClickHooked = nil
addon.coordinatesFrame = addon.coordinatesFrame or nil
addon.gatheringFilterDropDown = addon.gatheringFilterDropDown or nil
addon.gatheringFilterButton = addon.gatheringFilterButton or nil
addon.miningPerformPattern = nil
addon.herbalismPerformPattern = nil
addon.woodcuttingPerformPattern = nil
addon.DEFAULT_NOTE_ICON = "Interface\\Icons\\INV_Misc_Note_01"
addon.DEFAULT_GATHERING_FILTER = "all"

local GATHERING_FILTER_OPTIONS = {
    { value = "all", text = "All" },
    { value = "general", text = "General" },
    { value = "mining", text = "Mining" },
    { value = "herbalism", text = "Herbalism" },
    { value = "woodcutting", text = "Woodcutting" },
}

function addon:GetMapKey()
    local continent = GetCurrentMapContinent() or 0
    local zone = GetCurrentMapZone() or 0
    local floor = 0

    if GetCurrentMapDungeonLevel then
        floor = GetCurrentMapDungeonLevel() or 0
    end

    return continent .. ":" .. zone .. ":" .. floor
end

function addon:EnsureMapTable()
    ForgedMapNotesDB.notes = ForgedMapNotesDB.notes or {}
    local key = self:GetMapKey()
    ForgedMapNotesDB.notes[key] = ForgedMapNotesDB.notes[key] or {}
    return ForgedMapNotesDB.notes[key]
end

function addon:GetGatheringFilterText(filterValue)
    for i = 1, table.getn(GATHERING_FILTER_OPTIONS) do
        local option = GATHERING_FILTER_OPTIONS[i]
        if option.value == filterValue then
            return option.text
        end
    end

    return "All"
end

function addon:GetNoteCategory(note)
    if not note then
        return "general"
    end

    if note.category and note.category ~= "" then
        return note.category
    end

    if self.GetAutoCategoryForName then
        local autoCategory = self:GetAutoCategoryForName(note.name)
        if autoCategory then
            return autoCategory
        end
    end

    return "general"
end

function addon:ShouldDisplayNote(note)
    local activeFilter = self.activeGatheringFilter or self.DEFAULT_GATHERING_FILTER
    if activeFilter == "all" then
        return true
    end

    return self:GetNoteCategory(note) == activeFilter
end

function addon:SetGatheringFilter(filterValue)
    local nextFilter = filterValue or self.DEFAULT_GATHERING_FILTER
    self.activeGatheringFilter = nextFilter

    ForgedMapNotesDB = ForgedMapNotesDB or {}
    ForgedMapNotesDB.gatheringFilter = nextFilter

    if self.gatheringFilterButton and self.gatheringFilterButton.valueText then
        self.gatheringFilterButton.valueText:SetText(self:GetGatheringFilterText(nextFilter))
    end

    self:RefreshPins()
end

function addon:SetupGatheringFilterDropdown()
    if not WorldMapFrame or not self.coordinatesFrame or not UIDropDownMenu_Initialize or not ToggleDropDownMenu then
        return
    end

    local menuFrame = self.gatheringFilterDropDown
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "ForgedMapNotesGatheringDropDown", WorldMapFrame, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(menuFrame, function()
            for i = 1, table.getn(GATHERING_FILTER_OPTIONS) do
                local option = GATHERING_FILTER_OPTIONS[i]
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.text
                info.value = option.value
                info.checked = addon.activeGatheringFilter == option.value
                info.func = function()
                    addon:SetGatheringFilter(option.value)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        menuFrame:Hide()
        self.gatheringFilterDropDown = menuFrame
    end

    local button = self.gatheringFilterButton
    if not button then
        button = CreateFrame("Button", "ForgedMapNotesGatheringFilterButton", self.coordinatesFrame, "UIPanelButtonTemplate")
        button:SetWidth(150)
        button:SetHeight(22)
        button:SetFrameStrata("TOOLTIP")
        button:SetFrameLevel(self.coordinatesFrame:GetFrameLevel() + 5)
        button:SetText("")

        button.label = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        button.label:SetText("Gathering")
        button.label:SetTextColor(1, 0.82, 0)

        button.valueText = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        button.valueText:SetJustifyH("LEFT")

        button.arrow = button:CreateTexture(nil, "ARTWORK")
        button.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        button.arrow:SetWidth(18)
        button.arrow:SetHeight(18)

        button:SetScript("OnClick", function()
            ToggleDropDownMenu(1, nil, addon.gatheringFilterDropDown, this, 0, 0)
        end)

        self.gatheringFilterButton = button
    end

    button:SetParent(self.coordinatesFrame)
    button:SetFrameStrata("TOOLTIP")
    button:SetFrameLevel(self.coordinatesFrame:GetFrameLevel() + 5)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", self.coordinatesFrame, "TOPRIGHT", -16, -18)

    button.label:ClearAllPoints()
    button.label:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 2, 1)
    button.valueText:ClearAllPoints()
    button.valueText:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.valueText:SetPoint("RIGHT", button, "RIGHT", -24, 0)
    button.valueText:SetText(self:GetGatheringFilterText(self.activeGatheringFilter or self.DEFAULT_GATHERING_FILTER))
    button.arrow:ClearAllPoints()
    button.arrow:SetPoint("RIGHT", button, "RIGHT", -5, 0)
    button:Show()
end

function addon:GetCursorMapPosition()
    if not WorldMapButton or not WorldMapButton:IsVisible() then
        return nil, nil
    end

    local scale = WorldMapButton:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local left = WorldMapButton:GetLeft()
    local top = WorldMapButton:GetTop()
    local width = WorldMapButton:GetWidth()
    local height = WorldMapButton:GetHeight()

    if not left or not top or not width or not height or width == 0 or height == 0 then
        return nil, nil
    end

    local x = (cursorX / scale - left) / width
    local y = (top - cursorY / scale) / height

    if x < 0 or y < 0 or x > 1 or y > 1 then
        return nil, nil
    end

    return x, y
end

function addon:HideAllPins()
    for i = 1, table.getn(self.noteFrames) do
        self.noteFrames[i]:Hide()
    end
end

function addon:AcquirePin(index)
    local pin = self.noteFrames[index]
    if pin then
        return pin
    end

    pin = CreateFrame("Button", nil, WorldMapButton)
    pin:SetWidth(12)
    pin:SetHeight(12)
    pin:EnableMouse(true)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetFrameLevel(pin:GetFrameLevel() + 3)

    local texture = pin:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(pin)
    texture:SetTexture(self.DEFAULT_NOTE_ICON)
    pin.texture = texture

    pin:SetScript("OnEnter", function()
        if this and this.noteName then
            local tooltip = WorldMapTooltip or GameTooltip
            local x, _ = this:GetCenter()
            local x2, _ = WorldMapButton:GetCenter()
            local anchor = "ANCHOR_RIGHT"
            if x and x2 and x > x2 then
                anchor = "ANCHOR_LEFT"
            end
            tooltip:SetOwner(this, anchor)
            tooltip:SetText(this.noteName, 1, 1, 1)
            tooltip:Show()
        end
    end)

    pin:SetScript("OnLeave", function()
        if WorldMapTooltip then
            WorldMapTooltip:Hide()
        end
        GameTooltip:Hide()
    end)

    pin:SetScript("OnClick", function()
        if addon.HandlePinClick then
            addon:HandlePinClick(this, arg1)
        end
    end)

    self.noteFrames[index] = pin
    return pin
end

function addon:RefreshPins()
    self:HideAllPins()

    if not ForgedMapNotesDB.notes then
        return
    end

    local key = self:GetMapKey()
    local notes = ForgedMapNotesDB.notes[key]
    if not notes then
        return
    end

    for i = 1, table.getn(notes) do
        local note = notes[i]
        if self:ShouldDisplayNote(note) then
            local pin = self:AcquirePin(i)
            pin.noteName = note.name or "Note"
            pin.noteIndex = i
            pin.texture:SetTexture(note.icon or self.DEFAULT_NOTE_ICON)

            pin:ClearAllPoints()
            pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", note.x * WorldMapButton:GetWidth(), -note.y * WorldMapButton:GetHeight())
            pin:Show()
        end
    end
end

function addon:AddNote(name)
    if not self.pendingX or not self.pendingY then
        return
    end

    local notes = self:EnsureMapTable()
    table.insert(notes, {
        x = self.pendingX,
        y = self.pendingY,
        name = (name and name ~= "") and name or "Note",
        icon = nil,
        category = (self.GetAutoCategoryForName and self:GetAutoCategoryForName(name)) or "general",
    })

    self.pendingX = nil
    self.pendingY = nil

    self:RefreshPins()
end

function addon:UpdateNoteName(mapKey, noteIndex, name)
    if not mapKey or not noteIndex then
        return
    end

    if not ForgedMapNotesDB.notes or not ForgedMapNotesDB.notes[mapKey] then
        return
    end

    local note = ForgedMapNotesDB.notes[mapKey][noteIndex]
    if not note then
        return
    end

    note.name = (name and name ~= "") and name or "Note"
    if self.GetAutoIconForName then
        note.icon = self:GetAutoIconForName(note.name)
    end
    note.category = (self.GetAutoCategoryForName and self:GetAutoCategoryForName(note.name)) or "general"
    self:RefreshPins()
end

function addon:DeleteNote(mapKey, noteIndex)
    if not mapKey or not noteIndex then
        return
    end

    if not ForgedMapNotesDB.notes or not ForgedMapNotesDB.notes[mapKey] then
        return
    end

    local notes = ForgedMapNotesDB.notes[mapKey]
    if not notes[noteIndex] then
        return
    end

    table.remove(notes, noteIndex)
    self:RefreshPins()
end

function addon:AddNoteAtCursor()
    local x, y = self:GetCursorMapPosition()
    if not x or not y then
        return
    end

    self.pendingX = x
    self.pendingY = y
    self.editMapKey = nil
    self.editNoteIndex = nil
    self.dialogDefaultName = ""

    if self.ShowNoteDialog then
        self:ShowNoteDialog(nil, nil, "")
    end
end

function addon:SetupMapClickHook()
    if not WorldMapButton then
        return
    end

    if not self.worldMapButtonOnClickHooked and type(WorldMapButton_OnClick) == "function" then
        self.originalWorldMapButtonOnClick = WorldMapButton_OnClick
        WorldMapButton_OnClick = function(mouseButton, button)
            local click = mouseButton or arg1
            if click == "RightButton" and IsControlKeyDown() then
                addon:AddNoteAtCursor()
                return
            end

            return addon.originalWorldMapButtonOnClick(mouseButton, button)
        end
        self.worldMapButtonOnClickHooked = true
    end

    if WorldMapButton.ForgedMapNotesHooked then
        return
    end

    local originalOnMouseUp = WorldMapButton:GetScript("OnMouseUp")

    WorldMapButton:SetScript("OnMouseUp", function()
        if arg1 == "RightButton" and IsControlKeyDown() then
            addon:AddNoteAtCursor()
            return
        end

        if originalOnMouseUp then
            originalOnMouseUp()
        end
    end)

    WorldMapButton.ForgedMapNotesHooked = true
end

function addon:OnEvent(event)
    if event == "PLAYER_LOGIN" then
        ForgedMapNotesDB = ForgedMapNotesDB or {}
        ForgedMapNotesDB.notes = ForgedMapNotesDB.notes or {}
        self.activeGatheringFilter = ForgedMapNotesDB.gatheringFilter or self.DEFAULT_GATHERING_FILTER

        if self.OnGatheringInit then
            self:OnGatheringInit()
        end

        if self.SetupCoordinateDisplay then
            self:SetupCoordinateDisplay()
        end
        self:SetupGatheringFilterDropdown()
        self:SetupMapClickHook()

        self:RegisterEvent("SPELLCAST_START")
        self:RegisterEvent("UI_ERROR_MESSAGE")
        self:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")

        self:RefreshPins()
        return
    end

    if event == "WORLD_MAP_UPDATE" then
        if self.SetupCoordinateDisplay then
            self:SetupCoordinateDisplay()
        end
        self:SetupGatheringFilterDropdown()
        self:SetupMapClickHook()
        if self.coordinatesFrame then
            self.coordinatesFrame:Show()
        end
        self:RefreshPins()
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        self:RefreshPins()
        return
    end

    if self.HandleGatheringEvent and self:HandleGatheringEvent(event, arg1) then
        return
    end
end

addon:SetScript("OnEvent", function()
    addon:OnEvent(event)
end)

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("WORLD_MAP_UPDATE")
addon:RegisterEvent("ZONE_CHANGED_NEW_AREA")

local originalWorldMapOnShow = WorldMapFrame and WorldMapFrame:GetScript("OnShow")
if WorldMapFrame then
    WorldMapFrame:SetScript("OnShow", function()
        if originalWorldMapOnShow then
            originalWorldMapOnShow()
        end
        if addon.SetupCoordinateDisplay then
            addon:SetupCoordinateDisplay()
        end
        if addon.SetupGatheringFilterDropdown then
            addon:SetupGatheringFilterDropdown()
        end
        if addon.coordinatesFrame then
            addon.coordinatesFrame:Show()
            if addon.coordinatesFrame.cursorCoords then
                addon.coordinatesFrame.cursorCoords:SetText("Cursor: --, --")
            end
        end
    end)
end

local originalWorldMapOnHide = WorldMapFrame and WorldMapFrame:GetScript("OnHide")
if WorldMapFrame then
    WorldMapFrame:SetScript("OnHide", function()
        if originalWorldMapOnHide then
            originalWorldMapOnHide()
        end

        if addon.ResetDialogState then
            addon:ResetDialogState()
        end

        if addon.coordinatesFrame and addon.coordinatesFrame.cursorCoords then
            addon.coordinatesFrame.cursorCoords:SetText("")
        end
        if addon.coordinatesFrame and addon.coordinatesFrame.playerCoords then
            addon.coordinatesFrame.playerCoords:SetText("")
        end

        if addon.HideDialogs then
            addon:HideDialogs()
        end
        if addon.gatheringFilterDropDown then
            addon.gatheringFilterDropDown:Hide()
        end
        if addon.gatheringFilterButton then
            addon.gatheringFilterButton:Hide()
        end
    end)
end
