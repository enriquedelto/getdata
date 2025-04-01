-- /files/wand_spell_helper.lua (v2.1 - Corregido error de formato en patrones y añadido mapeo XML)
print("DEBUG: Loading wand_spell_helper.lua (v2.1 - Fixed pattern format error and added XML mapping)...")

local wand_helper = {}

-- Cache para estadísticas base de hechizos por action_id
wand_helper.base_spell_stats_cache = {}

-- Intentar cargar LuaNXML (debe estar en tu mod, ej: files/nxml.lua)
local nxml_ok, nxml = pcall(require, "mods/getdata/files/nxml")
if not nxml_ok then
    print("FATAL ERROR: Could not load LuaNXML library (nxml.lua). Place it in mods/getdata/files/. Error: " .. tostring(nxml))
    -- Podríamos deshabilitar la función de stats base o retornar aquí
end

-- Cache para el contenido de gun_actions.lua para no leerlo múltiples veces
local gun_actions_content_cache = nil

local get_items_func = get_all_player_inventory_items or function() print("ERROR: get_all_player_inventory_items not loaded!") return {} end

-- Formatear Action ID
local function format_action_id(action_id)
    -- ... (función de formateo v1.7/v1.8) ...
    if action_id == nil then return "unknown (No ActionID)" end
    local name = action_id:gsub("_", " "):lower()
    name = name:gsub("(%w)(%w*)", function(c1, rest) return c1:upper() .. rest end)
     -- Correcciones específicas comunes
    name = name:gsub("Tier ", "T"):gsub("Bullet", "Bolt") -- Ej: Spitter T2 Timer
    return name
end

-- Helper para mergear tablas (stats actuales sobreescriben base)
local function merge_tables(base, current)
    local merged = {}
    for k, v in pairs(base) do merged[k] = v end
    if current then
        for k, v in pairs(current) do if v ~= nil then merged[k] = v end end -- Sobrescribir/añadir si no es nil
    end
    return merged
end

