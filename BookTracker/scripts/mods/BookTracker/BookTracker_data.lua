local mod = get_mod("BookTracker")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "toggle_tracker_keybind",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "toggle_tracker_table",
			},
			{
				setting_id = "hud_update_interval",
				type = "dropdown",
				default_value = "every_frame",
				options = {
					{
						text = "hud_update_every_frame",
						value = "every_frame",
					},
					{
						text = "hud_update_quarter_second",
						value = "quarter_second",
					},
				},
			},
			{
				setting_id = "world_marker_mode",
				type = "dropdown",
				default_value = "off",
				options = {
					{
						text = "world_marker_mode_all",
						value = "all",
					},
					{
						text = "world_marker_mode_active",
						value = "active_only",
					},
					{
						text = "world_marker_mode_possible",
						value = "possible_only",
					},
					{
						text = "world_marker_mode_inactive",
						value = "always_inactive_only",
					},
					{
						text = "world_marker_mode_section_1",
						value = "all_section_1",
					},
					{
						text = "world_marker_mode_section_2",
						value = "all_section_2",
					},
					{
						text = "world_marker_mode_section_3",
						value = "all_section_3",
					},
					{
						text = "world_marker_mode_off",
						value = "off",
					},
				},
			},
			{
				setting_id = "background_opacity_percent",
				type = "numeric",
				default_value = 50,
				range = {
					0,
					100,
				},
			},
			{
				setting_id = "text_size",
				type = "numeric",
				default_value = 15,
				range = {
					12,
					24,
				},
			},
			{
				setting_id = "diagnostic_logging",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}
