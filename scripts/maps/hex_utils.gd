# hex_utils.gd
# Static utility class for hex grid mathematics and coordinate conversions.
# Implements flat-top hexagon calculations using axial coordinate system.
#
# COORDINATE SYSTEMS EXPLAINED:
# -----------------------------
# 1. AXIAL (q, r): The primary coordinate system we use.
#    - q: column (increases to the right)
#    - r: row (increases down-right for flat-top hexes)
#    - Efficient for storage and most hex algorithms
#
# 2. CUBE (x, y, z): Three-axis system where x + y + z = 0
#    - Useful for distance calculations and line drawing
#    - x = q, z = r, y = -q - r
#
# 3. OFFSET (col, row): Grid-like coordinates
#    - More intuitive for rectangular map bounds
#    - We use "odd-q" offset (odd columns shifted down)
#
# 4. PIXEL (x, y): Screen position in pixels
#    - Used for rendering and mouse input
#
# FLAT-TOP VS POINTY-TOP:
# -----------------------
# This implementation uses FLAT-TOP hexagons, meaning:
# - The flat edge is at the top and bottom
# - Hex width = size * 2
# - Hex height = size * sqrt(3)
# - Horizontal spacing = width * 3/4
# - Vertical spacing = height

class_name HexUtils
extends RefCounted

# =============================================================================
# CONSTANTS
# =============================================================================

## Square root of 3, used frequently in hex math.
const SQRT3 := 1.7320508075688772

## The six direction vectors in axial coordinates for flat-top hexes.
## Order: East, NE, NW, West, SW, SE (clockwise from right)
const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # East (right)
	Vector2i(1, -1),  # Northeast
	Vector2i(0, -1),  # Northwest
	Vector2i(-1, 0),  # West (left)
	Vector2i(-1, 1),  # Southwest
	Vector2i(0, 1)    # Southeast
]

## Direction names for debugging and display.
const DIRECTION_NAMES: Array[String] = [
	"East", "Northeast", "Northwest", "West", "Southwest", "Southeast"
]

# =============================================================================
# COORDINATE CONVERSIONS
# =============================================================================

## Converts axial coordinates to pixel position (center of hex).
## @param axial: Vector2i - Axial coordinates (q, r).
## @param hex_size: float - Distance from hex center to corner.
## @return Vector2 - Pixel position of hex center.
##
## FORMULA (flat-top):
##   x = size * (3/2 * q)
##   y = size * (sqrt(3)/2 * q + sqrt(3) * r)
static func axial_to_pixel(axial: Vector2i, hex_size: float) -> Vector2:
	var q := float(axial.x)
	var r := float(axial.y)
	
	var x := hex_size * (1.5 * q)
	var y := hex_size * (SQRT3 * 0.5 * q + SQRT3 * r)
	
	return Vector2(x, y)


## Converts pixel position to axial coordinates.
## @param pixel: Vector2 - Pixel position to convert.
## @param hex_size: float - Distance from hex center to corner.
## @return Vector2i - Axial coordinates of the hex containing this pixel.
##
## This uses the inverse of the axial_to_pixel formula, then rounds
## to the nearest hex using cube coordinate rounding.
static func pixel_to_axial(pixel: Vector2, hex_size: float) -> Vector2i:
	# Convert to fractional axial coordinates
	var q := (2.0/3.0 * pixel.x) / hex_size
	var r := (-1.0/3.0 * pixel.x + SQRT3/3.0 * pixel.y) / hex_size
	
	# Round to nearest hex using cube coordinates
	return axial_round(Vector2(q, r))


## Rounds fractional axial coordinates to the nearest hex.
## @param axial_frac: Vector2 - Fractional axial coordinates.
## @return Vector2i - Rounded axial coordinates.
##
## ALGORITHM:
## 1. Convert to cube coordinates (x, y, z)
## 2. Round each component
## 3. The component with largest rounding error gets recalculated
##    to maintain the constraint x + y + z = 0
## 4. Convert back to axial
static func axial_round(axial_frac: Vector2) -> Vector2i:
	# Convert to cube coordinates
	var cube := axial_to_cube_float(axial_frac)
	
	# Round each component
	var rx:Variant = round(cube.x)
	var ry:Variant = round(cube.y)
	var rz:Variant = round(cube.z)
	
	# Calculate rounding differences
	var x_diff:Variant = abs(rx - cube.x)
	var y_diff:Variant = abs(ry - cube.y)
	var z_diff:Variant = abs(rz - cube.z)
	
	# Reset the component with largest diff to satisfy x + y + z = 0
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	
	# Convert back to axial
	return Vector2i(int(rx), int(rz))


