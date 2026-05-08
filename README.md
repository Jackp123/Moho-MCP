# MohoMCP

An MCP (Model Context Protocol) server for **Moho Pro 14** — enabling AI assistants like Claude Desktop and Claude Code to read, write, animate, and visually operate MOHO animation projects.

**Fully cross-platform: Windows and macOS.**

## Architecture

```
┌─────────────────────┐    File-based IPC     ┌──────────────────────┐
│  MCP Bridge Server  │◄──────────────────►   │  Moho Lua Plugin     │
│  (TypeScript/Node)  │  $TMPDIR/moho-mcp/    │  (runs inside MOHO)  │
└────────┬────────────┘   JSON-RPC 2.0        └──────────────────────┘
         │ MCP Protocol (stdio)
┌────────▼────────────┐
│  MCP Client/Host    │
│  (Claude Desktop,   │
│   Claude Code, etc) │
└─────────────────────┘
```

**Three components:**

1. **Moho Lua Plugin** — File-based IPC server running inside MOHO, handles read/write operations via MOHO's Lua 5.4 API
2. **MCP Bridge Server** — Node.js process bridging MCP protocol (stdio) to file-based JSON-RPC
3. **Static Knowledge Resources** — Keyboard shortcuts and tool reference data from the Moho manual

## Capabilities

| Capability | Description |
|------------|-------------|
| **Read** | Query document structure, layers, bones, animation keyframes, mesh data, curves, actions |
| **Write** | Set bone/layer transforms, create/delete keyframes, change interpolation, rename layers |
| **Create** | Create new layers, bones, mesh points, shapes, smart-bone dials; save the document |
| **Rig** | Curvature & bezier handles for smooth shapes, mesh-point/layer bone binding, smart-bone actions, reparent/reorder layers |
| **Cinematics** | Animate the camera (track, pan/tilt, roll, zoom) and layer effects (blur, drop shadow, outline) |
| **Particles** | Configure particle-layer emitters: count, lifetime, velocity, direction, acceleration |
| **History** | Undo / redo |
| **See** | Capture rendered scene frames or full MOHO UI screenshots |
| **Interact** | Send mouse clicks, drags, and keyboard shortcuts to the MOHO window |
| **Know** | Built-in reference data for all Moho 14 tools and keyboard shortcuts |

## Available Tools (51)

### Read-Only Tools

| Tool | Description |
|------|-------------|
| `document_getInfo` | Document metadata (name, path, dimensions, FPS, frame range) |
| `document_getLayers` | Full layer tree with hierarchy |
| `layer_getProperties` | Detailed layer properties (type, visibility, transform) |
| `layer_getChildren` | Direct children of a group layer |
| `layer_getBones` | List bones in a bone layer |
| `bone_getProperties` | Bone details (position, angle, scale, parent) |
| `animation_getKeyframes` | Keyframes for a channel on a layer |
| `animation_getFrameState` | Full layer state at a specific frame |
| `mesh_getPoints` | Point positions in a vector layer |
| `mesh_getShapes` | Shape data (fill, stroke, curves) |

### Write Tools

| Tool | Description |
|------|-------------|
| `bone_setTransform` | Set bone angle/position/scale at a frame (creates keyframes) |
| `bone_selectBone` | Select a bone in the MOHO UI |
| `animation_setKeyframe` | Set keyframe value (scalar or vec2) on any channel |
| `animation_deleteKeyframe` | Remove a keyframe at a specific frame |
| `animation_setInterpolation` | Set easing mode (linear, smooth, ease_in, ease_out, step) |
| `document_setFrame` | Navigate to a specific frame on the timeline |
| `layer_setTransform` | Set layer translation/rotation/scale at a frame |
| `layer_setVisibility` | Show or hide a layer |
| `layer_setOpacity` | Set layer transparency at a frame |
| `layer_setName` | Rename a layer |
| `layer_selectLayer` | Select a layer in the UI |

### Create Tools

| Tool | Description |
|------|-------------|
| `layer_createLayer` | Create a new layer (vector, group, bone, switch, image, particle, note, patch, audio); optional name and parent group |
| `layer_deleteLayer` | Delete a layer from the document |
| `bone_addBone` | Add a new bone to a bone layer's skeleton with optional rest-pose properties |
| `bone_deleteBone` | Remove a bone from a skeleton |
| `bone_setRestPose` | Edit a bone's rest-pose (position, angle, length, scale, parent, name) |
| `mesh_addPoint` | Add a new mesh point (vertex) to a vector layer |
| `mesh_createShape` | Create a new filled/stroked shape from a list of point indices on a vector layer |
| `document_save` | Save the document; pass `filePath` for Save As |

> **Tip:** Combine these with `batch_execute` to build whole rigs or scenes in a single round-trip — e.g. add a vector layer, add 4 mesh points, then create the shape, all in one call.

### Rigging Tools

