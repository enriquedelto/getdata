-- init.lua

-- Mensajes de verificación de carga del mod
print("DEBUG: GetData mod loading...")
GamePrint("DEBUG: GetData mod loading...")

-- Usamos rutas relativas (esto es correcto según tu estructura)
dofile_once("files/helper.lua")
print("DEBUG: helper.lua loaded")
dofile_once("files/wand_spell_helper.lua")
print("DEBUG: wand_spell_helper.lua loaded")

-- Create a local table to store our functions
local mod = {}

-- Store references to our functions after loading
function mod.init_functions()
    mod.get_all_wands = _G.get_all_wands
    mod.read_wand = _G.read_wand
    mod.get_all_spells = _G.get_all_spells
    mod.read_spell = _G.read_spell
    
    -- Debug print current state
    print("DEBUG: Function states after init:")
    print("get_all_wands:", type(mod.get_all_wands))
    print("read_wand:", type(mod.read_wand))
    print("get_all_spells:", type(mod.get_all_spells))
    print("read_spell:", type(mod.read_spell))
end

-- Call init after loading files
dofile_once("files/helper.lua")
dofile_once("files/wand_spell_helper.lua")
mod.init_functions()

-- Verify functions are properly loaded
if type(get_all_wands) ~= "function" then
    print("ERROR: get_all_wands not loaded properly")
end
if type(read_wand) ~= "function" then
    print("ERROR: read_wand not loaded properly")
end
if type(get_all_spells) ~= "function" then
    print("ERROR: get_all_spells not loaded properly")
end
if type(read_spell) ~= "function" then
    print("ERROR: read_spell not loaded properly")
end

-- Verify functions are available
print("DEBUG: get_all_wands is " .. tostring(type(get_all_wands)))
print("DEBUG: read_wand is " .. tostring(type(read_wand)))
print("DEBUG: get_all_spells is " .. tostring(type(get_all_spells)))
print("DEBUG: read_spell is " .. tostring(type(read_spell)))

-- Definimos la tecla de extracción (código 10 = tecla G)
local KEY_G = 10
local extraction_key_down = false

-- Función que extrae la información de las varitas activas y de los hechizos
function extract_player_info()
    -- Verify functions are available
    if type(mod.get_all_wands) ~= "function" then
        print("ERROR: get_all_wands lost from mod table")
        mod.init_functions() -- Try to reinitialize
        if type(mod.get_all_wands) ~= "function" then
            GamePrint("ERROR: Could not restore get_all_wands function")
            return "Error: Functions not available"
        end
    end

    local info = "=== Varitas activas ===\n"
    
    local player_wands = mod.get_all_wands()
    for slot, wand_entity in pairs(player_wands) do
        local wand_data = mod.read_wand(wand_entity)
        info = info .. "Slot " .. tostring(slot) .. ":\n"
        for key, value in pairs(wand_data) do
            info = info .. "  " .. key .. ": " .. tostring(value) .. "\n"
        end
        info = info .. "\n"
    end
    
    info = info .. "=== Hechizos en inventario ===\n"
    local spells = mod.get_all_spells()
    for i, spell_entity in ipairs(spells) do
        local spell_id = mod.read_spell(spell_entity)
        info = info .. "Hechizo " .. tostring(i) .. ": " .. tostring(spell_id) .. "\n"
    end
    
    return info
end

-- Función para "copiar" el texto al portapapeles con mensajes de debug
function SetClipboard(text)
  print("DEBUG: Entering SetClipboard")
  GamePrint("DEBUG: Entering SetClipboard")
  print("DEBUG: Text length: " .. tostring(#text))
  print("DEBUG: Text snippet: " .. string.sub(text, 1, 100))
  
  -- Intentamos cargar FFI
  local success, ffi = pcall(require, "ffi")
  if not success then
    print("DEBUG: Failed to require ffi")
    GamePrint("DEBUG: Failed to require ffi")
    return
  else
    print("DEBUG: ffi loaded successfully")
  end
  
  ffi.cdef[[
    int OpenClipboard(void*);
    int EmptyClipboard(void);
    void* GlobalAlloc(uint32_t, size_t);
    void* GlobalLock(void*);
    int GlobalUnlock(void*);
    void* SetClipboardData(uint32_t, void*);
    int CloseClipboard(void);
  ]]
  
  local GMEM_MOVEABLE = 0x0002
  local CF_TEXT = 1
  
  local openRes = ffi.C.OpenClipboard(nil)
  print("DEBUG: OpenClipboard result: " .. tostring(openRes))
  if openRes == 0 then
    print("DEBUG: OpenClipboard failed")
    GamePrint("DEBUG: OpenClipboard failed")
    return
  end
  print("DEBUG: Clipboard opened")
  
  ffi.C.EmptyClipboard()
  print("DEBUG: Clipboard emptied")
  
  local text_len = #text + 1 -- +1 para el terminador nulo
  print("DEBUG: Allocating memory for length: " .. tostring(text_len))
  local hmem = ffi.C.GlobalAlloc(GMEM_MOVEABLE, text_len)
  if hmem == nil then
    print("DEBUG: GlobalAlloc failed")
    GamePrint("DEBUG: GlobalAlloc failed")
    ffi.C.CloseClipboard()
    return
  end
  print("DEBUG: Memory allocated: " .. tostring(hmem))
  
  local mem = ffi.C.GlobalLock(hmem)
  if mem == nil then
    print("DEBUG: GlobalLock failed")
    GamePrint("DEBUG: GlobalLock failed")
    ffi.C.CloseClipboard()
    return
  end
  print("DEBUG: Memory locked: " .. tostring(mem))
  
  ffi.copy(mem, text, text_len)
  print("DEBUG: Text copied to memory")
  
  ffi.C.GlobalUnlock(hmem)
  print("DEBUG: Memory unlocked")
  
  local setRes = ffi.C.SetClipboardData(CF_TEXT, hmem)
  print("DEBUG: SetClipboardData result: " .. tostring(setRes))
  
  ffi.C.CloseClipboard()
  print("DEBUG: Clipboard closed")
  
  GamePrint("----- INFORMACIÓN COPIADA AL PORTAPAPELES -----\n" .. text)
end

-- Función de actualización del mundo con mensajes de depuración
function OnWorldPostUpdate()
  local frame = GameGetFrameNum()
  if frame % 60 == 0 then
    print("DEBUG: OnWorldPostUpdate, frame: " .. tostring(frame))
  end
  
  local is_pressed = InputIsKeyDown(KEY_G)
  if is_pressed then
    print("DEBUG: KEY_G is pressed")
  end
  
  if is_pressed and not extraction_key_down then
    extraction_key_down = true
    print("DEBUG: Extraction triggered")
    local info = extract_player_info()
    print("DEBUG: Extracted info (first 100 chars): " .. string.sub(info, 1, 100))
    SetClipboard(info)
    print("DEBUG: SetClipboard called")
  end
  
  if not is_pressed then
    extraction_key_down = false
  end
end

-- Registro del callback (asegúrate de que este script se ejecute en un contexto en el que OnWorldPostUpdate sea llamado)
print("DEBUG: GetData mod loaded successfully")
