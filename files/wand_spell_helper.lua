-- /files/wand_spell_helper.lua (Versión Corregida para leer gun_config)
print("DEBUG: Loading wand_spell_helper.lua (v1.1 - gun_config fix)...")

local wand_helper = {}

--[[ IMPORTANTE: Asume que get_all_player_inventory_items ya está cargado
     y disponible globalmente o accedido vía la tabla 'mod' en init.lua.
     NO añadas una llamada a dofile_once() aquí. ]]
local get_items_func = get_all_player_inventory_items or function() print("ERROR: get_all_player_inventory_items was not loaded before wand_spell_helper!") return {} end

function wand_helper.get_all_wands()
    local all_items = get_items_func() -- Usa la función cargada antes
    local wands = {}
    for _, item_id in ipairs(all_items) do
        if EntityHasTag(item_id, "wand") then
            table.insert(wands, item_id)
        end
    end
    -- print("DEBUG: get_all_wands returning " .. #wands .. " wands.") -- Menos verboso
    return wands
end

function wand_helper.read_wand(wand_entity)
    -- print("DEBUG: read_wand called for entity " .. tostring(wand_entity)) -- Menos verboso
    local wand_data = {}
    -- Inicializa con valores por defecto más genéricos o 0/false donde aplique
    wand_data["ui_name"] = "Unknown Wand"; wand_data["shuffle"] = "N/A"; wand_data["capacity"] = 0
    wand_data["spells_per_cast"] = 0; wand_data["cast_delay"] = "0.00"; wand_data["recharge_time"] = "0.00"
    wand_data["mana_max"] = 0; wand_data["mana_charge_speed"] = 0; wand_data["mana"] = 0
    wand_data["spread_degrees"] = "0.00"

    local ability_comp = EntityGetFirstComponentIncludingDisabled(wand_entity, "AbilityComponent")

    if ability_comp then
        -- print("  Found AbilityComponent (ID: " .. ability_comp .. ")") -- Menos verboso

        -- Leer estadísticas directas del AbilityComponent
        wand_data["mana"] = ComponentGetValue2(ability_comp, "mana") or 0
        wand_data["mana_max"] = ComponentGetValue2(ability_comp, "mana_max") or 0
        wand_data["mana_charge_speed"] = ComponentGetValue2(ability_comp, "mana_charge_speed") or 0

        -- Intentar leer el nombre UI del AbilityComponent primero
        local name_val = ComponentGetValue2(ability_comp, "ui_name")
        if name_val ~= nil and name_val ~= "" then
             wand_data["ui_name"] = name_val
        else
             -- Si no, intentar desde ItemComponent
             local item_comp_direct = EntityGetFirstComponent(wand_entity, "ItemComponent")
             if item_comp_direct then
                 local name_item = ComponentGetValue2(item_comp_direct, "ui_name") or ComponentGetValue2(item_comp_direct, "item_name")
                 if name_item and name_item ~= "" then wand_data["ui_name"] = name_item else wand_data["ui_name"] = "Unnamed Wand" end
             else wand_data["ui_name"] = "Unnamed Wand" end
        end

        -- Leer estadísticas del objeto anidado "gun_config" usando ComponentObjectGetValue2
        local capacity_val = ComponentObjectGetValue2(ability_comp, "gun_config", "deck_capacity")
        if capacity_val ~= nil then wand_data["capacity"] = capacity_val end

        local per_cast_val = ComponentObjectGetValue2(ability_comp, "gun_config", "actions_per_round")
        if per_cast_val ~= nil then wand_data["spells_per_cast"] = per_cast_val end

        local cast_delay_frames = ComponentObjectGetValue2(ability_comp, "gun_config", "reload_time")
        if cast_delay_frames ~= nil then
            wand_data["cast_delay"] = string.format("%.2f", cast_delay_frames / 60.0) -- Convertir frames a segundos
        end

        local recharge_frames = ComponentObjectGetValue2(ability_comp, "gun_config", "fire_rate_wait")
        if recharge_frames ~= nil then
            wand_data["recharge_time"] = string.format("%.2f", recharge_frames / 60.0) -- Convertir frames a segundos
        end

        local spread_val = ComponentObjectGetValue2(ability_comp, "gun_config", "spread_degrees")
        if spread_val ~= nil then
             wand_data["spread_degrees"] = string.format("%.2f", spread_val)
        end

        local shuffle_val = ComponentObjectGetValue2(ability_comp, "gun_config", "shuffle_deck_when_empty")
        -- shuffle_deck_when_empty suele ser 0 (No) o 1 (Yes)
        if shuffle_val ~= nil then
             wand_data["shuffle"] = (shuffle_val == 1 or shuffle_val == true) and "Yes" or "No"
        end

        -- print("  DEBUG: Read accessible stats including gun_config.") -- Menos verboso

    else
        print("  WARN: No AbilityComponent found for wand entity " .. wand_entity)
        wand_data["ui_name"] = "Unknown Wand (No AbilityComp)"
        -- Deja los valores por defecto si no hay componente
    end
    return wand_data
end


function wand_helper.get_all_spells()
    local all_items = get_items_func() -- Usa la función cargada antes
    local spells = {}
    for _, item_id in ipairs(all_items) do
        if EntityHasTag(item_id, "card_action") then
            table.insert(spells, item_id)
        end
    end
    -- print("DEBUG: get_all_spells returning " .. #spells .. " spells.") -- Menos verboso
    return spells
end

function wand_helper.read_spell(spell_entity)
    local item_component = EntityGetFirstComponent(spell_entity, "ItemComponent")
    if item_component then
        local ui_name = ComponentGetValue2(item_component, "ui_name")
        if ui_name and ui_name ~= "" then return ui_name end
        return ComponentGetValue2(item_component, "item_name") or "unknown"
    end
    return "unknown (no ItemComponent)"
end

print("DEBUG: wand_spell_helper.lua loaded successfully (v1.1)")

return wand_helper -- IMPORTANTE: Devolver la tabla