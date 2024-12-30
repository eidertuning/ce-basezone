Config = {}

Config.Locale = 'es' -- Idioma predeterminado

Config.Debug = {
    enabled = true,
    level = 3, -- 1: Basic, 2: Advanced, 3: Verbose
    showPolyZones = false
}

Config.VIPRanks = {
    {name = "Bronze", multiplier = 1.2},
    {name = "Silver", multiplier = 1.5},
    {name = "Gold", multiplier = 2.0},
    {name = "Platinum", multiplier = 2.5}
}


Config.StressSystems = {
    {
        name = "esx_status",
        reduceStress = function(playerId, amount)
            TriggerClientEvent('esx_status:remove', playerId, 'stress', amount)
        end
    },
    --{
    --    name = "qb-core",
    --    reduceStress = function(playerId, amount)
    --        local Player = QBCore.Functions.GetPlayer(playerId)
    --        if Player then
    --            Player.Functions.SetMetaData('stress', Player.PlayerData.metadata.stress - amount)
    --        end
    --    end
    --}
}

Config.Zones = {
    {
        name = "Refugio casino",
        points = {
            vector2(1089.2647705078, -101.84674835205),
            vector2(1105.8065185547, -91.442169189453),
            vector2(1135.6706542969, -42.052394866943),
            vector2(1173.7374267578, 21.359035491943),
            vector2(1287.7319335938, 199.87808227539),
            vector2(1317.0281982422, 256.40777587891),
            vector2(1317.0837402344, 318.69760131836),
            vector2(1216.1037597656, 381.39938354492),
            vector2(1166.9301757813, 304.29913330078),
            vector2(1142.2131347656, 288.4909362793),
            vector2(1094.9791259766, 264.36511230469),
            vector2(1084.6427001953, 247.84214782715),
            vector2(994.33190917969, 112.25933074951),
            vector2(996.04266357422, 101.46579742432),
            vector2(984.69793701172, 81.50756072998),
            vector2(981.95227050781, 78.068840026855),
            vector2(970.3271484375, 83.77091217041),
            vector2(962.54797363281, 73.655448913574),
            vector2(950.73236083984, 80.423683166504),
            vector2(938.53088378906, 60.990993499756),
            vector2(936.33032226563, 63.905185699463),
            vector2(913.46325683594, 29.191919326782),
            vector2(917.39447021484, 27.745306015015),
            vector2(907.72094726563, 11.168272018433),
            vector2(921.21466064453, 1.2416143417358),
            vector2(959.38391113281, -22.833381652832),
            vector2(966.64660644531, -30.53210067749),
            vector2(970.06341552734, -45.472179412842),
            vector2(979.96459960938, -65.25927734375),
            vector2(985.64111328125, -73.681549072266),
            vector2(1007.0831298828, -95.267517089844),
            vector2(1028.9515380859, -106.40139770508),
            vector2(1049.3826904297, -110.0022277832),
            vector2(1065.5017089844, -108.53945922852),
            vector2(1074.7003173828, -107.00260925293),
            vector2(1089.68359375, -101.67950439453)
        },
        minZ = 69.554306030273,
        maxZ = 86.442939758301,
        requiredItem = "ticket",
        requiredLevel = 10,
        teleportOutCoords = vector4(1076.25390625, 249.1213684082, 80.725158691406, 114.1695022583),
        ticketDuration = 60, -- duración en minutos
        vipEnabled = false,
        vipBonusTime = {
            Bronze = 15,
            Silver = 30,
            Gold = 45,
            Platinum = 60
        },
        experienceEnabled = true,
        stressReductionEnabled = true,
        stressReduction = {
            amount = 10, -- cantidad de estrés reducido por minuto
            interval = 60000 -- intervalo en ms (1 minuto)
        },
        core = {
            coords = vector3(977.74621582031, -65.860336303711, 73.959243774414),
            heading = 119.89825439453124,
            model = "s_m_m_bouncer_01"
        },
        blip = {
            enabled = true,
            sprite = 679,
            color = 5,
            scale = 0.8,
            label = "Refugio Casino"
        }
    }
}

