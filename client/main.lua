local menuOpen = false
local staffMode = false
local newCharacterMode = false
local previousAppearance = nil
local savedPosition = nil
local currentMode = 'characterisation' -- 'characterisation' | 'locker'
local currentFaction = nil

local function preloadEditorArea(coords)
    local x, y, z = coords.x, coords.y, coords.z

    RequestCollisionAtCoord(x, y, z)
    SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)
    NewLoadSceneStart(x, y, z, x, y, z, 20.0, 0)

    local timeout = GetGameTimer() + 3000
    while not IsNewLoadSceneLoaded() and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
    NewLoadSceneStop()
    ClearFocus()
end

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

--- Force string keys so json.encode never turns sparse slot tables into arrays
--- (which would shift Mask/Arms/Legs labels in the NUI catalog).
local function normalizeClothingNames(src)
    local out = { components = {}, props = {} }
    if type(src) ~= 'table' then return out end

    local function normalizeSlotMap(slotMap)
        local slots = {}
        if type(slotMap) ~= 'table' then return slots end
        for slotId, collections in pairs(slotMap) do
            local slotKey = tostring(slotId)
            local colOut = {}
            if type(collections) == 'table' then
                for collection, drawables in pairs(collections) do
                    local colKey = tostring(collection)
                    local drawOut = {}
                    if type(drawables) == 'table' then
                        for localIdx, label in pairs(drawables) do
                            drawOut[tostring(localIdx)] = label
                        end
                    end
                    colOut[colKey] = drawOut
                end
            end
            slots[slotKey] = colOut
        end
        return slots
    end

    out.components = normalizeSlotMap(src.components)
    out.props = normalizeSlotMap(src.props)
    return out
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

    -- Faction / global config presets (names only; outfit lives in config)
    local presets = {}
    if mode == 'locker' and factionKey and Config.Factions[factionKey] then
        for name, _ in pairs(Config.Factions[factionKey].presets or {}) do
            presets[#presets + 1] = { name = name, source = 'faction' }
        end
    else
        for name, _ in pairs(Config.ClothingPresets or {}) do
            presets[#presets + 1] = { name = name, source = 'global' }
        end
    end
    table.sort(presets, function(a, b) return a.name < b.name end)

    -- Player-owned presets (name + outfit)
    local playerPresets = lib.callback.await('kyr_appearance:getPlayerPresets', false) or {}

    local allowed, allowedProps = nil, nil
    local clothingNames = Config.ClothingNames or { components = {}, props = {} }

    if mode == 'locker' and factionKey and Config.Factions[factionKey] then
        local fac = Config.Factions[factionKey]
        allowed = fac.allowed
        allowedProps = fac.allowedProps
        -- Faction-specific catalog for the Clothing tab
        if fac.clothingNames then
            clothingNames = fac.clothingNames
        end
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
        clothingNames = normalizeClothingNames(clothingNames),
        presets = presets,
        playerPresets = playerPresets,

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

    if not isNewCharacter then
        savedPosition = getCurrentPosition(ped)
        -- Deep-copy so live edits to currentAppearance cannot mutate the cancel snapshot
        previousAppearance = json.decode(json.encode(GetCurrentAppearance()))
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

    local editor = Config.EditorCoords

    DoScreenFadeOut(0)             -- hide the teleport/streaming gap immediately

    teleportTo(ped, editor)
    preloadEditorArea(editor)      -- actually stream the underground room in
    freezeForEditor(ped, true)

    Wait(0)                        -- let the skeleton catch up to the teleport
    ped = PlayerPedId()

    CreateAppearanceCam(ped)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = buildNuiPayload(options)
    })

    DoScreenFadeIn(300)
end

local function closeAppearanceMenu()
    local ped = PlayerPedId()
    local wasNewCharacter = newCharacterMode

    DoScreenFadeOut(150)
    while not IsScreenFadedOut() do Wait(0) end

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

    -- Brand-new characters get faded back in by kyr_spawn once it finishes
    -- positioning them (see the kyr_appearance:characterReady handler we
    -- added earlier) — don't fade in twice here.
    if not wasNewCharacter then
        Wait(200)
        DoScreenFadeIn(500)
    end
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
            if not data then
                -- No saved appearance despite completed=1 (edge case) — nothing to
                -- apply, but kyr_spawn still needs to know it's safe to fade in.
                TriggerEvent('kyr_appearance:characterReady', character, groups)
                return
            end

            CreateThread(function()
                local model = data.model
                if not model then
                    model = (character.gender == 'female') and Config.Models.female or Config.Models.male
                end

                ApplyModel(model)

                local ped = PlayerPedId()
                local timeout = GetGameTimer() + 2500
                while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
                    Wait(50)
                    ped = PlayerPedId()
                end
                Wait(300)

                ApplyFullAppearance(PlayerPedId(), data)

                TriggerEvent('kyr_appearance:characterReady', character, groups)
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
    -- amount can be a multipler; hold-to-rotate sends frequent small steps
    local step = Config.RotateStep or 12.0
    local amount = tonumber(data.amount) or step
    RotatePed((data.direction or 1) * amount)
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
    -- Catalog items send useCollection=true with collection + local drawable.
    -- Numeric browser sends only global drawable/texture.
    if data.useCollection then
        ApplyComponent(PlayerPedId(), data.id, {
            collection = data.collection or '',
            localDrawable = tonumber(data.localDrawable or data.drawable) or 0,
            drawable = tonumber(data.localDrawable or data.drawable) or 0,
            texture = data.texture,
        })
    else
        ApplyComponent(PlayerPedId(), data.id, data.drawable, data.texture)
    end
    cb({ clothing = GetCurrentClothing(PlayerPedId()) })
end)

