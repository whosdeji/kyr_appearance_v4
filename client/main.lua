local menuOpen = false
local staffMode = false
local newCharacterMode = false
local previousAppearance = nil
local savedPosition = nil
local currentMode = 'characterisation' -- 'characterisation' | 'locker'
local currentFaction = nil

local function freezeForEditor(ped, freeze)
    FreezeEntityPosition(ped, freeze)
    SetEntityInvincible(ped, freeze)
    SetEntityVisible(ped, true, false)
    SetPlayerControl(PlayerId(), not freeze, 0)
    DisplayRadar(not freeze)
    DisplayHud(not freeze)
end

local function teleportTo(ped, c)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
end

local function getCurrentPosition(ped)
    local coords = GetEntityCoords(ped)
    return vector4(coords.x, coords.y, coords.z, GetEntityHeading(ped))
end

local function buildNuiPayload(options)
    options = options or {}
    local mode = options.mode or 'characterisation'
    local factionKey = options.faction

    local overlays = {}
    for _, o in ipairs(Config.HeadOverlays) do
        overlays[#overlays + 1] = {
            id = o.id,
            key = o.key,
            label = o.label,
            hasColor = o.hasColor or false,
            max = GetOverlayMax(o.id)
        }
    end

    local clothingLimits = GetClothingLimits(PlayerPedId())
    local currentClothing = GetCurrentClothing(PlayerPedId())

    local presets = {}
    if mode == 'locker' and factionKey and Config.Factions[factionKey] then
        for name, _ in pairs(Config.Factions[factionKey].presets or {}) do
            presets[#presets + 1] = name
        end
    else
        for name, _ in pairs(Config.ClothingPresets or {}) do
            presets[#presets + 1] = name
        end
    end
    table.sort(presets)

    local allowed, allowedProps = nil, nil
    if mode == 'locker' and factionKey and Config.Factions[factionKey] then
        allowed = Config.Factions[factionKey].allowed
        allowedProps = Config.Factions[factionKey].allowedProps
    end

    return {
        faceFeatures = Config.FaceFeatures,
        overlays = overlays,
        maxParentID = Config.MaxParentID,
        current = GetCurrentAppearance(),
        staffMode = staffMode,
        mode = mode,
        faction = factionKey,

        clothingComponents = Config.ClothingComponents,
        clothingProps = Config.ClothingProps,
        clothingLimits = clothingLimits,
        currentClothing = currentClothing,
        presets = presets,

        allowed = allowed,
        allowedProps = allowedProps,
    }
end

--- options = { mode = 'locker'|'characterisation', faction = 'usmarines' }
function OpenAppearanceMenu(isNewCharacter, staff, gender, options)
    if menuOpen then return end
    menuOpen = true
    staffMode = staff or false
    newCharacterMode = isNewCharacter or false
    options = options or {}
    currentMode = options.mode or 'characterisation'
    currentFaction = options.faction

    local ped = PlayerPedId()

    -- Remember position + appearance so we can revert on cancel
    if not isNewCharacter then
        savedPosition = getCurrentPosition(ped)
        previousAppearance = GetCurrentAppearance()
    end

    TriggerServerEvent('kyr_appearance:enterEditor')

    if isNewCharacter then
        local model = gender == 'female' and Config.Models.female or Config.Models.male
        ApplyModel(model)
        ped = PlayerPedId()
        ApplyHeadBlend(ped, {
            shapeFirst = 0, shapeSecond = 1, shapeThird = 0,
            skinFirst = 0, skinSecond = 1, skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0
        })
    end

    -- Future: per-faction editor rooms
    -- local editor = Config.EditorCoords
    -- if currentFaction and Config.Factions[currentFaction] and Config.Factions[currentFaction].editorCoords then
    --     editor = Config.Factions[currentFaction].editorCoords
    -- end
    local editor = Config.EditorCoords

    teleportTo(ped, editor)
    freezeForEditor(ped, true)
    CreateAppearanceCam(ped)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = buildNuiPayload(options)
    })
end

local function closeAppearanceMenu()
    local ped = PlayerPedId()

    DestroyAppearanceCam()
    freezeForEditor(ped, false)

    if newCharacterMode then
        teleportTo(ped, Config.PostCreationSpawn)
    elseif savedPosition then
        teleportTo(ped, savedPosition)
    end

    TriggerServerEvent('kyr_appearance:exitEditor')

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    menuOpen = false
    savedPosition = nil
    currentMode = 'characterisation'
    currentFaction = nil
    ClearLockerFaction()
end

-- ox_core character load
RegisterNetEvent('ox:setActiveCharacter', function(character, groups)
    if character.isNew then
        Wait(500)
        OpenAppearanceMenu(true, false, character.gender)
        return
    end

    lib.callback('kyr_appearance:isCompleted', false, function(completed)
        if not completed then
            Wait(400)
            OpenAppearanceMenu(true, false, character.gender)
            return
        end

        lib.callback('kyr_appearance:getAppearance', false, function(data)
            if not data then return end

            CreateThread(function()
                local model = data.model
                if not model then
                    model = (character.gender == 'female') and Config.Models.female or Config.Models.male
                end

                ApplyModel(model)

                -- Wait until freemode is actually ready before applying face/clothes
                local ped = PlayerPedId()
                local timeout = GetGameTimer() + 2500
                while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
                    Wait(50)
                    ped = PlayerPedId()
                end
                Wait(300)

                ApplyFullAppearance(PlayerPedId(), data)
            end)
        end)
    end)
end)

