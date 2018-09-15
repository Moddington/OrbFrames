-- ============================================================================
--  Orb.lua
-- ----------------------------------------------------------------------------
--  A. Orb creation and management
--  B. Callbacks and helpers
--  C. Settings
--  D. Regions
--  E. Pips
--  F. Labels
--  G. Local values and helper functions
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- Orb methods
local Orb = { }
local OrbSettings = { }

-- Local values and helper functions
local ApplyTexture
local ReadOrbSettings

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
    local orb = CreateFrame('Button', 'OrbFrames_Orb_'..name, UIParent, 'SecureUnitButtonTemplate')
    for k, v in pairs(Orb) do orb[k] = v end

    -- Initialize orb
    RegisterUnitWatch(orb)
    orb.pips = { }
    orb.labels = { }
    orb:EnableMouse(true)
    orb:SetMovable(true)
    orb:SetClampedToScreen(true)
    orb:SetFrameStrata('BACKGROUND')
    orb:SetScript('OnShow', orb.OnShow)
    orb:SetScript('OnEvent', orb.OnEvent)
    orb:SetScript('OnDragStart', orb.OnDragStart)
    orb:SetScript('OnDragStop', orb.OnDragStop)

    -- Default orb settings necessary for clean loading
    orb.settings = {
        enabled = true,

        flipped = false,
        direction = 'up',
        aspectRatio = 1,

        backdrop = { },
        backdropArt = { },
        fill = {
            resourceTextures = { },
        },
        overfill = { },
        border = { },
        borderArt = { },

        pips = {
            shape = 'none',
            resourceTextures = { },
        },

        labels = { },
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
        OrbSettings.enabled._apply(orb, true)
    end
end

function OrbFrames:DisableAllOrbs()
    for _, orb in pairs(self.orbs) do
        OrbSettings.enabled._apply(orb, false)
    end
end

function OrbFrames:LockAllOrbs()
    for _, orb in pairs(self.orbs) do
        OrbSettings.locked._apply(orb, true)
    end
end

function OrbFrames:UnlockAllOrbs()
    for _, orb in pairs(self.orbs) do
        OrbSettings.locked._apply(orb, false)
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
    local style = self.settings.style
    if style == 'orb' then
        local resource = self.resource
        if resource == 'health' then
            self:RegisterEvent('UNIT_HEALTH')
            self:RegisterEvent('UNIT_HEALTH_FREQUENT')
            self:RegisterEvent('UNIT_MAXHEALTH')
        elseif resource == 'power' or resource == 'power2' then
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
    local anchor = self.settings.anchor
    if anchor == nil then anchor = { point = 'CENTER' } end
    local relativeTo = anchor.relativeTo
    if relativeTo == nil then relativeTo = self:GetParent() end
    local relativePoint = anchor.relativePoint
    if relativePoint == nil then relativePoint = anchor.point end
    self:SetPoint(anchor.point, relativeTo, relativePoint, anchor.x, anchor.y)
end

function Orb:SetOrbLabelAnchors(label)
    label:ClearAllPoints()
    local anchor = label.settings.anchor
    if anchor == nil then anchor = { point = 'CENTER' } end
    local relativePoint = anchor.relativePoint
    if relativePoint == nil then relativePoint = anchor.point end
    label:SetPoint(anchor.point, self, relativePoint, anchor.x, anchor.y)
end

function Orb:SetOrbLabelDrawLayer(label)
    if label.settings.showOnlyOnHover then
        label:SetDrawLayer('HIGHLIGHT')
    else
        label:SetDrawLayer('ARTWORK')
    end
end

function Orb:UpdateOrb()
    local style = self.settings.style
    if style == 'orb' then
        local fill = self.fill
        local unit = self.unit
        local resource = self.resource

        -- Update fill height
        local proportion
        if not UnitExists(unit) then
            proportion = 0
        elseif resource == 'health' then
            local health, healthMax = UnitHealth(unit), UnitHealthMax(unit)
            if healthMax > 0 then
                proportion = health / healthMax
            else
                proportion = 0
            end
        elseif resource == 'power' then
            local power, powerMax = UnitPower(unit), UnitPowerMax(unit)
            if powerMax > 0 then
                proportion = power / powerMax
            else
                proportion = 0
            end
        elseif resource == 'power2' then
            local power2, power2Max = UnitPower2(unit), UnitPower2Max(unit)
            if power2Max > 0 then
                proportion = power2 / power2Max
            else
                proportion = 0
            end
        elseif resource == 'full' then
            proportion = 1
        elseif resource == 'empty' then
            proportion = 0
        end
        if proportion > 0 then
            proportion = math.min(1, proportion)
            local direction = self.settings.direction
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

        -- Update overfill height
        if resource == 'health' then
            -- TODO: overfill for health is absorb
            --       keep track of absorbs to maintain the maximum value
        end

        -- Update fill color
        local colors = OrbFrames.db.profile.colors
        local colorStyle = self.settings.colorStyle
        local color
        if colorStyle == 'class' then
            color = colors.classes[select(2, UnitClass(unit))]
        elseif colorStyle == 'resource' then
            if resource == 'health' then
                color = colors.resources['HEALTH']
            elseif resource == 'power' then
                color = colors.resources[select(2, UnitPowerType(unit))]
            elseif resource == 'power2' then
                local powerType = select(2, UnitPower2Type(unit))
                if powerType then
                    color = colors.resources[powerType]
                end
            end
        end
        if color ~= nil then
            fill:SetVertexColor(unpack(color))
        end
    else
        error('Orb has no style')
    end

    -- Update pips
    self:UpdateOrbPips()

    -- Update labels
    for labelName, label in pairs(self.labels) do
        self:UpdateOrbLabel(label)
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

function Orb:ApplyOrbSettings(settings)
    -- Read orb settings to acquire inherited and default values
    settings = ReadOrbSettings(settings)

    -- Suspend orb updates
    self:SuspendOrbUpdates()

    -- Apply settings
    local function VisitSetting(name, value, schema, iterator)
        if iterator.settings[name] ~= value then
            iterator.settings[name] = value
            schema._apply(self, value)
        end
    end
    local function VisitLabelSetting(name, value, schema, iterator)
        if iterator.settings[name] ~= value then
            iterator.settings[name] = value
            schema._apply(iterator.label, value)
        end
    end
    local function Enter(name, value, iterator)
        iterator = table.copy(iterator)
        iterator.settings[name] = iterator.settings[name] or { }
        iterator.settings = iterator.settings[name]
        return value, iterator
    end
    local function EnterLabel(name, value, iterator)
        self:AddOrbLabel(name)
        value, iterator = Enter(name, value, iterator)
        iterator.label = self.labels[name]
        return value, iterator
    end
    local function EnterList(name, value, iterator)
        value, iterator = Enter(name, value, iterator)
        if name == 'labels' then
            iterator.VisitSetting = VisitLabelSetting
            iterator.EnterListElement = EnterLabel
        end
        return value, iterator
    end
    OrbFrames.TraverseSettings(settings, OrbSettings, {
        VisitSetting = VisitSetting,
        EnterGroup = Enter,
        EnterList = EnterList,
        settings = self.settings,
    })

    -- Resume orb updates
    self:ResumeOrbUpdates()

    -- Update and return
    self:UpdateOrb()
end

function Orb:ApplyOrbSetting(path, value)
    local Settings = OrbSettings
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

function Orb:ApplyOrbLabelSetting(labelName, path, value)
    local label = self.labels[labelName]
    local Settings = OrbSettings.labels
    local settings = label.settings
    local name = string.gsub(path, '(.-)\.', function(tableName)
        Settings = Settings[tableName]
        settings[tableName] = settings[tableName] or { }
        settings = settings[tableName]
        return ''
    end)
    if value ~= settings[name] then
        settings[name] = value
        Settings[name]._apply(label, value)
    end
end

-- Setting 'enabled' (boolean)
-- Description: Whether the orb is enabled or disabled
OrbSettings.enabled = {
    _priority = -100,

    _apply = function(orb, enabled)
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
OrbSettings.locked = {
    _apply = function(orb, locked)
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
OrbSettings.style = {
    _priority = 100,

    _apply = function(orb, style)
        if style == 'orb' then
            orb:CreateOrbBackdrop()
            orb:CreateOrbBackdropArt()
            orb:CreateOrbFill()
            orb:CreateOrbOverfill()
            orb:CreateOrbBorder()
            orb:CreateOrbBorderArt()
        end
        orb:RegisterOrbEvents()
    end,
}

-- Setting 'unit' (string)
-- Description: Which unit the orb is tracking
-- Values: Any valid WoW unit name
OrbSettings.unit = {
    _apply = function(orb, unit)
        orb.unit = unit
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
--         'power2' - The unit's secondary power type
--         'empty'  - Always show an empty orb
--         'full'   - Always show a full orb
OrbSettings.resource = {
    _apply = function(orb, resource)
        orb.resource = resource
        orb:RegisterOrbEvents()
        orb:UpdateOrb()
    end,
}

-- Setting 'colorStyle' (string)
-- Description: The method used to choose the color for the orb liquid
-- Values: 'class'    - The unit's class color
--         'resource' - The resource's color
OrbSettings.colorStyle = {
    _apply = function(orb, colorStyle)
        orb:UpdateOrb()
    end,
}

-- Setting 'size' (number)
-- Description: The vertical size of the orb
OrbSettings.size = {
    _apply = function(orb, size)
        local aspectRatio = orb.settings.aspectRatio
        if aspectRatio ~= nil then
            orb:SetWidth(size * aspectRatio)
            orb:SetHeight(size)
            orb:UpdateOrb()
        end
    end,
}

-- Setting 'aspectRatio' (number)
-- Description: The ratio between the orb's height and its width
OrbSettings.aspectRatio = {
    _apply = function(orb, aspectRatio)
        local size = orb.settings.size
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
OrbSettings.direction = {
    _apply = function(orb, direction)
        if orb.fill then
            orb:SetOrbFillAnchors()
        end
    end,

    _mirror = function(direction)
        return OrbFrames.mirroredDirections[direction]
    end,
}

-- Setting 'flipped' (boolean)
-- Description: Whether the orb is flipped horizontally
OrbSettings.flipped = {
    _apply = function(orb, flipped)
        orb:UpdateOrb()
    end,

    _mirror = function(flipped)
        return not flipped
    end
}

-- Setting 'parent' (string)
-- Description: Which orb, if any, to be parented to
-- Values: Any valid orb name
--         nil - Parent to UIParent instead
-- TODO: allow parenting to any frame
OrbSettings.parent = {
    _apply = function(orb, parent)
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
OrbSettings.anchor = {
    _apply = function(orb, anchor)
        orb:SetOrbAnchors()
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

-- Setting group 'backdrop'
-- Description: Contains settings related to the orb's backdrop
OrbSettings.backdrop = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as a backdrop
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            local backdrop = orb.backdrop
            if backdrop ~= nil then ApplyTexture(backdrop, texture) end
        end,
    },

}

-- Setting group 'backdropArt'
-- Description: Contains settings related to the orb's backdrop art
OrbSettings.backdropArt = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as art behind and around the backdrop
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            local backdropArt = orb.backdropArt
            if backdropArt ~= nil then ApplyTexture(backdropArt, texture) end
        end,
    },

}

-- Setting group 'fill'
-- Description: Contains settings related to the orb's fill
OrbSettings.fill = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use for the fill
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            orb:SetOrbFillTexture()
        end,
    },

    -- Setting 'resourceTextures' (table)
    -- Description: A lookup table of textures to use for specific resources
    -- Values: A lookup table where keys are resource names, and values are
    --         any valid path to a texture
    resourceTextures = {
        _apply = function(orb, texture)
            orb:SetOrbFillTexture()
        end,
    },

}

-- Setting group 'border'
-- Description: Contains settings related to the orb's border
OrbSettings.border = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as a border
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            local border = orb.border
            if border ~= nil then ApplyTexture(border, texture) end
        end,
    },

}

