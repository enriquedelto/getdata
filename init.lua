-- init.lua (v2.0 - Usa get_base_spell_stats)

print("DEBUG: GetData mod loading...")
GamePrint("GetData Mod: Initializing...")

-- Load dependencies first IN ORDER
local helper_ok, helper_err = pcall(dofile_once, "mods/getdata/files/helper.lua")
if not helper_ok then print("FATAL ERROR loading helper.lua: " .. tostring(helper_err)); GamePrint("GetData ERROR: Failed to load helper.lua!"); return else print("DEBUG: helper.lua execution completed") end

local wand_spell_funcs = nil
local wand_helper_ok, wand_helper_err = pcall(function() wand_spell_funcs = dofile_once("mods/getdata/files/wand_spell_helper.lua") end)
if not wand_helper_ok then print("FATAL ERROR loading wand_spell_helper.lua: " .. tostring(wand_helper_err)); GamePrint("GetData ERROR: Failed to load wand_spell_helper.lua!"); return else print("DEBUG: wand_spell_helper.lua execution completed"); if type(wand_spell_funcs) ~= "table" then print("ERROR: wand_spell_helper.lua did not return a table!"); wand_spell_funcs = nil end end

-- Intentar cargar nxml aquí también para asegurar que el helper no falló silenciosamente
local nxml_init_ok, _ = pcall(require, "mods/getdata/files/nxml")
if not nxml_init_ok then
     GamePrint("GetData ERROR: LuaNXML (nxml.lua) not found or failed to load!")
     print("FATAL ERROR: LuaNXML (nxml.lua) failed to load. Ensure it is in mods/getdata/files/")
     -- Decidir si continuar sin stats base o detenerse
     -- return
end

local mod = {}
local functions_loaded = false

-- ***** Definición CORRECTA de mod.init_functions (v2.0) *****
function mod.init_functions()
    if _G.get_player_id then mod.get_player_id = _G.get_player_id else print("ERROR: get_player_id from helper.lua not found globally!"); return false end

    if wand_spell_funcs then
        mod.get_all_wands = wand_spell_funcs.get_all_wands
        mod.read_wand = wand_spell_funcs.read_wand
        mod.get_inventory_spell_info = wand_spell_funcs.get_inventory_spell_info
        mod.get_base_spell_stats = wand_spell_funcs.get_base_spell_stats -- NUEVA FUNCIÓN PRINCIPAL
        -- Ya no necesitamos las funciones de cache separadas
        _G.wand_helper = wand_spell_funcs -- Aún puede ser útil para debug o format_action_id
    else
        print("ERROR: wand_spell_funcs table is nil, cannot assign functions."); return false
    end

    mod.get_player_entity = mod.get_player_id

    local functions_ok = true
    local required_local_functions = {"get_all_wands", "read_wand", "get_inventory_spell_info", "get_base_spell_stats", "get_player_id", "get_player_entity"} -- Actualizado
    for _, name in ipairs(required_local_functions) do
        if type(mod[name]) ~= "function" then print("ERROR: Function '" .. name .. "' not loaded into mod table"); functions_ok = false end
    end

    functions_loaded = functions_ok
    if functions_loaded then print("DEBUG: All required functions loaded into mod table (v2.0).") else print("ERROR: Failed to load one or more required functions (v2.0).") end
    return functions_ok
end


-- ***** Llamada a ModTextFileGetContent DEBE estar aquí en init.lua, no dentro de funciones llamadas más tarde *****
-- Pre-calentar el caché llamando a get_base_spell_stats para algunos hechizos comunes al inicio.
-- NOTA: Esto solo funciona si mod.init_functions ya se ejecutó ANTES.
local function prewarm_spell_cache()
    print("DEBUG: Pre-warming spell stats cache...")
    if mod.get_base_spell_stats then
        local common_spells = {"SPARK_BOLT", "BOUNCY_ORB", "SPITTER", "BOMB", "LIGHT_BULLET", "RUBBER_BALL"} -- Añade más si quieres
        for _, action_id in ipairs(common_spells) do
            -- Usar pcall porque la lectura de archivos puede fallar
            pcall(mod.get_base_spell_stats, action_id)
        end
        print("DEBUG: Spell stats cache pre-warming finished.")
    else
         print("WARN: mod.get_base_spell_stats not available for pre-warming.")
    end
end

-- Ejecutar la inicialización y el precalentamiento
if not mod.init_functions() then
    GamePrint("WARNING: GetData Mod - Function load failed.")
else
    -- Solo intentar precalentar si las funciones se cargaron Y nxml está disponible
    if functions_loaded and nxml_init_ok then
       prewarm_spell_cache()
    elseif not nxml_init_ok then
       print("WARN: Skipping spell cache pre-warming because LuaNXML failed to load.")
    end
end


local KEY_G = 10
local extraction_key_down = false

