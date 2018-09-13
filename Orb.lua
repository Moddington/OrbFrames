-- ============================================================================
--  Orb.lua
-- ----------------------------------------------------------------------------
--  A. Orb creation and management
--  B. Callbacks and helpers
--  C. Settings
--  D. Regions
--  E. Labels
--  F. Local values and helper functions
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- Orb methods
local Orb = { }

-- Local values and helper functions
local mirroredAnchors
local mirroredAlignments
local mirroredDirections
local ApplyTexture
local MirrorSetting
local ReadSettings
local TraverseSettings

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
        fill = { },
        border = { },
        borderArt = { },

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
    local style = self.settings.style
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

        -- Update fill color
        local colors = OrbFrames.db.profile.colors
        local colorStyle = self.settings.colorStyle
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

    -- Update labels
    for labelName, label in pairs(self.labels) do
        self:UpdateOrbLabel(label)
    end
end

function Orb:UpdateOrbLabel(label)
    -- TODO: only update the text when necessary
    -- this will require the completion of the analysis step
    -- in Settings.labels.text._apply()
    local unit = self.unit
    local resource = self.resource
    local text = label.settings.text
    local formattedText = string.gsub(text, '{([^}]*)}', function(tag)
        if not UnitExists(unit) then
            return '-'
        else
            return self:ReadOrbLabelTag(tag)
        end
    end)
    label:SetText(formattedText)
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
    local function VisitSetting(name, value, schema, iterator)
        if iterator.settings[name] ~= value then
            iterator.settings[name] = value
            schema._apply(self, value)
        end
    end
    local function VisitLabelSetting(name, value, schema, iterator)
        if iterator.settings[name] ~= value then
            iterator.settings[name] = value
            schema._apply(self, iterator.label, value)
        end
    end
    local function Enter(name, iterator)
        local iterator = table.copy(iterator)
        iterator.settings[name] = iterator.settings[name] or { }
        iterator.settings = iterator.settings[name]
        return iterator
    end
    local function EnterLabel(name, iterator)
        self:AddOrbLabel(name)
        local iterator = Enter(name, iterator)
        iterator.label = self.labels[name]
        return iterator
    end
    local function EnterList(name, iterator)
        local iterator = Enter(name, iterator)
        if name == 'labels' then
            iterator.VisitSetting = VisitLabelSetting
            iterator.EnterListElement = EnterLabel
        end
        return iterator
    end
    TraverseSettings(settings, Settings, {
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

function Orb:ApplyOrbSetting(name, value, groupName)
    local Settings = Settings
    local settings = self.settings
    if groupName then
        if Settings[groupName] == nil then return end
        settings[groupName] = settings[groupName] or { }
        settings = settings[groupName]
        Settings = Settings[groupName]
    end
    if value ~= settings[name] then
        settings[name] = value
        Settings[name]._apply(self, value)
    end
end

function Orb:AddOrbLabel(labelName)
    if self.labels[labelName] then return end

    local label = self:CreateFontString()
    self.labels[labelName] = label
    self.settings.labels[labelName] = self.settings.labels[labelName] or { }
    label.settings = self.settings.labels[labelName]

    self:SetOrbLabelDrawLayer(label)

    label.name = labelName
end

function Orb:ApplyOrbLabelSetting(labelName, name, value)
    local label = self.labels[labelName]
    if value ~= label.settings[name] then
        label.settings[name] = value
        Settings.labels[name]._apply(self, label, value)
    end
end

-- Setting 'enabled' (boolean)
-- Description: Whether the orb is enabled or disabled
Settings.enabled = {
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
Settings.locked = {
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
Settings.style = {
    _priority = 100,

    _apply = function(orb, style)
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
--         'empty'  - Always show an empty orb
--         'full'   - Always show a full orb
Settings.resource = {
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
Settings.colorStyle = {
    _apply = function(orb, colorStyle)
        orb:UpdateOrb()
    end,
}

-- Setting 'size' (number)
-- Description: The vertical size of the orb
Settings.size = {
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
Settings.aspectRatio = {
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
Settings.direction = {
    _apply = function(orb, direction)
        if orb.fill then
            orb:SetFillAnchors()
        end
    end,

    _mirror = function(direction)
        return mirroredDirections[direction]
    end,
}

-- Setting 'flipped' (boolean)
-- Description: Whether the orb is flipped horizontally
Settings.flipped = {
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
Settings.parent = {
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
Settings.anchor = {
    _apply = function(orb, anchor)
        orb:SetOrbAnchors()
    end,

    _mirror = function(anchor)
        return {
            point = mirroredAnchors[anchor.point],
            relativeTo = anchor.relativeTo,
            relativePoint = mirroredAnchors[anchor.relativePoint],
            x = -anchor.x,
            y = anchor.y,
        }
    end,
}

-- Setting group 'backdrop'
-- Description: Contains settings related to the orb's backdrop
Settings.backdrop = {
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
Settings.backdropArt = {
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
Settings.fill = {
    _type = 'group',

    -- Setting 'texture' (string)
    -- Description: Name of the texture to use for the fill
    -- Values: Any valid path to a texture
    texture = {
        _apply = function(orb, texture)
            local fill = orb.fill
            if fill ~= nil then ApplyTexture(fill, texture) end
        end,
    },

}

-- Setting group 'border'
-- Description: Contains settings related to the orb's border
Settings.border = {
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
Settings.borderArt = {
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

-- Settings for elements list 'labels'
-- Description: An orb can have a number of labels on it to provide text display
Settings.labels = {
    _type = 'list',
    _priority = -10,

    -- Setting 'text'
    -- Description: A format string used to determine the label's text
    -- Values: A string optionally containing tags wrapped in {} braces.
    --         See the LabelTags table for a list of tags.
    text = {
        _apply = function(orb, label, text)
            -- TODO: Analyze the format string
            -- Update the label
            orb:UpdateOrbLabel(label)
        end,
    },

    -- Setting 'font'
    -- Description: The font object
    -- Values: Any string that refers to a font object in the global namespace
    font = {
        _priority = 10,

        _apply = function(orb, label, font)
            label:SetFontObject(_G[font]) -- TODO: better font lookup
        end,
    },

    -- Setting 'anchor'
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
        _apply = function(orb, label, anchor)
            orb:SetOrbLabelAnchors(label)
        end,

        _mirror = function(anchor)
            return {
                point = mirroredAnchors[anchor.point],
                relativePoint = mirroredAnchors[anchor.relativePoint],
                x = -anchor.x,
                y = anchor.y,
            }
        end,
    },

    -- Setting 'width'
    -- Description: The maximum width of the label
    width = {
        _apply = function(orb, label, width)
            label:SetWidth(width)
        end,
    },
    
    -- Setting 'height'
    -- Description: The maximum height of the label
    height = {
        _apply = function(orb, label, height)
            label:SetHeight(height)
        end,
    },

    -- Setting 'justifyH'
    -- Description: The horizontal justification for the text
    -- Values: 'LEFT', 'CENTER', 'RIGHT'
    justifyH = {
        _apply = function(orb, label, justifyH)
            label:SetJustifyH(justifyH)
        end,

        _mirror = function(justifyH)
            return mirroredAlignments[justifyH]
        end,
    },

    -- Setting 'justifyV'
    -- Description: The vertical justification for the text
    -- Values: 'TOP', 'MIDDLE', 'BOTTOM'
    justifyV = {
        _apply = function(orb, label, justifyV)
            label:SetJustifyV(justifyV)
        end,
    },

    -- Setting 'showOnlyOnHover'
    -- Description: Whether the label should only be visible while hovering
    --              over the orb
    showOnlyOnHover = {
        _apply = function(orb, label, showOnlyOnHover)
            orb:SetOrbLabelDrawLayer(label)
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
        fill:SetDrawLayer('ARTWORK', 0)
        local texture = self.settings.fill.texture
        if texture ~= nil then ApplyTexture(fill, texture) end
        self.fill = fill
        self:SetFillAnchors()
    end
end

function Orb:SetFillAnchors()
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
--  E. Labels
-- ============================================================================

local LabelTags = { }

function Orb:ReadOrbLabelTag(name)
    if LabelTags[name] == nil then
        return '-'
    else
        return LabelTags[name](self)
    end
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
        return L['POWER_'..select(2, UnitPowerType(orb.unit))]
    end
end

function LabelTags.resource(orb)
    if orb.resource == 'health' then
        return tostring(UnitHealth(orb.unit))
    elseif orb.resource == 'power' then
        return tostring(UnitPower(orb.unit))
    end
end

function LabelTags.resourceMax(orb)
    if orb.resource == 'health' then
        return tostring(UnitHealthMax(orb.unit))
    elseif orb.resource == 'power' then
        return tostring(UnitPowerMax(orb.unit))
    end
end

function LabelTags.resourcePercent(orb)
    if orb.resource == 'health' then
        return tostring(math.floor(UnitHealth(orb.unit) / UnitHealthMax(orb.unit) * 100))
    elseif orb.resource == 'power' then
        return tostring(math.floor(UnitPower(orb.unit) / UnitPowerMax(orb.unit) * 100))
    end
end

function LabelTags.health(orb)
    return tostring(UnitHealth(orb.unit))
end

function LabelTags.healthMax(orb)
    return tostring(UnitHealthMax(orb.unit))
end

function LabelTags.healthPercent(orb)
    return tostring(math.floor(UnitHealth(orb.unit) / UnitHealthMax(orb.unit) * 100))
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

function LabelTags.resourcePercent(orb)
    return tostring(math.floor(UnitPower(orb.unit) / UnitPowerMax(orb.unit) * 100))
end

-- ============================================================================
--  F. Local values and helper functions
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
    },
    border = {
        texture = '',
    },
    borderArt = {
        texture = '',
    },

    labels = {
        -- TODO
    },
}

mirroredAlignments = {
    ['LEFT'] = 'RIGHT',
    ['CENTER'] = 'CENTER',
    ['RIGHT'] = 'LEFT',
}

mirroredAnchors = {
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

mirroredDirections = {
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

function ReadSettings(settings)
    local readSettings = { }

    -- Iterator functions
    local function Enter(name, iterator)
        local iterator = table.copy(iterator)
        iterator.readSettings[name] = iterator.readSettings[name] or { }
        iterator.readSettings = iterator.readSettings[name]
        return iterator
    end

    -- Copy settings
    TraverseSettings(settings, Settings, {
        VisitSetting = function(name, value, schema, iterator)
            iterator.readSettings[name] = value
        end,
        EnterGroup = Enter,
        EnterList = Enter,
        EnterListElement = Enter,
        readSettings = readSettings,
    })

    -- Inherit settings
    local inheritName = settings.inherit
    local inheritStyle = settings.inheritStyle or 'copy'
    if inheritName ~= nil then
        local inheritSettings = OrbFrames.db.profile.orbs[inheritName]
        if inheritSettings == nil then error('Inherited orb "'..inheritName..'" does not exist') end
        inheritSettings = ReadSettings(inheritSettings)

        TraverseSettings(inheritSettings, Settings, {
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
    TraverseSettings(defaultSettings, Settings, {
        VisitSetting = function(name, value, schema, iterator)
            if iterator.readSettings[name] == nil then
                iterator.readSettings[name] = value
            end
        end,
        EnterGroup = Enter,
        EnterList = Enter,
        EnterListElement = Enter,
        readSettings = readSettings,
        inheritSettings = inheritSettings,
        defaultSettings = defaultSettings,
    })

    return readSettings
end

function TraverseSettings(settings, schema, iterator)
    -- iterator = {
    --     VisitSetting = function(name, value, schema, iterData) return end,
    --     EnterGroup = function(name, iterData) return iterData end,
    --     EnterList = function(name, iterData) return iterData end,
    --     EnterListElement = function(name, iterData) return iterData end,
    --     ...,
    -- }

    -- Generate settings order if it hasn't been yet
    if schema._order == nil then
        local order = { }
        for name, _ in pairs(schema) do
            if not string.match(name, '^_') then
                table.insert(order, name)
            end
        end
        table.sort(order, function(l, r)
            return (schema[l]._priority or 0) > (schema[r]._priority or 0)
        end)
        schema._order = order
    end

    -- Iterate through settings in order
    for _, name in ipairs(schema._order) do
        local schema = schema[name]
        local value = settings[name]
        if value ~= nil and not string.match(name, '^_') then
            if schema._type == 'group' then
                local iterator = iterator.EnterGroup(name, iterator)
                TraverseSettings(value, schema, iterator)
            elseif schema._type == 'list' then
                local iterator = iterator.EnterList(name, iterator)
                for name, value in pairs(value) do
                    local iterator = iterator.EnterListElement(name, iterator)
                    TraverseSettings(value, schema, iterator)
                end
            else
                iterator.VisitSetting(name, value, schema, iterator)
            end
        end
    end
end
