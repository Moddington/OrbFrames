-- ============================================================================
--  Components/ResourceBar.lua
-- ----------------------------------------------------------------------------
--  A. ResourceBar component
--   - Callbacks and updates
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

local ResourceDisplay = OrbFrames.Components.ResourceDisplay

-- ============================================================================
--  A. ResourceBar component
-- ============================================================================

local ResourceBar = OrbFrames:ComponentType('OrbFrames.Components.ResourceBar', ResourceDisplay)
OrbFrames.Components.ResourceBar = ResourceBar

-- ----------------------------------------------------------------------------
--  Callbacks and updates
-- ----------------------------------------------------------------------------

function ResourceBar:OnInitialize(entity, layer, subLayer)
    self:SetScript('OnShow', self.OnShow)
    self:RegisterMessage('ENTITY_SIZE_CHANGED', self.OnEntitySizeChanged)

    self.textures = { }

    self.region = entity:CreateTexture(entity:GetName()..'_'..self:GetName())
    self.region:SetDrawLayer(layer, subLayer)
end

function ResourceBar:OnShow()
    self:UpdateProportion()
    self:UpdateColor()
    self:UpdateTexture()
end

function ResourceBar:OnUnitEvent(event, unitID, ...)
    if self.unit == unitID then
        self:UpdateProportion()
        self:UpdateColor()
        self:UpdateTexture()
    end
end

function ResourceBar:OnUnitResourceEvent(event, unitID, ...)
    if self.unit == unitID then
        self:UpdateProportion()
    end
end

function ResourceBar:OnParentUnitEvent(event, unitID, ...)
    if self.parentUnit == unitID or
        (self.parentUnit == 'player' and string.match(event, '^PLAYER')) then
        self:UpdateProportion()
        self:UpdateColor()
        self:UpdateTexture()
    end
end

function ResourceBar:OnEntitySizeChanged()
    self:UpdateProportion()
end

function ResourceBar:UpdateAnchors()
    local direction = self.direction
    local region = self.region
    region:ClearAllPoints()
    if direction == 'up' then
        region:SetPoint('BOTTOMLEFT')
        region:SetPoint('BOTTOMRIGHT')
    elseif direction == 'down' then
        region:SetPoint('TOPLEFT')
        region:SetPoint('TOPRIGHT')
    elseif direction == 'left' then
        region:SetPoint('TOPRIGHT')
        region:SetPoint('BOTTOMRIGHT')
    elseif direction == 'right' then
        region:SetPoint('TOPLEFT')
        region:SetPoint('BOTTOMLEFT')
    end
end

function ResourceBar:UpdateProportion()
    local entity = self:GetEntity()
    local region = self.region
    local unit = self.unit
    local resource = self.resource

    local proportion = 0
    if unit and UnitExists(unit) then
        if resource == 'health' then
            local health, healthMax = UnitHealth(unit), UnitHealthMax(unit)
            if healthMax > 0 then
                proportion = health / healthMax
            end
        elseif resource == 'power' then
            local power, powerMax = UnitPower(unit), UnitPowerMax(unit)
            if powerMax > 0 then
                proportion = power / powerMax
            end
        elseif resource == 'power2' then
            local power2, power2Max = UnitPower2(unit), UnitPower2Max(unit)
            if power2Max > 0 then
                proportion = power2 / power2Max
            end
        elseif resource == 'absorb' then
            -- TODO
        elseif resource == 'heals' then
            local health, healthMax = UnitHealth(unit), UnitHealthMax(unit)
            -- TODO
        elseif resource == 'full' then
            proportion = 1
        end
    end
    if proportion > 0 then
        proportion = math.min(1, proportion)
        local direction = self.direction
        if direction == 'up' then
            region:SetHeight(entity:GetHeight() * proportion)
            region:SetTexCoord(0, 1, 1 - proportion, 1)
        elseif direction == 'down' then
            region:SetHeight(entity:GetHeight() * proportion)
            region:SetTexCoord(0, 1, 0, proportion)
        elseif direction == 'left' then
            region:SetWidth(entity:GetWidth() * proportion)
            region:SetTexCoord(1 - proportion, 1, 0, 1)
        elseif direction == 'right' then
            region:SetWidth(entity:GetWidth() * proportion)
            region:SetTexCoord(0, proportion, 0, 1)
        end
        region:Show()
    else
        region:Hide()
    end
end

function ResourceBar:UpdateColor()
    local colors = OrbFrames.db.profile.colors
    local unit = self.unit
    local resource = self.resource
    local colorStyle = self.colorStyle

    local color
    if unit then
        if colorStyle == 'class' then
            color = colors.classes[select(2, UnitClass(unit))]
        elseif colorStyle == 'resource' then
            if resource == 'health' or resource == 'heals' then
                color = colors.resources['HEALTH']
            elseif resource == 'power' then
                color = colors.resources[select(2, UnitPowerType(unit))]
            elseif resource == 'power2' then
                local powerType = select(2, UnitPower2Type(unit))
                if powerType then
                    color = colors.resources[powerType]
                end
            elseif resource == 'absorb' then
                -- TODO
            end
        elseif colorStyle == 'reaction' then
            color = { UnitSelectionColor(unit) }
        end

        local alpha = 1
        if resource == 'heals' then
            alpha = 0.5
        end
    end

    if color ~= nil then
        self.region:SetVertexColor(color[1], color[2], color[3], alpha)
    end
end

function ResourceBar:UpdateTexture()
    local unit = self.unit
    local resource = self.resource

    local specificResource = 'default'
    if resource == 'health' or resource == 'heals' then
        specificResource = 'HEALTH'
    elseif resource == 'power' then
        specificResource = select(2, UnitPowerType(unit))
    elseif resource == 'power2' then
        specificResource = select(2, UnitPower2Type(unit))
    end

    local texture = self.textures[specificResource]
    if texture == nil then texture = self.textures.default end
    OrbFrames.ApplyTexture(self.region, texture)
end

-- ----------------------------------------------------------------------------
--  Settings
-- ----------------------------------------------------------------------------

function ResourceBar:SetUnit(unit)
    ResourceDisplay.SetUnit(self, unit)
    self:UpdateProportion()
    self:UpdateColor()
end

function ResourceBar:SetResource(resource)
    ResourceDisplay.SetResource(self, resource)
    self:UpdateProportion()
    self:UpdateColor()
    self:UpdateTexture()
end

function ResourceBar:SetColorStyle(colorStyle)
    self.colorStyle = colorStyle
    self:UpdateColor()
end

function ResourceBar:SetDirection(direction)
    self.direction = direction
    self:UpdateAnchors()
    self:UpdateProportion()
end

function ResourceBar:SetTexture(texture)
    self.textures.default = texture
    self:UpdateTexture()
end

function ResourceBar:SetResourceTexture(resource, texture)
    self.textures[resource] = texture
    self:UpdateTexture()
end
