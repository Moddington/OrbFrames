-- ============================================================================
--  Orb.lua
-- ----------------------------------------------------------------------------
--  A. Orb creation and management
--  B. Callbacks and helpers
--  C. Settings
--  D. Regions
--  E. Local values and helper functions
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- Orb methods
local Orb = { }

-- Local values and helper functions
local mirrored_anchors
local ApplyTexture
local MirrorSetting

-- ============================================================================
--  A. Orb creation and management
-- ============================================================================

function OrbFrames:LoadAllOrbs()
    self:DisableAllOrbs()
    for name, _ in pairs(self.db.profile.orbs) do
        self:LoadOrb(name)
    end
    -- Now that all orbs are loaded, double-check that they all have parents set
    for name, orb in pairs(self.orbs) do
        if orb:GetParent() == nil then
            local parent = orb.parent
            orb.parent = nil
            orb:SetOrbParent(parent)
        end
    end
end

function OrbFrames:LoadOrb(name)
    local db = self.db.profile.orbs[name]
    if db == nil then error('Cannot load orb "'..name..'": settings do not exist for it') end
    local settings = db -- TODO: 'read' settings to apply inherit/mirror transforms instead of during application?
    local orb = self.orbs[name]
    if orb == nil then
        orb = self:CreateOrb(name, settings)
        self.orbs[name] = orb
    else
        orb:ApplyOrbSettings(settings)
    end
end

function OrbFrames:CreateOrb(name, settings)
    local orb = CreateFrame('Button', 'OrbFrames_Orb_'..name, UIParent, 'SecureUnitButtonTemplate')
    for k, v in pairs(Orb) do orb[k] = v end

    -- Initialize orb
    RegisterUnitWatch(orb)
    orb.regions = { }
    orb:EnableMouse(true)
    orb:SetMovable(true)
    orb:SetClampedToScreen(true)
    orb:SetFrameStrata('BACKGROUND')
    orb:SetScript('OnEvent', orb.OnEvent)
    orb:SetScript('OnDragStart', orb.OnDragStart)
    orb:SetScript('OnDragStop', orb.OnDragStop)

    -- Default orb settings
    orb.flipped = false
    orb.aspectRatio = 1

    -- Apply settings
    if settings ~= nil then orb:ApplyOrbSettings(settings) end

    return orb
end

function OrbFrames:EnableAllOrbs()
    for _, orb in pairs(self.orbs) do
        orb:SetOrbEnabled(true)
    end
end

function OrbFrames:DisableAllOrbs()
    for _, orb in pairs(self.orbs) do
        orb:SetOrbEnabled(false)
    end
end

function OrbFrames:LockAllOrbs()
    for _, orb in pairs(self.orbs) do
        orb:SetOrbLocked(true)
    end
end

function OrbFrames:UnlockAllOrbs()
    for _, orb in pairs(self.orbs) do
        orb:SetOrbLocked(false)
    end
end

-- ============================================================================
--  B. Callbacks and helpers
-- ============================================================================

function Orb:OnEvent(event, ...)
    if string.match(event, '^UNIT_') then
        -- UNIT_* events
        local unitID = ...
        if unitID == self.unit then
            self:UpdateOrb()
        end
    end
end

function Orb:OnDragStart(button)
    if button == 'LeftButton' then
        self:StartMoving()
    end
end

function Orb:OnDragStop()
    self:StopMovingOrSizing()
end

function Orb:RegisterOrbEvents()
    self:UnregisterAllEvents()
    local style = self.style
    if style == 'simple' then
        local resource = self.resource
        if resource == 'health' then
            self:RegisterEvent('UNIT_HEALTH')
            self:RegisterEvent('UNIT_HEALTH_FREQUENT')
            self:RegisterEvent('UNIT_MAXHEALTH')
        elseif resource == 'power' then
            self:RegisterEvent('UNIT_POWER_UPDATE')
            self:RegisterEvent('UNIT_POWER_FREQUENT')
            self:RegisterEvent('UNIT_MAXPOWER')
        end
    end
end

function Orb:SetOrbAnchors()
    self:ClearAllPoints()
    local anchor = self.anchor
    if anchor == nil then anchor = { point = 'CENTER' } end
    local relativeTo = anchor.relativeTo
    if relativeTo == nil then relativeTo = self:GetParent() end
    local relativePoint = anchor.relativePoint
    if relativePoint == nil then relativePoint = anchor.point end
    self:SetPoint(anchor.point, relativeTo, relativePoint, anchor.x, anchor.y)
