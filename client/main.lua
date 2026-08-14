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

--- Returns 'male' or 'female' for the current freemode ped.
local function getPedSex(ped)
    ped = ped or PlayerPedId()
    local model = GetEntityModel(ped)
    if model == Config.Models.female or model == `mp_f_freemode_01` then
        return 'female'
    end
    return 'male'
end

--- Resolve a clothingNames entry into { label = string, sex = 'male'|'female'|'unisex' }.
--- Accepts legacy bare strings and the new object form.
local function resolveClothingEntry(entry)
    if type(entry) == 'string' then
        return { label = entry, sex = 'unisex' }
    end
    if type(entry) == 'table' then
        local label = entry.label or entry.name or entry[1]
        if type(label) ~= 'string' or label == '' then return nil end
        local sex = entry.sex or entry.gender or 'unisex'
        sex = string.lower(tostring(sex))
        if sex ~= 'male' and sex ~= 'female' and sex ~= 'unisex' then
            sex = 'unisex'
        end
        return { label = label, sex = sex }
    end
    return nil
end

--- True when an item is allowed for the given ped sex.
local function sexAllowed(itemSex, pedSex)
    if not itemSex or itemSex == 'unisex' then return true end
    return itemSex == pedSex
end

--- Force string keys + normalise entries + optionally filter by ped sex.
--- When filterSex is a string ('male'/'female'), incompatible items are dropped
--- so the NUI never even sees them.
local function normalizeClothingNames(src, filterSex)
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
                        for localIdx, raw in pairs(drawables) do
                            local resolved = resolveClothingEntry(raw)
                            if resolved and sexAllowed(resolved.sex, filterSex) then
                                -- Send a clean object the NUI can always read
                                drawOut[tostring(localIdx)] = {
                                    label = resolved.label,
                                    sex   = resolved.sex,
                                }
                            end
                        end
                    end
                    if next(drawOut) then
                        colOut[colKey] = drawOut
                    end
                end
            end
            if next(colOut) then
                slots[slotKey] = colOut
            end
        end
        return slots
    end

    out.components = normalizeSlotMap(src.components)
    out.props      = normalizeSlotMap(src.props)
    return out
end

--- Read sex from a preset/outfit table. Defaults to 'unisex'.
local function getOutfitSex(data)
    if type(data) ~= 'table' then return 'unisex' end
    local sex = data.sex or data.gender
    if type(sex) == 'string' then
        sex = string.lower(sex)
        if sex == 'male' or sex == 'female' or sex == 'unisex' then
            return sex
        end
    end
    return 'unisex'
end

--- Wrap current clothing with the ped's sex (for player presets + share codes).
local function getClothingWithSex(ped)
    ped = ped or PlayerPedId()
    local clothing = GetCurrentClothing(ped)
    clothing.sex = getPedSex(ped)
    return clothing
end