-- Setting group 'borderArt'
-- Description: Contains settings related to the orb's border art
OrbSettings.borderArt = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as border artwork
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            local borderArt = orb.borderArt
            if borderArt ~= nil then ApplyTexture(borderArt, texture) end
        end,
    },

}

-- Setting group 'pips'
-- Description: Contains settings used to display secondary power values as pip
--              icons on the orb
OrbSettings.pips = {
    _type = 'group',
    _priority = -10,

    -- Setting 'shape' (string)
    -- Description: The shape used to arrange the pips
    -- Values: 'arc' - Arranged radially on a circle shape
    --         'orb' - Arranged radially on the edge of the orb
    --         'line' - Arranged on a line segment
    --         'edge' - Arranged on an edge of the orb's frame
    --         'none' - Do not display pips
    shape = {
        _priority = -10,
        _apply = function(orb, shape)
            orb:SetOrbPipShape()
        end,
    },

    -- Setting 'size' (number)
    -- Description: The size of each pip
    size = {
        _apply = function(orb, size)
            orb:SetOrbPipShape()
        end,
    },

    -- Setting 'radius' (number)
    -- Description: Radius of the circle for the 'arc' shape
    radius = {
        _apply = function(orb, radius)
            local shape = orb.settings.pips.shape
            if shape == 'arc' then
                orb:SetOrbPipShape()
            end
        end,
    },

    -- Setting 'centerPoint' (table)
    -- Description: Centerpoint of the circle for the 'arc' shape
    -- Values: { x, y }
    centerPoint = {
        _apply = function(orb, centerPoint)
            local shape = orb.settings.pips.shape
            if shape == 'arc' then
                orb:SetOrbPipShape()
            end
        end,

        _mirror = function(edge)
            return edge -- TODO
        end,
    },

    -- Setting 'radiusOffset' (number)
    -- Description: Offset for the radius of the 'orb' shape
    radiusOffset = {
        _apply = function(orb, radiusOffset)
            local shape = orb.settings.pips.shape
            if shape == 'orb' then
                orb:SetOrbPipShape()
            end
        end,
    },

    -- Setting 'arcSegment' (table)
    -- Description: Starting and ending angles for the 'arc' and 'orb' shapes
    -- Values: { theta1, theta2 }
    -- Notes: Angles are measured in degrees
    arcSegment = {
        _apply = function(orb, arcSegment)
            local shape = orb.settings.pips.shape
            if shape == 'arc' or shape == 'orb' then
                orb:SetOrbPipShape()
            end
        end,

        _mirror = function(edge)
            return edge -- TODO
        end,
    },

    -- Setting 'lineSegment' (table)
    -- Description: Starting and ending points of the line segment for the 'line' shape
    -- Values: { x1, y2, x2, y2 }
    lineSegment = {
        _apply = function(orb, lineSegment)
            local shape = orb.settings.pips.shape
            if shape == 'line' then
                orb:SetOrbPipShape()
            end
        end,

        _mirror = function(edge)
            return edge -- TODO
        end,
    },

    -- Setting 'edge' (string)
    -- Description: Name of the edge to use for the 'edge' shape
    edge = {
        _apply = function(orb, edge)
            local shape = orb.settings.pips.shape
            if shape == 'edge' then
                orb:SetOrbPipShape()
            end
        end,

        _mirror = function(edge)
            return edge -- TODO
        end,
    },

    -- Setting 'edgeOffset' (number)
    -- Description: Offset from the edge for the 'edge' shape
    edgeOffset = {
        _apply = function(orb, edgeOffset)
            local shape = orb.settings.pips.shape
            if shape == 'edge' then
                orb:SetOrbPipShape()
            end
        end,
    },

    -- Setting 'edgeSegment' (table)
    -- Description: The portion of the edge to use for the 'edge' shape
    -- Values = { start, end }, where each value represents a position along
    --          the edge, where 0 is one end and 1 is the other
    edgeSegment = {
        _apply = function(orb, edgeSegment)
            local shape = orb.settings.pips.shape
            if shape == 'edge' then
                orb:SetOrbPipShape()
            end
        end,
    },

    -- Setting 'rotatePips' (boolean)
    -- Description: Whether the pip icons should be rotated to be perpendicular
    --              to the shape they are placed upon
    rotatePips = {
        _apply = function(orb, rotatePips)
            local shape = orb.settings.pips.shape
            if shape == 'arc' or shape == 'orb' then
                orb:SetOrbPipShape()
            elseif shape == 'line' then
                orb:SetOrbPipShape()
            elseif shape == 'edge' then
                orb:SetOrbPipShape()
            end
        end,
    },

    -- Setting 'baseRotation' (number)
    -- Description: An angle to rotate the pips by with any shape
    -- Notes: Angles are measured in degrees
    baseRotation = {
        _apply = function(orb, baseRotation)
            local shape = orb.settings.pips.shape
            if shape ~= 'none' then
                orb:SetOrbPipShape()
            end
        end,
    },

    -- Setting 'textures' (table)
    -- Description: Names of the textures to use for the pips
    -- Values: { on, off }, where both values are any valid path to a texture
    textures = {
        _apply = function(orb, textures)
            orb:SetOrbPipTextures()
        end,
    },

    -- Setting 'resourceTextures' (table)
    -- Description: A lookup table of textures to use for specific resources
    -- Values: A lookup table where keys are resource names, and values are
    --         of the form { on, off }, where both values are any valid path
    --         to a texture
    resourceTextures = {
        _apply = function(orb, resourceTextures)
            orb:SetOrbPipTextures()
        end,
    },
}

