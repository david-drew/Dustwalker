# Hex RPG - Week 1-2 Implementation

A hex-based exploration RPG foundation built in Godot 4.5 using GDScript.

## Project Structure

```
hex_rpg/
├── assets/
│   └── images/
│       ├── actors/              # Character sprites (future)
│       ├── maps/
│       │   └── terrain/         # Terrain textures (optional)
│       └── ui/                  # UI elements (future)
├── data/
│   ├── actors/                  # Actor JSON configs (future)
│   ├── maps/
│   │   ├── default.json         # Default 30x30 map config
│   │   ├── terrain_config.json  # Terrain generation config
│   │   └── test_small.json      # Small 10x10 test map
│   ├── regions/                 # Region data (future)
│   └── combat/                  # Combat configs (future)
├── scenes/
│   └── maps/
│       └── main.tscn            # Main game scene
├── scripts/
│   ├── autoloads/
│   │   ├── event_bus.gd         # Global signal bus
│   │   └── data_loader.gd       # JSON data loading
│   ├── maps/
│   │   ├── hex_utils.gd         # Coordinate math utilities
│   │   ├── hex_cell.gd          # Individual hex representation
│   │   ├── hex_grid.gd          # Grid management
│   │   ├── map_camera.gd        # Camera controls
│   │   └── terrain_generator.gd # Procedural terrain generation
│   └── ui/
│       ├── debug_display.gd     # Debug overlay
│       └── generation_panel.gd  # Terrain generation UI
├── project.godot                # Godot project file
├── icon.svg                     # Project icon
└── README.md                    # This file
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
- A 30x30 hex grid with procedurally generated terrain
- Multiple terrain types (water, plains, forest, mountains, etc.)
- The camera centered on the map
- Debug overlay in the top-left corner

## Controls

| Input | Action |
|-------|--------|
| **Left Click** | Select a hex |
| **Middle/Right Mouse + Drag** | Pan the camera |
| **Mouse Wheel** | Zoom in/out |
| **G** | Open terrain generation panel |
| **F3** | Toggle debug display |
| **F4** | Toggle hex coordinate labels |
| **Escape** | Close generation panel |

## Features Implemented

### ✅ Week 1: Hex Grid Foundation

#### Hex Grid Rendering
- Flat-top hexagon orientation
- Configurable grid size (default 30x30)
- Colored Polygon2D rendering with fallback
- Support for terrain texture sprites (place PNGs in `assets/images/maps/terrain/`)

#### Coordinate System
- **Axial coordinates** (q, r) - Primary system
- **Cube coordinates** (x, y, z) - For distance/algorithms
- **Offset coordinates** (col, row) - For map bounds
- **Pixel coordinates** - For rendering

#### Camera System
- Smooth zoom with mouse wheel
- Click-and-drag panning
- Configurable zoom limits (0.25x to 2.0x)
- Map boundary constraints

#### Hex Selection
- Click to select hexes
- Visual highlight (yellow border)
- Hover highlighting (white)

### ✅ Week 2: Procedural Terrain Generation

#### Elevation & Moisture Maps
- FastNoiseLite (Simplex) noise for natural terrain
- Configurable noise parameters (scale, octaves, persistence, lacunarity)
- Separate elevation and moisture layers
- Seed-based generation (same seed = identical map)

#### Terrain Types
The terrain system uses non-overlapping elevation/moisture ranges:

| Terrain | Elevation | Moisture | Color |
|---------|-----------|----------|-------|
| Deep Water | 0.0-0.2 | Any | Dark Blue |
| Shallow Water | 0.2-0.3 | Any | Blue |
| Swamp | 0.3-0.38 | 0.65-1.0 | Murky Green |
| Desert | 0.3-0.6 | 0.0-0.25 | Sandy Tan |
| Plains | 0.3-0.55 | 0.25-0.55 | Light Green |
| Grassland | 0.38-0.55 | 0.55-0.65 | Green |
| Forest | 0.38-0.6 | 0.65-1.0 | Dark Green |
| Badlands | 0.55-0.7 | 0.0-0.35 | Dusty Brown |
| Hills | 0.55-0.7 | 0.35-0.6 | Olive |
| Forest Hills | 0.6-0.75 | 0.5-1.0 | Medium Green |
| Highlands | 0.7-0.8 | 0.0-0.5 | Gray |
| Mountains | 0.8-0.92 | Any | Gray-Brown |
| Mountain Peak | 0.92-1.0 | Any | Snow White |

#### Color Variation
Each hex gets subtle color variation based on its elevation/moisture values:
- **Brightness**: Adjusted by elevation within terrain range
- **Saturation**: Adjusted by moisture within terrain range  
- **Hue**: Subtle shift for visual diversity

#### Terrain Smoothing
Post-processing removes isolated single-hex terrain patches:
- Hexes surrounded by 4+ neighbors of a different terrain are smoothed
- Water and mountains are protected from smoothing
- Terrain transitions validated against elevation to maintain realism

#### Generation UI
Press **G** to open the generation panel:
- Enter a specific seed or leave empty for random
- "Generate with Seed" - Uses entered seed
- "Generate Random" - New random seed
- "Regenerate (Same Seed)" - Reproduce current map
- Live terrain statistics display

### ✅ Debug Display
- FPS counter
- Camera position and zoom level
- Hovered hex coordinates
- Selected hex information (terrain, elevation, moisture)
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

# Procedural Generation (Week 2)
hex_grid.generate_procedural_terrain(12345)  # With specific seed
hex_grid.regenerate_with_new_seed()          # Random seed
hex_grid.regenerate_with_same_seed()         # Reproduce current map

# Terrain statistics
var stats = hex_grid.get_terrain_statistics()  # {terrain_name: count}
var avg_elev = hex_grid.get_average_elevation()
var high_cells = hex_grid.get_cells_by_elevation(0.7, 1.0)
```

