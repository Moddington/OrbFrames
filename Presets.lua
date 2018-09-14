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

    style = 'orb',
    unit = 'player',
    resource = 'health',
    direction = 'up',

    colorStyle = 'resource',
    size = 256,
    anchor = {
        point = 'BOTTOMLEFT',
        x = 15,
        y = 15,
    },

    backdrop = {
        texture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
    },
    backdropArt = {
        texture = '',
    },
    fill = {
        texture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
    },
    overfill = {
        texture = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
    },
    border = {
        texture = '',
    },
    borderArt = {
        texture = '',
    },

    labels = {
        ['resource'] = {
            text = '{resourceName}: {resource}/{resourceMax} ({resourcePercent}%)',
            font = 'GameFontWhite',
            anchor = {
                point = 'BOTTOMLEFT',
                relativePoint = 'TOPLEFT',
                x = 5,
                y = 5,
            },
            width = 0,
            justifyH = 'LEFT',
            justifyV = 'TOP',
        },
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

    labels = {
        ['resource'] = {
            showOnlyOnHover = true,
        },
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

    backdrop = {
        texture = { 0, 0, 0 },
    },
    backdropArt = {
        texture = '',
    },
    fill = {
        texture = { 1, 1, 1 },
    },
    border = {
        texture = '',
    },
    borderArt = {
        texture = '',
    },

    labels = {
        ['name'] = {
            text = '{name:titlecase}',
            font = 'GameFontWhite',
            anchor = {
                point = 'TOP',
                x = 0,
                y = -10,
            },
            width = 0,
            justifyH = 'CENTER',
            justifyV = 'TOP',
        },
        ['health'] = {
            text = 'Health: {health}/{healthMax} ({healthPercent}%)',
            font = 'GameFontWhite',
            anchor = {
                point = 'LEFT',
                x = 10,
                y = 0,
            },
            width = 0,
            justifyH = 'LEFT',
            justifyV = 'MIDDLE',
        },
        ['power'] = {
            text = '{powerName}: {power}/{powerMax} ({powerPercent}%)',
            font = 'GameFontWhite',
            anchor = {
                point = 'RIGHT',
                x = -10,
                y = 0,
            },
            width = 0,
            justifyH = 'RIGHT',
            justifyV = 'MIDDLE',
        },
    },
}
