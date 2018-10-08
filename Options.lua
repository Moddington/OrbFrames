-- ============================================================================
--  Options.lua
-- ----------------------------------------------------------------------------
--  A. Options setup
--  B. Config setting access
--  C. Helpers
--  D. Options table
--   - New orb
--   - Select orb
--   - Orb settings
--   -- Meta
--   -- Inheritance
--   -- Style
--   -- Size and position
--   -- Textures
--   -- Pips
--   -- Labels
--   -- Icons
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

local AceConfig = LibStub('AceConfig-3.0')
local AceConfigCmd = LibStub('AceConfigCmd-3.0')
local AceConfigDialog = LibStub('AceConfigDialog-3.0')
local AceConfigRegistry = LibStub('AceConfigRegistry-3.0')
local AceDB = LibStub('AceDB-3.0')

-- ============================================================================
--  A. Options setup
-- ============================================================================

function OrbFrames:InitOptions()
	self.db = AceDB:New('OrbFramesDB', self.defaults, true)

	AceConfig:RegisterOptionsTable('OrbFrames', OrbFrames.options)
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
		--self:OpenBlizzConfig()
		AceConfigDialog:Open('OrbFrames')
	else
		AceConfigCmd.HandleCommand(OrbFrames, 'of', 'OrbFrames', input)
	end
end

function OrbFrames:OpenBlizzConfig()
	InterfaceOptionsFrame_OpenToCategory('OrbFrames')
	InterfaceOptionsFrame_OpenToCategory('OrbFrames')
end

-- ============================================================================
--  B. Config setting access
-- ============================================================================

function OrbFrames.GetOrbConfigSchema(path)
	local schema = OrbFrames.OrbSchema
    local name = string.gsub(path, '(.-)\\.', function(tableName)
        schema = schema[tableName]
        return ''
	end)
	print(path, schema, name, schema[name])
	return schema[name]
end

function OrbFrames.GetRawOrbConfigSetting(orbName, path)
	local orbConfig = OrbFrames.db.profile.orbs[orbName]

	local schema = OrbFrames.OrbSchema
	local settings = orbConfig
    local name = string.gsub(path, '(.-)\\.', function(tableName)
        schema = schema[tableName]
		settings = settings[tableName] or { }
        return ''
	end)
	return settings[name]
end

function OrbFrames.GetOrbConfigSetting(orbName, path)
	local orbConfig = OrbFrames.db.profile.orbs[orbName]
	return OrbFrames.ReadOrbSetting(orbConfig, path)
end

function OrbFrames.GetOrbConfigSettingSource(orbName, path)
	local orbConfig = OrbFrames.db.profile.orbs[orbName]

	local schema = OrbFrames.OrbSchema
	local settings = orbConfig
    local inheritName = settings.inherit
    local name = string.gsub(path, '(.-)\\.', function(tableName)
        schema = schema[tableName]
        settings = settings[tableName] or { }
        return ''
	end)

	if settings[name] then
		return orbName
	else
		if inheritName then
			if OrbFrames.db.profile.orbs[inheritName] == nil then
				error('Inherited orb "'..inheritName..'" does not exist')
			end
			local source = OrbFrames.GetOrbConfigSettingSource(inheritName, path)
			if source then
				return source
			end
		end
    end
end

function OrbFrames.SetOrbConfigSetting(orbName, path, value)
	local orbConfig = OrbFrames.db.profile.orbs[orbName]
	local orb = OrbFrames.orbs[orbName]

	local schema = OrbFrames.OrbSchema
	local settings = orbConfig
    local name = string.gsub(path, '(.-)\\.', function(tableName)
        schema = schema[tableName]
		settings[tableName] = settings[tableName] or { }
		settings = settings[tableName]
        return ''
	end)
	settings[name] = value

	value = OrbFrames.ReadOrbSetting(orbConfig, path)
	orb:ApplyOrbSetting(path, value)

	schema = schema[name]
	local mirroredValue = value
	if schema._mirror then
		mirroredValue = schema._mirror(value)
	end
	for name, settings in pairs(OrbFrames.db.profile.orbs) do
		local source = OrbFrames.GetOrbConfigSettingSource(name, path)
		if source == orbName then
			if settings.inheritStyle == 'mirror' then
				OrbFrames.orbs[name]:ApplyOrbSetting(path, mirroredValue)
			else
				OrbFrames.orbs[name]:ApplyOrbSetting(path, value)
			end
		end
	end
end

