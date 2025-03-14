print("DEBUG: Loading helper.lua...")

-- Devuelve un número convertido a cadena con espacios a la izquierda hasta alcanzar la longitud especificada.
-- NOTA: Aunque se va construyendo la cadena, al final se retorna el número original (quizá se esperaba retornar la cadena).
function pad_number(number, length)
	local output = tostring(number);
	for i = 1, length - #output do
		output = " " .. output;
	end
	return output;  -- Return the padded string instead of number
end

-- Retorna el ID de la entidad del jugador.
function get_player_id()
	return EntityGetWithTag("player_unit")[1];
end

-- Retorna el componente "WalletComponent" del jugador, incluso si está deshabilitado.
function get_wallet()
	return EntityGetFirstComponentIncludingDisabled(get_player_id(), "WalletComponent");
end

-- Retorna la entidad del inventario rápido identificada con el nombre "inventory_quick".
function get_inventory_quick()
	return EntityGetWithName("inventory_quick");
end

-- Retorna la entidad del inventario completo identificada con el nombre "inventory_full".
function get_inventory_full()
	return EntityGetWithName("inventory_full");
end

-- Retorna el componente GUI del inventario del jugador, si existe.
function get_inventory_gui()
	return EntityGetFirstComponentIncludingDisabled(get_player_id(), "InventoryGuiComponent");
end

-- Retorna el componente Inventory2 del jugador.
function get_inventory2()
	return EntityGetFirstComponentIncludingDisabled(get_player_id(), "Inventory2Component");
end

-- Retorna el componente de controles del jugador.
function get_controls_component()
	return EntityGetFirstComponentIncludingDisabled(get_player_id(), "ControlsComponent");
end

-- Activa la edición de varitas en el lobby, añadiendo un hijo al jugador con la entidad definida en "edit_wands_in_lobby.xml".
function enable_edit_wands_in_lobby()
	EntityAddChild(get_player_id(), EntityLoad("mods/persistence/files/edit_wands_in_lobby.xml", 0, 0));
end

-- Desactiva la edición de varitas en el lobby eliminando la entidad con nombre "persistence_edit_wands_in_lobby".
function disable_edit_wands_in_lobby()
	local entity_id = EntityGetWithName("persistence_edit_wands_in_lobby");
	if entity_id ~= nil and entity_id ~= 0 then
		EntityKill(entity_id);
	end
end

-- Divide un array en "trozos" o subarreglos (chunks) de tamaño 'chunk_size'.
-- Retorna una tabla donde cada elemento es un subarreglo de tamaño máximo 'chunk_size'.
function split_array(array, chunk_size)
	local chunks = {};
	local current_chunk = 1;
	local count = 0;
	for i = 1, #array do
		if count >= chunk_size then
			current_chunk = current_chunk + 1;
			count = 0;
		end
		if chunks[current_chunk] == nil then
			chunks[current_chunk] = {};
		end
		table.insert(chunks[current_chunk], array[i]);
		count = count + 1;
	end
	return chunks;
end

-- Calcula un hash simple a partir de un texto.
-- ADVERTENCIA: No es seguro para almacenar contraseñas.
function simple_string_hash(text) --don't use it for storing passwords...
	local sum = 0;
	for i = 1, #text do
		sum = sum + string.byte(text, i) * i * 2999;
	end
	return sum;
end

-- Realiza una comprobación de colisión utilizando un AABB (Axis-Aligned Bounding Box).
-- Retorna true si el punto (x,y) se encuentra dentro del rectángulo definido por (min_x, min_y) y (max_x, max_y).
function aabb_check(x, y, min_x, min_y, max_x, max_y)
	return x > min_x and x < max_x and y > min_y and y < max_y;
end

function get_player_entity()
    return EntityGetWithTag("player_unit")[1]
end

function get_inventory_items(inventory_type)
    local player = get_player_entity()
    if not player then
        print("DEBUG: No player entity found")
        return nil, nil
    end

    -- Get all inventory components
    local inventory_components = EntityGetComponentIncludingDisabled(player, "Inventory2Component")
    if not inventory_components then
        print("DEBUG: No Inventory2Component found")
        return nil, nil
    end
    
    print("DEBUG: Found " .. #inventory_components .. " inventory components")
    
    local function get_inventory_items_from_component(comp)
        if comp then
            -- Try to get the items directly from the component
            local item_list = {}
            local children = EntityGetAllChildren(player)
            if children then
                for _, child_id in ipairs(children) do
                    -- Check if this child is an item and belongs to this inventory
                    if EntityHasTag(child_id, "item") then
                        local inventory_id = tonumber(ComponentGetValue2(comp, "mActiveItem"))
                        if inventory_id and inventory_id == child_id then
                            table.insert(item_list, child_id)
                        end
                    end
                end
            end
            print("DEBUG: Found " .. #item_list .. " items in inventory")
            return ComponentGetValue2(comp, "mActiveItem"), item_list
        end
        return nil, {}
    end

    -- Quick inventory is the first one, Full inventory is the second one
    if inventory_type == "Quick" and #inventory_components > 0 then
        print("DEBUG: Using first inventory component for Quick inventory")
        return get_inventory_items_from_component(inventory_components[1])
    elseif inventory_type == "Full" and #inventory_components > 1 then
        print("DEBUG: Using second inventory component for Full inventory")
        return get_inventory_items_from_component(inventory_components[2])
    end
    
    print("DEBUG: No " .. inventory_type .. " inventory component found")
    return nil, {}
end

print("DEBUG: helper.lua loaded successfully")