end

function Orb:UpdateOrb()
    local style = self.style
    if style == 'simple' then
        local r_fillTexture = self.regions.fillTexture
        local unit = self.unit
        local resource = self.resource

        -- Update fill height
        local proportion
        if not UnitExists(unit) then
            proportion = 0
        elseif resource == 'health' then
            proportion = UnitHealth(unit) / UnitHealthMax(unit)
        elseif resource == 'power' then
            proportion = UnitPower(unit) / UnitPowerMax(unit)
        elseif resource == 'full' then
            proportion = 1
        elseif resource == 'empty' then
            proportion = 0
        end
        if proportion > 0 then
            proportion = math.min(1, proportion)
            r_fillTexture:SetHeight(self:GetHeight() * proportion)
            r_fillTexture:SetTexCoord(0, 1, 1 - proportion, 1)
            r_fillTexture:Show()
        else
            r_fillTexture:Hide()
        end

        -- Update fill color
        local colors = OrbFrames.db.profile.colors
        local colorStyle = self.colorStyle
        local color
        if colorStyle == 'class' then
            color = colors.classes[UnitClass(unit)]
        elseif colorStyle == 'resource' then
            if resource == 'health' then
                color = colors.resources['HEALTH']
            else
                color = colors.resources[select(2, UnitPowerType(unit))]
            end
        end
        r_fillTexture:SetVertexColor(unpack(color))
    else
        error('Orb has no style')
    end
end

function Orb:SuspendOrbUpdates()
    self.UpdateOrb = function() end
end

function Orb:ResumeOrbUpdates()
    self.UpdateOrb = Orb.UpdateOrb
end

-- ============================================================================
--  C. Settings
-- ============================================================================

local setting_application -- functions to apply settings to an orb, indexed by setting name
local setting_inheritance -- inheritance order for each setting

function Orb:ApplyOrbSettings(settings)
    -- Fetch inheritance orbs
    local inherit_orb
    local inherit = settings.inherit
    if inherit ~= nil then
        inherit_orb = OrbFrames.db.profile.orbs[inherit]
        if inherit_orb == nil then error('Inherited orb "'..inherit..'" does not exist') end
    end
    local mirror_orb
    local mirror = settings.mirror
    if mirror ~= nil then
        mirror_orb = OrbFrames.db.profile.orbs[mirror]
        if mirror_orb == nil then
            error('Mirrored orb "'..mirror..'" does not exist')
        end
    end

    -- Suspend orb updates
    self:SuspendUpdates()

    -- Apply settings
    for setting, apply in pairs(setting_application) do
        local value = settings[setting]
        if value == nil then
            -- Attempt to inherit value according to the setting's inheritance order
            for _, inherit_from in ipairs(setting_inheritance[setting]) do
                if inherit_from == 'inherit' then
                    value = inherit_orb[setting]
                elseif inherit_from == 'mirror' then
                    value = MirrorSetting(setting, mirror_orb[setting])
                end
                if value ~= nil then break end
            end
        end
        if value ~= nil then
            self[setting] = value
            apply(self, value)
        end
    end

    -- Resume orb updates
    self:ResumeUpdates()

    -- Update and return
    self:UpdateOrb()
end

function Orb:ApplyOrbSetting(setting, value)
    local apply = setting_application[setting]
    if apply == nil then error('Unknown setting "'..setting..'"') end

    if value ~= self[setting] then
        self[setting] = value
        apply(self, value)
    end
end

-- Setting 'enabled' (boolean)
-- Description: Whether the orb is enabled or disabled
setting_inheritance.enabled = { }
function setting_application.enabled(self, enabled)
    if enabled then
        self:ResumeOrbUpdates()
        self:Show()
    else
        self:Hide()
        self:SuspendOrbUpdates()
    end
end

-- Setting 'locked' (boolean)
-- Description: Whether the orb is locked in place, or can be repositioned with
--              the mouse
setting_inheritance.locked = { 'mirror', }
function setting_application.locked(self, locked)
    if locked then
        self:RegisterForDrag()
    else
        self:RegisterForDrag('LeftButton')
    end
end

-- Setting 'unit' (string)
-- Description: Which unit the orb is tracking
-- Values: Any valid WoW unit name
setting_inheritance.unit = { 'mirror', 'inherit', }
function setting_application.unit(self, unit)
    self:SetAttribute('unit', unit)
    SecureUnitButton_OnLoad(self, unit) -- TODO: menuFunc
    self:RegisterOrbEvents()
    self:UpdateOrb()
