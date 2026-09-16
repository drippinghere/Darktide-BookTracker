local mod = get_mod("BookTracker")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIResolution = require("scripts/managers/ui/ui_resolution")

local PANEL_WIDTH = 540
local PANEL_PADDING = 12
local INNER_WIDTH = PANEL_WIDTH - PANEL_PADDING * 2
local HEADER_HEIGHT = 32
local SUMMARY_HEIGHT = 24
local TABLE_HEADER_HEIGHT = 24
local ROW_HEIGHT = 24
local LEGEND_HEIGHT = 25
local LEGEND_GAP = 5
local BODY_TOP = HEADER_HEIGHT + SUMMARY_HEIGHT + TABLE_HEADER_HEIGHT
local DEFAULT_POSITION_X = 0
local DEFAULT_POSITION_Y = 0.5
local DIRECTION_X = 48
local DIRECTION_WIDTH = 88
local HORIZONTAL_DIRECTION_X = DIRECTION_X
local HORIZONTAL_DIRECTION_WIDTH = 56
local VERTICAL_DIRECTION_X = DIRECTION_X + 58
local VERTICAL_DIRECTION_WIDTH = 30
local DIRECTION_SIZE = {
	20,
	20,
}
local VERTICAL_INDICATOR_SIZE = {
	18,
	18,
}
local SAME_LEVEL_TOLERANCE = 1

local WHITE = {
	255,
	235,
	240,
	236,
}

local GREEN = {
	255,
	78,
	225,
	125,
}

local RED = {
	255,
	255,
	85,
	75,
}

local MUTED = {
	255,
	112,
	132,
	124,
}

local ACCENT = {
	255,
	66,
	135,
	116,
}

local ROW_ODD = {
	72,
	7,
	24,
	20,
}

local ROW_EVEN = {
	48,
	3,
	15,
	12,
}

local GROUP_BACKGROUND = {
	92,
	9,
	31,
	25,
}

local COLUMNS = {
	{
		id = "location",
		x = 0,
		width = 40,
		alignment = "left",
	},
	{
		id = "distance",
		x = 142,
		width = 82,
		alignment = "right",
	},
	{
		id = "x",
		x = 234,
		width = 84,
		alignment = "right",
	},
	{
		id = "y",
		x = 328,
		width = 84,
		alignment = "right",
	},
	{
		id = "z",
		x = 422,
		width = 84,
		alignment = "right",
	},
}

local LEGEND_COLUMNS = {
	{
		id = "possible",
		x = 0,
		width = 155,
		color = WHITE,
	},
	{
		id = "active",
		x = 165,
		width = 140,
		color = GREEN,
	},
	{
		id = "inactive",
		x = 315,
		width = 201,
		color = RED,
	},
}

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	tracker = {
		horizontal_alignment = "right",
		parent = "screen",
		vertical_alignment = "top",
		size = {
			0,
			0,
		},
		position = {
			-40,
			70,
			10,
		},
	},
}

local function visible(content)
	return content.visible
end

local function location_visible(content)
	return content.visible and content.row_kind == "location"
end

local function group_visible(content)
	return content.visible and content.row_kind == "group"
end

local function direction_visible(content)
	return location_visible(content) and content.has_direction
end

local function vertical_up_visible(content)
	return location_visible(content)
		and content.direction_enabled
		and content.vertical_direction == "above"
end

local function vertical_down_visible(content)
	return location_visible(content)
		and content.direction_enabled
		and content.vertical_direction == "below"
end

local function same_level_visible(content)
	return location_visible(content)
		and content.direction_enabled
		and content.vertical_direction == "same"
end

local function horizontal_offset(x, width)
	return -PANEL_PADDING - (INNER_WIDTH - x - width)
end

