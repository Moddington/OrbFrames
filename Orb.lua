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

    -- Setting groups
    orb.backdrop = { }
    orb.backdropArt = { }
    orb.fill = { }
    orb.border = { }
    orb.borderArt = { }

    -- Default orb settings
    orb.enabled = true
    orb.flipped = false
    orb.direction = 'up'
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
    if event == UNIT_TARGET then
        local unitID = ...
        if unitID == string.gsub(self.unit, 'target$', '') then
            self:UpdateOrb()
        end
    elseif string.match(event, '^UNIT_') then
        -- UNIT_* events
        local unitID = ...
        if unitID == self.unit then
            self:UpdateOrb()
        end
    elseif event == 'PLAYER_TARGET_CHANGED' then
        self:UpdateOrb()
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
    if style == 'orb' then
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
    local unit = self.unit
    if unit == 'target' or unit == 'playertarget' then
        self:RegisterEvent('PLAYER_TARGET_CHANGED')
    elseif unit ~= nil and string.match(unit, 'target$') then
        self:RegisterEvent('UNIT_TARGET')
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
    if style == 'orb' then
        local fill = self.regions.fill
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
            local direction = self.direction
            if direction == 'up' then
                fill:SetHeight(self:GetHeight() * proportion)
                fill:SetTexCoord(0, 1, 1 - proportion, 1)
            elseif direction == 'down' then
                fill:SetHeight(self:GetHeight() * proportion)
                fill:SetTexCoord(0, 1, 0, proportion)
            elseif direction == 'left' then
                fill:SetWidth(self:GetWidth() * proportion)
                fill:SetTexCoord(1 - proportion, 1, 0, 1)
            elseif direction == 'right' then
                fill:SetWidth(self:GetWidth() * proportion)
                fill:SetTexCoord(0, proportion, 0, 1)
            end
            fill:Show()
        else
            fill:Hide()
        end

        -- Update fill color
        local colors = OrbFrames.db.profile.colors
        local colorStyle = self.colorStyle
        local color
        if colorStyle == 'class' then
            color = colors.classes[select(2, UnitClass(unit))]
        elseif colorStyle == 'resource' then
            if resource == 'health' then
                color = colors.resources['HEALTH']
            else
                color = colors.resources[select(2, UnitPowerType(unit))]
            end
        end
        if color ~= nil then
            fill:SetVertexColor(unpack(color))
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
    local function ApplySetting(name, groupName)
        local settings = settings
        if groupName then
            if settings[groupName] == nil then return end
            settings = settings[groupName]
        end
        if settings[name] == nil then return end
        self:ApplyOrbSetting(name, settings[name], groupName)
    end

    ApplySetting('enabled')
    ApplySetting('locked')

    ApplySetting('style')
    ApplySetting('unit')
    ApplySetting('resource')

    ApplySetting('colorStyle')
    ApplySetting('size')
    ApplySetting('aspectRatio')
    ApplySetting('direction')
    ApplySetting('flipped')
    ApplySetting('parent')
    ApplySetting('anchor')

    ApplySetting('texture', 'backdrop')
    ApplySetting('texture', 'backdropArt')
    ApplySetting('texture', 'fill')
    ApplySetting('texture', 'border')
    ApplySetting('texture', 'borderArt')

    -- Resume orb updates
    self:ResumeOrbUpdates()

    -- Update and return
    self:UpdateOrb()
end

function Orb:ApplyOrbSetting(name, value, groupName)
    local Settings = Settings
    local settings = self
    if groupName then
        if Settings[groupName] == nil then return end
        settings[groupName] = settings[groupName] or { }
        settings = settings[groupName]
        Settings = Settings[groupName]
    end
    if value ~= settings[name] then
        settings[name] = value
        Settings[name].apply(self, value)
    end
end

-- Setting 'enabled' (boolean)
-- Description: Whether the orb is enabled or disabled
Settings.enabled = {
    apply = function(orb, enabled)
        if enabled then
            orb:ResumeOrbUpdates()
            orb:Show()
        else
            orb:Hide()
            orb:SuspendOrbUpdates()
        end
    end,
}

-- Setting 'locked' (boolean)
-- Description: Whether the orb is locked in place, or can be repositioned with
--              the mouse
Settings.locked = {
    apply = function(orb, locked)
        if locked then
            orb:RegisterForDrag()
        else
            orb:RegisterForDrag('LeftButton')
        end
    end,
}

