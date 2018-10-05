-- ============================================================================
--  Components/Icon.lua
-- ----------------------------------------------------------------------------
--  A. Icon component
--   - Callbacks and updates
--   - Settings
--  B. Icon types
--   - OnCombatIcon component
--   - RestingIcon component
--   - PvPFlagIcon component
--   - GroupLeaderIcon component
--   - GroupRoleIcon component
--   - MasterLooterIcon component
--   - RaidTargetIcon component
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- ============================================================================
--  A. Icon component
-- ============================================================================

local Icon = OrbFrames:ComponentType('OrbFrames.Components.Icon')
OrbFrames.Components.Icon = Icon

-- ----------------------------------------------------------------------------
--  Callbacks and updates
-- ----------------------------------------------------------------------------

Icon.WIDTH = 32
Icon.HEIGHT = 32

function Icon:OnInitialize(entity)
    self:SetScript('OnShow', self.OnShow)
    self:RegisterMessage('ENTITY_SIZE_CHANGED', self.OnEntitySizeChanged)

    self.region = entity:CreateTexture(entity:GetName()..'_'..self:GetName())
    self.region:SetDrawLayer('OVERLAY')
    self.region:Hide()

    self:SetIconScale(1)
end

function Icon:OnShow()
    self:UpdateIcon()
end

function Icon:OnEntitySizeChanged()
end

function Icon:OnParentUnitEvent(event, unitID)
    local parentUnit = self.parentUnit
    if unitID == parentUnit or (parentUnit == 'player' and unitID == nil) then
        self:UpdateIcon()
    end
end

function Icon:RegisterEvents()
    self:UnregisterAllEvents()
    local unit = self.unit
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
    error('Not implemented') -- Override me
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
    region:SetWidth(iconScale * self.WIDTH)
    region:SetHeight(iconScale * self.HEIGHT)
end

function Icon:SetAnchor(anchor)
    self.anchor = anchor
    self:UpdateAnchors()
end

function Icon:SetUnit(unit)
    self.unit = unit
    local parentUnit = string.match(unit, '^(.*)target$')
    if parentUnit == '' or unit == 'focus' then
        parentUnit = 'player'
    end
    self.parentUnit = parentUnit
    self:RegisterEvents()
end

-- ============================================================================
--  B. Icon types
-- ============================================================================

local IconTypes = { }
OrbFrames.IconTypes = IconTypes

-- ----------------------------------------------------------------------------
--  InCombatIcon component
-- ----------------------------------------------------------------------------

local InCombatIcon = OrbFrames:ComponentType('OrbFrames.Components.InCombatIcon', Icon)
OrbFrames.Components.InCombatIcon = InCombatIcon
IconTypes['inCombat'] = InCombatIcon

function InCombatIcon:OnInitialize(entity)
    Icon.OnInitialize(self, entity)

    OrbFrames.ApplyTexture(self.region, {
        file = 'Interface\\CharacterFrame\\UI-StateIcon',
        0.5, 1, 0, 0.5,
    })
    -- TODO: there is a glow overlay in UI-StateIcon; use it?
end

function InCombatIcon:RegisterEvents()
    Icon.RegisterEvents(self)
    local unit = self.unit
    if unit == 'player' then
        self:RegisterEvent('PLAYER_REGEN_DISABLED', self.OnPlayerRegenDisabled)
        self:RegisterEvent('PLAYER_REGEN_ENABLED', self.OnPlayerRegenEnabled)
    end
end

function InCombatIcon:OnPlayerRegenDisabled(event)
    self.inCombat = true
    self.region:Show()
end

function InCombatIcon:OnPlayerRegenEnabled(event)
    self.inCombat = false
    self.region:Hide()
end

function InCombatIcon:UpdateIcon()
    local region = self.region
    if self.inCombat then
        region:Show()
    else
        region:Hide()
    end
end

-- ----------------------------------------------------------------------------
--  RestingIcon component
-- ----------------------------------------------------------------------------

local RestingIcon = OrbFrames:ComponentType('OrbFrames.Components.RestingIcon', Icon)
OrbFrames.Components.RestingIcon = RestingIcon
IconTypes['resting'] = RestingIcon

function RestingIcon:OnInitialize(entity)
    Icon.OnInitialize(self, entity)

    OrbFrames.ApplyTexture(self.region, {
        file = 'Interface\\CharacterFrame\\UI-StateIcon',
        0, 0.5, 0, 0.5,
    })
    -- TODO: there is a glow overlay in UI-StateIcon; use it?
end

function RestingIcon:RegisterEvents()
    Icon.RegisterEvents(self)
    local unit = self.unit
    if unit == 'player' then
        self:RegisterEvent('PLAYER_UPDATE_RESTING', self.OnPlayerUpdateResting)
    end
end

function RestingIcon:OnPlayerUpdateResting(event)
    self:UpdateIcon()
end

function RestingIcon:UpdateIcon()
    local region = self.region
    if self.unit == 'player' and IsResting() then
        region:Show()
    else
        region:Hide()
    end
end

-- ----------------------------------------------------------------------------
--  PvPFlagIcon component
-- ----------------------------------------------------------------------------

local PvPFlagIcon = OrbFrames:ComponentType('OrbFrames.Components.PvPFlagIcon', Icon)
OrbFrames.Components.PvPFlagIcon = PvPFlagIcon
IconTypes['pvpFlag'] = PvPFlagIcon

