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
    orb.backdropTexture = { }
    orb.backdropArtTexture = { }
    orb.fillTexture = { }
    orb.borderTexture = { }
    orb.borderArtTexture = { }

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
            local direction = self.direction
            if direction == 'up' then
                r_fillTexture:SetHeight(self:GetHeight() * proportion)
                r_fillTexture:SetTexCoord(0, 1, 1 - proportion, 1)
            elseif direction == 'down' then
                r_fillTexture:SetHeight(self:GetHeight() * proportion)
                r_fillTexture:SetTexCoord(0, 1, 0, proportion)
            elseif direction == 'left' then
                r_fillTexture:SetWidth(self:GetWidth() * proportion)
                r_fillTexture:SetTexCoord(1 - proportion, 1, 0, 1)
            elseif direction == 'right' then
                r_fillTexture:SetWidth(self:GetWidth() * proportion)
                r_fillTexture:SetTexCoord(0, proportion, 0, 1)
            end
            r_fillTexture:Show()
        else
            r_fillTexture:Hide()
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
local settingOrder = { } -- This value is populated at the end of this section

function Orb:ApplyOrbSettings(settings)
    -- Read orb settings to acquire inherited and default values
    settings = ReadSettings(settings)

    -- Suspend orb updates
    self:SuspendOrbUpdates()

    -- Apply settings
    for _, setting in ipairs(settingOrder) do
        local fields = Settings[setting]
        if fields._group then
            local settingGroup = settings[setting]
            local selfSettingGroup = self[setting]
            for setting, fields in pairs(fields) do
                if not string.match(setting, '^_') then
                    local value = settingGroup[setting]
                    if value ~= nil and value ~= selfSettingGroup[setting] then
                        selfSettingGroup[setting] = value
                        fields.apply(self, value)
                    end
                end
            end
        else
            local value = settings[setting]
            if value ~= nil and value ~= self[setting] then
                self[setting] = value
                fields.apply(self, value)
            end
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
-- Values: 'orb' - A fixed-size element
-- TODO: 'bar' - A stretchable element
Settings.style = { }
function Settings.style.apply(orb, style)
    if style == 'orb' then
        orb:CreateOrbBackdropTexture()
        orb:CreateOrbBackdropArtTexture()
        orb:CreateOrbFillTexture()
        orb:CreateOrbBorderTexture()
        orb:CreateOrbBorderArtTexture()
    end
    orb:RegisterOrbEvents()
end

-- Setting 'direction' (string)
-- Description: The direction the orb fills in
-- Values: 'up', 'down', 'left', 'right'
Settings.direction = { }
function Settings.direction.apply(orb, direction)
    if orb.regions.fillTexture then
        orb:SetFillTextureAnchors()
    end
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
--         , x (number)             - X offset (defaults to 0)
--         , y (number)             - Y offset (defaults to 0)
--         }
--         nil - Defaults to { point = 'CENTER', }
-- Notes: Valid points are: TOPLEFT, TOP, TOPRIGHT, RIGHT, BOTTOMRIGHT,
--        BOTTOM, BOTTOMLEFT, LEFT, CENTER
Settings.anchor = { }
function Settings.anchor.apply(orb, anchor)
    orb:SetOrbAnchors()
end

-- Setting group 'backdropTexture'
-- Description: Contains settings related to the orb's backdrop
Settings.backdropTexture = { _group = true }

-- Setting 'backdropTexture.texture' (string)
-- Description: Name of the texture to use as a backdrop
-- Values: Any valid path to a texture
Settings.backdropTexture.texture = { }
function Settings.backdropTexture.texture.apply(orb, texture)
    local r_backdropTexture = orb.regions.backdropTexture
    if r_backdropTexture ~= nil then ApplyTexture(r_backdropTexture, texture) end
end

-- Setting group 'backdropArtTexture'
-- Description: Contains settings related to the orb's backdrop art
Settings.backdropArtTexture = { _group = true }

-- Setting 'backdropArtTexture.texture' (string)
-- Description: Name of the texture to use as art behind and around the backdrop
-- Values: Any valid path to a texture
Settings.backdropArtTexture.texture = { }
function Settings.backdropArtTexture.texture.apply(orb, texture)
    local r_backdropArtTexture = orb.regions.backdropArtTexture
    if r_backdropArtTexture ~= nil then ApplyTexture(r_backdropArtTexture, texture) end
end

-- Setting group 'fillTexture'
-- Description: Contains settings related to the orb's fill
Settings.fillTexture = { _group = true }

-- Setting 'fillTexture.texture' (string)
-- Description: Name of the texture to use for the fill
-- Values: Any valid path to a texture
Settings.fillTexture.texture = { }
function Settings.fillTexture.texture.apply(orb, texture)
    local r_fillTexture = orb.regions.fillTexture
    if r_fillTexture ~= nil then ApplyTexture(r_fillTexture, texture) end
end

-- Setting group 'borderTexture'
-- Description: Contains settings related to the orb's border
Settings.borderTexture = { _group = true }

