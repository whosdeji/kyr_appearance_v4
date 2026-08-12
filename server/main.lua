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
end)

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

    print(('[kyr_appearance] charId=%s completed=%s type=%s'):format(
        tostring(player.charId),
        tostring(row and row.completed),
        type(row and row.completed)
    ))

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