-- Settings for elements list 'labels'
-- Description: An orb can have a number of labels on it to provide text display
OrbSettings.labels = {
    _type = 'list',
    _priority = -10,

    -- Setting 'text' (string)
    -- Description: A format string used to determine the label's text
    -- Values: A string optionally containing tags wrapped in {} braces.
    --         See the LabelTags table for a list of tags.
    text = {
        _apply = function(label, text)
            -- TODO: Analyze the format string here
            label.orb:UpdateOrbLabel(label)
        end,
    },

    -- Setting 'font' (string)
    -- Description: The font object
    -- Values: Any string that refers to a font object in the global namespace
    font = {
        _priority = 10,

        _apply = function(label, font)
            label:SetFontObject(_G[font]) -- TODO: better font lookup
        end,
    },

    -- Setting 'anchor' (table)
    -- Description: An anchor used to position the label
    -- Values: { point (string)         - Point on the label to anchor with
    --         , relativePoint (string) - Point on the orb to anchor to
    --                                    (defaults to same as point)
    --         , x (number)             - X offset (defaults to 0)
    --         , y (number)             - Y offset (defaults to 0)
    --         }
    --         nil - Defaults to { point = 'CENTER', }
    -- Notes: Valid points are: TOPLEFT, TOP, TOPRIGHT, RIGHT, BOTTOMRIGHT,
    --        BOTTOM, BOTTOMLEFT, LEFT, CENTER
    anchor = {
        _apply = function(label, anchor)
            label.orb:SetOrbLabelAnchors(label)
        end,

        _mirror = function(anchor)
            return {
                point = OrbFrames.mirroredAnchors[anchor.point],
                relativePoint = OrbFrames.mirroredAnchors[anchor.relativePoint],
                x = -anchor.x,
                y = anchor.y,
            }
        end,
    },

    -- Setting 'width' (number)
    -- Description: The maximum width of the label
    width = {
        _apply = function(label, width)
            label:SetWidth(width)
        end,
    },
    
    -- Setting 'height' (number)
    -- Description: The maximum height of the label
    height = {
        _apply = function(label, height)
            label:SetHeight(height)
        end,
    },

    -- Setting 'justifyH' (string)
    -- Description: The horizontal justification for the text
    -- Values: 'LEFT', 'CENTER', 'RIGHT'
    justifyH = {
        _apply = function(label, justifyH)
            label:SetJustifyH(justifyH)
        end,

        _mirror = function(justifyH)
            return OrbFrames.mirroredAlignments[justifyH]
        end,
    },

    -- Setting 'justifyV' (string)
    -- Description: The vertical justification for the text
    -- Values: 'TOP', 'MIDDLE', 'BOTTOM'
    justifyV = {
        _apply = function(label, justifyV)
            label:SetJustifyV(justifyV)
        end,
    },

    -- Setting 'showOnlyOnHover' (boolean)
    -- Description: Whether the label should only be visible while hovering
    --              over the orb
    showOnlyOnHover = {
        _apply = function(label, showOnlyOnHover)
            label.orb:SetOrbLabelDrawLayer(label)
        end,
    },

}

