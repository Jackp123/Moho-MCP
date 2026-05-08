-- switch.lua
-- Tool handlers for SwitchLayer (Moho's mechanism for swapping which sub-layer
-- is visible per frame — used for lip-sync visemes, frame-by-frame mouth shapes,
-- and any other "swap art per frame" workflow).

local switch = {}

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

--- Cast a layer to a SwitchLayer, validating type first.
-- SwitchLayer extends GroupLayer; check the LT_SWITCH constant.
local function getSwitchLayer(moho, layerId)
    local lyr, err = getLayerById(moho, layerId)
    if not lyr then return nil, err end

    local isSwitch = false
    pcall(function()
        local M = MOHO or (LM and LM.MOHO)
        if M and lyr:LayerType() == M.LT_SWITCH then isSwitch = true end
    end)
    if not isSwitch then
        return nil, "Layer " .. tostring(layerId) .. " is not a switch layer"
    end

    local ok, sLyr = pcall(function() return moho:LayerAsSwitch(lyr) end)
    if not ok or not sLyr then
        return nil, "Failed to cast layer to switch layer"
    end
    return sLyr, nil, lyr
end

--- Resolve a child reference (name or index) to a child name string.
-- SwitchLayer:SetValue takes a string name, so a numeric index gets translated
-- through the GroupLayer:Layer(id):Name() chain.
local function resolveChildName(moho, switchLyr, baseLyr, childName, childIndex)
    if type(childName) == "string" and childName ~= "" then
        return childName
    end
    if type(childIndex) ~= "number" then
        return nil, "Provide childName (string) or childIndex (number)"
    end

    -- SwitchLayer extends GroupLayer, so we cast and use Layer(id):Name().
    local gOk, group = pcall(function() return moho:LayerAsGroup(baseLyr) end)
    if not gOk or not group then
        return nil, "Failed to cast switch layer to group"
    end

    local count = 0
    pcall(function() count = group:CountLayers() end)
    if childIndex < 0 or childIndex >= count then
        return nil, "childIndex out of range (0.." .. tostring(count - 1) .. ")"
    end

    local cOk, child = pcall(function() return group:Layer(childIndex) end)
    if not cOk or not child then
        return nil, "Failed to access child at index " .. tostring(childIndex)
    end

    local nOk, name = pcall(function() return child:Name() end)
    if not nOk or not name then
        return nil, "Failed to read child name at index " .. tostring(childIndex)
    end
    return name
end

--- Set the visible child of a switch layer at a given frame.
-- Per the SwitchLayer docs: SetValue(frame, value) where value is the child
-- layer's name (string). Pass either childName or childIndex.
-- @param params  layerId, frame. Provide childName (string) OR childIndex (number).
function switch.setActive(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end

    local sLyr, err, baseLyr = getSwitchLayer(moho, params.layerId)
    if not sLyr then return nil, err end

    local childName, resolveErr = resolveChildName(
        moho, sLyr, baseLyr, params.childName, params.childIndex)
    if not childName then return nil, resolveErr end

    moho.document:PrepUndo(baseLyr)
    local ok, setErr = pcall(function() sLyr:SetValue(params.frame, childName) end)
    if not ok then
        return nil, "Failed to set switch value: " .. tostring(setErr)
    end
    moho.document:SetDirty()

    return {
        success    = true,
        layerId    = params.layerId,
        frame      = params.frame,
        childName  = childName,
    }
end

--- Read the active child of a switch layer at a given frame.
-- @param params  layerId. Optional: frame (default = moho.frame).
function switch.getActive(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local sLyr, err = getSwitchLayer(moho, params.layerId)
    if not sLyr then return nil, err end

    local frame = params.frame
    if frame == nil then
        frame = 0
        pcall(function() frame = moho.frame end)
    end

    local childName = ""
    local ok, getErr = pcall(function() childName = sLyr:GetValue(frame) end)
    if not ok then
        return nil, "Failed to read switch value: " .. tostring(getErr)
    end

    -- Whether sub-layer interpolation is on (for lip-sync smoothing).
    local interp = false
    pcall(function() interp = sLyr:InterpMode() end)
    -- Whether this switch is in frame-by-frame mode.
    local fbf = false
    pcall(function() fbf = sLyr:IsFBFLayer() end)
    -- Lip-sync presence.
    local hasVisemes = false
    pcall(function() hasVisemes = sLyr:ContainsVisemes() end)

    return {
        layerId       = params.layerId,
        frame         = frame,
        childName     = childName or "",
        interpMode    = interp == true,
        isFrameByFrame = fbf == true,
        containsVisemes = hasVisemes == true,
    }
end

return switch
