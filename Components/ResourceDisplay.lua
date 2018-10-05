-- ============================================================================
--  Components/ResourceDisplay.lua
-- ----------------------------------------------------------------------------
--  A. ResourceDisplay component
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- ============================================================================
--  A. ResourceDisplay component
-- ============================================================================

local ResourceDisplay = OrbFrames:ComponentType('OrbFrames.Components.ResourceDisplay')
OrbFrames.Components.ResourceDisplay = ResourceDisplay

function ResourceDisplay:OnInitialize(entity)
end

function ResourceDisplay:RegisterEvents()
    local unit = self.unit
    local resource = self.resource
    self:UnregisterAllEvents()
    if unit == 'focus' then
        self:RegisterEvent('PLAYER_FOCUS_CHANGED', self.OnParentUnitEvent)
    elseif string.match(unit, 'target$') then
        local parentUnit = self.parentUnit
        if parentUnit == 'player' then
            self:RegisterEvent('PLAYER_TARGET_CHANGED', self.OnParentUnitEvent)
        elseif parentUnit ~= nil then
            self:RegisterEvent('UNIT_TARGET', self.OnParentUnitEvent)
        end
    end
    if resource == 'health' then
        self:RegisterEvent('UNIT_HEALTH', self.OnUnitEvent)
        self:RegisterEvent('UNIT_HEALTH_FREQUENT', self.OnUnitEvent)
        self:RegisterEvent('UNIT_MAXHEALTH', self.OnUnitEvent)
    elseif resource == 'power' then
        self:RegisterEvent('UNIT_POWER_UPDATE', self.OnUnitEvent)
        self:RegisterEvent('UNIT_POWER_FREQUENT', self.OnUnitEvent)
        self:RegisterEvent('UNIT_MAXPOWER', self.OnUnitEvent)
        self:RegisterEvent('UNIT_DISPLAYPOWER', self.OnUnitEvent)
    elseif resource == 'power2' then
        self:RegisterEvent('UNIT_POWER_UPDATE', self.OnUnitEvent)
        self:RegisterEvent('UNIT_POWER_FREQUENT', self.OnUnitEvent)
        self:RegisterEvent('UNIT_MAXPOWER', self.OnUnitEvent)
    elseif resource == 'absorb' then
        -- TODO
    elseif resource == 'heals' then
        -- TODO
    end
end

function ResourceDisplay:SetUnit(unit)
    self.unit = unit
    local parentUnit = string.match(unit, '^(.*)target$')
    if parentUnit == '' or unit == 'focus' then
        parentUnit = 'player'
    end
    self.parentUnit = parentUnit
    self:RegisterEvents()
end

function ResourceDisplay:SetResource(resource)
    self.resource = resource
    self:RegisterEvents()
end
