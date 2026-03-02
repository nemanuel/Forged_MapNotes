local addon = ForgedMapNotes
if not addon then
    return
end

function addon:SetupCoordinateDisplay()
    if not WorldMapFrame or not WorldMapButton then
        return
    end

    local frame = self.coordinatesFrame
    if not frame then
        frame = CreateFrame("Frame", "ForgedMapNotesCoordinates", WorldMapButton)
        frame.cursorCoords = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.playerCoords = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

        frame:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local left = WorldMapDetailFrame and WorldMapDetailFrame:GetLeft()
            local top = WorldMapDetailFrame and WorldMapDetailFrame:GetTop()
            local width = WorldMapDetailFrame and WorldMapDetailFrame:GetWidth()
            local height = WorldMapDetailFrame and WorldMapDetailFrame:GetHeight()
            local scale = WorldMapDetailFrame and WorldMapDetailFrame:GetEffectiveScale()

            if not left or not top or not width or not height or not scale or width == 0 or height == 0 then
                this.cursorCoords:SetText("Cursor: --, --")
            else
                local cx = (x / scale - left) / width
                local cy = (top - y / scale) / height
                this.cursorCoords:SetText(string.format("Cursor: %.1f, %.1f", 100 * cx, 100 * cy))
            end

            local px, py = GetPlayerMapPosition("player")
            if not px or not py or px == 0 or py == 0 or IsInInstance() then
                this.playerCoords:SetText("")
            else
                this.playerCoords:SetText(string.format("Player: %.1f, %.1f", 100 * px, 100 * py))
            end
        end)

        self.coordinatesFrame = frame
    end

    frame:SetParent(WorldMapButton)
    frame:ClearAllPoints()
    frame:SetAllPoints(WorldMapButton)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(WorldMapButton:GetFrameLevel() + 30)

    frame.cursorCoords:ClearAllPoints()
    frame.cursorCoords:SetPoint("BOTTOMLEFT", WorldMapButton, "BOTTOMLEFT", 8, 8)
    frame.cursorCoords:SetText("Cursor: --, --")

    frame.playerCoords:ClearAllPoints()
    frame.playerCoords:SetPoint("BOTTOMRIGHT", WorldMapButton, "BOTTOMRIGHT", -8, 8)
    frame.playerCoords:SetText("")

    if not frame.helpText then
        frame.helpText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.helpText:SetJustifyH("LEFT")
        frame.helpText:SetPoint("TOPLEFT", WorldMapButton, "TOPLEFT", 66, -48)
        frame.helpText:SetTextColor(1, 1, 1)
        frame.helpText:SetText("Ctrl+Right Click On Map To Add Note\nLeft Click on Note to Edit\nRight Click On Note To Delete")
    end

    frame:Show()
end
