local mod = get_mod("BookTracker")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local template = {}
local MARKER_SIZE = {
	70,
	70,
}
local RING_SIZE = {
	32,
	32,
}
local INNER_SIZE = {
	24,
	24,
}
local ARROW_SIZE = {
	58,
	58,
}
local CYAN = {
	255,
	0,
	220,
	255,
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
	65,
	65,
}
local SLIGHTLY_DIM_ALPHA = 0.7
local DIM_ALPHA = 0.35
local SLIGHTLY_DIM_DISTANCE = 30
local DIM_DISTANCE = 80

template.size = MARKER_SIZE
template.name = "book_tracker_location"
template.max_distance = 2000
template.min_distance = 0
template.position_offset = {
	0,
	0,
	0.75,
}
template.screen_clamp = true
template.screen_margins = {
	down = 0.08,
	left = 0.05,
	right = 0.05,
	up = 0.08,
}
template.scale_settings = {
	distance_max = 120,
	distance_min = 8,
	scale_from = 0.65,
	scale_to = 1,
}

local function marker_color(marker)
	local data = marker.data

	if data and data.active then
		return GREEN
	elseif data and data.always_inactive then
		return RED
	end

	return CYAN
end

local function apply_color(widget, color)
	local style = widget.style

	style.ring.color = table.clone(color)
	style.arrow.color = table.clone(color)
	style.number.text_color = table.clone(color)
	style.distance.text_color = table.clone(color)
end

local function distance_alpha(distance)
	if distance >= DIM_DISTANCE then
		return DIM_ALPHA
	elseif distance >= SLIGHTLY_DIM_DISTANCE then
		return SLIGHTLY_DIM_ALPHA
	end

	return 1
end

local function overlaps_tracker_table(widget)
	local bounds = mod:tracker_screen_bounds()
	local offset = widget.offset

	if not bounds or not offset or offset[1] == nil or offset[2] == nil then
		return false
	end

	local half_width = MARKER_SIZE[1] * 0.5
	local half_height = MARKER_SIZE[2] * 0.5
	local x = offset[1]
	local y = offset[2]

	return x + half_width >= bounds.left
		and x - half_width <= bounds.right
		and y + half_height >= bounds.top
		and y - half_height <= bounds.bottom
end

template.create_widget_defintion = function(template, scenegraph_id)
	local font_settings = UIFontSettings.hud_body or UIFontSettings.body_small

	return UIWidget.create_definition({
		{
			pass_type = "rotated_texture",
			style_id = "arrow",
			value = "content/ui/materials/hud/interactions/frames/direction",
			style = {
				color = table.clone(CYAN),
				horizontal_alignment = "center",
				offset = {
					0,
					0,
					0,
				},
				size = ARROW_SIZE,
				vertical_alignment = "center",
			},
			visibility_function = function(content)
				return content.is_clamped
			end,
			change_function = function(content, style)
				style.angle = content.angle
			end,
		},
		{
			pass_type = "slug_icon",
			style_id = "ring",
			value = "content/ui/vector_textures/hud/circle_full",
			style = {
				color = table.clone(CYAN),
				default_size = RING_SIZE,
				horizontal_alignment = "center",
				offset = {
					0,
					0,
					1,
				},
				size = table.clone(RING_SIZE),
				vertical_alignment = "center",
			},
		},
		{
			pass_type = "slug_icon",
			style_id = "inner",
			value = "content/ui/vector_textures/hud/circle_full",
			style = {
				color = {
					220,
					2,
					10,
					9,
				},
				default_size = INNER_SIZE,
				horizontal_alignment = "center",
				offset = {
					0,
					0,
					2,
				},
				size = table.clone(INNER_SIZE),
				vertical_alignment = "center",
			},
		},
		{
			pass_type = "text",
			style_id = "number",
			value = "",
			value_id = "number",
			style = {
				font_size = 15,
				font_type = font_settings.font_type,
				horizontal_alignment = "center",
				offset = {
					0,
					-1,
					3,
				},
				size = {
					40,
					24,
				},
				text_color = table.clone(CYAN),
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
			},
		},
		{
			pass_type = "text",
			style_id = "distance",
			value = "",
			value_id = "distance_text",
			style = {
				font_size = 15,
				font_type = font_settings.font_type,
				horizontal_alignment = "center",
				offset = {
					0,
					27,
					3,
				},
				size = {
					100,
					22,
				},
				text_color = table.clone(CYAN),
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
			},
		},
	}, scenegraph_id)
end

template.on_enter = function(widget, marker)
	apply_color(widget, marker_color(marker))
end

template.update_function = function(parent, ui_renderer, widget, marker)
	local content = widget.content
	local data = marker.data or {}
	local distance = content.distance or 0
	local color = marker_color(marker)

	apply_color(widget, color)
	content.number = string.format("%02d", data.location_number or 0)
	content.distance_text = distance > 1
		and string.format("%dm", math.floor(distance + 0.5))
		or ""
	widget.alpha_multiplier = distance_alpha(distance)

	if overlaps_tracker_table(widget) then
		marker.draw = false
	end

	marker.ignore_scale = content.is_clamped

	return false
end

return template