local function make_text_style(font_settings, x, width, y, height, alignment, color, font_size)
	local style = table.clone(font_settings)

	style.font_size = font_size
	style.horizontal_alignment = "right"
	style.offset = {
		horizontal_offset(x, width),
		y,
		3,
	}
	style.size = {
		width,
		height,
	}
	style.text_color = color
	style.text_horizontal_alignment = alignment
	style.text_vertical_alignment = "center"
	style.vertical_alignment = "top"

	return style
end

local header_style = make_text_style(
	UIFontSettings.header_3,
	0,
	INNER_WIDTH,
	5,
	HEADER_HEIGHT,
	"left",
	WHITE,
	21
)
local summary_style = make_text_style(
	UIFontSettings.body_small,
	0,
	278,
	HEADER_HEIGHT,
	SUMMARY_HEIGHT,
	"left",
	MUTED,
	16
)
local player_coordinates_style = make_text_style(
	UIFontSettings.body_small,
	280,
	INNER_WIDTH - 280,
	HEADER_HEIGHT,
	SUMMARY_HEIGHT,
	"right",
	MUTED,
	14
)

local column_header_passes = {}

for i = 1, #COLUMNS do
	local column = COLUMNS[i]

	column_header_passes[#column_header_passes + 1] = {
		pass_type = "text",
		style = make_text_style(
			UIFontSettings.body_small,
			column.x,
			column.width,
			HEADER_HEIGHT + SUMMARY_HEIGHT,
			TABLE_HEADER_HEIGHT,
			column.alignment,
			MUTED,
			14
		),
		style_id = column.id,
		value = "",
		value_id = column.id,
		visibility_function = visible,
	}
end

column_header_passes[#column_header_passes + 1] = {
	pass_type = "text",
	style = make_text_style(
		UIFontSettings.body_small,
		DIRECTION_X,
		DIRECTION_WIDTH,
		HEADER_HEIGHT + SUMMARY_HEIGHT,
		TABLE_HEADER_HEIGHT,
		"center",
		MUTED,
		14
	),
	style_id = "direction",
	value = "",
	value_id = "direction",
	visibility_function = visible,
}

local legend_passes = {}

for i = 1, #LEGEND_COLUMNS do
	local column = LEGEND_COLUMNS[i]

	legend_passes[#legend_passes + 1] = {
		pass_type = "text",
		style = make_text_style(
			UIFontSettings.body_small,
			column.x,
			column.width,
			BODY_TOP,
			LEGEND_HEIGHT,
			"left",
			column.color,
			14
		),
		style_id = column.id,
		value = "",
		value_id = column.id,
		visibility_function = visible,
	}
end

local widget_definitions = {
	background = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				color = {
					90,
					0,
					8,
					7,
				},
				horizontal_alignment = "right",
				offset = {
					0,
					0,
					0,
				},
				size = {
					PANEL_WIDTH,
					BODY_TOP + ROW_HEIGHT + LEGEND_HEIGHT + PANEL_PADDING,
				},
				vertical_alignment = "top",
			},
			visibility_function = visible,
		},
		{
			pass_type = "rect",
			style_id = "top_accent",
			style = {
				color = ACCENT,
				horizontal_alignment = "right",
				offset = {
					-PANEL_PADDING,
					0,
					1,
				},
				size = {
					INNER_WIDTH,
					1,
				},
				vertical_alignment = "top",
			},
			visibility_function = visible,
		},
		{
			pass_type = "rect",
			style_id = "header_separator",
			style = {
				color = ACCENT,
				horizontal_alignment = "right",
				offset = {
					-PANEL_PADDING,
					HEADER_HEIGHT + SUMMARY_HEIGHT - 1,
					1,
				},
				size = {
					INNER_WIDTH,
					1,
				},
				vertical_alignment = "top",
			},
			visibility_function = visible,
		},
		{
			pass_type = "rect",
			style_id = "legend_separator",
			style = {
				color = ACCENT,
				horizontal_alignment = "right",
				offset = {
					-PANEL_PADDING,
					BODY_TOP + ROW_HEIGHT,
					1,
				},
				size = {
					INNER_WIDTH,
					1,
				},
				vertical_alignment = "top",
			},
			visibility_function = visible,
		},
	}, "tracker"),
	header = UIWidget.create_definition({
		{
			pass_type = "text",
			style = header_style,
			style_id = "text",
			value = "",
			value_id = "text",
			visibility_function = visible,
		},
	}, "tracker"),
	summary = UIWidget.create_definition({
		{
			pass_type = "text",
			style = summary_style,
			style_id = "text",
			value = "",
			value_id = "text",
			visibility_function = visible,
		},
		{
			pass_type = "text",
			style = player_coordinates_style,
			style_id = "player_coordinates",
			value = "",
			value_id = "player_coordinates",
			visibility_function = visible,
		},
	}, "tracker"),
	column_headers = UIWidget.create_definition(column_header_passes, "tracker"),
	legend = UIWidget.create_definition(legend_passes, "tracker"),
}