function OrbFrames.DefaultOrbConfigSetting(orbName, path)
	local orbConfig = OrbFrames.db.profile.orbs[orbName]
	local orb = OrbFrames.orbs[orbName]

	local schema = OrbFrames.OrbSchema
	local settings = orbConfig
    local name = string.gsub(path, '(.-)\\.', function(tableName)
        schema = schema[tableName]
		settings[tableName] = settings[tableName] or { }
		settings = settings[tableName]
        return ''
	end)
	local value = schema._default

	settings[name] = value
	orb:ApplyOrbSetting(path, value)

	schema = schema[name]
	local mirroredValue = value
	if schema._mirror then
		mirroredValue = schema._mirror(value)
	end
	for name, settings in pairs(OrbFrames.db.profile.orbs) do
		local source = OrbFrames.GetOrbConfigSettingSource(name, path)
		if source == orbName then
			if settings.inheritStyle == 'mirror' then
				OrbFrames.orbs[name]:ApplyOrbSetting(path, mirroredValue)
			else
				OrbFrames.orbs[name]:ApplyOrbSetting(path, value)
			end
		end
	end
end

-- ============================================================================
--  C. Helpers
-- ============================================================================

local values_AnchorPoints = {
	TOPLEFT = 'Top left',
	TOP = 'Top',
	TOPRIGHT = 'Top right',
	RIGHT = 'Right',
	BOTTOMRIGHT = 'Bottom right',
	BOTTOM = 'Bottom',
	BOTTOMLEFT = 'Bottom left',
	LEFT = 'Left',
	CENTER = 'Center',
}

local function values_Orbs(info)
	local values = { }
	for name, orb in pairs(OrbFrames.orbs) do
		values[name] = name
	end
	return values
end

local function values_OtherOrbs(info)
	local values = values_Orbs(info)
	values[OrbFrames.configSelectedOrb] = nil
	return values
end

local function get_OrbSetting(path)
	return function(info)
		local orbName = OrbFrames.configSelectedOrb
		return OrbFrames.GetOrbConfigSetting(orbName, path)
	end
end

local function set_OrbSetting(path)
	return function(info, value)
		local orbName = OrbFrames.configSelectedOrb
		OrbFrames.SetOrbConfigSetting(orbName, path, value)
	end
end

local function options_InheritSetting(order, path)
	return {
		order = order,
		name = function(info)
			local orbName = OrbFrames.configSelectedOrb
			local orbConfig = OrbFrames.db.profile.orbs[orbName]
			if orbConfig.inheritStyle == 'mirror' then
				local schema = OrbFrames.GetOrbConfigSchema(path)
				if schema._mirror then
					return 'Mirrored'
				end
			end
			return 'Copied'
		end,
		type = 'toggle',
		width = 'half',
		hidden = function(info)
			local orbName = OrbFrames.configSelectedOrb
			local orbConfig = OrbFrames.db.profile.orbs[orbName]
			return orbConfig.inherit == nil
		end,
		get = function(info)
			local orbName = OrbFrames.configSelectedOrb
			local source = OrbFrames.GetOrbConfigSettingSource(orbName, path)
			return source and source ~= orbName
		end,
		set = function(info, value)
			local orbName = OrbFrames.configSelectedOrb
			if value then
				OrbFrames.SetOrbConfigSetting(orbName, path, nil)
			end
		end,
	}
end

local function options_DefaultSetting(order, path)
	return {
		order = order,
		name = 'Default',
		type = 'execute',
		width = 'half',
		func = function(info)
			local orbName = OrbFrames.configSelectedOrb
			OrbFrames.DefaultOrbConfigSetting(orbName, path)
		end,
	}
end

local function options_OrbSetting(order, path, options)
    local group = {
        order = order,
        name = '',
        type = 'group',
        inline = true,
        args = {
			setting = options,
			inherit = options_InheritSetting(2, path),
			default = options_DefaultSetting(3, path),
        },
    }
	options.order = 1
	options.get = get_OrbSetting(path)
	options.set = set_OrbSetting(path)
    return group
end

