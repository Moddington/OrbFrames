-- ============================================================================
--  Orb.lua
-- ----------------------------------------------------------------------------
--  A. Orb creation and management
--  B. Callbacks and methods
--  C. Settings
--   - Meta
--   - Style
--   - Size and positioning
--   - Textures
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- Orb methods
local Orb = { }

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
        orb:ApplyOrbSettings(orb.delayedSettings)
        orb.delayedSettings = nil
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
    local orb = self:CreateEntity('Button', 'OrbFrames_Orb_'..name, UIParent, 'SecureUnitButtonTemplate')
    for k, v in pairs(Orb) do orb[k] = v end

    -- Initialize orb
    RegisterUnitWatch(orb)
    orb:EnableMouse(true)
    orb:SetMovable(true)
    orb:SetClampedToScreen(true)
    orb:SetFrameStrata('BACKGROUND')
    orb:SetScript('OnDragStart', orb.OnDragStart)
    orb:SetScript('OnDragStop', orb.OnDragStop)

    -- Default orb settings necessary for clean loading
    orb.settings = {
        enabled = true,
        locked = true,
    }

    -- Apply settings
    if settings ~= nil then
        if twoPhase then
            orb.delayedSettings = settings
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
--  B. Callbacks and methods
-- ============================================================================

function Orb:OnDragStart(button)
    if button == 'LeftButton' then
        self:StartMoving()
    end
end

function Orb:OnDragStop()
    self:StopMovingOrSizing()
end

function Orb:SetOrbEnabled(enabled)
    self.enabled = enabled
    if enabled then
        self:Show()
        self:SetStyle(self.style)
    else
        self:DisableAllComponents()
        self:Hide()
    end
end

function Orb:SetOrbLocked(locked)
    if locked then
        self:RegisterForDrag()
    else
        self:RegisterForDrag('LeftButton')
    end
end

function Orb:SetOrbStyle(style)
    self.style = style
    self:DisableAllComponents()
    if style == 'simple' then
        self:CreateOrEnableComponent(OrbFrames.Components.SimpleSconce, 'SimpleSconce')
        self:CreateOrEnableComponent(OrbFrames.Components.ResourceBar, 'FillBar', 'ARTWORK', -2)
        -- TODO: pips, icons, labels
    end
    if self.enabled == false then
        self:DisableAllComponents()
    end
end

function Orb:SetOrbDirection(direction)
    local style = self.style
    if style == 'simple' then
        self:GetComponent('FillBar'):SetDirection(direction)
    end
end

function Orb:SetOrbUnit(unit)
    self.unit = unit
    self:SetAttribute('unit', unit)
    SecureUnitButton_OnLoad(self, unit) -- TODO: menuFunc
    local style = self.style
    if style == 'simple' then
        self:GetComponent('FillBar'):SetUnit(unit)
    end
end

function Orb:SetOrbResource(resource)
    self.resource = resource
    local style = self.style
    if style == 'simple' then
        self:GetComponent('FillBar'):SetResource(resource)
    end
end

function Orb:SetOrbColorStyle(colorStyle)
    self.colorStyle = colorStyle
    local style = self.style
    if style == 'simple' then
        self:GetComponent('FillBar'):SetColorStyle(colorStyle)
    end
end

function Orb:SetOrbShowAbsorb(showAbsorb)
    local style = self.style
    if style == 'simple' then
        -- TODO: self:GetComponent('overlayBar'):SetColorStyle(colorStyle)
    end
end

function Orb:SetOrbShowHeals(showHeals)
    local style = self.style
    if style == 'simple' then
        -- TODO: self:GetComponent('extraFillBar'):SetColorStyle(colorStyle)
    end
end

function Orb:SetOrbSize(size, aspectRatio)
    self:SetWidth(size * aspectRatio)
    self:SetHeight(size)
    self:SendMessage('ENTITY_UPDATE_SIZE')
end

function Orb:SetOrbPosition(anchor)
    local relativeTo = anchor.relativeTo
    if relativeTo == nil then relativeTo = self:GetParent() or UIParent end
    local relativePoint = anchor.relativePoint
    if relativePoint == nil then relativePoint = anchor.point end
    self:ClearAllPoints()
    self:SetPoint(anchor.point, relativeTo, relativePoint, anchor.x, anchor.y)
end

function Orb:SetOrbSconceTexture(regionName, texture)
    local style = self.style
    if style == 'simple' then
        self:GetComponent('SimpleSconce'):SetTexture(regionName, texture)
    end
end

function Orb:SetOrbFillTexture(texture)
    local style = self.style
    if style == 'simple' then
        self:GetComponent('FillBar'):SetTexture(texture)
    end
end

function Orb:SetOrbFillResourceTextures(resourceTextures)
    local style = self.style
    if style == 'simple' then
        local fillBar = self:GetComponent('FillBar')
        for resource, texture in pairs(resourceTextures) do
            fillBar:SetResourceTexture(resource, texture)
        end
    end
end

-- ============================================================================
--  C. Settings
-- ============================================================================

