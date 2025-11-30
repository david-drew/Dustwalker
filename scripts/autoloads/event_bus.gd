# event_bus.gd
# Global signal bus for decoupled communication between game systems.
# Add this as an autoload named "EventBus" in Project Settings.
extends Node

# =============================================================================
# HEX MAP SIGNALS
# =============================================================================

## Emitted when a hex cell is selected by the player.
## @param hex_coords: Vector2i - The axial coordinates (q, r) of the selected hex.
signal hex_selected(hex_coords: Vector2i)

## Emitted when the current hex selection is cleared.
signal hex_deselected()

## Emitted when the player hovers over a new hex.
## @param hex_coords: Vector2i - The axial coordinates of the hovered hex, or null if none.
signal hex_hovered(hex_coords: Vector2i)

## Emitted when the mouse leaves all hexes.
signal hex_hover_exited()

# =============================================================================
# CAMERA SIGNALS
# =============================================================================

## Emitted when the camera position changes.
## @param new_position: Vector2 - The new camera global position.
signal camera_moved(new_position: Vector2)

## Emitted when the camera zoom level changes.
## @param new_zoom: float - The new zoom level (1.0 = default, <1 = zoomed out, >1 = zoomed in).
signal camera_zoomed(new_zoom: float)

# =============================================================================
# MAP SIGNALS
# =============================================================================

## Emitted when the hex map has finished generating.
## @param map_size: Vector2i - The dimensions of the generated map.
signal map_generated(map_size: Vector2i)

## Emitted when map data is loaded from a file.
## @param map_name: String - The name/identifier of the loaded map.
signal map_loaded(map_name: String)

# =============================================================================
# DEBUG SIGNALS
# =============================================================================

## Emitted to toggle debug display visibility.
## @param enabled: bool - Whether debug display should be shown.
signal debug_display_toggled(enabled: bool)

# =============================================================================
# FUTURE EXPANSION SIGNALS (placeholder for weeks 3+)
# =============================================================================

## Emitted when terrain at a hex changes.
## @param hex_coords: Vector2i - The coordinates of the changed hex.
## @param new_terrain: String - The new terrain type identifier.
signal terrain_changed(hex_coords: Vector2i, new_terrain: String)

## Emitted when fog of war is revealed at a location.
## @param hex_coords: Vector2i - The coordinates of the revealed hex.
signal fog_revealed(hex_coords: Vector2i)

## Emitted when an encounter is triggered.
## @param hex_coords: Vector2i - The coordinates where the encounter occurred.
## @param encounter_data: Dictionary - Data about the encounter.
signal encounter_triggered(hex_coords: Vector2i, encounter_data: Dictionary)
