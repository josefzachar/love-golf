# Cellular Golf

A 2D golf game with cellular automaton physics, inspired by games like Noita. This game features a sand simulation with various materials that interact with each other in a physically realistic way.

## Features

- Cellular automaton physics simulation
- GPU-accelerated rendering for performance
- Multiple material types with unique behaviors:
  - Solids (stone, dirt)
  - Particles (sand)
  - Liquids (water)
  - Energy (fire)
- Multiple golf ball types with special abilities:
  - Standard ball
  - Explosive ball (like a grenade)
  - Sticky ball (adheres to surfaces)
  - Mining ball (can dig through materials)
- Interactive level editor
- Pixel-perfect collision detection
- Smooth camera controls

## Controls

### Game Controls
- **Left Mouse Button**: Place material
- **Right Mouse Button**: Pan camera
- **Middle Mouse Button**: Cycle through materials
- **Arrow Keys/WASD**: Move camera
- **+/-**: Zoom in/out
- **Space**: Use ball ability
- **Escape**: Pause/Resume game
- **F3**: Toggle debug mode
- **R**: Restart current level
- **Page Up/Down**: Increase/decrease simulation speed

### Material Selection
- **1**: Select Sand
- **2**: Select Water
- **3**: Select Fire
- **4**: Select Stone
- **5**: Select Dirt

### Brush Controls
- **[**: Decrease brush size
- **]**: Increase brush size
- **Ctrl+C**: Clear all cells

## Material Behaviors

- **Sand**: Falls down and piles up realistically. Can displace water.
- **Water**: Flows downward and spreads horizontally. Can be displaced by heavier materials.
- **Fire**: Rises upward and has a chance to burn out, creating smoke.
- **Stone**: Solid, immovable material that forms the level structure.
- **Dirt**: Solid material that can be destroyed by certain ball types.

## Development

This game is built using the LÖVE framework (https://love2d.org/), a free 2D game engine for Lua.

### Project Structure

- `main.lua`: Entry point for the game
- `conf.lua`: LÖVE configuration
- `src/`: Source code directory
  - `balls/`: Ball types and behavior
  - `cells/`: Cellular automaton implementation
  - `levels/`: Level definitions
  - `shaders/`: GLSL shaders for GPU acceleration

### Performance Optimization

The cellular simulation is optimized to run efficiently:
- GPU-accelerated rendering using GLSL shaders
- Double-buffering technique for cell updates
- Spatial partitioning for collision detection
- Optimized update loop that prioritizes active cells

## License

This project is licensed under the MIT License - see the LICENSE file for details.
