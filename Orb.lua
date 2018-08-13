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
local orb_default_settings
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

function Orb:ApplyOrbSettings(settings)
    -- Set metatable for value inheritance
    local mirror_orb = nil
    local inherit_orb = nil
    setmetatable(settings, {
        __index = function(t, k)
            if rawget(t, k) ~= nil then return rawget(t, k) end
            if mirror_orb ~= nil and mirror_orb[k] ~= nil then return MirrorSetting(k, mirror_orb[k]) end
            if inherit_orb ~= nil and inherit_orb[k] ~= nil then return inherit_orb[k] end
            return orb_default_settings[k]
        end,
    })

    -- Suspend updates
    self:SuspendOrbUpdates()

    -- Apply settings
    local enabled = settings.enabled
    if enabled ~= nil then self:SetOrbEnabled(enabled) end
    local locked = settings.locked
    if locked ~= nil then self:SetOrbLocked(locked) end
    local mirror = settings.mirror
    if mirror ~= nil then
        mirror_orb = OrbFrames.db.profile.orbs[mirror]
        if mirror_orb == nil then
            error('Mirrored orb "'..mirror..'" does not exist')
        end
    end
    local inherit = settings.inherit
    if inherit ~= nil then
        inherit_orb = OrbFrames.db.profile.orbs[inherit]
        if inherit_orb == nil then error('Inherited orb "'..inherit..'" does not exist') end
    end

    local unit = settings.unit
    if unit ~= nil then self:SetOrbUnit(unit) end
    local resource = settings.resource
    if resource ~= nil then self:SetOrbResource(resource) end
    local style = settings.style
    if style ~= nil then self:SetOrbStyle(style) end

    local colorStyle = settings.colorStyle
    if colorStyle ~= nil then self:SetOrbColorStyle(colorStyle) end
    local size = settings.size
    if size ~= nil then self:SetOrbSize(size) end
    local aspectRatio = settings.aspectRatio
    if aspectRatio ~= nil then self:SetOrbAspectRatio(aspectRatio) end
    local flipped = settings.flipped
    if flipped ~= nil then self:SetOrbFlipped(flipped) end
    local parent = settings.parent
    if parent ~= nil then self:SetOrbParent(parent) end
    local anchor = settings.anchor
    if anchor ~= nil then self:SetOrbAnchor(anchor) end
    local backdropTexture = settings.backdropTexture
    if backdropTexture ~= nil then self:SetOrbBackdropTexture(backdropTexture) end
    local fillTexture = settings.fillTexture
    if fillTexture ~= nil then self:SetOrbFillTexture(fillTexture) end
    local borderTexture = settings.borderTexture
    if borderTexture ~= nil then self:SetOrbBorderTexture(borderTexture) end
    local borderArtTexture = settings.borderArtTexture
    if borderArtTexture ~= nil then self:SetOrbBorderArtTexture(borderArtTexture) end

    -- Resume updates
    self:ResumeOrbUpdates()

    -- Clear settings metatable
    setmetatable(settings, nil)

    -- Update and return
    self:UpdateOrb()
end

function Orb:SetOrbEnabled(enabled)
    if enabled ~= self.enabled then
        self.enabled = enabled
        if enabled then
            self:Show()
        else
            self:Hide()
        end
    end
end

function Orb:SetOrbLocked(locked)
    if locked ~= self.locked then
        self.locked = locked
        if locked then
            self:RegisterForDrag()
        else
            self:RegisterForDrag('LeftButton')
        end
    end
end

function Orb:SetOrbUnit(unit)
    if unit ~= self.unit then
        self.unit = unit
        self:SetAttribute('unit', unit)
        SecureUnitButton_OnLoad(self, unit) -- TODO: menuFunc
        self:RegisterOrbEvents()
        self:UpdateOrb()
    end
end

function Orb:SetOrbResource(resource)
    if resource ~= self.resource then
        self.resource = resource
        self:RegisterOrbEvents()
        self:UpdateOrb()
    end
end

function Orb:SetOrbStyle(style)
    if style ~= self.style then
        self.style = style
        if style == 'simple' then
            self:CreateOrbBackdropTexture()
            self:CreateOrbFillTexture()
            self:CreateOrbBorderTexture()
            self:CreateOrbBorderArtTexture()
        end
        self:RegisterOrbEvents()
    end
end

function Orb:SetOrbColorStyle(colorStyle)
    if colorStyle ~= self.colorStyle then
        self.colorStyle = colorStyle
        self:UpdateOrb()
    end
end

function Orb:SetOrbSize(size)
    if size ~= self.size then
        self.size = size
        local aspectRatio = self.aspectRatio
        if aspectRatio ~= nil then
            self:SetWidth(size * aspectRatio)
            self:SetHeight(size)
            self:UpdateOrb()
        end
    end
end

function Orb:SetOrbAspectRatio(aspectRatio)
    if aspectRatio ~= self.aspectRatio then
        self.aspectRatio = aspectRatio
        local size = self.size
        if size ~= nil then
            self:SetWidth(size * aspectRatio)
            self:SetHeight(size)
            self:UpdateOrb()
        end
    end
end

function Orb:SetOrbFlipped(flipped)
    if flipped ~= self.flipped then
        self.flipped = flipped
        self:UpdateOrb()
    end
end

function Orb:SetOrbParent(parent)
    if parent ~= self.parent then
        self.parent = parent
        if parent == nil then
            parent = UIParent
        else
            parent = OrbFrames.orbs[parent]
        end
        self:SetParent(parent)
        self:SetOrbAnchors()
    end
end

function Orb:SetOrbAnchor(anchor)
    if anchor ~= self.anchor then
        self.anchor = anchor
        self:SetOrbAnchors()
    end
end

function Orb:SetOrbBackdropTexture(backdropTexture)
    if backdropTexture ~= self.backdropTexture then
        self.backdropTexture = backdropTexture
        local r_backdropTexture = self.regions.backdropTexture
        if r_backdropTexture ~= nil then ApplyTexture(r_backdropTexture, backdropTexture) end
    end
end

function Orb:SetOrbFillTexture(fillTexture)
    if fillTexture ~= self.fillTexture then
        self.fillTexture = fillTexture
        local r_fillTexture = self.regions.fillTexture
        if r_fillTexture ~= nil then ApplyTexture(r_fillTexture, fillTexture) end
    end
end

function Orb:SetOrbBorderTexture(borderTexture)
    if borderTexture ~= self.borderTexture then
        self.borderTexture = borderTexture
        local r_borderTexture = self.regions.borderTexture
        if r_borderTexture ~= nil then ApplyTexture(r_borderTexture, borderTexture) end
    end
end

function Orb:SetOrbBorderArtTexture(borderArtTexture)
    if borderArtTexture ~= self.borderArtTexture then
        self.borderArtTexture = borderArtTexture
        local r_borderArtTexture = self.regions.borderArtTexture
        if r_borderArtTexture ~= nil then ApplyTexture(r_borderArtTexture, borderArtTexture) end
    end
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

orb_default_settings = {
    aspectRatio = 1,
    flipped = false,
}

function ApplyTexture(r_texture, texture)
    if type(texture) == 'string' then
        r_texture:SetTexture(texture)
    elseif type(texture) == 'table' then
        r_texture:SetColorTexture(unpack(texture))
    end
end

function MirrorSetting(k, v)
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