end

-- Setting 'resource' (string)
-- Description: Which resource the orb is displaying
-- Values: 'health' - The unit's health
--         'power'  - The unit's primary power type
--         'empty'  - Always show an empty orb
--         'full'   - Always show a full orb
setting_inheritance.resource = { 'mirror', 'inherit', }
function setting_application.resource(self, resource)
    self:RegisterOrbEvents()
    self:UpdateOrb()
end

-- Setting 'style' (string)
-- Description: The style used for the orb
-- Values: 'simple' - An orb that fills vertically
setting_inheritance.style = { 'mirror', 'inherit', }
function setting_application.style(self, style)
    if style == 'simple' then
        self:CreateOrbBackdropTexture()
        self:CreateOrbFillTexture()
        self:CreateOrbBorderTexture()
        self:CreateOrbBorderArtTexture()
    end
    self:RegisterOrbEvents()
end

-- Setting 'colorStyle' (string)
-- Description: The method used to choose the color for the orb liquid
-- Values: 'class'    - The unit's class color
--         'resource' - The resource's color
setting_inheritance.colorStyle = { 'mirror', 'inherit', }
function setting_application.colorStyle(self, colorStyle)
    self:UpdateOrb()
end

-- Setting 'size' (number)
-- Description: The vertical size of the orb
setting_inheritance.size = { 'mirror', 'inherit', }
function setting_application.size(self, size)
    local aspectRatio = self.aspectRatio
    if aspectRatio ~= nil then
        self:SetWidth(size * aspectRatio)
        self:SetHeight(size)
        self:UpdateOrb()
    end
end

-- Setting 'aspectRatio' (number)
-- Description: The ratio between the orb's height and its width
setting_inheritance.aspectRatio = { 'mirror', 'inherit', }
function setting_application.aspectRatio(self, aspectRatio)
    local size = self.size
    if size ~= nil then
        self:SetWidth(size * aspectRatio)
        self:SetHeight(size)
        self:UpdateOrb()
    end
end

-- Setting 'flipped' (boolean)
-- Description: Whether the orb is flipped horizontally
setting_inheritance.flipped = { 'mirror', 'inherit', }
function setting_application.flipped(self, flipped)
    self:UpdateOrb()
end

-- Setting 'parent' (string)
-- Description: Which orb, if any, to be parented to
-- Values: Any valid orb name
--         nil - Parent to UIParent instead
-- TODO - allow parenting to any frame
setting_inheritance.parent = { 'mirror', 'inherit', }
function setting_application.parent(self, parent)
    if parent == nil then
        parent = UIParent
    else
        parent = OrbFrames.orbs[parent]
    end
    self:SetParent(parent)
    self:SetOrbAnchors()
end