RegisterCommand('characterisation', function()
    if menuOpen then return end

    lib.callback('kyr_appearance:checkPermission', false, function(allowed)
        if allowed then
            OpenAppearanceMenu(false, true)
        else
            lib.notify({
                title = 'Characterisation',
                description = 'You do not have permission to use this.',
                type = 'error'
            })
        end
    end)
end, false)

-- ---------------------------------------------------------------------
-- NUI callbacks
-- ---------------------------------------------------------------------
RegisterNUICallback('randomize', function(_, cb)
    RandomizeAppearance(PlayerPedId())
    -- send the new values back so the UI sliders update
    cb({
        current = GetCurrentAppearance()
    })
end)

RegisterNUICallback('rotate', function(data, cb)
    RotatePed((data.direction or 1) * Config.RotateStep)
    cb(1)
end)

RegisterNUICallback('zoom', function(data, cb)
    ZoomAppearanceCam((data.direction or 1) * Config.ZoomStep)
    cb(1)
end)

RegisterNUICallback('setCamFocus', function(data, cb)
    SetCamFocus(data.focus or 'head')
    cb(1)
end)

RegisterNUICallback('headBlend', function(data, cb)
    ApplyHeadBlend(PlayerPedId(), data)
    cb(1)
end)

RegisterNUICallback('faceFeature', function(data, cb)
    ApplyFaceFeature(PlayerPedId(), tonumber(data.index), tonumber(data.value))
    cb(1)
end)

RegisterNUICallback('overlay', function(data, cb)
    ApplyHeadOverlay(
        PlayerPedId(),
        tonumber(data.id),
        tonumber(data.index),
        tonumber(data.opacity),
        data.colorType and tonumber(data.colorType) or nil,
        data.colorIndex and tonumber(data.colorIndex) or nil,
        data.secondColorIndex and tonumber(data.secondColorIndex) or nil
    )
    cb(1)
end)

RegisterNUICallback('hair', function(data, cb)
    ApplyHair(PlayerPedId(), tonumber(data.style), tonumber(data.color), tonumber(data.highlight))
    cb(1)
end)

RegisterNUICallback('eyeColor', function(data, cb)
    ApplyEyeColor(PlayerPedId(), tonumber(data.colorId))
    cb(1)
end)

RegisterNUICallback('component', function(data, cb)
    ApplyComponent(PlayerPedId(), data.id, data.drawable, data.texture)
    cb(1)
end)

RegisterNUICallback('prop', function(data, cb)
    ApplyProp(PlayerPedId(), data.id, data.drawable, data.texture)
    cb(1)
end)

RegisterNUICallback('getTextureMax', function(data, cb)
    local max = GetTextureMax(PlayerPedId(), data.isProp, data.id, data.drawable)
    cb({ max = max })
end)

RegisterNUICallback('applyPreset', function(data, cb)
    local name = data.name
    local ok = false

    if currentMode == 'locker' and currentFaction and Config.Factions[currentFaction] then
        local preset = Config.Factions[currentFaction].presets[name]
        if preset then
            ApplyClothing(PlayerPedId(), preset)
            ok = true
        end
    else
        ok = ApplyPreset(PlayerPedId(), name)
    end

    if ok then
        cb({ clothing = GetCurrentClothing(PlayerPedId()) })
    else
        cb({ error = true })
    end
end)

RegisterNUICallback('save', function(data, cb)
    TriggerServerEvent('kyr_appearance:save', GetCurrentAppearance())
    closeAppearanceMenu()
    cb(1)
end)

RegisterNUICallback('cancel', function(data, cb)
    if newCharacterMode then
        lib.notify({
            title = 'Characterisation',
            description = 'You must confirm your appearance before continuing.',
            type = 'error'
        })
        cb(1)
        return
    end

    if previousAppearance then
        ApplyFullAppearance(PlayerPedId(), previousAppearance)
    end

    closeAppearanceMenu()
    cb(1)
end)

-- /saveoutfit still works (staff only)
RegisterCommand('saveoutfit', function(_, args)
    lib.callback('kyr_appearance:checkPermission', false, function(allowed)
        if not allowed then
            lib.notify({ title = 'Save Outfit', description = 'No permission.', type = 'error' })
            return
        end

        local name = args[1] or 'unnamed_outfit'
        local clothing = GetCurrentClothing(PlayerPedId())

        local lines = {
            string.format("['%s'] = {", name),
            "    components = {",
        }

        for _, c in ipairs(Config.ClothingComponents) do
            local v = clothing.components[tostring(c.id)]
            if v then
                lines[#lines + 1] = string.format(
                    "        [%d] = { drawable = %d, texture = %d },  -- %s",
                    c.id, v.drawable, v.texture, c.label
                )
            end
        end

        lines[#lines + 1] = "    },"
        lines[#lines + 1] = "    props = {"

        for _, p in ipairs(Config.ClothingProps) do
            local v = clothing.props[tostring(p.id)]
            if v then
                lines[#lines + 1] = string.format(
                    "        [%d] = { drawable = %d, texture = %d },  -- %s",
                    p.id, v.drawable, v.texture, p.label
                )
            end
        end

        lines[#lines + 1] = "    }"
        lines[#lines + 1] = "},"

        local output = table.concat(lines, "\n")
        print("^2===== PASTE THIS INTO THE CORRECT presets TABLE =====^0")
        print(output)
        print("^2====================================================^0")

        lib.setClipboard(output)

        lib.notify({
            title = 'Save Outfit',
            description = 'Preset dumped to F8 + clipboard.',
            type = 'success'
        })
    end)
end, false)