local OrbSchema = { }
OrbFrames.OrbSchema = OrbSchema

local ReadOrbSettings

local defaultSettings = {
    enabled = true,
    locked = true,

    style = 'simple',
    unit = 'player',
    resource = 'health',
    colorStyle = 'resource',
    showAbsorb = true,
    showHeals = true,

    size = 256,
    aspectRatio = 1,
    parent = nil,
    anchor = {
        point = 'CENTER',
    },

    backdrop = {
        texture = '',
    },
    backdropArt = {
        texture = '',
    },
    border = {
        texture = '',
    },
    borderArt = {
        texture = '',
    },
}

function Orb:ApplyOrbSettings(settings)
    -- Read orb settings to acquire inherited and default values
    settings = ReadOrbSettings(settings)

    -- Apply settings
    local function VisitSetting(name, value, schema, iterator)
        if iterator.settings[name] ~= value then
            iterator.settings[name] = value
            schema._apply(self, value)
        end
    end
    local function Enter(name, value, iterator)
        iterator = table.copy(iterator)
        iterator.settings[name] = iterator.settings[name] or { }
        iterator.settings = iterator.settings[name]
        return value, iterator
    end
    OrbFrames.TraverseSettings(settings, OrbSchema, {
        VisitSetting = VisitSetting,
        EnterGroup = Enter,
        EnterList = Enter,
        EnterListElement = Enter,
        settings = self.settings,
    })
end

function Orb:ApplyOrbSetting(path, value)
    local Settings = OrbSchema
    local settings = self.settings
    local name = string.gsub(path, '(.-)\.', function(tableName)
        Settings = Settings[tableName]
        settings[tableName] = settings[tableName] or { }
        settings = settings[tableName]
        return ''
    end)
    if value ~= settings[name] then
        settings[name] = value
        Settings[name]._apply(self, value)
    end
end

function ReadOrbSettings(settings)
    local readSettings = { }

    -- Iterator functions
    local function Enter(name, value, iterator)
        iterator = table.copy(iterator)
        iterator.readSettings[name] = iterator.readSettings[name] or { }
        iterator.readSettings = iterator.readSettings[name]
        return value, iterator
    end

    -- Copy settings
    OrbFrames.TraverseSettings(settings, OrbSchema, {
        VisitSetting = function(name, value, schema, iterator)
            iterator.readSettings[name] = value
        end,
        EnterGroup = Enter,
        EnterList = Enter,
        EnterListElement = Enter,
        readSettings = readSettings,
    })

    -- Prevent these settings from being inherited
    if readSettings.enabled == nil then readSettings.enabled = true end

    -- Inherit settings
    local inheritName = settings.inherit
    local inheritStyle = settings.inheritStyle or 'copy'
    if inheritName ~= nil then
        local inheritSettings = OrbFrames.db.profile.orbs[inheritName]
        if inheritSettings == nil then error('Inherited orb "'..inheritName..'" does not exist') end
        inheritSettings = ReadOrbSettings(inheritSettings)

        OrbFrames.TraverseSettings(inheritSettings, OrbSchema, {
            VisitSetting = function(name, value, schema, iterator)
                if iterator.readSettings[name] == nil then
                    if inheritStyle == 'mirror' then
                        if schema._mirror then
                            value = schema._mirror(value)
                        end
                    end
                    iterator.readSettings[name] = value
                end
            end,
            EnterGroup = Enter,
            EnterList = Enter,
            EnterListElement = Enter,
            readSettings = readSettings,
        })
    end

    -- Apply missing defaults
    OrbFrames.TraverseSettings(defaultSettings, OrbSchema, {
        VisitSetting = function(name, value, schema, iterator)
            if iterator.readSettings[name] == nil then
                iterator.readSettings[name] = value
            end
        end,

        EnterGroup = Enter,
        EnterList = function(name, value, iterator)
            value, iterator = Enter(name, value, iterator)
            if value['*'] then
                local star = value['*']
                value = { }
                for name, _ in pairs(readSettings[name]) do
                    value[name] = star
                end
            end
            return value, iterator
        end,
        EnterListElement = Enter,
        readSettings = readSettings,
    })

    return readSettings
end

-- ----------------------------------------------------------------------------
--  Meta
-- ----------------------------------------------------------------------------

-- Setting 'enabled' (boolean)
-- Description: Whether the orb is enabled or disabled
OrbSchema.enabled = {
    _priority = -100,

    _apply = Orb.SetOrbEnabled,
}

-- Setting 'locked' (boolean)
-- Description: Whether the orb is locked in place, or can be repositioned with
--              the mouse
OrbSchema.locked = {
    _apply = Orb.SetOrbLocked,
}

-- ----------------------------------------------------------------------------
--  Style
-- ----------------------------------------------------------------------------

-- Setting 'style' (string)
-- Description: The style used for the orb
-- Values: 'simple' - A plain ol' orb
OrbSchema.style = {
    _priority = 100,

    _apply = Orb.SetOrbStyle,
}