-- ============================================================================
--  D. Regions
-- ============================================================================

function Orb:CreateOrbBackdrop()
    if self.backdrop == nil then
        local backdrop = self:CreateTexture()
        backdrop:SetAllPoints(self)
        backdrop:SetDrawLayer('BACKGROUND', 0)
        backdrop:SetVertexColor(0, 0, 0, 1) -- TODO: remove
        local texture = self.settings.backdrop.texture
        if texture ~= nil then ApplyTexture(backdrop, texture) end
        self.backdrop = backdrop
    end
end

function Orb:CreateOrbBackdropArt()
    if self.backdropArt == nil then
        local backdropArt = self:CreateTexture()
        backdropArt:SetAllPoints(self)
        backdropArt:SetDrawLayer('BACKGROUND', -1)
        local texture = self.settings.backdropArt.texture
        if texture ~= nil then ApplyTexture(backdropArt, texture) end
        self.backdropArt = backdropArt
    end
end

function Orb:CreateOrbFill()
    if self.fill == nil then
        local fill = self:CreateTexture()
        fill:SetDrawLayer('ARTWORK', -2)
        self:SetOrbFillTexture()
        self.fill = fill
        self:SetOrbFillAnchors()
    end
end

function Orb:SetOrbFillAnchors()
    local direction = self.settings.direction
    local fill = self.fill
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

