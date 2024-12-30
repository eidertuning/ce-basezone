local ox_inventory = exports.ox_inventory

-- Debug function
    local function DebugPrint(level, message)
        if Config.Debug and Config.Debug.enabled then
            if type(Config.Debug.level) ~= 'number' then
                print("[CE-BaseZone Debug] Error: Config.Debug.level no es un número. Valor actual: " .. tostring(Config.Debug.level))
                return
            end
            if type(level) ~= 'number' then
                print("[CE-BaseZone Debug] Error: El parámetro 'level' no es un número. Valor actual: " .. tostring(level))
                return
            end
            if Config.Debug.level >= level then
                print("[CE-BaseZone Debug] " .. message)
            end
        end
    end
    


-- Función para traducir textos
local function Translate(category, key, ...)
    local lang = Config.Locale
    if Config.Translations and Config.Translations[lang] and Config.Translations[lang][category] and Config.Translations[lang][category][key] then
        local translation = Config.Translations[lang][category][key]
        local args = {...}
        if #args > 0 then
            return string.format(translation, table.unpack(args))
        else
            return translation
        end
    end
    return "Translation missing: " .. category .. "." .. key
end

local function HasValidTicket(playerId, zoneName)
    if not Config.Zones or not Config.Zones[zoneName] or not Config.Zones[zoneName].requiredItem then
        return false
    end

    -- Obtén el resultado del inventario
    local count = ox_inventory:Search(playerId, 'count', Config.Zones[zoneName].requiredItem)
    
    -- Asegúrate de que el resultado sea un número
    if type(count) ~= "number" then
        print("[CE-BaseZone Debug] Error: ox_inventory:Search devolvió un valor no válido: " .. tostring(count))
        return false
    end

    return count > 0
end


-- Función para obtener el tiempo restante del ticket
local function GetTicketTimeRemaining(playerId, zoneName)
    local result = exports.oxmysql:executeSync('SELECT time_remaining FROM user_zone_tickets WHERE user_id = ? AND zone_name = ?', {playerId, zoneName})

    if result and #result > 0 then
        return result[1].time_remaining
    end

    return 0
end

-- Función para actualizar el tiempo restante del ticket
local function UpdateTicketTimeRemaining(playerId, zoneName, timeRemaining)
    exports.oxmysql:execute('INSERT INTO user_zone_tickets (user_id, zone_name, time_remaining) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE time_remaining = ?', {
        playerId, zoneName, timeRemaining, timeRemaining
    })
end

-- Función para verificar y manejar el ticket de un jugador
local function VerifyAndHandleTicket(playerId, zoneName)
    if HasValidTicket(playerId, zoneName) then
        local timeRemaining = GetTicketTimeRemaining(playerId, zoneName)
        if timeRemaining == 0 and Config.Zones and Config.Zones[zoneName] and Config.Zones[zoneName].ticketDuration then
            timeRemaining = Config.Zones[zoneName].ticketDuration * 60
            UpdateTicketTimeRemaining(playerId, zoneName, timeRemaining)
        end
        TriggerClientEvent('ce-basezone:setTicketTime', playerId, timeRemaining)
        return true
    else
        TriggerClientEvent('ce-basezone:noValidTicket', playerId, zoneName)
        return false
    end
end

-- Función para comprobar el acceso del jugador
local function CheckPlayerAccess(playerLevel, zone)
    if zone and zone.requiredLevel and playerLevel >= zone.requiredLevel then
        return true, 'ticket_required'
    end

    return true
end

-- Función para obtener el rango VIP del jugador
local function GetPlayerVIPRank(playerId)
    if Config.VIPSystems then
        for _, system in ipairs(Config.VIPSystems) do
            local rank = system.getVIPRank(playerId)
            if rank then
                return rank
            end
        end
    end
    return nil
end

-- Función para verificar todos los jugadores en una zona
local function VerifyAllPlayersInZone(zoneName)
    if not Config.Zones or not Config.Zones[zoneName] or not Config.Zones[zoneName].points then
        DebugPrint(1, "Invalid zone configuration for: " .. zoneName)
        return
    end

    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local playerPed = GetPlayerPed(playerId)
        if playerPed and DoesEntityExist(playerPed) then
            local playerCoords = GetEntityCoords(playerPed)
            if IsPointInPolygon(playerCoords, Config.Zones[zoneName].points) then
                VerifyAndHandleTicket(playerId, zoneName)
            end
        end
    end
end

-- Evento para cuando el recurso se inicia
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    if Config.Zones then
        for zoneName, _ in pairs(Config.Zones) do
            VerifyAllPlayersInZone(zoneName)
        end
    end
end)

-- Evento para reducir el estrés del jugador
RegisterNetEvent('ce-basezone:reduceStress')
AddEventHandler('ce-basezone:reduceStress', function(amount, zoneName)
    local playerId = source
    DebugPrint(2, "Reducing stress for player " .. playerId .. " in zone " .. zoneName)
    for _, system in ipairs(Config.StressSystems) do
        system.reduceStress(playerId, amount)
    end
    
    if Config.DiscordLog.logLevel.stressReduction then
        local playerName = GetPlayerName(playerId)
        SendDiscordLog(
            Translate('interaction', 'stress_reduced'),
            string.format(Translate('logs', 'stress_reduced_log'), playerName, amount, zoneName),
            5763719, -- Verde claro
            {
                {name = "Jugador", value = playerName, inline = true},
                {name = "Cantidad", value = tostring(amount), inline = true},
                {name = "Zona", value = zoneName, inline = true}
            }
        )
    end
end)