PvPFlagIcon.WIDTH = 40
PvPFlagIcon.HEIGHT = 40

PvPFlagIcon.TEXTURES = {
    Alliance = {
        file = 'Interface\\TargetingFrame\\UI-PVP-Alliance',
        0, 40/64, 0, 40/64,
    },
    Horde = {
        file = 'Interface\\TargetingFrame\\UI-PVP-Horde',
        0, 40/64, 0, 40/64,
    },
    FreeForAll = {
        file = 'Interface\\TargetingFrame\\UI-PVP-FFA',
        0, 40/64, 0, 40/64,
    },
}

function PvPFlagIcon:OnInitialize(entity)
    Icon.OnInitialize(self, entity)
end

function PvPFlagIcon:RegisterEvents()
    Icon.RegisterEvents(self)
end

function PvPFlagIcon:UpdateIcon()
    local unit = self.unit
    local region = self.region
    if UnitIsPVPFreeForAll(unit) then
        OrbFrames.ApplyTexture(region, self.TEXTURES.FreeForAll)
        region:Show()
    else
        local faction = UnitFactionGroup(unit)
        if faction and faction ~= 'Neutral' and UnitIsPVP(unit) then
            OrbFrames.ApplyTexture(region, self.TEXTURES[faction])
            region:Show()
        else
            region:Hide()
        end
    end
end

-- ----------------------------------------------------------------------------
--  GroupLeaderIcon component
-- ----------------------------------------------------------------------------

local GroupLeaderIcon = OrbFrames:ComponentType('OrbFrames.Components.GroupLeaderIcon', Icon)
OrbFrames.Components.GroupLeaderIcon = GroupLeaderIcon
IconTypes['groupLeader'] = GroupLeaderIcon

function GroupLeaderIcon:OnInitialize(entity)
    Icon.OnInitialize(self, entity)
end

function GroupLeaderIcon:RegisterEvents()
    Icon.RegisterEvents(self)
end

function GroupLeaderIcon:UpdateIcon()
    local unit = self.unit
    local region = self.region
end

-- ----------------------------------------------------------------------------
--  GroupRoleIcon component
-- ----------------------------------------------------------------------------

local GroupRoleIcon = OrbFrames:ComponentType('OrbFrames.Components.GroupRoleIcon', Icon)
OrbFrames.Components.GroupRoleIcon = GroupRoleIcon
IconTypes['groupRole'] = GroupRoleIcon

function GroupRoleIcon:OnInitialize(entity)
    Icon.OnInitialize(self, entity)
end

function GroupRoleIcon:RegisterEvents()
    Icon.RegisterEvents(self)
end

function GroupRoleIcon:UpdateIcon()
    local unit = self.unit
    local region = self.region
end

-- ----------------------------------------------------------------------------
--  MasterLooterIcon component
-- ----------------------------------------------------------------------------

local MasterLooterIcon = OrbFrames:ComponentType('OrbFrames.Components.MasterLooterIcon', Icon)
OrbFrames.Components.MasterLooterIcon = MasterLooterIcon
IconTypes['masterLooter'] = MasterLooterIcon

function MasterLooterIcon:OnInitialize(entity)
    Icon.OnInitialize(self, entity)
end

function MasterLooterIcon:RegisterEvents()
    Icon.RegisterEvents(self)
end

function MasterLooterIcon:UpdateIcon()
    local unit = self.unit
    local region = self.region
end

-- ----------------------------------------------------------------------------
--  RaidTargetIcon component
-- ----------------------------------------------------------------------------

local RaidTargetIcon = OrbFrames:ComponentType('OrbFrames.Components.RaidTargetIcon', Icon)
OrbFrames.Components.RaidTargetIcon = RaidTargetIcon
IconTypes['raidTarget'] = RaidTargetIcon

RaidTargetIcon.TEXTURES = {
    [1] = { file = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons', 0/4, 1/4, 0/4, 1/4, },
    [2] = { file = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons', 1/4, 2/4, 0/4, 1/4, },
    [3] = { file = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons', 2/4, 3/4, 0/4, 1/4, },
    [4] = { file = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons', 3/4, 4/4, 0/4, 1/4, },
    [5] = { file = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons', 0/4, 1/4, 1/4, 2/4, },
    [6] = { file = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons', 1/4, 2/4, 1/4, 2/4, },
    [7] = { file = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons', 2/4, 3/4, 1/4, 2/4, },
    [8] = { file = 'Interface\\TargetingFrame\\UI-RaidTargetingIcons', 3/4, 4/4, 1/4, 2/4, },
}

function RaidTargetIcon:OnInitialize(entity)
    Icon.OnInitialize(self, entity)
end

function RaidTargetIcon:OnRaidTargetUpdate(event)
    self:UpdateIcon()
end

function RaidTargetIcon:RegisterEvents()
    Icon.RegisterEvents(self)
    self:RegisterEvent('RAID_TARGET_UPDATE', self.OnRaidTargetUpdate)
end

function RaidTargetIcon:UpdateIcon()
    local region = self.region
    local raidTarget = GetRaidTargetIndex(self.unit)
    if raidTarget then
        OrbFrames.ApplyTexture(region, self.TEXTURES[raidTarget])
        region:Show()
    else
        region:Hide()
    end
end
