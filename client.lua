local ox_inventory = exports.ox_inventory
local currentZone = nil
local ticketTimeRemaining = 0
local stressReductionInterval = false
local display = false

-- Debug function
local function DebugPrint(level, message)
    if Config.Debug.enabled and Config.Debug.level >= level then
        print("[CE-BaseZone Debug] " .. message)
    end
end

-- Función para traducir textos
local function Translate(category, key, ...)
    local lang = Config.Locale
    if Config.Translations[lang] and Config.Translations[lang][category] and Config.Translations[lang][category][key] then
        return string.format(Config.Translations[lang][category][key], ...)
    end
    return "Translation missing: " .. category .. "." .. key
end

-- Función para obtener el nivel del jugador
local function GetPlayerLevel()
    local playerLevel = 0
    for _, system in ipairs(Config.ExperienceSystems) do
        local level = system.getLevel()
        if level > playerLevel then
            playerLevel = level
        end
    end
    DebugPrint(1, "Player level: " .. playerLevel) -- Mensaje de depuración
    return playerLevel
end

-- Función para verificar el acceso del jugador a una zona
local function CheckPlayerAccess(zone)
    local playerLevel = GetPlayerLevel()
    DebugPrint(1, "Checking player access for zone: " .. zone.name .. " with player level: " .. playerLevel) -- Mensaje de depuración

    if playerLevel >= zone.requiredLevel then
        return true, 'ticket_required'
    end

    if IsPedInAnyVehicle(PlayerPedId(), false) and ticketTimeRemaining <= 0 then
        return false, Translate('interaction', 'vehicle_not_allowed')
    end

    return true
end

-- Función para teletransportar al jugador fuera de la zona
local function TeleportOutOfZone(coords)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    DoScreenFadeOut(1000)
    Citizen.Wait(1000)

    if vehicle ~= 0 then
        SetEntityCoords(vehicle, coords.x, coords.y, coords.z)
        SetEntityHeading(vehicle, coords.w)
    else
        SetEntityCoords(playerPed, coords.x, coords.y, coords.z)
        SetEntityHeading(playerPed, coords.w)
    end

    Citizen.Wait(1000)
    DoScreenFadeIn(1000)

    lib.notify({
        title = Translate('interaction', 'teleporting'),
        type = 'info',
        duration = 5000
    })
    DebugPrint(1, "Player teleported out of the zone.")
end

-- Función para iniciar la reducción de estrés
local function StartStressReduction(zone)
    if zone.stressReductionEnabled and not stressReductionInterval then
        stressReductionInterval = true
        CreateThread(function()
            while stressReductionInterval do
                TriggerServerEvent('ce-basezone:reduceStress', zone.stressReduction.amount, zone.name)
                lib.notify({
                    title = Translate('interaction', 'stress_reduced'),
                    type = 'success',
                    duration = 3000
                })
                Wait(zone.stressReduction.interval)
            end
        end)
    end
end

-- Función para detener la reducción de estrés
local function StopStressReduction()
    stressReductionInterval = false
end

function ShowTimeRemaining(time)
    if not display then
        display = true
        SetNuiFocus(false, false)
        SendNUIMessage({
            type = "updateTimer",
            time = time
        })
    else
        SendNUIMessage({
            type = "updateTimer",
            time = time
        })
    end
end

function HideTimeRemaining()
    display = false
    SendNUIMessage({
        type = "updateTimer",
        time = 0
    })
end

-- Create PolyZone for each zone
local polyZones = {}
Citizen.CreateThread(function()
    for _, zone in ipairs(Config.Zones) do
        local poly = PolyZone:Create(zone.points, {
            name = zone.name,
            minZ = zone.minZ,
            maxZ = zone.maxZ,
            debugGrid = Config.Debug.showPolyZones,
            debugColor = {0, 255, 0},
            gridDivisions = 25
        })
        polyZones[zone.name] = poly
        DebugPrint(1, "Created PolyZone for " .. zone.name)
    end
end)

-- Bucle principal para verificar la posición del jugador
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local inAnyZone = false

        local playerLevel = GetPlayerLevel()

        for _, zone in ipairs(Config.Zones) do
            if polyZones[zone.name]:isPointInside(playerCoords) then
                inAnyZone = true
                if currentZone ~= zone.name then
                    currentZone = zone.name
                    DebugPrint(2, "Player entered new zone: " .. zone.name)
                    TriggerServerEvent('ce-basezone:playerEnterZone', zone.name, playerLevel)
                    local hasAccess, message = CheckPlayerAccess(zone)
                    if not hasAccess then
                        DebugPrint(2, "Player doesn't have access to zone: " .. zone.name)
                        TriggerServerEvent('ce-basezone:requestAccessDenied', zone.name, playerLevel)
                        lib.notify({
                            title = message,
                            type = 'error',
                            duration = 5000
                        })
                        TeleportOutOfZone(zone.teleportOutCoords)
                    else
                        DebugPrint(2, "Player granted access to zone: " .. zone.name)
                        if message == 'ticket_required' then
                            TriggerServerEvent('ce-basezone:checkTicket', zone.name)
                        else
                            StartStressReduction(zone)
                        end
                    end
                end

                if ticketTimeRemaining > 0 then
                    ticketTimeRemaining = ticketTimeRemaining - 1
                    ShowTimeRemaining(ticketTimeRemaining)
                    DebugPrint(3, "Ticket time remaining: " .. ticketTimeRemaining .. " seconds")
                    if ticketTimeRemaining == 0 then
                        DebugPrint(2, "Ticket expired, teleporting player out of zone: " .. zone.name)
                        TeleportOutOfZone(zone.teleportOutCoords)
                        StopStressReduction()
                        TriggerServerEvent('ce-basezone:updateTicketTime', zone.name, 0)
                        HideTimeRemaining()
                    else
                        TriggerServerEvent('ce-basezone:updateTicketTime', zone.name, ticketTimeRemaining)
                    end
                else
                    HideTimeRemaining()
                end

                break
            end
        end

        if not inAnyZone and currentZone then
            DebugPrint(2, "Player exited zone: " .. currentZone)
            TriggerServerEvent('ce-basezone:playerExitZone', currentZone)
            currentZone = nil
            StopStressReduction()
            HideTimeRemaining()
            ticketTimeRemaining = 0
        end
    end
