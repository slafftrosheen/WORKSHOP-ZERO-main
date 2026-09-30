# Workshop Zero - Asset Wishlist

> [!IMPORTANT]
> **Core Architecture Rules:**
> - **Visual assets are replaceable skins over stable Workshop Zero physics contracts.**
> - **Missing art must never make an experiment unplayable.**

This wishlist defines the production asset queue for Hyper3D generation and Blender cleanup. The game remains 100% playable using procedural primitives when any or all of these models are absent.

Shared visual direction for every asset:

```text
warm workshop, chunky geometry, toy-like proportions
big readable silhouettes, minimal small detail
handmade rather than industrial, friendly rather than realistic
clean topology, low polygon count, no text, no logos, isolated single objects
```

---

## Priority Structure

- **P0**: Core character, level objective, and primary power unit (`Duck`, `GoalButton`, `Motor`).
- **P1**: Essential kinetic and structural construction components (`Wheel`, `Plank`, `Block`, `Spring`, `Fan`).
- **P2**: Workshop environment props and dressing (`Workbench`, `ToolRack`, `Shelving`).

---

## Priority 0 Asset Queue (Core Experience)

### P0-01 Rubber Duck [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/duck_rubber_01/`
- **Blender Source**: `assets/source/blender/duck_rubber_01.blend`
- **Roblox Export**: `assets/export/roblox/duck_rubber_01.glb`
- **Purpose**: The star and payload of Workshop Zero. Transported by player machines to trigger the goal.
- **Roblox Size**: `2.5 × 2.0 × 3.0` studs (matches payload volume).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Payloads.Duck`
- **Visual Requirements**: Recognisably yellow, rounded exaggerated silhouette, friendly simple face, oversized head, clean broad surfaces, slightly handmade workshop-toy character.
- **What NOT to Model**: Do NOT model collision meshes, interior hollows, or stands/pedestals. Physics is handled entirely by the authoritative invisible/primitive payload collider.
- **Hyper3D Prompt**:
  ```text
  Stylized chunky yellow rubber duck toy for a family-friendly physics construction game. Exaggerated rounded silhouette, friendly simple face, oversized head, clean broad surfaces, slightly handmade workshop-toy character, minimal tiny details, no text, no stand, no environment, isolated single object.

  Roblox-friendly low-poly game asset.
  Simple topology.
  Strong silhouette.
  PBR materials.
  No internal geometry.
  No thin fragile pieces.
  ```
- **Blender Cleanup Notes**:
  - Center origin at the bottom base of the duck body.
  - Scale to 2.5 studs wide, 2.0 studs high, 3.0 studs deep.
  - Apply all transformations (`Ctrl+A`).
  - Merge vertices by distance, verify surface normals face outward.
  - Ensure single clean PBR material set.

---

### P0-02 Giant Red Goal Button [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/button_goal_red_01/`
- **Blender Source**: `assets/source/blender/button_goal_red_01.blend`
- **Roblox Export**: `assets/export/roblox/button_goal_red_01.glb`
- **Purpose**: Level objective target. Depressed when the duck contacts it to complete the experiment.
- **Roblox Size**: `4.0 × 1.8 × 4.0` studs base with `3.2 × 0.8 × 3.2` studs plunger cap.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Goals.GoalButton`
- **Visual Requirements**: Oversized comical red mechanical push button. Huge readable red cap, chunky metal base, visible oversized bolts, rounded toy-industrial forms, friendly rather than dangerous, strong silhouette.
- **What NOT to Model**: Do NOT model trigger physics or moving constraint mechanics. The server-owned invisible `GoalTrigger` part remains authoritative for contact detection.
- **Hyper3D Prompt**:
  ```text
  Oversized comical red mechanical push button for a playful maker workshop physics game. Huge readable red cap, chunky metal base, visible oversized bolts, rounded toy-industrial forms, friendly rather than dangerous, strong silhouette, no text, isolated object.

  Stylized Roblox-friendly low-poly game asset.
  PBR materials.
  No environment.
  No tiny mechanical details.
  ```
- **Blender Cleanup Notes**:
  - Model base and cap as clean sub-parts or single unified model with cap centered.
  - Set origin at the bottom center of the mounting base.
  - Keep poly count under 3,000 tris.
  - Assign vibrant red material to cap, matte metallic finish to base.

---

### P0-03 Powered Motor [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/motor_electric_01/`
- **Blender Source**: `assets/source/blender/motor_electric_01.blend`
- **Roblox Export**: `assets/export/roblox/motor_electric_01.glb` (3,500 tris)
- **Purpose**: Electric actuator power plant converting energy into rotation. Mounts rigidly to planks/blocks and drives wheels or fans on powered axles.
- **Roblox Size**: `2.0 × 2.0 × 2.0` studs (matches `ComponentDefinitions.luau` Motor).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Motor`
- **Visual Requirements**: Chunky toy motor housing, vibrant industrial color (e.g. bold electric blue or construction orange casing), distinct metallic drive shaft/hub on the front (+X), rigid mounting flange on the back (-X), and a visible indicator lens socket on top (+Y). Friendly, stylized maker-workshop character with a strong silhouette.
- **What NOT to Model**: Do NOT model internal coils, wires, power cords, or separate spinning rotors. The server manages physical `HingeConstraint` actuators and neon LED indicator state authoritatively.
- **Hyper3D Prompt**:
  ```text
  Chunky toy electric motor component for a playful maker workshop Roblox game. Bold colorful casing, cylindrical drive shaft hub on one end, rigid flat mounting plate on back, rounded indicator lens on top, friendly toy-like industrial proportions, clean silhouette, no wires, no text, isolated single object.

  Low-poly game asset.
  PBR materials.
  No internal geometry.
  ```
- **Blender Cleanup Notes**:
  - Center origin at `(0, 0, 0)` matching the 2×2×2 stud bounding box.
  - Ensure drive shaft faces +X and mounting plate faces -X to align with socket attachment frames.
  - Keep poly count under 2,500 tris.

---

## Priority 1 Asset Queue (Construction Components)

### P1-01 Workshop Wheel [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/wheel_rubber_01/`
- **Blender Source**: `assets/source/blender/wheel_rubber_01.blend`
- **Roblox Export**: `assets/export/roblox/wheel_rubber_01.glb` (3,000 tris)
- **Purpose**: Rotational component attached to axles for rolling vehicles and kinetic contraptions.
- **Roblox Size**: `0.4 × 2.4 × 2.4` studs (`Cylinder` matching `ComponentDefinitions.luau`).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Wheel`
- **Visual Requirements**: Chunky workshop construction wheel. Thick rubber tire, simple metal hub, large obvious round axle opening, toy-like mechanical proportions, clean circular silhouette from every angle.
- **Hyper3D Prompt**:
  ```text
  Chunky workshop construction wheel for a playful Roblox engineering game. Thick rubber tire, simple metal hub, large obvious round axle opening, toy-like mechanical proportions, slightly imperfect maker-workshop character, clean silhouette, no text, isolated object.

  Low-poly game asset.
  PBR.
  No axle included.
  No hidden/internal geometry.
  ```

---

### P1-02 Structural Plank [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/plank_beam_01/`
- **Blender Source**: `assets/source/blender/plank_beam_01.blend`
- **Roblox Export**: `assets/export/roblox/plank_beam_01.glb` (2,500 tris)
- **Purpose**: Primary structural beam for building ramps, bridges, levers, and chassis.
- **Roblox Size**: `8.0 × 0.6 × 2.0` studs (matches `ComponentDefinitions.luau` Plank).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Plank`
- **Visual Requirements**: Chunky rectangular wooden beam, soft bevels, subtle wear, obvious mounting areas at both ends, simple handmade workshop character, broad readable surfaces.
- **Hyper3D Prompt**:
  ```text
  Stylized reusable construction plank for a playful maker workshop Roblox game. Chunky rectangular wooden beam, soft bevels, subtle wear, obvious mounting areas at both ends, simple handmade workshop character, broad readable surfaces, no nails sticking out, no text, isolated object.

  Low-poly.
  Game-ready.
  PBR.
  Strong silhouette.
  ```

---

### P1-03 Construction Block [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/block_cube_01/`
- **Blender Source**: `assets/source/blender/block_cube_01.blend`
- **Roblox Export**: `assets/export/roblox/block_cube_01.glb` (2,000 tris)
- **Purpose**: Heavy structural anchor, weight, spacer, and multi-socket connector block.
- **Roblox Size**: `2.0 × 2.0 × 2.0` studs (matches `ComponentDefinitions.luau` Block).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Block`
- **Visual Requirements**: Chunky multipurpose construction block, durable toy-workshop form, soft bevels, slightly industrial painted workshop material, broad mounting faces, simple silhouette.
- **Hyper3D Prompt**:
  ```text
  Chunky multipurpose construction block for a playful engineering workshop game. Durable toy-workshop form, soft bevels, slightly industrial material, broad mounting faces, intentionally simple silhouette, friendly stylized design, no text, isolated object.

  Roblox-friendly low-poly game asset.
  PBR.
  No tiny details.
  ```

---

### P1-04 Spring Launcher / Bumper

- **Purpose**: Stored-energy compression component. Mounts rigidly to chassis or structure and compresses under load to release kinetic thrust.
- **Approximate Roblox Size**: `3.0 × 2.5 × 3.0` studs (matches `ComponentDefinitions.luau` Spring).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Spring`
- **Visual Requirements**: Chunky toy-industrial base, large clearly visible metal coil, broad moving plunger plate, rounded safe proportions, obvious compression direction.
- **What NOT to Model**: Do NOT model hundreds of coil segments or internal prismatic sliders.
- **Hyper3D Prompt**:
  ```text
  Stylized compression spring launcher component for a playful family engineering game. Chunky toy-industrial base, large clearly visible metal coil, broad moving plunger plate, rounded safe proportions, obvious compression direction, friendly maker-workshop design, subtle wear, no text, isolated object on white background.

  Roblox-friendly low-poly game asset.
  PBR materials.
  No environment.
  No thin fragile geometry.
  Strong readable silhouette.
  ```
