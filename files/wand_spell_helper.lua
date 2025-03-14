-- Se cargan las configuraciones y librerías necesarias.
dofile_once("mods/getdata/files/helper.lua");  -- Funciones auxiliares (obtener jugador, inventarios, etc.).
dofile_once("data/scripts/gun/gun_actions.lua");  -- Define las acciones que puede tener una varita.
dofile_once("data/scripts/gun/procedural/gun_procedural.lua");  -- Funciones procedurales para la generación de varitas.


--------------------------------------------------------------------------------
-- Función: wand_type_to_sprite_file
-- Propósito: Dada una cadena que identifica el tipo de varita, retorna la ruta del sprite asociado.
-- Si el tipo es "default_X", usa la configuración por defecto; de lo contrario, asume que está en la carpeta de wands.
function wand_type_to_sprite_file(wand_type)
	if string.sub(wand_type, 1, #"default") == "default" then
		local nr = tonumber(string.sub(wand_type, #"default" + 2));
		return mod_config.default_wands[nr].file;
	else
		return "data/items_gfx/wands/" .. wand_type .. ".png";
	end
end


--------------------------------------------------------------------------------
-- Función: wand_type_to_wand
-- Propósito: Retorna la definición de la varita asociada a un tipo determinado.
-- Si es del tipo "default", se retorna el objeto de la configuración por defecto;
-- de lo contrario, se recorre la lista de varitas existentes (wands) buscando la que coincida.
function wand_type_to_wand(wand_type)
	if string.sub(wand_type, 1, #"default") == "default" then
		local nr = tonumber(string.sub(wand_type, #"default" + 2));
		return mod_config.default_wands[nr];
	else
		for i = 1, #wands do
			if wands[i].file == "data/items_gfx/wands/" .. wand_type .. ".png" then
				return wands[i];
			end
		end
		return nil;
	end
end


--------------------------------------------------------------------------------
-- Función: sprite_file_to_wand_type
-- Propósito: Dado el nombre del archivo del sprite, determina el tipo de varita.
-- Comprueba si el sprite corresponde a una varita default; si no, extrae el nombre basado en la ruta.
function sprite_file_to_wand_type(sprite_file)
	for i = 1, #mod_config.default_wands do
		if mod_config.default_wands[i].file == sprite_file then
			return "default_" .. tostring(i);
		end
	end
	-- Extrae el nombre del archivo usando una búsqueda en la cadena (desde la última barra hasta el final, quitando la extensión)
	return string.sub(sprite_file, string.find(sprite_file, "/[^/]*$") + 1, -5);
end


--------------------------------------------------------------------------------
-- Función: read_wand
-- Propósito: Extrae y retorna una tabla con los parámetros de una varita a partir de su entidad.
-- Recorre los componentes de la entidad y, al encontrar un "AbilityComponent", extrae:
--   - Configuración del disparo: cantidad de acciones, tiempo de disparo, recarga, etc.
--   - Parámetros de mana y capacidad.
--   - El sprite asociado y se determina el tipo de varita.
-- Además, recorre los hijos de la entidad para identificar las spells:
--   - Las que están "siempre activas" (permanently_attached) se guardan en always_cast_spells.
--   - Las demás se guardan en spells.
-- Ajusta la capacidad restando la cantidad de spells fijas.
function read_wand(entity_id)
	local wand_data = {};
	-- Recorre los componentes de la entidad para obtener el AbilityComponent
	for _, comp in ipairs(EntityGetAllComponents(entity_id)) do
		if ComponentGetTypeName(comp) == "AbilityComponent" then
			wand_data["shuffle"] = tonumber(ComponentObjectGetValue(comp, "gun_config", "shuffle_deck_when_empty")) == 1 and true or false;
			wand_data["spells_per_cast"] = tonumber(ComponentObjectGetValue(comp, "gun_config", "actions_per_round"));
			wand_data["cast_delay"] = tonumber(ComponentObjectGetValue(comp, "gunaction_config", "fire_rate_wait"));
			wand_data["recharge_time"] = tonumber(ComponentObjectGetValue(comp, "gun_config", "reload_time"));
			wand_data["mana_max"] = tonumber(ComponentGetValue(comp, "mana_max"));
			wand_data["mana_charge_speed"] = tonumber(ComponentGetValue(comp, "mana_charge_speed"));
			wand_data["capacity"] = tonumber(ComponentObjectGetValue(comp, "gun_config", "deck_capacity"));
			wand_data["spread"] = tonumber(ComponentObjectGetValue(comp, "gunaction_config", "spread_degrees"));
			-- Determina el tipo de varita a partir del sprite asignado
			wand_data["wand_type"] = sprite_file_to_wand_type(ComponentGetValue(comp, "sprite_file"));
			break;
		end
	end
	-- Inicializa las listas para spells
	wand_data["spells"] = {};
	wand_data["always_cast_spells"] = {};
	-- Recorre los hijos de la entidad para detectar componentes de acción (spells)
	local childs = EntityGetAllChildren(entity_id);
	if childs ~= nil then
		for _, child_id in ipairs(childs) do
			local item_action_comp = EntityGetFirstComponentIncludingDisabled(child_id, "ItemActionComponent");
			if item_action_comp ~= nil and item_action_comp ~= 0 then
				local action_id = ComponentGetValue(item_action_comp, "action_id");
				-- Verifica si el spell está permanentemente unido a la varita
				if tonumber(ComponentGetValue(EntityGetFirstComponentIncludingDisabled(child_id, "ItemComponent"), "permanently_attached")) == 1 then
					table.insert(wand_data["always_cast_spells"], action_id);
				else
					table.insert(wand_data["spells"], action_id);
				end
			end
		end
	end
	-- Ajusta la capacidad disponible restando la cantidad de spells que se disparan siempre
	wand_data["capacity"] = wand_data["capacity"] - #wand_data["always_cast_spells"];
	return wand_data;
end


--------------------------------------------------------------------------------
-- Función: read_spell
-- Propósito: Dada la entidad de un hechizo, retorna su identificador (action_id) leyendo el componente de acción.
function read_spell(entity_id)
	for _, comp_id in ipairs(EntityGetAllComponents(entity_id)) do
		if ComponentGetTypeName(comp_id) == "ItemActionComponent" then
			return ComponentGetValue(comp_id, "action_id");
		end
	end
end

--------------------------------------------------------------------------------
-- Función: get_all_wands
-- Propósito: Retorna una tabla con todas las varitas que se encuentran en el inventario rápido.
-- Recorre los hijos del inventario "inventory_quick" y verifica que tengan la etiqueta "wand".
-- Se utiliza el valor del componente "ItemComponent" para ubicar la posición en el inventario.
function get_all_wands()
	local wands = {};
	if get_inventory_quick() == nil then
		return wands;
	end
	local inventory_quick_childs = EntityGetAllChildren(get_inventory_quick());
	if inventory_quick_childs ~= nil then
		for _, item in ipairs(inventory_quick_childs) do
			if EntityHasTag(item, "wand") then
				local inventory_comp = EntityGetFirstComponentIncludingDisabled(item, "ItemComponent");
				local x, _ = ComponentGetValue2(inventory_comp, "inventory_slot");
				wands[x] = item;
			end
		end
	end
	return wands;
end

--------------------------------------------------------------------------------
-- Función: get_all_spells
-- Propósito: Retorna una tabla con todas las entidades de hechizos que se encuentran en el inventario completo.
-- Recorre los hijos del inventario "inventory_full" y los agrega a la lista.
function get_all_spells()
	local spells = {};
	if get_inventory_full() == nil then
		return spells;
	end
	local inventory_full_childs = EntityGetAllChildren(get_inventory_full());
	if inventory_full_childs ~= nil then
		for _, item in ipairs(inventory_full_childs) do
			table.insert(spells, item);
		end
	end
	return spells;
end
