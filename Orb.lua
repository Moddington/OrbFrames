-- ============================================================================
--  Orb.lua
-- ----------------------------------------------------------------------------
--  A. Orb creation and management
--  B. Callbacks and methods
--  C. Updates
--  D. Settings
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

function Orb:OnShow()
    self:UpdateOrb()
end

function Orb:OnDragStart(button)
    if button == 'LeftButton' then
        self:StartMoving()
    end
end

function Orb:OnDragStop()
    self:StopMovingOrSizing()
end

function Orb:SetOrbEnabled(enabled)
    if enabled then
        self:ResumeOrbUpdates()
        self:Show()
    else
        self:Hide()
        self:SuspendOrbUpdates()
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
    if style == 'simple' then
        -- TODO
        if not self:HasComponent('sconce') then
            self:CreateComponent(OrbFrames.Components.Sconce, 'sconce')
        end
    end
end

-- ============================================================================
--  C. Updates
-- ============================================================================

function Orb:SuspendOrbUpdates()
    self.UpdateOrb = function() end
end

function Orb:ResumeOrbUpdates()
    self.UpdateOrb = Orb.UpdateOrb
end

function Orb:UpdateOrb()
    -- TODO
end

-- ============================================================================
--  D. Settings
-- ============================================================================

local OrbSchema = { }
OrbFrames.OrbSchema = OrbSchema

local ReadOrbSettings

local defaultSettings = {
    enabled = true,
    locked = true,
}

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

    -- Resume orb updates
    self:ResumeOrbUpdates()

    -- Update and return
    self:UpdateOrb()
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

-- Setting 'enabled' (boolean)
-- Description: Whether the orb is enabled or disabled
OrbSchema.enabled = {
    _priority = -100,

    _apply = function(orb, enabled)
        orb:SetOrbEnabled(enabled)
    end,
}

-- Setting 'locked' (boolean)
-- Description: Whether the orb is locked in place, or can be repositioned with
--              the mouse
OrbSchema.locked = {
    _apply = function(orb, locked)
    end,
}

-- Setting 'style' (string)
-- Description: The style used for the orb
-- Values: 'simple' - A plain ol' orb
OrbSchema.style = {
    _priority = 100,

    _apply = function(orb, style)
        orb:SetOrbStyle(style)
    end,
}

