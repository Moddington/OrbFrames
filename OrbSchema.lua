-- ============================================================================
--  OrbSchema.lua
-- ----------------------------------------------------------------------------
--  A. Meta
--  B. Style
--  C. Size and positioning
--  D. Textures
--  E. Pips
--  F. Labels
--  G. Icons
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- Schema table
local OrbSchema = { }
OrbFrames.OrbSchema = OrbSchema

local Orb = OrbFrames.Orb

-- ============================================================================
--  A. Meta
-- ============================================================================

-- Setting 'enabled' (boolean)
-- Description: Whether the orb is enabled or disabled
OrbSchema.enabled = {
    _priority = -100,
    _default = true,
    _apply = Orb.SetOrbEnabled,
}

-- Setting 'locked' (boolean)
-- Description: Whether the orb is locked in place, or can be repositioned with
--              the mouse
OrbSchema.locked = {
    _default = true,
    _apply = Orb.SetOrbLocked,
}

-- ============================================================================
--  B. Style
-- ============================================================================

-- Setting 'style' (string)
-- Description: The style used for the orb
-- Values: 'simple' - A plain ol' orb
OrbSchema.style = {
    _priority = 100,
    _default = 'simple',
    _apply = Orb.SetOrbStyle,
}

-- Setting 'direction' (string)
-- Description: The direction the orb fills in
-- Values: 'up', 'down', 'left', 'right'
OrbSchema.direction = {
    _apply = Orb.SetOrbDirection,
    _default = 'up',
    _mirror = function(direction)
        return OrbFrames.mirroredDirections[direction]
    end,
}

-- Setting 'unit' (string)
-- Description: Which unit the orb is tracking
-- Values: Any valid WoW unit name
OrbSchema.unit = {
    _default = 'player',
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
    _default = 'health',
    _apply = Orb.SetOrbResource,
}

-- Setting 'colorStyle' (string)
-- Description: The method used to choose the color for the orb liquid
-- Values: 'class'    - The unit's class color
--         'resource' - The resource's color
--         'reaction' - The unit's reaction color
OrbSchema.colorStyle = {
    _default = 'resource',
    _apply = Orb.SetOrbColorStyle,
}

-- Setting 'showAbsorb' (boolean)
-- Description: When the orb resource is 'health', display absorb effects on
--              the unit as an overlay on the orb
OrbSchema.showAbsorb = {
    _default = true,
    _apply = Orb.SetOrbShowAbsorb,
}

-- Setting 'showHeals' (boolean)
-- Description: When the orb resource is 'health', display incoming heals as
--              a semi-transparent liquid on top of the health liquid
OrbSchema.showHeals = {
    _default = true,
    _apply = Orb.SetOrbShowHeals,
}

-- ============================================================================
--  C. Size and positioning
-- ============================================================================

-- Setting 'size' (number)
-- Description: The vertical size of the orb
OrbSchema.size = {
    _default = 256,
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
    _default = 1,
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
    _default = nil,
    _apply = function(orb, parent)
        local parentFrame
        if parent == nil then
            parentFrame = UIParent
        else
            local parentOrb = string.match(parent, '^orb:(.*)')
            if parentOrb then
                parentFrame = OrbFrames.orbs[parentOrb]
            else
                parentFrame = _G[parent]
            end
        end
        orb:SetParent(parentFrame)
        local anchor = orb.settings.anchor
        if anchor and anchor.relativeTo == nil then
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
    _default = nil,
    _alwaysApply = true,
    _apply = function(orb, anchor)
        orb:SetOrbPosition(anchor or {
            point = 'CENTER',
        })
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

-- ============================================================================
--  D. Textures
-- ============================================================================

-- Setting group 'backdrop'
-- Description: Contains settings related to the orb's backdrop
OrbSchema.backdrop = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use as a backdrop
    -- Values: Any valid path to a texture
    texture = {
        _default = '',
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
        _default = '',
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
        _default = '',
        _apply = Orb.SetOrbFillTexture,
    },

    -- Setting 'resourceTextures' (table)
    -- Description: A lookup table of textures to use for specific resources
    -- Values: A lookup table where keys are resource names, and values are
    --         any valid path to a texture
    resourceTextures = {
        _default = { },
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
        _default = '',
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
        _default = '',
        _apply = function(orb, texture)
            orb:SetOrbSconceTexture('BorderArt', texture)
        end,
    },

}

-- ============================================================================
--  E. Pips
-- ============================================================================

