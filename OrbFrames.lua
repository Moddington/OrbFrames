-- ============================================================================
--  OrbFrames.lua
-- ----------------------------------------------------------------------------
--  A. AddOn setup
--  B. AceAddon callbacks
--  C. Options table
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
    },
}

-- ============================================================================
--  B. AceAddon callbacks
-- ============================================================================

function OrbFrames:OnInitialize()
    self:InitOptions()
end

function OrbFrames:OnEnable()
end

function OrbFrames:OnDisable()
end

-- ============================================================================
--  C. Options table
-- ============================================================================

local options = {
	name = 'OrbFrames',
	handler = OrbFrames,
	type = 'group',
	args = {
	}
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
