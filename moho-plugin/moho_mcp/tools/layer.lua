-- layer.lua
-- Tool handlers for querying individual layer properties in Moho.
-- Returns a table of handler functions that accept (moho, params) and return
-- a result table on success, or nil + errorMessage on failure.

local layer = {}

-- Map numeric layer type constants to human-readable strings.
local LAYER_TYPE_NAMES = {}
local function initLayerTypeNames()
    if next(LAYER_TYPE_NAMES) ~= nil then
        return
    end
    -- Try MOHO global first, then LM.MOHO
    local M = nil
    pcall(function() M = MOHO end)
    if not M then
        pcall(function() M = LM.MOHO end)
    end
    if M then
        pcall(function() LAYER_TYPE_NAMES[M.LT_VECTOR]   = "vector" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_BONE]     = "bone" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_GROUP]    = "group" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_IMAGE]    = "image" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_AUDIO]    = "audio" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_SWITCH]   = "switch" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_PARTICLE] = "particle" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_NOTE]     = "note" end)
        pcall(function() LAYER_TYPE_NAMES[M.LT_PATCH]    = "patch" end)
    end
end

local function layerTypeName(layerType)
    initLayerTypeNames()
    return LAYER_TYPE_NAMES[layerType] or "unknown"
end

--- Safely retrieve a layer by its absolute ID.
-- @param moho  The global ScriptInterface object
-- @param layerId number  The absolute layer ID
-- @return userdata|nil  The layer object, or nil
-- @return string|nil  An error message on failure
local function getLayerById(moho, layerId)
    if not moho or not moho.document then
        return nil, "No active document"
    end

    if type(layerId) ~= "number" then
        return nil, "layerId must be a number"
    end

    local ok, lyr = pcall(function()
        return moho.document:LayerByAbsoluteID(layerId)
    end)

    if not ok or not lyr then
        return nil, "Layer not found with absolute ID " .. tostring(layerId)
    end

    return lyr
end

--- Convert an LM.Vector2 (or similar) to a plain {x, y} table.
-- Falls back gracefully if the value is not a vector.
local function vec2table(v)
    if v == nil then
        return { x = 0, y = 0 }
    end
    local ok, x, y = pcall(function() return v.x, v.y end)
    if ok then
        return { x = x or 0, y = y or 0 }
    end
    return { x = 0, y = 0 }
end

--- Read the static transform properties of a layer.
-- Wraps each accessor in pcall so a missing channel does not abort everything.
-- Note: fTranslation and fScale are AnimVec3 channels per the MohoLayer docs,
-- so we read x/y/z and report all three.
local function readTransform(lyr, frame)
    local transform = {}
    frame = frame or 0

    -- Translation via fTranslation (AnimVec3)
    local tOk, tx, ty, tz = pcall(function()
        local val = lyr.fTranslation:GetValue(frame)
        return val.x, val.y, val.z
    end)
    if tOk then
        transform.translation = { x = tx, y = ty, z = tz or 0 }
    else
        transform.translation = { x = 0, y = 0, z = 0 }
    end

    -- Rotation via fRotationZ (AnimVal, radians)
    local rOk, rVal = pcall(function()
        return lyr.fRotationZ:GetValue(frame)
    end)
    transform.rotation = rOk and rVal or 0

    -- Scale via fScale (AnimVec3)
    local sOk, sx, sy, sz = pcall(function()
        local val = lyr.fScale:GetValue(frame)
        return val.x, val.y, val.z
    end)
    if sOk then
        transform.scale = { x = sx, y = sy, z = sz or 1 }
    else
        transform.scale = { x = 1, y = 1, z = 1 }
    end

    return transform
end

