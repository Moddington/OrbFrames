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
--   - Pips
--   - Labels
--   - Icons
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- Orb methods
local Orb = { }
OrbFrames.Orb = Orb

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
    orb.labels = { }
    orb.icons = { }
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
--  B. Callbacks
-- ============================================================================

function Orb:OnDragStart(button)
    if button == 'LeftButton' then
        self:StartMoving()
    end
end

function Orb:OnDragStop()
    self:StopMovingOrSizing()
end

-- ============================================================================
--  C. Settings
-- ============================================================================

local ReadOrbSettings

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
    local function VisitLabelSetting(name, value, schema, iterator)
        if iterator.settings[name] ~= value then
            iterator.settings[name] = value
            schema._apply(iterator.label, value)
        end
    end
    local function VisitIconSetting(name, value, schema, iterator)
        if iterator.settings[name] ~= value then
            iterator.settings[name] = value
            schema._apply(iterator.icon, value)
        end
    end
    local function Enter(name, value, iterator)
        iterator = table.copy(iterator)
        iterator.settings[name] = iterator.settings[name] or { }
        iterator.settings = iterator.settings[name]
        return iterator
    end
    local function EnterLabel(name, value, iterator)
        self:AddOrbLabel(name)
        iterator = Enter(name, value, iterator)
        iterator.label = self.labels[name]
        return iterator
    end
    local function EnterIcon(name, value, iterator)
        self:AddOrbIcon(name)
        iterator = Enter(name, value, iterator)
        iterator.icon = self.icons[name]
        return iterator
    end
    local function EnterList(name, value, iterator)
        iterator = Enter(name, value, iterator)
        if name == 'labels' then
            iterator.VisitSetting = VisitLabelSetting
            iterator.EnterListElement = EnterLabel
        elseif name == 'icons' then
            iterator.VisitSetting = VisitIconSetting
            iterator.EnterListElement = EnterIcon
        end
        return iterator
    end
    OrbFrames.TraverseSchema(settings, OrbFrames.OrbSchema, {
        VisitSetting = VisitSetting,
        EnterGroup = Enter,
        EnterList = EnterList,
        settings = self.settings,
    })
end

function Orb:ApplyOrbSetting(path, value)
    local schema = OrbFrames.OrbSchema
    local settings = self.settings
    local name = string.gsub(path, '(.-)\.', function(tableName)
        schema = schema[tableName]
        settings[tableName] = settings[tableName] or { }
        settings = settings[tableName]
        return ''
    end)
    if value ~= settings[name] then
        settings[name] = value
        schema[name]._apply(self, value)
    end
end

function ReadOrbSettings(settings)
    local readSettings = { }

    -- Iterator functions
    local function Enter(name, value, iterator)
        iterator = table.copy(iterator)
        iterator.readSettings[name] = iterator.readSettings[name] or { }
        iterator.readSettings = iterator.readSettings[name]
        return iterator
    end

    -- Copy settings
    OrbFrames.TraverseSchema(settings, OrbFrames.OrbSchema, {
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

        OrbFrames.TraverseSchema(inheritSettings, OrbFrames.OrbSchema, {
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
    OrbFrames.ApplySchemaDefaults(readSettings, OrbFrames.OrbSchema)

    return readSettings
end

-- ----------------------------------------------------------------------------
--  Meta
-- ----------------------------------------------------------------------------

function Orb:SetOrbEnabled(enabled)
    self.enabled = enabled
    if enabled then
        self:Show()
        self:SetOrbStyle(self.style)
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

-- ----------------------------------------------------------------------------
--  Style
-- ----------------------------------------------------------------------------

function Orb:SetOrbStyle(style)
    self.style = style
    self:DisableAllComponents()
    if style == 'simple' then
        self:CreateOrEnableComponent(OrbFrames.Components.SimpleSconce, 'SimpleSconce')
        self:CreateOrEnableComponent(OrbFrames.Components.ResourceBar, 'FillBar', 'ARTWORK', -2)
        self:CreateOrEnableComponent(OrbFrames.Components.Pips, 'Pips', 'ARTWORK', 3)
        -- TODO: icons, labels
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
        self:GetComponent('Pips'):SetUnit(unit)
    end
    for name, label in pairs(self.labels) do
        label:SetUnit(unit)
    end
    for name, icon in pairs(self.icons) do
        icons:SetUnit(unit)
    end
end

function Orb:SetOrbResource(resource)
    self.resource = resource
    local style = self.style
    if style == 'simple' then
        self:GetComponent('FillBar'):SetResource(resource)
        local pips = self:GetComponent('Pips')
        if resource == 'power' then
            pips:SetResource('power2')
        else
            pips:SetResource()
        end
        for name, label in pairs(self.labels) do
            label:SetResource(resource)
        end
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

-- ----------------------------------------------------------------------------
--  Size and positioning
-- ----------------------------------------------------------------------------

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

-- ----------------------------------------------------------------------------
--  Textures
-- ----------------------------------------------------------------------------

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

-- ----------------------------------------------------------------------------
--  Pips
-- ----------------------------------------------------------------------------

function Orb:SetOrbPipShape(shape, ...)
    local style = self.style
    if style == 'simple' then
        self:GetComponent('Pips'):SetShape(shape, ...)
    end
end

function Orb:SetOrbPipSize(size)
    local style = self.style
    if style == 'simple' then
        self:GetComponent('Pips'):SetSize(size)
    end
end

function Orb:SetOrbPipRotatePips(rotatePips)
    local style = self.style
    if style == 'simple' then
        self:GetComponent('Pips'):SetRotatePips(rotatePips)
    end
end

function Orb:SetOrbPipBaseRotation(baseRotation)
    local style = self.style
    if style == 'simple' then
        self:GetComponent('Pips'):SetBaseRotation(baseRotation)
    end
end

function Orb:SetOrbPipTextures(textures)
    local style = self.style
    if style == 'simple' then
        self:GetComponent('Pips'):SetTextures(textures)
    end
end

function Orb:SetOrbPipResourceTextures(resourceTextures)
    local style = self.style
    if style == 'simple' then
        for resource, textures in pairs(resourceTextures) do
            self:GetComponent('Pips'):SetResourceTextures(resource, textures)
        end
    end
end

-- ----------------------------------------------------------------------------
--  Labels
-- ----------------------------------------------------------------------------

function Orb:AddOrbLabel(name)
    local label = self:CreateOrEnableComponent(OrbFrames.Components.Label, 'Label_'..name)
    self.labels[name] = label
    label:SetUnit(self.unit)
    label:SetResource(self.resource)
end

-- ----------------------------------------------------------------------------
--  Icons
-- ----------------------------------------------------------------------------

function Orb:AddOrbIcon(name)
    local icon = self:CreateOrEnableComponent(OrbFrames.IconTypes[name], 'Icon_'..name)
    self.icons[name] = icon
    icon:SetIconScale(self.iconScale)
    icon:SetUnit(self.unit)
end

function Orb:SetOrbIconScale(iconScale)
    self.iconScale = iconScale
    for name, icon in pairs(self.icons) do
        icon:SetIconScale(iconScale)
    end
end