local function Orb_SetOrbPipShapeHelper(orb, shape, ...)
    local pipSettings = orb.settings.pips
    shape = shape or pipSettings.shape
    if shape == 'arc' then
        local radius, centerPoint, arcSegment = ...
        radius = radius or pipSettings.radius
        centerPoint = centerPoint or pipSettings.centerPoint
        arcSegment = arcSegment or pipSettings.arcSegment
        if radius and centerPoint and arcSegment then
            orb:SetOrbPipShape(shape, radius, centerPoint, arcSegment)
        end
    elseif shape == 'orb' then
        local radiusOffset, arcSegment = ...
        radiusOffset = radiusOffset or pipSettings.radiusOffset
        arcSegment = arcSegment or pipSettings.arcSegment
        if radiusOffset and arcSegment then
            orb:SetOrbPipShape(shape, radiusOffset, arcSegment)
        end
    elseif shape == 'line' then
        local lineSegment = ...
        lineSegment = lineSegment or pipSettings.lineSegment
        if lineSegment then
            orb:SetOrbPipShape(shape, lineSegment)
        end
    elseif shape == 'edge' then
        local edge, edgeOffset, edgeSegment = ...
        edge = edge or pipSettings.edge
        edgeOffset = edgeOffset or pipSettings.edgeOffset
        edgeSegment = edgeSegment or pipSettings.edgeSegment
        if edge and edgeOffset and edgeSegment then
            orb:SetOrbPipShape(shape, edge, edgeOffset, edgeSegment)
        end
    elseif shape == 'none' then
        orb:SetOrbPipShape(shape)
    end
end

-- Setting group 'pips'
-- Description: Contains settings used to display secondary power values as pip
--              icons on the orb
OrbSchema.pips = {
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
        _default = 'none',
        _apply = function(orb, shape)
            Orb_SetOrbPipShapeHelper(orb, shape)
        end,
    },

    -- Setting 'radius' (number)
    -- Description: Radius of the circle for the 'arc' shape
    radius = {
        _default = 0,
        _apply = function(orb, radius)
            local shape = orb.settings.pips.shape
            if shape == 'arc' then
                Orb_SetOrbPipShapeHelper(orb, 'arc', radius, nil, nil)
            end
        end,
    },

    -- Setting 'centerPoint' (table)
    -- Description: Centerpoint of the circle for the 'arc' shape
    -- Values: { x, y }
    centerPoint = {
        _default = { 0, 0 },
        _apply = function(orb, centerPoint)
            local shape = orb.settings.pips.shape
            if shape == 'arc' then
                Orb_SetOrbPipShapeHelper(orb, 'arc', nil, centerPoint, nil)
            end
        end,
        _mirror = function(centerPoint)
            return { -centerPoint[1], centerPoint[2] }
        end,
    },

    -- Setting 'radiusOffset' (number)
    -- Description: Offset for the radius of the 'orb' shape
    radiusOffset = {
        _default = 0,
        _apply = function(orb, radiusOffset)
            local shape = orb.settings.pips.shape
            if shape == 'orb' then
                Orb_SetOrbPipShapeHelper(orb, 'orb', radiusOffset, nil)
            end
        end,
    },

    -- Setting 'arcSegment' (table)
    -- Description: Starting and ending angles for the 'arc' and 'orb' shapes
    -- Values: { theta1, theta2 }
    -- Notes: Angles are measured in degrees
    arcSegment = {
        _default = { 0, 0 },
        _apply = function(orb, arcSegment)
            local shape = orb.settings.pips.shape
            if shape == 'arc' then
                Orb_SetOrbPipShapeHelper(orb, 'arc', nil, nil, arcSegment)
            elseif shape == 'orb' then
                Orb_SetOrbPipShapeHelper(orb, 'orb', nil, arcSegment)
            end
        end,
        _mirror = function(arcSegment)
            return { (180 - arcSegment[1]) % 360, (180 - arcSegment[2]) % 360 }
        end,
    },

    -- Setting 'lineSegment' (table)
    -- Description: Starting and ending points of the line segment for the 'line' shape
    -- Values: { x1, y2, x2, y2 }
    lineSegment = {
        _default = { 0, 0, 0, 0 },
        _apply = function(orb, lineSegment)
            local shape = orb.settings.pips.shape
            if shape == 'line' then
                Orb_SetOrbPipShapeHelper(orb, 'line', lineSegment)
            end
        end,
        _mirror = function(lineSegment)
            return {
                -lineSegment[1], lineSegment[2],
                -lineSegment[3], lineSegment[4],
            }
        end,
    },

    -- Setting 'edge' (string)
    -- Description: Name of the edge to use for the 'edge' shape
    -- Values: 'TOP', 'BOTTOM', 'LEFT', 'RIGHT'
    edge = {
        _default = 'top',
        _apply = function(orb, lineSegment)
            local shape = orb.settings.pips.shape
            if shape == 'edge' then
                Orb_SetOrbPipShapeHelper(orb, 'edge', edge, nil, nil)
            end
        end,
        _mirror = function(edge)
            return OrbFrames.mirroredEdges[edge]
        end,
    },

    -- Setting 'edgeOffset' (number)
    -- Description: Offset from the edge for the 'edge' shape
    edgeOffset = {
        _default = 0,
        _apply = function(orb, edgeOffset)
            local shape = orb.settings.pips.shape
            if shape == 'edge' then
                Orb_SetOrbPipShapeHelper(orb, 'edge', nil, edgeOffset, nil)
            end
        end,
    },

    -- Setting 'edgeSegment' (table)
    -- Description: The portion of the edge to use for the 'edge' shape
    -- Values = { start, end }, where each value represents a position along
    --          the edge, where 0 is one end and 1 is the other
    edgeSegment = {
        _default = { 0, 1 },
        _apply = function(orb, edgeSegment)
            local shape = orb.settings.pips.shape
            if shape == 'edge' then
                Orb_SetOrbPipShapeHelper(orb, 'edge', nil, nil, edgeSegment)
            end
        end,
    },

    -- Setting 'size' (number)
    -- Description: The size of each pip
    size = {
        _default = 0,
        _apply = Orb.SetOrbPipSize,
    },

    -- Setting 'rotatePips' (boolean)
    -- Description: Whether the pip icons should be rotated to be perpendicular
    --              to the shape they are placed upon
    rotatePips = {
        _default = false,
        _apply = Orb.SetOrbPipRotatePips,
    },

    -- Setting 'baseRotation' (number)
    -- Description: An angle to rotate the pips by
    -- Notes: Angles are measured in degrees
    baseRotation = {
        _default = 0,
        _apply = Orb.SetOrbPipBaseRotation,
        _mirror = function(baseRotation)
            return -baseRotation
        end,
    },

    -- Setting 'textures' (table)
    -- Description: Names of the textures to use for the pips
    -- Values: { on  (texture) - A texture for the 'on' state
    --         , off (texture) - A texture for the 'off' state
    --         }
    textures = {
        _default = {
            on = '',
            off = '',
        },
        _apply = Orb.SetOrbPipTextures,
    },

    -- Setting 'resourceTextures' (table)
    -- Description: A lookup table of textures to use for specific resources
    -- Values: A lookup table where keys are resource names, and values are
    --         of the form { on, off }, where both values are any valid path
    --         to a texture
    resourceTextures = {
        _default = { },
        _apply = Orb.SetOrbPipResourceTextures,
    },
}

