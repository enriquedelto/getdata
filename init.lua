dofile_once("data/scripts/lib/utilities.lua")

local Key_g = 10
local debug_frame_counter = 0
local extraction_key_down = false

function OnModInit()
    GamePrint("Mod cargado")
end

function get_player_entity()
    local players = EntityGetWithTag("player_unit")
    if players and #players > 0 then
        GamePrint("[DEBUG] Se encontraron " .. #players .. " jugador(es). Usando el primero con ID: " .. tostring(players[1]))
        return players[1]
    end
    GamePrint("[DEBUG] No se encontró ningún jugador con el tag 'player_unit'")
    return nil
end

-- Obtiene la varita activa a través del Inventory2Component
function get_active_wand(player)
    if not player then 
        GamePrint("[DEBUG] No se encontró la entidad del jugador.")
        return nil 
    end

    local inv_comp = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
    if not inv_comp then 
        GamePrint("[DEBUG] No se encontró Inventory2Component en el jugador.")
        return nil 
    end

    local active_wand = ComponentGetValue2(inv_comp, "mActiveItem") or 0
    if active_wand == 0 or not EntityGetIsAlive(active_wand) then 
        GamePrint("[DEBUG] No hay varita activa o la entidad no es válida. ID recibido: " .. tostring(active_wand))
        return nil 
    end

    -- Se asume que la varita debe tener ItemComponent para ser válida
    if not EntityGetFirstComponentIncludingDisabled(active_wand, "ItemComponent") then
        GamePrint("[DEBUG] La entidad con ID " .. tostring(active_wand) .. " no tiene 'ItemComponent'.")
        return nil
    end

    return active_wand
end

-- Extrae información de la varita usando los componentes de interés:
-- GunComponent, ConfigGun, ConfigGunActionInfo y los ItemComponent de los hechizos.
function extract_wand_info(player)
    local wand_entity = get_active_wand(player)
    if not wand_entity then 
        return "No se encontró varita activa."
    end

    local info = "Varita activa con ID: " .. tostring(wand_entity) .. "\n"

    -- 1. GunComponent: Estadísticas principales de la varita
    local gun_comp = EntityGetFirstComponentIncludingDisabled(wand_entity, "GunComponent")
    if gun_comp then
        local actions_per_round = ComponentGetValue2(gun_comp, "actions_per_round") or "N/A"
        local mana_max = ComponentGetValue2(gun_comp, "mana_max") or "N/A"
        local mana_charge_speed = ComponentGetValue2(gun_comp, "mana_charge_speed") or "N/A"
        local deck_capacity = ComponentGetValue2(gun_comp, "deck_capacity") or "N/A"
        local reload_time = ComponentGetValue2(gun_comp, "reload_time") or "N/A"

        info = info .. "Acciones por ronda: " .. tostring(actions_per_round) .. "\n"
        info = info .. "Mana Máximo: " .. tostring(mana_max) .. "\n"
        info = info .. "Recarga de Mana: " .. tostring(mana_charge_speed) .. "\n"
        info = info .. "Capacidad: " .. tostring(deck_capacity) .. "\n"
        info = info .. "Tiempo de Recarga: " .. tostring(reload_time) .. " frames\n"
    else
        info = info .. "[Placeholder] GunComponent no encontrado.\n"
    end

    -- 2. ConfigGun: Configuración adicional de la varita
    local config_gun = EntityGetFirstComponentIncludingDisabled(wand_entity, "ConfigGun")
    if config_gun then
        -- Aquí se podría extraer información adicional, por ahora se usa un placeholder
        info = info .. "[Placeholder] ConfigGun leído.\n"
    else
        info = info .. "[Placeholder] ConfigGun no encontrado.\n"
    end

    -- 3. ConfigGunActionInfo: Información detallada de las acciones/hechizos
    local config_gun_action = EntityGetFirstComponentIncludingDisabled(wand_entity, "ConfigGunActionInfo")
    if config_gun_action then
        info = info .. "[Placeholder] ConfigGunActionInfo leído.\n"
    else
        info = info .. "[Placeholder] ConfigGunActionInfo no encontrado.\n"
    end

    -- 4. Hechizos: Se extraen usando el ItemComponent de los hijos de la varita.
    local spells = {}
    local inv_comp = EntityGetFirstComponentIncludingDisabled(wand_entity, "Inventory2Component")
    if inv_comp then
        local children = EntityGetAllChildren(wand_entity) or {}
        for _, child in ipairs(children) do
            local item_comp = EntityGetFirstComponentIncludingDisabled(child, "ItemComponent")
            if item_comp then
                local action_id = ComponentGetValue2(item_comp, "mItemName") or "Desconocido"
                table.insert(spells, action_id)
            end
        end
    end

    info = info .. "---\nHechizos en la varita:\n"
    if #spells > 0 then
        for i, spell in ipairs(spells) do
            info = info .. i .. ". " .. spell .. "\n"
        end
    else
        info = info .. "No hay hechizos equipados.\n"
    end

    return info
end

function export_info(info)
    local file_path = "mods/getdata/files/player_info.txt"
    if ModTextFileSetContent then
        ModTextFileSetContent(file_path, info)
        GamePrint("Datos guardados en: " .. file_path)
    else
        GamePrint("[ERROR] No se pudo escribir el archivo.")
    end
end

function OnWorldPreUpdate()
    local is_key_pressed = InputIsKeyDown(Key_g)
    debug_frame_counter = is_key_pressed and debug_frame_counter + 1 or 0

    if is_key_pressed and not extraction_key_down then
        extraction_key_down = true
        GamePrint("[DEBUG] Key_g pressed, starting extraction...")
        local player = get_player_entity()
        if player then
            GamePrint("[DEBUG] Player obtained: " .. tostring(player))
            local info = extract_wand_info(player)
            if info == "" then
                GamePrint("[DEBUG] No wand info extracted.")
            else
                GamePrint("[DEBUG] Extracted info:\n" .. info)
            end
            export_info(info)
            GamePrint("Data extracted and exported to player_info.txt")
        else
            GamePrint("Player not found.")
        end
    end

    if not is_key_pressed then
        if extraction_key_down then
            GamePrint("[DEBUG] Key_g released")
        end
        extraction_key_down = false
    end
end