## Converts axial coordinates to cube coordinates.
## @param axial: Vector2i - Axial coordinates (q, r).
## @return Vector3i - Cube coordinates (x, y, z).
static func axial_to_cube(axial: Vector2i) -> Vector3i:
	var x := axial.x
	var z := axial.y
	var y := -x - z
	return Vector3i(x, y, z)


## Converts fractional axial to fractional cube (for rounding).
static func axial_to_cube_float(axial: Vector2) -> Vector3:
	var x := axial.x
	var z := axial.y
	var y := -x - z
	return Vector3(x, y, z)


## Converts cube coordinates to axial coordinates.
## @param cube: Vector3i - Cube coordinates (x, y, z).
## @return Vector2i - Axial coordinates (q, r).
static func cube_to_axial(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x, cube.z)


## Converts axial to offset coordinates (odd-q vertical layout).
## @param axial: Vector2i - Axial coordinates.
## @return Vector2i - Offset coordinates (col, row).
##
## Odd-q means odd columns are shifted down by half a hex.
static func axial_to_offset(axial: Vector2i) -> Vector2i:
	var col := axial.x
	var row := axial.y + int((axial.x - (axial.x & 1)) / 2)
	return Vector2i(col, row)


## Converts offset coordinates to axial (odd-q vertical layout).
## @param offset: Vector2i - Offset coordinates (col, row).
## @return Vector2i - Axial coordinates.
static func offset_to_axial(offset: Vector2i) -> Vector2i:
	var q := offset.x
	var r := offset.y - int((offset.x - (offset.x & 1)) / 2)
	return Vector2i(q, r)

# =============================================================================
# HEX GEOMETRY
# =============================================================================