-- ============================================================================
--  F. Labels
-- ============================================================================

-- Settings for elements list 'labels'
-- Description: An orb can have a number of labels on it to provide text display
OrbSchema.labels = {
    _type = 'list',
    _priority = -10,

    -- Setting 'text' (string)
    -- Description: A format string used to determine the label's text
    -- Values: A string optionally containing tags wrapped in {} braces.
    --         See the LabelTags table for a list of tags.
    text = {
        _default = '',
        _apply = function(label, text)
            label:SetText(text)
        end,
    },

    -- Setting 'font' (string)
    -- Description: The font object
    -- Values: Any string that refers to a font object in the global namespace
    font = {
        _priority = 10,
        _default = 'GameFontWhite',
        _apply = function(label, font)
            label:SetFont(_G[font]) -- TODO: better font lookup
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
        _default = {
            point = 'CENTER',
        },
        _apply = function(label, anchor)
            label:SetAnchor(anchor)
        end,
        _alwaysApply = true,
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
        _default = 0,
        _apply = function(label, width)
            label:SetWidth(width)
        end,
    },

    -- Setting 'height' (number)
    -- Description: The maximum height of the label
    height = {
        _default = 0,
        _apply = function(label, height)
            label:SetHeight(height)
        end,
    },

    -- Setting 'justifyH' (string)
    -- Description: The horizontal justification for the text
    -- Values: 'LEFT', 'CENTER', 'RIGHT'
    justifyH = {
        _default = 'LEFT',
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
        _default = 'TOP',
        _apply = function(label, justifyV)
            label:SetJustifyV(justifyV)
        end,
    },

    -- Setting 'showOnlyOnHover' (boolean)
    -- Description: Whether the label should only be visible while hovering
    --              over the orb
    showOnlyOnHover = {
        _default = false,
        _apply = function(label, showOnlyOnHover)
            label:SetShowOnlyOnHover(showOnlyOnHover)
        end,
    },

}

-- ============================================================================
--  G. Icons
-- ============================================================================

-- Setting 'iconScale' (number)
-- Description: The size to use for icons
OrbSchema.iconScale = {
    _default = 1,
    _apply = function(orb, iconScale)
        orb:SetOrbIconScale(iconScale)
    end,
}

-- Settings for elements list 'icons'
-- Description: A number of preset indicator icons are available for display on an orb
-- Values: For a list of valid element names, see the OrbFrames.IconTypes table
OrbSchema.icons = {
    _type = 'list',
    _priority = -10,

    -- Setting 'enabled' (boolean)
    -- Description: Whether the icon is enabled
    enabled = {
        _default = false,
        _apply = function(icon, enabled)
            icon:SetEnabled(enabled)
        end,
    },

    -- Setting 'anchor' (table)
    -- Description: An anchor used to position the icon
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
        _default = {
            point = 'CENTER',
        },
        _apply = function(icon, anchor)
            icon:SetAnchor(anchor)
        end,
        _alwaysApply = true,
        _mirror = function(anchor)
            return {
                point = OrbFrames.mirroredAnchors[anchor.point],
                relativePoint = OrbFrames.mirroredAnchors[anchor.relativePoint],
                x = -anchor.x,
                y = anchor.y,
            }
        end,
    },
}
