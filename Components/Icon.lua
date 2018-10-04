-- ============================================================================
--  Components/Icon.lua
-- ----------------------------------------------------------------------------
--  A. Icon component
--   - Callbacks and updates
--   - Settings
--  B. Icon types
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- Icon types table
local IconTypes = { }
OrbFrames.IconTypes = IconTypes

-- ============================================================================
--  A. Icon component
-- ============================================================================

local Icon = OrbFrames:ComponentType('OrbFrames.Components.Icon')
OrbFrames.Components.Icon = Icon

-- ----------------------------------------------------------------------------
--  Callbacks and updates
-- ----------------------------------------------------------------------------

function Icon:OnInitialize(entity, iconType)
    self:SetScript('OnShow', self.OnShow)
    self:RegisterMessage('ENTITY_SIZE_CHANGED', self.OnEntitySizeChanged)

    self.iconType = IconTypes[iconType]

    self.region = entity:CreateTexture(entity:GetName()..'_'..self:GetName())
    self.region:SetDrawLayer('ARTWORK', 5)

    self:SetIconScale(1)
end

function Icon:OnShow()
    self:UpdateIcon()
end

function Icon:OnEntitySizeChanged()
end

function Icon:OnEvent(event, ...)
    self:UpdateIcon()
end

function Icon:RegisterEvents()
    self:UnregisterAllEvents()
    local iconType = self.iconType
    for n, event in ipairs(iconType.events) do
        self:RegisterEvent(event, self.OnEvent)
    end
end

function Icon:UpdateAnchors()
    local region = self.region
    region:ClearAllPoints()
    local anchor = self.anchor
    if anchor == nil then anchor = { point = 'CENTER' } end
    local relativePoint = anchor.relativePoint
    if relativePoint == nil then relativePoint = anchor.point end
    region:SetPoint(anchor.point, self:GetEntity(), relativePoint, anchor.x, anchor.y)
end

function Icon:UpdateIcon()
    local region = self.region
    if self.enabled then
        local iconType = self.iconType
        local textureKey = iconType.GetTextureKey(self.unit)
        if textureKey then
            OrbFrames.ApplyTexture(region, iconType.textures[textureKey])
            region:Show()
        else
            region:Hide()
        end
    else
        region:Hide()
    end
end

-- ----------------------------------------------------------------------------
--  Settings
-- ----------------------------------------------------------------------------

function Icon:SetEnabled(enabled)
    self.enabled = true
    self:UpdateIcon()
end

function Icon:SetIconScale(iconScale)
    local region = self.region
    local iconType = self.iconType
    region:SetWidth(iconScale * (iconType.width or 16))
    region:SetHeight(iconScale * (iconType.height or 16))
end

function Icon:SetAnchor(anchor)
    self.anchor = anchor
    self:UpdateAnchors()
end

function Icon:SetUnit(unit)
    self.unit = unit
    self:RegisterEvents()
end

-- ============================================================================
--  B. Icon types
-- ============================================================================

IconTypes.inCombat = {
    events = { },
    textures = {
    },
    GetTextureKey = function(unit)
    end,
}

IconTypes.resting = {
    events = { 'PLAYER_UPDATE_RESTING', },
    textures = {
        resting = { 1, 1, 1 },
    },
    GetTextureKey = function(unit)
        if unit == 'player' and IsResting() then
            return 'resting'
        end
    end,
}

IconTypes.pvpFlag = {
    events = { },
    width = 16,
    height = 32,
    textures = {
        alliance = { 1, 1, 1 },
        horde = { 1, 1, 1 },
    },
    GetTextureKey = function(unit)
    end,
}

IconTypes.groupLeader = {
    events = { },
    textures = {
    },
    GetTextureKey = function(unit)
    end,
}

IconTypes.groupRole = {
    events = { },
    textures = {
    },
    GetTextureKey = function(unit)
    end,
}

IconTypes.masterLooter = {
    events = { },
    textures = {
    },
    GetTextureKey = function(unit)
    end,
}

IconTypes.raidTarget = {
    events = { 'RAID_TARGET_UPDATE', },
    textures = {
        [1] = { 1, 1, 0 },
        [2] = { 1, 0.5, 0 },
        [3] = { 1, 0, 1 },
        [4] = { 0, 1, 0 },
        [5] = { 1, 1, 1 },
        [6] = { 0, 0, 1 },
        [7] = { 1, 0, 0 },
        [8] = { 0.5, 0.5, 0.5 },
    },
    GetTextureKey = function(unit)
        return GetRaidTargetIndex(unit)
    end,
}
