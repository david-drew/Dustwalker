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

# =============================================================================
# TERRAIN GENERATION SIGNALS
# =============================================================================

## Emitted when procedural terrain generation starts.
## @param seed_value: int - The seed being used for generation.
signal map_generation_started(seed_value: int)

## Emitted periodically during terrain generation with progress.
## @param progress: float - Progress from 0.0 to 1.0.
signal map_generation_progress(progress: float)

## Emitted when procedural terrain generation completes.
## @param seed_value: int - The seed that was used for generation.
signal map_generation_complete(seed_value: int)

# =============================================================================
# DEBUG SIGNALS
# =============================================================================

## Emitted to toggle debug display visibility.
## @param enabled: bool - Whether debug display should be shown.
signal debug_display_toggled(enabled: bool)

# =============================================================================
# TIME SIGNALS (Week 4A)
# =============================================================================

## Emitted when a new turn starts.
## @param turn: int - Turn number (1-6).
## @param day: int - Day number.
## @param time_name: String - Name of time of day.
signal turn_started(turn: int, day: int, time_name: String)

## Emitted when turns are advanced.
## @param old_turn: int - Previous turn.
## @param new_turn: int - New turn.
## @param turns_consumed: int - Number of turns that passed.
signal turn_advanced(old_turn: int, new_turn: int, turns_consumed: int)

## Emitted when a turn ends.
## @param turn: int - Turn that ended.
## @param day: int - Current day.
signal turn_ended(turn: int, day: int)

## Emitted when a new day starts.
## @param day: int - The new day number.
signal day_started(day: int)

## Emitted when time of day changes.
## @param old_name: String - Previous time name.
## @param new_name: String - New time name.
signal time_of_day_changed(old_name: String, new_name: String)

# =============================================================================
# PLAYER SIGNALS (Week 4A)
# =============================================================================

## Emitted when the player is spawned.
## @param hex_coords: Vector2i - Spawn location.
signal player_spawned(hex_coords: Vector2i)

## Emitted when player position changes (instant or after movement).
## @param new_hex: Vector2i - New position.
signal player_position_changed(new_hex: Vector2i)

## Emitted when player movement starts.
## @param from_hex: Vector2i - Starting position.
## @param to_hex: Vector2i - Destination.
signal player_movement_started(from_hex: Vector2i, to_hex: Vector2i)

## Emitted when player moves to a hex during movement.
## @param hex_coords: Vector2i - Current hex.
signal player_moved_to_hex(hex_coords: Vector2i)

## Emitted when player movement completes.
## @param total_hexes: int - Number of hexes moved.
## @param total_turns: int - Number of turns consumed.
signal player_movement_completed(total_hexes: int, total_turns: int)

## Emitted when player movement fails.
## @param reason: String - Reason for failure.
signal player_movement_failed(reason: String)

# =============================================================================
# FOG OF WAR SIGNALS (Week 4B)
# =============================================================================

## Emitted when fog system is initialized.
## @param total_hexes: int - Total hexes on the map.
signal fog_initialized(total_hexes: int)

## Emitted when a hex is explored for the first time.
## @param coords: Vector2i - Hex coordinates.
## @param day: int - Day of discovery.
## @param turn: int - Turn of discovery.
signal hex_first_explored(coords: Vector2i, day: int, turn: int)

## Emitted when a hex becomes visible.
## @param coords: Vector2i - Hex coordinates.
signal hex_became_visible(coords: Vector2i)

## Emitted when a hex leaves vision (becomes explored).
## @param coords: Vector2i - Hex coordinates.
signal hex_became_explored(coords: Vector2i)

## Emitted when vision range changes.
## @param old_range: int - Previous range.
## @param new_range: int - New range.
signal vision_range_changed(old_range: int, new_range: int)

## Emitted when exploration stats update.
## @param explored_count: int - Number of explored hexes.
## @param total_count: int - Total hexes.
## @param percentage: float - Exploration percentage.
signal exploration_stats_updated(explored_count: int, total_count: int, percentage: float)

## Emitted when entire map is revealed (debug).
signal map_revealed_debug()

## Emitted when fog rendering is toggled.
## @param enabled: bool - Whether fog is enabled.
signal fog_debug_toggled(enabled: bool)

