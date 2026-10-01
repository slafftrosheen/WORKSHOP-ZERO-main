# Workshop Zero - Asset Pipeline

> [!IMPORTANT]
> **Core Architecture Rules:**
> - **Visual assets are replaceable skins over stable Workshop Zero physics contracts.**
> - **Missing art must never make an experiment unplayable.**

## The asset bridge pipeline

```text
Hyper3D / Rodin
       |
       v (export GLB)
Blender
       | clean mesh, normalize scale, apply transforms, set origin/pivot, inspect materials
       v (export GLB)
Roblox Studio Import 3D
       |
       v
ReplicatedStorage.WorkshopZeroAssets/<category>/<AssetName>
       | (set Model pivot correctly)
       v
AssetProvider (server runtime bridge)
       |
       +---> Clones visual model
       +---> Normalizes physics (CanCollide=false, CanTouch=false, Massless=true, Anchored=false)
       +---> Measures the mesh and aligns it (never trusts the export pivot)
       +---> Welds visual to authoritative physics part
       `---> Hides primitive geometry (or falls back cleanly to primitive if missing)
```

## Where the bridge is called

Nothing has to "turn the assets on".  Each asset class has exactly one place
that applies art, so no experiment can forget it:

| Asset class | Applied by | Alignment |
| ----------- | ---------- | --------- |
| `Components/*` | `ComponentFactory.Create`, for every component ever spawned | centre on the physics Root |
| `Payloads/Duck` | `ExperimentLevelUtil.CreateDuck`, shared by all five experiments | underside on the collider's underside |
| `Goals/GoalButton` | `ExperimentLevelUtil.CreateGoalButton`, shared by all five experiments | underside on the static base |
| `Props/*` | `WorkshopService.buildPersistentShell` | underside on the floor pivot |

## Pivots and alignment

An imported model's pivot is whatever Blender last set, and guessing wrong used
to mean a workbench buried in the floor or a duck floating over its collider.
The bridge therefore measures instead of assuming:

```text
AssetProvider.GetVisualBounds(model)        world-space box of the visible parts
AssetProvider.AlignVisual(model, cf, mode)  "Center" | "Bottom" placement
AssetProvider.HidePrimitives(container)     hide what the art replaced
```

```text
Components   bbox centre  -> physics Root centre
Payloads     bbox bottom  -> underside of the collider
Goals        bbox bottom  -> underside of the static base part
Props        bbox bottom  -> the floor pivot the shell passes in
```

Consequences worth knowing:

* A Blender pivot set to "bottom centre" or "geometric centre" both work.  The
  only thing that has to be right is the model's **orientation** and **scale**.
* A visual is aligned **before** it is welded.  A `WeldConstraint` captures the
  offset it finds when it is created, so aligning afterwards would be undone.
* Components are aligned on their physics Root.  For a `Spring`, the Root is the
  base plate rather than the model centre, so spring art should be authored
  around its base plate.
* Visual parts are cloned with `Anchored = false`.  Props are anchored when they
  are placed, components follow the build/test anchoring of their machine, and
  an anchored mesh part must never pin a moving assembly.
* `HidePrimitives` changes transparency and shadow only.  It never touches
  `CanQuery`, because the physics Root must keep receiving raycasts for the
  server-owned `DragDetector` under the mesh.
* The goal mesh is welded to the **base**, not the cap: the cap presses 0.4 studs
  under the art, and a mesh welded to the cap would drag the whole button down
  with it.

### Exact step-by-step workflow

1. **Hyper3D / Rodin**: Generate prompt-based model, export GLB. Save raw export to `assets/source/hyper3d/<asset-name>/`.
2. **Blender**:
   - Open GLB.
   - Clean mesh (remove internal faces, loose geometry, duplicate vertices).
   - Normalize scale (match required Roblox stud dimensions).
   - Apply all transforms (`Ctrl+A` -> Apply All Transforms).
   - Set origin / pivot to geometric center or connection socket.
   - Inspect and assign clean PBR materials.
   - Export optimized GLB to `assets/export/roblox/<name>.glb`.
3. **Roblox Studio 3D Importer (Bulk Import)**:
   - Open `place/WorkshopZeroPrototype.rbxlx` in Roblox Studio.
   - Click **Avatar** / **Home** tab -> **Import 3D** (or **File** -> **Import**).
   - In the file picker, navigate to `assets/export/roblox/` and select all 9 `.glb` files at once:
     - `block_cube_01.glb`
     - `button_goal_red_01.glb`
     - `duck_rubber_01.glb`
     - `motor_electric_01.glb`
     - `plank_beam_01.glb`
     - `rack_tool_01.glb`
     - `wall_panel_01.glb`
     - `wheel_rubber_01.glb`
     - `workbench_maker_01.glb`
   - In the Import Queue preview dialog, click **Import** to upload them into Studio.
4. **Organize into `ReplicatedStorage.WorkshopZeroAssets`**:
   - Open [organize_imported_assets.luau](../scripts/organize_imported_assets.luau), copy the
     whole file, paste it into Studio's **Command Bar** (`View -> Command Bar`) and press Enter.
   - It is safe to run twice, and it does not care where the importer dropped the models -
     `Workspace`, a folder inside it, or `ReplicatedStorage` are all searched.
   - It renames and classifies each model, normalizes physics
     (`CanCollide=false`, `CanTouch=false`, `Massless=true`, `Anchored=false`), guarantees a
     `PrimaryPart`, reports the measured size against `AssetManifest`, and files the models into:
     - `ReplicatedStorage.WorkshopZeroAssets.Components` (`Plank`, `Block`, `Wheel`, `Motor`)
     - `ReplicatedStorage.WorkshopZeroAssets.Payloads` (`Duck`)
     - `ReplicatedStorage.WorkshopZeroAssets.Goals` (`GoalButton`)
     - `ReplicatedStorage.WorkshopZeroAssets.Props` (`MakerWorkbench`, `ToolStorageRack`, `WorkshopWallPanel`)
   - Delete the importer's leftovers in `Workspace`, then **save the place**.
5. **Play**:
   - Start Play mode in Studio (`F5`). `AssetProvider` finds the custom assets, normalizes
     them, measures them, and welds them over the physics parts. If any asset is absent, the
     game falls back cleanly to the primitive without error.
   - Studio Output reports the whole bridge once per session, at the moment the persistent
     Workshop shell is built:

     ```text
     [WZ Assets]

     Components
       Block              custom
       Fan                primitive
       Hook               primitive
       Motor              custom
       Plank              custom
       Spring             primitive
       Wheel              custom
       Winch              primitive

     Payloads
       Duck               custom

     Goals
       GoalButton         custom

     Props
       ConnectorBoard     primitive
       Crate              primitive
       MakerWorkbench     custom
       ToolStorageRack    custom
       WorkshopWallPanel  custom

     9/17 visuals are custom art, 8 fall back to primitives
     ```

   - `primitive` is not an error.  It means no art exists for that asset yet and the
     procedural stand-in is doing its job.  Art currently exists for: `Plank`, `Block`,
     `Wheel`, `Motor`, `Duck`, `GoalButton`, `MakerWorkbench`, `ToolStorageRack`,
     `WorkshopWallPanel`.  Still waiting on art: `Spring`, `Fan`, `Hook`, `Winch`,
     `Crate`, `ConnectorBoard`.
   - Studio warnings from the bridge are worth reading: they report `CanCollide` that
     survived normalization, missing `PrimaryPart`, high geometry counts, and an export
     whose size deviates from `AssetManifest.ExpectedBounds`.

## Folder map

```text
assets/source/hyper3d/<asset-name>/   untouched originals
assets/source/blender/                editable Blender sources
assets/export/roblox/                 clean, correctly named exports
assets/references/                    sketches, photos, inspiration
```

Large binaries (`*.blend`, `*.glb`, `*.gltf`, `*.fbx`, `*.obj`, `*.stl`,
`*.psd`, `*.exr`) are stored through Git LFS. Small PNG/JPG art stays as normal
Git objects on purpose.

## Hyper3D / Rodin

Hyper3D/Rodin is initially a **human-operated content tool**. There is no API
automation and no API client in this repository. Do not build one yet.

- Store originals under `assets/source/hyper3d/<asset-name>/`.
- Prefer **GLB** with **PBR** materials for normal props.
- Never overwrite an original. A new attempt gets a new folder or a new name.
- Filenames coming out of the generator may stay untouched in the source
  folder. Renaming happens at the export step.

If API automation is ever added, credentials must come from an environment
variable (`RODIN_API_KEY`) and must never enter Git or Roblox code.
`.env.example` exists for exactly that future, and is the only place the
variable is mentioned. It currently contains one line:

```text
RODIN_API_KEY=
```

## Blender rules

Editable sources live in `assets/source/blender/`.

For Roblox-oriented scenes:

```text
Unit System: None
Rotation: Degrees
```

Before final export:

```text
clean topology
remove hidden junk
remove duplicate geometry
apply scale
apply rotation where appropriate
set deliberate origin / pivot
verify normals
verify UVs
reduce unnecessary polygons
remove unnecessary materials
give objects meaningful names
```

Keep the visual and the physics separate:

```text
Visual asset:  pretty mesh
Physics:       simple Part / box / cylinder / convex approximation
```

Generated models are **not** physics collision meshes. Do not hand a complex
generated mesh to Roblox's collision solver for a fast-moving machine part
unless testing proves it is actually needed.

## Performance budget

Hard limit:

```text
Never exceed Roblox's per-mesh 20,000 triangle limit.
```

Workshop Zero internal targets are much smaller:

| Asset kind             | Triangles         | Texture      |
| ---------------------- | ----------------- | ------------ |
| tiny / simple prop     | 500 - 3,000       | 256 x 256    |
| normal interactive prop| 2,000 - 8,000     | 512 x 512    |
| important hero prop    | 10,000 - 15,000   | 1024 x 1024  |

Hero props only when the visuals actually justify it. Do not chase polygon
limits. Workshop Zero should run well on ordinary phones and tablets, because
that is what the family actually has.

## Naming conventions

Semantic names, lower snake case, version suffix.

Good:

```text
motor_small_01
wheel_rubber_01
plank_wood_01
spring_medium_01
button_goal_red_01
duck_rubber_01
```

Bad:

```text
mesh3
finalfinal
newobject
rodin_output_92873
Cube.042
```

Generated filenames may remain untouched in `assets/source/hyper3d`.
Clean Roblox exports must be renamed properly.

## Studio import

Preferred format: **GLB / glTF**. FBX is acceptable if GLB creates a specific
problem.

1. Put the export in `assets/export/roblox/` with its final name.
2. In Studio: **File -> Import -> 3D Importer** (or Avatar/Asset Manager for
   accessory-style items), choose the file.
3. Keep Blender -> Roblox orientation and scale intact; do not "fix" a
   rotation by rotating the imported MeshPart.
4. Verify, in this order:

```text
verify scale
verify pivot
verify orientation
verify textures
verify SurfaceAppearance / PBR
verify material count
verify collision behavior
verify mobile visual quality
```

5. If the mesh is a machine component, replace its imported collision with a
   simple Part / box / cylinder / convex hull unless testing shows otherwise.
6. Save the place. The imported mesh now lives in the Studio-owned place, not
   in Git.

## Studio Import Checklist for Workshop Props

When importing props for the persistent Workshop shell:

```text
1. Import GLB via Studio 3D Importer

2. Rename Model exactly:
   MakerWorkbench
   ToolStorageRack
   Crate
   WorkshopWallPanel
   ConnectorBoard

3. Move under:
   ReplicatedStorage.WorkshopZeroAssets.Props

4. Verify:
   pivot
   scale (AssetProvider Studio diagnostics warn if off-scale)
   materials
   SurfaceAppearance
   no unwanted collisions (visuals are normalized CanCollide=false, Massless=true)

5. Save place
```

### Exact Component Asset Names

Under `ReplicatedStorage.WorkshopZeroAssets.Components`:
- `Components/Plank`
- `Components/Block`
- `Components/Wheel`
- `Components/Motor`
- `Components/Spring`
- `Components/Fan`
- `Components/Hook`
- `Components/Winch`

Under `ReplicatedStorage.WorkshopZeroAssets.Payloads`:
- `Payloads/Duck`

Under `ReplicatedStorage.WorkshopZeroAssets.Goals`:
- `Goals/GoalButton`

### Recommended Prop Pivots

Setting intentional Model pivots ensures procedural placement in `WorkshopService` aligns cleanly:

```text
MakerWorkbench:
   bottom-center pivot

ToolStorageRack:
   bottom-center pivot

Crate:
   bottom-center pivot

WorkshopWallPanel:
   center / back mounting plane

ConnectorBoard:
   center / back mounting plane
```

## Future idea: reproducible asset import

Roblox now ships an `opencloud`/asset-import path and Studio has a scriptable
3D importer. When the asset count grows past "a handful", revisit automated
import - as a separate, explicit decision, not as a BOOTSTRAP-001 side effect.