- **Blender Cleanup Notes**:
  - Base plate origin at bottom center.
  - Plunger can be separate subpart or welded visual cap.
  - Coils modeled with 4–5 clean turns maximum.

---

### P1-05 Propeller Fan Module

- **Purpose**: Aerodynamic thrust and airflow component. Mounts to powered motor axle to blow air forward and propel vehicles backward via reaction thrust.
- **Approximate Roblox Size**: `0.8 × 3.2 × 3.2` studs (matches `ComponentDefinitions.luau` Fan).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Fan`
- **Visual Requirements**: Chunky circular protective shroud, 3–4 large rounded blades, central axle hub, toy-industrial construction, clear airflow direction silhouette.
- **Hyper3D Prompt**:
  ```text
  Stylized workshop propeller fan module for a playful family engineering game. Chunky circular protective shroud, three large rounded blades, obvious central axle hub, toy-industrial construction, strong airflow direction silhouette, blue and metal mechanical materials, friendly safe proportions, no text, isolated object on white background.

  Roblox-friendly low-poly game asset.
  PBR materials.
  No stand.
  No cables.
  No environment.
  ```
- **Blender Cleanup Notes**:
	- Origin centered at axle socket.
	- Airflow direction aligns along +X axis.
	- Round protective shroud around outer perimeter.

---

### P1-06 Rope Hook [STATUS: QUEUED]
- **Purpose**: Structural rope anchor component. Provides an eyelet loop to attach rope lines to platforms, beams, or overhead gantries.
- **Roblox Size**: `1.0 × 1.5 × 1.0` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Hook`
- **Visual Requirements**: Chunky steel/iron lifting hook with heavy eyelet loop at top, rigid square base plate on bottom. Toy-industrial proportions, visible bevels.