# =============================================================================
# RIVER SIGNALS (Week 3)
# =============================================================================

## Emitted when river generation completes.
## @param river_count: int - Number of rivers generated.
signal rivers_generated(river_count: int)

# =============================================================================
# LOCATION SIGNALS (Week 3)
# =============================================================================

## Emitted when locations of a type have been placed.
## @param location_type: String - Type of location (town, fort, etc.).
## @param count: int - Number placed.
signal locations_placed(location_type: String, count: int)

## Emitted when a location is discovered by the player.
## @param location_data: Dictionary - Data about the discovered location.
signal location_discovered(location_data: Dictionary)

# =============================================================================
# SAVE/LOAD SIGNALS (Week 3)
# =============================================================================

## Emitted when a map is saved successfully.
## @param file_path: String - Path to the saved file.
signal map_saved(file_path: String)

## Emitted when a map save fails.
## @param reason: String - Reason for failure.
signal map_save_failed(reason: String)

## Emitted when a map is loaded successfully.
## @param file_path: String - Path to the loaded file.
## @param generation_seed: int - The seed of the loaded map.
signal map_loaded(file_path: String, generation_seed: int)

## Emitted when a map load fails.
## @param reason: String - Reason for failure.
signal map_load_failed(reason: String)

# =============================================================================
# VALIDATION SIGNALS (Week 3)
# =============================================================================

## Emitted when map validation completes.
## @param valid: bool - Whether validation passed.
## @param error_count: int - Number of errors found.
signal map_validation_complete(valid: bool, error_count: int)

# =============================================================================
# TERRAIN/WORLD SIGNALS
# =============================================================================

## Emitted when terrain at a hex changes.
## @param hex_coords: Vector2i - The coordinates of the changed hex.
## @param new_terrain: String - The new terrain type identifier.
signal terrain_changed(hex_coords: Vector2i, new_terrain: String)

## Emitted when fog of war is revealed at a location.
## @param hex_coords: Vector2i - The coordinates of the revealed hex.
signal fog_revealed(hex_coords: Vector2i)

# =============================================================================
# ENCOUNTER SIGNALS (Stage 5)
# =============================================================================

## Emitted when encounter check starts.
signal encounter_check_started(hex_coords: Vector2i)

## Emitted when an encounter is triggered.
## @param encounter_id: String - The encounter identifier.
## @param hex_coords: Vector2i - Where the encounter occurred.
signal encounter_triggered(encounter_id: String, hex_coords: Vector2i)

## Emitted when player makes a choice in an encounter.
signal encounter_choice_made(encounter_id: String, choice_index: int)

## Emitted when encounter is resolved.
signal encounter_resolved(encounter_id: String, effects: Dictionary)

## Emitted when encounter UI opens.
signal encounter_ui_opened()

## Emitted when encounter UI closes.
signal encounter_ui_closed()

# =============================================================================
# SURVIVAL SIGNALS (Stage 5)
# =============================================================================

## Emitted when hunger changes.
signal hunger_changed(new_value: int, old_value: int)

## Emitted when thirst changes.
signal thirst_changed(new_value: int, old_value: int)

## Emitted when health changes.
signal health_changed(new_value: int, old_value: int, source: String)

## Emitted when survival warning should be shown.
signal survival_warning(warning_type: String, level: int)

## Emitted when player is starving.
signal player_starving(hunger_level: int)

## Emitted when player is dehydrated.
signal player_dehydrated(thirst_level: int)

## Emitted when player dies.
signal player_died(cause: String)

# =============================================================================
# INVENTORY SIGNALS (Stage 5)
# =============================================================================

## Emitted when inventory contents change.
signal inventory_changed()

## Emitted when item is added.
signal item_added(item_id: String, quantity: int, new_total: int)

## Emitted when item is removed.
signal item_removed(item_id: String, quantity: int, new_total: int)

## Emitted when item is consumed.
signal item_consumed(item_id: String, effect: String)

## Emitted when item use fails.
signal cannot_consume_item(item_id: String, reason: String)

# =============================================================================
# COMBAT SIGNALS (Phase 1 Finale)
# =============================================================================

## Emitted when combat is initiated from an encounter.
## @param encounter_id: String - The encounter that triggered combat.
## @param terrain: String - Terrain type for tactical map.
signal combat_initiated(encounter_id: String, terrain: String)

