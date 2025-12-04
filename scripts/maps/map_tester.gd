# map_tester.gd
# Generates multiple maps with different seeds and validates each one.
# Produces a JSON report with results for each map.
#
# Usage:
#   var tester = MapTester.new()
#   tester.run_tests(hex_grid, 10)
#   # Results saved to user://saves/test_reports/

class_name MapTester
extends RefCounted

# =============================================================================
# CONSTANTS
# =============================================================================

const REPORT_DIRECTORY := "user://saves/test_reports/"

# =============================================================================
# SIGNALS
# =============================================================================

signal test_started(total_count: int)
signal test_progress(current: int, total: int, seed_value: int, valid: bool)
signal test_complete(passed: int, failed: int, report_path: String)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Maximum attempts per map before giving up
var max_attempts_per_map: int = 3

## Whether to save failed maps for debugging
var save_failed_maps: bool = true

# =============================================================================
# STATE
# =============================================================================

var _hex_grid: HexGrid = null
var _locations_config: Dictionary = {}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

## Runs validation tests on multiple generated maps.
## @param hex_grid: HexGrid - The grid to test with.
## @param count: int - Number of maps to generate and test.
## @param start_seed: int - Starting seed (0 = random).
## @return Dictionary - Test results summary.
func run_tests(hex_grid: HexGrid, count: int = 10, start_seed: int = 0) -> Dictionary:
	_hex_grid = hex_grid
	
	# Load locations config
	var loader = Engine.get_main_loop().root.get_node_or_null("/root/DataLoader")
	if loader:
		_locations_config = loader.load_map_config("locations_config")
	
	# Ensure report directory exists
	_ensure_report_directory()
	
	var results: Array[Dictionary] = []
	var passed := 0
	var failed := 0
	
	# Generate random starting seed if not provided
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if start_seed == 0:
		start_seed = rng.randi()
	
	test_started.emit(count)
	print("MapTester: Starting test run with %d maps (base seed: %d)" % [count, start_seed])
	
	for i in range(count):
		var test_seed := start_seed + i * 12345  # Different seeds
		var test_result := _test_single_map(test_seed, i + 1, count)
		results.append(test_result)
		
		if test_result["valid"]:
			passed += 1
		else:
			failed += 1
		
		test_progress.emit(i + 1, count, test_seed, test_result["valid"])
	
	# Generate report
	var report := _generate_report(results, passed, failed, start_seed)
	var report_path := _save_report(report)
	
	test_complete.emit(passed, failed, report_path)
	print("MapTester: Complete - %d passed, %d failed" % [passed, failed])
	print("MapTester: Report saved to %s" % report_path)
	
	return {
		"passed": passed,
		"failed": failed,
		"total": count,
		"pass_rate": float(passed) / float(count) * 100.0,
		"report_path": report_path,
		"results": results
	}


func _test_single_map(generation_seed: int, index: int, total: int) -> Dictionary:
	print("MapTester: Testing map %d/%d (seed: %d)" % [index, total, generation_seed])
	
	var attempt := 0
	var best_result: MapValidator.ValidationResult = null
	var final_seed := generation_seed
	
	while attempt < max_attempts_per_map:
		attempt += 1
		var current_seed := generation_seed + (attempt - 1) * 1000
		
		# Generate the map
		_hex_grid.generate_procedural_terrain(current_seed)
		
		# Get generators
		var terrain_gen := _hex_grid.get_terrain_generator()
		var river_gen := RiverGenerator.new()
		var location_placer := LocationPlacer.new()
		var validator := MapValidator.new()
		
		# Load configs
		river_gen.load_config(_locations_config)
		location_placer.load_config(_locations_config)
		validator.load_config(_locations_config)
		
		# Generate rivers
		river_gen.generate_rivers(_hex_grid, current_seed)
		
		# Set river generator for location placer
		location_placer.set_river_generator(river_gen)
		
		# Place locations
		location_placer.place_all_locations(_hex_grid, current_seed)
		
		# Validate
		var result := validator.validate_map(_hex_grid, river_gen, location_placer)
		
		if result.valid:
			best_result = result
			final_seed = current_seed
			break
		elif best_result == null or result.errors.size() < best_result.errors.size():
			best_result = result
			final_seed = current_seed
	
	# Build test result
	var test_result := {
		"seed": final_seed,
		"original_seed": generation_seed,
		"attempts": attempt,
		"valid": best_result.valid if best_result else false,
		"errors": best_result.errors if best_result else ["No result"],
		"warnings": best_result.warnings if best_result else [],
		"stats": best_result.stats if best_result else {}
	}
	
	# Optionally save failed maps for debugging
	if not test_result["valid"] and save_failed_maps:
		var serializer := MapSerializer.new()
		var filename := "failed_map_%d" % final_seed
		# Note: This would require regenerating the map with the same seed
		# For now, just log the failure
	
	return test_result

