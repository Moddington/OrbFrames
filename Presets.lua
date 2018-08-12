-- ============================================================================
--  Presets.lua
-- ----------------------------------------------------------------------------
--  A. Player
--  B. Pet
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

local presets = OrbFrames.defaults.profile.orbs

-- ============================================================================
--  A. Player
-- ============================================================================

presets['PlayerHealth'] = {
    enabled = true,
    locked = true,

    unit = 'player',
    resource = 'health',
    style = 'simple',

    colorStyle = 'resource',
    size = 256,
    position = { 'BOTTOMLEFT', 50, 50 },
    fillTexture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
}

presets['PlayerPower'] = {
    enabled = true,
    locked = true,
    mirror = 'PlayerHealth'

    resource = 'power',
}

-- ============================================================================
--  B. Pet
-- ============================================================================

presets['PetHealth'] = {
    enabled = true,
    locked = true,

    unit = 'pet',
    resource = 'health',
    style = 'simple',

    colorStyle = 'resource',
    size = 64,
    parent = 'PlayerHealth',
    position = { 'BOTTOMRIGHT', 32, 0 },
    fillTexture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
}

presets['PetPower'] = {
    enabled = true,
    locked = true,
    mirror = 'PetHealth',

    resource = 'power',

    parent = 'PlayerPower',
}
