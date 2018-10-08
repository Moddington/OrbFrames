-- ============================================================================
--  Schema.lua
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

function OrbFrames.TraverseSchema(settings, schema, iterator)
    -- iterator = {
    --     VisitSetting = function(name, value, schema, iterator) return end,
    --     EnterGroup = function(name, iterator) return iterator end,
    --     EnterList = function(name, iterator) return iterator end,
    --     EnterListElement = function(name, iterator) return iterator end,
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
                local iterator = iterator.EnterGroup(name, iterator)
                OrbFrames.TraverseSchema(value, schema, iterator)
            elseif schema._type == 'list' then
                local iterator = iterator.EnterList(name, iterator)
                for name, value in pairs(value) do
                    local iterator = iterator.EnterListElement(name, iterator)
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