local definitions = {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
}

local function row_widget_definition()
	local passes = {
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				color = ROW_ODD,
				horizontal_alignment = "right",
				offset = {
					-PANEL_PADDING,
					BODY_TOP,
					1,
				},
				size = {
					INNER_WIDTH,
					ROW_HEIGHT,
				},
				vertical_alignment = "top",
			},
			visibility_function = visible,
		},
		{
			pass_type = "text",
			style = make_text_style(
				UIFontSettings.body_small,
				0,
				INNER_WIDTH,
				BODY_TOP,
				ROW_HEIGHT,
				"left",
				ACCENT,
				16
			),
			style_id = "group",
			value = "",
			value_id = "group",
			visibility_function = group_visible,
		},
		{
			pass_type = "rotated_texture",
			style_id = "direction",
			value = "content/ui/materials/icons/mission_types/mission_type_quick",
			style = {
				color = table.clone(WHITE),
				horizontal_alignment = "right",
				offset = {
					horizontal_offset(
						HORIZONTAL_DIRECTION_X
							+ (HORIZONTAL_DIRECTION_WIDTH - DIRECTION_SIZE[1]) * 0.5,
						DIRECTION_SIZE[1]
					),
					BODY_TOP + (ROW_HEIGHT - DIRECTION_SIZE[2]) * 0.5,
					4,
				},
				size = DIRECTION_SIZE,
				vertical_alignment = "top",
			},
			visibility_function = direction_visible,
			change_function = function(content, style)
				style.angle = content.direction_angle or 0
			end,
		},
		{
			pass_type = "texture",
			style_id = "vertical_up",
			value = "content/ui/materials/icons/circumstances/more_resistance_01",
			style = {
				color = table.clone(WHITE),
				horizontal_alignment = "right",
				offset = {
					horizontal_offset(
						VERTICAL_DIRECTION_X
							+ (VERTICAL_DIRECTION_WIDTH - VERTICAL_INDICATOR_SIZE[1]) * 0.5,
						VERTICAL_INDICATOR_SIZE[1]
					),
					BODY_TOP + (ROW_HEIGHT - VERTICAL_INDICATOR_SIZE[2]) * 0.5,
					4,
				},
				size = VERTICAL_INDICATOR_SIZE,
				vertical_alignment = "top",
			},
			visibility_function = vertical_up_visible,
		},
		{
			pass_type = "texture",
			style_id = "vertical_down",
			value = "content/ui/materials/icons/circumstances/less_resistance_01",
			style = {
				color = table.clone(WHITE),
				horizontal_alignment = "right",
				offset = {
					horizontal_offset(
						VERTICAL_DIRECTION_X
							+ (VERTICAL_DIRECTION_WIDTH - VERTICAL_INDICATOR_SIZE[1]) * 0.5,
						VERTICAL_INDICATOR_SIZE[1]
					),
					BODY_TOP + (ROW_HEIGHT - VERTICAL_INDICATOR_SIZE[2]) * 0.5,
					4,
				},
				size = VERTICAL_INDICATOR_SIZE,
				vertical_alignment = "top",
			},
			visibility_function = vertical_down_visible,
		},
		{
			pass_type = "text",
			style = make_text_style(
				UIFontSettings.body_small,
				VERTICAL_DIRECTION_X,
				VERTICAL_DIRECTION_WIDTH,
				BODY_TOP,
				ROW_HEIGHT,
				"center",
				WHITE,
				16
			),
			style_id = "same_level",
			value = "",
			value_id = "same_level",
			visibility_function = same_level_visible,
		},
	}

	for i = 1, #COLUMNS do
		local column = COLUMNS[i]

		passes[#passes + 1] = {
			pass_type = "text",
			style = make_text_style(
				UIFontSettings.body_small,
				column.x,
				column.width,
				BODY_TOP,
				ROW_HEIGHT,
				column.alignment,
				WHITE,
				16
			),
			style_id = column.id,
			value = "",
			value_id = column.id,
			visibility_function = location_visible,
		}
	end

	return UIWidget.create_definition(passes, "tracker")