-- Lee y parsea un archivo XML, manejando la herencia <Base>
local function parse_xml_with_inheritance(filepath, visited_files)
    visited_files = visited_files or {} -- Evitar bucles infinitos de herencia
    -- Verificar si el path es válido antes de proceder
    if not filepath or type(filepath) ~= "string" or filepath == "" then
         print("WARN: Invalid filepath provided to parse_xml_with_inheritance: "..tostring(filepath))
         return nil, {}
    end
    if visited_files[filepath] then
        print("WARN: Circular inheritance detected for XML file: " .. filepath)
        return nil, {} -- Devolver tabla vacía para stats base en caso de bucle
    end
    visited_files[filepath] = true

    -- Leer archivo
    -- Usar pcall aquí también por si ModTextFileGetContent falla
    local read_ok, xml_content = pcall(ModTextFileGetContent, filepath)
    if not read_ok or not xml_content then
        print("WARN: Failed to read XML file: " .. filepath .. (read_ok and "" or " Error: "..tostring(xml_content)))
        return nil, {}
    end

    -- Parsear XML
    local parse_ok, xml_root = pcall(nxml.parse, xml_content)
    if not parse_ok or not xml_root then
        print("WARN: Failed to parse XML file: " .. filepath .. " Error: " .. tostring(xml_root))
        return nil, {}
    end

    local base_stats = {}
    local current_stats = {}

    -- Manejar herencia
    local base_tag = xml_root:first_of("Base")
    if base_tag and base_tag.attr and base_tag.attr.file then
        local base_filepath = base_tag.attr.file
        -- Recursivamente parsear la base y obtener sus stats finales mergeadas
        local _, recursive_base_stats = parse_xml_with_inheritance(base_filepath, visited_files)
        base_stats = recursive_base_stats
    end

    -- Extraer stats del XML ACTUAL (sobrescribirán las de la base)
    local ability_comp = xml_root:first_of("AbilityComponent")
    if ability_comp then
        local gunaction_cfg = ability_comp:first_of("gunaction_config")
        if gunaction_cfg and gunaction_cfg.attr then
            current_stats.mana_drain = tonumber(gunaction_cfg.attr.action_mana_drain)
            current_stats.uses = tonumber(gunaction_cfg.attr.action_max_uses)
            current_stats.crit_chance = (tonumber(gunaction_cfg.attr.damage_critical_chance) or 0) * 100
            current_stats.projectile_file = gunaction_cfg.attr.projectile_file or gunaction_cfg.attr.entity_file
        end
    end

    local projectile_comp = xml_root:first_of("ProjectileComponent")
    if projectile_comp then
        if projectile_comp.attr then
             current_stats.damage_projectile = tonumber(projectile_comp.attr.damage)
        end
        local damage_by_type = projectile_comp:first_of("damage_by_type")
        if damage_by_type and damage_by_type.attr then
             current_stats.damage_fire = tonumber(damage_by_type.attr.fire or 0)
             current_stats.damage_ice = tonumber(damage_by_type.attr.ice or 0)
             current_stats.damage_electricity = tonumber(damage_by_type.attr.electricity or 0)
             current_stats.damage_slice = tonumber(damage_by_type.attr.slice or 0)
             current_stats.damage_melee = tonumber(damage_by_type.attr.melee or 0)
             current_stats.damage_drill = tonumber(damage_by_type.attr.drill or 0)
             current_stats.damage_healing = tonumber(damage_by_type.attr.healing or 0)
             current_stats.damage_curse = tonumber(damage_by_type.attr.curse or 0)
        end
        local explosion_config = projectile_comp:first_of("config_explosion")
        if explosion_config and explosion_config.attr and explosion_config.attr.damage then
            current_stats.damage_explosion = tonumber(explosion_config.attr.damage)
        end
        -- Actualizar projectile_file si se encuentra aquí y no antes
         if not current_stats.projectile_file then current_stats.projectile_file = projectile_comp.attr.projectile_file or projectile_comp.attr.entity_file end
    end

    local explosion_comp_direct = xml_root:first_of("ExplosionComponent")
     if explosion_comp_direct then
          local exp_cfg_direct = explosion_comp_direct:first_of("config_explosion")
          if exp_cfg_direct and exp_cfg_direct.attr and exp_cfg_direct.attr.damage then
               if not current_stats.damage_explosion or current_stats.damage_explosion == 0 then
                    current_stats.damage_explosion = tonumber(exp_cfg_direct.attr.damage)
               end
          end
     end

    local final_stats = merge_tables(base_stats, current_stats)
    return xml_root, final_stats
end

