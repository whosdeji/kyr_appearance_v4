local currentLockerFaction = nil

local function openLocker(factionKey)
    if menuOpen then return end

    local hasAccess = lib.callback.await('kyr_appearance:hasFaction', false, factionKey)
    if not hasAccess then
        lib.notify({
            title = 'Locker',
            description = 'You do not have access to this locker.',
            type = 'error'
        })
        return
    end

    currentLockerFaction = factionKey

    OpenAppearanceMenu(false, false, nil, {
        mode = 'locker',
        faction = factionKey
    })
end

CreateThread(function()
    for i, locker in ipairs(Config.Lockers or {}) do
        exports.ox_target:addBoxZone({
            coords = locker.coords,
            size = locker.size or vec3(1.5, 1.5, 2.0),
            rotation = locker.rotation or 0.0,
            debug = false,
            options = {
                {
                    name = ('kyr_locker_%s'):format(i),
                    icon = 'fa-solid fa-shirt',
                    label = locker.label or 'Open Locker',
                    onSelect = function()
                        openLocker(locker.faction)
                    end,
                    canInteract = function()
                        return not menuOpen
                    end
                }
            }
        })
    end
end)

function GetCurrentLockerFaction()
    return currentLockerFaction
end

function ClearLockerFaction()
    currentLockerFaction = nil
end