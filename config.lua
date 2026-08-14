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
        --
        -- Each item is { label = "Display Name", sex = 'male' | 'female' | 'unisex' }.
        -- `sex` controls who sees the item in the locker menu at all (filtered
        -- client-side before the NUI even renders it), and is re-checked when the
        -- item is applied. Omitting `sex` (or using a bare string like older
        -- configs did) defaults to 'unisex'.
        clothingNames = {
            components = {
                -- [1]  = { -- Mask
                --     ['r4usarmyc3'] = {
                --         [0] = { label = 'Example Mask', sex = 'unisex' },
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
                --         [0] = { label = 'USMC Frogman [Wood Untucked]', sex = 'male' },
                --         [1] = { label = 'USMC Frogman [Desert Untucked]', sex = 'male' },
                --         [5] = { label = 'USMC Frogman [Wood Untucked]', sex = 'female' },
                --     },
                -- },
            },
            props = {
                -- [0] = { -- Hat
                --     ['r4usarmyc3'] = {
                --         [0] = { label = 'USMC Cap', sex = 'unisex' },
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
                        [0] = { label = 'US Army Mask 0', sex = 'male' }, [1] = { label = 'US Army Mask 1', sex = 'male' },
                    },
                },
                [3] = { -- Arms / Torso
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Arms 0', sex = 'male' }, [1] = { label = 'US Army Arms 1', sex = 'male' },
                    },
                },
                [4] = { -- Legs
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Legs 0', sex = 'male' }, [1] = { label = 'US Army Legs 1', sex = 'male' }, [2] = { label = 'US Army Legs 2', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' }, [1] = { label = '', sex = 'male' },
                    },
                },
                [5] = { -- Bag / Parachute
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Bag 0', sex = 'male' }, [1] = { label = 'US Army Bag 1', sex = 'male' }, [2] = { label = 'US Army Bag 2', sex = 'male' }, [3] = { label = 'US Army Bag 3', sex = 'male' },
                        [4] = { label = 'US Army Bag 4', sex = 'male' }, [5] = { label = 'US Army Bag 5', sex = 'male' }, [6] = { label = 'US Army Bag 6', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' }, [1] = { label = '', sex = 'male' }, [2] = { label = '', sex = 'male' }, [3] = { label = '', sex = 'male' }, [4] = { label = '', sex = 'male' },
                    },
                },
                [6] = { -- Shoes
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Shoes 0', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' }, 
                    },
                },
                [7] = { -- Accessories
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Acc 0', sex = 'male' }, [1] = { label = 'US Army Acc 1', sex = 'male' }, [2] = { label = 'US Army Acc 2', sex = 'male' }, [3] = { label = 'US Army Acc 3', sex = 'male' },
                        [4] = { label = 'US Army Acc 4', sex = 'male' }, [5] = { label = 'US Army Acc 5', sex = 'male' }, [6] = { label = 'US Army Acc 6', sex = 'male' }, [7] = { label = 'US Army Acc 7', sex = 'male' },
                        [8] = { label = 'US Army Acc 8', sex = 'male' }, [9] = { label = 'US Army Acc 9', sex = 'male' }, [10] = { label = 'US Army Acc 10', sex = 'male' },
                    },
                },
                [8] = { -- Undershirt
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Undershirt 0', sex = 'male' }, [1] = { label = 'US Army Undershirt 1', sex = 'male' }, [2] = { label = 'US Army Undershirt 2', sex = 'male' }, [3] = { label = 'US Army Undershirt 3', sex = 'male' },
                        [4] = { label = 'US Army Undershirt 4', sex = 'male' }, [5] = { label = 'US Army Undershirt 5', sex = 'male' }, [6] = { label = 'US Army Undershirt 6', sex = 'male' }, [7] = { label = 'US Army Undershirt 7', sex = 'male' },
                        [8] = { label = 'US Army Undershirt 8', sex = 'male' }, [9] = { label = 'US Army Undershirt 9', sex = 'male' }, [10] = { label = 'US Army Undershirt 10', sex = 'male' }, [11] = { label = 'US Army Undershirt 11', sex = 'male' },
                        [12] = { label = 'US Army Undershirt 12', sex = 'male' }, [13] = { label = 'US Army Undershirt 13', sex = 'male' },
                    },
                },
                [9] = { -- Body Armor
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Vest 0', sex = 'male' }, [1] = { label = 'US Army Vest 1', sex = 'male' }, [2] = { label = 'US Army Vest 2', sex = 'male' }, [3] = { label = 'US Army Vest 3', sex = 'male' },
                        [4] = { label = 'US Army Vest 4', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' },
                    },
                },
                [10] = { -- Decals
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Decal 0', sex = 'male' }, [1] = { label = 'US Army Decal 1', sex = 'male' }, [2] = { label = 'US Army Decal 2', sex = 'male' }, [3] = { label = 'US Army Decal 3', sex = 'male' },
                        [4] = { label = 'US Army Decal 4', sex = 'male' }, [5] = { label = 'US Army Decal 5', sex = 'male' }, [6] = { label = 'US Army Decal 6', sex = 'male' }, [7] = { label = 'US Army Decal 7', sex = 'male' },
                        [8] = { label = 'US Army Decal 8', sex = 'male' }, [9] = { label = 'US Army Decal 9', sex = 'male' }, [10] = { label = 'US Army Decal 10', sex = 'male' }, [11] = { label = 'US Army Decal 11', sex = 'male' },
                        [12] = { label = 'US Army Decal 12', sex = 'male' }, [13] = { label = 'US Army Decal 13', sex = 'male' }, [14] = { label = 'US Army Decal 14', sex = 'male' }, [15] = { label = 'US Army Decal 15', sex = 'male' },
                        [16] = { label = 'US Army Decal 16', sex = 'male' }, [17] = { label = 'US Army Decal 17', sex = 'male' }, [18] = { label = 'US Army Decal 18', sex = 'male' }, [19] = { label = 'US Army Decal 19', sex = 'male' },
                        [20] = { label = 'US Army Decal 20', sex = 'male' }, [21] = { label = 'US Army Decal 21', sex = 'male' }, [22] = { label = 'US Army Decal 22', sex = 'male' }, [23] = { label = 'US Army Decal 23', sex = 'male' },
                        [24] = { label = 'US Army Decal 24', sex = 'male' }, [25] = { label = 'US Army Decal 25', sex = 'male' }, [26] = { label = 'US Army Decal 26', sex = 'male' }, [27] = { label = 'US Army Decal 27', sex = 'male' },
                        [28] = { label = 'US Army Decal 28', sex = 'male' }, [29] = { label = 'US Army Decal 29', sex = 'male' }, [30] = { label = 'US Army Decal 30', sex = 'male' }, [31] = { label = 'US Army Decal 31', sex = 'male' },
                        [32] = { label = 'US Army Decal 32', sex = 'male' }, [33] = { label = 'US Army Decal 33', sex = 'male' }, [34] = { label = 'US Army Decal 34', sex = 'male' }, [35] = { label = 'US Army Decal 35', sex = 'male' },
                        [36] = { label = 'US Army Decal 36', sex = 'male' }, [37] = { label = 'US Army Decal 37', sex = 'male' }, [38] = { label = 'US Army Decal 38', sex = 'male' }, [39] = { label = 'US Army Decal 39', sex = 'male' },
                        [40] = { label = 'US Army Decal 40', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' }, [1] = { label = '', sex = 'male' }, [2] = { label = '', sex = 'male' },
                    },
                },
                [11] = { -- Top / Jacket
                    ['r4usarmyv3'] = {
                        [0] = { label = '[ACU] OCP COAT | UNTUCKED', sex = 'male' }, [1] = { label = '[ACU] OCP COAT | UNTUCKED | SLEEVES', sex = 'male' }, [2] = { label = '[ACU] OCP COAT | TUCKED', sex = 'male' }, [3] = { label = '[ACU] OCP COAT | TUCKED | SLEEVES', sex = 'male' },
                        [4] = { label = '[IHWCU] OCP COAT | UNTUCKED', sex = 'male' }, [5] = { label = '[IHWCU] OCP COAT | UNTUCKED | SLEEVES', sex = 'male' }, [6] = { label = '[IHWCU] OCP COAT | TUCKED', sex = 'male' }, [7] = { label = '[IHWCU] OCP COAT | TUCKED | SLEEVES', sex = 'male' },
                        [8] = { label = '[ACU] OCP COMBAT SHIRT | ZIPPED', sex = 'male' }, [9] = { label = '[IHWCU] OCP COMBAT SHIRT | UNZIPPED', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' }, [1] = { label = '', sex = 'male' },
                    },
                },
            },
            props = {
                [0] = { -- Hat
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Hat 0', sex = 'male' }, [1] = { label = 'US Army Hat 1', sex = 'male' }, [2] = { label = 'US Army Hat 2', sex = 'male' }, [3] = { label = 'US Army Hat 3', sex = 'male' },
                        [4] = { label = 'US Army Hat 4', sex = 'male' }, [5] = { label = 'US Army Hat 5', sex = 'male' }, [6] = { label = 'US Army Hat 6', sex = 'male' }, [7] = { label = 'US Army Hat 7', sex = 'male' },
                        [8] = { label = 'US Army Hat 8', sex = 'male' }, [9] = { label = 'US Army Hat 9', sex = 'male' }, [10] = { label = 'US Army Hat 10', sex = 'male' }, [11] = { label = 'US Army Hat 11', sex = 'male' },
                        [12] = { label = 'US Army Hat 12', sex = 'male' }, [13] = { label = 'US Army Hat 13', sex = 'male' }, [14] = { label = 'US Army Hat 14', sex = 'male' }, [15] = { label = 'US Army Hat 15', sex = 'male' },
                        [16] = { label = 'US Army Hat 16', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' }, [1] = { label = '', sex = 'male' }, 
                    },
                },
                [1] = { -- Glasses
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Glasses 0', sex = 'male' }, [1] = { label = 'US Army Glasses 1', sex = 'male' }, [2] = { label = 'US Army Glasses 2', sex = 'male' }, [3] = { label = 'US Army Glasses 3', sex = 'male' },
                        [4] = { label = 'US Army Glasses 4', sex = 'male' }, [5] = { label = 'US Army Glasses 5', sex = 'male' }, [6] = { label = 'US Army Glasses 6', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' }, [1] = { label = '', sex = 'male' }, [2] = { label = '', sex = 'male' }, [3] = { label = '', sex = 'male' }, [4] = { label = '', sex = 'male' },
                    },
                },
                [2] = { -- Ears
                    ['r4usarmyv3'] = {
                        [0] = { label = 'US Army Ears 0', sex = 'male' }, [1] = { label = 'US Army Ears 1', sex = 'male' }, [2] = { label = 'US Army Ears 2', sex = 'male' }, [3] = { label = 'US Army Ears 3', sex = 'male' },
                        [4] = { label = 'US Army Ears 4', sex = 'male' }, [5] = { label = 'US Army Ears 5', sex = 'male' }, [6] = { label = 'US Army Ears 6', sex = 'male' },
                    },
                    ['r4cryeg3'] = {
                        [0] = { label = '', sex = 'male' }, [1] = { label = '', sex = 'male' }, 
                    },
                },
            },
        },
        presets = {
            -- Legacy global indexes below still apply, but re-run /saveoutfit
            -- while wearing the outfit to convert to collection-stable form.
            ['usarmy_base'] = {
                sex = 'male',
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