function Orb:SetOrbFillTexture()
    local fill = self.fill
    if fill == nil then return end
    local fillSettings = self.settings.fill
    local resource = self.resource
    if resource == 'health' then
        resource = 'HEALTH'
    elseif resource == 'power' then
        resource = select(2, UnitPowerType(self.unit))
    end
    if fillSettings.resourceTextures[resource] ~= nil then
        ApplyTexture(fill, fillSettings.resourceTextures[resource])
    else
        ApplyTexture(fill, fillSettings.texture or '')
    end
end

function Orb:CreateOrbOverfill()
    if self.overfill == nil then
        local overfill = self:CreateTexture()
        overfill:SetDrawLayer('ARTWORK', -1)
        local texture = self.settings.overfill.texture
        if texture ~= nil then ApplyTexture(overfill, texture) end
        self.overfill = overfill
        self:SetOverfillAnchors()
    end
end

function Orb:SetOverfillAnchors()
    local direction = self.settings.direction
    local overfill = self.overfill
    overfill:ClearAllPoints()
    if direction == 'up' then
        overfill:SetPoint('BOTTOMLEFT')
        overfill:SetPoint('BOTTOMRIGHT')
        overfill:SetHeight(self:GetHeight())
    elseif direction == 'down' then
        overfill:SetPoint('TOPLEFT')
        overfill:SetPoint('TOPRIGHT')
        overfill:SetHeight(self:GetHeight())
    elseif direction == 'left' then
        overfill:SetPoint('TOPRIGHT')
        overfill:SetPoint('BOTTOMRIGHT')
        overfill:SetWidth(self:GetWidth())
    elseif direction == 'right' then
        overfill:SetPoint('TOPLEFT')
        overfill:SetPoint('BOTTOMLEFT')
        overfill:SetWidth(self:GetWidth())
    end
end

function Orb:CreateOrbBorder()
    if self.border == nil then
        local border = self:CreateTexture()
        border:SetAllPoints(self)
        border:SetDrawLayer('ARTWORK', 1)
        local texture = self.settings.border.texture
        if texture ~= nil then ApplyTexture(border, texture) end
        self.border = border
    end
end

