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
addon.miningPerformPattern = nil
addon.herbalismPerformPattern = nil
addon.woodcuttingPerformPattern = nil
addon.DEFAULT_NOTE_ICON = "Interface\\Icons\\INV_Misc_Note_01"
addon.DEFAULT_GATHERING_FILTER = "all"

local GATHERING_FILTER_OPTIONS = {
    { value = "all", text = "All" },
    { value = "personal", text = "Personal" },
    { value = "mining", text = "Mining" },
    { value = "herbalism", text = "Herbalism" },
    { value = "woodcutting", text = "Woodcutting" },
    { value = "treasure", text = "Treasure" },
}

function addon:NormalizeNoteCategory(category)
    if not category or category == "" or category == "general" then
        return "personal"
    end

    return category
end

function addon:MigrateLegacyGeneralCategory()
    if not ForgedMapNotesDB then
        return
    end

    if ForgedMapNotesDB.gatheringFilter == "general" then
        ForgedMapNotesDB.gatheringFilter = "personal"
    end

    if not ForgedMapNotesDB.notes then
        return
    end

    for _, notes in pairs(ForgedMapNotesDB.notes) do
        if notes then
            for i = 1, table.getn(notes) do
                local note = notes[i]
                if note and note.category == "general" then
                    note.category = "personal"
                end
            end
        end
    end
end

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
        return "personal"
    end

    if note.category and note.category ~= "" then
        return self:NormalizeNoteCategory(note.category)
    end

    if self.GetAutoCategoryForName then
        local autoCategory = self:GetAutoCategoryForName(note.name)
        if autoCategory then
            return self:NormalizeNoteCategory(autoCategory)
        end
    end

    return "personal"
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
    if nextFilter == "general" then
        nextFilter = "personal"
    end
    self.activeGatheringFilter = nextFilter

    ForgedMapNotesDB = ForgedMapNotesDB or {}
    ForgedMapNotesDB.gatheringFilter = nextFilter

    self:UpdateGatheringFilterDropdownText()

    self:RefreshPins()
end

function addon:UpdateGatheringFilterDropdownText()
    local dropDown = self.gatheringFilterDropDown
    if not dropDown then
        return
    end

    local activeFilter = self.activeGatheringFilter or self.DEFAULT_GATHERING_FILTER
    local filterText = self:GetGatheringFilterText(activeFilter)

    if UIDropDownMenu_SetSelectedValue then
        UIDropDownMenu_SetSelectedValue(dropDown, activeFilter)
    end

    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(filterText, dropDown)
        return
    end

    local textRegion = getglobal(dropDown:GetName() .. "Text")
    if textRegion then
        textRegion:SetText(filterText)
    end
end

function addon:ScaleGatheringFilterMenu(scale)
    local menuScale = scale or 1.15
    local maxLevels = UIDROPDOWNMENU_MAXLEVELS or 2
    local level = 1

    while level <= maxLevels do
        local listFrame = getglobal("DropDownList" .. level)
        if listFrame then
            listFrame:SetScale(menuScale)
        end
        level = level + 1
    end
end

function addon:SetupGatheringFilterDropdown()
    if not WorldMapFrame or not self.coordinatesFrame or not UIDropDownMenu_Initialize or not ToggleDropDownMenu then
        return
    end

    local dropDown = self.gatheringFilterDropDown
    if not dropDown then
        dropDown = CreateFrame("Frame", "ForgedMapNotesGatheringDropDown", self.coordinatesFrame, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(dropDown, function()
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
        if UIDropDownMenu_SetWidth then
            UIDropDownMenu_SetWidth(130, dropDown)
        end

        if not dropDown.titleText then
            dropDown.titleText = dropDown:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            dropDown.titleText:SetPoint("BOTTOMLEFT", dropDown, "TOPLEFT", 20, 2)
            dropDown.titleText:SetJustifyH("LEFT")
            dropDown.titleText:SetTextColor(1, 0.82, 0)
        end

        dropDown.titleText:SetText("Map Notes")

        local textRegion = getglobal(dropDown:GetName() .. "Text")
        if textRegion then
            textRegion:ClearAllPoints()
            textRegion:SetPoint("LEFT", dropDown, "LEFT", 22, 5)
            textRegion:SetPoint("RIGHT", dropDown, "RIGHT", -46, 5)
            textRegion:SetJustifyH("RIGHT")
        end

        local leftTexture = getglobal(dropDown:GetName() .. "Left")
        if leftTexture then
            leftTexture:SetHeight(60)
        end

        local middleTexture = getglobal(dropDown:GetName() .. "Middle")
        if middleTexture then
            middleTexture:SetHeight(60)
        end

        local rightTexture = getglobal(dropDown:GetName() .. "Right")
        if rightTexture then
            rightTexture:SetHeight(60)
        end

        local button = getglobal(dropDown:GetName() .. "Button")
        if button then
            button:ClearAllPoints()
            button:SetPoint("RIGHT", dropDown, "RIGHT", -16, 4)
            button:SetWidth(24)
            button:SetHeight(24)
            button:SetFrameLevel(dropDown:GetFrameLevel() + 5)
            button:SetScript("OnClick", function()
                ToggleDropDownMenu(1, nil, dropDown, button, 10, -22)
                addon:ScaleGatheringFilterMenu(1)
            end)
            button:Show()
        end

        self.gatheringFilterDropDown = dropDown
    end

    dropDown:SetParent(self.coordinatesFrame)
    dropDown:SetFrameStrata("TOOLTIP")
    dropDown:SetFrameLevel(self.coordinatesFrame:GetFrameLevel() + 5)
    dropDown:ClearAllPoints()
    dropDown:SetPoint("TOPRIGHT", self.coordinatesFrame, "TOPRIGHT", -14, 32)

    if dropDown.titleText then
        dropDown.titleText:Show()
    end

    self:UpdateGatheringFilterDropdownText()
    dropDown:Show()
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
        category = self:NormalizeNoteCategory((self.GetAutoCategoryForName and self:GetAutoCategoryForName(name)) or "personal"),
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
    note.category = self:NormalizeNoteCategory((self.GetAutoCategoryForName and self:GetAutoCategoryForName(note.name)) or "personal")
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
        self:MigrateLegacyGeneralCategory()
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
        self:RegisterEvent("LOOT_OPENED")
        self:RegisterEvent("OPEN_LOCK")

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
    end)
end
