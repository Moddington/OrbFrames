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

local function GlobalTextureName(entity, name)
    if name ~= nil then
        local entityName = entity:GetName()
        if entityName ~= nil then
            return entityName..'_'..name
        end
    end
end

function Sconce:OnInitialize(entity)
    self.regions = { }
end

function Sconce:CreateTexture(name, layer, subLayer)
    local entity = self:GetEntity()
    local region, globalName
    if name ~= nil then
        local entityName = entity:GetName()
        if entityName ~= nil then
            globalName = entityName..'_'..name
            region = _G[globalName]
        end
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
    local entity = self:GetEntity()
    local region = self.regions[name]
    if type(texture) == 'string' then
        region:SetTexture(texture)
    elseif type(texture) == 'table' then
        region:SetColorTexture(unpack(texture))
    end
end

-- ============================================================================
--  B. SimpleSconce component
-- ============================================================================

local SimpleSconce = OrbFrames:ComponentType('OrbFrames.Components.SimpleSconce', Sconce)
OrbFrames.Components.SimpleSconce = SimpleSconce

function SimpleSconce:OnInitialize(entity)
    Sconce.OnInitialize(self, entity)

    self:RegisterMessage('ENTITY_UPDATE_ALL', self.OnEntityUpdateAll)
    self:RegisterMessage('ENTITY_UPDATE_SIZE', self.OnEntityUpdateSize)

    local backdrop = self:CreateTexture('Backdrop', 'BACKGROUND', -1)
    backdrop:SetVertexColor(0, 0, 0, 1) -- TODO: remove
    local backdropArt = self:CreateTexture('BackdropArt', 'BACKGROUND', 0)
    local border = self:CreateTexture('Border', 'ARTWORK', 1)
    local borderArt = self:CreateTexture('BorderArt', 'ARTWORK', 2)
end

function SimpleSconce:OnEntityUpdateAll()
    self:OnEntityUpdateSize()
end

function SimpleSconce:OnEntityUpdateSize()
    -- TODO: update relative coordinate anchors
end
