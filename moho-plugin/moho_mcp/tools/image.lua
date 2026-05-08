-- image.lua
-- Tool handlers for ImageLayer source image management.
-- ImageLayer extends AudioLayer extends MohoLayer. Per the docs:
--   ImageLayer:SetSourceImage(path) → void
--   ImageLayer:SourceImage(outAccess) → char  (file path)

local image = {}

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

--- Cast a layer to an ImageLayer, validating type first.
local function getImageLayer(moho, layerId)
    local lyr, err = getLayerById(moho, layerId)
    if not lyr then return nil, err end

    local isImage = false
    pcall(function()
        local M = MOHO or (LM and LM.MOHO)
        if M and lyr:LayerType() == M.LT_IMAGE then isImage = true end
    end)
    if not isImage then
        return nil, "Layer " .. tostring(layerId) .. " is not an image layer"
    end

    local ok, iLyr = pcall(function() return moho:LayerAsImage(lyr) end)
    if not ok or not iLyr then
        return nil, "Failed to cast layer to image layer"
    end
    return iLyr, nil, lyr
end

--- Set the source image file on an image layer.
-- Useful for placing pre-drawn art into scenes after layer.createLayer.
-- @param params  layerId, filePath (string).
function image.setSource(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.filePath) ~= "string" or params.filePath == "" then
        return nil, "Missing required parameter: filePath (string)"
    end

    local iLyr, err, baseLyr = getImageLayer(moho, params.layerId)
    if not iLyr then return nil, err end

    moho.document:PrepUndo(baseLyr)
    local ok, setErr = pcall(function() iLyr:SetSourceImage(params.filePath) end)
    if not ok then
        return nil, "Failed to set source image: " .. tostring(setErr)
    end
    moho.document:SetDirty()

    -- Read back the actual stored path to confirm.
    local actualPath = ""
    pcall(function() actualPath = iLyr:SourceImage() end)

    return {
        success  = true,
        layerId  = params.layerId,
        filePath = actualPath ~= "" and actualPath or params.filePath,
    }
end

--- Read the source image path of an image layer.
-- Plus useful metadata (pixel dimensions, movie/PSD/sequence flags) when available.
function image.getSource(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local iLyr, err = getImageLayer(moho, params.layerId)
    if not iLyr then return nil, err end

    local result = { layerId = params.layerId }

    pcall(function() result.filePath = iLyr:SourceImage() end)
    pcall(function() result.pixelWidth = iLyr:PixelWidth() end)
    pcall(function() result.pixelHeight = iLyr:PixelHeight() end)
    pcall(function() result.isMovie = iLyr:IsMovieLayer() end)
    pcall(function() result.isImageSequence = iLyr:IsImageSequenceLayer() end)
    pcall(function() result.isPSD = iLyr:IsPSDImage() end)

    return result
end

return image
