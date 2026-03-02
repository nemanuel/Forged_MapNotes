local addon = ForgedMapNotes
if not addon then
    return
end

local MINING_ICON_PATHS = {
    ["Copper"] = "Interface\\Icons\\INV_Ore_Copper_01",
    ["Tin"] = "Interface\\Icons\\INV_Ore_Tin_01",
    ["Silver"] = "Interface\\Icons\\INV_Stone_16",
    ["Iron"] = "Interface\\Icons\\INV_Ore_Iron_01",
    ["Gold"] = "Interface\\Icons\\INV_Ore_Copper_01",
    ["Mithril"] = "Interface\\Icons\\INV_Ore_Mithril_02",
    ["Truesilver"] = "Interface\\Icons\\INV_Ore_TrueSilver_01",
    ["Small Thorium"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Thorium"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Rich Thorium"] = "Interface\\Icons\\INV_Ore_Thorium_02",
    ["Dark Iron"] = "Interface\\Icons\\INV_Ore_Mithril_01",
    ["Fel Iron"] = "Interface\\Icons\\INV_Ore_FelIron",
    ["Adamantite"] = "Interface\\Icons\\INV_Ore_Adamantium",
    ["Rich Adamantite"] = "Interface\\Icons\\INV_Ore_Adamantium_01",
    ["Khorium"] = "Interface\\Icons\\INV_Ore_Khorium",
    ["Gemstone"] = "Interface\\Icons\\INV_Misc_Gem_01",
}

local HERBALISM_ICON_PATHS = {
    ["Black Lotus"] = "Interface\\Icons\\INV_Misc_Herb_BlackLotus",
    ["Blindweed"] = "Interface\\Icons\\INV_Misc_Herb_14",
    ["Briarthorn"] = "Interface\\Icons\\INV_Misc_Root_01",
    ["Bruiseweed"] = "Interface\\Icons\\INV_Misc_Herb_01",
    ["Dreamfoil"] = "Interface\\Icons\\INV_Misc_Herb_DreamFoil",
    ["Earthroot"] = "Interface\\Icons\\INV_Misc_Herb_07",
    ["Fadeleaf"] = "Interface\\Icons\\INV_Misc_Herb_12",
    ["Felweed"] = "Interface\\Icons\\INV_Misc_Herb_Felweed",
    ["Firebloom"] = "Interface\\Icons\\INV_Misc_Herb_19",
    ["Goldthorn"] = "Interface\\Icons\\INV_Misc_Herb_15",
    ["Grave Moss"] = "Interface\\Icons\\INV_Misc_Dust_02",
    ["Gromsblood"] = "Interface\\Icons\\INV_Misc_Herb_16",
    ["Icecap"] = "Interface\\Icons\\INV_Misc_Herb_IceCap",
    ["Kingsblood"] = "Interface\\Icons\\INV_Misc_Herb_03",
    ["Liferoot"] = "Interface\\Icons\\INV_Misc_Root_02",
    ["Mageroyal"] = "Interface\\Icons\\INV_Jewelry_Talisman_03",
    ["Peacebloom"] = "Interface\\Icons\\INV_Misc_Flower_02",
    ["Plaguebloom"] = "Interface\\Icons\\INV_Misc_Herb_PlagueBloom",
    ["Silverleaf"] = "Interface\\Icons\\INV_Misc_Herb_10",
    ["Stranglekelp"] = "Interface\\Icons\\INV_Misc_Herb_11",
    ["Sungrass"] = "Interface\\Icons\\INV_Misc_Herb_18",
    ["Swiftthistle"] = "Interface\\Icons\\INV_Misc_Herb_04",
    ["Wildvine"] = "Interface\\Icons\\INV_Misc_Herb_03",
    ["Wintersbite"] = "Interface\\Icons\\INV_Misc_Flower_03",
    ["Arthas' Tears"] = "Interface\\Icons\\INV_Misc_Herb_13",
    ["Ghost Mushroom"] = "Interface\\Icons\\INV_Mushroom_08",
    ["Golden Sansam"] = "Interface\\Icons\\INV_Misc_Herb_SansamRoot",
    ["Khadgar's Whisker"] = "Interface\\Icons\\INV_Misc_Herb_08",
    ["Mountain Silversage"] = "Interface\\Icons\\INV_Misc_Herb_MountainSilverSage",
    ["Purple Lotus"] = "Interface\\Icons\\INV_Misc_Herb_17",
    ["Wild Steelbloom"] = "Interface\\Icons\\INV_Misc_Flower_01",
    ["Blood Thistle"] = "Interface\\Icons\\INV_Misc_Herb_Nightmareseed",
    ["Mana Thistle"] = "Interface\\Icons\\INV_Misc_Herb_Manathistle",
    ["Netherbloom"] = "Interface\\Icons\\INV_Misc_Herb_Netherbloom",
    ["Nightmare Vine"] = "Interface\\Icons\\INV_Misc_Herb_Nightmarevine",
    ["Ragveil"] = "Interface\\Icons\\INV_Misc_Herb_Ragveil",
    ["Terocone"] = "Interface\\Icons\\INV_Misc_Herb_Terrocone",
    ["Flame Cap"] = "Interface\\Icons\\INV_Misc_Herb_Flamecap",
    ["Dreaming Glory"] = "Interface\\Icons\\INV_Misc_Herb_Dreamingglory",
    ["Fel Lotus"] = "Interface\\Icons\\INV_Misc_Herb_FelLotus",
    ["Ancient Lichen"] = "Interface\\Icons\\INV_Misc_Herb_AncientLichen",
}

