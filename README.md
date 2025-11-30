# Hex RPG - Week 1-2 Implementation

A hex-based exploration RPG foundation built in Godot 4.5 using GDScript.

## Project Structure

```
hex_rpg/
├── assets/
│   └── images/
│       ├── actors/          # Character sprites (future)
│       ├── maps/            # Terrain textures (optional)
│       └── ui/              # UI elements (future)
├── data/
│   ├── actors/              # Actor JSON configs (future)
│   ├── maps/                # Map configuration files
│   │   ├── default.json     # Default 30x30 map config
│   │   └── test_small.json  # Small 10x10 test map
│   ├── regions/             # Region data (future)
│   └── combat/              # Combat configs (future)
├── scenes/
│   └── maps/
│       └── main.tscn        # Main game scene
├── scripts/
│   ├── autoloads/
│   │   ├── event_bus.gd     # Global signal bus
│   │   └── data_loader.gd   # JSON data loading
│   ├── maps/
│   │   ├── hex_utils.gd     # Coordinate math utilities
│   │   ├── hex_cell.gd      # Individual hex representation
│   │   ├── hex_grid.gd      # Grid management
│   │   └── map_camera.gd    # Camera controls
│   └── ui/
│       └── debug_display.gd # Debug overlay
├── project.godot            # Godot project file
├── icon.svg                 # Project icon
└── README.md                # This file
```

## Setup Instructions

### 1. Open in Godot 4.5

1. Open Godot 4.5
2. Click "Import" and navigate to the `hex_rpg` folder
3. Select `project.godot` and click "Import & Edit"

### 2. Verify Autoloads

The autoloads should be configured automatically, but verify in:
**Project → Project Settings → Autoload**

You should see:
- `EventBus` → `res://scripts/autoloads/event_bus.gd`
- `DataLoader` → `res://scripts/autoloads/data_loader.gd`

### 3. Run the Project

Press F5 or click the Play button. You should see:
- A 30x30 hex grid rendered with green (grass) hexes
- The camera centered on the map
- Debug overlay in the top-left corner

## Controls

| Input | Action |
|-------|--------|
| **Left Click** | Select a hex |
| **Middle/Right Mouse + Drag** | Pan the camera |
| **Mouse Wheel** | Zoom in/out |
| **F3** | Toggle debug display |
| **F4** | Toggle hex coordinate labels |

## Features Implemented

### ✅ Hex Grid Rendering
- Flat-top hexagon orientation
- Configurable grid size (default 30x30)
- Colored Polygon2D rendering with fallback
- Support for terrain texture sprites (place PNGs in `assets/images/maps/`)

### ✅ Coordinate System
- **Axial coordinates** (q, r) - Primary system
- **Cube coordinates** (x, y, z) - For distance/algorithms
- **Offset coordinates** (col, row) - For map bounds
- **Pixel coordinates** - For rendering

Key utilities in `HexUtils`:
```gdscript
# Convert between coordinate systems
var pixel = HexUtils.axial_to_pixel(axial_coords, hex_size)
var axial = HexUtils.pixel_to_axial(pixel_pos, hex_size)
var offset = HexUtils.axial_to_offset(axial_coords)

# Get neighbors and distance
var neighbors = HexUtils.get_neighbors(axial_coords)
var dist = HexUtils.distance(hex_a, hex_b)

# Get hexes in range
var area = HexUtils.get_hexes_in_range(center, radius)
```

### ✅ Camera System
- Smooth zoom with mouse wheel
- Click-and-drag panning
- Configurable zoom limits (0.25x to 2.0x)
- Map boundary constraints
- Optional edge panning

### ✅ Hex Selection
- Click to select hexes
- Visual highlight (yellow border)
- Hover highlighting (white)
- Signals emitted via EventBus

### ✅ Debug Display
- FPS counter
- Camera position and zoom level
- Hovered hex coordinates
- Selected hex information
- Terrain type display
- Toggleable hex coordinate labels

