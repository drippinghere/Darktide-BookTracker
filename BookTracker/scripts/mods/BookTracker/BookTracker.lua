local mod = get_mod("BookTracker")

local BOOK_TYPES = {
	grimoire = true,
	tome = true,
}

local SCAN_INTERVAL = 1
local BookTrackerMarker = mod:io_dofile(
	"BookTracker/scripts/mods/BookTracker/BookTracker_marker"
)

mod._book_tracker_info = {
	version = "1.0.0",
	author = "Dripping",
}

mod._active_spawns = {}
mod._selected_location_keys = {}
mod._active_book_type = nil
mod._display_locations = {}
mod._matched_count = 0
mod._unmatched_count = 0
mod._revision = 0
mod._last_scan_signature = nil
mod._last_scanned_book_type = nil
mod._scan_elapsed = SCAN_INTERVAL
mod._internal_error = nil
mod._world_marker_ids = {}
mod._world_marker_pending = {}
mod._world_marker_data = {}
mod._world_marker_desired = {}
mod._world_marker_targets = {}
mod._world_marker_hud_ready = false
mod._tracker_table_visible = true
mod._tracker_screen_bounds = nil
mod._book_move_mode = false

if not mod:get("background_opacity_percent_migrated") then
	local old_opacity = mod:get("background_opacity")

	if type(old_opacity) == "number" then
		local opacity_percent = math.floor(math.clamp(old_opacity, 0, 255) / 255 * 100 + 0.5)

		mod:set("background_opacity_percent", opacity_percent)
	end

	mod:set("background_opacity_percent_migrated", true)
end

local clear_world_markers
local sync_world_markers
local scan_pickup_system

local function debug_log(message, ...)
	if mod:get("diagnostic_logging") then
		local success, formatted_message = pcall(string.format, message, ...)
		local output = rawget(_G, "__print") or print

		output("[BookTracker] " .. (success and formatted_message or tostring(message)))
	end
end

local function touch()
	mod._revision = mod._revision + 1
end

function mod:is_tracker_table_visible()
	return mod._tracker_table_visible ~= false
end

function mod:set_tracker_screen_bounds(bounds)
	mod._tracker_screen_bounds = bounds
end

function mod:tracker_screen_bounds()
	return mod._tracker_screen_bounds
end

function mod:is_book_move_mode()
	return mod._book_move_mode == true
end

function mod.toggle_tracker_table()
	mod._tracker_table_visible = not mod._tracker_table_visible

	if not mod._tracker_table_visible then
		mod._tracker_screen_bounds = nil
		mod._book_move_mode = false
	end

	touch()
end

function mod:set_book_tracker_error(stage, error_message)
	local message = string.format("%s: %s", tostring(stage), tostring(error_message))

	if message ~= mod._internal_error then
		mod._internal_error = message
		touch()

		local output = rawget(_G, "__print") or print

		output("[BookTracker][ERROR] " .. message)
	end
end

local function protected_call(stage, callback, ...)
	local success, result = pcall(callback, ...)

	if not success then
		mod:set_book_tracker_error(stage, result)
	end

	return success, result
end

local function reset_state()
	if clear_world_markers then
		clear_world_markers()
	end

	mod._active_spawns = {}
	mod._selected_location_keys = {}
	mod._active_book_type = nil
	mod._display_locations = {}
	mod._matched_count = 0
	mod._unmatched_count = 0
	mod._last_scan_signature = nil
	mod._last_scanned_book_type = nil
	mod._scan_elapsed = SCAN_INTERVAL
	mod._internal_error = nil
	mod._world_marker_hud_ready = false
	mod._tracker_screen_bounds = nil
	mod._book_move_mode = false

	touch()
	debug_log("Mission state cleared.")
end

local function list_contains(list, wanted)
	if type(list) ~= "table" then
		return false
	end

	for i = 1, #list do
		if list[i] == wanted then
			return true
		end
	end

	return false
end

local function current_book_type()
	local mission_state = Managers.state
	local mission_manager = mission_state and mission_state.mission

	if not mission_manager then
		return nil
	end

	local side_mission = mission_manager:side_mission()

	if not side_mission or not BOOK_TYPES[side_mission.unit_name] then
		return nil
	end

	return side_mission.unit_name