## Emitted when combat scene/layer is ready.
signal combat_started()

## Emitted when combat ends.
## @param victory: bool - True if player won.
## @param loot: Dictionary - Loot gained (if victory).
signal combat_ended(victory: bool, loot: Dictionary)

## Emitted when player's combat turn starts.
signal player_combat_turn_started()

## Emitted when an enemy's combat turn starts.
## @param enemy_name: String - Name of the enemy.
signal enemy_combat_turn_started(enemy_name: String)

## Emitted when a combatant moves.
## @param combatant_name: String - Who moved.
## @param from_hex: Vector2i - Starting position.
## @param to_hex: Vector2i - Ending position.
signal combatant_moved(combatant_name: String, from_hex: Vector2i, to_hex: Vector2i)

## Emitted when a combatant attacks.
## @param attacker: String - Attacker name.
## @param target: String - Target name.
## @param hit: bool - Whether attack hit.
## @param damage: int - Damage dealt (0 if miss).
signal combatant_attacked(attacker: String, target: String, hit: bool, damage: int)

## Emitted when a combatant reloads their weapon.
## @param combatant_name: String - Who reloaded.
signal combatant_reloaded(combatant_name: String)

## Emitted when a combatant takes damage.
## @param combatant_name: String - Who was damaged.
## @param damage: int - Amount of damage.
## @param current_hp: int - HP after damage.
## @param max_hp: int - Maximum HP.
signal combatant_damaged(combatant_name: String, damage: int, current_hp: int, max_hp: int)

## Emitted when a combatant dies.
## @param combatant_name: String - Who died.
## @param is_player: bool - True if player died.
signal combatant_died(combatant_name: String, is_player: bool)

## Emitted when player wins combat.
## @param loot: Dictionary - Loot gained.
signal combat_victory(loot: Dictionary)

## Emitted when player loses combat.
signal combat_defeat()

## Emitted when a combat log message should be displayed.
## @param message: String - The message to display.
signal combat_log_message(message: String)

## Emitted when player AP changes during combat.
## @param current_ap: int - Current AP.
## @param max_ap: int - Maximum AP.
signal combat_ap_changed(current_ap: int, max_ap: int)

## Emitted when player ammo changes during combat.
## @param current_ammo: int - Current ammo.
## @param max_ammo: int - Maximum ammo.
signal combat_ammo_changed(current_ammo: int, max_ammo: int)

## Emitted when player health changes during combat.
## @param current_hp: int - Current HP.
## @param max_hp: int - Maximum HP.
signal combat_hp_changed(current_hp: int, max_hp: int)

## Emitted when combat round changes.
## @param round_number: int - The new round number.
signal combat_round_started(round_number: int)

## Emitted to request showing floating damage number.
## @param position: Vector2 - World position for the number.
## @param damage: int - Damage amount.
## @param is_player_damage: bool - True if player took damage.
signal show_floating_damage(position: Vector2, damage: int, is_player_damage: bool)

## Emitted to request showing miss indicator.
## @param position: Vector2 - World position for the indicator.
signal show_miss_indicator(position: Vector2)

# Time Signals
signal time_period_changed(period: String)
signal day_changed(day: int)
signal season_changed(season: String)
signal night_started(day: int)
signal dawn_started(day: int)

# Player Stat Signals
signal player_stat_changed(stat: String, old_value: int, new_value: int)
signal player_modifier_added(source: String, stat: String, value: int)
signal player_modifier_removed(source: String)
signal player_stat_check_rolled(stat: String, result: Dictionary)

# Temperature Signals
signal temperature_changed(temp: float, zone: String)
signal temperature_warning(zone: String, message: String)
signal temperature_damage(damage: int, type: String)

# Fatigue Signals
signal fatigue_changed(fatigue: int, level: String)
signal fatigue_level_changed(old_level: String, new_level: String)
signal stimulant_crash(fatigue_added: int)
signal collapse_risk(chance: float)

# Sleep Signals
signal sleep_started(turns: int, quality: float)
signal sleep_completed(result: Dictionary)
signal sleep_interrupted(reason: String)
signal sleep_deprivation_changed(stage: String, nights: int)
signal hallucination_started(type: String)
signal hallucination_ended()
