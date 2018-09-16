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

function table.find(t, k, i)
    for i=i or 1, #t do
        if t[i] == k then return i end
    end
end

local power2Types = {
    ['ROGUE'] = { 4, 'COMBO_POINTS' },
    ['DEATH_KNIGHT'] = { 5, 'RUNES' },
    ['WARLOCK'] = { 7, 'SOUL_SHARDS' },
    ['PALADIN'] = { 9, 'HOLY_POWER' },
}
function UnitPower2Type(unitID)
    local class = select(2, UnitClass(unitID))
    return unpack(power2Types[class] or { })
end

function UnitPower2(unitID)
    local powerID = UnitPower2Type(unitID)
    if powerID then
        return UnitPower(unitID, powerID)
    else
        return 0
    end
end

function UnitPower2Max(unitID)
    local powerID = UnitPower2Type(unitID)
    if powerID then
        return UnitPowerMax(unitID, powerID)
    else
        return 0
    end
end