end

local HudElementBookTracker = class("HudElementBookTracker", "HudElementBase")

HudElementBookTracker.init = function(self, parent, draw_layer, start_scale)
	HudElementBookTracker.super.init(self, parent, draw_layer, start_scale, definitions)

	self._parent = parent
	self._row_widgets = {}
	self._last_revision = -1
	self._last_book_type = nil
	self._display_update_elapsed = math.huge
	self._book_tracker_scale = type(start_scale) == "number" and start_scale or 1
	self._position_x_normalized = nil
	self._position_y_normalized = nil
	self._drag_active = false
	self._drag_offset_x = 0
	self._drag_offset_y = 0
	self._cursor_pushed = false
end

HudElementBookTracker.destroy = function(self, ui_renderer)
	local input_manager = Managers.input

	if self._cursor_pushed and input_manager then
		input_manager:pop_cursor(self.__class_name)
		self._cursor_pushed = false
	end

	HudElementBookTracker.super.destroy(self, ui_renderer)
end

HudElementBookTracker._set_move_cursor = function(self, enabled)
	if enabled and not self._cursor_pushed then
		local input_manager = Managers.input

		if input_manager then
			input_manager:push_cursor(self.__class_name)
			input_manager:set_cursor_position(self.__class_name, Vector3(0.5, 0.5, 0))
			self._cursor_pushed = true
		end
	elseif not enabled and self._cursor_pushed then
		if self._drag_active then
			self:_save_position()
		end

		local input_manager = Managers.input

		if input_manager then
			input_manager:pop_cursor(self.__class_name)
		end

		self._cursor_pushed = false
		self._drag_active = false
	end
end

HudElementBookTracker.using_input = function(self)
	return self._cursor_pushed == true
end

HudElementBookTracker._saved_position = function(self)
	if self._position_x_normalized == nil then
		local legacy_position = mod:get("table_position")
		local default_x = legacy_position == "center_left" and 0 or DEFAULT_POSITION_X

		self._position_x_normalized = math.clamp(
			mod:get("table_position_x_normalized") or default_x,
			0,
			1
		)
	end

	if self._position_y_normalized == nil then
		self._position_y_normalized = math.clamp(
			mod:get("table_position_y_normalized") or DEFAULT_POSITION_Y,
			0,
			1
		)
	end

	return self._position_x_normalized, self._position_y_normalized
end

HudElementBookTracker._save_position = function(self)
	mod:set("table_position_x_normalized", self._position_x_normalized)
	mod:set("table_position_y_normalized", self._position_y_normalized)
end

