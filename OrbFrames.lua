-- ============================================================================
--  OrbFrames.lua
-- ----------------------------------------------------------------------------
--  A. AddOn setup
--  B. AceAddon callbacks
--  C. Options table
--  D. Misc
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

local AceAddon = LibStub('AceAddon-3.0')
local AceConfig = LibStub('AceConfig-3.0')
local AceConfigCmd = LibStub('AceConfigCmd-3.0')
local AceConfigDialog = LibStub('AceConfigDialog-3.0')
local AceDB = LibStub('AceDB-3.0')

-- ============================================================================
--  A. AddOn setup
-- ============================================================================

_G.OrbFrames = AceAddon:NewAddon(OrbFrames, 'OrbFrames',
    'AceConsole-3.0')

-- Version info
OrbFrames.version = '0.0'

-- Default config data
OrbFrames.defaults = {
    profile = {
		colors = {
			classes = {
				DEATHKNIGHT = { 0.77, 0.12, 0.23 },
				DEMONHUNTER = { 0.64, 0.19, 0.79 },
				DRUID       = { 1.00, 0.49, 0.04 },
				HUNTER      = { 0.67, 0.83, 0.45 },
				MAGE        = { 0.41, 0.80, 0.94 },
				MONK        = { 0.33, 0.54, 0.52 },
				PALADIN     = { 0.96, 0.55, 0.73 },
				PRIEST      = { 1.00, 1.00, 1.00 },
				ROGUE       = { 1.00, 0.96, 0.41 },
				SHAMAN      = { 0.00, 0.44, 0.87 },
				WARLOCK     = { 0.58, 0.51, 0.79 },
				WARRIOR     = { 0.78, 0.61, 0.43 },
			},
			resources = {
				HEALTH = { 1.00, 0.00, 0.00 },
				MANA   = { 0.00, 0.00, 1.00 },
				RAGE   = { 1.00, 0.00, 0.00 },
				FOCUS  = { 1.00, 0.50, 0.25 },
				ENERGY = { 1.00, 1.00, 0.00 },
			},
		},
		orbs = { },
		blizz = { }
    },
}

-- ============================================================================
--  B. AceAddon callbacks
-- ============================================================================

function OrbFrames:OnInitialize()
	self.orbs = { }
	self.blizzHider = CreateFrame('Frame', 'OrbFrames_BlizzHider')
	self.blizzHider:Hide()
    self:InitOptions()
end

function OrbFrames:OnEnable()
	self:LoadAllOrbs()
	self:LoadBlizzSettings()
end

function OrbFrames:OnDisable()
	self:UnloadBlizzSettings()
    self:DisableAllOrbs()
end

-- ============================================================================
--  C. Options table
-- ============================================================================

local options = {
	name = 'OrbFrames',
	handler = OrbFrames,
	type = 'group',
	args = {
	},
}

function OrbFrames:InitOptions()
	self.db = AceDB:New('OrbFramesDB', self.defaults, true)

	AceConfig:RegisterOptionsTable('OrbFrames', options)
	self:RegisterChatCommand('of', 'ChatCommand')
	self:RegisterChatCommand('orbframes', 'ChatCommand')

	AceConfigDialog:AddToBlizOptions('OrbFrames')
end

function OrbFrames:ChatCommand(input)
	if InCombatLockdown() then
		self:Print(L['Cannot access options during combat.'])
		return
	end
	if not input or input:trim() == '' then
		self:OpenBlizzConfig()
	else
		AceConfigCmd.HandleCommand(OrbFrames, 'of', 'OrbFrames', input)
	end
end

function OrbFrames:OpenBlizzConfig()
	InterfaceOptionsFrame_OpenToCategory('OrbFrames')
	InterfaceOptionsFrame_OpenToCategory('OrbFrames')
end

-- ============================================================================
--  D. Misc
-- ============================================================================

function OrbFrames:LoadBlizzSettings()
	for blizzFrameName, settings in pairs(self.db.profile.blizz or { }) do
		self:SetBlizzHidden(blizzFrameName, settings.hidden)
	end
end

function OrbFrames:UnloadBlizzSettings()
	for blizzFrameName, settings in pairs(self.db.profile.blizz or { }) do
		self:SetBlizzHidden(blizzFrameName, false)
	end
end

function OrbFrames:SetBlizzHidden(blizzFrameName, hidden)
	-- TODO: maybe this can be made more compatible with other mods
	--       trying to hide the same frames?
	local blizzFrame = _G[blizzFrameName]
	if blizzFrame then
		if hidden then
			if blizzFrame:GetParent() ~= self.blizzHider then
				blizzFrame._oldParent = blizzFrame:GetParent()
				blizzFrame:SetParent(self.blizzHider)
			end
		else
			if blizzFrame:GetParent() == self.blizzHider then
				blizzFrame:SetParent(blizzFrame._oldParent)
				blizzFrame._oldParent = nil
			end
		end
	end
end
