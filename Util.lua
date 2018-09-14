-- ============================================================================
--  Util.lua
-- ----------------------------------------------------------------------------
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

function table.copy(t)
	local t2 = { }
	for k, v in pairs(t) do t2[k] = v end
	return t2
end

local secondaryPowerTypes = {
    ['ROGUE'] = { 4, 'COMBO_POINTS' },
    ['DEATH_KNIGHT'] = { 5, 'RUNES' },
    ['WARLOCK'] = { 7, 'SOUL_SHARDS' },
    ['PALADIN'] = { 9, 'HOLY_POWER' },
}
function UnitSecondaryPowerType(unitID)
    local class = select(2, UnitClass(unitID))
    return unpack(secondaryPowerTypes[class] or { })
end