-- Evento para cuando un jugador entra en una zona
RegisterNetEvent('ce-basezone:playerEnterZone')
AddEventHandler('ce-basezone:playerEnterZone', function(zoneName, playerLevel)
    local playerId = source
    local playerName = GetPlayerName(playerId)

    for _, zone in ipairs(Config.Zones) do
        if zone.name == zoneName then
            local hasAccess, reason = CheckPlayerAccess(playerLevel, zone)
            if not hasAccess then
                TriggerClientEvent('ce-basezone:accessDenied', playerId, reason, zone.teleportOutCoords)
                return
            elseif reason == 'ticket_required' then
                local timeRemaining = GetTicketTimeRemaining(playerId, zoneName)
                TriggerClientEvent('ce-basezone:setTicketTime', playerId, timeRemaining)
                DebugPrint(1, "Ticket time remaining for player " .. playerName .. " in zone " .. zoneName .. ": " .. timeRemaining)
                return
            end
            break
        end
    end

    if Config.DiscordLog.logLevel.playerEnter then
        SendDiscordLog(
            Translate('logs', 'zone_enter'),
            string.format(Translate('logs', 'zone_enter_log'), playerName, zoneName),
            3066993, -- Verde
            {
                {name = "Jugador", value = playerName, inline = true},
                {name = "Zona", value = zoneName, inline = true}
            }
        )
    end
end)


-- Evento para manejar la entrega de tickets
RegisterNetEvent('ce-basezone:deliverTicket')
AddEventHandler('ce-basezone:deliverTicket', function(zoneName, playerLevel)
    local playerId = source
    local playerName = GetPlayerName(playerId)
    
    DebugPrint(1, "Intento de entrega de ticket por " .. playerName .. " para la zona " .. zoneName)
    
    for _, zone in ipairs(Config.Zones) do
        if zone.name == zoneName then
            if ox_inventory:Search(playerId, 'count', zone.requiredItem) > 0 then
                ox_inventory:RemoveItem(playerId, zone.requiredItem, 1)
                local ticketDuration = zone.ticketDuration * 60 -- Convertir minutos a segundos
                
                -- Aplicar bonus VIP si está habilitado
                if zone.vipEnabled then
                    local vipRank = GetPlayerVIPRank(playerId)
                    if vipRank and zone.vipBonusTime[vipRank] then
                        local bonusTime = zone.vipBonusTime[vipRank] * 60 -- Convertir minutos a segundos
                        ticketDuration = ticketDuration + bonusTime
                        TriggerClientEvent('ce-basezone:vipBonus', playerId, vipRank, bonusTime / 60)
                    end
                end
                
                local currentTime = GetTicketTimeRemaining(playerId, zoneName)
                local newTime = currentTime + ticketDuration
                UpdateTicketTimeRemaining(playerId, zoneName, newTime)
                TriggerClientEvent('ce-basezone:ticketDelivered', playerId, newTime, zoneName)
                
                DebugPrint(1, "Ticket entregado con éxito por " .. playerName .. " para la zona " .. zoneName)
                
                if Config.DiscordLog.logLevel.ticketUse then
                    SendDiscordLog(
                        Translate('logs', 'ticket_delivered'),
                        string.format(Translate('logs', 'ticket_delivered_log'), playerName, zoneName, newTime / 60),
                        1752220, -- Amarillo
                        {
                            {name = "Jugador", value = playerName, inline = true},
                            {name = "Zona", value = zoneName, inline = true},
                            {name = "Tiempo Total", value = tostring(newTime / 60) .. " minutos", inline = true}
                        }
                    )
                end
            else
                DebugPrint(1, "Intento fallido de entrega de ticket por " .. playerName .. " para la zona " .. zoneName .. " (sin ticket)")
                TriggerClientEvent('ce-basezone:noTicket', playerId)
            end
            return
        end
    end
    
    DebugPrint(1, "Intento fallido de entrega de ticket por " .. playerName .. " para la zona " .. zoneName .. " (zona no encontrada)")
end)

-- Evento para cuando un jugador sale de una zona
RegisterNetEvent('ce-basezone:playerExitZone')
AddEventHandler('ce-basezone:playerExitZone', function(zoneName)
    local playerId = source
    local playerName = GetPlayerName(playerId)
    
    if Config.DiscordLog.logLevel.playerExit then
        SendDiscordLog(
            Translate('logs', 'zone_exit'),
            string.format(Translate('logs', 'zone_exit_log'), playerName, zoneName),
            15158332, -- Rojo
            {
                {name = "Jugador", value = playerName, inline = true},
                {name = "Zona", value = zoneName, inline = true}
            }
        )
    end
end)