--- Get detailed properties of a single layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number)
-- @return table|nil  A table of layer properties on success
-- @return string|nil  An error message on failure
function layer.getProperties(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local result = {
        id      = params.layerId,
        name    = lyr:Name(),
        type    = layerTypeName(lyr:LayerType()),
        visible = lyr:IsVisible(),
        locked  = lyr:IsLocked(),
    }

    -- Opacity via fAlpha AnimVal channel
    local opOk, opacity = pcall(function()
        local frame = moho.document:CurrentFrame()
        return lyr.fAlpha:GetValue(frame)
    end)
    result.opacity = opOk and opacity or 1.0

    -- Blend mode
    local bmOk, blendMode = pcall(function() return lyr:BlendingMode() end)
    result.blendMode = bmOk and blendMode or 0

    -- Current frame for reading animated transform values
    local frame = 0
    local fOk, f = pcall(function() return moho.document:CurrentFrame() end)
    if fOk then frame = f end

    result.transform = readTransform(lyr, frame)

    -- Extras depending on type
    if lyr:IsGroupType() then
        local gOk, group = pcall(function() return moho:LayerAsGroup(lyr) end)
        if gOk and group then
            result.childCount = group:CountLayers()
        end
    end

    local lt = lyr:LayerType()
    initLayerTypeNames()
    if LAYER_TYPE_NAMES[lt] == "bone" then
        local bOk, boneLyr = pcall(function() return moho:LayerAsBone(lyr) end)
        if bOk and boneLyr then
            local skelOk, skel = pcall(function() return boneLyr:Skeleton() end)
            if skelOk and skel then
                result.boneCount = skel:CountBones()
            end
        end
    elseif LAYER_TYPE_NAMES[lt] == "vector" then
        local vOk, vecLyr = pcall(function() return moho:LayerAsVector(lyr) end)
        if vOk and vecLyr then
            local mOk, mesh = pcall(function() return vecLyr:Mesh() end)
            if mOk and mesh then
                result.pointCount = mesh:CountPoints()
                result.shapeCount = mesh:CountShapes()
            end
        end
    end

    return result
end

--- Get direct children of a group layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number) pointing to a group layer
-- @return table|nil  An array of child-layer summary tables on success
-- @return string|nil  An error message on failure
function layer.getChildren(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    if not lyr:IsGroupLayer() then
        return nil, "Layer " .. tostring(params.layerId) .. " is not a group layer"
    end

    local gOk, group = pcall(function() return moho:LayerAsGroup(lyr) end)
    if not gOk or not group then
        return nil, "Failed to cast layer to group: " .. tostring(group)
    end

    local children = {}
    local count = group:CountLayers()

    for i = 0, count - 1 do
        local cOk, child = pcall(function() return group:Layer(i) end)
        if cOk and child then
            children[#children + 1] = {
                id      = moho.document:LayerAbsoluteID(child),
                name    = child:Name(),
                type    = layerTypeName(child:LayerType()),
                visible = child:IsVisible(),
                locked  = child:IsLocked(),
                isGroup = child:IsGroupType(),
            }
        end
    end

    return children
end

--- Get all bones in a bone layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number) pointing to a bone layer
-- @return table|nil  An array of bone descriptor tables on success
-- @return string|nil  An error message on failure
function layer.getBones(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local isBoneOk, isBone = pcall(function() return lyr:IsBoneType() end)
    if not isBoneOk or not isBone then
        return nil, "Layer " .. tostring(params.layerId) .. " is not a bone layer"
    end

    local bOk, boneLyr = pcall(function() return moho:LayerAsBone(lyr) end)
    if not bOk or not boneLyr then
        return nil, "Failed to cast layer to bone layer: " .. tostring(boneLyr)
    end

    local skelOk, skel = pcall(function() return boneLyr:Skeleton() end)
    if not skelOk or not skel then
        return nil, "Failed to get skeleton: " .. tostring(skel)
    end

    local bones = {}
    local count = skel:CountBones()

    for i = 0, count - 1 do
        local ok, boneOrErr = pcall(function() return skel:Bone(i) end)
        if ok and boneOrErr then
            local b = boneOrErr
            local entry = {
                id       = i,
                name     = b:Name(),
                position = vec2table(b.fPos),
                angle    = b.fAngle or 0,
                scale    = b.fScale or 1,
                length   = b.fLength or 0,
                parentId = b.fParent or -1,
                selected = b.fSelected or false,
            }
            bones[#bones + 1] = entry
        end
    end

    return bones
end

--- Set the transform of a layer at a specific frame.
-- All transform parameters are optional; only supplied values are applied.
-- Note: fTranslation and fScale are AnimVec3 channels per the MohoLayer docs,
-- so we use LM.Vector3 (not Vector2) and preserve the existing z component.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId, frame.
--   Optional: transX, transY, transZ, rotation, scaleX, scaleY, scaleZ
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.setTransform(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local frame = params.frame
    moho.document:PrepUndo(lyr)

    local changed = {}

    -- Translation (AnimVec3 — preserve z when only x/y are supplied)
    if params.transX ~= nil or params.transY ~= nil or params.transZ ~= nil then
        local ok, setErr = pcall(function()
            local cur = lyr.fTranslation:GetValue(frame)
            local vec = LM.Vector3:new_local()
            vec.x = params.transX or cur.x
            vec.y = params.transY or cur.y
            vec.z = params.transZ or cur.z
            lyr.fTranslation:SetValue(frame, vec)
        end)
        if ok then
            changed.transX = params.transX
            changed.transY = params.transY
            changed.transZ = params.transZ
        else
            return nil, "Failed to set translation: " .. tostring(setErr)
        end
    end

    -- Rotation (radians)
    if params.rotation ~= nil then
        local ok, setErr = pcall(function()
            lyr.fRotationZ:SetValue(frame, params.rotation)
        end)
        if ok then
            changed.rotation = params.rotation
        else
            return nil, "Failed to set rotation: " .. tostring(setErr)
        end
    end

    -- Scale (AnimVec3 — preserve z when only x/y are supplied)
    if params.scaleX ~= nil or params.scaleY ~= nil or params.scaleZ ~= nil then
        local ok, setErr = pcall(function()
            local cur = lyr.fScale:GetValue(frame)
            local vec = LM.Vector3:new_local()
            vec.x = params.scaleX or cur.x
            vec.y = params.scaleY or cur.y
            vec.z = params.scaleZ or cur.z
            lyr.fScale:SetValue(frame, vec)
        end)
        if ok then
            changed.scaleX = params.scaleX
            changed.scaleY = params.scaleY
            changed.scaleZ = params.scaleZ
        else
            return nil, "Failed to set scale: " .. tostring(setErr)
        end
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        frame   = frame,
        changed = changed,
    }
end

--- Set visibility of a layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId and visible (boolean)
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.setVisibility(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.visible == nil then
        return nil, "Missing required parameter: visible"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    moho.document:PrepUndo(lyr)

    local ok, setErr = pcall(function()
        lyr:SetVisible(params.visible == true)
    end)

    if not ok then
        return nil, "Failed to set visibility: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        visible = params.visible == true,
    }
end

--- Set opacity of a layer at a specific frame.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId, frame, opacity (0.0 to 1.0)
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.setOpacity(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.frame == nil then
        return nil, "Missing required parameter: frame"
    end
    if params.opacity == nil then
        return nil, "Missing required parameter: opacity"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    moho.document:PrepUndo(lyr)

    local ok, setErr = pcall(function()
        lyr.fAlpha:SetValue(params.frame, params.opacity)
    end)

    if not ok then
        return nil, "Failed to set opacity: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        frame   = params.frame,
        opacity = params.opacity,
    }
end

--- Rename a layer.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId and name (string)
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.setName(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.name) ~= "string" then
        return nil, "Missing required parameter: name (string)"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    moho.document:PrepUndo(lyr)

    local ok, setErr = pcall(function()
        lyr:SetName(params.name)
    end)

    if not ok then
        return nil, "Failed to set name: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        name    = params.name,
    }
end

--- Look up the numeric LayerType constant for a string layer type.
-- Accepts "vector", "group", "bone", "image", "switch", "particle", "note", "patch", "audio".
-- @return number|nil  The numeric constant
-- @return string|nil  Error message on failure
local function resolveLayerTypeConstant(typeName)
    initLayerTypeNames()
    if type(typeName) ~= "string" then
        return nil, "type must be a string"
    end
    local lower = typeName:lower()
    local M = nil
    pcall(function() M = MOHO end)
    if not M then pcall(function() M = LM.MOHO end) end
    if not M then return nil, "MOHO API not available" end

    local map = {
        vector   = "LT_VECTOR",
        group    = "LT_GROUP",
        bone     = "LT_BONE",
        image    = "LT_IMAGE",
        switch   = "LT_SWITCH",
        particle = "LT_PARTICLE",
        note     = "LT_NOTE",
        patch    = "LT_PATCH",
        audio    = "LT_AUDIO",
    }
    local field = map[lower]
    if not field then
        return nil, "Unknown layer type: " .. typeName
    end
    local constant = M[field]
    if constant == nil then
        return nil, "MOHO does not expose " .. field
    end
    return constant
end

--- Create a new layer in the document.
-- Per the ScriptInterface docs:
--   moho:CreateNewLayer(layerType, undoable)            — creates the new layer
--   moho:PlaceLayerInGroup(child, group, top, isUndoable) — moves it into a group
-- @param params table  Required: type (string).
--   Optional: name (string), parentId (number — absolute ID of a group layer to nest into).
-- @return table|nil  { success, layerId, name, type } on success
-- @return string|nil  Error message on failure
function layer.createLayer(moho, params)
    if not moho or not moho.document then
        return nil, "No active document"
    end
    if not params or params.type == nil then
        return nil, "Missing required parameter: type"
    end

    local typeConst, typeErr = resolveLayerTypeConstant(params.type)
    if not typeConst then
        return nil, typeErr
    end

    -- Resolve parent group up front so we can fail fast on a bad parentId.
    local parentGroup = nil
    if params.parentId ~= nil then
        if type(params.parentId) ~= "number" then
            return nil, "parentId must be a number"
        end
        local parentLyr, perr = getLayerById(moho, params.parentId)
        if not parentLyr then
            return nil, perr
        end
        if not parentLyr:IsGroupType() then
            return nil, "parentId " .. tostring(params.parentId) .. " is not a group layer"
        end
        local gOk, group = pcall(function() return moho:LayerAsGroup(parentLyr) end)
        if not gOk or not group then
            return nil, "Failed to cast parent layer to group"
        end
        parentGroup = group
    end

    -- Per docs: moho:CreateNewLayer(layerType, undoable). Pass undoable=true so
    -- the user can Ctrl-Z this in MOHO.
    local newLayer = nil
    local createOk, createErr = pcall(function()
        newLayer = moho:CreateNewLayer(typeConst, true)
    end)

    if not createOk or not newLayer then
        return nil, "Failed to create layer: " .. tostring(createErr)
    end

    -- Move into the parent group if one was specified.
    if parentGroup ~= nil then
        pcall(function()
            -- moho:PlaceLayerInGroup(child, group, top, isUndoable)
            moho:PlaceLayerInGroup(newLayer, parentGroup, true, true)
        end)
    end

    if params.name ~= nil then
        if type(params.name) ~= "string" then
            return nil, "name must be a string"
        end
        pcall(function() newLayer:SetName(params.name) end)
    end

    moho.document:SetDirty()

    local newId = -1
    pcall(function() newId = moho.document:LayerAbsoluteID(newLayer) end)

    return {
        success  = true,
        layerId  = newId,
        name     = newLayer:Name(),
        type     = layerTypeName(newLayer:LayerType()),
        parentId = params.parentId or -1,
    }
end

--- Delete a layer from the document.
-- Per the ScriptInterface docs: moho:DeleteLayer(layer).
-- @param params table  Must contain layerId (number)
function layer.deleteLayer(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    moho.document:PrepUndo(lyr)

    local ok, delErr = pcall(function()
        moho:DeleteLayer(lyr)
    end)

    if not ok then
        return nil, "Failed to delete layer: " .. tostring(delErr)
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
    }
end

--- Select a layer in the UI.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain layerId
-- @return table|nil  Confirmation on success
-- @return string|nil  An error message on failure
function layer.selectLayer(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local ok, selErr = pcall(function()
        moho:SetSelLayer(lyr)
    end)

    if not ok then
        return nil, "Failed to select layer: " .. tostring(selErr)
    end

    return {
        success = true,
        layerId = params.layerId,
        name    = lyr:Name(),
    }
end

--- Set the controlling parent bone for a layer.
-- Per the MohoLayer docs: SetLayerParentBone(id). Pass -1 to clear.
function layer.setParentBone(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.boneId) ~= "number" then
        return nil, "boneId must be a number (-1 to clear)"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    moho.document:PrepUndo(lyr)
    local ok, setErr = pcall(function() lyr:SetLayerParentBone(params.boneId) end)
    if not ok then
        return nil, "Failed to set parent bone: " .. tostring(setErr)
    end
    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        boneId  = params.boneId,
    }
end

--- Move a layer into a group.
-- Per the ScriptInterface docs: PlaceLayerInGroup(child, group, top, isUndoable).
-- @param params  layerId, parentGroupId. Optional: top (default false).
function layer.placeInGroup(moho, params)
    if not params or params.layerId == nil or params.parentGroupId == nil then
        return nil, "Missing required parameter: layerId and parentGroupId"
    end

    local child, err = getLayerById(moho, params.layerId)
    if not child then
        return nil, err
    end

    local parent, perr = getLayerById(moho, params.parentGroupId)
    if not parent then
        return nil, perr
    end
    if not parent:IsGroupType() then
        return nil, "parentGroupId is not a group layer"
    end

    local gOk, parentGroup = pcall(function() return moho:LayerAsGroup(parent) end)
    if not gOk or not parentGroup then
        return nil, "Failed to cast parent layer to group"
    end

    moho.document:PrepUndo(child)
    local ok, setErr = pcall(function()
        moho:PlaceLayerInGroup(child, parentGroup, params.top == true, true)
    end)
    if not ok then
        return nil, "Failed to place layer in group: " .. tostring(setErr)
    end
    moho.document:SetDirty()

    return {
        success       = true,
        layerId       = params.layerId,
        parentGroupId = params.parentGroupId,
        top           = params.top == true,
    }
end

--- Reorder a layer behind another.
-- Per the ScriptInterface docs: PlaceLayerBehindAnother(moveLayer, behindThis).
function layer.placeBehind(moho, params)
    if not params or params.layerId == nil or params.behindLayerId == nil then
        return nil, "Missing required parameter: layerId and behindLayerId"
    end

    local mover, err = getLayerById(moho, params.layerId)
    if not mover then
        return nil, err
    end
    local pivot, perr = getLayerById(moho, params.behindLayerId)
    if not pivot then
        return nil, perr
    end

    moho.document:PrepUndo(mover)
    local ok, setErr = pcall(function()
        moho:PlaceLayerBehindAnother(mover, pivot)
    end)
    if not ok then
        return nil, "Failed to reorder layer: " .. tostring(setErr)
    end
    moho.document:SetDirty()

    return {
        success        = true,
        layerId        = params.layerId,
        behindLayerId  = params.behindLayerId,
    }
end

--- Activate (or deactivate) an action on a layer for editing.
-- Per the MohoLayer docs: ActivateAction(name). Pass an empty string to return
-- to the mainline timeline. Any keyframes set while an action is active are
-- stored in that action — this is how smart bone dials are recorded.
function layer.activateAction(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.actionName ~= nil and type(params.actionName) ~= "string" then
        return nil, "actionName must be a string (or omit / pass \"\" for mainline)"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local actionName = params.actionName or ""
    local ok, setErr = pcall(function() lyr:ActivateAction(actionName) end)
    if not ok then
        return nil, "Failed to activate action: " .. tostring(setErr)
    end

    local current = ""
    pcall(function() current = lyr:CurrentAction() end)

    return {
        success       = true,
        layerId       = params.layerId,
        currentAction = current,
    }
end

--- List all actions on a layer.
function layer.listActions(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then
        return nil, err
    end

    local count = 0
    pcall(function() count = lyr:CountActions() end)

    local actions = {}
    for i = 0, count - 1 do
        local nameOk, name = pcall(function() return lyr:ActionName(i) end)
        if nameOk and name then
            local isSmart = false
            pcall(function() isSmart = lyr:IsSmartBoneAction(name) end)
            local duration = 0
            pcall(function() duration = lyr:ActionDuration(name) end)
            actions[#actions + 1] = {
                index        = i,
                name         = name,
                isSmartBone  = isSmart,
                duration     = duration,
            }
        end
    end

    local current = ""
    pcall(function() current = lyr:CurrentAction() end)

    return {
        layerId       = params.layerId,
        actionCount   = count,
        currentAction = current,
        actions       = actions,
    }
end

--- Helper: parse #RRGGBB or #RRGGBBAA into an LM.ColorVector.
local function makeColorVector(hex)
    hex = hex:gsub("^#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    local a = 255
    if #hex >= 8 then a = tonumber(hex:sub(7, 8), 16) or 255 end
    local col = LM.ColorVector:new_local()
    col:Set(r / 255, g / 255, b / 255, a / 255)
    return col
end

--- Set a layer's blur amount at a specific frame.
-- fBlur on MohoLayer is an AnimVal channel.
function layer.setBlur(moho, params)
    if not params or params.layerId == nil or params.frame == nil or params.amount == nil then
        return nil, "Missing required parameter: layerId, frame, amount"
    end
    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then return nil, err end

    moho.document:PrepUndo(lyr)
    local ok, setErr = pcall(function() lyr.fBlur:SetValue(params.frame, params.amount) end)
    if not ok then
        return nil, "Failed to set blur: " .. tostring(setErr)
    end
    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        frame   = params.frame,
        amount  = params.amount,
    }
end

--- Set a layer's drop shadow at a specific frame.
-- fShadowOffset / fShadowBlur / fShadowAngle are AnimVal; fShadowColor is AnimColor.
-- All component params are optional. Pass enabled=true/false to toggle the
-- non-animated fLayerShadow channel.
function layer.setShadow(moho, params)
    if not params or params.layerId == nil or params.frame == nil then
        return nil, "Missing required parameter: layerId, frame"
    end
    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then return nil, err end

    moho.document:PrepUndo(lyr)
    local frame = params.frame
    local changed = {}

    if params.enabled ~= nil then
        pcall(function() lyr.fLayerShadow:SetValue(frame, params.enabled == true) end)
        changed.enabled = params.enabled == true
    end
    if params.offset ~= nil then
        pcall(function() lyr.fShadowOffset:SetValue(frame, params.offset) end)
        changed.offset = params.offset
    end
    if params.blur ~= nil then
        pcall(function() lyr.fShadowBlur:SetValue(frame, params.blur) end)
        changed.blur = params.blur
    end
    if params.angle ~= nil then
        pcall(function() lyr.fShadowAngle:SetValue(frame, params.angle) end)
        changed.angle = params.angle
    end
    if params.color ~= nil and type(params.color) == "string" then
        pcall(function() lyr.fShadowColor:SetValue(frame, makeColorVector(params.color)) end)
        changed.color = params.color
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        frame   = frame,
        changed = changed,
    }
end

--- Set a layer's outline at a specific frame.
-- fOutlineWidth is AnimVal, fOutlineColor is AnimColor; fLayerOutline is the
-- non-animated on/off toggle.
function layer.setOutline(moho, params)
    if not params or params.layerId == nil or params.frame == nil then
        return nil, "Missing required parameter: layerId, frame"
    end
    local lyr, err = getLayerById(moho, params.layerId)
    if not lyr then return nil, err end

    moho.document:PrepUndo(lyr)
    local frame = params.frame
    local changed = {}

    if params.enabled ~= nil then
        pcall(function() lyr.fLayerOutline:SetValue(frame, params.enabled == true) end)
        changed.enabled = params.enabled == true
    end
    if params.width ~= nil then
        pcall(function() lyr.fOutlineWidth:SetValue(frame, params.width) end)
        changed.width = params.width
    end
    if params.color ~= nil and type(params.color) == "string" then
        pcall(function() lyr.fOutlineColor:SetValue(frame, makeColorVector(params.color)) end)
        changed.color = params.color
    end

    moho.document:SetDirty()

    return {
        success = true,
        layerId = params.layerId,
        frame   = frame,
        changed = changed,
    }
end

return layer
