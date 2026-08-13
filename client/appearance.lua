local currentAppearance = {}
local lastFullAppearance = nil

function ApplyModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    RequestModel(hash)

    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasModelLoaded(hash) then return false end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)

    return true
end

local function normalizeHeadBlend(d)
    d = d or {}
    return {
        shapeFirst  = tonumber(d.shapeFirst) or 0,
        shapeSecond = tonumber(d.shapeSecond) or 0,
        shapeThird  = tonumber(d.shapeThird) or 0,
        skinFirst   = tonumber(d.skinFirst) or 0,
        skinSecond  = tonumber(d.skinSecond) or 0,
        skinThird   = tonumber(d.skinThird) or 0,
        shapeMix    = tonumber(d.shapeMix) or 0.5,
        skinMix     = tonumber(d.skinMix) or 0.5,
        thirdMix    = tonumber(d.thirdMix) or 0.0,
    }
end

--- Read head blend from the live ped (FiveM native can vary by build).
local function ReadHeadBlendFromPed(ped)
    -- Method used by most appearance resources: struct via InvokeNative
    local ok, blend = pcall(function()
        -- GetPedHeadBlendData fills a table in some builds
        local t = {
            shapeFirst = 0, shapeSecond = 0, shapeThird = 0,
            skinFirst = 0, skinSecond = 0, skinThird = 0,
            shapeMix = 0.0, skinMix = 0.0, thirdMix = 0.0,
        }
        local success = GetPedHeadBlendData(ped, t)
        if success ~= false and (t.shapeFirst or t.shapeSecond or t.shapeMix) then
            return normalizeHeadBlend(t)
        end
        return nil
    end)
    if ok and blend then return blend end

    -- Fallback: multi-return form
    ok, blend = pcall(function()
        local a, b, c, d, e, f, g, h, i = GetPedHeadBlendData(ped)
        if a == nil then return nil end
        -- Some builds return (retval, shapeFirst, ...)
        if type(a) == 'boolean' then
            return normalizeHeadBlend({
                shapeFirst = b, shapeSecond = c, shapeThird = d,
                skinFirst = e, skinSecond = f, skinThird = g,
                shapeMix = h, skinMix = i,
            })
        end
        return normalizeHeadBlend({
            shapeFirst = a, shapeSecond = b, shapeThird = c,
            skinFirst = d, skinSecond = e, skinThird = f,
            shapeMix = g, skinMix = h, thirdMix = i,
        })
    end)
    if ok and blend then return blend end

    return nil
end

local function syncLastFull(key, value)
    lastFullAppearance = lastFullAppearance or {}
    lastFullAppearance[key] = value
end

function ApplyHeadBlend(ped, d)
    d = normalizeHeadBlend(d)
    -- Apply twice — GTA often ignores the first call right after model set
    SetPedHeadBlendData(ped,
        d.shapeFirst, d.shapeSecond, d.shapeThird,
        d.skinFirst, d.skinSecond, d.skinThird,
        d.shapeMix, d.skinMix, d.thirdMix,
        false)
    SetPedHeadBlendData(ped,
        d.shapeFirst, d.shapeSecond, d.shapeThird,
        d.skinFirst, d.skinSecond, d.skinThird,
        d.shapeMix, d.skinMix, d.thirdMix,
        false)

    currentAppearance.headBlend = d
    syncLastFull('headBlend', d)
end

function ApplyFaceFeature(ped, index, value)
    index = tonumber(index)
    value = tonumber(value) or 0.0
    if index == nil then return end
    SetPedFaceFeature(ped, index, value)

    currentAppearance.faceFeatures = currentAppearance.faceFeatures or {}
    currentAppearance.faceFeatures[tostring(index)] = value
    lastFullAppearance = lastFullAppearance or {}
    lastFullAppearance.faceFeatures = lastFullAppearance.faceFeatures or {}
    lastFullAppearance.faceFeatures[tostring(index)] = value
end