| Tool | Description |
|------|-------------|
| `mesh_setPointCurvature` | Smooth or sharpen a single vertex (positive curvature = smooth, 0 = corner) — essential for hand-drawn-looking shapes |
| `mesh_getCurves` | List a vector layer's curves with mesh-global → curve-local point index mapping |
| `mesh_setBezierHandle` | Direct control of a bezier handle on a curve point |
| `mesh_bindPoints` | Bind mesh points to a bone (or unbind / flexi-bind) so the bone deforms the art |
| `layer_setParentBone` | Set a layer's controlling parent bone (e.g. parent a hand layer to a wrist bone) |
| `layer_placeInGroup` | Reparent a layer into a group |
| `layer_placeBehind` | Reorder layers within a group |
| `layer_activateAction` | Switch into action-edit mode (or back to mainline) — keyframes recorded while active become the action's content |
| `layer_listActions` | List all actions on a layer, marking which are smart-bone dials |
| `bone_createSmartAction` | Create a smart-bone action named after a bone — call `layer_activateAction` next to start recording the dial |

### Camera & Effects

| Tool | Description |
|------|-------------|
| `document_setCamera` | Animate the camera at a frame: 3D track position, pan/tilt/roll (radians), zoom |
| `layer_setBlur` | Animate a layer's blur amount |
| `layer_setShadow` | Animate a drop shadow (offset, blur, angle, color, on/off) |
| `layer_setOutline` | Animate the layer outline (width, color, on/off) |

### Particles

| Tool | Description |
|------|-------------|
| `particle_setEmitter` | Configure a particle layer's emitter (count, lifetime, velocity, direction, acceleration, source dimensions, etc.); auto-finalizes |

### History

| Tool | Description |
|------|-------------|
| `document_undo` | Undo the most recent change |
| `document_redo` | Redo the most recently undone change |

### Visual & Input Tools

| Tool | Description |
|------|-------------|
| `document_screenshot` | Capture scene render or full MOHO UI window as PNG |
| `input_mouseClick` | Click at window-relative coordinates (left/right/middle, single/double) |
| `input_mouseDrag` | Drag from point A to B with configurable steps |
| `input_sendKeys` | Send keyboard shortcuts (e.g. `ctrl+z`, `space`, `a`) |

### Batch Execution

| Tool | Description |
|------|-------------|
| `batch_execute` | Execute multiple operations in a single IPC round-trip (~300ms total vs ~300ms each) |

> **Performance tip:** Always prefer `batch_execute` when you need 2+ operations. A batch of 10 operations takes the same time as 1 individual call.

### Knowledge Resources

| Resource | URI | Description |
|----------|-----|-------------|
| Shortcuts | `moho://shortcuts` | All Moho 14 keyboard shortcuts organized by category |
| Tools | `moho://tools` | All Moho 14 tools with shortcuts, descriptions, and modifiers |

## Quick Start

### 1. Install the MOHO Plugin

Copy the `moho-plugin/` contents into MOHO's scripts folder, or use the provided install scripts:

