-- mesh.lua
-- Tool handlers for querying mesh (vector layer) data in Moho.
-- Returns a table of handler functions that accept (moho, params) and return
-- a result table on success, or nil + errorMessage on failure.

local mesh = {}

--- Safely retrieve a layer by its absolute ID.
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

--- Retrieve the mesh object from a vector layer.
-- Validates the layer type and casts it before accessing the mesh.
-- @param moho  The global ScriptInterface object
-- @param layerId number  Absolute layer ID
-- @return userdata|nil  The mesh object
-- @return userdata|nil  The vector layer object
-- @return string|nil  An error message on failure
local function getMesh(moho, layerId)
    local lyr, err = getLayerById(moho, layerId)
    if not lyr then
        return nil, nil, err
    end

    -- Verify this is a vector layer
    -- No IsVectorType() method exists, so compare LayerType() against known constant
    local ltOk, lt = pcall(function() return lyr:LayerType() end)
    if not ltOk then
        return nil, nil, "Failed to read layer type"
    end

    local isVector = false
    pcall(function()
        local M = MOHO or (LM and LM.MOHO)
        if M and lt == M.LT_VECTOR then isVector = true end
    end)
    if not isVector then
        return nil, nil, "Layer " .. tostring(layerId) .. " is not a vector layer"
    end

    -- Cast to vector layer
    local vOk, vecLyr = pcall(function() return moho:LayerAsVector(lyr) end)
    if not vOk or not vecLyr then
        return nil, nil, "Failed to cast layer to vector layer"
    end

    -- Get mesh from the vector layer
    local mOk, meshObj = pcall(function() return vecLyr:Mesh() end)
    if not mOk or not meshObj then
        return nil, nil, "Failed to get mesh from vector layer"
    end

    return meshObj, vecLyr
end

--- Convert an LM.Vector2 (userdata) to a plain table with numeric values.
local function vec2table(v)
    if v == nil then
        return { x = 0, y = 0 }
    end
    local ok, x, y = pcall(function() return tonumber(v.x) or 0, tonumber(v.y) or 0 end)
    if ok then
        return { x = x, y = y }
    end
    return { x = 0, y = 0 }
end

--- Convert a Moho color value to a hex string.
-- Moho colors can be various types (userdata); this attempts a safe conversion.
local function colorToHex(color)
    if color == nil then
        return nil
    end

    -- Try reading r, g, b, a — force to numbers since MOHO may return userdata
    local ok, r, g, b, a = pcall(function()
        return tonumber(color.r), tonumber(color.g), tonumber(color.b), tonumber(color.a)
    end)

    if not ok or not r or not g or not b then
        return nil
    end

    -- If values are floats 0.0-1.0, scale to 0-255
    if r <= 1.0 and g <= 1.0 and b <= 1.0 then
        r = math.floor(r * 255 + 0.5)
        g = math.floor(g * 255 + 0.5)
        b = math.floor(b * 255 + 0.5)
        if a then
            a = math.floor(a * 255 + 0.5)
        end
    end

    if a and a < 255 then
        return string.format("#%02X%02X%02X%02X", r, g, b, a)
    else
        return string.format("#%02X%02X%02X", r, g, b)
    end
end

