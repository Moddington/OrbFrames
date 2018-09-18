-- ============================================================================
--  Components/Sconce.lua
-- ----------------------------------------------------------------------------
--  A. Sconce component
-- ============================================================================

local _, OrbFrames = ...
local L = LibStub('AceLocale-3.0'):GetLocale('OrbFrames')

-- ============================================================================
--  A. Sconce component
-- ============================================================================

local Sconce = OrbFrames:ComponentType('OrbFrames.Components.Sconce')
OrbFrames.Components.Sconce = Sconce

function Sconce:OnInitialize()
    self:SetScript('OnUpdate', self.OnUpdate)
end

function Sconce:OnUpdate(elapsed)
    print('elapsed')
end