function ApplyHeadOverlay(ped, overlayId, index, opacity, colorType, colorIndex, secondColorIndex)
    overlayId = tonumber(overlayId)
    if overlayId == nil then return end
    -- 255 / 0 = clear overlay in GTA
    local idx = tonumber(index)
    if idx == nil or idx < 0 then idx = 255 end
    local op = tonumber(opacity) or 0.0

    SetPedHeadOverlay(ped, overlayId, idx, op)

    if colorType and colorIndex then
        SetPedHeadOverlayColor(ped, overlayId, tonumber(colorType), tonumber(colorIndex), tonumber(secondColorIndex) or tonumber(colorIndex))
    end

    local entry = {
        index = idx,
        opacity = op,
        colorType = colorType and tonumber(colorType) or nil,
        colorIndex = colorIndex and tonumber(colorIndex) or nil,
        secondColorIndex = secondColorIndex and tonumber(secondColorIndex) or nil
    }
    currentAppearance.overlays = currentAppearance.overlays or {}
    currentAppearance.overlays[tostring(overlayId)] = entry
    lastFullAppearance = lastFullAppearance or {}
    lastFullAppearance.overlays = lastFullAppearance.overlays or {}
    lastFullAppearance.overlays[tostring(overlayId)] = entry
end

function ApplyHair(ped, style, color, highlight)
    SetPedComponentVariation(ped, 2, style or 0, 0, 0)
    SetPedHairColor(ped, color or 0, highlight or 0)

    local hair = { style = style or 0, color = color or 0, highlight = highlight or 0 }
    currentAppearance.hair = hair
    syncLastFull('hair', hair)
end

function ApplyEyeColor(ped, colorId)
    SetPedEyeColor(ped, colorId or 0)
    currentAppearance.eyeColor = colorId or 0
    syncLastFull('eyeColor', colorId or 0)
end

--- Apply a component using collection + local index when available.
--- Falls back to global drawable for legacy presets that only store `drawable`.
---
--- Accepts either:
---   ApplyComponent(ped, id, { collection = "...", drawable = localIdx, texture = n })
---   ApplyComponent(ped, id, globalDrawable, texture)   -- legacy
function ApplyComponent(ped, componentId, drawableOrData, texture)
    componentId = tonumber(componentId)
    if not componentId then return end

    local collection, localDrawable, tex, globalDrawable

    if type(drawableOrData) == 'table' then
        collection = drawableOrData.collection
        tex        = tonumber(drawableOrData.texture) or 0
        -- Prefer explicit localDrawable; else treat drawable as local when collection present,
        -- otherwise as global (legacy / NUI).
        if drawableOrData.localDrawable ~= nil then
            localDrawable = tonumber(drawableOrData.localDrawable)
        elseif collection and collection ~= '' then
            localDrawable = tonumber(drawableOrData.drawable)
        else
            globalDrawable = tonumber(drawableOrData.drawable) or 0
            localDrawable  = globalDrawable
        end
    else
        globalDrawable = tonumber(drawableOrData) or 0
        localDrawable  = globalDrawable
        tex            = tonumber(texture) or 0
        collection     = nil
    end

    if collection and collection ~= '' and localDrawable ~= nil then
        -- Stable path: collection-local index does not shift when new packs are added
        SetPedCollectionComponentVariation(ped, componentId, collection, localDrawable, tex, 0)
        globalDrawable = GetPedDrawableVariation(ped, componentId)
    else
        -- Global path (NUI browsing or legacy presets)
        SetPedComponentVariation(ped, componentId, localDrawable or 0, tex, 0)
        globalDrawable = localDrawable or 0
        local ok, col = pcall(GetPedDrawableVariationCollectionName, ped, componentId)
        local ok2, loc = pcall(GetPedDrawableVariationCollectionLocalIndex, ped, componentId)
        if ok and ok2 and col then
            collection = col
            localDrawable = loc
        end
    end

    currentAppearance.components = currentAppearance.components or {}
    currentAppearance.components[tostring(componentId)] = {
        drawable      = globalDrawable,          -- UI / legacy global
        texture       = tex,
        collection    = collection or '',
        localDrawable = localDrawable or globalDrawable or 0,
    }
