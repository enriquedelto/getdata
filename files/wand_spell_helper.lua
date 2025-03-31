-- /files/wand_spell_helper.lua (v1.5 - Lectura precisa de gun_config/gunaction_config, usa action_id para nombres)
print("DEBUG: Loading wand_spell_helper.lua (v1.5 - Final structure based on XML)...")

local wand_helper = {}

local get_items_func = get_all_player_inventory_items or function() print("ERROR: get_all_player_inventory_items was not loaded before wand_spell_helper!") return {} end

-- Intenta obtener un nombre legible para un action_id (¡esto es básico!)
-- Puedes expandir esto con más IDs si quieres nombres más amigables.
local function format_action_id(action_id)
    if action_id == nil then return "unknown (No ActionID)" end
    return action_id:gsub("_", " "):lower():gsub("^%l", string.upper) -- Ej: "BOUNCY_ORB" -> "Bouncy orb"
end

-- Función auxiliar para leer nombres de hechizos (AHORA USA action_id)
function wand_helper.read_spell_name(spell_entity)
    if not EntityGetIsAlive(spell_entity) then
        -- print(" WARN: Attempted to read spell name from dead entity: " .. spell_entity)
        return "unknown (Entity Dead)"
    end

    -- Intentar obtener ItemActionComponent primero
    local item_action_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemActionComponent")
    if item_action_comp then
        local action_id = ComponentGetValue2(item_action_comp, "action_id")
        if action_id and action_id ~= "" then
            -- Intentar leer también el ItemComponent por si acaso tuviera nombre (poco probable ahora)
            local item_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemComponent")
            if item_comp then
                 local item_name_val = ComponentGetValue2(item_comp, "item_name")
                 if item_name_val and item_name_val ~= "" then return item_name_val .. " (" .. format_action_id(action_id) .. ")" end -- Usar nombre si existe + ID formateado
                 local ui_name_val = ComponentGetValue2(item_comp, "ui_name")
                 if ui_name_val and ui_name_val ~= "" then return ui_name_val .. " (" .. format_action_id(action_id) .. ")" end
            end
            -- Si no hay nombre en ItemComponent, devolver el ID formateado
            return format_action_id(action_id)
        else
            print(" WARN: ItemActionComponent found for spell "..spell_entity..", but action_id is empty.")
            return "unknown (Empty ActionID)"
        end
    else
        -- Si no hay ItemActionComponent, es raro para un hechizo
        print(" WARN: No ItemActionComponent found for spell entity " .. spell_entity .. ". Cannot get name.")
        -- Como último recurso, intentar leer el ItemComponent directamente
        local item_comp = EntityGetFirstComponentIncludingDisabled(spell_entity, "ItemComponent")
        if item_comp then
             local item_name_val = ComponentGetValue2(item_comp, "item_name")
             if item_name_val and item_name_val ~= "" then return item_name_val end
             local ui_name_val = ComponentGetValue2(item_comp, "ui_name")
             if ui_name_val and ui_name_val ~= "" then return ui_name_val end
             return "unknown (No ActionID, ItemComp names empty)"
        end
        return "unknown (No Action/Item Comp)"
    end
end


function wand_helper.get_all_wands()
    local all_items = get_items_func()
    local wands = {}
    for _, item_id in ipairs(all_items) do
        if EntityGetIsAlive(item_id) and EntityHasTag(item_id, "wand") then
            table.insert(wands, item_id)
        end
    end
    return wands
end

