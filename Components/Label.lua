-- ============================================================================
--  Components/Label.lua
-- ----------------------------------------------------------------------------
--  A. Label component
--   - Callbacks and updates
--   - Settings
--  B. Label tags
--   - Formatting method
--   - Tags
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

local ResourceDisplay = OrbFrames.Components.ResourceDisplay

-- ============================================================================
--  A. Label component
-- ============================================================================

local Label = OrbFrames:ComponentType('OrbFrames.Components.Label', ResourceDisplay)
OrbFrames.Components.Label = Label

-- ----------------------------------------------------------------------------
--  Callbacks and updates
-- ----------------------------------------------------------------------------

function Label:OnInitialize(entity)
    self:SetScript('OnShow', self.OnShow)
    self:RegisterMessage('ENTITY_SIZE_CHANGED', self.OnEntitySizeChanged)

    self.fontstring = entity:CreateFontString(entity:GetName()..'_'..self:GetName())
    self.fontstring:SetFontObject(GameFontNormal)
end

function Label:OnShow()
    self:UpdateText()
end

function Label:OnEntitySizeChanged()
end

function Label:UpdateAnchors()
    local fontstring = self.fontstring
    fontstring:ClearAllPoints()
    local anchor = self.anchor
    if anchor == nil then anchor = { point = 'CENTER' } end
    local relativePoint = anchor.relativePoint
    if relativePoint == nil then relativePoint = anchor.point end
    fontstring:SetPoint(anchor.point, self:GetEntity(), relativePoint, anchor.x, anchor.y)
end

function Label:UpdateText()
    self.fontstring:SetText(self:FormatTaggedText(self.text or ''))
end

-- ----------------------------------------------------------------------------
--  Settings
-- ----------------------------------------------------------------------------

function Label:SetUnit(unit)
    ResourceDisplay.SetUnit(self, unit)
    self:UpdateText()
end

function Label:SetResource(resource)
    ResourceDisplay.SetResource(self, resource)
    self:UpdateText()
end

function Label:SetText(text)
    self.text = text
    -- TODO: Analyze the format string here
    self:UpdateText()
end

function Label:SetFont(font)
    self.fontstring:SetFontObject(font)
end

function Label:SetAnchor(anchor)
    self.anchor = anchor
    self:UpdateAnchors()
end

function Label:SetWidth(width)
    self.fontstring:SetWidth(width)
end

function Label:SetHeight(height)
    self.fontstring:SetHeight(height)
end

function Label:SetJustifyH(justifyH)
    self.fontstring:SetJustifyH(justifyH)
end

function Label:SetJustifyV(justifyV)
    self.fontstring:SetJustifyV(justifyV)
end

function Label:SetShowOnlyOnHover(showOnlyOnHover)
    if showOnlyOnHover then
        self.fontstring:SetDrawLayer('HIGHLIGHT')
    else
        self.fontstring:SetDrawLayer('ARTWORK')
    end
end

-- ============================================================================
--  B. Label tags
-- ============================================================================

local LabelTags = { }
OrbFrames.LabelTags = LabelTags

-- ----------------------------------------------------------------------------
--  Formatting method
-- ----------------------------------------------------------------------------

function Label:FormatTaggedText(text)
    local unit = self.unit
    local newText = ''
    local state = 'start'
    local segmentStart = 1
    local braceDepth
    local tagName
    for i=1, #text do
        local c = string.sub(text, i, i)
        if state == 'start' then
            if c == '{' then
                state = 'tagName'
                newText = newText..string.sub(text, segmentStart, i-1)
                segmentStart = i+1
            end
        elseif state == 'tagName' then
            if c == '}' then
                state = 'start'
                tagName = string.sub(text, segmentStart, i-1)
                local tag = LabelTags[tagName]
                if tag and UnitExists(unit) then
                    newText = newText..tag(self)
                else
                    newText = newText..'-'
                end
                segmentStart = i+1
            elseif c == ':' then
                state = 'tagContents'
                braceDepth = 1
                tagName = string.sub(text, segmentStart, i-1)
                segmentStart = i+1
            end
        elseif state == 'tagContents' then
            if c == '{' then
                braceDepth = braceDepth + 1
            elseif c == '}' then
                braceDepth = braceDepth - 1
                if braceDepth == 0 then
                    state = 'start'
                    local tagContents = string.sub(text, segmentStart, i-1)
                    local tag = LabelTags[tagName]
                    if tag and UnitExists(unit) then
                        newText = newText..tag(self, tagContents)
                    else
                        newText = newText..'-'
                    end
                    segmentStart = i+1
                end
            end
        end
    end
    return newText..string.sub(text, segmentStart)
end

-- ----------------------------------------------------------------------------
--  Tags
-- ----------------------------------------------------------------------------

