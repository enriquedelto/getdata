print("DEBUG: Loading wand_spell_helper.lua...")

function get_all_wands()
    print("DEBUG: get_all_wands called")
    local wands = {}
    local _, quick_inventory = get_inventory_items("Quick")
    
    if quick_inventory then
        print("DEBUG: Processing quick inventory with " .. tostring(#quick_inventory) .. " items")
        for i, item_id in ipairs(quick_inventory) do
            if item_id and EntityGetIsAlive(item_id) then
                print("DEBUG: Checking item " .. tostring(item_id))
                if EntityHasTag(item_id, "wand") then
                    table.insert(wands, item_id)
                    print("DEBUG: Found valid wand: " .. tostring(item_id))
                end
            end
        end
    else
        print("DEBUG: Quick inventory is nil or empty")
    end
    
    print("DEBUG: Found " .. tostring(#wands) .. " wands")
    return wands
end

function read_wand(wand_entity)
    print("DEBUG: read_wand called for entity " .. tostring(wand_entity))
    local wand_data = {}
    local ability_component = EntityGetFirstComponent(wand_entity, "AbilityComponent")
    if ability_component then
        wand_data["shuffle"] = ComponentGetValue2(ability_component, "shuffle_deck_when_empty")
        wand_data["spells_per_cast"] = ComponentGetValue2(ability_component, "deck_capacity")
        wand_data["cast_delay"] = ComponentGetValue2(ability_component, "reload_time")
    end
    return wand_data
end

function get_all_spells()
    print("DEBUG: get_all_spells called")
    local spells = {}
    local active_item, inventory = get_inventory_items("Full")
    
    if inventory then
        print("DEBUG: Processing " .. tostring(#inventory) .. " inventory items")
        for _, item_id in ipairs(inventory) do
            print("DEBUG: Checking item " .. tostring(item_id) .. " for spell tag")
            -- Check if item exists and has spell tags
            if EntityGetIsAlive(item_id) and 
               (EntityHasTag(item_id, "card_action") or EntityHasTag(item_id, "spell")) then
                table.insert(spells, item_id)
                print("DEBUG: Found valid spell: " .. tostring(item_id))
            end
        end
    else
        print("DEBUG: No full inventory found")
    end
    
    print("DEBUG: Found " .. tostring(#spells) .. " spells")
    return spells
end

function read_spell(spell_entity)
    print("DEBUG: read_spell called for entity " .. tostring(spell_entity))
    local item_component = EntityGetFirstComponent(spell_entity, "ItemComponent")
    if item_component then
        return ComponentGetValue2(item_component, "item_name")
    end
    return "unknown"
end

-- Simplified global registration
_G.get_all_wands = get_all_wands
_G.read_wand = read_wand
_G.get_all_spells = get_all_spells
_G.read_spell = read_spell

print("DEBUG: wand_spell_helper.lua loaded successfully")