local function buildNuiPayload(options)
    options = options or {}
    local mode = options.mode or 'characterisation'
    local factionKey = options.faction
    local ped = PlayerPedId()
    local pedSex = getPedSex(ped)

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

    local clothingLimits = GetClothingLimits(ped)
    local currentClothing = GetCurrentClothing(ped)

    local presets = {}
    if mode == 'locker' and factionKey and Config.Factions[factionKey] then
        for name, preset in pairs(Config.Factions[factionKey].presets or {}) do
            if sexAllowed(getOutfitSex(preset), pedSex) then
                presets[#presets + 1] = {
                    name = name,
                    source = 'faction',
                    sex = getOutfitSex(preset),
                }
            end
        end
    else
        for name, preset in pairs(Config.ClothingPresets or {}) do
            if sexAllowed(getOutfitSex(preset), pedSex) then
                presets[#presets + 1] = {
                    name = name,
                    source = 'global',
                    sex = getOutfitSex(preset),
                }
            end
        end
    end
    table.sort(presets, function(a, b) return a.name < b.name end)

    -- Player-owned presets: only show ones that match this ped's sex
    local rawPlayerPresets = lib.callback.await('kyr_appearance:getPlayerPresets', false) or {}
    local playerPresets = {}
    for _, p in ipairs(rawPlayerPresets) do
        local outfitSex = 'unisex'
        if type(p.outfit) == 'table' then
            outfitSex = getOutfitSex(p.outfit)
        end
        if sexAllowed(outfitSex, pedSex) then
            p.sex = outfitSex
            playerPresets[#playerPresets + 1] = p
        end
    end

    local allowed, allowedProps = nil, nil
    local clothingNames = Config.ClothingNames or { components = {}, props = {} }

    if mode == 'locker' and factionKey and Config.Factions[factionKey] then
        local fac = Config.Factions[factionKey]
        allowed = fac.allowed
        allowedProps = fac.allowedProps
        if fac.clothingNames then
            clothingNames = fac.clothingNames
        end
    end

    -- In locker mode we filter by ped sex so male clothes never appear for female peds (and vice versa).
    -- In characterisation mode we still normalise but do not drop items (filterSex = nil).
    local filterSex = (mode == 'locker') and pedSex or nil

    return {
        faceFeatures = Config.FaceFeatures,
        overlays = overlays,
        maxParentID = Config.MaxParentID,
        current = GetCurrentAppearance(),
        staffMode = staffMode,
        mode = mode,
        faction = factionKey,
        pedSex = pedSex,                     -- useful for NUI if needed later

        clothingComponents = Config.ClothingComponents,
        clothingProps = Config.ClothingProps,
        clothingLimits = clothingLimits,
        currentClothing = currentClothing,
        clothingNames = normalizeClothingNames(clothingNames, filterSex),
        presets = presets,
        playerPresets = playerPresets,

        allowed = allowed,
        allowedProps = allowedProps,
    }
end

--- Look up the configured sex for a catalog item. Returns 'unisex' if unknown.
local function getCatalogItemSex(isProp, slotId, collection, localDrawable)
    if not currentFaction or not Config.Factions[currentFaction] then
        return 'unisex'
    end
    local names = Config.Factions[currentFaction].clothingNames
    if not names then return 'unisex' end

    local bucket = isProp and names.props or names.components
    if type(bucket) ~= 'table' then return 'unisex' end

    local bySlot = bucket[tonumber(slotId)] or bucket[tostring(slotId)]
    if type(bySlot) ~= 'table' then return 'unisex' end

    local byCol = bySlot[collection or ''] or bySlot[tostring(collection or '')]
    if type(byCol) ~= 'table' then return 'unisex' end

    local raw = byCol[tonumber(localDrawable)] or byCol[tostring(localDrawable)]
    local resolved = resolveClothingEntry(raw)
    return (resolved and resolved.sex) or 'unisex'
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
        previousAppearance = DeepCopy(GetCurrentAppearance())
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
                Wait(400)

                ApplyFullAppearance(PlayerPedId(), data)
                Wait(100)
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
    -- Merge into existing blend so a partial payload cannot zero other fields
    local current = GetCurrentAppearance()
    local merged = current.headBlend or {}
    if type(data) == 'table' then
        for k, v in pairs(data) do
            merged[k] = v
        end
    end
    ApplyHeadBlend(PlayerPedId(), merged)
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

--- Re-checks a catalog-picked item's `sex` against the config on the client
--- (not just trusting whatever the NUI sent back), so a stale menu state or
--- tampered payload can't apply a wrong-sex item to the ped.
local function isAllowedSex(componentId, isProp, collection, localDrawable)
    local factionKey = GetCurrentLockerFaction()
    local names = (factionKey and Config.Factions[factionKey] and Config.Factions[factionKey].clothingNames)
        or Config.ClothingNames

    if not names then return true end

    local bucket = isProp and names.props or names.components
    local slot = bucket and bucket[componentId]
    local byCollection = slot and slot[collection or '']
    local entry = byCollection and byCollection[localDrawable]

    if type(entry) ~= 'table' or not entry.sex or entry.sex == 'unisex' then
        return true
    end

    return entry.sex == getPedSex(PlayerPedId())
end

RegisterNUICallback('component', function(data, cb)
    local ped = PlayerPedId()

    if data.useCollection then
        -- Re-check sex when applying a named catalog item (locker mode)
        if currentMode == 'locker' then
            local itemSex = getCatalogItemSex(false, data.id, data.collection, data.localDrawable or data.drawable)
            if not sexAllowed(itemSex, getPedSex(ped)) then
                lib.notify({
                    title = 'Locker',
                    description = 'This clothing is not available for your character.',
                    type = 'error'
                })
                cb({ clothing = GetCurrentClothing(ped), error = 'sex_mismatch' })
                return
            end
        end

        ApplyComponent(ped, data.id, {
            collection    = data.collection or '',
            localDrawable = tonumber(data.localDrawable or data.drawable) or 0,
            drawable      = tonumber(data.localDrawable or data.drawable) or 0,
            texture       = data.texture,
        })
    else
        ApplyComponent(ped, data.id, data.drawable, data.texture)
    end
    cb({ clothing = GetCurrentClothing(ped) })
end)

RegisterNUICallback('prop', function(data, cb)
    local ped = PlayerPedId()

    if data.useCollection then
        if currentMode == 'locker' then
            local itemSex = getCatalogItemSex(true, data.id, data.collection, data.localDrawable or data.drawable)
            if not sexAllowed(itemSex, getPedSex(ped)) then
                lib.notify({
                    title = 'Locker',
                    description = 'This clothing is not available for your character.',
                    type = 'error'
                })
                cb({ clothing = GetCurrentClothing(ped), error = 'sex_mismatch' })
                return
            end
        end

        ApplyProp(ped, data.id, {
            collection    = data.collection or '',
            localDrawable = tonumber(data.localDrawable or data.drawable) or -1,
            drawable      = tonumber(data.localDrawable or data.drawable) or -1,
            texture       = data.texture,
        })
    else
        ApplyProp(ped, data.id, data.drawable, data.texture)
    end
    cb({ clothing = GetCurrentClothing(ped) })
end)

RegisterNUICallback('getTextureMax', function(data, cb)
    local max = GetTextureMax(PlayerPedId(), data.isProp, data.id, data.drawable)
    cb({ max = max })
end)

RegisterNUICallback('applyPreset', function(data, cb)
    local name = data.name
    local ped = PlayerPedId()
    local pedSex = getPedSex(ped)
    local outfitToApply = nil

    if data.source == 'player' and type(data.outfit) == 'table' then
        outfitToApply = data.outfit
    elseif currentMode == 'locker' and currentFaction and Config.Factions[currentFaction] then
        outfitToApply = Config.Factions[currentFaction].presets and Config.Factions[currentFaction].presets[name]
    else
        outfitToApply = Config.ClothingPresets and Config.ClothingPresets[name]
    end

    if not outfitToApply then
        cb({ ok = false, error = true })
        return
    end

    local outfitSex = getOutfitSex(outfitToApply)
    if not sexAllowed(outfitSex, pedSex) then
        lib.notify({
            title = 'Outfit',
            description = ('This outfit is for %s characters only.'):format(outfitSex),
            type = 'error'
        })
        cb({ ok = false, error = 'sex_mismatch' })
        return
    end

    ApplyClothing(ped, outfitToApply)

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

    local outfit = getClothingWithSex(PlayerPedId())
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
        local pedSex = getPedSex(PlayerPedId())
        local filtered = {}
        for _, p in ipairs(list or {}) do
            local outfitSex = (type(p.outfit) == 'table') and getOutfitSex(p.outfit) or 'unisex'
            if sexAllowed(outfitSex, pedSex) then
                p.sex = outfitSex
                filtered[#filtered + 1] = p
            end
        end
        cb({ presets = filtered })
    end)
end)

RegisterNUICallback('createShareCode', function(_, cb)
    local outfit = getClothingWithSex(PlayerPedId())
    lib.callback('kyr_appearance:createShareCode', false, function(result)
        cb(result or { ok = false })
    end, outfit)
end)

RegisterNUICallback('redeemShareCode', function(data, cb)
    local code = data and data.code
    if type(code) ~= 'string' or code:gsub('%s+', '') == '' then
        cb({ ok = false, error = 'bad_code' })
        return
    end

    lib.callback('kyr_appearance:redeemShareCode', false, function(result)
        if not result or not result.ok or type(result.outfit) ~= 'table' then
            cb(result or { ok = false, error = 'not_found' })
            return
        end

        local ped = PlayerPedId()
        local outfitSex = getOutfitSex(result.outfit)
        if not sexAllowed(outfitSex, getPedSex(ped)) then
            lib.notify({
                title = 'Share Code',
                description = ('This outfit is for %s characters only.'):format(outfitSex),
                type = 'error'
            })
            cb({ ok = false, error = 'sex_mismatch' })
            return
        end

        ApplyClothing(ped, result.outfit)
        Wait(50)
        ped = PlayerPedId()
        cb({
            ok = true,
            code = result.code,
            clothing = GetCurrentClothing(ped),
            clothingLimits = GetClothingLimits(ped),
        })
    end, code)
end)

RegisterNUICallback('save', function(data, cb)
    local wasNewCharacter = newCharacterMode
    -- Capture a full snapshot (head blend + face + hair + clothing) before closing
    local snapshot = GetCurrentAppearance()
    SetCurrentAppearance(snapshot) -- also refreshes lastFullAppearance inside appearance.lua
    TriggerServerEvent('kyr_appearance:save', snapshot)
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
        local ped = PlayerPedId()
        ApplyFullAppearance(ped, previousAppearance)
        -- Re-apply head blend so skin tone doesn't drift after cancel
        if previousAppearance.headBlend then
            ApplyHeadBlend(ped, previousAppearance.headBlend)
            Wait(50)
            ApplyHeadBlend(ped, previousAppearance.headBlend)
        end
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

exports('ReapplyAppearance', function()
    local data = GetCurrentAppearance()
    if not data or not data.headBlend then return end
    ApplyHeadBlend(PlayerPedId(), data.headBlend)
    Wait(50)
    ApplyHeadBlend(PlayerPedId(), data.headBlend)
end)