local addon = ForgedMapNotes
if not addon then
    return
end

addon.noteDialog = addon.noteDialog or nil
addon.deleteDialog = addon.deleteDialog or nil

function addon:ResetDialogState()
    self.pendingX = nil
    self.pendingY = nil
    self.editMapKey = nil
    self.editNoteIndex = nil
    self.dialogDefaultName = ""
    self.deleteMapKey = nil
    self.deleteNoteIndex = nil
end

function addon:GetDeleteDialog()
    if self.deleteDialog then
        return self.deleteDialog
    end

    local deleteDialog = CreateFrame("Frame", "ForgedMapNotesDeleteDialog", WorldMapFrame)
    deleteDialog:SetPoint("CENTER", WorldMapFrame, "CENTER", 0, 0)
    deleteDialog:SetWidth(320)
    deleteDialog:SetHeight(130)
    deleteDialog:SetFrameStrata("FULLSCREEN")
    deleteDialog:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 25)
    deleteDialog:EnableMouse(true)
    deleteDialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11,
        },
    })

    local headerTexture = deleteDialog:CreateTexture(nil, "ARTWORK")
    headerTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerTexture:SetWidth(256)
    headerTexture:SetHeight(64)
    headerTexture:SetPoint("TOP", deleteDialog, "TOP", 0, 12)

    local header = deleteDialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOP", headerTexture, "TOP", 0, -14)
    header:SetText("Delete Note")

    local text = deleteDialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOP", deleteDialog, "TOP", 0, -44)
    text:SetWidth(270)
    text:SetJustifyH("CENTER")
    text:SetText("Delete this note?")

    local acceptButton = CreateFrame("Button", nil, deleteDialog, "UIPanelButtonTemplate")
    acceptButton:SetPoint("BOTTOMLEFT", deleteDialog, "BOTTOMLEFT", 20, 18)
    acceptButton:SetWidth(130)
    acceptButton:SetHeight(24)
    acceptButton:SetText(ACCEPT)

    local cancelButton = CreateFrame("Button", nil, deleteDialog, "UIPanelButtonTemplate")
    cancelButton:SetPoint("BOTTOMRIGHT", deleteDialog, "BOTTOMRIGHT", -20, 18)
    cancelButton:SetWidth(130)
    cancelButton:SetHeight(24)
    cancelButton:SetText(CANCEL)

    acceptButton:SetScript("OnClick", function()
        if addon.deleteMapKey and addon.deleteNoteIndex then
            addon:DeleteNote(addon.deleteMapKey, addon.deleteNoteIndex)
        end
        addon:ResetDialogState()
        deleteDialog:Hide()
    end)

    cancelButton:SetScript("OnClick", function()
        addon.deleteMapKey = nil
        addon.deleteNoteIndex = nil
        deleteDialog:Hide()
    end)

    deleteDialog:Hide()
    self.deleteDialog = deleteDialog
    return deleteDialog
end