end

local function refresh_book_type()
	local book_type = current_book_type()

	if book_type ~= mod._active_book_type then
		mod._active_book_type = book_type
		mod._last_scanned_book_type = nil
		mod._last_scan_signature = nil
		mod._scan_elapsed = SCAN_INTERVAL
		touch()
		debug_log("Active book objective changed to: %s", book_type or "none")
	end
end

local function is_side_mission_component(component)
	return component and (component.is_side_mission or component.distribution_type == "side_mission")
end

local function unit_is_alive(unit)
	if not unit then
		return false
	end

	local success, alive = pcall(Unit.alive, unit)

	return success and alive == true
end

local function safe_local_position(unit)
	if not unit_is_alive(unit) then
		return nil
	end

	local success, position = pcall(Unit.local_position, unit, 1)

	return success and position or nil
end

local function position_key(position)
	local x, y, z = Vector3.to_elements(position)

	return string.format("%.0f_%.0f_%.0f", x, y, z)
end

local function current_mission_name()
	local mission_state = Managers.state
	local mission_manager = mission_state and mission_state.mission

	if mission_manager and mission_manager.mission_name then
		local success, mission_name = pcall(mission_manager.mission_name, mission_manager)

		if success and mission_name then
			return tostring(mission_name)
		end
	end

	return "unknown_mission"
end

local function location_storage_key(location)
	return table.concat({
		current_mission_name(),
		mod._active_book_type or "none",
		position_key(location.position:unbox()),
	}, "|")
end

local function world_marker_mode_includes(location)
	local mode = mod:get("world_marker_mode")

	if mode == "all" then
		return true
	elseif mode == "active_only" then
		return location.active == true
	elseif mode == "possible_only" then
		return not location.active and not location.always_inactive
	elseif mode == "always_inactive_only" then
		return location.always_inactive == true
	elseif mode == "all_section_1" then
		return location.group == 1
	elseif mode == "all_section_2" then
		return location.group == 2
	elseif mode == "all_section_3" then
		return mod._active_book_type == "tome" and location.group == 3
	end

	return false
end

local function remove_world_marker(marker_id)
	local event_manager = Managers.event

	if marker_id and event_manager then
		event_manager:trigger("remove_world_marker", marker_id)
	end
end

clear_world_markers = function()
	for _, marker_id in pairs(mod._world_marker_ids) do
		remove_world_marker(marker_id)
	end

	mod._world_marker_ids = {}
	mod._world_marker_pending = {}
	mod._world_marker_data = {}
	mod._world_marker_desired = {}
	mod._world_marker_targets = {}
end

sync_world_markers = function()
	if mod:get("world_marker_mode") == "off"
		or not mod._world_marker_hud_ready
		or not mod._active_book_type
		or not BookTrackerMarker
		or not BookTrackerMarker.name then
		clear_world_markers()

		return
	end

	local event_manager = Managers.event

	if not event_manager then
		return
	end

	local desired = {}
	local desired_targets = {}

	for index = 1, #mod._display_locations do
		local location = mod._display_locations[index]

		if world_marker_mode_includes(location) then
			local key = location.location_key or location_storage_key(location)
			local data = mod._world_marker_data[key] or {}
			local active_unit = location.active_unit
			local target

			if location.active and unit_is_alive(active_unit) then
				target = {
					kind = "unit",
					unit = active_unit,
				}
			else
				target = {
					kind = "position",
					position = location.position:unbox(),
				}
			end

			location.location_key = key
			data.active = location.active == true
			data.always_inactive = location.always_inactive == true
			data.location_number = index

			desired[key] = true
			desired_targets[key] = target

			mod._world_marker_data[key] = data
		end
	end

	mod._world_marker_desired = desired

	for key, marker_id in pairs(mod._world_marker_ids) do
		local current_target = mod._world_marker_targets[key]
		local wanted_target = desired_targets[key]
		local target_changed = current_target and wanted_target
			and (current_target.kind ~= wanted_target.kind
				or current_target.unit ~= wanted_target.unit)

		if not desired[key] or target_changed then
			remove_world_marker(marker_id)
			mod._world_marker_ids[key] = nil
			mod._world_marker_targets[key] = nil

			if not desired[key] then
				mod._world_marker_data[key] = nil
			end
		end
	end

	for index = 1, #mod._display_locations do
		local location = mod._display_locations[index]

		local key = location.location_key
		local target = key and desired_targets[key]

		if target and not mod._world_marker_ids[key] and not mod._world_marker_pending[key] then
			mod._world_marker_pending[key] = true

			local marker_callback = function(marker_id)
				mod._world_marker_pending[key] = nil

				if mod._world_marker_desired[key]
					and mod._world_marker_hud_ready then
					mod._world_marker_ids[key] = marker_id
					mod._world_marker_targets[key] = target
				else
					remove_world_marker(marker_id)
				end
			end

			if target.kind == "unit" then
				event_manager:trigger(
					"add_world_marker_unit",
					BookTrackerMarker.name,
					target.unit,
					marker_callback,
					mod._world_marker_data[key]
				)
			else
				event_manager:trigger(
					"add_world_marker_position",
					BookTrackerMarker.name,
					target.position,
					marker_callback,
					mod._world_marker_data[key]
				)
			end
		end
	end
