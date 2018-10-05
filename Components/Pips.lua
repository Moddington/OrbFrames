-- ============================================================================
--  Components/Pips.lua
-- ----------------------------------------------------------------------------
--  A. Pips component
--   - Callbacks and updates
--   - Helpers
--   - Settings
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

local ResourceDisplay = OrbFrames.Components.ResourceDisplay

-- ============================================================================
--  A. Pips component
-- ============================================================================

local Pips = OrbFrames:ComponentType('OrbFrames.Components.Pips', ResourceDisplay)
OrbFrames.Components.Pips = Pips

-- ----------------------------------------------------------------------------
--  Callbacks and updates
-- ----------------------------------------------------------------------------

function Pips:OnInitialize(entity, layer, subLayer)
    ResourceDisplay.OnInitialize(self, entity)

    self:SetScript('OnShow', self.OnShow)
    self:RegisterMessage('ENTITY_SIZE_CHANGED', self.OnEntitySizeChanged)

    self.pips = { }

    self.rotatePips = false
    self.baseRotation = 0
    self.layer = layer
    self.subLayer = subLayer
end

function Pips:OnShow()
    self:UpdateShape()
    self:UpdateTextures()
end

function Pips:OnEntitySizeChanged()
    self:UpdateShape()
end

function Pips:OnParentUnitEvent(event, unitID)
    local parentUnit = self.parentUnit
    if unitID == parentUnit or (parentUnit == 'player' and unitID == nil) then
        self:UpdateTextures()
    end
end

function Pips:OnUnitEvent(event, unitID, ...)
    local unit = self.unit
    if unitID == unit then
        if event == 'UNIT_MAX_POWER' or event == 'UNIT_MAX_HEALTH' then
            self:UpdateShape()
        end
        self:UpdateTextures()
    end
end

function Pips:UpdateShape()
    local shape = self.shape
    local entity = self:GetEntity()
    local width = entity:GetWidth()
    local height = entity:GetHeight()
    local pipCount, pipMaxCount = self:GetPipCount()
    local rotatePips = self.rotatePips
    local baseRotation = math.rad(self.baseRotation)
    for n=#self.pips+1, pipMaxCount do
        local name = entity:GetName()..'_'..self:GetName()..'_Pip'..tostring(n)
        local pip = entity:CreateTexture(name)
        pip:SetDrawLayer(self.layer, self.subLayer)
        self.pips[n] = pip
    end
    if shape == 'arc' then
        local radius, centerPoint, arcSegment = unpack(self.shapeArgs)
        local arcStart, arcEnd = unpack(arcSegment)
        local arcStep
        if (arcEnd - arcStart) % 360 == 0 then
            arcStep = (arcEnd - arcStart) / pipMaxCount
        else
            arcStep = (arcEnd - arcStart) / (pipMaxCount-1)
        end
        for n, pip in ipairs(self.pips) do
            if n > pipMaxCount then
                pip:Hide()
            else
                local theta = math.rad(arcStart + arcStep * (n-1))
                local x = radius * math.cos(theta) + centerPoint[1]
                local y = radius * math.sin(theta) + centerPoint[2]
                pip:SetPoint('CENTER', entity, 'CENTER', x, y)
                if rotatePips then
                    pip:SetRotation(baseRotation + theta)
                else
                    pip:SetRotation(baseRotation)
                end
            end
        end
    elseif shape == 'orb' then
        local radiusOffset, arcSegment = unpack(self.shapeArgs)
        local radius = (height / 2) + radiusOffset
        local arcStart, arcEnd = unpack(arcSegment)
        local arcStep
        if (arcEnd - arcStart) % 360 == 0 then
            arcStep = (arcEnd - arcStart) / pipMaxCount
        else
            arcStep = (arcEnd - arcStart) / (pipMaxCount-1)
        end
        for n, pip in ipairs(self.pips) do
            if n > pipMaxCount then
                pip:Hide()
            else
                local theta = math.rad(arcStart + arcStep * (n-1))
                local x = radius * math.cos(theta)
                local y = radius * math.sin(theta)
                pip:SetPoint('CENTER', entity, 'CENTER', x, y)
                if rotatePips then
                    pip:SetRotation(baseRotation + theta)
                else
                    pip:SetRotation(baseRotation)
                end
            end
        end
    elseif shape == 'line' then
        local lineSegment = unpack(self.shapeArgs)
        local x1, y1, x2, y2 = unpack(lineSegment)
        local xStep = (x2 - x1) / (pipMaxCount - 1)
        local yStep = (y2 - y1) / (pipMaxCount - 1)
        local theta = math.atan2(xStep, yStep)
        for n, pip in ipairs(self.pips) do
            if n > pipMaxCount then
                pip:Hide()
            else
                local x = x1 + xStep * (n-1)
                local y = y1 + yStep * (n-1)
                pip:SetPoint('CENTER', entity, 'CENTER', x, y)
                if rotatePips then
                    pip:SetRotation(baseRotation + theta)
                else
                    pip:SetRotation(baseRotation)
                end
            end
        end
    elseif shape == 'edge' then
        local edge, edgeOffset, edgeSegment = unpack(self.shapeArgs)
        local x1, y1, x2, y2
        if edge == 'top' then
            x1, y1 = edgeSegment[1] * width, height - edgeOffset
            x2, y2 = edgeSegment[2] * width, height - edgeOffset
        elseif edge == 'bottom' then
            x1, y1 = edgeSegment[1] * width, edgeOffset
            x2, y2 = edgeSegment[2] * width, edgeOffset
        elseif edge == 'left' then
            x1, y1 = edgeOffset, edgeSegment[1] * height
            x2, y2 = edgeOffset, edgeSegment[2] * height
        elseif edge == 'right' then
            x1, y1 = width - edgeOffset, edgeSegment[1] * height
            x2, y2 = width - edgeOffset, edgeSegment[2] * height
        end
        local xStep = (x2 - x1) / (pipMaxCount-1)
        local yStep = (y2 - y1) / (pipMaxCount-1)
        local theta = math.atan2(xStep, yStep)
        for n, pip in ipairs(self.pips) do
            if n > pipMaxCount then
                pip:Hide()
            else
                local x = x1 + xStep * (n-1)
                local y = y1 + yStep * (n-1)
                pip:SetPoint('CENTER', entity, 'BOTTOMLEFT', x, y)
                if rotatePips then
                    pip:SetRotation(baseRotation + theta)
                else
                    pip:SetRotation(baseRotation)
                end
            end
        end
    elseif shape == 'none' then
        for n, pip in ipairs(self.pips) do
            pip:Hide()
        end
    end
