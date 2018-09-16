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

OrbFrames.defaults.profile.blizz = {
    ['PlayerFrame'] = {
        hidden = true,
    },
    ['PetFrame'] = {
        hidden = true,
    },
    ['TargetFrame'] = {
        hidden = true,
    },
    ['PartyMemberFrame1'] = {
        hidden = false,
    },
    ['PartyMemberFrame2'] = {
        hidden = false,
    },
    ['PartyMemberFrame3'] = {
        hidden = false,
    },
    ['PartyMemberFrame4'] = {
        hidden = false,
    },
    ['CompactRaidManagerFrame'] = {
        hidden = false,
    },
    ['CastingBarFrame'] = {
        hidden = false,
    },
}

-- ============================================================================
--  A. Player
-- ============================================================================

presets['PlayerPortrait'] = {
    enabled = true,
    locked = true,

    style = 'orb',
    unit = 'player',
    resource = 'empty',
    direction = 'up',

    colorStyle = 'resource',
    size = 64,
    anchor = {
        point = 'TOPLEFT',
        x = 15,
        y = -15,
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
    border = {
        texture = '',
    },
    borderArt = {
        texture = '',
    },

    labels = {
        ['level'] = {
            text = '{level}',
            font = 'GameFontWhite',
            anchor = {
                point = 'CENTER',
                relativePoint = 'BOTTOMRIGHT',
                x = 0,
                y = 0,
            },
            justifyH = 'CENTER',
            justifyV = 'MIDDLE',
            -- TODO: border+backdrop
        },
    },

    iconScale = 1,
    icons = {
        inCombat = {
            enabled = true,
            anchor = {
                point = 'CENTER',
                relativePoint = 'BOTTOMRIGHT',
                x = 0,
                y = 0,
            },
        },
        resting = {
            enabled = true,
            anchor = {
                point = 'CENTER',
                relativePoint = 'BOTTOMLEFT',
                x = 0,
                y = 0,
            },
        },
        pvpFlag = {
            enabled = true,
            anchor = {
                point = 'CENTER',
                relativePoint = 'RIGHT',
                x = 0,
                y = 0,
            },
        },
        groupLeader = {
            enabled = true,
            anchor = {
                point = 'CENTER',
                relativePoint = 'BOTTOMRIGHT',
                x = 0,
                y = 0,
            },
        },
        groupRole = {
            enabled = true,
            anchor = {
                point = 'CENTER',
                relativePoint = 'BOTTOMRIGHT',
                x = 0,
                y = 0,
            },
        },
        masterLooter = {
            enabled = true,
            anchor = {
                point = 'CENTER',
                relativePoint = 'BOTTOMRIGHT',
                x = 0,
                y = 0,
            },
        },
        raidTarget = {
            enabled = true,
            anchor = {
                point = 'CENTER',
                relativePoint = 'BOTTOMRIGHT',
                x = 0,
                y = 0,
            },
        },
    },
}

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
--[[ TODO:
        resourceTextures = {
            ['HEALTH'] = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
            ['MANA'] = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
            ['RAGE'] = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
            ['FOCUS'] = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
            ['ENERGY'] = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
            ['RUNIC_POWER'] = 'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
        },
--]]
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
            text = '{hasResource:{resourceName}: {resource}/{resourceMax} ({resourcePercent}%)'
                .. '{hasResource2:\n{resource2Name}: {resource2}/{resource2Max} ({resource2Percent}%)}}',
            font = 'GameFontWhite',
            anchor = {
                point = 'BOTTOMLEFT',
                relativePoint = 'TOPLEFT',
                x = 5,
                y = 5,
            },
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

    pips = {
        shape = 'orb',
        size = 20,
        radiusOffset = 0,
        arcSegment = { 115, 165 },
        rotatePips = true,
        baseRotation = 0,
        textures = {
            'Interface\\AddOns\\OrbFrames\\Media\\circle.tga',
            { 0, 0, 0 }, -- TODO
        },
--[[ TODO:
        resourceTextures = {
            ['COMBO_POINTS'] = {
                '',
                '',
            },
            ['RUNES'] = {
                '',
                '',
            },
            ['SOUL_SHARDS'] = {
                '',
                '',
            },
            ['HOLY_POWER'] = {
                '',
                '',
            },
        },
--]]
    },
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

    colorStyle = 'reaction',
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
            text = '{name}',
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
            text = '{hasPower:{powerName}: {power}/{powerMax} ({powerPercent}%)}',
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