### HexCell Properties (Week 2)

```gdscript
# Terrain data
cell.terrain_type   # String: "forest", "water", etc.
cell.elevation      # float: 0.0 to 1.0
cell.moisture       # float: 0.0 to 1.0
cell.terrain_color  # Color: with variation applied

# Gameplay helpers
cell.is_passable()       # bool
cell.get_movement_cost() # float (-1 = impassable)
cell.get_terrain_data()  # Dictionary with all terrain info
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

### Terrain Generation Configuration (JSON)

Edit `data/maps/terrain_config.json`:

```json
{
  "generation": {
    "seed": 0,
    "auto_seed": true,
    "elevation": {
      "scale": 0.045,
      "octaves": 4,
      "persistence": 0.5,
      "lacunarity": 2.0
    },
    "moisture": {
      "scale": 0.06,
      "octaves": 3,
      "persistence": 0.5,
      "lacunarity": 2.0
    },
    "smoothing": {
      "enabled": true,
      "neighbor_threshold": 4,
      "iterations": 1,
      "protect_water": true,
      "protect_mountains": true
    }
  },
  "terrain_types": {
    "plains": {
      "color": "#7bae5a",
      "elevation_min": 0.3,
      "elevation_max": 0.55,
      "moisture_min": 0.25,
      "moisture_max": 0.55,
      "priority": 4,
      "movement_cost": 1.0,
      "passable": true
    }
  },
  "color_variation": {
    "enabled": true,
    "brightness_range": 0.12,
    "saturation_range": 0.08,
    "hue_range": 0.02
  }
}
```

**Noise Parameters:**
- `scale`: Smaller = larger terrain features (default: 0.045 for elevation)
- `octaves`: More = more detail/roughness (default: 4)
- `persistence`: How much each octave contributes (default: 0.5)
- `lacunarity`: Frequency multiplier between octaves (default: 2.0)

### Using a Different Map

In the scene, change the HexGrid's `config_file` property:
```gdscript
# In main.tscn or via code:
hex_grid.config_file = "test_small"
hex_grid.terrain_config_file = "terrain_config"
hex_grid.use_procedural_generation = true
```

### Adding Terrain Textures

1. Create PNG images for each terrain type
2. Name them `{terrain_type}.png` (e.g., `plains.png`, `water.png`)
3. Place in `assets/images/maps/terrain/`
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