-- Evento para obtener el tiempo restante del ticket
RegisterNetEvent('ce-basezone:getTicketTime')
AddEventHandler('ce-basezone:getTicketTime', function(zoneName)
    local playerId = source
    local timeRemaining = GetTicketTimeRemaining(playerId, zoneName)
    TriggerClientEvent('ce-basezone:setTicketTime', playerId, timeRemaining)
end)

-- Evento para actualizar el tiempo restante del ticket
RegisterNetEvent('ce-basezone:updateTicketTime')
AddEventHandler('ce-basezone:updateTicketTime', function(zoneName, timeRemaining)
    local playerId = source
    UpdateTicketTimeRemaining(playerId, zoneName, timeRemaining)
end)

-- Evento para verificar el ticket del jugador
RegisterNetEvent('ce-basezone:checkTicket')
AddEventHandler('ce-basezone:checkTicket', function(zoneName)
    local playerId = source
    VerifyAndHandleTicket(playerId, zoneName)
end)

-- Evento para verificar los ocupantes de un vehículo
RegisterNetEvent('ce-basezone:checkVehicleOccupants')
AddEventHandler('ce-basezone:checkVehicleOccupants', function(vehicleNetId, zoneName)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle then return end

    local occupants = GetVehicleOccupants(vehicle)
    for seat, playerId in pairs(occupants) do
        if not VerifyAndHandleTicket(playerId, zoneName) then
            -- Si un ocupante no tiene ticket válido, lo sacamos del vehículo
            TriggerClientEvent('ce-basezone:ejectFromVehicle', playerId, zoneName)
        end
    end
end)

-- Función auxiliar para obtener los ocupantes de un vehículo
function GetVehicleOccupants(vehicle)
    local occupants = {}
    for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, i)
        if ped ~= 0 then
            local playerId = NetworkGetPlayerIndexFromPed(ped)
            if playerId ~= -1 then
                occupants[i] = playerId
            end
        end
    end
    return occupants
end

-- Comando de administrador para toggle de características
RegisterCommand('togglezonefeature', function(source, args, rawCommand)
    if source ~= 0 then -- Asegurarse de que es un administrador
        local playerName = GetPlayerName(source)
        if not IsPlayerAceAllowed(source, "command.togglezonefeature") then
            TriggerClientEvent('chat:addMessage', source, {args = {"^1Error", "No tienes permiso para usar este comando."}})
            return
        end
    end

    if #args < 3 then
        print("Uso: /togglezonefeature [nombre_zona] [característica] [true/false]")
        return
    end

    local zoneName = args[1]
    local feature = args[2]
    local state = args[3] == "true"

    for i, zone in ipairs(Config.Zones) do
        if zone.name == zoneName then
            if feature == "vip" then
                Config.Zones[i].vipEnabled = state
            elseif feature == "experience" then
                Config.Zones[i].experienceEnabled = state
            elseif feature == "stress" then
                Config.Zones[i].stressReductionEnabled = state
            else
                print("Característica no reconocida. Opciones válidas: vip, experience, stress")
                return
            end
            
            print(string.format("Característica %s %s para la zona %s", feature, state and "activada" or "desactivada", zoneName))
            
            if Config.DiscordLog.logLevel.adminActions then
                SendDiscordLog(
                    Translate('logs', 'admin_action'),
                    string.format(Translate('logs', 'admin_action_log'), 
                        source == 0 and "CONSOLE" or GetPlayerName(source),
                        state and "activado" or "desactivado",
                        feature,
                        zoneName
                    ),
                    16776960, -- Amarillo
                    {
                        {name = "Administrador", value = source == 0 and "CONSOLE" or GetPlayerName(source), inline = true},
                        {name = "Acción", value = state and "Activar" or "Desactivar", inline = true},
                        {name = "Característica", value = feature, inline = true},
                        {name = "Zona", value = zoneName, inline = true}
                    }
                )
            end
            
            return
        end
    end
    
    print("Zona no encontrada.")
end, true)

-- Función para enviar logs a Discord
function SendDiscordLog(title, description, color, fields)
    if not Config.DiscordLog or not Config.DiscordLog.webhookUrl then return end

    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["type"] = "rich",
            ["color"] = color,
            ["fields"] = fields
        }
    }

    PerformHttpRequest(Config.DiscordLog.webhookUrl, function(err, text, headers) end, 'POST', json.encode({username = "CE-BaseZone", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Función para verificar si un punto está dentro de un polígono
function IsPointInPolygon(point, polygon)
    local x, y = point.x, point.y
    local inside = false
    local j = #polygon

    for i = 1, #polygon do
        if (polygon[i].y < y and polygon[j].y >= y or polygon[j].y < y and polygon[i].y >= y) and
           (polygon[i].x + (y - polygon[i].y) / (polygon[j].y - polygon[i].y) * (polygon[j].x - polygon[i].x) < x) then
            inside = not inside
        end
        j = i
    end

    return inside
end

-- Inicialización del recurso
Citizen.CreateThread(function()
    print("CE-BaseZone iniciado correctamente.")
    -- Aquí puedes agregar cualquier lógica adicional de inicialización si es necesario
end)

