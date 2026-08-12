Config = {}

-- Where the player is teleported to while the menu is open. w = heading.
Config.EditorCoords = vector4(402.915, -996.429, -99.000, 90.0)

-- Where a BRAND NEW character is sent once they confirm their appearance for
-- the first time (staff using /characterisation are sent back to wherever
-- they were instead - see Config.EditorCoords flow in client/main.lua).
-- TODO: point this at your server's actual default spawn.
Config.PostCreationSpawn = vector4(-269.4, -955.3, 31.2, 205.0)

-- Routing buckets keep anyone inside the characterisation zone invisible to
-- (and unable to see) the rest of the server, including other players who
-- are also customising at the same time.
Config.DefaultRoutingBucket = 0
Config.EditorRoutingBucketBase = 100000 -- actual bucket used is this + player server id

-- Camera zoom limits (distance in units from the head bone)
Config.MinZoom = 0.5
Config.MaxZoom = 2.5
Config.DefaultZoom = 1.4
Config.RotateStep = 6.0   -- degrees per button press
Config.ZoomStep = 0.15

-- ACE permission required to run /characterisation
Config.StaffAce = 'characterisation.use'

Config.Models = {
    male = `mp_m_freemode_01`,
    female = `mp_f_freemode_01`
}

-- Heritage / parent blend range. Freemode models safely support 0-45.
Config.MaxParentID = 45

-- SetPedFaceFeature indices -> friendly labels. Range is -1.0 to 1.0.
Config.FaceFeatures = {
    [0]  = 'Nose Width',
    [1]  = 'Nose Peak Height',
    [2]  = 'Nose Peak Length',
    [3]  = 'Nose Bone Height',
    [4]  = 'Nose Peak Lowering',
    [5]  = 'Nose Bone Twist',
    [6]  = 'Eyebrow Height',
    [7]  = 'Eyebrow Forward',
    [8]  = 'Cheek Bone Height',
    [9]  = 'Cheek Bone Width',
    [10] = 'Cheek Width',
    [11] = 'Eyes Opening',
    [12] = 'Lips Thickness',
    [13] = 'Jaw Bone Width',
    [14] = 'Jaw Bone Backward',
    [15] = 'Chin Bone Lowering',
    [16] = 'Chin Bone Length',
    [17] = 'Chin Bone Width',
    [18] = 'Chin Hole',
    [19] = 'Neck Thickness'
}

-- SetPedHeadOverlay / SetPedHeadOverlayColor targets.
-- `max` per overlay is read at runtime from GetNumHeadOverlayValues, not hardcoded here.
Config.HeadOverlays = {
    { id = 0,  key = 'blemishes',     label = 'Blemishes' },
    { id = 1,  key = 'beard',         label = 'Facial Hair',      hasColor = true },
    { id = 2,  key = 'eyebrows',      label = 'Eyebrows',         hasColor = true },
    { id = 3,  key = 'ageing',        label = 'Ageing' },
    { id = 4,  key = 'makeup',        label = 'Makeup',           hasColor = true },
    { id = 5,  key = 'blush',         label = 'Blush',            hasColor = true },
    { id = 6,  key = 'complexion',    label = 'Complexion' },
    { id = 7,  key = 'sundamage',     label = 'Sun Damage' },
    { id = 8,  key = 'lipstick',      label = 'Lipstick',         hasColor = true },
    { id = 9,  key = 'moles',         label = 'Moles / Freckles' },
    { id = 10, key = 'chesthair',     label = 'Chest Hair',       hasColor = true },
    { id = 11, key = 'bodyblemishes', label = 'Body Blemishes' },
}
-- ============================================================
-- Clothing
-- ============================================================

Config.ClothingComponents = {
    { id = 1,  label = 'Mask' },
    { id = 3,  label = 'Arms / Torso' },
    { id = 4,  label = 'Legs' },
    { id = 5,  label = 'Bag / Parachute' },
    { id = 6,  label = 'Shoes' },
    { id = 7,  label = 'Accessories' },
    { id = 8,  label = 'Undershirt' },
    { id = 9,  label = 'Body Armor' },
    { id = 10, label = 'Decals' },
    { id = 11, label = 'Top / Jacket' },
}

Config.ClothingProps = {
    { id = 0, label = 'Hat' },
    { id = 1, label = 'Glasses' },
    { id = 2, label = 'Ears' },
    { id = 6, label = 'Watch' },
    { id = 7, label = 'Bracelet' },
}

-- Paste output from /saveoutfit here.
-- Preferred (stable) format uses collection + local drawable:
--   [11] = { collection = "mp_m_freemode_01_mp_m_yourpack", drawable = 12, texture = 0 },
-- Legacy format still works but WILL shift when you add new streamed EUP:
--   [11] = { drawable = 548, texture = 0 },
Config.ClothingPresets = {
    -- Example (collection-stable):
    -- ['default_male'] = {
    --     components = {
    --         [3]  = { collection = "", drawable = 15, texture = 0 },
    --         [4]  = { collection = "", drawable = 21, texture = 0 },
    --         [6]  = { collection = "", drawable = 34, texture = 0 },
    --         [8]  = { collection = "", drawable = 15, texture = 0 },
    --         [11] = { collection = "", drawable = 15, texture = 0 },
    --     },
    --     props = {}
    -- },
}
-- ============================================================
-- Factions & Lockers
-- ============================================================