function Orb:CreateOrbBorderArt()
    if self.borderArt == nil then
        local borderArt = self:CreateTexture()
        borderArt:SetAllPoints(self)
        borderArt:SetDrawLayer('ARTWORK', 2)
        local texture = self.settings.borderArt.texture
        if texture ~= nil then ApplyTexture(borderArt, texture) end
        self.borderArt = borderArt
    end
end

-- ============================================================================
--  E. Pips
-- ============================================================================

function Orb:AddOrbPip()
    local pip = self:CreateTexture()
    pip:SetDrawLayer('ARTWORK', 3)
    table.insert(self.pips, pip)
end

function Orb:GetOrbPipCount()
    if self.resource == 'power' then
        return UnitPower2(self.unit), UnitPower2Max(self.unit)
    else
        return 0, 0
    end
end

function Orb:UpdateOrbPips()
    local pipSettings = self.settings.pips
    if self.resource == 'power' and pipSettings.shape ~= 'none' then
        local pipCount, pipMaxCount = self:GetOrbPipCount()
        if pipMaxCount > #self.pips then
            while pipMaxCount > #self.pips do
                self:AddOrbPip()
            end
            self:SetOrbPipShape()
        end
        self:SetOrbPipTextures()
    else
        for n, pip in ipairs(self.pips) do
            pip:Hide()
        end
    end
end

function Orb:SetOrbPipShape()
    local pipSettings = self.settings.pips
    local pipCount, pipMaxCount = self:GetOrbPipCount()
    local rotatePips = pipSettings.rotatePips
    local baseRotation = math.rad(pipSettings.baseRotation)
    if pipSettings.shape == 'arc' then
        local radius = pipSettings.radius
        local centerPoint = pipSettings.centerPoint
        local rotatePips = pipSettings.rotatePips
        local arcStart, arcEnd = unpack(pipSettings.arcSegment)
        local arcStep
        if (arcEnd - arcStart) % 360 == 0 then
            arcStep = (arcEnd - arcStart) / pipMaxCount
        else
            arcStep = (arcEnd - arcStart) / (pipMaxCount-1)
        end
        for n, pip in ipairs(self.pips) do
            if n > pipMaxCount then break end
            local theta = math.rad(arcStart + arcStep * (n-1))
            local x = radius * math.cos(theta) + centerPoint[1]
            local y = radius * math.sin(theta) + centerPoint[2]
            pip:SetPoint('CENTER', self, 'CENTER', x, y)
            if rotatePips then
                pip:SetRotation(baseRotation + theta)
            else
                pip:SetRotation(baseRotation)
            end
        end
    elseif pipSettings.shape == 'orb' then
        local radius = (self.settings.size / 2) + pipSettings.radiusOffset
        local arcStart, arcEnd = unpack(pipSettings.arcSegment)
        local arcStep
        if (arcEnd - arcStart) % 360 == 0 then
            arcStep = (arcEnd - arcStart) / pipMaxCount
        else
            arcStep = (arcEnd - arcStart) / (pipMaxCount-1)
        end
        for n, pip in ipairs(self.pips) do
            if n > pipMaxCount then break end
            local theta = math.rad(arcStart + arcStep * (n-1))
            local x = radius * math.cos(theta)
            local y = radius * math.sin(theta)
            pip:SetPoint('CENTER', self, 'CENTER', x, y)
            if rotatePips then
                pip:SetRotation(baseRotation + theta)
            else
                pip:SetRotation(baseRotation)
            end
        end
    elseif pipSettings.shape == 'line' then
        local x1, y1, x2, y2 = unpack(pipSettings.lineSegment)
        local xStep = (x2 - x1) / (pipMaxCount - 1)
        local yStep = (y2 - y1) / (pipMaxCount - 1)
        local theta = math.atan2(xStep, yStep)
        for n, pip in ipairs(self.pips) do
            if n > pipMaxCount then break end
            local x = x1 + xStep * (n-1)
            local y = y1 + yStep * (n-1)
            pip:SetPoint('CENTER', self, 'CENTER', x, y)
            if rotatePips then
                pip:SetRotation(baseRotation + theta)
            else
                pip:SetRotation(baseRotation)
            end
        end
    elseif pipSettings.shape == 'edge' then
        local edge = pipSettings.edge
        local edgeOffset = pipSettings.edgeOffset
        local edgeSegment = pipSettings.edgeSegment
        local w, h = self:GetWidth(), self:GetHeight()
        local x1, y1, x2, y2
        if edge == 'top' then
            x1, y1 = edgeSegment[1] * w, h - edgeOffset
            x2, y2 = edgeSegment[2] * w, h - edgeOffset
        elseif edge == 'bottom' then
            x1, y1 = edgeSegment[1] * w, edgeOffset
            x2, y2 = edgeSegment[2] * w, edgeOffset
        elseif edge == 'left' then
            x1, y1 = edgeOffset, edgeSegment[1] * h
            x2, y2 = edgeOffset, edgeSegment[2] * h
        elseif edge == 'right' then
            x1, y1 = w - edgeOffset, edgeSegment[1] * h
            x2, y2 = w - edgeOffset, edgeSegment[2] * h
        end
        local xStep = (x2 - x1) / (pipMaxCount-1)
        local yStep = (y2 - y1) / (pipMaxCount-1)
        local theta = math.atan2(xStep, yStep)
        for n, pip in ipairs(self.pips) do
            if n > pipMaxCount then break end
            local x = x1 + xStep * (n-1)
            local y = y1 + yStep * (n-1)
            pip:SetPoint('CENTER', self, 'BOTTOMLEFT', x, y)
            if rotatePips then
                pip:SetRotation(baseRotation + theta)
            else
                pip:SetRotation(baseRotation)
            end
        end
    end
    for i=pipMaxCount+1, #self.pips do
        self.pips[i]:Hide()
    end