end

function ApplyProp(ped, propId, drawableOrData, texture)
    propId = tonumber(propId)
    if not propId then return end

    local collection, localDrawable, tex, globalDrawable

    if type(drawableOrData) == 'table' then
        collection = drawableOrData.collection
        tex        = tonumber(drawableOrData.texture) or 0
        if drawableOrData.localDrawable ~= nil then
            localDrawable = tonumber(drawableOrData.localDrawable)
        elseif collection and collection ~= '' then
            localDrawable = tonumber(drawableOrData.drawable)
        else
            globalDrawable = tonumber(drawableOrData.drawable)
            localDrawable  = globalDrawable
        end
    else
        globalDrawable = tonumber(drawableOrData)
        localDrawable  = globalDrawable
        tex            = tonumber(texture) or 0
        collection     = nil
    end

    if not localDrawable or localDrawable < 0 then
        ClearPedProp(ped, propId)
        collection = ''
        localDrawable = -1
        globalDrawable = -1
        tex = 0
    elseif collection and collection ~= '' then
        SetPedCollectionPropIndex(ped, propId, collection, localDrawable, tex, true)
        globalDrawable = GetPedPropIndex(ped, propId)
    else
        SetPedPropIndex(ped, propId, localDrawable, tex, true)
        globalDrawable = localDrawable
        local ok, col = pcall(GetPedPropCollectionName, ped, propId)
        local ok2, loc = pcall(GetPedPropCollectionLocalIndex, ped, propId)
        if ok and ok2 and col then
            collection = col
            localDrawable = loc
        end
    end

    currentAppearance.props = currentAppearance.props or {}
    currentAppearance.props[tostring(propId)] = {
        drawable      = globalDrawable,
        texture       = tex,
        collection    = collection or '',
        localDrawable = localDrawable or -1,
    }
end

--- Capture clothing.
---
--- Persistence fields (stable across EUP additions):
---   collection, localDrawable, texture
---
--- UI fields (linear global space the NUI sliders expect):
---   drawable = current global index
function GetCurrentClothing(ped)
    ped = ped or PlayerPedId()

    local components = {}
    for _, c in ipairs(Config.ClothingComponents) do
        local globalDrawable = GetPedDrawableVariation(ped, c.id)
        local texture = GetPedTextureVariation(ped, c.id)

        local collection, localDrawable = '', globalDrawable
        local ok, col = pcall(GetPedDrawableVariationCollectionName, ped, c.id)
        local ok2, loc = pcall(GetPedDrawableVariationCollectionLocalIndex, ped, c.id)
        if ok and ok2 and col then
            collection = col
            localDrawable = loc
        end

        components[tostring(c.id)] = {
            -- UI / legacy
            drawable = globalDrawable,
            texture  = texture,
            -- Stable identity for DB + config presets
            collection    = collection,
            localDrawable = localDrawable,
        }
    end

    local props = {}
    for _, p in ipairs(Config.ClothingProps) do
        local globalDrawable = GetPedPropIndex(ped, p.id)
        local texture = 0
        local collection, localDrawable = '', globalDrawable

        if globalDrawable >= 0 then
            texture = GetPedPropTextureIndex(ped, p.id)
            local ok, col = pcall(GetPedPropCollectionName, ped, p.id)
            local ok2, loc = pcall(GetPedPropCollectionLocalIndex, ped, p.id)
            if ok and ok2 and col then
                collection = col
                localDrawable = loc
            end
        else
            localDrawable = -1
            collection = ''
        end

        props[tostring(p.id)] = {
            drawable = globalDrawable,
            texture  = texture,
            collection    = collection,
            localDrawable = localDrawable,
        }
    end

    return { components = components, props = props }
