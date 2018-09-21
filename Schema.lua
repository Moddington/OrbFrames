-- ============================================================================
--  Schema.lua
-- ----------------------------------------------------------------------------
--  A. TraverseSchema
--  B. Utils
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- ============================================================================
--  A. TraverseSchema
-- ============================================================================

function OrbFrames.TraverseSchema(settings, schema, iterator)
    -- iterator = {
    --     VisitSetting = function(name, value, schema, iterator) return end,
    --     EnterGroup = function(name, value, iterator) return value, iterator end,
    --     EnterList = function(name, value, iterator) return value, iterator end,
    --     EnterListElement = function(name, value, iterator) return value, iterator end,
    --     ...,
    -- }

    -- Generate settings order if it hasn't been yet
    if schema._order == nil then
        local order = { }
        for name, _ in pairs(schema) do
            if not string.match(name, '^_') then
                table.insert(order, name)
            end
        end
        table.sort(order, function(l, r)
            return (schema[l]._priority or 0) > (schema[r]._priority or 0)
        end)
        schema._order = order
    end

    -- Iterate through settings in order
    for _, name in ipairs(schema._order) do
        local schema = schema[name]
        local value = settings[name]
        if value ~= nil and not string.match(name, '^_') then
            if schema._type == 'group' then
                local value, iterator = iterator.EnterGroup(name, value, iterator)
                OrbFrames.TraverseSchema(value, schema, iterator)
            elseif schema._type == 'list' then
                local value, iterator = iterator.EnterList(name, value, iterator)
                for name, value in pairs(value) do
                    local value, iterator = iterator.EnterListElement(name, value, iterator)
                    OrbFrames.TraverseSchema(value, schema, iterator)
                end
            else
                iterator.VisitSetting(name, value, schema, iterator)
            end
        end
    end
end

function OrbFrames.ApplySchemaDefaults(settings, schema)
    for name, schema in pairs(schema) do
        if not string.match(name, '^_') then
            local value = settings[name]
            if schema._type == 'group' then
                if value == nil then
                    value = { }
                    settings[name] = value
                end
                OrbFrames.ApplySchemaDefaults(value, schema)
            elseif schema._type == 'list' then
                if value then
                    for name, value in pairs(value) do
                        OrbFrames.ApplySchemaDefaults(value, schema)
                    end
                end
            else
                if value == nil then
                    local default = schema._default
                    if type(default) == 'function' then
                        settings[name] = default()
                    else
                        settings[name] = default
                    end
                end
            end
        end
    end
end

-- ============================================================================
--  B. Utils
-- ============================================================================

OrbFrames.mirroredAlignments = {
    ['LEFT'] = 'RIGHT',
    ['CENTER'] = 'CENTER',
    ['RIGHT'] = 'LEFT',
}

OrbFrames.mirroredAnchors = {
    ['TOPLEFT'] = 'TOPRIGHT',
    ['TOP'] = 'TOP',
    ['TOPRIGHT'] = 'TOPLEFT',
    ['RIGHT'] = 'LEFT',
    ['BOTTOMRIGHT'] = 'BOTTOMLEFT',
    ['BOTTOM'] = 'BOTTOM',
    ['BOTTOMLEFT'] = 'BOTTOMRIGHT',
    ['LEFT'] = 'RIGHT',
    ['CENTER'] = 'CENTER',
}

OrbFrames.mirroredDirections = {
    ['up'] = 'up',
    ['down'] = 'down',
    ['left'] = 'right',
    ['right'] = 'left',
}
