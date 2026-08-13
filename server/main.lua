local Ox = require '@ox_core.lib.init'

CreateThread(function()
    -- Create table if it doesn't exist
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS character_appearance (
            charId INT UNSIGNED NOT NULL PRIMARY KEY,
            appearance LONGTEXT NOT NULL,
            completed TINYINT(1) NOT NULL DEFAULT 0,
            CONSTRAINT character_appearance_charId_fk
                FOREIGN KEY (charId) REFERENCES characters(charId)
                ON DELETE CASCADE ON UPDATE CASCADE
        )
    ]])

    -- Add the column if the table already existed without it
    pcall(function()
        MySQL.query.await([[
            ALTER TABLE character_appearance
            ADD COLUMN completed TINYINT(1) NOT NULL DEFAULT 0
        ]])
    end)

    -- Player-saved clothing presets (per character)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS character_clothing_presets (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            charId INT UNSIGNED NOT NULL,
            name VARCHAR(64) NOT NULL,
            outfit LONGTEXT NOT NULL,
            UNIQUE KEY character_clothing_presets_unique (charId, name),
            CONSTRAINT character_clothing_presets_charId_fk
                FOREIGN KEY (charId) REFERENCES characters(charId)
                ON DELETE CASCADE ON UPDATE CASCADE
        )
    ]])

    -- Shareable outfit codes (anyone with the code can apply the outfit)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS character_outfit_shares (
            code VARCHAR(12) NOT NULL PRIMARY KEY,
            outfit LONGTEXT NOT NULL,
            created_by INT UNSIGNED NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            uses INT UNSIGNED NOT NULL DEFAULT 0
        )
    ]])
end)

local function generateOutfitCode()
    local charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' -- no ambiguous 0/O/1/I
    local length = Config.ShareCodeLength or 8
    local code = {}
    for i = 1, length do
        local idx = math.random(1, #charset)
        code[i] = charset:sub(idx, idx)
    end
    return table.concat(code)
end

-- Returns the appearance ONLY if characterisation was finished
local function isRowCompleted(row)
    if not row then return false end
    local c = row.completed
    -- oxmysql can return tinyint as boolean, number, or string
    return c == true or c == 1 or c == '1'
end

lib.callback.register('kyr_appearance:getAppearance', function(source)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return nil end

    local row = MySQL.single.await(
        'SELECT appearance, completed FROM character_appearance WHERE charId = ?',
        { player.charId }
    )

    if row and row.appearance and isRowCompleted(row) then
        return json.decode(row.appearance)
    end

    return nil
end)

lib.callback.register('kyr_appearance:isCompleted', function(source)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return true end

    local row = MySQL.single.await(
        'SELECT completed FROM character_appearance WHERE charId = ?',
        { player.charId }
    )

    return isRowCompleted(row)
end)

lib.callback.register('kyr_appearance:checkPermission', function(source)
    return IsPlayerAceAllowed(source, Config.StaffAce)
end)

lib.callback.register('kyr_appearance:hasFaction', function(source, factionKey)
    local player = Ox.GetPlayer(source)
    if not player then return false end

    local faction = Config.Factions and Config.Factions[factionKey]
    if not faction then return false end

    for _, groupName in ipairs(faction.groups or {}) do
        local grade = player.getGroup(groupName)
        if grade and grade > 0 then
            return true
        end
    end

    return false
end)

RegisterNetEvent('kyr_appearance:enterEditor', function()
    local src = source
    SetPlayerRoutingBucket(src, Config.EditorRoutingBucketBase + src)
end)

RegisterNetEvent('kyr_appearance:exitEditor', function()
    local src = source
    SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket)
end)

-- THIS is the important part – sets completed = 1
RegisterNetEvent('kyr_appearance:save', function(appearance)
    local src = source
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then return end
    if type(appearance) ~= 'table' then return end

    local encoded = json.encode(appearance)

    MySQL.insert([[
        INSERT INTO character_appearance (charId, appearance, completed)
        VALUES (?, ?, 1)
        ON DUPLICATE KEY UPDATE
            appearance = VALUES(appearance),
            completed  = 1
    ]], {
        player.charId,
        encoded
    })
end)

