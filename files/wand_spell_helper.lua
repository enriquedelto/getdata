-- /files/wand_spell_helper.lua (v2.0 - Lectura de stats base desde archivos)
print("DEBUG: Loading wand_spell_helper.lua (v2.0 - Reading base stats from files)...")

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
    if visited_files[filepath] then
        print("WARN: Circular inheritance detected for XML file: " .. filepath)
        return nil, {} -- Devolver tabla vacía para stats base en caso de bucle
    end
    visited_files[filepath] = true

    -- Leer archivo
    local xml_content = ModTextFileGetContent(filepath)
    if not xml_content then
        print("WARN: Failed to read XML file: " .. filepath)
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
        -- Normalizar path (asumir que está relativo a data/)
        local base_filepath = base_tag.attr.file
        -- print("DEBUG: Found base tag in "..filepath..", parsing base file: "..base_filepath)
        local base_root, recursive_base_stats = parse_xml_with_inheritance(base_filepath, visited_files)
        -- Usar las stats mergeadas de la base recursiva
        base_stats = recursive_base_stats
    end

    -- Extraer stats del XML ACTUAL (sobrescribirán las de la base)
    -- Mana/Uses no suelen estar aquí, pero los buscamos por si acaso
    local ability_comp = xml_root:first_of("AbilityComponent")
    if ability_comp then
        local gunaction_cfg = ability_comp:first_of("gunaction_config")
        if gunaction_cfg and gunaction_cfg.attr then
            if gunaction_cfg.attr.action_mana_drain then current_stats.mana_drain = tonumber(gunaction_cfg.attr.action_mana_drain) end
            if gunaction_cfg.attr.action_max_uses then current_stats.uses = tonumber(gunaction_cfg.attr.action_max_uses) end
            if gunaction_cfg.attr.damage_critical_chance then current_stats.crit_chance = tonumber(gunaction_cfg.attr.damage_critical_chance) * 100 end
            -- Guardar el path del proyectil si se encuentra aquí
            if gunaction_cfg.attr.projectile_file and gunaction_cfg.attr.projectile_file ~= "" then current_stats.projectile_file = gunaction_cfg.attr.projectile_file end
             if gunaction_cfg.attr.entity_file and gunaction_cfg.attr.entity_file ~= "" then current_stats.projectile_file = gunaction_cfg.attr.entity_file end -- A veces se usa entity_file
        end
    end

    -- Extraer daños del ProjectileComponent
    local projectile_comp = xml_root:first_of("ProjectileComponent")
    if projectile_comp and projectile_comp.attr then
        if projectile_comp.attr.damage then current_stats.damage_projectile = tonumber(projectile_comp.attr.damage) end
        -- Buscar daños específicos si existen
        local damage_by_type = projectile_comp:first_of("damage_by_type")
        if damage_by_type and damage_by_type.attr then
             current_stats.damage_fire = tonumber(damage_by_type.attr.fire or 0)
             current_stats.damage_ice = tonumber(damage_by_type.attr.ice or 0)
             current_stats.damage_electricity = tonumber(damage_by_type.attr.electricity or 0)
             current_stats.damage_slice = tonumber(damage_by_type.attr.slice or 0)
             current_stats.damage_melee = tonumber(damage_by_type.attr.melee or 0) -- Aunque raro en projectile
             current_stats.damage_drill = tonumber(damage_by_type.attr.drill or 0)
             current_stats.damage_healing = tonumber(damage_by_type.attr.healing or 0)
             current_stats.damage_curse = tonumber(damage_by_type.attr.curse or 0)
        end
        -- Guardar el path del proyectil si se encuentra aquí y no se encontró antes
         if not current_stats.projectile_file and projectile_comp.attr.projectile_file and projectile_comp.attr.projectile_file ~= "" then current_stats.projectile_file = projectile_comp.attr.projectile_file end
         if not current_stats.projectile_file and projectile_comp.attr.entity_file and projectile_comp.attr.entity_file ~= "" then current_stats.projectile_file = projectile_comp.attr.entity_file end
    end

     -- Extraer daño de explosión
    local explosion_config = xml_root:first_of("config_explosion") -- A veces está fuera de ProjectileComponent
    if not explosion_config and projectile_comp then explosion_config = projectile_comp:first_of("config_explosion") end -- O dentro
    if explosion_config and explosion_config.attr and explosion_config.attr.damage then
        current_stats.damage_explosion = tonumber(explosion_config.attr.damage)
    end

    -- Mergear stats actuales sobre las base
    local final_stats = merge_tables(base_stats, current_stats)

    return xml_root, final_stats
end

