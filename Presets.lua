-- ============================================================================
--  Presets.lua
-- ----------------------------------------------------------------------------
--  A. Player
--  B. Pet
--  C. Target
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
    style = 'orb',
    direction = 'up',

    colorStyle = 'resource',
    size = 256,
    anchor = {
        point = 'BOTTOMLEFT',
        x = 15,
        y = 15,
    },

    backdropTexture = {
        texture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
    },
    backdropArtTexture = {
        texture = '',
    },
    fillTexture = {
        texture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
    },
    borderTexture = {
        texture = '',
    },
    borderArtTexture = {
        texture = '',
    },
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

-- ============================================================================
--  C. Target
-- ============================================================================

presets['TargetHealth'] = {
    enabled = true,
    locked = true,

    unit = 'target',
    resource = 'health',
    style = 'orb',
    direction = 'right',

    colorStyle = 'class',
    size = 64,
    aspectRatio = 8,
    anchor = {
        point = 'TOP',
        x = 0,
        y = -15,
    },

    backdropTexture = {
        texture = { 0, 0, 0 },
    },
    backdropArtTexture = {
        texture = '',
    },
    fillTexture = {
        texture = { 1, 1, 1 },
    },
    borderTexture = {
        texture = '',
    },
    borderArtTexture = {
        texture = '',
    },
}
