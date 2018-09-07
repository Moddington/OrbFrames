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
    anchor = {
        point = 'BOTTOMLEFT',
        x = 15,
        y = 15,
    },
    backdropTexture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
    fillTexture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
    borderTexture = '',
    borderArtTexture = '',
}

presets['PlayerPower'] = {
    enabled = true,
    locked = true,
    inherit = 'PlayerHealth',
    inheritStyle = 'mirror',

    resource = 'power',
}

-- ============================================================================
--  B. Pet
-- ============================================================================

presets['PetHealth'] = {
    enabled = true,
    locked = true,
    inherit = 'PlayerHealth',

    unit = 'pet',

    size = 128,
    parent = 'PlayerHealth',
    anchor = {
        point = 'BOTTOMRIGHT',
        x = 32,
        y = 0,
    },
}

presets['PetPower'] = {
    enabled = true,
    locked = true,
    inherit = 'PetHealth',
    inheritStyle = 'mirror',

    resource = 'power',

    parent = 'PlayerPower',
}