## Architecture

### Signal Flow

All cross-system communication uses the EventBus:

```gdscript
# Emitting signals
EventBus.hex_selected.emit(coords)
EventBus.camera_zoomed.emit(zoom_level)

# Connecting to signals
EventBus.hex_selected.connect(_on_hex_selected)
```

### Data Loading

Configuration is loaded via DataLoader:

```gdscript
# Load map config
var config = DataLoader.load_map_config("default")

# Access terrain data
var terrain = config["terrain_types"]["grass"]
var color = terrain["color"]  # "#4a7c59"
var move_cost = terrain["movement_cost"]  # 1.0
```

### HexGrid API

```gdscript
# Access cells
var cell = hex_grid.get_cell(Vector2i(5, 3))
var cell_at_pixel = hex_grid.get_cell_at_pixel(mouse_pos)

# Selection
hex_grid.select_hex(coords)
hex_grid.deselect()
var selected = hex_grid.get_selected_cell()

# Terrain modification
hex_grid.set_terrain(coords, "water")

# Queries
var water_cells = hex_grid.get_cells_by_terrain("water")
var neighbors = hex_grid.get_neighbors(coords)
```

## Configuration

### Map Configuration (JSON)

Edit `data/maps/default.json`:

```json
{
  "map_name": "default",
  "map_size": {"width": 30, "height": 30},
  "hex_size": 64,
  "default_terrain": "grass",
  "terrain_types": {
    "grass": {
      "color": "#4a7c59",
      "movement_cost": 1.0,
      "passable": true
    }
  }
}
```

### Using a Different Map

In the scene, change the HexGrid's `config_file` property:
```gdscript
# In main.tscn or via code:
hex_grid.config_file = "test_small"
```

### Adding Terrain Textures

1. Create PNG images for each terrain type
2. Name them `{terrain_type}.png` (e.g., `grass.png`, `water.png`)
3. Place in `assets/images/maps/`
4. The HexCell will automatically use textures if found

## Extending the System

### Adding New Terrain Types

1. Add to your map JSON:
```json
"terrain_types": {
  "lava": {
    "color": "#ff4400",
    "movement_cost": -1,
    "passable": false,
    "description": "Deadly lava"
  }
}
```

2. Optionally add `lava.png` to `assets/images/maps/`

### Custom Hex Data

```gdscript
var cell = hex_grid.get_cell(coords)
cell.custom_data["encounter_id"] = "goblin_camp"
cell.custom_data["loot_table"] = "forest_common"
```

### Listening to Events

```gdscript
func _ready():
    EventBus.hex_selected.connect(_on_hex_selected)
    EventBus.terrain_changed.connect(_on_terrain_changed)

func _on_hex_selected(coords: Vector2i):
    print("Selected hex at: ", coords)
```

## Future Expansion Points

The codebase is designed for easy extension:

- **Procedural Generation (Week 3-4)**: Add generation algorithms that call `hex_grid.set_terrain()`
- **Fog of War**: Add visibility state to HexCell, emit `fog_revealed` signal
- **Pathfinding**: Use `HexUtils.get_neighbors()` and terrain movement costs
- **Encounters**: Use `cell.custom_data` and `encounter_triggered` signal
- **Save/Load**: Serialize cell terrain and custom_data to JSON

## Troubleshooting

### Hexes not rendering
- Ensure autoloads are configured
- Check console for JSON parsing errors
- Verify `default.json` exists in `data/maps/`

### Camera not working
- Ensure MapCamera is in the scene
- Check that it's added to the "map_camera" group
- Verify mouse input is not blocked by UI

### Signals not firing
- Verify EventBus autoload is active
- Check signal connections in `_ready()`
- Use `print()` statements to debug

## Credits

Built following Godot 4.5 best practices with:
- Axial coordinate system (Red Blob Games reference)
- Signal-based architecture
- Data-driven configuration