---

### P1-07 Powered Winch [STATUS: QUEUED]
- **Purpose**: Motorized rope tension spool. Automatically reels in attached ropes during `TEST` to lift or pull loads.
- **Roblox Size**: `2.0 × 2.0 × 2.0` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Winch`
- **Visual Requirements**: Heavy cylindrical cable drum housing with ribbed spool, cable guide opening, rigid mounting bracket on bottom/rear, industrial yellow/metal casing.

---

## Priority 2 Asset Queue (Environment & Dressing)

### P2-01 Maker Workbench [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/workbench_maker_01/`
- **Blender Source**: `assets/source/blender/workbench_maker_01.blend`
- **Roblox Export**: `assets/export/roblox/workbench_maker_01.glb` (12,000 tris)
- **Purpose**: Level staging and dressing background prop.
- **Roblox Size**: `12.0 × 3.5 × 5.0` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Props.MakerWorkbench`

### P2-02 Tool Storage Rack [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/rack_tool_01/`
- **Blender Source**: `assets/source/blender/rack_tool_01.blend`
- **Roblox Export**: `assets/export/roblox/rack_tool_01.glb` (10,000 tris)
- **Purpose**: Component rack holding unused building parts.
- **Roblox Size**: `10.0 × 4.0 × 4.0` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Props.ToolStorageRack`

### P2-03 Workshop Wall Panel [STATUS: EXPORTED]
- **Source**: `assets/source/hyper3d/wall_panel_01/`
- **Blender Source**: `assets/source/blender/wall_panel_01.blend`
- **Roblox Export**: `assets/export/roblox/wall_panel_01.glb` (8,000 tris)
- **Purpose**: Modular workshop back wall panel.
- **Roblox Size**: `8.0 × 12.0 × 1.0` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Props.WorkshopWallPanel`

### P2-04 Workshop Storage Crate [STATUS: QUEUED]
- **Purpose**: Industrial wooden and steel storage crate dressing.
- **Roblox Size**: `2.4 × 2.4 × 2.4` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Props.Crate`

### P2-05 Connector Pegboard [STATUS: QUEUED]
- **Purpose**: Wall-mounted tool and connector board on the back wall.
- **Roblox Size**: `10.0 × 8.0 × 0.6` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Props.ConnectorBoard`