function LabelTags.name(label)
    return UnitName(label.unit)
end

function LabelTags.class(label)
    return UnitClass(label.unit)
end

function LabelTags.level(label)
    local level = UnitLevel(label.unit)
    if level > 0 then
        local classification = UnitClassification(label.unit)
        if classification == 'elite' or classification == 'rareelite' then
            return tostring(level)..'+'
        elseif classification == 'trivial' or classification == 'minus' then
            return tostring(level)..'-'
        else
            return tostring(level)
        end
    else
        return '??'
    end
end

function LabelTags.hasResource(label, tagContents)
    if (label.resource == 'health') or
       (label.resource == 'power' and UnitPowerMax(label.unit) > 0) or
       (label.resource == 'power2' and UnitPower2Max(label.unit) > 0) then
        return label:FormatTaggedText(tagContents)
    else
        return ''
    end
end

function LabelTags.resourceName(label)
    if label.resource == 'health' then
        return 'Health'
    elseif label.resource == 'power' then
        return LabelTags.powerName(label)
    elseif label.resource == 'power2' then
        return LabelTags.power2Name(label)
    end
end

function LabelTags.resource(label)
    if label.resource == 'health' then
        return LabelTags.health(label)
    elseif label.resource == 'power' then
        return LabelTags.power(label)
    elseif label.resource == 'power2' then
        return LabelTags.power2(label)
    end
end

function LabelTags.resourceMax(label)
    if label.resource == 'health' then
        return LabelTags.healthMax(label)
    elseif label.resource == 'power' then
        return LabelTags.powerMax(label)
    elseif label.resource == 'power2' then
        return LabelTags.power2Max(label)
    end
end

function LabelTags.resourcePercent(label)
    if label.resource == 'health' then
        return LabelTags.healthPercent(label)
    elseif label.resource == 'power' then
        return LabelTags.powerPercent(label)
    elseif label.resource == 'power2' then
        return LabelTags.power2Percent(label)
    end
end

function LabelTags.hasResource2(label, tagContents)
    if label.resource == 'power' and UnitPower2Max(label.unit) > 0 then
        return label:FormatTaggedText(tagContents)
    else
        return ''
    end
end

function LabelTags.resource2Name(label)
    if label.resource == 'power' then
        return LabelTags.power2Name(label)
    else
        return '-'
    end
end

function LabelTags.resource2(label)
    if label.resource == 'power' then
        return LabelTags.power2(label)
    else
        return '-'
    end
end

function LabelTags.resource2Max(label)
    if label.resource == 'power' then
        return LabelTags.power2Max(label)
    else
        return '-'
    end
end

function LabelTags.resource2Percent(label)
    if label.resource == 'power' then
        return LabelTags.power2Percent(label)
    else
        return '-'
    end
end

function LabelTags.health(label)
    return tostring(UnitHealth(label.unit))
end

function LabelTags.healthMax(label)
    return tostring(UnitHealthMax(label.unit))
end

function LabelTags.healthPercent(label)
    local health, healthMax = UnitHealth(label.unit), UnitHealthMax(label.unit)
    if healthMax == 0 then
        return '-'
    else
        return tostring(math.floor(health / healthMax * 100))
    end
end

function LabelTags.hasPower(label, tagContents)
    if UnitPowerMax(label.unit) > 0 then
        return label:FormatTaggedText(tagContents)
    else
        return ''
    end
end

function LabelTags.powerName(label)
    return L['POWER_'..select(2, UnitPowerType(label.unit))]
end

function LabelTags.power(label)
    return tostring(UnitPower(label.unit))
end

function LabelTags.powerMax(label)
    return tostring(UnitPowerMax(label.unit))
end

function LabelTags.powerPercent(label)
    local power, powerMax = UnitPower(label.unit), UnitPowerMax(label.unit)
    if powerMax == 0 then
        return '-'
    else
        return tostring(math.floor(power / powerMax * 100))
    end
end

function LabelTags.hasPower2(label, tagContents)
    if UnitPower2Max(label.unit) > 0 then
        return label:FormatTaggedText(tagContents)
    else
        return ''
    end
end

function LabelTags.power2Name(label)
    local powerType = select(2, UnitPower2Type(label.unit))
    if powerType then
        return L['POWER_'..powerType]
    else
        return '-'
    end
end

function LabelTags.power2(label)
    return tostring(UnitPower2(label.unit))
end

function LabelTags.power2Max(label)
    return tostring(UnitPower2Max(label.unit))
end

function LabelTags.power2Percent(label)
    local power2, power2Max = UnitPower2(label.unit), UnitPower2Max(label.unit)
    if power2Max == 0 then
        return '-'
    else
        return tostring(math.floor(power2 / power2Max * 100))
    end
end