local function BuildSimplePerformPattern()
    if type(SIMPLEPERFORMSELFOTHER) ~= "string" then
        return nil
    end

    local escaped = string.gsub(SIMPLEPERFORMSELFOTHER, "([%(%)%.%*%+%-%[%]%?%^%$%%])", "%%%1")
    return "^" .. string.gsub(escaped, "%%%%s", "(.+)") .. "$"
end

local function CapturePlayerMapContext()
    local mapWasShown = WorldMapFrame and WorldMapFrame:IsShown()
    local oldContinent, oldZone, oldFloor

    if mapWasShown then
        oldContinent = GetCurrentMapContinent() or 0
        oldZone = GetCurrentMapZone() or 0
        if GetCurrentMapDungeonLevel then
            oldFloor = GetCurrentMapDungeonLevel() or 0
        else
            oldFloor = 0
        end
    end

    SetMapToCurrentZone()
    local x, y = GetPlayerMapPosition("player")
    local key = addon:GetMapKey()

    if mapWasShown and oldContinent and oldContinent > 0 then
        if oldZone and oldZone > 0 then
            SetMapZoom(oldContinent, oldZone)
        else
            SetMapZoom(oldContinent)
        end
        if SetDungeonMapLevel and oldFloor and oldFloor > 0 then
            SetDungeonMapLevel(oldFloor)
        end
    end

    return key, x, y
end

local function NormalizeMiningNodeName(text)
    if not text or text == "" then
        return nil
    end

    local node = string.gsub(text, " %(%d+%)", "")

    if string.find(node, " Vein$") or string.find(node, " Deposit$") then
        return node
    end

    local _, _, ore, suffix = string.find(node, "([^ ]+) ([^ ]+)$")
    if ore and suffix and (suffix == "Vein" or suffix == "Deposit") then
        return ore .. " " .. suffix
    end

    if string.find(node, "Thorium") and not string.find(node, "Vein") then
        if string.find(node, "Rich") then
            return "Rich Thorium Vein"
        elseif string.find(node, "Small") then
            return "Small Thorium Vein"
        end
    end

    return nil
end

function addon:GetMiningIconPath(nodeName)
    if not nodeName then
        return nil
    end

    for key, path in pairs(MINING_ICON_PATHS) do
        if string.find(nodeName, key) then
            return path
        end
    end

    return nil
end