local function options_OrbOrFrame(order, name, path, isAnchor)
	local function getType()
		return OrbFrames.configOrbOrFrame[path]
	end
	local function setType(type)
		OrbFrames.configOrbOrFrame[path] = type
	end
	local getValue
	local setValue
	if isAnchor then
		local anchorPath = string.gsub(path, '\\..-$', '')
		local subPath = string.match(path, '\\.(.-)$')
		getValue = function()
			local orbName = OrbFrames.configSelectedOrb
			local anchor = OrbFrames.GetOrbConfigSetting(orbName, anchorPath) or { }
			return anchor[subPath]
		end
		setValue = function(value)
			local orbName = OrbFrames.configSelectedOrb
			local anchor = OrbFrames.GetOrbConfigSetting(orbName, anchorPath) or { }
			anchor[subPath] = value
			OrbFrames.SetOrbConfigSetting(orbName, anchorPath, anchor)
		end
	else
		getValue = function()
			local orbName = OrbFrames.configSelectedOrb
			return OrbFrames.GetOrbConfigSetting(orbName, path)
		end
		setValue = function(value)
			local orbName = OrbFrames.configSelectedOrb
			OrbFrames.SetOrbConfigSetting(orbName, path, value)
		end
	end

	local orbOrFrame = {
		order = order,
		name = name,
		type = 'group',
		args = {
			type = {
				order = 1,
				name = '',
				type = 'select',
				values = {
					frame = 'Frame',
					orb = 'Orb',
				},
				get = function(info)
					if not getType() then
						local value = getValue()
						local valueType = 'orb'
						if value and not string.match(value, '^orb:') then
							valueType = 'frame'
						end
						setType(valueType)
					end
					return getType()
				end,
				set = function(info, value)
					setType(value)
				end,
			},
			orb = {
				order = 2,
				name = '',
				type = 'select',
				values = values_OtherOrbs,
				hidden = function(info)
					return getType() ~= 'orb'
				end,
				get = function(info)
					local value = getValue()
					if value then
						if string.match(value, '^orb:') then
							return string.gsub(value, '^orb:', '')
						else
							local valueName = string.match(value, 'OrbFrames_Orb_(.+)')
							if OrbFrames.orbs[valueName] == _G[value] then
								return valueName
							end
						end
					end
					return ''
				end,
				set = function(info, value)
					setValue('orb:'..value)
				end,
			},
			frame = {
				order = 2,
				name = '',
				type = 'input',
				hidden = function(info)
					return getType() ~= 'frame'
				end,
				get = function(info)
					local value = getValue()
					if value then
						if string.match(value, '^orb:') then
							local valueName = string.gsub(value, '^orb:', '')
							local valueOrb = OrbFrames.orbs[valueName]
							return valueOrb:GetName()
						else
							return value
						end
					end
					return ''
				end,
				set = function(info, value)
					setValue(value)
				end,
				validate = function(info, value)
					local frame = _G[value]
					if frame and frame.GetName and frame:GetName() == value then
						return true
					else
						return 'No such frame "'..value..'"'
					end
				end,
			},
			clear = {
				order = 3,
				name = 'Clear',
				type = 'execute',
				width = 'half',
				func = function(info)
					setValue(nil)
				end,
			},
		},
	}
	if not isAnchor then
		orbOrFrame.args.inherit = options_InheritSetting(4, path)
		orbOrFrame.args.default = options_DefaultSetting(5, path)
	end
	return orbOrFrame
end

local function options_OrbAnchorSetting(order, name, path, hasRelativeTo)
	local function getAnchorPart(subPath)
		return function(info)
			local orbName = OrbFrames.configSelectedOrb
			local anchor = OrbFrames.GetOrbConfigSetting(orbName, path) or { }
			return anchor[subPath]
		end
	end
	local function setAnchorPart(subPath)
		return function(info, value)
			local orbName = OrbFrames.configSelectedOrb
			local anchor = OrbFrames.GetOrbConfigSetting(orbName, path) or { }
			anchor[subPath] = value
			OrbFrames.SetOrbConfigSetting(orbName, path, anchor)
		end
	end
	local anchor = {
		order = order,
		name = name,
		type = 'group',
		args = {
			points = {
				order = 1,
				name = '',
				type = 'group',
				inline = true,
				args = {
					point = {
						order = 1,
						name = 'Point',
						type = 'select',
						values = values_AnchorPoints,
						get = getAnchorPart('point'),
						set = setAnchorPart('point'),
					},
					relativePoint = {
						order = 2,
						name = 'Relative point',
						type = 'select',
						values = values_AnchorPoints,
						get = getAnchorPart('relativePoint'),
						set = setAnchorPart('relativePoint'),
					},
					clearRelativePoint = {
						order = 3,
						name = 'Clear',
						type = 'execute',
						func = function(info)
							setAnchorPart('relativePoint')(info, nil)
						end,
					},
				},
			},
			offset = {
				order = 3,
				name = '',
				type = 'group',
				inline = true,
				args = {
					x = {
						order = 4,
						name = 'X offset',
						type = 'range',
						softMin = -1024,
						softMax = 1024,
						bigStep = 1,
						get = getAnchorPart('x'),
						set = setAnchorPart('x'),
					},
					y = {
						order = 5,
						name = 'Y offset',
						type = 'range',
						softMin = -1024,
						softMax = 1024,
						bigStep = 1,
						get = getAnchorPart('y'),
						set = setAnchorPart('y'),
					},
				},
			},
			inherit = options_InheritSetting(4, path),
			default = options_DefaultSetting(5, path),
		},
	}
	if hasRelativeTo then
		anchor.args.relativeTo = options_OrbOrFrame(2, 'Relative to', path..'.relativeTo', true)
	end
	return anchor
