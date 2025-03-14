-- Importamos las funciones de los archivos de utilidades
dofile_once("mods/Extract Player Info/files/helper.lua")
dofile_once("mods/Extract Player Info/files/wand_spell_helper.lua")

-- Definimos la tecla de extracción (tecla G, código 10)
local KEY_G = 10
local extraction_key_down = false

-- Función para obtener al jugador (usando la función get_player_id de helper.lua)
local function get_player()
    return get_player_id()  -- retorna el ID de la entidad del jugador
end

-- Función para obtener la varita activa del jugador.
-- Se asume que la varita se encuentra en el inventario rápido (inventory_quick) y tiene la etiqueta "wand"
local function get_active_wand(player)
    local inventory = get_inventory_quick()
    if inventory == nil then return nil end
    local children = EntityGetAllChildren(inventory)
    if children then
        for i, child in ipairs(children) do
            if EntityHasTag(child, "wand") then
                return child
            end
        end
    end
    return nil
end

-- Función que extrae la información de la varita activa usando read_wand (definida en wand_spell_helper.lua)
local function extract_wand_info()
    local player = get_player()
    if not player then
        return "Jugador no encontrado."
    end

    local wand = get_active_wand(player)
    if not wand then
        return "No se encontró varita activa."
    end

    local info = "=== Varita Activa (ID " .. tostring(wand) .. ") ===\n"
    local wand_data = read_wand(wand)
    if wand_data then
        info = info .. "Tipo de varita: " .. tostring(wand_data["wand_type"]) .. "\n"
        info = info .. "Shuffle: " .. tostring(wand_data["shuffle"]) .. "\n"
        info = info .. "Acciones por disparo: " .. tostring(wand_data["spells_per_cast"]) .. "\n"
        info = info .. "Retraso de disparo: " .. tostring(wand_data["cast_delay"]) .. "\n"
        info = info .. "Tiempo de recarga: " .. tostring(wand_data["recharge_time"]) .. "\n"
        info = info .. "Mana Máximo: " .. tostring(wand_data["mana_max"]) .. "\n"
        info = info .. "Velocidad de recarga de mana: " .. tostring(wand_data["mana_charge_speed"]) .. "\n"
        info = info .. "Capacidad: " .. tostring(wand_data["capacity"]) .. "\n"
        info = info .. "Spread: " .. tostring(wand_data["spread"]) .. "\n"
        if wand_data["spells"] and #wand_data["spells"] > 0 then
            info = info .. "Hechizos: " .. table.concat(wand_data["spells"], ", ") .. "\n"
        else
            info = info .. "Hechizos: Ninguno\n"
        end
        if wand_data["always_cast_spells"] and #wand_data["always_cast_spells"] > 0 then
            info = info .. "Always Cast Spells: " .. table.concat(wand_data["always_cast_spells"], ", ") .. "\n"
        else
            info = info .. "Always Cast Spells: Ninguno\n"
        end
    else
        info = info .. "No se pudieron obtener datos de la varita."
    end

    return info
end

-- Función para exportar la información a un archivo
local function export_info(info)
    local file_path = "mods/Extract Player Info/files/player_info.txt"
    if ModTextFileSetContent then
        ModTextFileSetContent(file_path, info)
        GamePrint("Información extraída guardada en: " .. file_path)
    else
        GamePrint("[ERROR] No se pudo escribir el archivo.")
    end
end

-- Se ejecuta cada frame antes de actualizar el mundo
function OnWorldPreUpdate()
    local is_pressed = InputIsKeyDown(KEY_G)
    if is_pressed and not extraction_key_down then
        extraction_key_down = true
        local info = extract_wand_info()
        export_info(info)
    end

    if not is_pressed then
        extraction_key_down = false
    end
end

-- Función que se llama al iniciar el mod
function OnModInit()
    GamePrint("Mod 'Extract Player Info' cargado")
end
