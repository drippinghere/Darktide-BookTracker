# BookTracker 1.0.0

BookTracker lists every level-authored Scripture or Grimoire spawn location for the current mission. It displays only the collectible used by the active side objective. Possible locations are white, locations selected for the current run are green, and locations that the game can prove will never become active are red. Optional in-world markers use the same state model.

## Requirements

- Darktide Mod Framework (DMF)
- Darktide Mod Loader

## Installation

1. Extract the `BookTracker` folder into your Darktide `mods` directory.
2. Add `BookTracker` on its own line in `mods/mod_load_order.txt`.
3. Launch Darktide through the mod loader.

The installed layout should be:

```text
mods/
└── BookTracker/
    ├── BookTracker.mod
    └── scripts/mods/BookTracker/
```

## What the HUD shows

- The header identifies the active objective as Scriptures or Grimoires.
- The summary reports active and possible location counts.
- The table separates location number, direction, live distance, X, Y, and Z into aligned columns.
- Linear missions divide locations into two Grimoire or three Scripture allocation sections.
- When an empty path section creates spawn debt, BookTracker reconstructs the later section's co-occurrence sets and assigns them to the affected allocation sections.
- Within each section, locations are ordered by their fixed 3D distance from the beginning of the mission's main path.
- Each row shows its current 3D distance from the player, a view-relative horizontal direction icon, a vertical level indicator, and world coordinates.
- The vertical indicator shows whether the location is above or below the player and displays `-` when its Z coordinate is within 1 meter of the player's.
- The upper-right summary displays the player's live X, Y, and Z coordinates.
- White rows are possible spawn locations.
- Green rows are locations where a book spawned in the current run. They remain green after the book is collected.
- Red rows are authored locations that BookTracker can prove the game will never select during that mission.
- The color legend at the bottom explains the three location states.
- Missions without a Scripture or Grimoire side objective show nothing.

## Chat commands

### `/bookmove`

Enables table move mode during a Scripture or Grimoire mission. Click and drag anywhere on the table to reposition it, then enter `/bookmove` again to exit. The position is saved when the mouse button is released and is constrained to the visible HUD workspace.

The position is stored proportionally instead of as fixed pixels, allowing it to adapt to changes in resolution, aspect ratio, HUD scale, and table height.

### `/bookcopy`

Copies the current mission's location data to the system clipboard. The copied text includes the localized mission name, internal mission ID, collectible type, and every displayed location. Each location includes its table number, allocation section, X/Y/Z coordinates, and Possible, Active, or Always Inactive status.

## Mod options

### Toggle Tracker Table

Assigns a keybind that hides or restores the table without disabling BookTracker or its world markers.

### HUD Update Interval

Controls how frequently the table refreshes live distances, direction indicators, and player coordinates.

- **Every Frame** provides the smoothest updates.
- **Every 0.25 Seconds** reduces the update frequency for lower-end systems.

Move mode always updates every frame while the table is being dragged.

### World Markers

Controls which location markers appear in the game world.

- **Show All Markers** displays every possible, active, and always-inactive location.
- **Show Active Only** displays only locations selected for the current mission.
- **Show Possible Only** displays possible locations while excluding active and always-inactive locations.
- **Show Always-Inactive Only** displays only locations that BookTracker has proven cannot become active.
- **Show Section 1 Only**, **Show Section 2 Only**, and **Show Section 3 Only** display every marker state from the selected allocation section. Section 3 is used only by Scripture missions.
- **Off** disables all BookTracker world markers.

Cyan markers identify possible locations, green markers identify active locations, and red markers identify always-inactive locations. Green markers follow a live book and remain at its original spawn location after collection. Each marker displays its table location number and current distance.

Markers are fully opaque below 30 meters, slightly dimmed at 30 meters and beyond, and strongly dimmed at 80 meters and beyond. A marker is hidden whenever its full icon footprint overlaps the visible tracker table.

### Background Opacity

Controls the table background from 0 to 100. A value of 0 is fully transparent and 100 is fully opaque.

### Text Size

Controls the table's font size from 12 to 24.

### Diagnostic Logging

Writes additional BookTracker discovery, matching, allocation, and error information to the game log. This should normally remain disabled and can be enabled when troubleshooting a mission or preparing a bug report.

## Known limitations

- Individual locations are numbered; custom landmark descriptions are not included.
- Open or non-linear missions do not use Darktide's path-section grouping algorithm, so BookTracker leaves their locations ungrouped.
- On a dedicated-server client, active books are associated with the nearest eligible authored spawner. The exact pickup-to-spawner association is used when the game exposes it locally.
- Re-enabling the entire mod after a mission has already loaded can miss active-book initialization events. Reload the mission after re-enabling it. The table keybind can hide or restore the table without disabling tracking or world markers.