end

-- ============================================================================
--  D. Options table
-- ============================================================================

OrbFrames.options = {
	name = 'OrbFrames',
	type = 'group',
	childGroups = 'tree',
	args = { },
}

local optionsArgs = OrbFrames.options.args

-- ----------------------------------------------------------------------------
--  - New orb
-- ----------------------------------------------------------------------------

optionsArgs.newOrb = {
	order = 1,
	name = '',
	type = 'group',
	inline = true,
	args = {
		name = {
			order = 1,
			name = 'Name',
			type = 'input',
			get = function(info)
				return OrbFrames.configNewOrbName or ''
			end,
			set = function(info, value)
				OrbFrames.configNewOrbName = value
			end,
			validate = function(info, value)
				if OrbFrames.db.profile.orbs[value] then
					return 'An orb with that name already exists'
				else
					return true
				end
			end,
		},
		create = {
			order = 2,
			name = 'Create Orb',
			type = 'execute',
			disabled = function(info)
				return (OrbFrames.configNewOrbName or '') == ''
			end,
			func = function(info)
				local orbName = OrbFrames.configNewOrbName
				OrbFrames.configNewOrbName = nil
				if OrbFrames.db.profile.orbs[orbName] == nil then
					local orbConfig = {
						locked = false,
					}
					OrbFrames.db.profile.orbs[orbName] = orbConfig
					local orb = OrbFrames.orbs[orbName]
					if orb == nil then
						orb = OrbFrames:CreateOrb(orbName)
					else
						orb:ApplyOrbSettings(orbConfig)
					end
					AceConfigRegistry:NotifyChange('OrbFrames')
				end
			end,
		},
	},
}

-- ----------------------------------------------------------------------------
--  - Select orb
-- ----------------------------------------------------------------------------

optionsArgs.selectOrb = {
	order = 2,
	name = '',
	type = 'group',
	inline = true,
	args = {
		select = {
			order = 1,
			name = 'Select Orb',
			type = 'select',
			style = 'dropdown',
			values = values_Orbs,
			get = function(info)
				return OrbFrames.configSelectedOrb
			end,
			set = function(info, value)
				OrbFrames.configSelectedOrb = value
				OrbFrames.configOrbOrFrame = { }
			end,
		},
		delete = {
			order = 2,
			name = 'Delete Selected Orb',
			type = 'execute',
			confirm = true,
			disabled = function(info)
				return OrbFrames.configSelectedOrb == nil
			end,
			func = function(info)
				local orbName = OrbFrames.configSelectedOrb
				local orbConfig = OrbFrames.db.profile.orbs[orbName]
				local readOrbConfig = OrbFrames.ReadOrbSettings(orbConfig)
				local orb = OrbFrames.orbs[orbName]
				orb:SetOrbEnabled(false)
				OrbFrames.db.profile.orbs[orbName] = nil
				OrbFrames.configSelectedOrb = nil
				-- For any orbs that inherited from this one, copy the settings to preserve them
				local function VisitSetting(name, value, schema, iterator)
					if iterator.settings[name] == nil then
						if iterator.inheritStyle == 'mirror' and schema._mirror then
							value = schema._mirror(value)
						end
						iterator.settings[name] = value
					end
				end
				local function Enter(name, iterator)
					iterator = table.copy(iterator)
					iterator.settings[name] = iterator.settings[name] or { }
					iterator.settings = iterator.settings[name]
					return iterator
				end
				for name, settings in pairs(OrbFrames.db.profile.orbs) do
					local childOrb = OrbFrames.orbs[name]
					if settings.inherit == orbName then
						OrbFrames.TraverseSchema(readOrbConfig, OrbFrames.OrbSchema, {
							VisitSetting = VisitSetting,
							EnterGroup = Enter,
							EnterList = Enter,
							EnterListElement = Enter,
							settings = settings,
							inheritStyle = settings.inheritStyle or 'copy',
						})
						settings.inherit = nil
						childOrb:ApplyOrbSettings(settings)
					end
					if settings.parent == 'orb:'..orbName or settings.parent == orb:GetName() then
						settings.parent = nil
						childOrb:ApplyOrbSetting('parent', nil)
						if settings.anchor and settings.anchor.relativeTo == nil then
							settings.anchor = nil
							childOrb:ApplyOrbSetting('anchor', nil)
						end
					end
					if settings.anchor and (settings.anchor.relativeTo == 'orb:'..orbName
							or settings.anchor.relativeTo == orb:GetName()) then
						settings.anchor = nil
						childOrb:ApplyOrbSetting('anchor', nil)
					end
				end
				AceConfigRegistry:NotifyChange('OrbFrames')
			end,
		},
	},
}