end

function ApplyClothing(ped, data)
    if not data then return end

    if data.components then
        for id, v in pairs(data.components) do
            -- Pass whole table so collection is used when present
            ApplyComponent(ped, tonumber(id) or id, v)
        end
    end

    if data.props then
        for id, v in pairs(data.props) do
            ApplyProp(ped, tonumber(id) or id, v)
        end
    end
end

function ApplyPreset(ped, presetName)
    local preset = Config.ClothingPresets[presetName]
    if not preset then return false end
    ApplyClothing(ped, preset)
    return true
end

function GetClothingLimits(ped)
    ped = ped or PlayerPedId()
    local limits = { components = {}, props = {} }

    for _, c in ipairs(Config.ClothingComponents) do
        local maxDrawable = GetNumberOfPedDrawableVariations(ped, c.id) - 1
        limits.components[tostring(c.id)] = {
            maxDrawable = math.max(0, maxDrawable),
        }
    end

    for _, p in ipairs(Config.ClothingProps) do
        local maxDrawable = GetNumberOfPedPropDrawableVariations(ped, p.id) - 1
        limits.props[tostring(p.id)] = {
            maxDrawable = math.max(0, maxDrawable),
        }
    end

    return limits
end

function GetTextureMax(ped, isProp, id, drawable)
    ped = ped or PlayerPedId()
    id = tonumber(id)
    drawable = tonumber(drawable) or 0

    if isProp then
        if drawable < 0 then return 0 end
        return math.max(0, GetNumberOfPedPropTextureVariations(ped, id, drawable) - 1)
    else
        return math.max(0, GetNumberOfPedTextureVariations(ped, id, drawable) - 1)
    end
end

function GetOverlayMax(overlayId)
    local n = GetNumHeadOverlayValues(overlayId)
    return (n or 1) - 1
end

function RandomizeAppearance(ped)
    ped = ped or PlayerPedId()

    local shapeFirst  = math.random(0, Config.MaxParentID)
    local shapeSecond = math.random(0, Config.MaxParentID)
    local skinFirst   = math.random(0, Config.MaxParentID)
    local skinSecond  = math.random(0, Config.MaxParentID)

    ApplyHeadBlend(ped, {
        shapeFirst  = shapeFirst,
        shapeSecond = shapeSecond,
        shapeThird  = 0,
        skinFirst   = skinFirst,
        skinSecond  = skinSecond,
        skinThird   = 0,
        shapeMix    = math.random() * 0.9 + 0.05,
        skinMix     = math.random() * 0.9 + 0.05,
        thirdMix    = 0.0
    })

    for i = 0, 19 do
        local value = ((math.random() * 2.0) - 1.0) * 0.7
        ApplyFaceFeature(ped, i, value)
    end

    ApplyHair(ped, math.random(0, 73), math.random(0, 63), math.random(0, 63))
    ApplyEyeColor(ped, math.random(0, 31))

    -- Do not randomize cosmetic makeup overlays — always clear them
    local skipRandomOverlay = {
        makeup = true,
        blush = true,
        lipstick = true,
    }

    for _, o in ipairs(Config.HeadOverlays) do
        if skipRandomOverlay[o.key] then
            ApplyHeadOverlay(ped, o.id, 255, 0.0, nil, nil, nil)
        else
            local max = GetOverlayMax(o.id)
            local index = math.random(-1, max)
            local opacity = index >= 0 and (math.random() * 0.7 + 0.3) or 0.0

            local colorType, colorIndex, secondColorIndex = nil, nil, nil
            if o.hasColor and index >= 0 then
                colorType = 1
                colorIndex = math.random(0, 63)
                secondColorIndex = colorIndex
            end

            ApplyHeadOverlay(ped, o.id, index, opacity, colorType, colorIndex, secondColorIndex)
        end
    end
end