-- Función principal para obtener stats base (usa cache)
function wand_helper.get_base_spell_stats(action_id)
    if not action_id then return nil end
    if wand_helper.base_spell_stats_cache[action_id] then return wand_helper.base_spell_stats_cache[action_id] end
    if not nxml_ok then print("WARN: LuaNXML not loaded, cannot fetch base stats for " .. action_id); return nil end

    local stats = {
        action_id = action_id, formatted_name = format_action_id(action_id),
        mana_drain = nil, uses = nil, crit_chance = nil,
        damage_projectile = 0, damage_explosion = 0, damage_fire = 0, damage_ice = 0, damage_electricity = 0, damage_slice = 0, damage_melee = 0, damage_drill = 0, damage_healing = 0, damage_curse = 0,
        projectile_file = nil
    }

    -- Leer de gun_actions.lua (Mana/Uses)
    if not gun_actions_content_cache then
        local read_ok, content = pcall(ModTextFileGetContent, "data/scripts/gun/gun_actions.lua")
        if read_ok and content then gun_actions_content_cache = content else print("WARN: Could not read data/scripts/gun/gun_actions.lua. Error: " .. tostring(content)); gun_actions_content_cache = "" end
    end
    if gun_actions_content_cache ~= "" then
        -- *** Patrones Corregidos v2.1 ***
        local pattern1 = 'action_id = "' .. action_id .. '".-\n.-action_mana_drain = (%d*%.?%d*),.-\n.-action_max_uses = (%-?%d+)'
        local pattern2 = action_id .. '%s*=%s*{%s*.-action_mana_drain%s*=%s*(%d*%.?%d*),.-action_max_uses%s*=%s*(%-?%d+)' -- Patrón más robusto para { }

        local drain_str, uses_str = string.match(gun_actions_content_cache, pattern1)
        if not drain_str then drain_str, uses_str = string.match(gun_actions_content_cache, pattern2) end

        -- Si aún no se encuentra, intentar buscar asignaciones directas separadas (menos común)
        if not drain_str then drain_str = string.match(gun_actions_content_cache, action_id .. '%s*%.%s*action_mana_drain%s*=%s*(%d*%.?%d*)') end
        if not uses_str then uses_str = string.match(gun_actions_content_cache, action_id .. '%s*%.%s*action_max_uses%s*=%s*(%-?%d+)') end

        if drain_str then stats.mana_drain = tonumber(drain_str) end
        if uses_str then stats.uses = tonumber(uses_str) end
    end

    -- Determinar y leer XML usando el mapeo
    local xml_path = action_id_to_xml_map[action_id]

    if not xml_path then
         -- Intentar derivar path genérico si no está en el mapa
         local derived_path_proj = string.format("data/entities/projectiles/deck/%s.xml", string.lower(action_id))
         local derived_path_action = string.format("data/entities/items/actions/%s.xml", string.lower(action_id))
         
         local check_ok_proj, _ = pcall(ModTextFileGetContent, derived_path_proj)
         if check_ok_proj then
             xml_path = derived_path_proj
             -- print("DEBUG: Derived XML path (proj): " .. xml_path)
         else
             local check_ok_action, _ = pcall(ModTextFileGetContent, derived_path_action)
             if check_ok_action then
                 xml_path = derived_path_action
                 -- print("DEBUG: Derived XML path (action): " .. xml_path)
             end
         end
    end

    if xml_path then
        local _, xml_stats = parse_xml_with_inheritance(xml_path)
        stats = merge_tables(stats, xml_stats) -- Mergear stats del XML (daños, etc.)
    else
        print("WARN: No XML path found in map or derived for action_id: " .. action_id)
    end

    -- Cachear y devolver
    wand_helper.base_spell_stats_cache[action_id] = stats
    return stats
end

-- --- Resto de funciones (read_spell_name_and_id, get_all_wands, read_wand, get_inventory_spell_info) ---
function wand_helper.read_spell_name_and_id(spell_entity)
    local result = { name = "unknown", id = nil }
    if not EntityGetIsAlive(spell_entity) then result.name = "unknown (Entity Dead)"; return result end
    local spell_ability_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "AbilityComponent"); if spell_ability_comp then local ui_name_ability = ComponentGetValue2(spell_ability_comp, "ui_name"); if ui_name_ability and ui_name_ability ~= "" and ui_name_ability:sub(1,1) == "$" then result.name = ui_name_ability; local iac = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemActionComponent"); if iac then result.id = ComponentGetValue2(iac, "action_id") end; return result end end
    local item_action_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemActionComponent"); if item_action_comp then local action_id = ComponentGetValue2(item_action_comp, "action_id"); if action_id and action_id ~= "" then result.id = action_id; result.name = format_action_id(action_id); local item_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemComponent"); if item_comp then local iname = ComponentGetValue2(item_comp, "item_name"); if iname and iname ~= "" then result.name = iname; return result end; local uiname = ComponentGetValue2(item_comp, "ui_name"); if uiname and uiname ~= "" then result.name = uiname; return result end end; return result else result.name = "unknown (Empty ActionID)" end end
    local item_comp_fallback = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemComponent"); if item_comp_fallback then local iname = ComponentGetValue2(item_comp_fallback, "item_name"); if iname and iname ~= "" then result.name = iname; return result end; local uiname = ComponentGetValue2(item_comp_fallback, "ui_name"); if uiname and uiname ~= "" then result.name = uiname; return result end; result.name = "unknown (No ActionID, ItemComp names empty)"; return result end
    result.name = "unknown (No Action/Item/Ability Comp)"; return result
end