-- ----------------------------------------------------------------------------
--  - Orb settings
-- ----------------------------------------------------------------------------

optionsArgs.orbSettings = {
	order = 3,
	name = 'Orb Settings',
	type = 'group',
	inline = true,
	childGroups = 'tree',
	hidden = function(info)
		return OrbFrames.configSelectedOrb == nil
	end,
	args = { },
}

local orbSettingsArgs = optionsArgs.orbSettings.args

-- ----------------------------------------------------------------------------
--  -- Meta
-- ----------------------------------------------------------------------------

orbSettingsArgs.meta = {
	order = 1,
	name = '',
	type = 'group',
	inline = true,
	args = {
		name = {
			order = 1,
			name = 'Name',
			type = 'input',
			get = function(info)
				return OrbFrames.configSelectedOrb
			end,
			set = function(info, value)
				local orbName = OrbFrames.configSelectedOrb
				local orbConfig = OrbFrames.db.profile.orbs[orbName]
				local orb = OrbFrames.orbs[orbName]
				local newName = value
				local newOrb = OrbFrames:CreateOrb(newName, orbConfig)
				orb:SetEnabled(false)
				OrbFrames.configSelectedOrb = newName
				OrbFrames.db.profile.orbs[orbName] = nil
				OrbFrames.db.profile.orbs[newName] = orbConfig
				for name, settings in pairs(OrbFrames.db.profile.orbs) do
					if settings.inherit == orbName then
						settings.inherit = newName
					end
					if settings.parent == 'orb:'..orbName then
						settings.parent = 'orb:'..newName
					elseif settings.parent == orb:GetName() then
						settings.parent = newOrb:GetName()
					end
					if settings.anchor and settings.anchor.relativeTo == 'orb:'..orbName then
						settings.anchor.relativeTo = 'orb:'..newName
					elseif settings.anchor and settings.anchor.relativeTo == 'orb:'..orbName then
						settings.anchor.relativeTo = newOrb:GetName()
					end
				end
				AceConfigRegistry:NotifyChange('OrbFrames')
			end,
			validate = function(info, value)
				if OrbFrames.db.profile.orbs[value] then
					return 'An orb with that name already exists'
				else
					return true
				end
			end,
		},
		enabled = {
			order = 2,
			name = 'Enabled',
			type = 'toggle',
			get = get_OrbSetting('enabled'),
			set = set_OrbSetting('enabled'),
		},
		locked = {
			order = 3,
			name = 'Locked',
			type = 'toggle',
			get = get_OrbSetting('locked'),
			set = set_OrbSetting('locked'),
		},
	},
}

-- ----------------------------------------------------------------------------
--  -- Inheritance
-- ----------------------------------------------------------------------------

