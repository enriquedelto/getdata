-- /files/helper.lua (Final Clean - No internal dofile_once)
print("DEBUG: Loading helper.lua...")

function pad_number(number, length)
	local output = tostring(number)
	for i = 1, length - #output do
		output = " " .. output
	end
	return output;
end

function get_player_id()
	local players = EntityGetWithTag("player_unit")
	if players and #players > 0 then
		return players[1]
	end
	print("ERROR: Could not find player entity!")
	return nil
end

function get_wallet()
	local player_id = get_player_id()
	if player_id then
		return EntityGetFirstComponentIncludingDisabled(player_id, "WalletComponent")
	end
	return nil
end

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

function simple_string_hash(text) --don't use it for storing passwords...
	local sum = 0;
	for i = 1, #text do
		sum = sum + string.byte(text, i) * i * 2999;
	end
	return sum;
end

function aabb_check(x, y, min_x, min_y, max_x, max_y)
	return x > min_x and x < max_x and y > min_y and y < max_y;
end

function get_player_entity()
    return get_player_id()
end

-- Uses the dedicated GameGetAllInventoryItems() API function.
function get_all_player_inventory_items()
    -- print("--- DEBUG: get_all_player_inventory_items called ---") -- Keep commented unless debugging
    local player_id = get_player_id()
    if not player_id then
        print("ERROR: get_all_player_inventory_items - No player entity found.")
        return {}
    end

    local items = {}
    local success, result = pcall(GameGetAllInventoryItems, player_id)

    if success then
        if result and type(result) == "table" then
            -- print("DEBUG: GameGetAllInventoryItems SUCCESS. Found " .. #result .. " total items.")
            for _, item_id in ipairs(result) do
                if EntityGetIsAlive(item_id) then
                    table.insert(items, item_id)
                end
            end
            -- print("DEBUG: Returning " .. #items .. " ALIVE items from inventory.")
        else
            print("DEBUG: GameGetAllInventoryItems returned nil or not a table. Assuming empty inventory.")
        end
    else
        print("ERROR: pcall(GameGetAllInventoryItems) FAILED: " .. tostring(result))
    end
    return items
end

print("DEBUG: helper.lua loaded successfully")