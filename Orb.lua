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
local ReadSettings

-- ============================================================================
--  A. Orb creation and management
-- ============================================================================

function OrbFrames:LoadAllOrbs()
    self:DisableAllOrbs() -- Disable all orbs, so that afterwards, only those
                          -- in the profile will be enabled
    -- Load all orbs
    for name, _ in pairs(self.db.profile.orbs) do
        self:LoadOrb(name, true)
    end
    -- Perform second-phase initialization
    for name, _ in pairs(self.db.profile.orbs) do
        local orb = self.orbs[name]
        orb:ApplyOrbSettings(orb.settings)
        orb.settings = nil
    end
end

function OrbFrames:LoadOrb(name, twoPhase)
    local settings = self.db.profile.orbs[name]
    if settings == nil then error('Cannot load orb "'..name..'": settings do not exist for it') end
    local orb = self.orbs[name]
    if orb == nil then
        orb = self:CreateOrb(name, settings, twoPhase)
        self.orbs[name] = orb
    else
        if twoPhase then
            orb.settings = settings
        else
            orb:ApplyOrbSettings(settings)
        end
    end
end

function OrbFrames:CreateOrb(name, settings, twoPhase)
    local orb = CreateFrame('Button', 'OrbFrames_Orb_'..name, UIParent, 'SecureUnitButtonTemplate')
    for k, v in pairs(Orb) do orb[k] = v end

    -- Initialize orb
    RegisterUnitWatch(orb)
    orb.regions = { }
    orb:EnableMouse(true)
    orb:SetMovable(true)
    orb:SetClampedToScreen(true)
    orb:SetFrameStrata('BACKGROUND')
    orb:SetScript('OnShow', orb.OnShow)
    orb:SetScript('OnEvent', orb.OnEvent)
    orb:SetScript('OnDragStart', orb.OnDragStart)
    orb:SetScript('OnDragStop', orb.OnDragStop)

    -- Default orb settings
    orb.enabled = true
    orb.flipped = false
    orb.aspectRatio = 1

    -- Apply settings
    if settings ~= nil then
        if twoPhase then
            orb.settings = settings
        else
            orb:ApplyOrbSettings(settings)
        end
    end

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

function Orb:OnShow()
    self:UpdateOrb()
end

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
        if color ~= nil then
            r_fillTexture:SetVertexColor(unpack(color))
        end
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

local Settings = { }

function Orb:ApplyOrbSettings(settings)
    -- Read orb settings to acquire inherited and default values
    settings = ReadSettings(settings)

    -- Suspend orb updates
    self:SuspendOrbUpdates()

    -- Apply settings
    for setting, fields in pairs(Settings) do
        local value = settings[setting]
        if value ~= nil and value ~= self[setting] then
            self[setting] = value
            fields.apply(self, value)
        end
    end

    -- Resume orb updates
    self:ResumeOrbUpdates()

    -- Update and return
    self:UpdateOrb()
end

function Orb:ApplyOrbSetting(setting, value)
    if value ~= self[setting] then
        self[setting] = value
        Settings[setting].apply(self, value)
    end
end

-- Setting 'enabled' (boolean)
-- Description: Whether the orb is enabled or disabled
Settings.enabled = { }
function Settings.enabled.apply(self, enabled)
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
Settings.locked = { }
function Settings.locked.apply(self, locked)
    if locked then
        self:RegisterForDrag()
    else
        self:RegisterForDrag('LeftButton')
    end
end

-- Setting 'unit' (string)
-- Description: Which unit the orb is tracking
-- Values: Any valid WoW unit name
Settings.unit = { }
function Settings.unit.apply(self, unit)
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
Settings.resource = { }
function Settings.resource.apply(self, resource)
    self:RegisterOrbEvents()
    self:UpdateOrb()
end

-- Setting 'style' (string)
-- Description: The style used for the orb
-- Values: 'simple' - An orb that fills vertically
Settings.style = { }
function Settings.style.apply(orb, style)
    if style == 'simple' then
        orb:CreateOrbBackdropTexture()
        orb:CreateOrbFillTexture()
        orb:CreateOrbBorderTexture()
        orb:CreateOrbBorderArtTexture()
    end
    orb:RegisterOrbEvents()
end