function wand_helper.read_wand(wand_entity)
    local wand_data = {}
    wand_data["ui_name"] = "Unknown Wand"; wand_data["shuffle"] = "N/A"; wand_data["capacity"] = 0
    wand_data["spells_per_cast"] = 0; wand_data["cast_delay"] = "0.00"; wand_data["recharge_time"] = "0.00"
    wand_data["mana_max"] = 0; wand_data["mana_charge_speed"] = 0; wand_data["mana"] = 0
    wand_data["spread_degrees"] = "0.00"
    wand_data["spells"] = {}

    if not EntityGetIsAlive(wand_entity) then
        wand_data["ui_name"] = "Unknown Wand (Entity Dead)"
        return wand_data
    end

    local ability_comp = EntityGetFirstComponentIncludingDisabled(wand_entity, "AbilityComponent")

    if ability_comp then
        -- Estadísticas directas de AbilityComponent
        wand_data["mana"] = ComponentGetValue2(ability_comp, "mana") or 0
        wand_data["mana_max"] = ComponentGetValue2(ability_comp, "mana_max") or 0
        wand_data["mana_charge_speed"] = ComponentGetValue2(ability_comp, "mana_charge_speed") or 0
        wand_data["ui_name"] = ComponentGetValue2(ability_comp, "ui_name") or "Unnamed Wand (from AbilityComp)"

        -- Estadísticas de gun_config
        local gun_config_obj = "gun_config"
        local capacity_val = ComponentObjectGetValue2(ability_comp, gun_config_obj, "deck_capacity")
        if capacity_val ~= nil then wand_data["capacity"] = capacity_val end

        local per_cast_val = ComponentObjectGetValue2(ability_comp, gun_config_obj, "actions_per_round")
        if per_cast_val ~= nil then wand_data["spells_per_cast"] = per_cast_val end

        local cast_delay_frames = ComponentObjectGetValue2(ability_comp, gun_config_obj, "reload_time")
        if cast_delay_frames ~= nil then
            wand_data["cast_delay"] = string.format("%.2f", cast_delay_frames / 60.0)
        end

        local shuffle_val = ComponentObjectGetValue2(ability_comp, gun_config_obj, "shuffle_deck_when_empty")
        if shuffle_val ~= nil then
             wand_data["shuffle"] = (shuffle_val == 1 or shuffle_val == true) and "Yes" or "No"
        end

        -- Estadísticas de gunaction_config
        local gunaction_config_obj = "gunaction_config"
        local recharge_frames = ComponentObjectGetValue2(ability_comp, gunaction_config_obj, "fire_rate_wait")
        if recharge_frames ~= nil then
            wand_data["recharge_time"] = string.format("%.2f", recharge_frames / 60.0)
        else
             wand_data["recharge_time"] = "N/A" -- O 0.00 si se prefiere
             -- print(" DEBUG: fire_rate_wait not found in gunaction_config for wand " .. wand_entity)
        end

        local spread_val = ComponentObjectGetValue2(ability_comp, gunaction_config_obj, "spread_degrees")
        if spread_val ~= nil then
             wand_data["spread_degrees"] = string.format("%.2f", spread_val)
        else
             wand_data["spread_degrees"] = "N/A" -- O 0.00 si se prefiere
             -- print(" DEBUG: spread_degrees not found in gunaction_config for wand " .. wand_entity)
        end

        -- Obtener hechizos dentro de la varita (usando el nuevo read_spell_name)
        local child_entities = EntityGetAllChildren(wand_entity)
        if child_entities then
            for _, child_id in ipairs(child_entities) do
                if EntityGetIsAlive(child_id) and EntityHasTag(child_id, "card_action") then
                    local spell_name = wand_helper.read_spell_name(child_id)
                    table.insert(wand_data["spells"], spell_name .. " (ID:" .. child_id .. ")")
                end
            end
        end

    else
        print("  WARN: No AbilityComponent found for wand entity " .. wand_entity)
        -- Intentar leer nombre desde ItemComponent como último recurso si no hay AbilityComponent
        local item_comp = EntityGetFirstComponentIncludingDisabled(wand_entity, "ItemComponent")
        if item_comp then
             wand_data["ui_name"] = ComponentGetValue2(item_comp, "ui_name") or ComponentGetValue2(item_comp, "item_name") or "Unknown Wand (No AbilityComp)"
        else
             wand_data["ui_name"] = "Unknown Wand (No Ability/Item Comp)"
        end
    end
    return wand_data
end


function wand_helper.get_all_spells()
    local all_inventory_items = get_items_func()
    local spells = {}
    -- print("--- DEBUG: Inventory Item Scan ---") -- Mantener comentado a menos que se depure el inventario
    if not all_inventory_items or #all_inventory_items == 0 then
        -- print("  No items returned by GameGetAllInventoryItems.")
        return spells
    end

    for i, item_id in ipairs(all_inventory_items) do
        -- local tags_str = table.concat(EntityGetTags(item_id) or {}, ", ")
        -- local name = EntityGetName(item_id) or "N/A"
        -- print(string.format("  Item %d: ID=%d, Name=%s, Tags=[%s]", i, item_id, name, tags_str)) -- Comentado

        -- Filtrar hechizos
        if EntityHasTag(item_id, "card_action") and not EntityHasTag(item_id, "wand") then
            -- print("    -> Identified as potential inventory spell.") -- Comentado
            table.insert(spells, item_id)
        end
    end
    -- print("--- End Inventory Scan. Found " .. #spells .. " potential spells. ---") -- Comentado
    return spells
end

-- read_spell ahora llama a la función que lee el action_id
function wand_helper.read_spell(spell_entity)
    return wand_helper.read_spell_name(spell_entity)
end

print("DEBUG: wand_spell_helper.lua loaded successfully (v1.5)")

return wand_helper