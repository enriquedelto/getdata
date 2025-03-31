-- init.lua (Final Clean Version - Loads helpers in order, uses mod table)

print("DEBUG: GetData mod loading...")
GamePrint("GetData Mod: Initializing...")

-- Load dependencies first IN ORDER
-- Use pcall for initial loading to catch file-not-found or syntax errors early
local helper_ok, helper_err = pcall(dofile_once, "mods/getdata/files/helper.lua")
if not helper_ok then
    print("FATAL ERROR loading helper.lua: " .. tostring(helper_err))
    GamePrint("GetData ERROR: Failed to load helper.lua!")
    return -- Stop loading if core helper fails
else
    print("DEBUG: helper.lua execution completed")
end

local wand_spell_funcs = nil
local wand_helper_ok, wand_helper_err = pcall(function()
    -- dofile_once returns the value from the 'return' statement in the loaded file
    wand_spell_funcs = dofile_once("mods/getdata/files/wand_spell_helper.lua")
end)

if not wand_helper_ok then
     print("FATAL ERROR loading wand_spell_helper.lua: " .. tostring(wand_helper_err))
     GamePrint("GetData ERROR: Failed to load wand_spell_helper.lua!")
     return -- Stop loading if second helper fails
else
    print("DEBUG: wand_spell_helper.lua execution completed")
    if type(wand_spell_funcs) ~= "table" then
         print("ERROR: wand_spell_helper.lua did not return a table!")
         wand_spell_funcs = nil -- Ensure it's nil if it didn't return correctly
    end
end

-- Create a local table to store our functions safely
local mod = {}
local functions_loaded = false

-- Store references to our functions
function mod.init_functions()
    -- Ensure helper functions are globally accessible or passed correctly
    -- Assuming helper.lua makes get_player_id and get_all_player_inventory_items global
    -- or accessible via _G for simplicity here, as wand_spell_helper depends on it.
    -- A better pattern would be for helper.lua to also return a table.
    if _G.get_player_id then
        mod.get_player_id = _G.get_player_id
    else
        print("ERROR: get_player_id from helper.lua not found globally!")
        return false
    end
    -- We don't need get_all_player_inventory_items in the mod table directly if wand_helper uses it internally

    -- Get functions from wand_spell_helper's returned table
    if wand_spell_funcs then
        mod.get_all_wands = wand_spell_funcs.get_all_wands
        mod.read_wand = wand_spell_funcs.read_wand
        mod.get_all_spells = wand_spell_funcs.get_all_spells
        mod.read_spell = wand_spell_funcs.read_spell
    else
        print("ERROR: wand_spell_funcs table is nil, cannot assign functions.")
        return false
    end

    mod.get_player_entity = mod.get_player_id -- Alias

    -- Verify all required functions are available in the mod table
    local functions_ok = true
    local required_local_functions = {"get_all_wands", "read_wand", "get_all_spells", "read_spell", "get_player_id", "get_player_entity"}
    for _, name in ipairs(required_local_functions) do
        if type(mod[name]) ~= "function" then
            print("ERROR: Function '" .. name .. "' not loaded into mod table")
            functions_ok = false
        end
    end

    functions_loaded = functions_ok
    if functions_loaded then print("DEBUG: All required functions loaded into mod table.")
    else print("ERROR: Failed to load one or more required functions.") end
    return functions_ok
end

-- Initialize functions right after loading dependencies
if not mod.init_functions() then
    GamePrint("WARNING: GetData Mod - Func load failed.")
end

local KEY_G = 10
local extraction_key_down = false

