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
addon.miningPerformPattern = nil
addon.herbalismPerformPattern = nil
addon.woodcuttingPerformPattern = nil
addon.DEFAULT_NOTE_ICON = "Interface\\Icons\\INV_Misc_Note_01"

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
        local pin = self:AcquirePin(i)
        pin.noteName = note.name or "Note"
        pin.noteIndex = i
        pin.texture:SetTexture(note.icon or self.DEFAULT_NOTE_ICON)

        pin:ClearAllPoints()
        pin:SetPoint("CENTER", WorldMapButton, "TOPLEFT", note.x * WorldMapButton:GetWidth(), -note.y * WorldMapButton:GetHeight())
        pin:Show()
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

        if self.OnGatheringInit then
            self:OnGatheringInit()
        end

        if self.SetupCoordinateDisplay then
            self:SetupCoordinateDisplay()
        end
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
    end)
end