-- -------------------- player clothing presets --------------------

lib.callback.register('kyr_appearance:getPlayerPresets', function(source)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return {} end

    local rows = MySQL.query.await(
        'SELECT name, outfit FROM character_clothing_presets WHERE charId = ? ORDER BY name ASC',
        { player.charId }
    ) or {}

    local list = {}
    for _, row in ipairs(rows) do
        local outfit = nil
        if type(row.outfit) == 'string' then
            outfit = json.decode(row.outfit)
        elseif type(row.outfit) == 'table' then
            outfit = row.outfit
        end
        if outfit then
            list[#list + 1] = { name = row.name, outfit = outfit, source = 'player' }
        end
    end
    return list
end)

lib.callback.register('kyr_appearance:savePlayerPreset', function(source, name, outfit)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return { ok = false, error = 'no_char' } end
    if type(name) ~= 'string' then return { ok = false, error = 'bad_name' } end

    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' or #name > 64 then return { ok = false, error = 'bad_name' } end
    if type(outfit) ~= 'table' then return { ok = false, error = 'bad_outfit' } end

    local maxPresets = Config.MaxPlayerPresets or 20
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM character_clothing_presets WHERE charId = ?',
        { player.charId }
    ) or 0

    local exists = MySQL.scalar.await(
        'SELECT 1 FROM character_clothing_presets WHERE charId = ? AND name = ?',
        { player.charId, name }
    )

    if not exists and count >= maxPresets then
        return { ok = false, error = 'limit', max = maxPresets }
    end

    MySQL.insert([[
        INSERT INTO character_clothing_presets (charId, name, outfit)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE outfit = VALUES(outfit)
    ]], {
        player.charId,
        name,
        json.encode(outfit)
    })

    return { ok = true, name = name }
end)

lib.callback.register('kyr_appearance:deletePlayerPreset', function(source, name)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return { ok = false } end
    if type(name) ~= 'string' or name == '' then return { ok = false } end

    MySQL.query.await(
        'DELETE FROM character_clothing_presets WHERE charId = ? AND name = ?',
        { player.charId, name }
    )
    return { ok = true }
end)

-- -------------------- share outfit codes --------------------

lib.callback.register('kyr_appearance:createShareCode', function(source, outfit)
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return { ok = false, error = 'no_char' } end
    if type(outfit) ~= 'table' then return { ok = false, error = 'bad_outfit' } end

    local code, attempts = nil, 0
    repeat
        code = generateOutfitCode()
        attempts = attempts + 1
        local exists = MySQL.scalar.await(
            'SELECT 1 FROM character_outfit_shares WHERE code = ?',
            { code }
        )
        if not exists then break end
        code = nil
    until attempts >= 12

    if not code then return { ok = false, error = 'gen_failed' } end

    MySQL.insert.await([[
        INSERT INTO character_outfit_shares (code, outfit, created_by)
        VALUES (?, ?, ?)
    ]], {
        code,
        json.encode(outfit),
        player.charId
    })

    return { ok = true, code = code }
end)

lib.callback.register('kyr_appearance:redeemShareCode', function(source, code)
    if type(code) ~= 'string' then return { ok = false, error = 'bad_code' } end
    code = code:gsub('%s+', ''):upper()
    if code == '' or #code > 16 then return { ok = false, error = 'bad_code' } end

    local row = MySQL.single.await(
        'SELECT outfit FROM character_outfit_shares WHERE code = ?',
        { code }
    )
    if not row or not row.outfit then
        return { ok = false, error = 'not_found' }
    end

    local outfit = row.outfit
    if type(outfit) == 'string' then
        outfit = json.decode(outfit)
    end
    if type(outfit) ~= 'table' then
        return { ok = false, error = 'bad_outfit' }
    end

    MySQL.update.await(
        'UPDATE character_outfit_shares SET uses = uses + 1 WHERE code = ?',
        { code }
    )

    return { ok = true, outfit = outfit, code = code }
end)