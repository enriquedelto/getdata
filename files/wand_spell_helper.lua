-- /files/wand_spell_helper.lua (Final Clean Version - Reads accessible stats)
print("DEBUG: Loading wand_spell_helper.lua...")

local wand_helper = {}

--[[ IMPORTANT: Assume get_all_player_inventory_items is already loaded
     and available globally or accessed via the 'mod' table in init.lua.
     DO NOT add a dofile_once() call here. ]]
local get_items_func = get_all_player_inventory_items or function() print("ERROR: get_all_player_inventory_items was not loaded before wand_spell_helper!") return {} end

function wand_helper.get_all_wands()
    local all_items = get_items_func() -- Uses the function loaded earlier
    local wands = {}
    for _, item_id in ipairs(all_items) do
        if EntityHasTag(item_id, "wand") then
            table.insert(wands, item_id)
        end
    end
    print("DEBUG: get_all_wands returning " .. #wands .. " wands.")
    return wands
end

function wand_helper.read_wand(wand_entity)
    -- print("DEBUG: read_wand called for entity " .. tostring(wand_entity)) -- Less verbose
    local wand_data = {}
    wand_data["ui_name"] = "N/A"; wand_data["shuffle"] = "N/A (API Limit)"; wand_data["capacity"] = "N/A"
    wand_data["spells_per_cast"] = "N/A"; wand_data["cast_delay"] = "N/A"; wand_data["recharge_time"] = "N/A (API Limit)"
    wand_data["mana_max"] = "N/A"; wand_data["mana_charge_speed"] = "N/A"; wand_data["mana"] = "N/A"
    wand_data["spread_degrees"] = "N/A (API Limit)"

    local ability_comp = EntityGetFirstComponentIncludingDisabled(wand_entity, "AbilityComponent")

    if ability_comp then
        -- print("  Found AbilityComponent (ID: " .. ability_comp .. ")") -- Less verbose
        wand_data["capacity"] = ComponentGetValue2(ability_comp, "deck_capacity") or 0
        wand_data["spells_per_cast"] = ComponentGetValue2(ability_comp, "actions_per_round") or 0
        wand_data["cast_delay"] = string.format("%.2f", ComponentGetValue2(ability_comp, "reload_time") or 0.0)
        wand_data["mana"] = ComponentGetValue2(ability_comp, "mana") or 0
        wand_data["mana_max"] = ComponentGetValue2(ability_comp, "mana_max") or 0
        wand_data["mana_charge_speed"] = ComponentGetValue2(ability_comp, "mana_charge_speed") or 0
        local shuffle_val = ComponentGetValue2(ability_comp, "shuffle_deck_when_empty")
        if shuffle_val ~= nil then wand_data["shuffle"] = tostring(shuffle_val) end
        local name_val = ComponentGetValue2(ability_comp, "ui_name")
        if name_val ~= nil and name_val ~= "" then
             wand_data["ui_name"] = name_val
        else
             local item_comp_direct = EntityGetFirstComponent(wand_entity, "ItemComponent")
             if item_comp_direct then
                 local name_item = ComponentGetValue2(item_comp_direct, "ui_name") or ComponentGetValue2(item_comp_direct, "item_name")
                 if name_item then wand_data["ui_name"] = name_item else wand_data["ui_name"] = "Unknown" end
             else wand_data["ui_name"] = "Unknown" end
        end
        -- print("  DEBUG: Read directly accessible stats.") -- Less verbose
    else
        print("  WARN: No AbilityComponent found for wand entity " .. wand_entity)
        wand_data["ui_name"] = "Unknown Wand (No AbilityComp)"
        for k, v in pairs(wand_data) do if v == "N/A" then wand_data[k] = "N/A (No Comp)" end end
    end
    return wand_data
end


function wand_helper.get_all_spells()
    local all_items = get_items_func() -- Uses the function loaded earlier
    local spells = {}
    for _, item_id in ipairs(all_items) do
        if EntityHasTag(item_id, "card_action") then
            table.insert(spells, item_id)
        end
    end
    print("DEBUG: get_all_spells returning " .. #spells .. " spells.")
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

print("DEBUG: wand_spell_helper.lua loaded successfully")

return wand_helper -- IMPORTANT: Return the table