-- ============================================================================
--  Components/Sconce.lua
-- ----------------------------------------------------------------------------
--  A. Sconce component
--  B. SimpleSconce component
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- ============================================================================
--  A. Sconce component
-- ============================================================================

local Sconce = OrbFrames:ComponentType('OrbFrames.Components.Sconce')
OrbFrames.Components.Sconce = Sconce

function Sconce:OnInitialize(entity)
    self.regions = { }
end

function Sconce:CreateTexture(name, layer, subLayer)
    local entity = self:GetEntity()
    local region, globalName
    if name ~= nil then
        globalName = entity:GetName()..'_'..name
        region = _G[globalName]
    end
    if region == nil then
        region = entity:CreateTexture(globalName)
    end
    region:SetAllPoints(entity)
    region:SetDrawLayer(layer, subLayer)
    self.regions[name] = region
    return region
end

function Sconce:SetTexture(name, texture)
    OrbFrames.ApplyTexture(self.regions[name], texture)
end

-- ============================================================================
--  B. SimpleSconce component
-- ============================================================================

local SimpleSconce = OrbFrames:ComponentType('OrbFrames.Components.SimpleSconce', Sconce)
OrbFrames.Components.SimpleSconce = SimpleSconce

function SimpleSconce:OnInitialize(entity)
    Sconce.OnInitialize(self, entity)

    self:RegisterMessage('ENTITY_SIZE_CHANGED', self.OnEntitySizeChanged)

    local backdrop = self:CreateTexture('Backdrop', 'BACKGROUND', -1)
    backdrop:SetVertexColor(0, 0, 0, 1) -- TODO: remove
    self:CreateTexture('BackdropArt', 'BACKGROUND', 0)
    self:CreateTexture('Border', 'ARTWORK', 1)
    self:CreateTexture('BorderArt', 'ARTWORK', 2)
end

function SimpleSconce:OnEntitySizeChanged()
    -- TODO: update relative coordinate anchors
end