-- Setting 'style' (string)
-- Description: The style used for the orb
-- Values: 'orb' - A fixed-size element
-- TODO: 'bar' - A stretchable element
Settings.style = {
    apply = function(orb, style)
        if style == 'orb' then
            orb:CreateOrbBackdrop()
            orb:CreateOrbBackdropArt()
            orb:CreateOrbFill()
            orb:CreateOrbBorder()
            orb:CreateOrbBorderArt()
        end
        orb:RegisterOrbEvents()
    end,
}

-- Setting 'unit' (string)
-- Description: Which unit the orb is tracking
-- Values: Any valid WoW unit name
Settings.unit = {
    apply = function(orb, unit)
        orb:SetAttribute('unit', unit)
        SecureUnitButton_OnLoad(orb, unit) -- TODO: menuFunc
        orb:RegisterOrbEvents()
        orb:UpdateOrb()
    end,
}

-- Setting 'resource' (string)
-- Description: Which resource the orb is displaying
-- Values: 'health' - The unit's health
--         'power'  - The unit's primary power type
--         'empty'  - Always show an empty orb
--         'full'   - Always show a full orb
Settings.resource = {
    apply = function(orb, resource)
        orb:RegisterOrbEvents()
        orb:UpdateOrb()
    end,
}

-- Setting 'colorStyle' (string)
-- Description: The method used to choose the color for the orb liquid
-- Values: 'class'    - The unit's class color
--         'resource' - The resource's color
Settings.colorStyle = {
    apply = function(orb, colorStyle)
        orb:UpdateOrb()
    end,
}

-- Setting 'size' (number)
-- Description: The vertical size of the orb
Settings.size = {
    apply = function(orb, size)
        local aspectRatio = orb.aspectRatio
        if aspectRatio ~= nil then
            orb:SetWidth(size * aspectRatio)
            orb:SetHeight(size)
            orb:UpdateOrb()
        end
    end,
}

-- Setting 'aspectRatio' (number)
-- Description: The ratio between the orb's height and its width
Settings.aspectRatio = {
    apply = function(orb, aspectRatio)
        local size = orb.size
        if size ~= nil then
            orb:SetWidth(size * aspectRatio)
            orb:SetHeight(size)
            orb:UpdateOrb()
        end
    end,
}

-- Setting 'direction' (string)
-- Description: The direction the orb fills in
-- Values: 'up', 'down', 'left', 'right'
Settings.direction = {
    apply = function(orb, direction)
        if orb.regions.fill then
            orb:SetFillAnchors()
        end
    end,
}

-- Setting 'flipped' (boolean)
-- Description: Whether the orb is flipped horizontally
Settings.flipped = {
    apply = function(orb, flipped)
        orb:UpdateOrb()
    end,
}

-- Setting 'parent' (string)
-- Description: Which orb, if any, to be parented to
-- Values: Any valid orb name
--         nil - Parent to UIParent instead
-- TODO: allow parenting to any frame
Settings.parent = {
    apply = function(orb, parent)
        if parent == nil then
            parent = UIParent
        else
            parent = OrbFrames.orbs[parent]
        end
        orb:SetParent(parent)
        orb:SetOrbAnchors()
    end,
}