orbSettingsArgs.inherit = {
	order = 2,
	name = 'Copy Settings',
	type = 'group',
	inline = true,
	args = {
		inheritStyle = {
			order = 1,
			name = '',
			type = 'select',
			values = {
				copy = 'Copy',
				mirror = 'Mirror',
			},
			get = function(info)
				local orbName = OrbFrames.configSelectedOrb
				local orbConfig = OrbFrames.db.profile.orbs[orbName]
				return orbConfig.inheritStyle or 'copy'
			end,
			set = function(info, value)
				local orbName = OrbFrames.configSelectedOrb
				local orbConfig = OrbFrames.db.profile.orbs[orbName]
				if orbConfig.inheritStyle ~= value then
					local orb = OrbFrames.orbs[orbName]
					orbConfig.inheritStyle = value
					orb:ApplyOrbSettings(orbConfig)
				end
			end,
		},
		inherit = {
			order = 3,
			name = '',
			type = 'select',
			values = values_OtherOrbs,
			get = get_OrbSetting('inherit'),
			set = function(info, value)
				local orbName = OrbFrames.configSelectedOrb
				local orbConfig = OrbFrames.db.profile.orbs[orbName]
				local orb = OrbFrames.orbs[orbName]
				orbConfig.inherit = value
				orb:ApplyOrbSettings(orbConfig)
			end,
		},
		clear = {
			order = 4,
			name = 'Clear',
			type = 'execute',
			width = 'half',
			func = function(info)
				local orbName = OrbFrames.configSelectedOrb
				local orbConfig = OrbFrames.db.profile.orbs[orbName]
				local orb = OrbFrames.orbs[orbName]
				orbConfig.inherit = nil
				orb:ApplyOrbSettings(orbConfig)
			end,
		},
	},
}

-- ----------------------------------------------------------------------------
--  -- Style
-- ----------------------------------------------------------------------------

orbSettingsArgs.style = {
	order = 3,
	name = '',
	type = 'group',
	inline = true,
	args = {
		style = options_OrbSetting(1, 'style', {
			name = 'Style',
			type = 'select',
			values = {
				simple = 'Simple',
			},
		}),
		direction = options_OrbSetting(2, 'direction', {
			name = 'Direction',
			type = 'select',
			values = {
				up = 'Up',
				down = 'Down',
				left = 'Left',
				right = 'Right',
			},
		}),
		unit = options_OrbSetting(3, 'unit', {
			name = 'Unit',
			type = 'input',
		}),
		resource = options_OrbSetting(4, 'resource', {
			name = 'Resource',
			type = 'select',
			values = {
				health = 'Health',
				power = 'Power',
				power2 = 'Secondary Power',
				empty = 'Always Empty',
				full = 'Always Full',
			},
		}),
		colorStyle = options_OrbSetting(5, 'colorStyle', {
			name = 'Color Style',
			type = 'select',
			values = {
				class = 'By class color',
				resource = 'By resource color',
				reaction = 'By reaction color',
			},
		}),
		showAbsorb = options_OrbSetting(6, 'showAbsorb', {
			name = 'Show Absorb Amount',
			type = 'toggle',
		}),
		showHeals = options_OrbSetting(7, 'showHeals', {
			name = 'Show Incoming Heals',
			type = 'toggle',
		}),
	},
}

-- ----------------------------------------------------------------------------
--  -- Size and position
-- ----------------------------------------------------------------------------

orbSettingsArgs.sizeAndPosition = {
	order = 4,
	name = '',
	type = 'group',
	inline = true,
	args = {
		size = options_OrbSetting(1, 'size', {
			name = 'Size',
			type = 'range',
			min = 0,
			softMax = 512,
			step = 1,
		}),
		aspectRatio = options_OrbSetting(2, 'aspectRatio', {
			name = 'Aspect Ratio',
			type = 'range',
			min = 0,
			softMax = 10,
		}),
		parent = options_OrbOrFrame(3, 'Parent', 'parent', false),
		anchor = options_OrbAnchorSetting(4, 'Anchor', 'anchor', true),
	},
}

-- ----------------------------------------------------------------------------
--  -- Textures
-- ----------------------------------------------------------------------------

orbSettingsArgs.textures = {
	order = 5,
	name = 'Textures',
	type = 'group',
	inline = true,
	args = {
		-- TODO
	},
}

-- ----------------------------------------------------------------------------
--  -- Pips
-- ----------------------------------------------------------------------------

orbSettingsArgs.pips = {
	order = 6,
	name = 'Pips',
	type = 'group',
	inline = true,
	args = {
		-- TODO
	},
}

-- ----------------------------------------------------------------------------
--  -- Labels
-- ----------------------------------------------------------------------------

orbSettingsArgs.labels = {
	order = 7,
	name = 'Labels',
	type = 'group',
	args = {
		-- TODO
	},
}

-- ----------------------------------------------------------------------------
--  -- Icons
-- ----------------------------------------------------------------------------

orbSettingsArgs.icons = {
	order = 8,
	name = 'Icons',
	type = 'group',
	args = {
		-- TODO
	},
}