local function NormalizeHerbName(text)
    if not text or text == "" then
        return nil
    end

    local herb = text
    local _, _, stripped = string.find(herb, "^(.-) %(%d+%)$")
    if stripped then
        herb = stripped
    end

    for key in pairs(HERBALISM_ICON_PATHS) do
        if herb == key then
            return key
        end
    end

    for key in pairs(HERBALISM_ICON_PATHS) do
        if string.find(herb, key) then
            return key
        end
    end

    return nil
end

function addon:GetHerbalismIconPath(herbName)
    if not herbName then
        return nil
    end
    return HERBALISM_ICON_PATHS[herbName]
end

function addon:GetAutoIconForName(name)
    return self:GetMiningIconPath(name) or self:GetHerbalismIconPath(NormalizeHerbName(name))
end

local function AddAutomaticGatheringNote(normalizedName, iconPath)
    local mapKey, x, y = CapturePlayerMapContext()
    if not mapKey or not x or not y or (x == 0 and y == 0) then
        return
    end

    ForgedMapNotesDB.notes = ForgedMapNotesDB.notes or {}
    ForgedMapNotesDB.notes[mapKey] = ForgedMapNotesDB.notes[mapKey] or {}
    local notes = ForgedMapNotesDB.notes[mapKey]

    local threshold = 0.003
    for i = 1, table.getn(notes) do
        local note = notes[i]
        if note and note.name == normalizedName and math.abs((note.x or 0) - x) <= threshold and math.abs((note.y or 0) - y) <= threshold then
            return
        end
    end

    table.insert(notes, {
        x = x,
        y = y,
        name = normalizedName,
        icon = iconPath,
    })

    addon:RefreshPins()
end

local function AddAutomaticMiningNote(nodeName)
    local normalized = NormalizeMiningNodeName(nodeName)
    if not normalized then
        return
    end

    AddAutomaticGatheringNote(normalized, addon:GetMiningIconPath(normalized))
end

local function AddAutomaticHerbalismNote(herbName)
    local normalized = NormalizeHerbName(herbName)
    if not normalized then
        return
    end

    AddAutomaticGatheringNote(normalized, addon:GetHerbalismIconPath(normalized))
end

function addon:OnGatheringInit()
    self.miningPerformPattern = BuildSimplePerformPattern()
    self.herbalismPerformPattern = self.miningPerformPattern
end

function addon:HandleGatheringEvent(event, msg)
    if event == "SPELLCAST_START" then
        if msg and string.find(string.lower(msg), "mining") then
            if GameTooltipTextLeft1 and GameTooltipTextLeft1.GetText then
                AddAutomaticMiningNote(GameTooltipTextLeft1:GetText())
            end
        elseif msg and string.find(string.lower(msg), "herb") then
            if GameTooltipTextLeft1 and GameTooltipTextLeft1.GetText then
                AddAutomaticHerbalismNote(GameTooltipTextLeft1:GetText())
            end
        end
        return true
    end

    if event == "UI_ERROR_MESSAGE" then
        if msg and string.find(string.lower(msg), "requires mining") then
            if GameTooltipTextLeft1 and GameTooltipTextLeft1.GetText then
                AddAutomaticMiningNote(GameTooltipTextLeft1:GetText())
            end
        elseif msg and string.find(string.lower(msg), "requires herbalism") then
            if GameTooltipTextLeft1 and GameTooltipTextLeft1.GetText then
                AddAutomaticHerbalismNote(GameTooltipTextLeft1:GetText())
            end
        end
        return true
    end

    if event == "CHAT_MSG_SPELL_SELF_BUFF" then
        if msg and self.miningPerformPattern then
            local _, _, skillName, targetName = string.find(msg, self.miningPerformPattern)
            if skillName and targetName then
                local lowerSkill = string.lower(skillName)
                if string.find(lowerSkill, "mining") then
                    AddAutomaticMiningNote(targetName)
                elseif string.find(lowerSkill, "herb") then
                    AddAutomaticHerbalismNote(targetName)
                end
            end
        end
        return true
    end

    return false
end