-- Setting 'anchor' (table)
-- Description: An anchor used to position the orb
-- Values: { point (string)         - Point on the orb to anchor with
--         , relativeTo (string)    - Name of the frame to anchor to (defaults
--                                    to the orb's parent)
--         , relativePoint (string) - Point on the relative frame to anchor to
--                                    (defaults to same as point)
--         , x (number)             - X offset
--         , y (number)             - Y offset
--         }
--         nil - Defaults to { point = 'CENTER', }
-- Notes: Valid points are: TOPLEFT, TOP, TOPRIGHT, RIGHT, BOTTOMRIGHT,
--        BOTTOM, BOTTOMLEFT, LEFT, CENTER
setting_inheritance.anchor = { 'mirror', 'inherit', }
function setting_application.anchor(self, anchor)
    self:SetOrbAnchors()
end

-- Setting 'backdropTexture' (string)
-- Description: Name of the texture to use as a backdrop
-- Values: Any valid path to a texture
setting_inheritance.backdropTexture = { 'mirror', 'inherit', }
function setting_application.backdropTexture(self, backdropTexture)
    local r_backdropTexture = self.regions.backdropTexture
    if r_backdropTexture ~= nil then ApplyTexture(r_backdropTexture, backdropTexture) end
end

-- Setting 'fillTexture' (string)
-- Description: Name of the texture to use for the fill
-- Values: Any valid path to a texture
setting_inheritance.fillTexture = { 'mirror', 'inherit', }
function setting_application.fillTexture(self, fillTexture)
    local r_fillTexture = self.regions.fillTexture
    if r_fillTexture ~= nil then ApplyTexture(r_fillTexture, fillTexture) end
end

-- Setting 'borderTexture' (string)
-- Description: Name of the texture to use as a border
-- Values: Any valid path to a texture
setting_inheritance.borderTexture = { 'mirror', 'inherit', }
function setting_application.borderTexture(self, borderTexture)
    local r_borderTexture = self.regions.borderTexture
    if r_borderTexture ~= nil then ApplyTexture(r_borderTexture, borderTexture) end
end

-- Setting 'borderArtTexture' (string)
-- Description: Name of the texture to use as border artwork
-- Values: Any valid path to a texture
setting_inheritance.borderArtTexture = { 'mirror', 'inherit', }
function setting_application.borderArtTexture(self, borderArtTexture)
    local r_borderArtTexture = self.regions.borderArtTexture
    if r_borderArtTexture ~= nil then ApplyTexture(r_borderArtTexture, borderArtTexture) end
end

-- ============================================================================
--  D. Regions
-- ============================================================================

function Orb:CreateOrbBackdropTexture()
    if self.regions.backdropTexture == nil then
        local r_backdropTexture = self:CreateTexture()
        r_backdropTexture:SetAllPoints(self)
        r_backdropTexture:SetDrawLayer('BACKGROUND')
        r_backdropTexture:SetVertexColor(0, 0, 0, 1) -- TODO: remove
        local backdropTexture = self.backdropTexture
        if backdropTexture ~= nil then ApplyTexture(r_backdropTexture, backdropTexture) end
        self.regions.backdropTexture = r_backdropTexture
    end
end

function Orb:CreateOrbFillTexture()
    if self.regions.fillTexture == nil then
        local r_fillTexture = self:CreateTexture()
        r_fillTexture:SetPoint('BOTTOMLEFT')
        r_fillTexture:SetPoint('BOTTOMRIGHT')
        r_fillTexture:SetHeight(self:GetHeight())
        r_fillTexture:SetDrawLayer('ARTWORK', 0)
        local fillTexture = self.fillTexture
        if fillTexture ~= nil then ApplyTexture(r_fillTexture, fillTexture) end
        self.regions.fillTexture = r_fillTexture
    end
end

function Orb:CreateOrbBorderTexture()
    if self.regions.borderTexture == nil then
        local r_borderTexture = self:CreateTexture()
        r_borderTexture:SetAllPoints(self)
        r_borderTexture:SetDrawLayer('ARTWORK', 1)
        local borderTexture = self.borderTexture
        if borderTexture ~= nil then ApplyTexture(r_borderTexture, borderTexture) end
        self.regions.borderTexture = r_borderTexture
    end
end

function Orb:CreateOrbBorderArtTexture()
    if self.regions.borderArtTexture == nil then
        local r_borderArtTexture = self:CreateTexture()
        r_borderArtTexture:SetAllPoints(self)
        r_borderArtTexture:SetDrawLayer('ARTWORK', 2)
        local borderArtTexture = self.borderArtTexture
        if borderArtTexture ~= nil then ApplyTexture(r_borderArtTexture, borderArtTexture) end
        self.regions.borderArtTexture = r_borderArtTexture
    end
end

-- ============================================================================
--  E. Local values and helper functions
-- ============================================================================

mirrored_anchors = {
    ['TOPLEFT'] = 'TOPRIGHT',
    ['TOP'] = 'TOP',
    ['TOPRIGHT'] = 'TOPLEFT',
    ['RIGHT'] = 'LEFT',
    ['BOTTOMRIGHT'] = 'BOTTOMLEFT',
    ['BOTTOM'] = 'BOTTOM',
    ['BOTTOMLEFT'] = 'BOTTOMRIGHT',
    ['LEFT'] = 'RIGHT',
    ['CENTER'] = 'CENTER',
}

function ApplyTexture(r_texture, texture)
    if type(texture) == 'string' then
        r_texture:SetTexture(texture)
    elseif type(texture) == 'table' then
        r_texture:SetColorTexture(unpack(texture))
    end
end

function MirrorSetting(k, v)
    if v == nil then return end
    if k == 'anchor' then
        return {
            point = mirrored_anchors[v.point],
            relativeTo = v.relativeTo,
            relativePoint = mirrored_anchors[v.relativePoint],
            x = -v.x,
            y = v.y,
        }
    elseif k == 'flipped' then
        return not v
    else
        return v
    end
end
