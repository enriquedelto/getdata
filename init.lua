-- Verify mod loading with debug message
print("GetData mod loading...")
GamePrint("GetData mod loading...")
-- init.lua

-- Use relative paths for importing
dofile_once("files/helper.lua")
dofile_once("files/wand_spell_helper.lua")

-- Definimos la tecla de extracción. En este ejemplo se utiliza el código 10, que corresponde a la tecla G.
local KEY_G = 10
local extraction_key_down = false

-- Función que extrae la información de las varitas activas y de los hechizos
function extract_player_info()
  local info = "=== Varitas activas ===\n"
  
  -- Se obtienen las varitas del inventario rápido (suponiendo que allí se encuentran las varitas equipadas)
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

-- Función para “copiar” el texto al portapapeles.
-- En este ejemplo se simula copiándolo al imprimirlo, pero podrías reemplazarla por una función que interactúe con el sistema.
function SetClipboard(text)
  -- Mantener la impresión en el juego para feedback
  GamePrint("----- INFORMACIÓN COPIADA AL PORTAPAPELES -----\n" .. text)
  
  -- Usar LuaJIT FFI para acceder a la API de Windows
  local ffi = require("ffi")
  
  ffi.cdef[[
    int OpenClipboard(void*);
    void* GlobalAlloc(uint32_t, size_t);
    void* GlobalLock(void*);
    void GlobalUnlock(void*);
    void* SetClipboardData(uint32_t, void*);
    void CloseClipboard(void);
    int EmptyClipboard(void);
  ]]
  
  -- Constantes de Windows
  local GMEM_MOVEABLE = 0x0002
  local CF_TEXT = 1
  
  -- Abrir el portapapeles
  if ffi.C.OpenClipboard(nil) ~= 0 then
    -- Limpiar el contenido actual
    ffi.C.EmptyClipboard()
    
    -- Alojar memoria para el texto
    local text_len = #text + 1  -- +1 para el null terminator
    local hmem = ffi.C.GlobalAlloc(GMEM_MOVEABLE, text_len)
    if hmem ~= nil then
      -- Copiar el texto a la memoria
      local mem = ffi.C.GlobalLock(hmem)
      if mem ~= nil then
        ffi.copy(mem, text, text_len)
        ffi.C.GlobalUnlock(hmem)
        
        -- Establecer los datos en el portapapeles
        ffi.C.SetClipboardData(CF_TEXT, hmem)
      end
    end
    
    -- Cerrar el portapapeles
    ffi.C.CloseClipboard()
  end
end

-- Función que se llama cada frame y verifica si se ha pulsado la tecla G.
function OnWorldPostUpdate()
  -- Debug message to verify callback execution
  if GameGetFrameNum() % 60 == 0 then
    print("GetData mod running...")
  end

  local is_pressed = InputIsKeyDown(KEY_G)
  
  -- Si se detecta la pulsación y aún no se ha procesado la extracción en este ciclo
  if is_pressed and not extraction_key_down then
    extraction_key_down = true
    local info = extract_player_info()
    SetClipboard(info)
    print("Información del jugador extraída y copiada al portapapeles.")
  end

  -- Cuando se suelta la tecla, se reinicia la bandera para permitir futuras extracciones.
  if not is_pressed then
    extraction_key_down = false
  end
end

-- Registro de la función de actualización del mundo
function OnModPreInit()
  ModLuaFileAppend("data/scripts/gun/gun_actions.lua", "mods/getdata/init.lua")
end

function OnModInit()
  ModLuaFileAppend("data/scripts/gun/gun_actions.lua", "mods/getdata/init.lua")
end

function OnModPostInit()
  ModLuaFileAppend("data/scripts/gun/gun_actions.lua", "mods/getdata/init.lua")
end

print("GetData mod loaded successfully")
