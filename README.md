# AtomUni (Atomware Universal Script)

Universal Roblox script suite powered by the Atomware UI & Runtime Framework.

## Module Structure

- **`init.lua`**: Universal master initializer. Automatically detects platform (PC vs Mobile) and directs to the proper UI and backend. Blocks Trident Survival with a prompt directing users to the dedicated Trident Survival script.
- **`main_ui.lua`**: Desktop & Xbox Controller UI Framework featuring two-column responsive layout, theme engine, and gamepad navigation.
- **`mobile_ui.lua`**: Mobile & Tablet UI Framework with draggable floating control button, responsive columns, and touch-optimized navigation.
- **`features.lua`**: Universal Visuals Engine (Phase 1):
  - **Player ESP**: 2D Boxes, Corner Boxes, Health Bars, Display Names, Distance, Tool Detection, and Tracers.
  - **Rig Detection**: Dynamic R15 and R6 bounding box and body part detection.
  - **Material Chams**: Dynamic material presets (`ForceField`, `Neon`, `Glass`, `Ice`, `Marble`, `Foil`, `Metal`, `Wood`) with tinting, see-through glow outline, and team check.
  - **Chinese Hat ESP**: 3D wireframe conical hat atop player heads with optional rotation and segment customization.
  - **Dual-Engine Rendering**: Native Drawing API with automatic ScreenGui fallback for mobile/unsupported executors.
- **`config.lua`**: Shared configuration manager, profile persistence, keybind handling, and notification system.
- **`cleanup.lua`**: Central resource tracker ensuring leak-free unloads and thread cancellation.

## Testing Loader

To load directly in an executor:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/redisaac758-art/AtomUni/main/init.lua"))()
```