function addon:GetNoteDialog()
    if self.noteDialog then
        return self.noteDialog
    end

    local noteDialog = CreateFrame("Frame", "ForgedMapNotesAddDialog", WorldMapFrame)
    noteDialog:SetPoint("CENTER", WorldMapFrame, "CENTER", 0, 0)
    noteDialog:SetWidth(320)
    noteDialog:SetHeight(140)
    noteDialog:SetFrameStrata("FULLSCREEN")
    noteDialog:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 20)
    noteDialog:EnableMouse(true)
    noteDialog:SetMovable(true)
    noteDialog:RegisterForDrag("LeftButton")
    noteDialog:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    noteDialog:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
    noteDialog:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11,
        },
    })

    local headerTexture = noteDialog:CreateTexture(nil, "ARTWORK")
    headerTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerTexture:SetWidth(256)
    headerTexture:SetHeight(64)
    headerTexture:SetPoint("TOP", noteDialog, "TOP", 0, 12)

    local header = noteDialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOP", headerTexture, "TOP", 0, -14)
    header:SetText("New Note")
    noteDialog.header = header

    local label = noteDialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", noteDialog, "TOPLEFT", 20, -45)
    label:SetText("Name")

    local editBox = CreateFrame("EditBox", "ForgedMapNotesAddDialogEditBox", noteDialog, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    editBox:SetWidth(270)
    editBox:SetHeight(20)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(64)
    noteDialog.editBox = editBox

    local acceptButton = CreateFrame("Button", nil, noteDialog, "UIPanelButtonTemplate")
    acceptButton:SetPoint("BOTTOMLEFT", noteDialog, "BOTTOMLEFT", 20, 18)
    acceptButton:SetWidth(130)
    acceptButton:SetHeight(24)
    acceptButton:SetText(ACCEPT)

    local cancelButton = CreateFrame("Button", nil, noteDialog, "UIPanelButtonTemplate")
    cancelButton:SetPoint("BOTTOMRIGHT", noteDialog, "BOTTOMRIGHT", -20, 18)
    cancelButton:SetWidth(130)
    cancelButton:SetHeight(24)
    cancelButton:SetText(CANCEL)

    local function SubmitNote()
        local noteName = ""
        if noteDialog.editBox then
            noteName = noteDialog.editBox:GetText() or ""
        end

        if addon.editMapKey and addon.editNoteIndex then
            addon:UpdateNoteName(addon.editMapKey, addon.editNoteIndex, noteName)
        else
            addon:AddNote(noteName)
        end

        addon:ResetDialogState()
        noteDialog:Hide()
    end

    acceptButton:SetScript("OnClick", SubmitNote)
    cancelButton:SetScript("OnClick", function()
        addon:ResetDialogState()
        noteDialog:Hide()
    end)

    editBox:SetScript("OnEnterPressed", SubmitNote)
    editBox:SetScript("OnEscapePressed", function()
        addon:ResetDialogState()
        noteDialog:Hide()
    end)

    noteDialog:SetScript("OnShow", function()
        this:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 20)
        this:EnableMouse(true)
        if this.header then
            if addon.editMapKey and addon.editNoteIndex then
                this.header:SetText("Edit Note")
            else
                this.header:SetText("New Note")
            end
        end
        if this.editBox then
            this.editBox:SetText(addon.dialogDefaultName or "")
            this.editBox:SetFocus()
            this.editBox:HighlightText()
        end
    end)

    noteDialog:Hide()
    self.noteDialog = noteDialog
    return noteDialog
end

function addon:ShowNoteDialog(mapKey, noteIndex, defaultName)
    self.editMapKey = mapKey
    self.editNoteIndex = noteIndex
    self.dialogDefaultName = defaultName or ""

    local dialog = self:GetNoteDialog()
    dialog:ClearAllPoints()
    dialog:SetPoint("CENTER", WorldMapFrame, "CENTER", 0, 0)
    dialog:Show()
end

function addon:ShowDeleteDialog(mapKey, noteIndex)
    self.deleteMapKey = mapKey
    self.deleteNoteIndex = noteIndex
    self.pendingX = nil
    self.pendingY = nil
    self.editMapKey = nil
    self.editNoteIndex = nil

    if self.noteDialog and self.noteDialog:IsShown() then
        self.noteDialog:Hide()
    end

    local dialog = self:GetDeleteDialog()
    dialog:ClearAllPoints()
    dialog:SetPoint("CENTER", WorldMapFrame, "CENTER", 0, 0)
    dialog:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 25)
    dialog:Show()
end

function addon:HandlePinClick(pin, click)
    if not pin or not pin.noteIndex then
        return
    end

    if click ~= "LeftButton" and click ~= "RightButton" then
        return
    end

    local mapKey = self:GetMapKey()
    local notes = ForgedMapNotesDB.notes and ForgedMapNotesDB.notes[mapKey]
    local note = notes and notes[pin.noteIndex]
    if not note then
        return
    end

    if click == "RightButton" then
        self:ShowDeleteDialog(mapKey, pin.noteIndex)
        return
    end

    self.pendingX = nil
    self.pendingY = nil
    self:ShowNoteDialog(mapKey, pin.noteIndex, note.name or "")
end

function addon:HideDialogs()
    if self.noteDialog and self.noteDialog:IsShown() then
        self.noteDialog:Hide()
    end
    if self.deleteDialog and self.deleteDialog:IsShown() then
        self.deleteDialog:Hide()
    end
end
