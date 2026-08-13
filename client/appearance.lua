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

function ApplyHeadBlend(ped, d)
    d = d or {}
    SetPedHeadBlendData(ped,
        d.shapeFirst or 0, d.shapeSecond or 0, d.shapeThird or 0,
        d.skinFirst or 0, d.skinSecond or 0, d.skinThird or 0,
        d.shapeMix or 0.5, d.skinMix or 0.5, d.thirdMix or 0.0,
        false)

    currentAppearance.headBlend = d
end

function ApplyFaceFeature(ped, index, value)
    SetPedFaceFeature(ped, index, value)

    currentAppearance.faceFeatures = currentAppearance.faceFeatures or {}
    currentAppearance.faceFeatures[tostring(index)] = value
end

function ApplyHeadOverlay(ped, overlayId, index, opacity, colorType, colorIndex, secondColorIndex)
    SetPedHeadOverlay(ped, overlayId, index or 255, opacity or 1.0)

    if colorType and colorIndex then
        SetPedHeadOverlayColor(ped, overlayId, colorType, colorIndex, secondColorIndex or colorIndex)
    end

    currentAppearance.overlays = currentAppearance.overlays or {}
    currentAppearance.overlays[tostring(overlayId)] = {
        index = index,
        opacity = opacity,
        colorType = colorType,
        colorIndex = colorIndex,
        secondColorIndex = secondColorIndex
    }
end

function ApplyHair(ped, style, color, highlight)
    SetPedComponentVariation(ped, 2, style or 0, 0, 0)
    SetPedHairColor(ped, color or 0, highlight or 0)

    currentAppearance.hair = { style = style, color = color, highlight = highlight }
end

function ApplyEyeColor(ped, colorId)
    SetPedEyeColor(ped, colorId or 0)
    currentAppearance.eyeColor = colorId
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

    -- Head blend + overlays: use last full apply (never wiped by locker)
    if lastFullAppearance then
        if lastFullAppearance.headBlend then
            currentAppearance.headBlend = lastFullAppearance.headBlend
        end
        if lastFullAppearance.overlays then
            currentAppearance.overlays = lastFullAppearance.overlays
        end
        if not currentAppearance.hair and lastFullAppearance.hair then
            currentAppearance.hair = lastFullAppearance.hair
        end
        if currentAppearance.eyeColor == nil and lastFullAppearance.eyeColor ~= nil then
            currentAppearance.eyeColor = lastFullAppearance.eyeColor
        end
    end

    return currentAppearance
end

function SetCurrentAppearance(data)
    currentAppearance = data or {}
end

function ApplyFullAppearance(ped, data)
    if not data then return end

    if data.headBlend then
        ApplyHeadBlend(ped, data.headBlend)
    end

    if data.faceFeatures then
        for idx, val in pairs(data.faceFeatures) do
            ApplyFaceFeature(ped, tonumber(idx), val)
        end
    end

    if data.overlays then
        for id, o in pairs(data.overlays) do
            ApplyHeadOverlay(ped, tonumber(id), o.index, o.opacity, o.colorType, o.colorIndex, o.secondColorIndex)
        end
    end

    if data.hair then
        ApplyHair(ped, data.hair.style, data.hair.color, data.hair.highlight)
    end

    if data.eyeColor then
        ApplyEyeColor(ped, data.eyeColor)
    end

    if data.components or data.props then
        ApplyClothing(ped, {
            components = data.components,
            props = data.props
        })
    end

    currentAppearance = data
    lastFullAppearance = data
end