end

local function current_mission_display_name()
	local mission_state = Managers.state
	local mission_manager = mission_state and mission_state.mission
	local mission

	if mission_manager and mission_manager.mission then
		local success, current_mission = pcall(mission_manager.mission, mission_manager)

		mission = success and current_mission or nil
	end

	local localization_key = mission and mission.mission_name

	if localization_key and rawget(_G, "Localize") then
		local success, display_name = pcall(Localize, localization_key)

		if success and display_name and display_name ~= localization_key then
			return tostring(display_name)
		end
	end

	return current_mission_name()
end

local function clipboard_export_text()
	local locations = mod._display_locations

	if not mod._active_book_type or #locations == 0 then
		return nil
	end

	local mission_name = current_mission_name()
	local display_name = current_mission_display_name()
	local collectible_name = mod._active_book_type == "tome" and "Scriptures" or "Grimoires"
	local lines = {
		"BookTracker Locations",
		"Mission: " .. display_name,
		"Mission ID: " .. mission_name,
		"Collectible: " .. collectible_name,
		string.format("Locations: %d", #locations),
		"",
	}

	for index = 1, #locations do
		local location = locations[index]
		local x, y, z = Vector3.to_elements(location.position:unbox())
		local section = location.group and tostring(location.group) or "Unassigned"
		local status = location.active and "Active"
			or location.always_inactive and "Always Inactive"
			or "Possible"

		lines[#lines + 1] = string.format(
			"%02d | Section %s | X: %.1f | Y: %.1f | Z: %.1f | %s",
			index,
			section,
			x,
			y,
			z,
			status
		)
	end

	return table.concat(lines, "\r\n")
end

local function copy_locations_to_clipboard()
	protected_call("objective update", refresh_book_type)

	if mod._active_book_type and mod._last_scanned_book_type ~= mod._active_book_type then
		protected_call("pickup-system scan", scan_pickup_system)
	end

	local export_text = clipboard_export_text()

	if not export_text then
		mod:notify(mod:localize("bookcopy_no_locations"))

		return
	end

	local clipboard = rawget(_G, "Clipboard")
	local success = clipboard and type(clipboard.put) == "function"
		and pcall(clipboard.put, export_text)

	if success then
		mod:notify(mod:localize("bookcopy_success", #mod._display_locations))
	else
		mod:notify(mod:localize("bookcopy_clipboard_unavailable"))
	end
end

local function toggle_book_move_mode()
	if mod._book_move_mode then
		mod._book_move_mode = false
		touch()
		mod:notify(mod:localize("bookmove_disabled"))

		return
	end

	protected_call("objective update", refresh_book_type)

	if mod._active_book_type and mod._last_scanned_book_type ~= mod._active_book_type then
		protected_call("pickup-system scan", scan_pickup_system)
	end

	if not mod._active_book_type or #mod._display_locations == 0 then
		mod:notify(mod:localize("bookmove_unavailable"))

		return
	end

	mod._tracker_table_visible = true
	mod._book_move_mode = true
	touch()
	mod:notify(mod:localize("bookmove_enabled"))
end

local candidate_progress

local function main_path_distance(position)
	if not rawget(_G, "EngineOptimized") or not EngineOptimized.closest_pos_at_main_path then
		return nil
	end

	local success, _, distance = pcall(function()
		return EngineOptimized.closest_pos_at_main_path(position)
	end)

	if success and type(distance) == "number" then
		return distance
	end

	return nil
end

local function mission_start_position()
	if not rawget(_G, "EngineOptimized") or not EngineOptimized.point_on_mainpath then
		return nil
	end

	local success, position = pcall(EngineOptimized.point_on_mainpath, 0)

	return success and position or nil
end

local function main_path_is_linear()
	local main_path = Managers.state and Managers.state.main_path

	if not main_path or not main_path.path_type then
		return false
	end

	local success, path_type = pcall(main_path.path_type, main_path)

	return success and path_type == "linear"
end

-- Mirrors PickupSystem._spawn_linear_pickups section membership. The normal
-- pass uses an exclusive upper boundary, except for an exact 1.0 progress
-- value in the final section. A terminal authored spawner can therefore be
-- outside every normal section when last_progress is below 1.0.
local function game_section_for_progress(
	progress,
	collect_amount,
	first_progress,
	last_progress,
	usable_spawner_count
)
	if not collect_amount or collect_amount < 1 or type(progress) ~= "number" then
		return nil
	end

	local section_start = 0
	local section_size = 1 / collect_amount

	if usable_spawner_count and usable_spawner_count >= 2 then
		if type(first_progress) ~= "number" or type(last_progress) ~= "number" then
			return nil
		end

		section_start = first_progress
		section_size = (last_progress - first_progress) / collect_amount
	end

	for group = 1, collect_amount do
		local section_end = section_start + section_size
		local in_section = section_start <= progress and progress < section_end
		local final_progress_special_case = group == collect_amount and progress == 1

		if in_section or final_progress_special_case then
			return group
		end

		section_start = section_end
	end

	return nil
end

local function mark_always_inactive_locations(
	locations,
	locations_by_unit,
	side_mission_components,
	collect_amount,
	first_progress,
	last_progress
)
	for i = 1, #locations do
		locations[i].always_inactive = false
		locations[i].normal_section_eligible = false
	end

	if not main_path_is_linear()
		or not collect_amount
		or collect_amount < 1
		or #side_mission_components == 0 then
		return
	end

	local covered_sections = {}
	local usable_spawner_count = #side_mission_components

	for i = 1, usable_spawner_count do
		local record = side_mission_components[i]

		if record.supports_book then
			local group = game_section_for_progress(
				record.progress,
				collect_amount,
				first_progress,
				last_progress,
				usable_spawner_count
			)

			if group then
				covered_sections[group] = true

				local candidate = locations_by_unit[record.unit]

				if candidate then
					candidate.normal_section_eligible = true
				end
			end
		end
	end

	-- Excluded spawners can still be used by the game's spawn-debt fallback.
	-- Only call one ALWAYS INACTIVE when every normal section independently has
	-- a compatible book spawner, which keeps spawn debt at zero and makes that
	-- fallback unreachable for this side-mission pickup set.
	for group = 1, collect_amount do
		if not covered_sections[group] then
			return
		end
	end

	for i = 1, #locations do
		local candidate = locations[i]

		if not candidate.normal_section_eligible then
			candidate.always_inactive = true
		end
	end
end

local function assign_path_sections(locations, collect_amount, first_progress, last_progress)
	if not main_path_is_linear() or not collect_amount or collect_amount < 1 or #locations == 0 then
		return
	end

	local section_start = 0
	local section_size = 1 / collect_amount

	if first_progress and last_progress and first_progress ~= last_progress then
		section_start = first_progress
		section_size = (last_progress - first_progress) / collect_amount
	end

	for i = 1, #locations do
		local location = locations[i]
		local group = 1

		if section_size > 0 then
			group = math.floor((candidate_progress(location) - section_start) / section_size) + 1
		end

		location.path_section = math.max(1, math.min(collect_amount, group))
		location.group = location.path_section
	end
end

local function allocation_candidate_sort(a, b)
	local a_progress = candidate_progress(a)
	local b_progress = candidate_progress(b)

	if a_progress ~= b_progress then
		return a_progress < b_progress
	end

	local ax, ay, az = Vector3.to_elements(a.position:unbox())
	local bx, by, bz = Vector3.to_elements(b.position:unbox())

	if az ~= bz then
		return az < bz
	elseif ay ~= by then
		return ay < by
	end

	return ax < bx
end


-- Darktide does not persist an allocation number on a side-mission spawner.
-- Normally one path section supplies one book, so the allocation and section
-- numbers are identical. When an earlier section cannot spawn a book, its
-- spawn debt is repaid by selecting multiple books in a later section. After
-- the first selection there, the game prefers the closest remaining spawner
-- by main-path percentage. Coloring those progress-ordered candidates
-- cyclically across the current allocation and its repaid debts reconstructs
-- the stable co-occurrence sets observed on debt maps such as dm_stockpile.
local function assign_allocation_groups(
	locations,
	locations_by_unit,
	side_mission_components,
	collect_amount,
	first_progress,
	last_progress
)
	assign_path_sections(locations, collect_amount, first_progress, last_progress)

	if not main_path_is_linear()
		or not collect_amount
		or collect_amount < 1
		or #side_mission_components == 0 then
		return
	end

	local records_by_section = {}

	for section = 1, collect_amount do
		records_by_section[section] = {}
	end

	for i = 1, #side_mission_components do
		local record = side_mission_components[i]
		local section = game_section_for_progress(
			record.progress,
			collect_amount,
			first_progress,
			last_progress,
			#side_mission_components
		)

		if section then
			local section_records = records_by_section[section]

			section_records[#section_records + 1] = record
		end
	end

	local pending_allocations = {}

	for section = 1, collect_amount do
		pending_allocations[#pending_allocations + 1] = section

		local section_records = records_by_section[section]
		local section_spawner_count = #section_records

		if section_spawner_count > 0 then
			local compatible_candidates = {}
			local compatible_lookup = {}

			for i = 1, section_spawner_count do
				local record = section_records[i]

				if record.supports_book then
					local candidate = locations_by_unit[record.unit]

					if candidate and not compatible_lookup[candidate] then
						compatible_lookup[candidate] = true
						compatible_candidates[#compatible_candidates + 1] = candidate
					end
				end
			end

			table.sort(compatible_candidates, allocation_candidate_sort)

			local remaining_sections = collect_amount - section + 1
			local spawn_debt = #pending_allocations - 1
			local requested_spawns = math.min(
				1 + math.ceil(spawn_debt / remaining_sections),
				section_spawner_count
			)
			local fulfilled_count = math.min(
				requested_spawns,
				#compatible_candidates,
				#pending_allocations
			)

			if fulfilled_count > 0 then
				-- Give the current section the first color, followed by the oldest
				-- outstanding allocation. This fixes the otherwise arbitrary label
				-- orientation while preserving the game's co-occurrence partition.
				local fulfilled_allocations = {
					section,
				}

				for i = 1, #pending_allocations do
					local allocation = pending_allocations[i]

					if allocation ~= section
						and #fulfilled_allocations < fulfilled_count then
						fulfilled_allocations[#fulfilled_allocations + 1] = allocation
					end
				end

				for i = 1, #compatible_candidates do
					local allocation_index = (i - 1) % fulfilled_count + 1

					compatible_candidates[i].group = fulfilled_allocations[allocation_index]
				end

				local fulfilled_lookup = {}

				for i = 1, #fulfilled_allocations do
					fulfilled_lookup[fulfilled_allocations[i]] = true
				end

				local still_pending = {}

				for i = 1, #pending_allocations do
					local allocation = pending_allocations[i]

					if not fulfilled_lookup[allocation] then
						still_pending[#still_pending + 1] = allocation
					end
				end

				pending_allocations = still_pending
			end
		end
	end
end

candidate_progress = function(candidate)
	local extension = candidate.extension

	if extension and extension.percentage_through_level then
		local success, percentage = pcall(extension.percentage_through_level, extension)

		if success then
			return percentage or 0
		end
	end

	return 0
end

local function candidate_sort(a, b)
	local a_group = a.group or 0
	local b_group = b.group or 0

	if a_group ~= b_group then
		return a_group < b_group
	end

	if a.start_distance_squared and b.start_distance_squared
		and a.start_distance_squared ~= b.start_distance_squared then
		return a.start_distance_squared < b.start_distance_squared
	end

	if a.path_distance and b.path_distance and a.path_distance ~= b.path_distance then
		return a.path_distance < b.path_distance
	end

	local a_progress = candidate_progress(a)
	local b_progress = candidate_progress(b)

	if a_progress ~= b_progress then
		return a_progress < b_progress
	end

	local ax, ay, az = Vector3.to_elements(a.position:unbox())
	local bx, by, bz = Vector3.to_elements(b.position:unbox())

	if az ~= bz then
		return az < bz
	elseif ay ~= by then
		return ay < by
	end

	return ax < bx
end

local function pickup_system()
	local extension_manager = Managers.state and Managers.state.extension

	if not extension_manager then
		return nil
	end

	return extension_manager:system("pickup_system")
end

local function pickup_type(unit)
	if not unit_is_alive(unit) then
		return nil
	end

	local success, value = pcall(Unit.get_data, unit, "pickup_type")

	return success and value or nil
end

local function spawner_unit(spawner)
	if not spawner then
		return nil
	elseif spawner._unit then
		return spawner._unit
	elseif spawner.unit then
		local success, unit = pcall(spawner.unit, spawner)

		return success and unit or nil
	end

	return nil
end

local function nearest_inactive_candidate(locations, position)
	local closest
	local closest_distance_squared = math.huge

	for i = 1, #locations do
		local candidate = locations[i]

		if not candidate.active and not candidate.always_inactive then
			local distance_squared = Vector3.distance_squared(position, candidate.position:unbox())

			if distance_squared < closest_distance_squared then
				closest = candidate
				closest_distance_squared = distance_squared
			end
		end
	end

	return closest, closest_distance_squared
end

scan_pickup_system = function()
	local book_type = mod._active_book_type

	if not book_type then
		return false
	end

	local system = pickup_system()
	local unit_to_extension = system and system._unit_to_extension_map

	if type(unit_to_extension) ~= "table" then
		return false
	end

	local locations = {}
	local locations_by_position = {}
	local locations_by_unit = {}
	local side_mission_components = {}
	local start_position = mission_start_position()
	local first_side_mission_progress
	local last_side_mission_progress

	-- The pickup system owns the complete post-initialization set of authored
	-- spawner extensions. Darktide registers side-mission spawn locations per
	-- component, so preserve that component-level eligibility for section tests
	-- while still displaying one row per authored root position.
	for unit, extension in pairs(unit_to_extension) do
		if Unit.alive(unit) then
			local components = extension and extension._components
			local supports_book = false
			local progress = candidate_progress({
				extension = extension,
			})

			if type(components) == "table" then
				for component_index = 1, #components do
					local component = components[component_index]

					if is_side_mission_component(component) then
						local component_supports_book = list_contains(component.spawnable_pickups, book_type)

						side_mission_components[#side_mission_components + 1] = {
							component_index = component_index,
							extension = extension,
							progress = progress,
							supports_book = component_supports_book,
							unit = unit,
						}

						first_side_mission_progress = math.min(first_side_mission_progress or progress, progress)
						last_side_mission_progress = math.max(last_side_mission_progress or progress, progress)
						supports_book = supports_book or component_supports_book
					end
				end
			end

			if supports_book then
				local position = safe_local_position(unit)

				if position then
					local key = position_key(position)
					local candidate = locations_by_position[key]

					if not candidate then
						candidate = {
							active = false,
							extension = extension,
							path_distance = main_path_distance(position),
							position = Vector3Box(position),
							start_distance_squared = start_position
								and Vector3.distance_squared(position, start_position)
								or nil,
							unit = unit,
						}
						locations_by_position[key] = candidate
						locations[#locations + 1] = candidate
					end

					locations_by_unit[unit] = candidate
				end
			end
		end
	end

	local mission_manager = Managers.state and Managers.state.mission
	local side_mission = mission_manager and mission_manager:side_mission()
	local collect_amount = side_mission and side_mission.collect_amount

	assign_allocation_groups(
		locations,
		locations_by_unit,
		side_mission_components,
		collect_amount,
		first_side_mission_progress,
		last_side_mission_progress
	)
	mark_always_inactive_locations(
		locations,
		locations_by_unit,
		side_mission_components,
		collect_amount,
		first_side_mission_progress,
		last_side_mission_progress
	)

	table.sort(locations, candidate_sort)

	local locations_by_key = {}

	for i = 1, #locations do
		local location = locations[i]
		local key = location_storage_key(location)

		location.location_key = key
		locations_by_key[key] = location

		if mod._selected_location_keys[key] then
			location.active = true
			location.always_inactive = false
		end
	end

	local exact_pickups = {}
	local pickup_to_spawner = system._pickup_to_spawner

	-- This exact relation is populated when BookTracker runs in the same game
	-- process that selected the pickups. It is preferred whenever available.
	if type(pickup_to_spawner) == "table" then
		for pickup, spawner in pairs(pickup_to_spawner) do
			if pickup_type(pickup) == book_type then
				local candidate = locations_by_unit[spawner_unit(spawner)]

				if candidate then
					local key = candidate.location_key
					local spawn = mod._active_spawns[pickup]
					local old_key = spawn and spawn.location_key

					if old_key and old_key ~= key then
						local old_candidate = locations_by_key[old_key]

						mod._selected_location_keys[old_key] = nil

						if old_candidate then
							old_candidate.active = false
							old_candidate.active_unit = nil
						end
					end

					candidate.active = true
					candidate.active_unit = pickup
					candidate.always_inactive = false
					mod._selected_location_keys[key] = true

					if spawn then
						spawn.location_key = key
					end

					exact_pickups[pickup] = true
				end
			end
		end
	end

	local unmatched_count = 0

	-- Normal players are clients of a dedicated server, so the server-owned
	-- pickup-to-spawner relation can be empty. In that case the initial pickup
	-- position captured by SideMissionPickupExtension selects the nearest
	-- authored spawner. No distance cutoff is used: these are the only eligible
	-- spawners and selection is one-to-one.
	for pickup, spawn in pairs(mod._active_spawns) do
		if spawn.book_type == book_type and not exact_pickups[pickup] then
			local candidate = spawn.location_key and locations_by_key[spawn.location_key]
			local distance_squared

			if not candidate then
				candidate, distance_squared = nearest_inactive_candidate(
					locations,
					spawn.position:unbox()
				)
			end

			if candidate then
				local key = candidate.location_key

				candidate.active = true
				candidate.active_unit = unit_is_alive(pickup) and pickup or nil
				candidate.always_inactive = false
				mod._selected_location_keys[key] = true
				spawn.location_key = key

				if distance_squared then
					debug_log(
						"Matched active %s to spawner root at %.2fm.",
						book_type,
						math.sqrt(distance_squared)
					)
				end
			else
				unmatched_count = unmatched_count + 1
			end
		end
	end

	local matched_count = 0
	local always_inactive_count = 0
	local signature_parts = {
		book_type,
		tostring(unmatched_count),
	}

	for i = 1, #locations do
		local candidate = locations[i]

		if candidate.active then
			matched_count = matched_count + 1
		end

		if candidate.always_inactive then
			always_inactive_count = always_inactive_count + 1
		end

		signature_parts[#signature_parts + 1] = position_key(candidate.position:unbox())
			.. (candidate.active and ":1" or ":0")
			.. (candidate.always_inactive and ":I" or ":A")
			.. ":" .. tostring(candidate.group or 0)
			.. ":" .. tostring(candidate.path_section or 0)
			.. ":" .. tostring(candidate.start_distance_squared or -1)
	end

	local signature = table.concat(signature_parts, "|")

	mod._display_locations = locations
	mod._matched_count = matched_count
	mod._unmatched_count = unmatched_count
	mod._last_scanned_book_type = book_type
	sync_world_markers()

	if signature ~= mod._last_scan_signature then
		mod._last_scan_signature = signature
		touch()
		debug_log(
			"Pickup-system scan: %d authored, %d active, %d always inactive, %d unmatched.",
			#locations,
			matched_count,
			always_inactive_count,
			unmatched_count
		)

		for i = 1, #locations do
			local candidate = locations[i]

			if candidate.group ~= candidate.path_section then
				local x, y, z = Vector3.to_elements(candidate.position:unbox())

				debug_log(
					"Allocation split: section=%s allocation=%s progress=%.6f root=(%.1f, %.1f, %.1f)",
					tostring(candidate.path_section or "none"),
					tostring(candidate.group or "none"),
					candidate_progress(candidate),
					x,
					y,
					z
				)
			end

			if candidate.always_inactive then
				local x, y, z = Vector3.to_elements(candidate.position:unbox())

				debug_log(
					"Always inactive: group=%s progress=%.6f root=(%.1f, %.1f, %.1f)",
					tostring(candidate.group or "none"),
					candidate_progress(candidate),
					x,
					y,
					z
				)
			end
		end
	end

	return true
end

function mod:get_book_tracker_state()
	protected_call("objective update", refresh_book_type)

	if mod._active_book_type and mod._last_scanned_book_type ~= mod._active_book_type then
		protected_call("pickup-system scan", scan_pickup_system)
	end

	return mod._active_book_type,
		mod._display_locations,
		mod._matched_count,
		mod._unmatched_count,
		mod._revision,
		mod._internal_error
end

mod:register_hud_element({
	class_name = "HudElementBookTracker",
	filename = "BookTracker/scripts/mods/BookTracker/BookTracker_hud",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
})

mod:command(
	"bookcopy",
	mod:localize("bookcopy_command_description"),
	copy_locations_to_clipboard
)

mod:command(
	"bookmove",
	mod:localize("bookmove_command_description"),
	toggle_book_move_mode
)

mod:hook_safe("HudElementWorldMarkers", "init", function(self)
	if BookTrackerMarker and BookTrackerMarker.name then
		self._marker_templates[BookTrackerMarker.name] = BookTrackerMarker
		mod._world_marker_hud_ready = true
		protected_call("world marker initialization", sync_world_markers)
	end
end)

mod:hook_safe("HudElementWorldMarkers", "destroy", function()
	mod._world_marker_hud_ready = false
	mod._world_marker_ids = {}
	mod._world_marker_pending = {}
	mod._world_marker_data = {}
	mod._world_marker_desired = {}
	mod._world_marker_targets = {}
end)

local function register_active_book(self, unit)
	local book_type = pickup_type(unit)

	if not BOOK_TYPES[book_type] or mod._active_spawns[unit] then
		return
	end

	local position = safe_local_position(unit)

	if not position then
		return
	end

	mod._active_spawns[unit] = {
		book_type = book_type,
		position = Vector3Box(position),
	}
	mod._scan_elapsed = SCAN_INTERVAL
	mod._last_scanned_book_type = nil

	debug_log("Active %s registered at %s", book_type, tostring(position))
end

mod:hook_safe("SideMissionPickupExtension", "_register_to_mission_objective", function(...)
	protected_call("active book registration", register_active_book, ...)
end)

mod.update = function(dt)
	protected_call("periodic update", function()
		refresh_book_type()

		if not mod._active_book_type then
			return
		end

		mod._scan_elapsed = mod._scan_elapsed + dt

		if mod._scan_elapsed >= SCAN_INTERVAL then
			mod._scan_elapsed = 0
			scan_pickup_system()
		end
	end)
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "world_marker_mode" then
		protected_call("world marker setting", sync_world_markers)
	end
end

mod.on_enabled = function()
	protected_call("world marker enable", sync_world_markers)
end

mod.on_disabled = function()
	mod._tracker_screen_bounds = nil
	mod._book_move_mode = false
	protected_call("world marker disable", clear_world_markers)
end

mod.on_unload = function()
	mod._tracker_screen_bounds = nil
	mod._book_move_mode = false
	clear_world_markers()
end

mod.on_game_state_changed = function(status, state_name)
	if state_name == "StateLoading" and status == "enter" then
		reset_state()
	end
end