end)

-- Crear blips para las zonas
Citizen.CreateThread(function()
    for _, zone in ipairs(Config.Zones) do
        if zone.blip.enabled then
            local blip = AddBlipForCoord(zone.core.coords.x, zone.core.coords.y, zone.core.coords.z)
            SetBlipSprite(blip, zone.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, zone.blip.scale)
            SetBlipColour(blip, zone.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(zone.blip.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Crear NPCs para las zonas
Citizen.CreateThread(function()
    for _, zone in ipairs(Config.Zones) do
        local model = GetHashKey(zone.core.model)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Citizen.Wait(1)
        end

        local npc = CreatePed(4, model, zone.core.coords.x, zone.core.coords.y, zone.core.coords.z, zone.core.heading, false, true)
        SetEntityHeading(npc, zone.core.heading)
        FreezeEntityPosition(npc, true)
        SetEntityInvincible(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)

        exports.ox_target:addLocalEntity(npc, {
            {
                name = 'deliver_ticket_' .. zone.name,
                icon = 'fas fa-ticket-alt',
                label = 'Entregar Ticket',
                onSelect = function()
                    TriggerServerEvent('ce-basezone:deliverTicket', zone.name, GetPlayerLevel())
                end
            }
        })
    end
end)

RegisterNetEvent('ce-basezone:accessDenied')
AddEventHandler('ce-basezone:accessDenied', function(reason, coords)
    lib.notify({
        title = Translate('interaction', reason),
        type = 'error',
        duration = 5000
    })
    TeleportOutOfZone(coords)
end)

RegisterNetEvent('ce-basezone:ticketDelivered')
AddEventHandler('ce-basezone:ticketDelivered', function(duration, zoneName)
    ticketTimeRemaining = duration
    ShowTimeRemaining(ticketTimeRemaining)
    lib.notify({
        title = Translate('interaction', 'ticket_delivered', zoneName),
        type = 'success',
        duration = 5000
    })
    for _, zone in ipairs(Config.Zones) do
        if zone.name == zoneName then
            StartStressReduction(zone)
            break
        end
    end
end)

RegisterNetEvent('ce-basezone:setTicketTime')
AddEventHandler('ce-basezone:setTicketTime', function(time)
    ticketTimeRemaining = time
    if currentZone and time > 0 then
        ShowTimeRemaining(ticketTimeRemaining)
        DebugPrint(1, "Ticket time remaining updated: " .. ticketTimeRemaining)
    else
        HideTimeRemaining()
    end
end)

RegisterNetEvent('ce-basezone:vipBonus')
AddEventHandler('ce-basezone:vipBonus', function(vipRank, bonusTime)
    lib.notify({
        title = Translate('interaction', 'vip_access', vipRank, bonusTime),
        type = 'success',
        duration = 5000
    })
end)

RegisterNetEvent('ce-basezone:noTicket')
AddEventHandler('ce-basezone:noTicket', function()
    lib.notify({
        title = Translate('interaction', 'no_ticket'),
        type = 'error',
        duration = 5000
    })
end)

-- Comando para alternar la visibilidad de los blips de las zonas
RegisterCommand('togglezoneblip', function(source, args)
    if #args < 1 then
        lib.notify({
            title = Translate('interaction', 'usage_toggle_blip'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local zoneName = args[1]
    local found = false

    for _, zone in ipairs(Config.Zones) do
        if zone.name == zoneName then
            found = true
            zone.blip.enabled = not zone.blip.enabled

            if zone.blip.enabled then
                local blip = AddBlipForCoord(zone.core.coords.x, zone.core.coords.y, zone.core.coords.z)
                SetBlipSprite(blip, zone.blip.sprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, zone.blip.scale)
                SetBlipColour(blip, zone.blip.color)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(zone.blip.label)
                EndTextCommandSetBlipName(blip)

                lib.notify({
                    title = Translate('interaction', 'blip_toggled_on', zoneName),
                    type = 'success',
                    duration = 3000
                })
            else
                local blip = GetBlipFromCoord(zone.core.coords.x, zone.core.coords.y, zone.core.coords.z)
                if DoesBlipExist(blip) then
                    RemoveBlip(blip)
                end

                lib.notify({
                    title = Translate('interaction', 'blip_toggled_off', zoneName),
                    type = 'info',
                    duration = 3000
                })
            end

            break
        end
    end

    if not found then
        lib.notify({
            title = Translate('interaction', 'zone_not_found'),
            type = 'error',
            duration = 3000
        })
    end
end, false)

RegisterNetEvent('ce-basezone:ticketRequired')
AddEventHandler('ce-basezone:ticketRequired', function(zoneName)
    lib.notify({
        title = Translate('interaction', 'ticket_required', Config.Zones[zoneName].requiredLevel),
        type = 'warning',
        duration = 5000
    })
end)
