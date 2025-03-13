-- Se carga la librería de utilidades (por ejemplo, para funciones básicas de Noita)
dofile_once("data/scripts/lib/utilities.lua")

-- Se importan módulos de Component Explorer para reutilizar funciones
local player_util  = dofile_once("mods/getdata/utils/player_util.lua")
local file_util    = dofile_once("mods/getdata/utils/file_util.lua")

local Key_g = 10
local debug_frame_counter = 0
local extraction_key_down = false

-- Se delega la búsqueda del jugador a player_util
local function get_player_entity()
    local player = player_util.get_player()
    if player then
        GamePrint("[DEBUG] Se obtuvo al jugador con ID: " .. tostring(player))
        return player
    else
        GamePrint("[DEBUG] No se encontró ninguna entidad con el tag 'player_unit'")
        return nil
    end
end

-- Obtiene la varita activa del jugador usando el Inventory2Component.
local function get_active_wand(player)
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

    if not EntityGetFirstComponentIncludingDisabled(active_wand, "ItemComponent") then
        GamePrint("[DEBUG] La entidad con ID " .. tostring(active_wand) .. " no tiene 'ItemComponent'.")
        return nil
    end

    return active_wand
end

-- Función que extrae información de la varita activa.
-- Se consultan GunComponent, ConfigGun, ConfigGunActionInfo y se recorren los hijos con ItemComponent para listar los hechizos.
local function extract_wand_info(player)
    local wand_entity = get_active_wand(player)
    if not wand_entity then 
        return "No se encontró varita activa."
    end

    local info = "Varita activa (ID " .. tostring(wand_entity) .. ")\n"

    -- 1. GunComponent: Estadísticas principales
    local gun_comp = EntityGetFirstComponentIncludingDisabled(wand_entity, "GunComponent")
    if gun_comp then
        local actions_per_round = ComponentGetValue2(gun_comp, "actions_per_round") or "N/A"
        local mana_max          = ComponentGetValue2(gun_comp, "mana_max") or "N/A"
        local mana_charge_speed = ComponentGetValue2(gun_comp, "mana_charge_speed") or "N/A"
        local deck_capacity     = ComponentGetValue2(gun_comp, "deck_capacity") or "N/A"
        local reload_time       = ComponentGetValue2(gun_comp, "reload_time") or "N/A"

        info = info .. "Acciones por ronda: " .. tostring(actions_per_round) .. "\n"
        info = info .. "Mana Máximo: " .. tostring(mana_max) .. "\n"
        info = info .. "Recarga de Mana: " .. tostring(mana_charge_speed) .. "\n"
        info = info .. "Capacidad: " .. tostring(deck_capacity) .. "\n"
        info = info .. "Tiempo de Recarga: " .. tostring(reload_time) .. " frames\n"
    else
        info = info .. "[DEBUG] GunComponent no encontrado.\n"
    end

    -- 2. ConfigGun: Información adicional de la varita
    local config_gun = EntityGetFirstComponentIncludingDisabled(wand_entity, "ConfigGun")
    if config_gun then
        info = info .. "[DEBUG] ConfigGun leído.\n"
    else
        info = info .. "[DEBUG] ConfigGun no encontrado.\n"
    end

    -- 3. ConfigGunActionInfo: Detalles de los hechizos
    local config_gun_action = EntityGetFirstComponentIncludingDisabled(wand_entity, "ConfigGunActionInfo")
    if config_gun_action then
        info = info .. "[DEBUG] ConfigGunActionInfo leído.\n"
    else
        info = info .. "[DEBUG] ConfigGunActionInfo no encontrado.\n"
    end

    -- 4. Hechizos: Se recorren los hijos que tienen ItemComponent
    local spells = {}
    local children = EntityGetAllChildren(wand_entity) or {}
    for _, child in ipairs(children) do
        local item_comp = EntityGetFirstComponentIncludingDisabled(child, "ItemComponent")
        if item_comp then
            local action_id = ComponentGetValue2(item_comp, "mItemName") or "Desconocido"
            table.insert(spells, action_id)
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

-- Escribe la información extraída en un archivo, usando la función de file_util.
local function export_info(info)
    local file_path = "mods/getdata/files/player_info.txt"
    if file_util.ModTextFileSetContent then
        file_util.ModTextFileSetContent(file_path, info)
        GamePrint("Datos guardados en: " .. file_path)
    else
        GamePrint("[ERROR] No se pudo escribir el archivo.")
    end
end

-- Función principal que se invoca en cada frame antes de actualizar el mundo.
function OnWorldPreUpdate()
    local is_key_pressed = InputIsKeyDown(Key_g)
    debug_frame_counter = is_key_pressed and debug_frame_counter + 1 or 0

    if is_key_pressed and not extraction_key_down then
        extraction_key_down = true
        GamePrint("[DEBUG] Tecla Key_g presionada. Iniciando extracción...")
        local player = get_player_entity()
        if player then
            local info = extract_wand_info(player)
            GamePrint("[DEBUG] Información extraída:\n" .. info)
            export_info(info)
            GamePrint("Datos extraídos y exportados a player_info.txt")
        else
            GamePrint("Jugador no encontrado.")
        end
    end

    if not is_key_pressed then
        if extraction_key_down then
            GamePrint("[DEBUG] Tecla Key_g liberada")
        end
        extraction_key_down = false
    end
end

-- Se notifica la carga del mod
function OnModInit()
    GamePrint("Mod 'Extract Player Info' cargado")
end
