return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BookTracker` could not load the Darktide Mod Framework.")

		new_mod("BookTracker", {
			mod_script = "BookTracker/scripts/mods/BookTracker/BookTracker",
			mod_data = "BookTracker/scripts/mods/BookTracker/BookTracker_data",
			mod_localization = "BookTracker/scripts/mods/BookTracker/BookTracker_localization",
		})
	end,
	packages = {},
}

