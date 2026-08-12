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

function ApplyComponent(ped, componentId, drawable, texture)
    componentId = tonumber(componentId)
    drawable = tonumber(drawable) or 0
    texture = tonumber(texture) or 0

    SetPedComponentVariation(ped, componentId, drawable, texture, 0)

    currentAppearance.components = currentAppearance.components or {}
    currentAppearance.components[tostring(componentId)] = {
        drawable = drawable,
        texture = texture
    }
end

function ApplyProp(ped, propId, drawable, texture)
    propId = tonumber(propId)
    drawable = tonumber(drawable)
    texture = tonumber(texture) or 0

    if not drawable or drawable < 0 then
        ClearPedProp(ped, propId)
        drawable = -1
    else
        SetPedPropIndex(ped, propId, drawable, texture, true)
    end

    currentAppearance.props = currentAppearance.props or {}
    currentAppearance.props[tostring(propId)] = {
        drawable = drawable,
        texture = texture
    }
end

function GetCurrentClothing(ped)
    ped = ped or PlayerPedId()

    local components = {}
    for _, c in ipairs(Config.ClothingComponents) do
        components[tostring(c.id)] = {
            drawable = GetPedDrawableVariation(ped, c.id),
            texture  = GetPedTextureVariation(ped, c.id)
        }
    end

    local props = {}
    for _, p in ipairs(Config.ClothingProps) do
        local drawable = GetPedPropIndex(ped, p.id)
        props[tostring(p.id)] = {
            drawable = drawable,
            texture  = drawable >= 0 and GetPedPropTextureIndex(ped, p.id) or 0
        }
    end

    return { components = components, props = props }
end

function ApplyClothing(ped, data)
    if not data then return end

    if data.components then
        for id, v in pairs(data.components) do
            ApplyComponent(ped, id, v.drawable, v.texture)
        end
    end

    if data.props then
        for id, v in pairs(data.props) do
            ApplyProp(ped, id, v.drawable, v.texture)
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

    for _, o in ipairs(Config.HeadOverlays) do
        local max = GetOverlayMax(o.id)
        local index = math.random(-1, max)
        local opacity = index >= 0 and (math.random() * 0.7 + 0.3) or 0.0

        local colorType, colorIndex, secondColorIndex = nil, nil, nil
        if o.hasColor and index >= 0 then
            colorType = (o.key == 'blush' or o.key == 'lipstick') and 2 or 1
            colorIndex = math.random(0, 63)
            secondColorIndex = colorIndex
        end

        ApplyHeadOverlay(ped, o.id, index, opacity, colorType, colorIndex, secondColorIndex)
    end
end

function GetCurrentAppearance()
    local ped = PlayerPedId()

    -- Clothing from live ped
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
        -- If hair somehow missing
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