-- ***** Definición CORRECTA de extract_player_info (v2.0) *****
function extract_player_info()
    print("--- DEBUG: Entering extract_player_info (v2.0) ---")
    if not functions_loaded then print("ERROR: extract_player_info called but functions not loaded!"); return "Error: Functions not loaded properly" end

    -- Ya no necesitamos limpiar caché aquí, se maneja dentro de get_base_spell_stats

    local info = ""
    local player_id = mod.get_player_id()
    if not player_id then return "Error: Player entity not found" end

    local all_spell_info_map = {} -- Usar mapa para evitar duplicados { [action_id] = {name=..., id=...} }

    -- === Sección Varitas ===
    info = info .. "=== Player Wands ===\n"
    local wands_success, player_wands = pcall(mod.get_all_wands)
    if wands_success and player_wands and #player_wands > 0 then
        for i, wand_entity in ipairs(player_wands) do
             local read_success, wand_data = pcall(mod.read_wand, wand_entity)
            if read_success and wand_data then
                info = info .. string.format("Wand %d (ID: %d) Name: %s\n", i, wand_entity, tostring(wand_data.ui_name))
                -- ... (imprimir stats de varita) ...
                info = info .. string.format("  %-18s %s\n", "Shuffle:", tostring(wand_data.shuffle))
                info = info .. string.format("  %-18s %s\n", "Capacity:", tostring(wand_data.capacity))
                info = info .. string.format("  %-18s %s\n", "Spells/Cast:", tostring(wand_data.spells_per_cast))
                info = info .. string.format("  %-18s %s\n", "Cast Delay:", tostring(wand_data.cast_delay))
                info = info .. string.format("  %-18s %s\n", "Recharge Time:", tostring(wand_data.recharge_time))
                info = info .. string.format("  %-18s %s\n", "Mana:", tostring(wand_data.mana))
                info = info .. string.format("  %-18s %s\n", "Mana Max:", tostring(wand_data.mana_max))
                info = info .. string.format("  %-18s %s\n", "Mana Charge:", tostring(wand_data.mana_charge_speed))
                info = info .. string.format("  %-18s %s\n", "Spread (deg):", tostring(wand_data.spread_degrees))

                -- Mostrar hechizos y añadirlos al mapa general
                if wand_data.spells and #wand_data.spells > 0 then
                    info = info .. "    Spells:\n"
                    for idx, spell_data in ipairs(wand_data.spells) do
                        local spell_name = spell_data.name or "Unknown"
                        local spell_id = spell_data.id
                        info = info .. string.format("      %d: %s (ID:%s)\n", idx, spell_name, tostring(spell_id or "N/A"))
                        if spell_id then all_spell_info_map[spell_id] = spell_data end -- Guardar/sobrescribir info
                    end
                else
                    info = info .. "    Spells: (Empty)\n"
                end
                info = info .. "\n"
            else
                print("ERROR: mod.read_wand() FAILED for entity " .. wand_entity .. ": " .. tostring(wand_data))
                info = info .. "Wand " .. i .. ": Error reading data - " .. tostring(wand_data) .. "\n\n"
            end
        end
    else
        info = info .. "No wands found or error occurred.\n"
        if not wands_success then print("ERROR: mod.get_all_wands() FAILED: " .. tostring(player_wands)) end
    end

    -- === Sección Hechizos Inventario ===
    info = info .. "\n=== Inventory Spells ===\n"
    local inv_spells_success, inv_spell_info_list = pcall(mod.get_inventory_spell_info)
     if inv_spells_success and inv_spell_info_list and #inv_spell_info_list > 0 then
        for i, spell_info_inv in ipairs(inv_spell_info_list) do
             local display_name = spell_info_inv.name or "Unknown"
             local display_id = spell_info_inv.id
             info = info .. string.format("%d: %s (ID: %s)\n", i, display_name, tostring(display_id or "N/A"))
             -- Añadir al mapa general si no estaba ya
             if display_id and not all_spell_info_map[display_id] then
                 all_spell_info_map[display_id] = spell_info_inv
             end
        end
    else
        info = info .. "No spells found in inventory or error occurred.\n"
         if not inv_spells_success then print("ERROR: mod.get_inventory_spell_info() FAILED: " .. tostring(inv_spell_info_list)) end
    end

    -- === Sección Detalles de Hechizos (Ahora usa stats base) ===
    info = info .. "\n=== Spell Base Details (Read from files) ===\n"
    if not nxml_init_ok then -- Advertir si nxml falló al inicio
        info = info .. "-- WARNING: LuaNXML library failed to load. Cannot display base stats. --\n"
    end

    local count = 0
    -- Iterar sobre el mapa de hechizos únicos encontrados
    for action_id, spell_data in pairs(all_spell_info_map) do
        count = count + 1
        info = info .. string.format("%s (ID: %s):\n", spell_data.name or "Unknown Name", action_id)

        -- Intentar obtener las stats base (usará cache si ya se leyó)
        local stats_ok, stats = pcall(mod.get_base_spell_stats, action_id)

        if stats_ok and stats then
            info = info .. string.format("  %-18s %s\n", "Mana Cost:", tostring(stats.mana_drain or "N/A"))
            local uses_str = "N/A"
            if stats.uses then uses_str = (stats.uses == -1) and "Infinite" or tostring(stats.uses) end
            info = info .. string.format("  %-18s %s\n", "Uses:", uses_str)
            info = info .. string.format("  %-18s %s%%\n", "Critical Chance:", string.format("%.0f", stats.crit_chance or 0))

            local damage_str = ""
            if (stats.damage_projectile or 0) > 0 then damage_str = damage_str .. "Proj:" .. stats.damage_projectile .. " " end
            if (stats.damage_explosion or 0) > 0 then damage_str = damage_str .. "Expl:" .. stats.damage_explosion .. " " end
            if (stats.damage_fire or 0) > 0 then damage_str = damage_str .. "Fire:" .. stats.damage_fire .. " " end
            if (stats.damage_ice or 0) > 0 then damage_str = damage_str .. "Ice:" .. stats.damage_ice .. " " end
            if (stats.damage_electricity or 0) > 0 then damage_str = damage_str .. "Elec:" .. stats.damage_electricity .. " " end
            if (stats.damage_slice or 0) > 0 then damage_str = damage_str .. "Slice:" .. stats.damage_slice .. " " end
            if (stats.damage_melee or 0) > 0 then damage_str = damage_str .. "Melee:" .. stats.damage_melee .. " " end
            if (stats.damage_drill or 0) > 0 then damage_str = damage_str .. "Drill:" .. stats.damage_drill .. " " end
            if (stats.damage_healing or 0) > 0 then damage_str = damage_str .. "Heal:" .. stats.damage_healing .. " " end
            if (stats.damage_curse or 0) > 0 then damage_str = damage_str .. "Curse:" .. stats.damage_curse .. " " end
            if damage_str == "" then damage_str = "None/Unknown" end -- Si no se encontró nada

            info = info .. string.format("  %-18s %s\n", "Base Damage:", damage_str:gsub("%s$", "")) -- Etiqueta más clara
            info = info .. string.format("  %-18s %s\n", "Projectile File:", stats.projectile_file or "N/A")
        elseif not nxml_init_ok then
             info = info .. "  (Base stats unavailable - LuaNXML missing)\n"
        else
            info = info .. "  (Failed to read/parse base stats for this spell - Check logs)\n"
            print(string.format("ERROR: Failed to get base stats for %s: %s", action_id, tostring(stats))) -- 'stats' aquí es el mensaje de error del pcall
        end
        info = info .. "\n" -- Línea en blanco entre hechizos
    end

    if count == 0 then
         info = info .. "No spells found in wands or inventory.\n"
    end

    return info