-- Setting 'borderTexture.texture' (string)
-- Description: Name of the texture to use as a border
-- Values: Any valid path to a texture
Settings.borderTexture.texture = { }
function Settings.borderTexture.texture.apply(orb, texture)
    local r_borderTexture = orb.regions.borderTexture
    if r_borderTexture ~= nil then ApplyTexture(r_borderTexture, texture) end
end

-- Setting group 'borderArtTexture'
-- Description: Contains settings related to the orb's border art
Settings.borderArtTexture = { _group = true }

-- Setting 'borderArtTexture.texture' (string)
-- Description: Name of the texture to use as border artwork
-- Values: Any valid path to a texture
Settings.borderArtTexture.texture = { }
function Settings.borderArtTexture.texture.apply(orb, texture)
    local r_borderArtTexture = orb.regions.borderArtTexture
    if r_borderArtTexture ~= nil then ApplyTexture(r_borderArtTexture, texture) end
end

-- Optimize the loading order of settings
do
    local settingPriorities = {
        -- Positive values push to the front of the list, negative to the back
        style = 100,
        enabled = -100,
    }
    for setting, _ in pairs(Settings) do
        table.insert(settingOrder, setting)
    end
    table.sort(settingOrder, function(l, r)
        return (settingPriorities[l] or 0) > (settingPriorities[r] or 0)
    end)
end

-- ============================================================================
--  D. Regions
-- ============================================================================

function Orb:CreateOrbBackdropTexture()
    if self.regions.backdropTexture == nil then
        local r_backdropTexture = self:CreateTexture()
        r_backdropTexture:SetAllPoints(self)
        r_backdropTexture:SetDrawLayer('BACKGROUND', 0)
        r_backdropTexture:SetVertexColor(0, 0, 0, 1) -- TODO: remove
        local texture = self.backdropTexture.texture
        if texture ~= nil then ApplyTexture(r_backdropTexture, texture) end
        self.regions.backdropTexture = r_backdropTexture
    end
end

function Orb:CreateOrbBackdropArtTexture()
    if self.regions.backdropArtTexture == nil then
        local r_backdropArtTexture = self:CreateTexture()
        r_backdropArtTexture:SetAllPoints(self)
        r_backdropArtTexture:SetDrawLayer('BACKGROUND', -1)
        local texture = self.backdropArtTexture.texture
        if texture ~= nil then ApplyTexture(r_backdropArtTexture, texture) end
        self.regions.backdropArtTexture = r_backdropArtTexture
    end
end

function Orb:CreateOrbFillTexture()
    if self.regions.fillTexture == nil then
        local r_fillTexture = self:CreateTexture()
        r_fillTexture:SetDrawLayer('ARTWORK', 0)
        local texture = self.fillTexture.texture
        if texture ~= nil then ApplyTexture(r_fillTexture, texture) end
        self.regions.fillTexture = r_fillTexture
        self:SetFillTextureAnchors()
    end
end

function Orb:SetFillTextureAnchors()
    local direction = self.direction
    local r_fillTexture = self.regions.fillTexture
    r_fillTexture:ClearAllPoints()
    if direction == 'up' then
        r_fillTexture:SetPoint('BOTTOMLEFT')
        r_fillTexture:SetPoint('BOTTOMRIGHT')
        r_fillTexture:SetHeight(self:GetHeight())
    elseif direction == 'down' then
        r_fillTexture:SetPoint('TOPLEFT')
        r_fillTexture:SetPoint('TOPRIGHT')
        r_fillTexture:SetHeight(self:GetHeight())
    elseif direction == 'left' then
        r_fillTexture:SetPoint('TOPRIGHT')
        r_fillTexture:SetPoint('BOTTOMRIGHT')
        r_fillTexture:SetWidth(self:GetWidth())
    elseif direction == 'right' then
        r_fillTexture:SetPoint('TOPLEFT')
        r_fillTexture:SetPoint('BOTTOMLEFT')
        r_fillTexture:SetWidth(self:GetWidth())
    end
end

function Orb:CreateOrbBorderTexture()
    if self.regions.borderTexture == nil then
        local r_borderTexture = self:CreateTexture()
        r_borderTexture:SetAllPoints(self)
        r_borderTexture:SetDrawLayer('ARTWORK', 1)
        local texture = self.borderTexture.texture
        if texture ~= nil then ApplyTexture(r_borderTexture, texture) end
        self.regions.borderTexture = r_borderTexture
    end
end

function Orb:CreateOrbBorderArtTexture()
    if self.regions.borderArtTexture == nil then
        local r_borderArtTexture = self:CreateTexture()
        r_borderArtTexture:SetAllPoints(self)
        r_borderArtTexture:SetDrawLayer('ARTWORK', 2)
        local texture = self.borderArtTexture.texture
        if texture ~= nil then ApplyTexture(r_borderArtTexture, texture) end
        self.regions.borderArtTexture = r_borderArtTexture
    end
end

-- ============================================================================
--  E. Local values and helper functions
-- ============================================================================

local mirrored_anchors = {
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

local mirrored_directions = {
    ['up'] = 'up',
    ['down'] = 'down',
    ['left'] = 'right',
    ['right'] = 'left',
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
    elseif k == 'direction' then
        return mirrored_directions[v]
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