-- Setting 'anchor' (table)
-- Description: An anchor used to position the orb
-- Values: { point (string)         - Point on the orb to anchor with
--         , relativeTo (string)    - Name of the frame to anchor to (defaults
--                                    to the orb's parent)
--         , relativePoint (string) - Point on the relative frame to anchor to
--                                    (defaults to same as point)
--         , x (number)             - X offset (defaults to 0)
--         , y (number)             - Y offset (defaults to 0)
--         }
--         nil - Defaults to { point = 'CENTER', }
-- Notes: Valid points are: TOPLEFT, TOP, TOPRIGHT, RIGHT, BOTTOMRIGHT,
--        BOTTOM, BOTTOMLEFT, LEFT, CENTER
Settings.anchor = {
    apply = function(orb, anchor)
        orb:SetOrbAnchors()
    end,
}

-- Setting group 'backdrop'
-- Description: Contains settings related to the orb's backdrop
Settings.backdrop = {

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as a backdrop
    -- Values: Any valid path to a texture
    texture = {
        apply = function(orb, texture)
            local backdrop = orb.regions.backdrop
            if backdrop ~= nil then ApplyTexture(backdrop, texture) end
        end,
    },

}

-- Setting group 'backdropArt'
-- Description: Contains settings related to the orb's backdrop art
Settings.backdropArt = {

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as art behind and around the backdrop
    -- Values: Any valid path to a texture
    texture = {
        apply = function(orb, texture)
            local backdropArt = orb.regions.backdropArt
            if backdropArt ~= nil then ApplyTexture(backdropArt, texture) end
        end,
    },

}

-- Setting group 'fill'
-- Description: Contains settings related to the orb's fill
Settings.fill = {

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use for the fill
    -- Values: Any valid path to a texture
    texture = {
        apply = function(orb, texture)
            local fill = orb.regions.fill
            if fill ~= nil then ApplyTexture(fill, texture) end
        end,
    },

}

-- Setting group 'border'
-- Description: Contains settings related to the orb's border
Settings.border = {

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as a border
    -- Values: Any valid path to a texture
    texture = {
        apply = function(orb, texture)
            local border = orb.regions.border
            if border ~= nil then ApplyTexture(border, texture) end
        end,
    },

}

-- Setting group 'borderArt'
-- Description: Contains settings related to the orb's border art
Settings.borderArt = {

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as border artwork
    -- Values: Any valid path to a texture
    texture = {
        apply = function(orb, texture)
            local borderArt = orb.regions.borderArt
            if borderArt ~= nil then ApplyTexture(borderArt, texture) end
        end,
    },

}

-- ============================================================================
--  D. Regions
-- ============================================================================

function Orb:CreateOrbBackdrop()
    if self.regions.backdrop == nil then
        local backdrop = self:CreateTexture()
        backdrop:SetAllPoints(self)
        backdrop:SetDrawLayer('BACKGROUND', 0)
        backdrop:SetVertexColor(0, 0, 0, 1) -- TODO: remove
        local texture = self.backdrop.texture
        if texture ~= nil then ApplyTexture(backdrop, texture) end
        self.regions.backdrop = backdrop
    end
end

function Orb:CreateOrbBackdropArt()
    if self.regions.backdropArt == nil then
        local backdropArt = self:CreateTexture()
        backdropArt:SetAllPoints(self)
        backdropArt:SetDrawLayer('BACKGROUND', -1)
        local texture = self.backdropArt.texture
        if texture ~= nil then ApplyTexture(backdropArt, texture) end
        self.regions.backdropArt = backdropArt
    end
end

function Orb:CreateOrbFill()
    if self.regions.fill == nil then
        local fill = self:CreateTexture()
        fill:SetDrawLayer('ARTWORK', 0)
        local texture = self.fill.texture
        if texture ~= nil then ApplyTexture(fill, texture) end
        self.regions.fill = fill
        self:SetFillAnchors()
    end
end

function Orb:SetFillAnchors()
    local direction = self.direction
    local fill = self.regions.fill
    fill:ClearAllPoints()
    if direction == 'up' then
        fill:SetPoint('BOTTOMLEFT')
        fill:SetPoint('BOTTOMRIGHT')
        fill:SetHeight(self:GetHeight())
    elseif direction == 'down' then
        fill:SetPoint('TOPLEFT')
        fill:SetPoint('TOPRIGHT')
        fill:SetHeight(self:GetHeight())
    elseif direction == 'left' then
        fill:SetPoint('TOPRIGHT')
        fill:SetPoint('BOTTOMRIGHT')
        fill:SetWidth(self:GetWidth())
    elseif direction == 'right' then
        fill:SetPoint('TOPLEFT')
        fill:SetPoint('BOTTOMLEFT')
        fill:SetWidth(self:GetWidth())
    end
end

function Orb:CreateOrbBorder()
    if self.regions.border == nil then
        local border = self:CreateTexture()
        border:SetAllPoints(self)
        border:SetDrawLayer('ARTWORK', 1)
        local texture = self.border.texture
        if texture ~= nil then ApplyTexture(border, texture) end
        self.regions.border = border
    end
end

function Orb:CreateOrbBorderArt()
    if self.regions.borderArt == nil then
        local borderArt = self:CreateTexture()
        borderArt:SetAllPoints(self)
        borderArt:SetDrawLayer('ARTWORK', 2)
        local texture = self.borderArt.texture
        if texture ~= nil then ApplyTexture(borderArt, texture) end
        self.regions.borderArt = borderArt
    end
end

-- ============================================================================
--  E. Local values and helper functions
-- ============================================================================

local mirroredAnchors = {
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

local mirroredDirections = {
    ['up'] = 'up',
    ['down'] = 'down',
    ['left'] = 'right',
    ['right'] = 'left',
}

function ApplyTexture(region, texture)
    if type(texture) == 'string' then
        region:SetTexture(texture)
    elseif type(texture) == 'table' then
        region:SetColorTexture(unpack(texture))
    end
end

function MirrorSetting(name, value, groupName)
    if value == nil then return end
    if groupName == nil then
        if name == 'anchor' then
        return {
                point = mirroredAnchors[value.point],
                relativeTo = value.relativeTo,
                relativePoint = mirroredAnchors[value.relativePoint],
                x = -value.x,
                y = value.y,
        }
        elseif name == 'flipped' then
            return not value
        elseif name == 'direction' then
            return mirroredDirections[value]
        else
            return value
        end
    else
        return value
    end
end

function ReadSettings(settings)
    local readSettings = { }

    -- Copy from the settings table
    local function CopySetting(name, groupName)
        local readSettings = readSettings
        local settings = settings
        if groupName then
            if settings[groupName] == nil then return end
            readSettings[groupName] = readSettings[groupName] or { }
            readSettings = readSettings[groupName]
            settings = settings[groupName]
        end
        if settings[name] == nil then return end
        readSettings[name] = settings[name]
    end

    CopySetting('enabled')
    CopySetting('locked')

    CopySetting('style')
    CopySetting('unit')
    CopySetting('resource')

    CopySetting('colorStyle')
    CopySetting('size')
    CopySetting('aspectRatio')
    CopySetting('direction')
    CopySetting('flipped')
    CopySetting('parent')
    CopySetting('anchor')

    CopySetting('texture', 'backdrop')
    CopySetting('texture', 'backdropArt')
    CopySetting('texture', 'fill')
    CopySetting('texture', 'border')
    CopySetting('texture', 'borderArt')

    -- Fetch inherited settings
    local inheritName = settings.inherit
    local inheritStyle = settings.inheritStyle or 'copy'
    if inheritName ~= nil then
        local inheritSettings = OrbFrames.db.profile.orbs[inheritName]
        if inheritSettings == nil then error('Inherited orb "'..inheritName..'" does not exist') end
        inheritSettings = ReadSettings(inheritSettings)

        local function InheritSetting(name, groupName)
            local readSettings = readSettings
            local inheritSettings = inheritSettings
            if groupName then
                if inheritSettings[groupName] == nil then return end
                readSettings[groupName] = readSettings[groupName] or { }
                readSettings = readSettings[groupName]
                inheritSettings = inheritSettings[groupName]
            end
            if inheritSettings[name] == nil then return end
            if readSettings[name] == nil then
                if inheritStyle == 'copy' then
                    readSettings[name] = inheritSettings[name]
                elseif inheritStyle == 'mirror' then
                    readSettings[name] = MirrorSetting(name, inheritSettings[name], groupName)
                end
            end
        end

        --InheritSetting('enabled')
        if inheritStyle == 'copy' then InheritSetting('locked') end

        InheritSetting('style')
        InheritSetting('unit')
        InheritSetting('resource')

        InheritSetting('colorStyle')
        InheritSetting('size')
        InheritSetting('aspectRatio')
        InheritSetting('direction')
        InheritSetting('flipped')
        InheritSetting('parent')
        InheritSetting('anchor')

        InheritSetting('texture', 'backdrop')
        InheritSetting('texture', 'backdropArt')
        InheritSetting('texture', 'fill')
        InheritSetting('texture', 'border')
        InheritSetting('texture', 'borderArt')
    end

    -- Supply missing settings with defaults
    local function DefaultSetting(name, default, groupName)
        local readSettings = readSettings
        if groupName then
            readSettings[groupName] = readSettings[groupName] or { }
            readSettings = readSettings[groupName]
        end
        if readSettings[name] == nil then
            readSettings[name] = default
        end
    end

    DefaultSetting('enabled', true)
    DefaultSetting('locked', true)

    DefaultSetting('style', 'orb')
    DefaultSetting('unit', 'player')
    DefaultSetting('resource', 'health')

    DefaultSetting('colorStyle', 'resource')
    DefaultSetting('size', 128)
    DefaultSetting('aspectRatio', 1)
    DefaultSetting('direction', 'up')
    DefaultSetting('flipped', false)
    DefaultSetting('parent', nil)
    DefaultSetting('anchor', nil)

    DefaultSetting('texture', '', 'backdrop')
    DefaultSetting('texture', '', 'backdropArt')
    DefaultSetting('texture', '', 'fill')
    DefaultSetting('texture', '', 'border')
    DefaultSetting('texture', '', 'borderArt')

    return readSettings
end