end

-- ***** Funciones SetClipboard y OnWorldPostUpdate (Sin cambios) *****
-- ... (igual que v1.8) ...
function SetClipboard(text)
  local ok, ffi = pcall(require,"ffi")
  if not ok then GamePrint("FFI Error"); return end
  ffi.cdef"int OpenClipboard(void*);int EmptyClipboard(void);void* GlobalAlloc(unsigned int,size_t);void* GlobalLock(void*);int GlobalUnlock(void*);void* SetClipboardData(unsigned int,void*);int CloseClipboard(void);"
  local G=0x2;local C=1;local N=nil;local ok,e=pcall(function()if ffi.C.OpenClipboard(N)==0 then error()end;ffi.C.EmptyClipboard();local l=#text+1;local h=ffi.C.GlobalAlloc(G,l);if h==N then error()end;local m=ffi.C.GlobalLock(h);if m==N then error()end;ffi.copy(m,text,l-1);ffi.cast("char*",m)[l-1]=0;ffi.C.GlobalUnlock(h);if ffi.C.SetClipboardData(C,h)==N then error()end;ffi.C.CloseClipboard()end)
  if ok then GamePrint("Info Copied!") else GamePrint("Clipboard Error");pcall(ffi.C.CloseClipboard) end
end

function OnWorldPostUpdate()
    if not functions_loaded then return end
    local is_pressed = InputIsKeyDown(KEY_G)
    if is_pressed and not extraction_key_down then
        extraction_key_down = true
        print("--- 'G' KEY PRESS DETECTED (v2.0) ---")
        local success, result = pcall(function() local info = extract_player_info(); SetClipboard(info) end)
        if not success then print("ERROR G-Key Action: "..tostring(result)); GamePrint("GetData Error during extraction/copy!") else print("--- G-Key Action OK ---") end
    end
    if not is_pressed then extraction_key_down = false end
end


print("DEBUG: GetData mod loaded successfully (end of init.lua v2.0).")