-- Setting 'direction' (string)
-- Description: The direction the orb fills in
-- Values: 'up', 'down', 'left', 'right'
OrbSchema.direction = {
    _apply = Orb.SetOrbDirection,

    _mirror = function(direction)
        return OrbFrames.mirroredDirections[direction]
    end,
}

-- Setting 'unit' (string)
-- Description: Which unit the orb is tracking
-- Values: Any valid WoW unit name
OrbSchema.unit = {
    _apply = Orb.SetOrbUnit,
}

-- Setting 'resource' (string)
-- Description: Which resource the orb is displaying
-- Values: 'health' - The unit's health
--         'power'  - The unit's primary power type
--         'power2' - The unit's secondary power type
--         'empty'  - Always show an empty orb
--         'full'   - Always show a full orb
OrbSchema.resource = {
    _apply = Orb.SetOrbResource,
}

-- Setting 'colorStyle' (string)
-- Description: The method used to choose the color for the orb liquid
-- Values: 'class'    - The unit's class color
--         'resource' - The resource's color
--         'reaction' - The unit's reaction color
OrbSchema.colorStyle = {
    _apply = Orb.SetOrbColorStyle,
}

-- Setting 'showAbsorb' (boolean)
-- Description: When the orb resource is 'health', display absorb effects on
--              the unit as an overlay on the orb
OrbSchema.showAbsorb = {
    _apply = Orb.SetOrbShowAbsorb,
}

-- Setting 'showHeals' (boolean)
-- Description: When the orb resource is 'health', display incoming heals as
--              a semi-transparent liquid on top of the health liquid
OrbSchema.showHeals = {
    _apply = Orb.SetOrbShowHeals,
}

-- ----------------------------------------------------------------------------
--  Size and positioning
-- ----------------------------------------------------------------------------

-- Setting 'size' (number)
-- Description: The vertical size of the orb
OrbSchema.size = {
    _apply = function(orb, size)
        local aspectRatio = orb.settings.aspectRatio
        if aspectRatio ~= nil then
            orb:SetOrbSize(size, aspectRatio)
        end
    end,
}

-- Setting 'aspectRatio' (number)
-- Description: The ratio between the orb's height and its width
OrbSchema.aspectRatio = {
    _apply = function(orb, aspectRatio)
        local size = orb.settings.size
        if size ~= nil then
            orb:SetOrbSize(size, aspectRatio)
        end
    end,
}

-- Setting 'parent' (string)
-- Description: Which orb, if any, to be parented to
-- Values: 'orb:' followed by any valid orb name
--         Any valid frame name
--         nil - Parent to UIParent by default
OrbSchema.parent = {
    _priority = 1,

    _apply = function(orb, parent)
        local parentOrb = string.match(parent, '^orb:(.*)')
        if parentOrb then
            parent = OrbFrames.orbs[parentOrb]
        else
            parent = _G[parent]
        end
        orb:SetParent(parent)
        local anchor = orb.settings.anchor
        if anchor ~= nil then
            orb:SetOrbPosition(anchor)
        end
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
OrbSchema.anchor = {
    _apply = function(orb, anchor)
        orb:SetOrbPosition(anchor)
    end,

    _mirror = function(anchor)
        return {
            point = OrbFrames.mirroredAnchors[anchor.point],
            relativeTo = anchor.relativeTo,
            relativePoint = OrbFrames.mirroredAnchors[anchor.relativePoint],
            x = -anchor.x,
            y = anchor.y,
        }
    end,
}

-- ----------------------------------------------------------------------------
--  Textures
-- ----------------------------------------------------------------------------

-- Setting group 'backdrop'
-- Description: Contains settings related to the orb's backdrop
OrbSchema.backdrop = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as a backdrop
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            orb:SetOrbSconceTexture('Backdrop', texture)
        end,
    },

}

-- Setting group 'backdropArt'
-- Description: Contains settings related to the orb's backdrop art
OrbSchema.backdropArt = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as art behind and around the backdrop
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            orb:SetOrbSconceTexture('BackdropArt', texture)
        end,
    },

}

-- Setting group 'fill'
-- Description: Contains settings related to the orb's fill
OrbSchema.fill = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use for the fill
    -- Values: Any valid path to a texture
    texture = {
        _apply = Orb.SetOrbFillTexture,
    },

    -- Setting 'resourceTextures' (table)
    -- Description: A lookup table of textures to use for specific resources
    -- Values: A lookup table where keys are resource names, and values are
    --         any valid path to a texture
    resourceTextures = {
        _apply = Orb.SetOrbFillResourceTextures,
    },

}

-- Setting group 'border'
-- Description: Contains settings related to the orb's border
OrbSchema.border = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as a border
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            orb:SetOrbSconceTexture('Border', texture)
        end,
    },

}

-- Setting group 'borderArt'
-- Description: Contains settings related to the orb's border art
OrbSchema.borderArt = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as border artwork
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            orb:SetOrbSconceTexture('BorderArt', texture)
        end,
    },

}
