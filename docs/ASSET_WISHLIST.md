# Workshop Zero - Asset Wishlist

> [!IMPORTANT]
> **Core Architecture Rules:**
> - **Visual assets are replaceable skins over stable Workshop Zero physics contracts.**
> - **Missing art must never make an experiment unplayable.**

This wishlist defines the initial production asset queue for Hyper3D generation and Blender cleanup. The game remains 100% playable using procedural primitives when any or all of these models are absent.

Shared visual direction for every asset:

```text
warm workshop, chunky geometry, toy-like proportions
big readable silhouettes, minimal small detail
handmade rather than industrial, friendly rather than realistic
clean topology, low polygon count, no text, no logos, isolated single objects
```

---

## Priority 0 Asset Queue (Experiment 001)

### P0-01 Rubber Duck

- **Purpose**: The star and payload of Experiment 001. Transported by player machines to trigger the goal.
- **Approximate Roblox Size**: `2.5 × 2.0 × 3.0` studs (matches `SaveTheDuckExperiment` payload volume).
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

### P0-02 Giant Red Goal Button

- **Purpose**: Level objective target. Depressed when the duck contacts it to complete the experiment.
- **Approximate Roblox Size**: `4.0 × 1.8 × 4.0` studs base with `3.2 × 0.8 × 3.2` studs plunger cap.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Goals.GoalButton`
- **Visual Requirements**: Oversized comical red mechanical push button. Huge readable red cap, chunky metal/industrial base, visible oversized bolts, rounded toy-industrial forms, friendly rather than dangerous, strong silhouette.
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

### P0-03 Workshop Wheel

- **Purpose**: Rotational component attached to axles for rolling vehicles and kinetic contraptions.
- **Approximate Roblox Size**: `3.0 × 1.5 × 3.0` studs (`Cylinder` matching `ComponentDefinitions.luau`).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Wheel`
- **Visual Requirements**: Chunky workshop construction wheel. Thick rubber tire, simple metal hub, large obvious round axle opening, toy-like mechanical proportions, clean circular silhouette from every angle.
- **What NOT to Model**: Do NOT include an axle rod or constraint. The axle hole is purely visual; physical rotation is governed by Roblox Attachments and `HingeConstraint`.
- **Hyper3D Prompt**:
  ```text
  Chunky workshop construction wheel for a playful Roblox engineering game. Thick rubber tire, simple metal hub, large obvious round axle opening, toy-like mechanical proportions, slightly imperfect maker-workshop character, clean silhouette, no text, isolated object.

  Low-poly game asset.
  PBR.
  No axle included.
  No hidden/internal geometry.
  ```
- **Blender Cleanup Notes**:
  - Center origin at the exact geometric center of the axle hole.
  - Orient wheel so rotation axis aligns cleanly with the component's coordinate space.
  - Keep cylinder segments clean (24–32 segments max).

---

### P0-04 Structural Plank

- **Purpose**: Primary structural beam for building ramps, bridges, levers, and chassis.
- **Approximate Roblox Size**: `8.0 × 1.0 × 2.0` studs (matches `ComponentDefinitions.luau` Plank).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Plank`
- **Visual Requirements**: Chunky rectangular wooden beam, soft bevels, subtle wear, obvious mounting areas at both ends, simple handmade workshop character, broad readable surfaces.
- **What NOT to Model**: Do NOT model protruding connector pins or studs that conflict with runtime socket visual indicators.
- **Hyper3D Prompt**:
  ```text
  Stylized reusable construction plank for a playful maker workshop Roblox game. Chunky rectangular wooden beam, soft bevels, subtle wear, obvious mounting areas at both ends, simple handmade workshop character, broad readable surfaces, no nails sticking out, no text, isolated object.

  Low-poly.
  Game-ready.
  PBR.
  Strong silhouette.
  ```
- **Blender Cleanup Notes**:
  - Maintain exact bounds `8.0 × 1.0 × 2.0` studs so socket connector offsets align accurately.
  - Set origin at center of the plank (`0, 0, 0`).
  - Warm timber / pine grain texture with softly beveled edges.

---

### P0-05 Construction Block

- **Purpose**: Heavy structural anchor, weight, spacer, and multi-socket connector block.
- **Approximate Roblox Size**: `3.0 × 3.0 × 3.0` studs (matches `ComponentDefinitions.luau` Block).
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Components.Block`
- **Visual Requirements**: Chunky multipurpose construction block, durable toy-workshop form, soft bevels, slightly industrial painted workshop material, broad mounting faces, simple silhouette.
- **What NOT to Model**: Do NOT embed complex greebles or tiny screws.
- **Hyper3D Prompt**:
  ```text
  Chunky multipurpose construction block for a playful engineering workshop game. Durable toy-workshop form, soft bevels, slightly industrial material, broad mounting faces, intentionally simple silhouette, friendly stylized design, no text, isolated object.

  Roblox-friendly low-poly game asset.
  PBR.
  No tiny details.
  ```
- **Blender Cleanup Notes**:
  - Center origin at `(0, 0, 0)`.
  - Ensure soft bevels on all 12 edges without excess polygons.
  - Distinct workshop colour (e.g. painted workshop teal/navy/grey).

---

## Priority 1 Asset Queue (Environment & Dressing)

### P1-01 Maker Workbench
- **Purpose**: Level staging and dressing background prop.
- **Approximate Size**: `12.0 × 3.5 × 5.0` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Props.Workbench`

### P1-02 Tool Storage Rack
- **Purpose**: Component rack holding unused building parts.
- **Approximate Size**: `10.0 × 4.0 × 4.0` studs.
- **Target Folder**: `ReplicatedStorage.WorkshopZeroAssets.Props.ToolRack`