HudElementBookTracker._drag_position = function(
	self,
	input_service,
	ui_renderer,
	left,
	top,
	available_width,
	available_height,
	panel_width,
	panel_height
)
	if not input_service or not ui_renderer then
		return left, top
	end

	local raw_cursor = input_service:get("cursor")

	if not raw_cursor then
		return left, top
	end

	local cursor = UIResolution.inverse_scale_vector(raw_cursor, ui_renderer.inverse_scale)
	local cursor_x, cursor_y = cursor[1], cursor[2]
	local left_pressed = input_service:get("left_pressed")
	local left_held = input_service:get("left_hold")

	if left_pressed
		and cursor_x >= left
		and cursor_x <= left + panel_width
		and cursor_y >= top
		and cursor_y <= top + panel_height then
		self._drag_active = true
		self._drag_offset_x = cursor_x - left
		self._drag_offset_y = cursor_y - top
	end

	if self._drag_active and left_held then
		left = math.clamp(cursor_x - self._drag_offset_x, 0, available_width)
		top = math.clamp(cursor_y - self._drag_offset_y, 0, available_height)
		self._position_x_normalized = available_width > 0 and left / available_width or 0
		self._position_y_normalized = available_height > 0 and top / available_height or 0
	elseif self._drag_active then
		self._drag_active = false
		self:_save_position()
	end

	return left, top
end