**Windows:** Run `install-plugin.bat` (or copy manually to `C:\Program Files\Moho 14\Resources\Support\Scripts\Menu\`)

**macOS:** Run `chmod +x install-plugin.sh && ./install-plugin.sh` (or copy manually to `/Applications/Moho 14/Moho Pro.app/Contents/Resources/Support/Scripts/Menu/`)

Files to copy:
- `MohoMCP_Server.lua`
- `MohoMCP_Poller.lua`
- `json.lua`
- `moho_mcp/` (entire directory)

### 2. Build the Bridge Server

```bash
cd bridge
npm install
npm run build
```

### 3. Start Everything

1. Open **Moho Pro 14** and load a project
2. Go to **Scripts > MohoMCP Server** to start the IPC server
3. Start your MCP client (Claude Desktop or Claude Code) — the bridge auto-connects

### 4. Configure Claude Desktop

Add to your Claude Desktop config (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "moho-mcp": {
      "command": "node",
      "args": ["C:/path/to/MohoMCP/bridge/dist/index.js"]
    }
  }
}
```

### 5. Configure Claude Code

Place a `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "moho-mcp": {
      "command": "node",
      "args": ["C:/path/to/MohoMCP/bridge/dist/index.js"]
    }
  }
}
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `MOHO_MCP_IPC_DIR` | `<system-temp>/moho-mcp` | Directory for file-based IPC communication |

Internal timing (in `bridge/src/config.ts`):

| Setting | Default | Description |
|---------|---------|-------------|
| Poll interval | 100ms | How often the bridge checks for response files |
| Request timeout | 10s | Max wait time for a Lua response |
| Render timeout | 30s | Max wait time for screenshot operations |
| Batch timeout per op | 500ms | Additional timeout per operation in a batch |
| Max batch size | 50 | Maximum operations per `batch_execute` call |

## How It Works

### File-Based IPC

Communication uses JSON files in the system temp directory (`%TEMP%\moho-mcp\` on Windows, `$TMPDIR/moho-mcp/` on macOS):

1. Bridge writes `req_<id>.json` (JSON-RPC 2.0 request)
2. MOHO Lua plugin polls for request files via DrawMe/IsEnabled callbacks
3. Lua processes the request, writes `resp_<id>.json`
4. Bridge reads the response, cleans up files

### Keep-Alive Mechanism

MOHO only processes Lua callbacks during UI repaints. A background process periodically forces viewport redraws (~4 Hz) to keep the polling loop alive even when the user isn't interacting:
- **Windows:** PowerShell process calling Win32 `RedrawWindow()`
- **macOS:** AppleScript process nudging the Moho application

### Security

- **Allow-list validation**: Only explicitly registered methods can be called
- **Parameter validation**: All parameters type-checked before execution
- **pcall wrapping**: All Lua handlers wrapped in protected calls — a crash in one method won't crash the server

## Development

```bash
cd bridge
npm install
npm run dev      # Watch mode — recompiles on changes
npm test         # Run test suite (61 tests)
npm run test:watch
```

### Project Structure

```
MohoMCP/
├── bridge/                    # TypeScript MCP Bridge Server
│   └── src/
│       ├── index.ts           # Entry point & bootstrap
│       ├── config.ts          # IPC directory, timeouts
│       ├── moho-client.ts     # File-based IPC client
│       ├── protocol.ts        # JSON-RPC 2.0 types
│       ├── tools.ts           # 51 MCP tool registrations
│       ├── resources.ts       # Static knowledge resources
│       ├── keep-alive.ts      # Cross-platform viewport refresh
│       ├── platform-capture.ts # Platform dispatch → window capture
│       ├── platform-input.ts  # Platform dispatch → input simulation
│       ├── window-capture.ts  # Win32 screenshot capture
│       ├── darwin-capture.ts  # macOS screenshot capture
│       ├── win32-input.ts     # Win32 mouse & keyboard
│       ├── darwin-input.ts    # macOS mouse & keyboard
│       └── __tests__/         # Vitest test suite
│
├── moho-plugin/               # Lua Plugin for MOHO 14
│   ├── MohoMCP_Server.lua     # Menu script & DrawMe hooks
│   ├── MohoMCP_Poller.lua     # Polling utilities
│   ├── json.lua               # JSON library
│   └── moho_mcp/
│       ├── server.lua         # File-based IPC server
│       ├── protocol.lua       # JSON-RPC 2.0 protocol
│       ├── validator.lua      # Method allow-list & validation
│       └── tools/             # Handler implementations
│           ├── document.lua
│           ├── layer.lua
│           ├── bone.lua
│           ├── animation.lua
│           ├── mesh.lua
│           ├── particle.lua
│           └── batch.lua
│
├── docs/                      # Documentation
│   ├── installation.md
│   └── tool-reference.md
│
└── schema/
    └── tools.json             # JSON Schema definitions
```

## Creating Content from Claude

Once the MCP server is connected, Claude can build scenes from scratch. A typical "create" flow:

1. `layer_createLayer { type: "vector", name: "Body" }` → returns a new `layerId`
2. `mesh_addPoint { layerId, x: -100, y: -100 }` four times to drop a quad's corners
3. `mesh_createShape { layerId, pointIndices: [0,1,2,3], fillColor: "#FF8800" }`
4. `layer_createLayer { type: "bone", name: "Skeleton" }` → new bone layer id
5. `bone_addBone { layerId: <bone-layer>, name: "Root", length: 100 }`
6. `bone_setTransform { ..., frame: 24, angle: 1.57 }` to keyframe the rotation
7. `document_save { filePath: "C:/projects/scene.moho" }` to persist the work

Wrap multiple create calls in `batch_execute` so a whole rig can be built in one round-trip.

## Platform Support

All 51 tools work identically on both platforms. The bridge auto-detects the OS at runtime and loads the appropriate native backend — no configuration needed.

| Feature | Windows | macOS |
|---------|---------|-------|
| Read tools (document, layers, bones, mesh) | Win32 file IPC | POSIX file IPC |
| Write tools (transforms, keyframes) | Win32 file IPC | POSIX file IPC |
| Scene screenshot (`mode="scene"`) | Moho FileRender | Moho FileRender |
| Full UI screenshot (`mode="full"`) | Win32 PrintWindow API | `screencapture -l` |
| Mouse input (click, drag) | Win32 user32.dll P/Invoke | cliclick / CoreGraphics via JXA |
| Keyboard input | Win32 keybd_event | AppleScript System Events |
| Keep-alive (viewport refresh) | PowerShell + RedrawWindow | AppleScript process nudge |
| Plugin installer | `install-plugin.bat` | `install-plugin.sh` |

### Windows Requirements

- **Windows 10/11**
- **Moho Pro 14**
- **Node.js** >= 18.0.0

### macOS Requirements

- **macOS** (tested on Ventura+)
- **Moho Pro 14**
- **Node.js** >= 18.0.0
- **Accessibility permissions** — required for input simulation (System Settings > Privacy & Security > Accessibility > add your terminal / Claude Desktop)
- **cliclick** (optional, recommended) — `brew install cliclick` — provides more reliable mouse input. Without it, falls back to CoreGraphics via JXA.

## License

MIT — see [LICENSE](LICENSE) for details.

## References

- **Official Moho Lua API docs** — https://www.mohoscripting.com — authoritative reference for `MohoDoc`, `M_Skeleton`, `M_Mesh`, `M_Bone`, and related classes used by the Lua plugin.
