-- particle.lua
-- Tool handlers for ParticleLayer settings (rain, snow, sparks, smoke, etc.).
-- Returns a table of handler functions that accept (moho, params) and return
-- a result table on success, or nil + errorMessage on failure.

local particle = {}

--- Safely retrieve a layer by its absolute ID.
local function getLayerById(moho, layerId)
    if not moho or not moho.document then
        return nil, "No active document"
    end
    if type(layerId) ~= "number" then
        return nil, "layerId must be a number"
    end
    local ok, lyr = pcall(function() return moho.document:LayerByAbsoluteID(layerId) end)
    if not ok or not lyr then
        return nil, "Layer not found with absolute ID " .. tostring(layerId)
    end
    return lyr
end

--- Cast a layer to a ParticleLayer, validating the layer type first.
local function getParticleLayer(moho, layerId)
    local lyr, err = getLayerById(moho, layerId)
    if not lyr then return nil, err end

    -- ParticleLayer extends GroupLayer; check the LT_PARTICLE constant.
    local isParticle = false
    pcall(function()
        local M = MOHO or (LM and LM.MOHO)
        if M and lyr:LayerType() == M.LT_PARTICLE then isParticle = true end
    end)
    if not isParticle then
        return nil, "Layer " .. tostring(layerId) .. " is not a particle layer"
    end

    local ok, pLyr = pcall(function() return moho:LayerAsParticle(lyr) end)
    if not ok or not pLyr then
        return nil, "Failed to cast layer to particle layer"
    end
    return pLyr, nil, lyr
end

--- Configure the particle emitter on a particle layer.
-- All settings are optional; only the supplied ones are applied. After applying,
-- the handler calls FinalizeSettings() per the ParticleLayer docs.
-- Per the ParticleLayer API:
--   SetNumParticles(num, displayNum)
--   SetLifetime(lifetime)        -- frames
--   SetVelocity(v, spread)       -- real
--   SetDirection(angle, spread)  -- radians
--   SetAcceleration(angle, rate) -- radians, real
--   SetDamping(d), SetEvenlySpaced(b), SetOrientation(b),
--   SetFreeFloating(b), SetFullSpeedStart(b), SetRandomStartTime(b),
--   SetSourceDimensions(Vector3), SetRandomSeed(seed)
function particle.setEmitter(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local pLyr, err, baseLyr = getParticleLayer(moho, params.layerId)
    if not pLyr then return nil, err end

    moho.document:PrepUndo(baseLyr)

    local changed = {}

    if params.numParticles ~= nil then
        local display = params.displayNumParticles or params.numParticles
        local ok = pcall(function() pLyr:SetNumParticles(params.numParticles, display) end)
        if ok then
            changed.numParticles = params.numParticles
            changed.displayNumParticles = display
        end
    end

    if params.lifetime ~= nil then
        local ok = pcall(function() pLyr:SetLifetime(params.lifetime) end)
        if ok then changed.lifetime = params.lifetime end
    end

    if params.velocity ~= nil then
        local spread = params.velocitySpread or 0
        local ok = pcall(function() pLyr:SetVelocity(params.velocity, spread) end)
        if ok then
            changed.velocity = params.velocity
            changed.velocitySpread = spread
        end
    end

    if params.directionAngle ~= nil then
        local spread = params.directionSpread or 0
        local ok = pcall(function() pLyr:SetDirection(params.directionAngle, spread) end)
        if ok then
            changed.directionAngle = params.directionAngle
            changed.directionSpread = spread
        end
    end

    if params.accelerationAngle ~= nil or params.accelerationRate ~= nil then
        local angle = params.accelerationAngle or 0
        local rate = params.accelerationRate or 0
        local ok = pcall(function() pLyr:SetAcceleration(angle, rate) end)
        if ok then
            changed.accelerationAngle = angle
            changed.accelerationRate = rate
        end
    end

    if params.damping ~= nil then
        pcall(function() pLyr:SetDamping(params.damping) end)
        changed.damping = params.damping
    end
    if params.evenlySpaced ~= nil then
        pcall(function() pLyr:SetEvenlySpaced(params.evenlySpaced == true) end)
        changed.evenlySpaced = params.evenlySpaced == true
    end
    if params.orientation ~= nil then
        pcall(function() pLyr:SetOrientation(params.orientation == true) end)
        changed.orientation = params.orientation == true
    end
    if params.freeFloating ~= nil then
        pcall(function() pLyr:SetFreeFloating(params.freeFloating == true) end)
        changed.freeFloating = params.freeFloating == true
    end
    if params.fullSpeedStart ~= nil then
        pcall(function() pLyr:SetFullSpeedStart(params.fullSpeedStart == true) end)
        changed.fullSpeedStart = params.fullSpeedStart == true
    end
    if params.randomStartTime ~= nil then
        pcall(function() pLyr:SetRandomStartTime(params.randomStartTime == true) end)
        changed.randomStartTime = params.randomStartTime == true
    end

    if params.sourceWidth ~= nil or params.sourceHeight ~= nil or params.sourceDepth ~= nil then
        local ok = pcall(function()
            local cur = pLyr:SourceDimensions()
            local v = LM.Vector3:new_local()
            v.x = params.sourceWidth or (cur and cur.x) or 0
            v.y = params.sourceHeight or (cur and cur.y) or 0
            v.z = params.sourceDepth or (cur and cur.z) or 0
            pLyr:SetSourceDimensions(v)
        end)
        if ok then
            changed.sourceWidth = params.sourceWidth
            changed.sourceHeight = params.sourceHeight
            changed.sourceDepth = params.sourceDepth
        end
    end

    if params.randomSeed ~= nil then
        pcall(function() pLyr:SetRandomSeed(params.randomSeed) end)
        changed.randomSeed = params.randomSeed
    end

    -- Per the ParticleLayer docs: FinalizeSettings must be called after parameter
    -- changes for them to take effect.
    pcall(function() pLyr:FinalizeSettings() end)

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        changed = changed,
    }
end

return particle