## Gets the pixel positions of all six corners of a hex.
## @param center: Vector2 - Center position of the hex in pixels.
## @param size: float - Distance from center to corner.
## @return PackedVector2Array - The six corner positions, starting from right.
##
## For flat-top hexes, corners are at angles: 0°, 60°, 120°, 180°, 240°, 300°
static func get_hex_corners(center: Vector2, size: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	corners.resize(6)
	
	for i in range(6):
		# Flat-top: start at 0 degrees (pointing right)
		var angle_deg := 60.0 * i
		var angle_rad := deg_to_rad(angle_deg)
		corners[i] = Vector2(
			center.x + size * cos(angle_rad),
			center.y + size * sin(angle_rad)
		)
	
	return corners


## Gets the width of a flat-top hex.
## @param size: float - Distance from center to corner.
## @return float - Total width of the hex.
static func get_hex_width(size: float) -> float:
	return size * 2.0


## Gets the height of a flat-top hex.
## @param size: float - Distance from center to corner.
## @return float - Total height of the hex.
static func get_hex_height(size: float) -> float:
	return size * SQRT3


## Gets the horizontal distance between hex centers in a row.
## @param size: float - Hex size.
## @return float - Horizontal spacing.
static func get_horizontal_spacing(size: float) -> float:
	return size * 1.5


## Gets the vertical distance between hex centers in a column.
## @param size: float - Hex size.
## @return float - Vertical spacing.
static func get_vertical_spacing(size: float) -> float:
	return size * SQRT3

# =============================================================================
# NEIGHBOR AND DISTANCE CALCULATIONS
# =============================================================================

## Gets the axial coordinates of all six neighbors of a hex.
## @param axial: Vector2i - Center hex coordinates.
## @return Array[Vector2i] - Coordinates of all six neighbors.
static func get_neighbors(axial: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction in AXIAL_DIRECTIONS:
		neighbors.append(axial + direction)
	return neighbors


## Gets the neighbor in a specific direction.
## @param axial: Vector2i - Center hex coordinates.
## @param direction_index: int - Index 0-5 (see AXIAL_DIRECTIONS).
## @return Vector2i - Neighbor coordinates.
static func get_neighbor(axial: Vector2i, direction_index: int) -> Vector2i:
	return axial + AXIAL_DIRECTIONS[direction_index % 6]


## Calculates the distance between two hexes (in hex steps).
## @param a: Vector2i - First hex axial coordinates.
## @param b: Vector2i - Second hex axial coordinates.
## @return int - Number of hex steps between a and b.
##
## FORMULA: Using cube coordinates, distance = (|dx| + |dy| + |dz|) / 2
## Or equivalently: max(|dq|, |dr|, |ds|) where s = -q - r
static func distance(a: Vector2i, b: Vector2i) -> int:
	var cube_a := axial_to_cube(a)
	var cube_b := axial_to_cube(b)
	
	return int(
		(abs(cube_a.x - cube_b.x) + 
		 abs(cube_a.y - cube_b.y) + 
		 abs(cube_a.z - cube_b.z)) / 2
	)


## Gets all hexes within a certain range of a center hex.
## @param center: Vector2i - Center hex coordinates.
## @param range_val: int - Maximum distance from center.
## @return Array[Vector2i] - All hexes within range (including center).
static func get_hexes_in_range(center: Vector2i, range_val: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	
	for q in range(-range_val, range_val + 1):
		for r in range(max(-range_val, -q - range_val), min(range_val, -q + range_val) + 1):
			results.append(center + Vector2i(q, r))
	
	return results


## Gets all hexes forming a ring at exactly the given distance.
## @param center: Vector2i - Center hex coordinates.
## @param radius: int - Distance from center.
## @return Array[Vector2i] - All hexes at exactly this distance.
static func get_hex_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]
	
	var results: Array[Vector2i] = []
	
	# Start at the hex radius steps in direction 4 (southwest)
	var current := center + AXIAL_DIRECTIONS[4] * radius
	
	# Walk around the ring
	for i in range(6):
		for _j in range(radius):
			results.append(current)
			current = get_neighbor(current, i)
	
	return results

# =============================================================================
# LINE DRAWING
# =============================================================================

## Gets all hexes along a line between two hexes.
## @param a: Vector2i - Start hex.
## @param b: Vector2i - End hex.
## @return Array[Vector2i] - All hexes the line passes through.
##
## Uses linear interpolation in cube space and rounds to nearest hex.
static func get_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n := distance(a, b)
	if n == 0:
		return [a]
	
	var results: Array[Vector2i] = []
	
	# Nudge to handle edge cases where line passes through hex corners
	var a_nudge := Vector2(float(a.x) + 1e-6, float(a.y) + 1e-6)
	var b_nudge := Vector2(float(b.x) + 1e-6, float(b.y) + 1e-6)
	
	for i in range(n + 1):
		var t := float(i) / float(n)
		var interpolated := a_nudge.lerp(b_nudge, t)
		results.append(axial_round(interpolated))
	
	return results

# =============================================================================
# MAP BOUNDS HELPERS
# =============================================================================

## Checks if axial coordinates are within rectangular bounds.
## @param axial: Vector2i - Coordinates to check.
## @param map_width: int - Map width in hexes.
## @param map_height: int - Map height in hexes.
## @return bool - True if coordinates are valid.
static func is_valid_coord(axial: Vector2i, map_width: int, map_height: int) -> bool:
	var offset := axial_to_offset(axial)
	return offset.x >= 0 and offset.x < map_width and offset.y >= 0 and offset.y < map_height


## Gets the pixel bounds of a hex map.
## @param map_width: int - Map width in hexes.
## @param map_height: int - Map height in hexes.
## @param hex_size: float - Size of each hex.
## @return Rect2 - Bounding rectangle in pixels.
static func get_map_pixel_bounds(map_width: int, map_height: int, hex_size: float) -> Rect2:
	# Calculate the position of the last hex in each direction
	var max_offset := Vector2i(map_width - 1, map_height - 1)
	var max_axial := offset_to_axial(max_offset)
	var max_pixel := axial_to_pixel(max_axial, hex_size)
	
	# Add padding for hex radius
	var width := max_pixel.x + hex_size * 2
	var height := max_pixel.y + hex_size * SQRT3
	
	# Account for offset in odd columns
	height += hex_size * SQRT3 * 0.5
	
	return Rect2(
		-hex_size,  # Start slightly before origin
		-hex_size * SQRT3 * 0.5,
		width + hex_size,
		height + hex_size * SQRT3 * 0.5
	)