function GetCurrentAppearance()
    local ped = PlayerPedId()

    -- Clothing from live ped (collection-stable)
    local clothing = GetCurrentClothing(ped)
    currentAppearance.components = clothing.components
    currentAppearance.props = clothing.props
    currentAppearance.model = GetEntityModel(ped)

    -- Hair + eyes from live ped
    currentAppearance.hair = {
        style     = GetPedDrawableVariation(ped, 2),
        color     = GetPedHairColor(ped),
        highlight = GetPedHairHighlightColor(ped),
    }
    currentAppearance.eyeColor = GetPedEyeColor(ped)

    -- Face features from live ped
    currentAppearance.faceFeatures = {}
    for i = 0, 19 do
        currentAppearance.faceFeatures[tostring(i)] = GetPedFaceFeature(ped, i)
    end

    -- Head blend: prefer live ped, then current edits, then last full snapshot
    local liveBlend = ReadHeadBlendFromPed(ped)
    if liveBlend then
        currentAppearance.headBlend = liveBlend
    elseif currentAppearance.headBlend then
        -- keep edits already tracked this session
        currentAppearance.headBlend = normalizeHeadBlend(currentAppearance.headBlend)
    elseif lastFullAppearance and lastFullAppearance.headBlend then
        currentAppearance.headBlend = normalizeHeadBlend(lastFullAppearance.headBlend)
    end

    -- Overlays: keep tracked session data (GTA has no reliable full read-back)
    if not currentAppearance.overlays and lastFullAppearance and lastFullAppearance.overlays then
        currentAppearance.overlays = lastFullAppearance.overlays
    end

    -- Keep lastFullAppearance in sync so locker sessions cannot wipe heritage
    lastFullAppearance = lastFullAppearance or {}
    lastFullAppearance.headBlend = currentAppearance.headBlend
    lastFullAppearance.faceFeatures = currentAppearance.faceFeatures
    lastFullAppearance.overlays = currentAppearance.overlays
    lastFullAppearance.hair = currentAppearance.hair
    lastFullAppearance.eyeColor = currentAppearance.eyeColor
    lastFullAppearance.model = currentAppearance.model
    lastFullAppearance.components = currentAppearance.components
    lastFullAppearance.props = currentAppearance.props

    -- Return a deep copy so callers cannot mutate our tracking tables
    return json.decode(json.encode(currentAppearance))
end

function SetCurrentAppearance(data)
    currentAppearance = data or {}
    lastFullAppearance = data and json.decode(json.encode(data)) or nil
end

function ApplyFullAppearance(ped, data)
    if not data then return end
    ped = ped or PlayerPedId()

    -- 1) Head blend first (twice + short wait so face features stick)
    if data.headBlend then
        ApplyHeadBlend(ped, data.headBlend)
        Wait(50)
        ApplyHeadBlend(ped, data.headBlend)
        Wait(50)
    end

    -- 2) Face features
    if data.faceFeatures then
        for idx, val in pairs(data.faceFeatures) do
            ApplyFaceFeature(ped, tonumber(idx), val)
        end
        Wait(50)
    end

    -- 3) Overlays (beard, brows, makeup, etc.)
    if data.overlays then
        for id, o in pairs(data.overlays) do
            if type(o) == 'table' then
                ApplyHeadOverlay(ped, tonumber(id), o.index, o.opacity, o.colorType, o.colorIndex, o.secondColorIndex)
            end
        end
    end

    -- 4) Hair + eyes
    if data.hair then
        ApplyHair(ped, data.hair.style, data.hair.color, data.hair.highlight)
    end

    if data.eyeColor ~= nil then
        ApplyEyeColor(ped, data.eyeColor)
    end

    -- 5) Clothing last
    if data.components or data.props then
        ApplyClothing(ped, {
            components = data.components,
            props = data.props
        })
    end

    -- Snapshot for future saves
    local snapshot = json.decode(json.encode(data))
    currentAppearance = snapshot
    lastFullAppearance = json.decode(json.encode(data))
end