HudElementBookTracker._ensure_row_widgets = function(self, count)
	for i = #self._row_widgets + 1, count do
		local name = "book_tracker_row_" .. i
		local widget = self:_create_widget(name, row_widget_definition())

		self._widgets[#self._widgets + 1] = widget
		self._row_widgets[i] = widget
	end
end

HudElementBookTracker._player_state = function(self)
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(1)
	local player_unit = player and player.player_unit
	local position
	local forward

	if player_unit and Unit.alive(player_unit) then
		position = Unit.local_position(player_unit, 1)
	end

	local parent = self._parent
	local camera_api = rawget(_G, "Camera")
	local quaternion_api = rawget(_G, "Quaternion")

	if parent and parent.player_camera and camera_api and quaternion_api then
		local success, camera_forward = pcall(function()
			local camera = parent:player_camera()

			return camera and quaternion_api.forward(camera_api.local_rotation(camera))
		end)

		if success then
			forward = camera_forward
		end
	end

	if not forward and player_unit and Unit.alive(player_unit) and quaternion_api then
		local success, unit_forward = pcall(function()
			return quaternion_api.forward(Unit.local_rotation(player_unit, 1))
		end)

		if success then
			forward = unit_forward
		end
	end

	return position, forward
end

local function atan2(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	elseif x > 0 then
		return math.atan(y / x)
	elseif x < 0 and y >= 0 then
		return math.atan(y / x) + math.pi
	elseif x < 0 then
		return math.atan(y / x) - math.pi
	elseif y > 0 then
		return math.pi * 0.5
	elseif y < 0 then
		return -math.pi * 0.5
	end

	return 0
end

local function horizontal_direction_angle(origin, forward, target)
	if not origin or not forward or not target then
		return nil
	end

	local origin_x, origin_y = Vector3.to_elements(origin)
	local forward_x, forward_y = Vector3.to_elements(forward)
	local target_x, target_y = Vector3.to_elements(target)
	local delta_x = target_x - origin_x
	local delta_y = target_y - origin_y

	if forward_x * forward_x + forward_y * forward_y < 0.0001
		or delta_x * delta_x + delta_y * delta_y < 0.0001 then
		return nil
	end

	local forward_dot = forward_x * delta_x + forward_y * delta_y
	local right_dot = forward_y * delta_x - forward_x * delta_y

	-- mission_type_quick points right at angle zero. Rotate that authored right
	-- direction into the target's view-relative horizontal bearing.
	return math.pi * 0.5 - atan2(right_dot, forward_dot)
end

local function vertical_direction_state(origin, target)
	if not origin or not target then
		return nil
	end

	local _, _, origin_z = Vector3.to_elements(origin)
	local _, _, target_z = Vector3.to_elements(target)
	local difference = target_z - origin_z

	if difference > SAME_LEVEL_TOLERANCE then
		return "above"
	elseif difference < -SAME_LEVEL_TOLERANCE then
		return "below"
	end

	return "same"
end

HudElementBookTracker._row_values = function(self, index, location, player_position)
	local position = location.position:unbox()
	local x, y, z = Vector3.to_elements(position)
	local distance = ""

	if player_position then
		local distance_value = math.sqrt(Vector3.distance_squared(player_position, position))

		distance = string.format("%dm", math.floor(distance_value + 0.5))
	end

	x = string.format("%.1f", x)
	y = string.format("%.1f", y)
	z = string.format("%.1f", z)

	return {
		location = string.format("%02d", index),
		distance = distance,
		x = x,
		y = y,
		z = z,
	}
end

HudElementBookTracker._set_group_row = function(self, widget, group, location_count, row_index, font_size)
	widget.content.visible = true
	widget.content.row_kind = "group"
	widget.content.group = mod:localize("section_header_format", group, location_count)
	widget.content.has_direction = false
	widget.content.direction_enabled = false
	widget.content.vertical_direction = nil
	widget.content.same_level = nil

	for i = 1, #COLUMNS do
		widget.content[COLUMNS[i].id] = ""
	end

	widget.style.background.color = GROUP_BACKGROUND
	widget.style.group.font_size = font_size
	widget.dirty = true
end

HudElementBookTracker._set_location_row = function(
	self,
	widget,
	index,
	location,
	player_position,
	player_forward,
	row_index,
	font_size
)
	local values = self:_row_values(index, location, player_position)
	local state_color = location.active and GREEN or location.always_inactive and RED or WHITE

	widget.content.visible = true
	widget.content.row_kind = "location"
	widget.content.group = ""
	widget.content.direction_enabled = true
	widget.content.direction_angle = horizontal_direction_angle(
		player_position,
		player_forward,
		location.position:unbox()
	)
	widget.content.has_direction = widget.content.direction_angle ~= nil
	widget.content.vertical_direction = vertical_direction_state(
		player_position,
		location.position:unbox()
	)
	widget.content.same_level = widget.content.vertical_direction == "same" and "-" or nil

	for i = 1, #COLUMNS do
		local column = COLUMNS[i]

		widget.content[column.id] = values[column.id]
		widget.style[column.id].font_size = font_size
	end

	-- Every value in the row carries the same location-state color.
	widget.style.location.text_color = state_color
	widget.style.distance.text_color = state_color
	widget.style.x.text_color = state_color
	widget.style.y.text_color = state_color
	widget.style.z.text_color = state_color
	widget.style.direction.color = state_color
	widget.style.vertical_up.color = state_color
	widget.style.vertical_down.color = state_color
	widget.style.same_level.text_color = state_color
	widget.style.background.color = row_index % 2 == 0 and ROW_EVEN or ROW_ODD
	widget.dirty = true
end

HudElementBookTracker._update_layout = function(self, display_row_count)
	local panel_height = BODY_TOP
		+ math.max(1, display_row_count) * ROW_HEIGHT
		+ LEGEND_GAP
		+ LEGEND_HEIGHT
		+ PANEL_PADDING
	local legend_y = BODY_TOP + math.max(1, display_row_count) * ROW_HEIGHT + LEGEND_GAP
	local font_size = mod:get("text_size")

	local background = self._widgets_by_name.background

	background.style.background.size[1] = PANEL_WIDTH
	background.style.background.size[2] = panel_height
	local opacity_percent = math.clamp(mod:get("background_opacity_percent") or 31, 0, 100)

	background.style.background.color[1] = math.floor(opacity_percent * 2.55 + 0.5)
	background.style.legend_separator.offset[2] = legend_y - LEGEND_GAP

	local header = self._widgets_by_name.header
	local summary = self._widgets_by_name.summary

	header.style.text.font_size = font_size + 5
	summary.style.text.font_size = font_size
	summary.style.player_coordinates.font_size = math.max(12, font_size - 2)

	local column_headers = self._widgets_by_name.column_headers

	for i = 1, #COLUMNS do
		column_headers.style[COLUMNS[i].id].font_size = math.max(12, font_size - 2)
	end

	column_headers.style.direction.font_size = math.max(12, font_size - 2)

	for i = 1, #self._row_widgets do
		local widget = self._row_widgets[i]
		local y = BODY_TOP + (i - 1) * ROW_HEIGHT

		widget.style.background.offset[2] = y
		widget.style.group.offset[2] = y
		widget.style.direction.offset[2] = y + (ROW_HEIGHT - DIRECTION_SIZE[2]) * 0.5
		widget.style.vertical_up.offset[2] = y + (ROW_HEIGHT - VERTICAL_INDICATOR_SIZE[2]) * 0.5
		widget.style.vertical_down.offset[2] = y + (ROW_HEIGHT - VERTICAL_INDICATOR_SIZE[2]) * 0.5
		widget.style.same_level.offset[2] = y
		widget.style.same_level.font_size = font_size

		for column_index = 1, #COLUMNS do
			widget.style[COLUMNS[column_index].id].offset[2] = y
		end
	end

	local legend = self._widgets_by_name.legend

	for i = 1, #LEGEND_COLUMNS do
		local column = LEGEND_COLUMNS[i]
		local style = legend.style[column.id]

		style.offset[2] = legend_y
		style.font_size = math.max(12, font_size - 2)
	end

	return panel_height
end

local function virtual_screen_size()
	local resolution = rawget(_G, "RESOLUTION_LOOKUP")

	if resolution and resolution.width and resolution.height then
		local inverse_scale = resolution.inverse_scale or 1

		return resolution.width * inverse_scale, resolution.height * inverse_scale
	end

	local screen_size = UIWorkspaceSettings.screen and UIWorkspaceSettings.screen.size

	if screen_size then
		return screen_size[1], screen_size[2]
	end
end

local function update_hud(self, dt, t, ui_renderer, render_settings, input_service)
	local book_type, locations, matched_count, unmatched_count, revision, internal_error =
		mod:get_book_tracker_state()
	local should_show = mod:is_enabled()
		and mod:is_tracker_table_visible()
		and book_type ~= nil
	local location_count = should_show and #locations or 0
	local display_row_count = location_count
	local group_counts = {}

	if should_show then
		local previous_group

		for i = 1, location_count do
			local group = locations[i].group

			if group then
				group_counts[group] = (group_counts[group] or 0) + 1
			end

			if group and group ~= previous_group then
				display_row_count = display_row_count + 1
				previous_group = group
			end
		end
	end

	self:_ensure_row_widgets(display_row_count)
	local panel_height = self:_update_layout(display_row_count)
	local screen_width, screen_height = virtual_screen_size()
	local move_mode = should_show and mod:is_book_move_mode()

	self:_set_move_cursor(move_mode)

	if should_show then
		if screen_width and screen_height then
			local hud_scale = math.max(self._book_tracker_scale, 0.001)
			local panel_width_scaled = PANEL_WIDTH * hud_scale
			local panel_height_scaled = panel_height * hud_scale
			local available_width = math.max(0, screen_width - panel_width_scaled)
			local available_height = math.max(0, screen_height - panel_height_scaled)
			local position_x, position_y = self:_saved_position()
			local left = position_x * available_width
			local top = position_y * available_height

			if move_mode then
				left, top = self:_drag_position(
					input_service,
					ui_renderer,
					left,
					top,
					available_width,
					available_height,
					panel_width_scaled,
					panel_height_scaled
				)
			end

			-- The tracker point is the panel's upper-right corner because its
			-- passes are right-aligned. Normalized top-left coordinates keep the
			-- chosen placement proportional when resolution or aspect ratio changes.
			self:set_scenegraph_position(
				"tracker",
				left / hud_scale + PANEL_WIDTH,
				top / hud_scale,
				nil,
				"left",
				"top"
			)

			mod:set_tracker_screen_bounds({
				bottom = top + panel_height_scaled,
				left = left,
				right = left + panel_width_scaled,
				top = top,
			})
		else
			mod:set_tracker_screen_bounds(nil)
		end
	else
		mod:set_tracker_screen_bounds(nil)
	end

	local background = self._widgets_by_name.background
	local header = self._widgets_by_name.header
	local summary = self._widgets_by_name.summary
	local column_headers = self._widgets_by_name.column_headers
	local legend = self._widgets_by_name.legend

	background.content.visible = should_show
	header.content.visible = should_show
	summary.content.visible = should_show
	column_headers.content.visible = should_show
	legend.content.visible = should_show

	if should_show then
		local player_position, player_forward = self:_player_state()

		header.content.text = move_mode
			and mod:localize("bookmove_header")
			or book_type == "tome" and mod:localize("scripture_header")
			or mod:localize("grimoire_header")
		summary.content.text = mod:localize(
			"summary_format",
			matched_count,
			location_count
		)

		if player_position then
			local player_x, player_y, player_z = Vector3.to_elements(player_position)

			summary.content.player_coordinates = mod:localize(
				"player_coordinates_format",
				player_x,
				player_y,
				player_z
			)
		else
			summary.content.player_coordinates = ""
		end

		if unmatched_count > 0 and mod:get("diagnostic_logging") then
			summary.content.text = summary.content.text .. string.format("  |  %d unmatched", unmatched_count)
		end

		if internal_error and mod:get("diagnostic_logging") then
			summary.content.text = summary.content.text .. "  |  internal error"
		end

		column_headers.content.location = mod:localize("column_location")
		column_headers.content.direction = mod:localize("column_direction")
		column_headers.content.distance = mod:localize("column_distance")
		column_headers.content.x = mod:localize("column_x")
		column_headers.content.y = mod:localize("column_y")
		column_headers.content.z = mod:localize("column_z")

		legend.content.possible = mod:localize("legend_possible")
		legend.content.active = mod:localize("legend_active")
		legend.content.inactive = mod:localize("legend_inactive")

		local widget_index = 0
		local previous_group
		local font_size = mod:get("text_size")

		for i = 1, location_count do
			local location = locations[i]
			local group = location.group

			if group and group ~= previous_group then
				widget_index = widget_index + 1

				self:_set_group_row(
					self._row_widgets[widget_index],
					group,
					group_counts[group] or 0,
					widget_index,
					font_size + 1
				)
				previous_group = group
			end

			widget_index = widget_index + 1

			self:_set_location_row(
				self._row_widgets[widget_index],
				i,
				location,
				player_position,
				player_forward,
				widget_index,
				font_size
			)
		end
	end

	for i = display_row_count + 1, #self._row_widgets do
		self._row_widgets[i].content.visible = false
	end

	background.dirty = true
	header.dirty = true
	summary.dirty = true
	column_headers.dirty = true
	legend.dirty = true
	self._last_revision = revision
	self._last_book_type = book_type

	HudElementBookTracker.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudElementBookTracker.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	local update_interval = not mod:is_book_move_mode()
		and mod:get("hud_update_interval") == "quarter_second"
		and 0.25
		or 0

	self._display_update_elapsed = self._display_update_elapsed + dt

	if update_interval > 0 and self._display_update_elapsed < update_interval then
		HudElementBookTracker.super.update(self, dt, t, ui_renderer, render_settings, input_service)

		return
	end

	self._display_update_elapsed = 0

	local success, error_message = pcall(
		update_hud,
		self,
		dt,
		t,
		ui_renderer,
		render_settings,
		input_service
	)

	if not success then
		mod:set_book_tracker_error("HUD update", error_message)
		mod:set_tracker_screen_bounds(nil)

		for i = 1, #self._widgets do
			self._widgets[i].content.visible = false
		end
	end
end

return HudElementBookTracker