end

function Pips:UpdateTextures()
    self:UpdateShape()
    local pipCount, pipMaxCount = self:GetPipCount()
    if self.textures then
        local onTexture = self.textures.on
        local offTexture = self.textures.off
        for n, pip in pairs(self.pips) do
            if n > pipMaxCount then
                break
            elseif n <= pipCount then
                OrbFrames.ApplyTexture(pip, onTexture)
            else
                OrbFrames.ApplyTexture(pip, offTexture)
            end
        end
    end
end

-- ----------------------------------------------------------------------------
--  Helpers
-- ----------------------------------------------------------------------------

function Pips:GetPipCount()
    local unit = self.unit
    local resource = self.resource
    if unit then
        if resource == 'power2' then
            return UnitPower2(unit), UnitPower2Max(unit)
        end
    end
    return 0, 0
end

-- ----------------------------------------------------------------------------
--  Settings
-- ----------------------------------------------------------------------------

function Pips:SetUnit(unit)
    ResourceDisplay.SetUnit(self, unit)
    self:UpdateShape()
    self:UpdateTextures()
end

function Pips:SetResource(resource)
    ResourceDisplay.SetResource(self, resource)
    self:UpdateShape()
    self:UpdateTextures()
end

function Pips:SetShape(shape, ...)
    self.shape = shape
    self.shapeArgs = { ... }
    self:UpdateShape()
end

function Pips:SetSize(size)
    for n, pip in pairs(self.pips) do
        pip:SetWidth(size)
        pip:SetHeight(size)
    end
end

function Pips:SetRotatePips(rotatePips)
    self.rotatePips = rotatePips
    self:UpdateShape()
end

function Pips:SetBaseRotation(baseRotation)
    self.baseRotation = baseRotation
    self:UpdateShape()
end

function Pips:SetTextures(textures)
    self.textures = {
        on = textures.on,
        off = textures.off,
    }
    self:UpdateTextures()
end

function Pips:SetResourceTextures(resource, textures)
    -- TODO
    self:UpdateTextures()
end