-- Setting 'colorStyle' (string)
-- Description: The method used to choose the color for the orb liquid
-- Values: 'class'    - The unit's class color
--         'resource' - The resource's color
Settings.colorStyle = { }
function Settings.colorStyle.apply(orb, colorStyle)
    orb:UpdateOrb()
end

-- Setting 'size' (number)
-- Description: The vertical size of the orb
Settings.size = { }
function Settings.size.apply(orb, size)
    local aspectRatio = orb.aspectRatio
    if aspectRatio ~= nil then
        orb:SetWidth(size * aspectRatio)
        orb:SetHeight(size)
        orb:UpdateOrb()
    end
end

-- Setting 'aspectRatio' (number)
-- Description: The ratio between the orb's height and its width
Settings.aspectRatio = { }
function Settings.aspectRatio.apply(orb, aspectRatio)
    local size = orb.size
    if size ~= nil then
        orb:SetWidth(size * aspectRatio)
        orb:SetHeight(size)
        orb:UpdateOrb()
    end
end

-- Setting 'flipped' (boolean)
-- Description: Whether the orb is flipped horizontally
Settings.flipped = { }
function Settings.flipped.apply(orb, flipped)
    orb:UpdateOrb()
end

-- Setting 'parent' (string)
-- Description: Which orb, if any, to be parented to
-- Values: Any valid orb name
--         nil - Parent to UIParent instead
-- TODO: allow parenting to any frame
Settings.parent = { }
function Settings.parent.apply(orb, parent)
    if parent == nil then
        parent = UIParent
    else
        parent = OrbFrames.orbs[parent]
    end
    orb:SetParent(parent)
    orb:SetOrbAnchors()
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
Settings.anchor = { }
function Settings.anchor.apply(orb, anchor)
    orb:SetOrbAnchors()
end

-- Setting 'backdropTexture' (string)
-- Description: Name of the texture to use as a backdrop
-- Values: Any valid path to a texture
Settings.backdropTexture = { }
function Settings.backdropTexture.apply(orb, backdropTexture)
    local r_backdropTexture = orb.regions.backdropTexture
    if r_backdropTexture ~= nil then ApplyTexture(r_backdropTexture, backdropTexture) end
end

-- Setting 'fillTexture' (string)
-- Description: Name of the texture to use for the fill
-- Values: Any valid path to a texture
Settings.fillTexture = { }
function Settings.fillTexture.apply(orb, fillTexture)
    local r_fillTexture = orb.regions.fillTexture
    if r_fillTexture ~= nil then ApplyTexture(r_fillTexture, fillTexture) end
end

-- Setting 'borderTexture' (string)
-- Description: Name of the texture to use as a border
-- Values: Any valid path to a texture
Settings.borderTexture = { }
function Settings.borderTexture.apply(orb, borderTexture)
    local r_borderTexture = orb.regions.borderTexture
    if r_borderTexture ~= nil then ApplyTexture(r_borderTexture, borderTexture) end
end

-- Setting 'borderArtTexture' (string)
-- Description: Name of the texture to use as border artwork
-- Values: Any valid path to a texture
Settings.borderArtTexture = { }
function Settings.borderArtTexture.apply(orb, borderArtTexture)
    local r_borderArtTexture = orb.regions.borderArtTexture
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

function ReadSettings(settings)
    local read_settings = { }
    for setting, value in pairs(settings) do
        read_settings[setting] = value
    end

    -- Prevent these settings from being inherited
    if read_settings.enabled == nil then read_settings.enabled = false end
    if read_settings.locked == nil then read_settings.locked = false end

    -- Fetch inherited settings
    local inherit_name = settings.inherit
    local inheritStyle = settings.inheritStyle or 'copy'
    if inherit_name ~= nil then
        local inherit_settings = OrbFrames.db.profile.orbs[inherit_name]
        if inherit_settings == nil then error('Inherited orb "'..inherit_name..'" does not exist') end
        inherit_settings = ReadSettings(inherit_settings)
        if inheritStyle == 'copy' then
            for setting, value in pairs(inherit_settings) do
                if read_settings[setting] == nil then
                    read_settings[setting] = value
                end
            end
        elseif inheritStyle == 'mirror' then
            for setting, value in pairs(inherit_settings) do
                if read_settings[setting] == nil then
                    read_settings[setting] = MirrorSetting(setting, value)
                end
            end
        end
    end

    -- TODO: applying default settings would go here

    return read_settings
end
