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
Config.RotateStep = 12.0  -- degrees per rotate tick (hold for continuous)
Config.MaxPlayerPresets = 20  -- max custom outfits a player can save
Config.ShareCodeLength = 8     -- length of shared outfit codes
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

-- Optional global / characterisation catalog (usually leave empty).
-- Locker menus use Config.Factions[faction].clothingNames instead.
-- Format: components[slot][collection][localDrawable] = "Display Name"
Config.ClothingNames = {
    components = {},
    props = {},
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
        -- Locker Clothing tab: only these named items (collection + local drawable)
        -- collection string must match /saveoutfit dump exactly (e.g. 'r4usarmyc3')
        clothingNames = {
            components = {
                -- [1]  = { -- Mask
                --     ['r4usarmyc3'] = {
                --         [0] = 'Example Mask',
                --     },
                -- },
                -- [3]  = { -- Arms / Torso
                -- },
                -- [4]  = { -- Legs
                -- },
                -- [5]  = { -- Bag / Parachute
                -- },
                -- [6]  = { -- Shoes
                -- },
                -- [7]  = { -- Accessories
                -- },
                -- [8]  = { -- Undershirt
                -- },
                -- [9]  = { -- Body Armor
                -- },
                -- [10] = { -- Decals
                -- },
                -- [11] = { -- Top / Jacket
                --     ['r4usarmyc3'] = {
                --         [0] = 'USMC Frogman [Wood Untucked]',
                --         [1] = 'USMC Frogman [Desert Untucked]',
                --     },
                -- },
            },
            props = {
                -- [0] = { -- Hat
                --     ['r4usarmyc3'] = {
                --         [0] = 'USMC Cap',
                --     },
                -- },
                -- [1] = { -- Glasses
                -- },
                -- [2] = { -- Ears
                -- },
                -- [6] = { -- Watch
                -- },
                -- [7] = { -- Bracelet
                -- },
            },
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
        clothingNames = {
            components = {
                [1] = { -- Mask
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Mask 0', [1] = 'US Army Mask 1',
                    },
                },
                [3] = { -- Arms / Torso
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Arms 0', [1] = 'US Army Arms 1',
                    },
                },
                [4] = { -- Legs
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Legs 0', [1] = 'US Army Legs 1', [2] = 'US Army Legs 2',
                    },
                },
                [5] = { -- Bag / Parachute
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Bag 0', [1] = 'US Army Bag 1', [2] = 'US Army Bag 2', [3] = 'US Army Bag 3',
                        [4] = 'US Army Bag 4', [5] = 'US Army Bag 5', [6] = 'US Army Bag 6',
                    },
                },
                [6] = { -- Shoes
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Shoes 0',
                    },
                },
                [7] = { -- Accessories
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Acc 0', [1] = 'US Army Acc 1', [2] = 'US Army Acc 2', [3] = 'US Army Acc 3',
                        [4] = 'US Army Acc 4', [5] = 'US Army Acc 5', [6] = 'US Army Acc 6', [7] = 'US Army Acc 7',
                        [8] = 'US Army Acc 8', [9] = 'US Army Acc 9', [10] = 'US Army Acc 10',
                    },
                },
                [8] = { -- Undershirt
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Undershirt 0', [1] = 'US Army Undershirt 1', [2] = 'US Army Undershirt 2', [3] = 'US Army Undershirt 3',
                        [4] = 'US Army Undershirt 4', [5] = 'US Army Undershirt 5', [6] = 'US Army Undershirt 6', [7] = 'US Army Undershirt 7',
                        [8] = 'US Army Undershirt 8', [9] = 'US Army Undershirt 9', [10] = 'US Army Undershirt 10', [11] = 'US Army Undershirt 11',
                        [12] = 'US Army Undershirt 12', [13] = 'US Army Undershirt 13',
                    },
                },
                [9] = { -- Body Armor
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Vest 0', [1] = 'US Army Vest 1', [2] = 'US Army Vest 2', [3] = 'US Army Vest 3',
                        [4] = 'US Army Vest 4',
                    },
                },
                [10] = { -- Decals
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Decal 0', [1] = 'US Army Decal 1', [2] = 'US Army Decal 2', [3] = 'US Army Decal 3',
                        [4] = 'US Army Decal 4', [5] = 'US Army Decal 5', [6] = 'US Army Decal 6', [7] = 'US Army Decal 7',
                        [8] = 'US Army Decal 8', [9] = 'US Army Decal 9', [10] = 'US Army Decal 10', [11] = 'US Army Decal 11',
                        [12] = 'US Army Decal 12', [13] = 'US Army Decal 13', [14] = 'US Army Decal 14', [15] = 'US Army Decal 15',
                        [16] = 'US Army Decal 16', [17] = 'US Army Decal 17', [18] = 'US Army Decal 18', [19] = 'US Army Decal 19',
                        [20] = 'US Army Decal 20', [21] = 'US Army Decal 21', [22] = 'US Army Decal 22', [23] = 'US Army Decal 23',
                        [24] = 'US Army Decal 24', [25] = 'US Army Decal 25', [26] = 'US Army Decal 26', [27] = 'US Army Decal 27',
                        [28] = 'US Army Decal 28', [29] = 'US Army Decal 29', [30] = 'US Army Decal 30', [31] = 'US Army Decal 31',
                        [32] = 'US Army Decal 32', [33] = 'US Army Decal 33', [34] = 'US Army Decal 34', [35] = 'US Army Decal 35',
                        [36] = 'US Army Decal 36', [37] = 'US Army Decal 37', [38] = 'US Army Decal 38', [39] = 'US Army Decal 39',
                        [40] = 'US Army Decal 40',
                    },
                },
                [11] = { -- Top / Jacket
                    ['r4usarmyv3'] = {
                        [0] = '[ACU] OCP Coat | Untucked', [1] = '[ACU] OCP Coat | Untucked | Sleeves', [2] = '[ACU] OCP Coat | Tucked', [3] = '[ACU] OCP Coat | Tucked | Sleeves',
                        [4] = '[IHWCU] OCP Coat | Untucked', [5] = '[IHWCU] OCP Coat | Untucked | Sleeves', [6] = '[IHWCU] OCP Coat | Tucked', [7] = '[IHWCU] OCP Coat | Tucked | Sleeves',
                        [8] = '[ACU] OCP Combat Shirt', [9] = '[ACU] OCP Combat Shirt | Unzipped',
                    },
                },
            },
            props = {
                [0] = { -- Hat
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Hat 0', [1] = 'US Army Hat 1', [2] = 'US Army Hat 2', [3] = 'US Army Hat 3',
                        [4] = 'US Army Hat 4', [5] = 'US Army Hat 5', [6] = 'US Army Hat 6', [7] = 'US Army Hat 7',
                        [8] = 'US Army Hat 8', [9] = 'US Army Hat 9', [10] = 'US Army Hat 10', [11] = 'US Army Hat 11',
                        [12] = 'US Army Hat 12', [13] = 'US Army Hat 13', [14] = 'US Army Hat 14', [15] = 'US Army Hat 15',
                        [16] = 'US Army Hat 16',
                    },
                },
                [1] = { -- Glasses
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Glasses 0', [1] = 'US Army Glasses 1', [2] = 'US Army Glasses 2', [3] = 'US Army Glasses 3',
                        [4] = 'US Army Glasses 4', [5] = 'US Army Glasses 5', [6] = 'US Army Glasses 6',
                    },
                },
                [2] = { -- Ears
                    ['r4usarmyv3'] = {
                        [0] = 'US Army Ears 0', [1] = 'US Army Ears 1', [2] = 'US Army Ears 2', [3] = 'US Army Ears 3',
                        [4] = 'US Army Ears 4', [5] = 'US Army Ears 5', [6] = 'US Army Ears 6',
                    },
                },
            },
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
        clothingNames = {
            components = {},
            props = {},
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