--- Get all points in a vector layer's mesh.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number)
-- @return table|nil  A result table containing the points array
-- @return string|nil  An error message on failure
function mesh.getPoints(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local countOk, pointCount = pcall(function() return meshObj:CountPoints() end)
    if not countOk then
        return nil, "Failed to count points: " .. tostring(pointCount)
    end

    local points = {}

    for i = 0, pointCount - 1 do
        local pOk, pt = pcall(function() return meshObj:Point(i) end)
        if pOk and pt then
            local entry = {
                index    = i,
                position = vec2table(pt.fPos),
            }

            -- Selection state
            local selOk, sel = pcall(function() return pt.fSelected end)
            entry.selected = selOk and sel or false

            points[#points + 1] = entry
        end
    end

    return {
        layerId    = params.layerId,
        pointCount = pointCount,
        points     = points,
    }
end

--- Get all shapes in a vector layer's mesh.
-- @param moho  The global ScriptInterface object
-- @param params table  Must contain params.layerId (number)
-- @return table|nil  A result table containing the shapes array
-- @return string|nil  An error message on failure
function mesh.getShapes(moho, params)
    if not params then
        return nil, "Missing parameters"
    end
    if params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local countOk, shapeCount = pcall(function() return meshObj:CountShapes() end)
    if not countOk then
        return nil, "Failed to count shapes: " .. tostring(shapeCount)
    end

    local shapes = {}

    for i = 0, shapeCount - 1 do
        local sOk, shape = pcall(function() return meshObj:Shape(i) end)
        if sOk and shape then
            local entry = {
                index = i,
            }

            -- Shape name
            local nOk, name = pcall(function() return shape:Name() end)
            entry.name = nOk and name or ""

            -- Edge count
            local eOk, edgeCount = pcall(function() return shape:CountEdges() end)
            entry.edgeCount = eOk and edgeCount or 0

            -- Fill color
            local fillOk, fillColor = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fFillCol
                end
                return nil
            end)
            if fillOk and fillColor then
                entry.fillColor = colorToHex(fillColor)
            end

            -- Stroke color
            local strokeOk, strokeColor = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fLineCol
                end
                return nil
            end)
            if strokeOk and strokeColor then
                entry.strokeColor = colorToHex(strokeColor)
            end

            -- Stroke width
            local swOk, strokeWidth = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fLineWidth
                end
                return nil
            end)
            if swOk and strokeWidth then
                entry.strokeWidth = tonumber(strokeWidth) or 0
            end

            -- Whether the shape is filled / has a stroke
            local hasFillOk, hasFill = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fHasFill
                end
                return nil
            end)
            if hasFillOk and hasFill ~= nil then
                entry.hasFill = hasFill
            end

            local hasStrokeOk, hasStroke = pcall(function()
                local style = shape.fMyStyle
                if style then
                    return style.fHasLine
                end
                return nil
            end)
            if hasStrokeOk and hasStroke ~= nil then
                entry.hasStroke = hasStroke
            end

            shapes[#shapes + 1] = entry
        end
    end

    return {
        layerId    = params.layerId,
        shapeCount = shapeCount,
        shapes     = shapes,
    }
end

--- Add a new point to a vector layer's mesh.
-- Per the M_Mesh API:
--   AddLonePoint(pos, frame)            — start a new disconnected point
--   AppendPoint(pos, frame)             — extend a curve from the last AddLonePoint/AppendPoint
--   AddPoint(pos, attachID, frame)      — connect to an existing point by ID
-- @param params table  Required: layerId, x, y.
--   Optional: frame (default 0), connectToPointId (number — connect to that point),
--   startNewCurve (boolean — force AddLonePoint even if mesh is non-empty).
function mesh.addPoint(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if params.x == nil or params.y == nil then
        return nil, "Missing required parameter: x and y"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local layer = getLayerById(moho, params.layerId)
    moho.document:PrepUndo(layer)

    local frame = params.frame or 0
    if type(frame) ~= "number" then
        return nil, "frame must be a number"
    end

    local before = 0
    pcall(function() before = meshObj:CountPoints() end)

    local mode = "lone"
    if params.connectToPointId ~= nil then
        if type(params.connectToPointId) ~= "number" then
            return nil, "connectToPointId must be a number"
        end
        if params.connectToPointId < 0 or params.connectToPointId >= before then
            return nil, "connectToPointId out of range"
        end
        mode = "attach"
    elseif params.startNewCurve == true or before == 0 then
        mode = "lone"
    else
        mode = "append"
    end

    local addOk, addErr = pcall(function()
        local vec = LM.Vector2:new_local()
        vec.x = params.x
        vec.y = params.y
        if mode == "attach" then
            meshObj:AddPoint(vec, params.connectToPointId, frame)
        elseif mode == "lone" then
            meshObj:AddLonePoint(vec, frame)
        else
            meshObj:AppendPoint(vec, frame)
        end
    end)

    if not addOk then
        return nil, "Failed to add point: " .. tostring(addErr)
    end

    local after = before
    pcall(function() after = meshObj:CountPoints() end)

    moho.document:SetDirty()

    return {
        success    = true,
        layerId    = params.layerId,
        pointIndex = after - 1,
        pointCount = after,
        position   = { x = params.x, y = params.y },
        mode       = mode,
    }
end

--- Create a shape from a list of point indices.
-- Per the ScriptInterface docs:
--   moho:CreateShape(filled, behindNeighborStrokes, frame,
--                    checkForBadShapes, skipDuplicateStrokes, skipFill, skipLine)
-- The "closed" concept isn't a parameter — closure is determined by the
-- selected points' geometry. `filled` controls whether the shape gets a fill;
-- `skipFill` / `skipLine` let callers create stroke-only or fill-only shapes.
-- Style fields:
--   fHasFill / fHasOutline   live on M_Shape (NOT on fMyStyle)
--   fFillCol / fLineCol      are AnimColor channels — set via :SetValue(frame, color)
--   fLineWidth               is a plain real on M_Style
-- @param params table  Required: layerId, pointIndices (array of >=2 indices).
--   Optional: frame, name, fillColor (#RRGGBB[AA]), strokeColor, strokeWidth,
--   filled (default true; pass false for stroke-only).
function mesh.createShape(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.pointIndices) ~= "table" or #params.pointIndices < 2 then
        return nil, "pointIndices must be an array of at least 2 point indices"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local layer = getLayerById(moho, params.layerId)
    moho.document:PrepUndo(layer)

    -- The vector layer must be active so CreateShape operates on its mesh.
    pcall(function() moho:SetSelLayer(layer) end)

    pcall(function() meshObj:SelectNone() end)

    local count = meshObj:CountPoints()
    for _, idx in ipairs(params.pointIndices) do
        if type(idx) ~= "number" or idx < 0 or idx >= count then
            return nil, "Point index out of range: " .. tostring(idx)
        end
        local pOk, pt = pcall(function() return meshObj:Point(idx) end)
        if not pOk or not pt then
            return nil, "Failed to access point " .. tostring(idx)
        end
        pcall(function() pt.fSelected = true end)
    end

    local frame = params.frame or 0
    local filled = (params.filled ~= false)
    local hasStroke = (params.strokeColor ~= nil or params.strokeWidth ~= nil)
    local skipFill = (params.fillColor == nil and not filled)
    local skipLine = not hasStroke and params.strokeColor == nil

    local beforeShapes = 0
    pcall(function() beforeShapes = meshObj:CountShapes() end)

    -- moho:CreateShape(filled, behindNeighborStrokes, frame, checkForBadShapes,
    --                  skipDuplicateStrokes, skipFill, skipLine)
    local createOk, createErr = pcall(function()
        moho:CreateShape(filled, false, frame, true, false, skipFill, skipLine)
    end)
    if not createOk then
        return nil, "Failed to create shape: " .. tostring(createErr)
    end

    local afterShapes = beforeShapes
    pcall(function() afterShapes = meshObj:CountShapes() end)

    if afterShapes <= beforeShapes then
        return nil, "Shape creation call succeeded but no new shape was added (check that points form a valid loop)"
    end

    local newIndex = afterShapes - 1

    local shape = nil
    pcall(function() shape = meshObj:Shape(newIndex) end)
    if shape then
        if params.name ~= nil and type(params.name) == "string" then
            pcall(function() shape:SetName(params.name) end)
        end

        local function makeColor(hex)
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

        if params.fillColor ~= nil and type(params.fillColor) == "string" then
            pcall(function()
                shape.fHasFill = true
                local style = shape.fMyStyle
                if style and style.fFillCol then
                    style.fFillCol:SetValue(frame, makeColor(params.fillColor))
                end
            end)
        end
        if params.strokeColor ~= nil and type(params.strokeColor) == "string" then
            pcall(function()
                shape.fHasOutline = true
                local style = shape.fMyStyle
                if style and style.fLineCol then
                    style.fLineCol:SetValue(frame, makeColor(params.strokeColor))
                end
            end)
        end
        if params.strokeWidth ~= nil and type(params.strokeWidth) == "number" then
            pcall(function()
                local style = shape.fMyStyle
                if style then style.fLineWidth = params.strokeWidth end
            end)
        end
    end

    moho.document:SetDirty()

    return {
        success    = true,
        layerId    = params.layerId,
        shapeIndex = newIndex,
        shapeCount = afterShapes,
    }
end

--- Set the curvature of a single mesh point.
-- Per the M_Point docs, SetCurvature(curvature, frame) "sets the curvature of
-- all curves that pass through this point" — the simplest way to make a vertex
-- smooth (positive) vs sharp (zero/negative).
-- @param params  layerId, pointIndex, curvature (real). Optional: frame (default 0).
function mesh.setPointCurvature(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.pointIndex) ~= "number" then
        return nil, "Missing required parameter: pointIndex"
    end
    if type(params.curvature) ~= "number" then
        return nil, "Missing required parameter: curvature"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local count = meshObj:CountPoints()
    if params.pointIndex < 0 or params.pointIndex >= count then
        return nil, "pointIndex out of range"
    end

    local pOk, pt = pcall(function() return meshObj:Point(params.pointIndex) end)
    if not pOk or not pt then
        return nil, "Failed to access point"
    end

    local lyr = getLayerById(moho, params.layerId)
    moho.document:PrepUndo(lyr)

    local frame = params.frame or 0
    local ok, setErr = pcall(function() pt:SetCurvature(params.curvature, frame) end)
    if not ok then
        return nil, "Failed to set curvature: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success    = true,
        layerId    = params.layerId,
        pointIndex = params.pointIndex,
        curvature  = params.curvature,
        frame      = frame,
    }
end

--- List all curves in a vector layer's mesh, with the mesh-point indices that
-- form each curve. Useful before calling mesh.setBezierHandle, which needs a
-- curve-local point ID rather than a mesh-global one.
-- @param params  layerId
function mesh.getCurves(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local curves = {}
    local count = 0
    pcall(function() count = meshObj:CountCurves() end)

    for i = 0, count - 1 do
        local cOk, curve = pcall(function() return meshObj:Curve(i) end)
        if cOk and curve then
            local entry = { curveIndex = i, points = {} }
            local closedOk, closed = pcall(function() return curve.fClosed end)
            entry.closed = closedOk and closed or false

            local ptCountOk, ptCount = pcall(function() return curve:CountPoints() end)
            if ptCountOk and ptCount then
                for j = 0, ptCount - 1 do
                    local meshIdx = -1
                    pcall(function()
                        local p = curve:Point(j)
                        meshIdx = meshObj:PointID(p)
                    end)
                    entry.points[#entry.points + 1] = {
                        curvePointIndex = j,
                        meshPointIndex  = meshIdx,
                    }
                end
            end

            curves[#curves + 1] = entry
        end
    end

    return {
        layerId    = params.layerId,
        curveCount = count,
        curves     = curves,
    }
end

--- Set one of the two bezier control handles on a curve point.
-- Per M_Curve docs: SetControlHandle(ptID, handle, frame, prePoint, syncAngles).
-- The ptID is the curve-local point index — use mesh.getCurves to find it.
-- @param params  layerId, curveIndex, curvePointIndex, x, y.
--   Optional: frame (default 0), prePoint (default false = outgoing handle),
--   syncAngles (default true).
function mesh.setBezierHandle(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.curveIndex) ~= "number"
        or type(params.curvePointIndex) ~= "number"
        or type(params.x) ~= "number"
        or type(params.y) ~= "number" then
        return nil, "Missing required params: curveIndex, curvePointIndex, x, y"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local cOk, curve = pcall(function() return meshObj:Curve(params.curveIndex) end)
    if not cOk or not curve then
        return nil, "curveIndex out of range"
    end

    local lyr = getLayerById(moho, params.layerId)
    moho.document:PrepUndo(lyr)

    local frame = params.frame or 0
    local prePoint = params.prePoint == true
    local syncAngles = (params.syncAngles ~= false)

    local ok, setErr = pcall(function()
        local v = LM.Vector2:new_local()
        v.x = params.x
        v.y = params.y
        curve:SetControlHandle(params.curvePointIndex, v, frame, prePoint, syncAngles)
    end)
    if not ok then
        return nil, "Failed to set control handle: " .. tostring(setErr)
    end

    moho.document:SetDirty()

    return {
        success         = true,
        layerId         = params.layerId,
        curveIndex      = params.curveIndex,
        curvePointIndex = params.curvePointIndex,
        handle          = { x = params.x, y = params.y },
        prePoint        = prePoint,
        frame           = frame,
    }
end

--- Bind one or more mesh points to a bone.
-- M_Point.fParent: -1 = unbound, -2 = flexi-bound to all bones in parent layer,
-- otherwise the int32 ID of the bone to attach to.
-- @param params  layerId, pointIndices (array), boneId (number).
function mesh.bindPoints(moho, params)
    if not params or params.layerId == nil then
        return nil, "Missing required parameter: layerId"
    end
    if type(params.pointIndices) ~= "table" or #params.pointIndices == 0 then
        return nil, "pointIndices must be a non-empty array"
    end
    if type(params.boneId) ~= "number" then
        return nil, "boneId must be a number (-1 unbind, -2 flexi-bind, or a bone ID)"
    end

    local meshObj, vecLyr, err = getMesh(moho, params.layerId)
    if not meshObj then
        return nil, err
    end

    local lyr = getLayerById(moho, params.layerId)
    moho.document:PrepUndo(lyr)

    local count = meshObj:CountPoints()
    local bound = {}
    for _, idx in ipairs(params.pointIndices) do
        if type(idx) ~= "number" or idx < 0 or idx >= count then
            return nil, "pointIndex out of range: " .. tostring(idx)
        end
        local pOk, pt = pcall(function() return meshObj:Point(idx) end)
        if not pOk or not pt then
            return nil, "Failed to access point " .. tostring(idx)
        end
        pcall(function() pt.fParent = params.boneId end)
        bound[#bound + 1] = idx
    end

    moho.document:SetDirty()

    return {
        success     = true,
        layerId     = params.layerId,
        boneId      = params.boneId,
        pointsBound = bound,
    }
end

return mesh