# =============================================================================
# REPORT GENERATION
# =============================================================================

func _generate_report(results: Array[Dictionary], passed: int, failed: int, base_seed: int) -> Dictionary:
	var report := {
		"summary": {
			"total_tests": results.size(),
			"passed": passed,
			"failed": failed,
			"pass_rate": float(passed) / float(results.size()) * 100.0,
			"base_seed": base_seed,
			"timestamp": Time.get_datetime_string_from_system()
		},
		"aggregate_stats": _calculate_aggregate_stats(results),
		"common_errors": _find_common_errors(results),
		"individual_results": results
	}
	
	return report


func _calculate_aggregate_stats(results: Array[Dictionary]) -> Dictionary:
	var stats := {
		"avg_rivers": 0.0,
		"avg_locations": 0.0,
		"avg_elevation": 0.0,
		"avg_moisture": 0.0,
		"location_counts": {}
	}
	
	var valid_count := 0
	
	for result in results:
		if not result.get("stats", {}).is_empty():
			valid_count += 1
			var s: Dictionary = result["stats"]
			
			stats["avg_rivers"] += s.get("river_count", 0)
			stats["avg_locations"] += s.get("total_locations", 0)
			stats["avg_elevation"] += s.get("avg_elevation", 0.5)
			stats["avg_moisture"] += s.get("avg_moisture", 0.5)
			
			var loc_counts: Dictionary = s.get("location_counts", {})
			for loc_type in loc_counts:
				if not stats["location_counts"].has(loc_type):
					stats["location_counts"][loc_type] = []
				stats["location_counts"][loc_type].append(loc_counts[loc_type])
	
	if valid_count > 0:
		stats["avg_rivers"] /= valid_count
		stats["avg_locations"] /= valid_count
		stats["avg_elevation"] /= valid_count
		stats["avg_moisture"] /= valid_count
		
		# Calculate min/max/avg for each location type
		for loc_type in stats["location_counts"]:
			var counts: Array = stats["location_counts"][loc_type]
			var sum := 0
			var min_val := 999
			var max_val := 0
			for c in counts:
				sum += c
				min_val = mini(min_val, c)
				max_val = maxi(max_val, c)
			
			stats["location_counts"][loc_type] = {
				"min": min_val,
				"max": max_val,
				"avg": float(sum) / counts.size()
			}
	
	return stats


func _find_common_errors(results: Array[Dictionary]) -> Array[Dictionary]:
	var error_counts: Dictionary = {}
	
	for result in results:
		var errors: Array = result.get("errors", [])
		for error in errors:
			# Normalize error message (remove specific values)
			var normalized := _normalize_error(error)
			error_counts[normalized] = error_counts.get(normalized, 0) + 1
	
	# Convert to sorted array
	var common_errors: Array[Dictionary] = []
	for error in error_counts:
		common_errors.append({
			"error": error,
			"count": error_counts[error],
			"percentage": float(error_counts[error]) / float(results.size()) * 100.0
		})
	
	common_errors.sort_custom(func(a, b): return a["count"] > b["count"])
	
	return common_errors


func _normalize_error(error: String) -> String:
	# Remove specific numbers to group similar errors
	var regex := RegEx.new()
	regex.compile("\\d+")
	return regex.sub(error, "N", true)


func _save_report(report: Dictionary) -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "test_report_%s.json" % timestamp
	var file_path := REPORT_DIRECTORY + filename
	
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("MapTester: Failed to save report to %s" % file_path)
		return ""
	
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	
	return file_path


func _ensure_report_directory() -> void:
	if not DirAccess.dir_exists_absolute(REPORT_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(REPORT_DIRECTORY)

# =============================================================================
# UTILITY
# =============================================================================

## Generates a human-readable test summary.
func generate_summary(results: Dictionary) -> String:
	var lines: Array[String] = []
	
	lines.append("=" .repeat(50))
	lines.append("MAP GENERATION TEST SUMMARY")
	lines.append("=" .repeat(50))
	lines.append("")
	lines.append("Total Tests: %d" % results["total"])
	lines.append("Passed: %d (%.1f%%)" % [results["passed"], results["pass_rate"]])
	lines.append("Failed: %d" % results["failed"])
	lines.append("")
	
	if results["passed"] >= results["total"] * 0.8:
		lines.append("STATUS: ACCEPTABLE ✓ (≥80% pass rate)")
	else:
		lines.append("STATUS: NEEDS IMPROVEMENT ✗ (<80% pass rate)")
	
	lines.append("")
	lines.append("Report saved to: %s" % results["report_path"])
	lines.append("=" .repeat(50))
	
	return "\n".join(lines)