function wand_helper.get_all_wands()
    local all_items = get_items_func(); local wands = {}; for _, item_id in ipairs(all_items) do if EntityGetIsAlive(item_id) and EntityHasTag(item_id, "wand") then table.insert(wands, item_id) end end; return wands
end

function wand_helper.read_wand(wand_entity)
    local wand_data = {}; wand_data["ui_name"] = "Unknown Wand"; wand_data["shuffle"] = "N/A"; wand_data["capacity"] = 0; wand_data["spells_per_cast"] = 0; wand_data["cast_delay"] = "0.00"; wand_data["recharge_time"] = "0.00"; wand_data["mana_max"] = 0; wand_data["mana_charge_speed"] = 0; wand_data["mana"] = 0; wand_data["spread_degrees"] = "0.00"; wand_data["spells"] = {}
    if not EntityGetIsAlive(wand_entity) then wand_data["ui_name"] = "Unknown Wand (Entity Dead)"; return wand_data end
    local ability_comp = EntityGetFirstComponentIncludingDisabled(wand_entity, "AbilityComponent"); if not ability_comp then local ic = EntityGetFirstComponentIncludingDisabled(wand_entity, "ItemComponent"); if ic then wand_data["ui_name"] = ComponentGetValue2(ic, "ui_name") or ComponentGetValue2(ic, "item_name") or "UW(NoAC)" else wand_data["ui_name"] = "UW(NoAC/IC)" end; return wand_data end
    wand_data["mana"] = ComponentGetValue2(ability_comp, "mana") or 0; wand_data["mana_max"] = ComponentGetValue2(ability_comp, "mana_max") or 0; wand_data["mana_charge_speed"] = ComponentGetValue2(ability_comp, "mana_charge_speed") or 0; wand_data["ui_name"] = ComponentGetValue2(ability_comp, "ui_name") or "UW(fAC)"
    local gco = "gun_config"; local cap = ComponentObjectGetValue2(ability_comp, gco, "deck_capacity"); if cap ~= nil then wand_data["capacity"] = cap end; local spc = ComponentObjectGetValue2(ability_comp, gco, "actions_per_round"); if spc ~= nil then wand_data["spells_per_cast"] = spc end; local cd = ComponentObjectGetValue2(ability_comp, gco, "reload_time"); if cd ~= nil then wand_data["cast_delay"] = string.format("%.2f", cd / 60.0) end; local shuf = ComponentObjectGetValue2(ability_comp, gco, "shuffle_deck_when_empty"); if shuf ~= nil then wand_data["shuffle"] = (shuf == 1 or shuf == true) and "Yes" or "No" end
    local gaco = "gunaction_config"; local rt = ComponentObjectGetValue2(ability_comp, gaco, "fire_rate_wait"); if rt ~= nil then wand_data["recharge_time"] = string.format("%.2f", rt / 60.0) else wand_data["recharge_time"] = "N/A" end; local sp = ComponentObjectGetValue2(ability_comp, gaco, "spread_degrees"); if sp ~= nil then wand_data["spread_degrees"] = string.format("%.2f", sp) else wand_data["spread_degrees"] = "N/A" end
    local child_entities = EntityGetAllChildren(wand_entity); if child_entities then for _, child_id in ipairs(child_entities) do if EntityGetIsAlive(child_id) and EntityHasTag(child_id, "card_action") then local spell_info = wand_helper.read_spell_name_and_id(child_id); table.insert(wand_data["spells"], spell_info) end end end
    return wand_data
end

function wand_helper.get_inventory_spell_info()
    local all_inventory_items = get_items_func(); local spell_info_list = {}; if not all_inventory_items or #all_inventory_items == 0 then return spell_info_list end; for _, item_id in ipairs(all_inventory_items) do if EntityHasTag(item_id, "card_action") and not EntityHasTag(item_id, "wand") then local spell_info = wand_helper.read_spell_name_and_id(item_id); table.insert(spell_info_list, spell_info) end end; return spell_info_list
end

print("DEBUG: wand_spell_helper.lua loaded successfully (v2.1)")

return wand_helper