RegisterNUICallback('prop', function(data, cb)
    if data.useCollection then
        ApplyProp(PlayerPedId(), data.id, {
            collection = data.collection or '',
            localDrawable = tonumber(data.localDrawable or data.drawable) or -1,
            drawable = tonumber(data.localDrawable or data.drawable) or -1,
            texture = data.texture,
        })
    else
        ApplyProp(PlayerPedId(), data.id, data.drawable, data.texture)
    end
    cb({ clothing = GetCurrentClothing(PlayerPedId()) })
end)

RegisterNUICallback('getTextureMax', function(data, cb)
    local max = GetTextureMax(PlayerPedId(), data.isProp, data.id, data.drawable)
    cb({ max = max })
end)

RegisterNUICallback('applyPreset', function(data, cb)
    local name = data.name
    local ok = false
    local ped = PlayerPedId()

    -- Player-owned preset: outfit payload sent from NUI
    if data.source == 'player' and type(data.outfit) == 'table' then
        ApplyClothing(ped, data.outfit)
        ok = true
    elseif currentMode == 'locker' and currentFaction and Config.Factions[currentFaction] then
        local preset = Config.Factions[currentFaction].presets[name]
        if preset then
            ApplyClothing(ped, preset)
            ok = true
        end
    else
        ok = ApplyPreset(ped, name)
    end

    if not ok then
        cb({ ok = false, error = true })
        return
    end

    -- Let the game apply variations before we read them back
    Wait(50)
    ped = PlayerPedId()
    cb({
        ok = true,
        clothing = GetCurrentClothing(ped),
        clothingLimits = GetClothingLimits(ped),
    })
end)

RegisterNUICallback('getClothingState', function(_, cb)
    local ped = PlayerPedId()
    cb({
        clothing = GetCurrentClothing(ped),
        clothingLimits = GetClothingLimits(ped),
    })
end)

RegisterNUICallback('savePlayerPreset', function(data, cb)
    local name = data and data.name
    if type(name) ~= 'string' or name:gsub('%s+', '') == '' then
        cb({ ok = false, error = 'bad_name' })
        return
    end

    local outfit = GetCurrentClothing(PlayerPedId())
    lib.callback('kyr_appearance:savePlayerPreset', false, function(result)
        cb(result or { ok = false })
    end, name, outfit)
end)

RegisterNUICallback('deletePlayerPreset', function(data, cb)
    local name = data and data.name
    if type(name) ~= 'string' then
        cb({ ok = false })
        return
    end
    lib.callback('kyr_appearance:deletePlayerPreset', false, function(result)
        cb(result or { ok = false })
    end, name)
end)

RegisterNUICallback('getPlayerPresets', function(_, cb)
    lib.callback('kyr_appearance:getPlayerPresets', false, function(list)
        cb({ presets = list or {} })
    end)
end)

RegisterNUICallback('save', function(data, cb)
    local wasNewCharacter = newCharacterMode
    TriggerServerEvent('kyr_appearance:save', GetCurrentAppearance())
    closeAppearanceMenu()
    cb(1)

    if wasNewCharacter then
        TriggerEvent('kyr_appearance:characterReady')
    end
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

        -- Dump collection-stable format so presets survive future EUP packs.
        -- collection = .ymt collection name; drawable = LOCAL index inside that collection.
        local lines = {
            string.format("['%s'] = {", name),
            "    components = {",
        }

        for _, c in ipairs(Config.ClothingComponents) do
            local v = clothing.components[tostring(c.id)]
            if v then
                local col = v.collection or ''
                local localIdx = v.localDrawable ~= nil and v.localDrawable or v.drawable or 0
                lines[#lines + 1] = string.format(
                    "        [%d] = { collection = %q, drawable = %d, texture = %d },  -- %s (global %s)",
                    c.id, col, localIdx, v.texture or 0, c.label, tostring(v.drawable)
                )
            end
        end

        lines[#lines + 1] = "    },"
        lines[#lines + 1] = "    props = {"

        for _, p in ipairs(Config.ClothingProps) do
            local v = clothing.props[tostring(p.id)]
            if v then
                local col = v.collection or ''
                local localIdx = v.localDrawable ~= nil and v.localDrawable or v.drawable or -1
                lines[#lines + 1] = string.format(
                    "        [%d] = { collection = %q, drawable = %d, texture = %d },  -- %s (global %s)",
                    p.id, col, localIdx, v.texture or 0, p.label, tostring(v.drawable)
                )
            end
        end

        lines[#lines + 1] = "    }"
        lines[#lines + 1] = "},"

        local output = table.concat(lines, "\n")
        print("^2===== PASTE THIS INTO THE CORRECT presets TABLE =====^0")
        print("^3Uses collection + local drawable (stable across EUP updates)^0")
        print(output)
        print("^2====================================================^0")

        lib.setClipboard(output)

        lib.notify({
            title = 'Save Outfit',
            description = 'Collection-stable preset dumped to F8 + clipboard.',
            type = 'success'
        })
    end)
end, false)