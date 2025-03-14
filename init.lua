-- init.lua

-- Se cargan las funciones auxiliares definidas en helper.lua y wand_spell_helper.lua
dofile_once("mods/getdata/files/helper.lua")
dofile_once("mods/getdata/files/wand_spell_helper.lua")

-- Definimos la tecla de extracción (tecla G, código 10)
local KEY_G = 10
local extraction_key_down = false

-- Función que extrae la información de las varitas activas y de los hechizos en el inventario
function extract_player_info()
  local info = "=== Varitas activas ===\n"
  
  -- Se obtienen las varitas del inventario rápido (se supone que ahí están las varitas equipadas)
  local player_wands = get_all_wands()
  for slot, wand_entity in pairs(player_wands) do
    local wand_data = read_wand(wand_entity)
    info = info .. "Slot " .. tostring(slot) .. ":\n"
    for key, value in pairs(wand_data) do
      info = info .. "  " .. key .. ": " .. tostring(value) .. "\n"
    end
    info = info .. "\n"
  end
  
  info = info .. "=== Hechizos en inventario ===\n"
  -- Se obtienen todos los hechizos del inventario completo
  local spells = get_all_spells()
  for i, spell_entity in ipairs(spells) do
    local spell_id = read_spell(spell_entity)
    info = info .. "Hechizo " .. tostring(i) .. ": " .. tostring(spell_id) .. "\n"
  end
  
  return info
end

-- Función que “copia” el texto al portapapeles.
-- Aquí se simula imprimiendo el resultado, pero se puede reemplazar por una función que interactúe con el sistema.
function SetClipboard(text)
  -- Si tu entorno admite copiar al portapapeles, reemplaza esta función.
  print("----- INFORMACIÓN COPIADA AL PORTAPAPELES -----\n" .. text)
end

-- Función de actualización que se llama cada frame
function OnWorldPreUpdate()
    local is_pressed = InputIsKeyDown(KEY_G)
    if is_pressed and not extraction_key_down then
        extraction_key_down = true
        local info = extract_player_info()
        SetClipboard(info)
        print("Información del jugador extraída y copiada al portapapeles.")
    end

    if not is_pressed then
        extraction_key_down = false
    end
end