Config.ExperienceSystems = {
    {
        name = "ESX_XP",
        getLevel = function(playerId)
            local xp = exports.esx_xp:ESXP_GetXP()
            if xp then
                return exports.esx_xp:ESXP_GetRank(xp)
            else
                print("Warning: Failed to get XP for player " .. playerId .. ". Using fallback level.")
                return 1
            end
        end
    },
    --{
    --    name = "CUSTOM_XP",
    --    getLevel = function(playerId)
    --        -- Ejemplo de cómo obtener el nivel de un sistema personalizado
    --        return exports.custom_xp:getPlayerLevel(playerId)
    --    end
    --}
}

Config.VIPSystems = {
    {
        name = "ESX_VIP",
        getVIPRank = function(playerId)
            return exports.esx_vip:getPlayerVIPRank(playerId)
        end
    },
    --{
    --    name = "CUSTOM_VIP",
    --    getVIPRank = function(playerId)
    --        -- Ejemplo de cómo obtener el rango VIP de un sistema personalizado
    --        return exports.custom_vip:getPlayerVIPRank(playerId)
    --    end
    --}
}

Config.Translations = {
    ['es'] = {
        -- Mensajes de interacción
        interaction = {
            ['ticket_required'] = '🎫 Necesitas entregar un ticket para permanecer en esta zona (nivel %s o superior).',
            ['vehicle_not_allowed'] = '🚫 No se permiten vehículos en esta zona sin tiempo acumulado.',
            ['teleporting'] = '🌀 Teletransportando...',
            ['stress_reduced'] = '😌 Tu nivel de estrés ha sido reducido.',
            ['time_remaining'] = '⏳ Tiempo restante: %s',
            ['no_ticket'] = '🚫 No tienes un ticket válido para esta zona.',
            ['ticket_delivered'] = '✅ Has entregado un ticket para la zona %s.',
            ['vip_access'] = '🌟 Acceso VIP: Rango %s. Tiempo adicional: %s minutos.',
            ['zone_enter'] = '🚶‍♂️ Has entrado en la zona %s.',
            ['zone_exit'] = '🚶‍♂️ Has salido de la zona %s.',
            ['blip_toggled_on'] = '🗺️ Blip activado para %s',
            ['blip_toggled_off'] = '🗺️ Blip desactivado para %s',
            ['zone_not_found'] = '❓ Zona no encontrada',
            ['no_valid_ticket'] = 'No tienes un ticket válido para esta zona. Serás teletransportado fuera.',
            ['usage_toggle_blip'] = '📌 Uso: /togglezoneblip [nombre_zona]'
        },
        
        -- Mensajes de registro (logs)
        logs = {
            ['stress_reduced_log'] = 'El jugador %s ha reducido su estrés en %s en la zona %s.',
            ['zone_enter_log'] = 'El jugador %s ha entrado en la zona %s.',
            ['zone_exit_log'] = 'El jugador %s ha salido de la zona %s.',
            ['ticket_delivered_log'] = 'El jugador %s ha entregado un ticket para la zona %s. Tiempo total: %s minutos.',
            ['admin_action'] = 'Acción de Administrador',
            ['admin_action_log'] = 'El administrador %s ha %s la característica %s para la zona %s.'
        },
        
        -- Mensajes de error
        errors = {
            ['access_denied'] = 'Acceso denegado: %s',
            ['invalid_command'] = 'Comando inválido. Uso: %s',
        },
    }
}

Config.DiscordLog = {
    enabled = true,
    webhookUrl = "https://discord.com/api/webhooks/1318309746800853042/zRoIvFB-SBKjwj4kdaA4-sYwq5nrU4MQf3ApbA03_TVrNV6NpJO799PCTVBpk5o-qopi",
    botName = "New-Z Base Log",
    botAvatar = "https://i.imgur.com/your_avatar_image.png",
    color = 3447003, -- Azul de Discord
    logLevel = {
        playerEnter = true,
        playerExit = true,
        ticketUse = true,
        vipAccess = true,
        stressReduction = true,
        adminActions = true
    },
    customFields = {
        {name = "New-Z", value = "Your Server Name"},
        {name = "Server IP", value = "your.server.ip"}
    }
}

Config.UI = {
    style = {
        backgroundColor = '#000000',
        color = '#FFFFFF'
    }
}