-- Función principal para obtener stats base (usa cache)
function wand_helper.get_base_spell_stats(action_id)
    if not action_id then return nil end
    -- 1. Verificar Cache
    if wand_helper.base_spell_stats_cache[action_id] then
        return wand_helper.base_spell_stats_cache[action_id]
    end

    -- Asegurarse de que nxml está cargado
    if not nxml_ok then return nil end

    local stats = {
        action_id = action_id,
        formatted_name = format_action_id(action_id),
        mana_drain = nil, uses = nil, crit_chance = nil,
        damage_projectile = 0, damage_explosion = 0, damage_fire = 0, damage_ice = 0, damage_electricity = 0, damage_slice = 0, damage_melee = 0, damage_drill = 0, damage_healing = 0, damage_curse = 0,
        projectile_file = nil
    }

    -- 2. Leer de gun_actions.lua (Mana/Uses) - ¡Frágil!
    if not gun_actions_content_cache then
        gun_actions_content_cache = ModTextFileGetContent("data/scripts/gun/gun_actions.lua")
    end
    if gun_actions_content_cache then
         -- Intentar patrones más flexibles
        local pattern1 = string.format('action_id = "%s".-%saction_mana_drain = (%d*%.?%d*),.-action_max_uses = (%-?%d+)', action_id, "\n", "\n")
        local pattern2 = string.format('%s = {.-action_mana_drain = (%d*%.?%d*),.-action_max_uses = (%-?%d+)', action_id) -- Si está en una línea

        local drain_str, uses_str = string.match(gun_actions_content_cache, pattern1)
        if not drain_str then drain_str, uses_str = string.match(gun_actions_content_cache, pattern2) end

        if drain_str then stats.mana_drain = tonumber(drain_str) end
        if uses_str then stats.uses = tonumber(uses_str) end
        -- print("DEBUG: gun_actions.lua read for "..action_id..": mana="..tostring(stats.mana_drain).." uses="..tostring(stats.uses))
    else
        print("WARN: Could not read data/scripts/gun/gun_actions.lua")
    end

    -- 3. Determinar y leer XML de acción/proyectil
    -- Necesitamos un mapeo mejor o lógica para encontrar el archivo correcto.
    -- Ejemplo simple (necesita expansión):
    local xml_path = nil
    if action_id == "BOMB" then xml_path = "data/entities/items/actions/bomb.xml" -- El item BOMB tiene su propio AbilityComp
    elseif action_id == "SPITTER" then xml_path = "data/entities/projectiles/deck/spitter.xml" -- Asumiendo que el proyectil define más
    elseif action_id == "LIGHT_BULLET" then xml_path = "data/entities/projectiles/deck/light_bullet.xml"
    elseif action_id == "BOUNCY_ORB" then xml_path = "data/entities/projectiles/deck/bouncy_orb.xml"
    -- Añadir más mapeos aquí para otros hechizos...
    -- O intentar derivar el path: string.format("data/entities/projectiles/deck/%s.xml", string.lower(action_id)) - esto falla a menudo
    end

    if xml_path then
        local _, xml_stats = parse_xml_with_inheritance(xml_path)
        -- Sobrescribir/añadir stats del XML (priorizando las del XML si existen)
        stats = merge_tables(stats, xml_stats)
        -- print("DEBUG: XML stats merged for "..action_id..": crit="..tostring(stats.crit_chance).." proj_dmg="..tostring(stats.damage_projectile))
    else
        print("WARN: No XML path defined or derived for action_id: " .. action_id)
    end

    -- 4. Cachear y devolver
    wand_helper.base_spell_stats_cache[action_id] = stats
    return stats
end

-- Funciones anteriores (simplificadas para no usar el caché viejo)
function wand_helper.read_spell_name_and_id(spell_entity)
    -- ... (igual que v1.8) ...
    local result = { name = "unknown", id = nil }
    if not EntityGetIsAlive(spell_entity) then result.name = "unknown (Entity Dead)"; return result end
    local spell_ability_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "AbilityComponent")
    if spell_ability_comp then local ui_name_ability = ComponentGetValue2(spell_ability_comp, "ui_name"); if ui_name_ability and ui_name_ability ~= "" and ui_name_ability:sub(1,1) == "$" then result.name = ui_name_ability; local iac = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemActionComponent"); if iac then result.id = ComponentGetValue2(iac, "action_id") end; return result end end
    local item_action_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemActionComponent"); if item_action_comp then local action_id = ComponentGetValue2(item_action_comp, "action_id"); if action_id and action_id ~= "" then result.id = action_id; result.name = format_action_id(action_id); local item_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemComponent"); if item_comp then local iname = ComponentGetValue2(item_comp, "item_name"); if iname and iname ~= "" then result.name = iname; return result end; local uiname = ComponentGetValue2(item_comp, "ui_name"); if uiname and uiname ~= "" then result.name = uiname; return result end end; return result else result.name = "unknown (Empty ActionID)" end end
    local item_comp_fallback = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemComponent"); if item_comp_fallback then local iname = ComponentGetValue2(item_comp_fallback, "item_name"); if iname and iname ~= "" then result.name = iname; return result end; local uiname = ComponentGetValue2(item_comp_fallback, "ui_name"); if uiname and uiname ~= "" then result.name = uiname; return result end; result.name = "unknown (No ActionID, ItemComp names empty)"; return result end
    result.name = "unknown (No Action/Item/Ability Comp)"; return result
end

function wand_helper.get_all_wands()
    -- ... (igual que v1.8) ...
    local all_items = get_items_func(); local wands = {}; for _, item_id in ipairs(all_items) do if EntityGetIsAlive(item_id) and EntityHasTag(item_id, "wand") then table.insert(wands, item_id) end end; return wands
end

function wand_helper.read_wand(wand_entity)
    -- ... (igual que v1.8 pero SIN poblar el caché de stats detalladas) ...
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
    -- ... (igual que v1.8) ...
    local all_inventory_items = get_items_func(); local spell_info_list = {}; if not all_inventory_items or #all_inventory_items == 0 then return spell_info_list end; for _, item_id in ipairs(all_inventory_items) do if EntityHasTag(item_id, "card_action") and not EntityHasTag(item_id, "wand") then local spell_info = wand_helper.read_spell_name_and_id(item_id); table.insert(spell_info_list, spell_info) end end; return spell_info_list
end

-- Ya no necesitamos estas:
-- wand_helper.clear_spell_cache = function() wand_helper.base_spell_stats_cache = {} end
-- wand_helper.get_cached_spell_stats = function() return wand_helper.base_spell_stats_cache end

print("DEBUG: wand_spell_helper.lua loaded successfully (v2.0)")

return wand_helper