end

function Orb:SetOrbPipTextures()
    local pipSettings = self.settings.pips
    if self.resource == 'power' then
        local textures = pipSettings.textures or { '', '' }
        local size = pipSettings.size
        local pipCount = UnitPower2(self.unit)
        local powerType = select(2, UnitPower2Type(self.unit))
        if powerType and pipSettings.resourceTextures[powerType] ~= nil then
            textures = pipSettings.resourceTextures[powerType]
        end
        for n, pip in ipairs(self.pips) do
            pip:SetWidth(size)
            pip:SetHeight(size)
            if n <= pipCount then
                ApplyTexture(pip, textures[1])
            else
                ApplyTexture(pip, textures[2])
            end
        end
    end
end

-- ============================================================================
--  F. Labels
-- ============================================================================

function Orb:AddOrbLabel(labelName)
    if self.labels[labelName] then return end

    local label = self:CreateFontString()
    self.labels[labelName] = label
    self.settings.labels[labelName] = self.settings.labels[labelName] or { }
    label.settings = self.settings.labels[labelName]
    label.orb = self

    self:SetOrbLabelDrawLayer(label)

    label.name = labelName
end

function Orb:UpdateOrbLabel(label)
    -- TODO: only update the text when necessary
    -- this will require the completion of the analysis step
    -- in OrbSettings.labels.text._apply()
    label:SetText(self:FormatTaggedText(label.settings.text))
end

local LabelTags = { }

local function ParseTags(text, callback)
end

function Orb:FormatTaggedText(text)
    local unit = self.unit
    local newText = ''
    local state = 'start'
    local segmentStart = 1
    local braceDepth
    local tagName
    for i=1, #text do
        local c = string.sub(text, i, i)
        if state == 'start' then
            if c == '{' then
                state = 'tagName'
                newText = newText..string.sub(text, segmentStart, i-1)
                segmentStart = i+1
            end
        elseif state == 'tagName' then
            if c == '}' then
                state = 'start'
                tagName = string.sub(text, segmentStart, i-1)
                local tag = LabelTags[tagName]
                if tag and UnitExists(unit) then
                    newText = newText..tag(self)
                else
                    newText = newText..'-'
                end
                segmentStart = i+1
            elseif c == ':' then
                state = 'tagContents'
                braceDepth = 1
                tagName = string.sub(text, segmentStart, i-1)
                segmentStart = i+1
            end
        elseif state == 'tagContents' then
            if c == '{' then
                braceDepth = braceDepth + 1
            elseif c == '}' then
                braceDepth = braceDepth - 1
                if braceDepth == 0 then
                    state = 'start'
                    local tagContents = string.sub(text, segmentStart, i-1)
                    local tag = LabelTags[tagName]
                    if tag and UnitExists(unit) then
                        newText = newText..tag(self, tagContents)
                    else
                        newText = newText..'-'
                    end
                    segmentStart = i+1
                end
            end
        end
    end
    return newText..string.sub(text, segmentStart)
end

function LabelTags.class(orb)
    return UnitClass(orb.unit)
end

function LabelTags.name(orb)
    return UnitName(orb.unit)
end

function LabelTags.resourceName(orb)
    if orb.resource == 'health' then
        return 'Health'
    elseif orb.resource == 'power' then
        return LabelTags.powerName(orb)
    elseif orb.resource == 'power2' then
        return LabelTags.power2Name(orb)
    end
end

function LabelTags.resource(orb)
    if orb.resource == 'health' then
        return LabelTags.health(orb)
    elseif orb.resource == 'power' then
        return LabelTags.power(orb)
    elseif orb.resource == 'power2' then
        return LabelTags.power2(orb)
    end
end

function LabelTags.resourceMax(orb)
    if orb.resource == 'health' then
        return LabelTags.healthMax(orb)
    elseif orb.resource == 'power' then
        return LabelTags.powerMax(orb)
    elseif orb.resource == 'power2' then
        return LabelTags.power2Max(orb)
    end