Config.Factions = {
    usmarines = {
        label = '31st Marine Expeditionary Unit',
        groups = { 'usmarines' },          -- ox_core group name(s)
        -- allowed component ranges (drawable min/max). texture usually 0-max
        allowed = {
            -- componentId = { minDrawable = 0, maxDrawable = 999 }  -- 999 = no real limit
            [1]  = { min = 0, max = 200 },   -- Mask
            [3]  = { min = 0, max = 200 },   -- Arms
            [4]  = { min = 0, max = 200 },   -- Legs
            [5]  = { min = 0, max = 100 },   -- Bag
            [6]  = { min = 0, max = 200 },   -- Shoes
            [7]  = { min = 0, max = 200 },   -- Accessories
            [8]  = { min = 0, max = 200 },   -- Undershirt
            [9]  = { min = 0, max = 100 },   -- Armor / Vest
            [10] = { min = 0, max = 100 },   -- Decals
            [11] = { min = 0, max = 400 },   -- Top / Jacket
        },
        allowedProps = {
            [0] = { min = -1, max = 200 },  -- Hat
            [1] = { min = -1, max = 50 },   -- Glasses
            [2] = { min = -1, max = 50 },   -- Ears
            [6] = { min = -1, max = 50 },   -- Watch
            [7] = { min = -1, max = 50 },   -- Bracelet
        },
        presets = {
            -- paste /saveoutfit results here, e.g.:
            -- ['Recruit'] = { components = {...}, props = {...} },
            -- ['Rifleman'] = { ... },
        }
    },

    usarmy = {
        label = '82nd Airborne Division',
        groups = { 'usarmy' },
        allowed = {
            [1]  = { min = 0, max = 200 },
            [3]  = { min = 0, max = 200 },
            [4]  = { min = 0, max = 200 },
            [5]  = { min = 0, max = 100 },
            [6]  = { min = 0, max = 200 },
            [7]  = { min = 0, max = 200 },
            [8]  = { min = 0, max = 200 },
            [9]  = { min = 0, max = 100 },
            [10] = { min = 0, max = 100 },
            [11] = { min = 0, max = 400 },
        },
        allowedProps = {
            [0] = { min = -1, max = 200 },
            [1] = { min = -1, max = 50 },
            [2] = { min = -1, max = 50 },
            [6] = { min = -1, max = 50 },
            [7] = { min = -1, max = 50 },
        },
        presets = {
            -- Legacy global indexes below still apply, but re-run /saveoutfit
            -- while wearing the outfit to convert to collection-stable form.
            ['usarmy_base'] = {
                components = {
                    [1] = { drawable = 0, texture = 0 },
                    [3] = { drawable = 0, texture = 0 },
                    [4] = { drawable = 204, texture = 0 },
                    [5] = { drawable = 0, texture = 0 },
                    [6] = { drawable = 151, texture = 0 },
                    [7] = { drawable = 0, texture = 0 },
                    [8] = { drawable = 15, texture = 0 },
                    [9] = { drawable = 0, texture = 0 },
                    [10] = { drawable = 211, texture = 22 },
                    [11] = { drawable = 548, texture = 0 },
                },

                props = {
                    [0] = { drawable = -1, texture = 0 },
                    [1] = { drawable = -1, texture = 0 },
                    [2] = { drawable = -1, texture = 0 },
                    [6] = { drawable = -1, texture = 0 },
                    [7] = { drawable = -1, texture = 0 },
                }
            }
        }
    },

    cdv = {
        label = 'Cartel del Valencia',
        groups = { 'cdv' },
        allowed = {
            [1]  = { min = 0, max = 200 },
            [3]  = { min = 0, max = 200 },
            [4]  = { min = 0, max = 200 },
            [5]  = { min = 0, max = 100 },
            [6]  = { min = 0, max = 200 },
            [7]  = { min = 0, max = 200 },
            [8]  = { min = 0, max = 200 },
            [9]  = { min = 0, max = 100 },
            [10] = { min = 0, max = 100 },
            [11] = { min = 0, max = 400 },
        },
        allowedProps = {
            [0] = { min = -1, max = 200 },
            [1] = { min = -1, max = 50 },
            [2] = { min = -1, max = 50 },
            [6] = { min = -1, max = 50 },
            [7] = { min = -1, max = 50 },
        },
        presets = {}
    },
}

-- Locker locations (ox_target). Fill these in.
-- type = faction key from Config.Factions
Config.Lockers = {
    {
        faction = 'usmarines',
        label = 'MEU Locker',
        coords = vector3(0.0, 0.0, 0.0),   -- << change me
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0.0,
        -- Optional: future per-faction editor room
        -- editorCoords = vector4(x, y, z, heading),
    },
    {
        faction = 'usarmy',
        label = '82nd Locker',
        coords = vec3(456.763, -987.972, 30.401),   -- << change me
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0.0,
    },
    {
        faction = 'cdv',
        label = 'CDV Locker',
        coords = vector3(0.0, 0.0, 0.0),   -- << change me
        size = vec3(1.5, 1.5, 2.0),
        rotation = 0.0,
    },
}