function extract_player_info()
    print("--- DEBUG: Entering extract_player_info (Final) ---")
    if not functions_loaded then return "Error: Functions not loaded" end

    local info = "=== Player Wands ===\n"
    local player_id = mod.get_player_id()
    if not player_id then return "Error: Player entity not found" end

    local wands_success, player_wands = pcall(mod.get_all_wands)
    if wands_success and player_wands and #player_wands > 0 then
        -- print("DEBUG: Found " .. #player_wands .. " wands. Reading available data...")
        for i, wand_entity in ipairs(player_wands) do
             local read_success, wand_data = pcall(mod.read_wand, wand_entity)
            if read_success then
                info = info .. "Wand " .. tostring(i) .. " (ID: " .. wand_entity .. ") Name: "..tostring(wand_data.ui_name).."\n"
                info = info .. string.format("  %-18s %s\n", "Shuffle:", tostring(wand_data.shuffle))
                info = info .. string.format("  %-18s %s\n", "Capacity:", tostring(wand_data.capacity))
                info = info .. string.format("  %-18s %s\n", "Spells/Cast:", tostring(wand_data.spells_per_cast))
                info = info .. string.format("  %-18s %s\n", "Cast Delay:", tostring(wand_data.cast_delay))
                info = info .. string.format("  %-18s %s\n", "Recharge Time:", tostring(wand_data.recharge_time))
                info = info .. string.format("  %-18s %s\n", "Mana:", tostring(wand_data.mana))
                info = info .. string.format("  %-18s %s\n", "Mana Max:", tostring(wand_data.mana_max))
                info = info .. string.format("  %-18s %s\n", "Mana Charge:", tostring(wand_data.mana_charge_speed))
                info = info .. string.format("  %-18s %s\n", "Spread (deg):", tostring(wand_data.spread_degrees))
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

    info = info .. "\n=== Inventory Spells ===\n"
    local spells_success, spells = pcall(mod.get_all_spells)
     if spells_success and spells and #spells > 0 then
        -- print("DEBUG: Found " .. #spells .. " spells. Reading names...")
        for i, spell_entity in ipairs(spells) do
            local read_success, spell_name = pcall(mod.read_spell, spell_entity)
            if read_success then
                info = info .. tostring(i) .. ": " .. tostring(spell_name) .. " (ID: "..spell_entity..")\n"
            else
                print("ERROR: mod.read_spell() FAILED for entity " .. spell_entity .. ": " .. tostring(spell_name))
                info = info .. tostring(i) .. ": Error reading name - " .. tostring(spell_name) .. "\n"
            end
        end
    else
        info = info .. "No spells found or error occurred.\n"
         if not spells_success then print("ERROR: mod.get_all_spells() FAILED: " .. tostring(spells)) end
    end

    -- print("--- DEBUG: Exiting extract_player_info. ---") -- Less verbose
    return info
end

-- Clipboard function (Simplified)
function SetClipboard(text)
  local ok, ffi = pcall(require,"ffi")
  if not ok then GamePrint("FFI Error"); return end
  ffi.cdef"int OpenClipboard(void*);int EmptyClipboard(void);void* GlobalAlloc(unsigned int,size_t);void* GlobalLock(void*);int GlobalUnlock(void*);void* SetClipboardData(unsigned int,void*);int CloseClipboard(void);"
  local G=0x2;local C=1;local N=nil;local ok,e=pcall(function()if ffi.C.OpenClipboard(N)==0 then error()end;ffi.C.EmptyClipboard();local l=#text+1;local h=ffi.C.GlobalAlloc(G,l);if h==N then error()end;local m=ffi.C.GlobalLock(h);if m==N then error()end;ffi.copy(m,text,l-1);ffi.cast("char*",m)[l-1]=0;ffi.C.GlobalUnlock(h);if ffi.C.SetClipboardData(C,h)==N then error()end;ffi.C.CloseClipboard()end)
  if ok then GamePrint("Info Copied!") else GamePrint("Clipboard Error");pcall(ffi.C.CloseClipboard) end
end

-- World update function
function OnWorldPostUpdate()
    if not functions_loaded then return end
    local is_pressed = InputIsKeyDown(KEY_G)
    if is_pressed and not extraction_key_down then
        extraction_key_down = true
        -- GamePrint("Getting data...") -- Less verbose
        print("--- 'G' KEY PRESS DETECTED (Final) ---")
        local success, result = pcall(function() local info = extract_player_info(); SetClipboard(info) end)
        if not success then print("ERROR G-Key: "..tostring(result)); GamePrint("GetData Error") else print("--- G-Key OK ---") end
    end
    if not is_pressed then extraction_key_down = false end
end

print("DEBUG: GetData mod loaded successfully.")