end

function LabelTags.resourcePercent(orb)
    if orb.resource == 'health' then
        return LabelTags.healthPercent(orb)
    elseif orb.resource == 'power' then
        return LabelTags.powerPercent(orb)
    elseif orb.resource == 'power2' then
        return LabelTags.power2Percent(orb)
    end
end

function LabelTags.hasResource2(orb, tagContents)
    if orb.resource == 'power' and UnitPower2Max(orb.unit) > 0 then
        return orb:FormatTaggedText(tagContents)
    else
        return ''
    end
end

function LabelTags.resource2Name(orb)
    if orb.resource == 'power' then
        return LabelTags.power2Name(orb)
    else
        return '-'
    end
end

function LabelTags.resource2(orb)
    if orb.resource == 'power' then
        return LabelTags.power2(orb)
    else
        return '-'
    end
end

function LabelTags.resource2Max(orb)
    if orb.resource == 'power' then
        return LabelTags.power2Max(orb)
    else
        return '-'
    end
end

function LabelTags.resource2Percent(orb)
    if orb.resource == 'power' then
        return LabelTags.power2Percent(orb)
    else
        return '-'
    end
end

function LabelTags.health(orb)
    return tostring(UnitHealth(orb.unit))
end

function LabelTags.healthMax(orb)
    return tostring(UnitHealthMax(orb.unit))
end

function LabelTags.healthPercent(orb)
    local health, healthMax = UnitHealth(orb.unit), UnitHealthMax(orb.unit)
    if healthMax == 0 then
        return '-'
    else
        return tostring(math.floor(health / healthMax * 100))
    end
end

function LabelTags.powerName(orb)
    return L['POWER_'..select(2, UnitPowerType(orb.unit))]
end

function LabelTags.power(orb)
    return tostring(UnitPower(orb.unit))
end

function LabelTags.powerMax(orb)
    return tostring(UnitPowerMax(orb.unit))
end

function LabelTags.powerPercent(orb)
    local power, powerMax = UnitPower(orb.unit), UnitPowerMax(orb.unit)
    if powerMax == 0 then
        return '-'
    else
        return tostring(math.floor(power / powerMax * 100))
    end
end

function LabelTags.hasPower2(orb, tagContents)
    if UnitPower2Max(orb.unit) > 0 then
        return orb:FormatTaggedText(tagContents)
    else
        return ''
    end
end

function LabelTags.power2Name(orb)
    local powerType = select(2, UnitPower2Type(orb.unit))
    if powerType then
        return L['POWER_'..powerType]
    else
        return '-'
    end
end

function LabelTags.power2(orb)
    return tostring(UnitPower2(orb.unit))
end

function LabelTags.power2Max(orb)
    return tostring(UnitPower2Max(orb.unit))
end

function LabelTags.power2Percent(orb)
    local power2, power2Max = UnitPower2(orb.unit), UnitPower2Max(orb.unit)
    if power2Max == 0 then
        return '-'
    else
        return tostring(math.floor(power2 / power2Max * 100))
    end
end

-- ============================================================================
--  G. Local values and helper functions
-- ============================================================================

local defaultSettings = {
    enabled = true,
    locked = true,

    style = 'orb',
    unit = 'player',
    resource = 'health',

    colorStyle = 'resource',
    size = 128,
    aspectRatio = 1,
    direction = 'up',
    flipped = false,
    parent = nil,
    anchor = nil,

    backdrop = {
        texture = '',
    },
    backdropArt = {
        texture = '',
    },
    fill = {
        texture = '',
        resourceTextures = { },
    },
    border = {
        texture = '',
    },
    borderArt = {
        texture = '',
    },

    pips = {
        shape = 'none',
        size = 0,
        radius = 0,
        centerPoint = { 0, 0 },
        radiusOffset = 0,
        arcSegment = { 0, 0 },
        lineSegment = { 0, 0, 0, 0 },
        edge = 'top',
        edgeOffset = 0,
        edgeSegment = { 0, 1 },
        rotatePips = false,
        baseRotation = 0,
        textures = { '', '' },
        resourceTextures = { },
    },

    labels = {
        ['*'] = {
            text = '',
            font = 'GameFontWhite',
            anchor = {
                point = 'CENTER',
            },
            width = 0,
            height = 0,
            justifyH = 'LEFT',
            justifyV = 'TOP',
            showOnlyOnHover = false,
        },
    },
}

function ApplyTexture(region, texture)
    if type(texture) == 'string' then
        region:SetTexture(texture)
    elseif type(texture) == 'table' then
        region:SetColorTexture(unpack(texture))
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
    OrbFrames.TraverseSettings(settings, OrbSettings, {
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

        OrbFrames.TraverseSettings(inheritSettings, OrbSettings, {
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
    OrbFrames.TraverseSettings(defaultSettings, OrbSettings, {
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
