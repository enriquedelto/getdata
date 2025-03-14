-- Carga la librería de utilidades de Noita
dofile_once("data/scripts/lib/utilities.lua")

-- Se importan los módulos reutilizables
local player_util = dofile_once("mods/getdata/utils/player_util.lua")
local file_util   = dofile_once("mods/getdata/utils/file_util.lua")

-- Define la tecla G (código 10)
local Key_g = 10

-- Variables para evitar extracciones repetidas mientras se mantiene pulsada la tecla
local extraction_key_down = false

-- Obtiene al jugador usando player_util
local function get_player()
    return player_util.get_player()
end

-- Obtiene la varita activa del jugador usando el componente Inventory2Component
local function get_active_wand(player)
    if not player then return nil end

    local inv_comp = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
    if not inv_comp then return nil end

    local wand = ComponentGetValue2(inv_comp, "mActiveItem") or 0
    if wand == 0 or not EntityGetIsAlive(wand) then return nil end

    if not EntityGetFirstComponentIncludingDisabled(wand, "ItemComponent") then
        return nil
    end

    return wand
end

-- Extrae información de la varita activa:
-- - Estadísticas principales a partir del GunComponent
-- - Lista los hechizos mediante la lectura de los ItemComponent de sus hijos
local function extract_wand_info(player)
    local wand = get_active_wand(player)
    if not wand then 
        return "No se encontró varita activa."
    end

    local info = "Varita activa (ID " .. tostring(wand) .. ")\n"

    local gun = EntityGetFirstComponentIncludingDisabled(wand, "GunComponent")
    if gun then
        info = info .. "Acciones por ronda: " .. tostring(ComponentGetValue2(gun, "actions_per_round") or "N/A") .. "\n"
        info = info .. "Mana Máximo: " .. tostring(ComponentGetValue2(gun, "mana_max") or "N/A") .. "\n"
        info = info .. "Recarga de Mana: " .. tostring(ComponentGetValue2(gun, "mana_charge_speed") or "N/A") .. "\n"
        info = info .. "Capacidad: " .. tostring(ComponentGetValue2(gun, "deck_capacity") or "N/A") .. "\n"
        info = info .. "Tiempo de Recarga: " .. tostring(ComponentGetValue2(gun, "reload_time") or "N/A") .. " frames\n"
    else
        info = info .. "GunComponent no encontrado.\n"
    end

    local spells = {}
    local children = EntityGetAllChildren(wand) or {}
    for _, child in ipairs(children) do
        local item = EntityGetFirstComponentIncludingDisabled(child, "ItemComponent")
        if item then
            local spell_name = ComponentGetValue2(item, "mItemName") or "Desconocido"
            table.insert(spells, spell_name)
        end
    end

    info = info .. "---\nHechizos:\n"
    if #spells > 0 then
        for i, spell in ipairs(spells) do
            info = info .. i .. ". " .. spell .. "\n"
        end
    else
        info = info .. "No hay hechizos equipados.\n"
    end

    return info
end

-- Escribe la información extraída en un archivo usando ModTextFileSetContent.
local function export_info(info)
    local file_path = "mods/getdata/files/player_info.csv"
    if ModTextFileSetContent then
        ModTextFileSetContent(file_path, info)
        GamePrint("Datos guardados en: " .. file_path)
    else
        GamePrint("[ERROR] No se pudo escribir el archivo.")
    end
end

-- Se invoca esta función cada frame antes de actualizar el mundo.
function OnWorldPreUpdate()
    local is_pressed = InputIsKeyDown(Key_g)
    if is_pressed and not extraction_key_down then
        extraction_key_down = true
        local player = get_player()
        if player then
            local info = extract_wand_info(player)
            export_info(info)
        else
            GamePrint("Jugador no encontrado.")
        end
    end

    if not is_pressed then
        extraction_key_down = false
    end
end

-- Notifica la carga del mod
function OnModInit()
    GamePrint("Mod 'Extract Player Info' cargado")
end
