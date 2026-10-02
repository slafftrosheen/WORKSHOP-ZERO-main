# Workshop Zero - Architecture

Status: **LONG-RUN-002**. The persistent workshop shell (`Workspace.Workshop.Shell`), modular experiment bay (`Workspace.Workshop.ExperimentBay`), rope connector, hook, powered winch, and all five experiments (Save the Duck, Uphill Delivery, Over the Wall, Windy Business, Lift Off) are fully operational with session-local progression and discovery cards.

> [!IMPORTANT]
> **Core Architectural Invariants:**
> - **Visual assets are replaceable skins over stable Workshop Zero physics contracts.**
> - **Missing art must never make an experiment unplayable.**
> - **Server owns authoritative game state and physics truth.**
> - **Never encode the intended solution as the only valid solution.**
> - **Internal component constraints are never registered as user construction connections.**
> - **The Workshop is persistent (`Workspace.Workshop.Shell`). Experiments occupy the Experiment Bay (`Workspace.Workshop.ExperimentBay`).**
> - **Rope is a user construction connection; internal ropes inside future components are not automatically construction topology.**
> - **A winch pulls by changing rope target length through physics. It never teleports loads.**

## Subsystem Boundaries

The system is strictly partitioned into single-responsibility boundaries:

1. **`WorkshopService` — Persistent Workshop Shell & Bay**
   - Owns `Workspace.Workshop` root, persistent `Shell` (ambient lighting, workbench, tool rack, wall panels, connector board, crates, player spawn).
   - Manages `ExperimentBay`, ensuring old experiment geometry teardown never destroys persistent workshop props.

2. **`ConnectorService` — Mechanical Topology**
   - Tracks user-constructed joints between components (`Rigid` -> `WeldConstraint`, `Axle` -> `HingeConstraint`, `Rope` -> `RopeConstraint`).
   - Owns snapping, alignment, disconnection, and the authoritative connection registry.
   - For `Rope`, maintains natural distance and slack without collapsing component transforms together.
   - For `Axle`, supports `RotaryMotor` (when Motor attached) or `RotaryServo` (when Servo attached). Warns on unsupported `Motor <-> Servo` axle connections.

3. **`ActuatorService` — Powered Joints & Actuators**
   - Subscribes to `ConnectorService` lifecycle hooks and discovers self-contained components (`Piston`).
   - Manages four distinct actuator types:
     - `RotaryMotor`: continuous angular rotation (`HingeConstraint`, `ActuatorType = Motor`).
     - `RopeWinch`: distance pull via physics (`RopeConstraint`, `WinchEnabled`).
     - `RotaryServo`: angular positioning (`HingeConstraint`, `ActuatorType = Servo`, limits 0°–90°).
     - `LinearPiston`: self-contained straight-line stroke (`PrismaticConstraint`, `ActuatorType = Servo`, limits 0–`PistonStroke`).
   - Actuator Control Policies:
     - Legacy actuators (`Motor`, `Winch`) auto-run when unwired during `Testing`; follow ON/OFF control when wired.
     - Positional actuators (`Servo`, `Piston`) hold rest (0°, 0 studs) when unwired or receiving `false`; actuate to active (90°, stroke studs) on `true`.
   - Never uses scripted CFrame animation: all motion is pure Roblox constraint physics.
   - Enables actuators on `Testing`, disables them and restores rest transforms and rope lengths **before** transform restoration on `Resetting` to prevent progressive drift.

4. **`BehaviourService` — Component-Specific Physical Effects**
   - Manages non-joint physical environmental interactions during `Testing`.
   - Simulates aerodynamic airflow cones and reaction thrust for powered `Fan` components using `VectorForce` primitives.
   - Runs a single shared, mobile-friendly Heartbeat loop during `Testing` only.
   - Tears down all dynamic attachments and forces cleanly on `Resetting` or level change.

5. **`ExperimentService` — Experiment Lifecycle & Progression**
   - Owns the `ExperimentState` state machine (`Loading`, `Build`, `Testing`, `Success`).
   - Validates session-local unlocks across Experiments 001–009 without persistent storage.
   - Enforces explicit Open Workshop unlock milestone (`ConstructionConfig.OpenWorkshopUnlockAfterExperiment = 5`), ensuring free build unlocks after completing Experiment 005.
   - Coordinates level loading, clean workshop teardown, counter publication, and experiment selection.

5. **`Experiment Modules` — Challenge-Specific Rules**
   - Implement the `ExperimentModule` contract (`Load`, `StartAttempt`, `RestoreToBuild`, `Restart`, `Unload`).
   - Own level-specific geometry creation via `ExperimentLevelUtil` and failure observation.
   - Validate goal completions authoritatively from server physics.

6. **`ComponentFactory` — Component Construction & Lifecycle**
   - Builds models, adds connectors, attaches DragDetectors, and manages root parts.
   - Delegates multi-part internal assemblies to specialized builders (`SpringBuilder`, `FanBuilder`).
   - Handles component-aware anchoring and drift-free internal state restoration (`ResetAllInternalState`).

7. **`AssetProvider` — Replaceable Visuals**
   - Bridges imported Studio/Blender meshes (`WorkshopZeroAssets`) to physical root parts.
   - Enforces zero-collision and masslessness on visual skins.
   - Falls back gracefully to procedural geometry when custom art is absent.

8. **`ConstructionMath` — Pure Mathematical & Validation Helpers**
   - Pure, deterministic Luau functions free of side-effects.
   - Derives motor rotation signs, fan aerodynamic falloff, and unlock checks.

9. **`WorkshopPresentationService` — What The Workshop Says**
   - Builds the WORKSHOP ZERO sign, the dynamic experiment wall, the component
     display wall, the physical TEST/RESET console, the physical EXPERIMENTS
     panel and two accent lamps, on top of the shell `WorkshopService` owns.
   - Renders replicated values only. It decides nothing and owns no state.
   - The console's two prompts call the same `ExperimentService` funnel the HUD
     calls: a second button, never a second action path.
   - Presentation may communicate construction state, but it must never own
     construction state.

10. **`WiringService` — Signal Topology & Control Wires**
    - Tracks logical connections between components (`Output` port -> `Input` port).
    - Enforces 1-wire-per-input fan-in rule and max signal wire length (35 studs).
    - Renders massless, collisionless `Beam` visuals between signal port attachments.
    - Preserves wires across normal `RESET` cycles; destroys them on `RESTART` or part return.

11. **`LogicService` — Centralized Logic & Sensor Evaluation**
    - Runs a single centralized 15 Hz update loop during `Testing`.
    - Evaluates logic gates (`AND`, `OR`, `NOT`), timers, sensors (`PressureSensor`, `ProximitySensor`), and switches.
    - Double-buffered tick evaluation: reads previous tick values, writes next state, preventing recursion and safely oscillating feedback cycles.
    - Communicates actuator control state to `ActuatorService`.

## The two phases

Everything in this repository exists to serve one loop:

```text
BUILD  ->  TEST  ->  RESET  ->  BUILD (again)
```

| Phase     | Who moves parts              | Components | Joints / Actuators / Behaviours |
| --------- | ---------------------------- | ---------- | ------------------------------- |
| Build     | the player, through a drag   | anchored   | present but physically inert    |
| Testing   | Roblox physics               | unanchored | live: welds weld, hinges spin, motors power, springs compress, fans blow |
| Resetting | nobody                       | anchored   | actuators & behaviours disabled first, snapshot restored |

Only `SimulationService` changes the phase, and the phase is published to
clients as a replicated `StringValue`, so a player who joins mid-test reads
`Testing` immediately instead of guessing.

Once components are unanchored, Roblox may hand network ownership of an
assembly to a nearby client. That is desirable for feel and is left alone. It
does **not** move authority: challenge completion, attempt counts and success
are judged by the server from its own view of the duck and the machine - never
from a client touch or a client-owned assembly. Feel may be client-simulated;
truth may not.

## Actuator & Power Architecture (Motor)

Workshop Zero keeps physical connection types minimal:
- **Connector Kinds**: `Rigid` and `Axle` are the **only** connector types. A motor does **not** introduce a new connector kind.
- **Powered Connection**: When an `Axle` connection joins a `Motor` component to another component (such as a `Wheel`), the resulting `HingeConstraint` is tagged as powered (`AttributePowered = "WZ_Powered"`).
- **Actuator Layer (`ActuatorService`)**:
  - `Attachment0` of the hinge is strictly assigned to the motor's connector attachment, guaranteeing deterministic local axes.
  - Symmetrical drive coordination: Motors placed symmetrically on opposite sides of a vehicle have outward axles pointing in opposite directions ($\vec{A}$ and $-\vec{A}$). The service calculates forward vehicle velocity direction $\vec{D} = \vec{A} \times \vec{Y}$ for each motor. If opposed ($\vec{D}_i \cdot \vec{D}_{ref} < 0$), rotation sign is inverted so both wheels drive forward cooperatively.
  - Reset contract: When transitioning from `Testing` to `Resetting`, `ActuatorService.DisableActuators()` is called **before** unanchoring or setting pivot CFrames, preventing erratic physics torques during position restoration.
  - Motor LED: A visual `WZ_MotorIndicator` glows Neon green while running in `Testing` and dims to SmoothPlastic when idle in `Build`.

## Spring & Stored Energy Architecture (Spring)

- Built via `SpringBuilder` as a multi-part component (`Root` Base Plate + `WZ_Plunger`).
- Internal mechanical constraints:
  - `PrismaticConstraint`: Restricts plunger movement strictly along local Y axis with physical travel limits (0 to 1.8 studs).
  - `SpringConstraint`: Provides restorative spring force with tuned stiffness (`Config.SpringStiffness = 320`) and damping (`Config.SpringDamping = 18`).
- Component-aware anchoring: In `Build` mode, both base and plunger are anchored. In `Testing`, the base unanchors with the assembly while the plunger floats freely within constraint limits.
- Drift-free reset: `ComponentFactory.ResetAllInternalState()` restores the plunger's relative offset to rest position and zeroes velocities on every RESET.

## Aerodynamics & Thrust Architecture (Fan)

- Built via `FanBuilder` with a cylindrical Root, central hub, 4 angled aerodynamic blades, and protective shroud.
- Input connector: `Axle_Input` on the rear face (`-X`). Requires a direct mechanical `Axle` connection to a `Motor` to activate.
- Thrust and reaction forces:
  - Directed airflow cone up to 32 studs in front of the fan (+X). Applies `VectorForce` to unanchored payloads and construction components with quadratic distance falloff and angular falloff.
  - Reaction thrust: In accordance with Newton's 3rd law, the fan assembly receives an opposing reaction force (`-forward * Config.FanThrustForce`), enabling propeller-driven vehicles.

## The two state machines (and why there are two)

```text
SimulationState   Build | Testing | Resetting     physics truth, SimulationService
ExperimentState   Loading | Build | Testing | Success   challenge lifecycle, ExperimentService
```

Only `SimulationService` writes SimulationState and only `ExperimentService`
writes ExperimentState. They observe each other's transitions instead of
fighting:

- an attempt starts when the simulation enters Testing (`Build -> Testing`)
- an attempt ends when the simulation returns to Build, or at success
- success leaves SimulationState at **Testing** so physics keeps running; the
  freeze is an experiment state, never a second physics state machine
- RESET during Success is refused by `ExperimentService` before it ever reaches
  `SimulationService`: a finished experiment can only be restarted or transitioned
- NEXT advances progression via `ExperimentService.NextExperiment(player)`,
  rebuilding the level in-place without place reloading

## Module map

```text
src/shared/assets/
    AssetManifest          central visual asset catalog, expected bounds, aliases

src/shared/construction/
    ConstructionTypes      states, kinds, record shapes, wire validators
    ConnectorTypes         connector kinds (Rigid, Axle, Rope) and compatibility
    ComponentDefinitions   catalogue (Plank, Block, Wheel, Motor, Spring, Fan, Hook, Winch)
    ConstructionConfig     every tunable number and name
    ConstructionMath       pure motor sign, fan force, and unlock calculations

src/shared/experiments/
    ExperimentTypes        experiment vocabulary, report and module contracts
    ExperimentDefinitions  definitions, ordering, discovery copy, DevExperimentId

src/server/world/
    WorkshopService        persistent shell, ambient lighting, workbench/rack/crates, bay
    WorkshopPresentationService  sign, experiment wall, component wall, console, panel

src/server/construction/
    ComponentFactory       builds components, connectors, drag detectors, indicator LEDs
    builders/
        SpringBuilder      multi-part plunger, prismatic & spring constraint setup
        FanBuilder         multi-part hub, shroud, and angled blade construction
    ConnectorService       connection registry, snapping (welds, hinges, ropes)
    ActuatorService        rotary motor & rope winch actuators, cooperative rotation
    BehaviourService       aerodynamic airflow cone and reaction thrust simulation
    SimulationService      the Build/Testing/Resetting state machine
    BuildService           dragging, rotation, return to rack, build-area rules

src/server/experiments/
    ExperimentRegistry     id-to-module directory (001 -> 005, plus Open Workshop)
    ExperimentLevelUtil    shared level construction, styling, duck, goal, staging
    SaveTheDuckLevel       builds Level 001 geometry
    SaveTheDuckExperiment  Level 001 experiment lifecycle and failure observer
    UphillDeliveryLevel    builds Level 002 ramp incline and upper platform
    UphillDeliveryExperiment Level 002 experiment lifecycle and uphill failure observer
    OverTheWallLevel       builds Level 003 barrier wall and target region
    OverTheWallExperiment  Level 003 experiment lifecycle and launch failure observer
    WindyBusinessLevel     builds Level 004 low-friction glide track and hazard zone
    WindyBusinessExperiment Level 004 experiment lifecycle and non-touch observer
    LiftOffLevel           builds Level 005 high platform and overhead gantry frame
    LiftOffExperiment      Level 005 experiment lifecycle and rope/winch observer
    OpenWorkshopLevel      builds the free-build bay (flat floor, pad, duck, full rack)
    OpenWorkshopExperiment free build: no goal, no success, ordinary physics flavour
    ExperimentService      attempt lifecycle, diagnostics, progression (Next/Restart/Select)

src/server/
    CollisionGroups        five groups and their matrix
src/server/assets/
    AssetProvider          resolves imported visual models from ReplicatedStorage
src/server/dev/
    PrototypeWorkshop      Studio-only runtime sandbox, behind a config flag

src/client/construction/
    BuildController        selection, requests, snap preview, ghost emphasis, tooltip
src/client/experiments/
    ExperimentController   intro card, success panel with Next/Board, debug overlay
src/client/ui/
    PrototypeControls      action button, state line, touch controls, return to rack
    ExperimentToast        one-line flavour notifications
    PartsTray              dynamic informational parts list & experiment header
    ExperimentBoard        modal experiment selector with locked cards & leave confirm
```

Dependencies point one way only:

```text
ConstructionTypes / ConnectorTypes / ConstructionConfig / ComponentDefinitions
        |
  ComponentFactory
        |
   ConnectorService <-> ActuatorService     SimulationService
        \                                         /
                        BuildService
                             |
             PrototypeWorkshop, Bootstrap (wiring)

ExperimentTypes / ExperimentDefinitions
        |
  ExperimentRegistry -> [Experiment Modules] -> ComponentFactory / LevelUtil
        |
  ExperimentService  (observes SimulationService, owns ExperimentState)
        |
  Bootstrap (wiring)
```

The client never requires a server module. Both read the same shared config,
which is why the snap preview and the server's snap decision use one number.

## Component contract

```text
WorkshopZeroRuntime/Components/<ComponentModel>     Folder
└── Model            WZ_Component      = true
                     WZ_ComponentId    = unique per server session (GUID)
                     WZ_ComponentType  = "Plank" | "Block" | "Wheel" | ...
                     PrimaryPart       = Root
    └── Root         the visible geometry (prototype components are one part)
                     └── Attachment  WZ_Connector      = true
                                     WZ_ConnectorType  = "Rigid" | "Axle"
                                     WZ_Occupied       = false | true
                     └── DragDetector RunLocally = false (server-run drag)
```

Nothing in the kernel addresses a component by instance. Requests from a client
carry a `ComponentId` string and the server resolves the real instance through
`ComponentFactory.FindComponentById`.

## Visual vs physics separation (Asset bridge)

A core rule of Workshop Zero is:

```text
GENERATED/IMPORTED MESH = VISUAL (appearance only)
ROBLOX ROOT PART        = PHYSICS (mass, collisions, constraints, dragging)
```

The construction kernel and experiments remain 100% playable with primitive parts. When custom meshes (from Hyper3D -> Blender) are placed in `ReplicatedStorage.WorkshopZeroAssets`:

```text
ReplicatedStorage.WorkshopZeroAssets/
    Components/       Plank, Block, Wheel, Motor
                      (Spring, Fan, Hook, Winch when art exists)
    Payloads/         Duck
    Goals/            GoalButton
    Props/            MakerWorkbench, ToolStorageRack, WorkshopWallPanel
                      (Crate, ConnectorBoard when art exists)
```

The bridge is a small, boring API:

1. `AssetProvider.Get(category, name)` clones the imported visual model.
2. It strips collision, touch, shadow, mass and anchors (`CanCollide = false`,
   `CanTouch = false`, `Massless = true`, `CanQuery = false`, `Anchored = false`).
3. `AssetProvider.AlignVisual(model, target, mode)` places the clone by its
   measured bounding box, never by its pivot: components align centre to
   centre, payloads, goals and props rest their underside on the support
   surface.
4. The caller welds the visual to the physics part with `WeldConstraint` -
   after the alignment, because a weld captures the offset it finds.
5. `AssetProvider.HidePrimitives(container, keep)` hides the primitive geometry
   the visual replaced, leaving `CanQuery` alone so the physics part keeps
   receiving raycasts and the server-owned DragDetector keeps working.
6. If the asset is missing, the game falls back to the procedural primitive
   without error.

Each asset class has exactly one place that applies art, so no experiment can
forget it: `ComponentFactory` for components, `ExperimentLevelUtil.CreateDuck`
and `CreateGoalButton` for payloads and goals, and `WorkshopService` for the
persistent shell's props.  Missing art still leaves a fully playable machine,
and never changes a mass, a collider or a connector.

## Connector contract

An attachment's own CFrame *is* the connection frame; the kernel never invents a
second transform representation.

```text
Attachment local +X   points out of the component, away from its surface
Attachment local +Y   is the component's "up" at that connector
```

Snapping rotates the moving component so its connector sits exactly where the
target connector's frame is, rotated 180 degrees about Y so the two connectors
face each other. Which joint results is decided only by the connector kind:

```text
Rigid + Rigid   ->  WeldConstraint     (Part0 / Part1 = the two root parts)
Axle  + Axle    ->  HingeConstraint    (Attachment0 / Attachment1 = the
                                        connectors themselves, no motor,
                                        no limits, free spin)
```

A candidate pair must be on different components, the same kind, unoccupied on
both sides, within `SnapDistance`, and roughly facing (within
`SnapAngleToleranceDegrees`). Axles are never welded: a wheel that cannot spin
is a bug, not a design.

## Connection records

The physical constraint is one field of a record, never the source of truth:

```lua
{
    Id = "guid",
    Type = "Rigid" | "Axle",
    ComponentA = "guid", ConnectorA = "Rigid_A",
    ComponentB = "guid", ConnectorB = "Rigid_B",
    Constraint = <WeldConstraint | HingeConstraint>,
}
```

Later batches - motors, machine analysis, saving machines, teaching
explanations - read records. Nothing should try to reconstruct the machine by
walking Roblox descendants and inspecting constraint types.

## Manipulation model

During BUILD every component is anchored, so nothing is simulated. Two
consequences the kernel is built around:

- **The whole assembly moves together.** Dragging a component that is already
  joined to others moves its whole connected assembly, so no joint's internal
  transform is ever stretched during BUILD. Physics therefore never has to
  "fix" a bent weld when TEST starts.
- **Placements are validated on release, not during the drag.** A drop outside
  the build area returns the assembly to its last valid transforms instead of
  fighting the player's hand.

Rotation is requested as a semantic operation (`YawLeft`, `YawRight`, `Flip`)
and applied by the server around the component's own pivot. The server never
accepts a CFrame from a client.

## The reset model

RESET is a restore, not a rebuild. The machine is never reconstructed.

```text
TEST    capture snapshot -> publish Testing -> disable dragging
        -> unanchor components -> zero velocities -> let physics run

RESET   publish Resetting -> anchor components -> zero velocities
        -> restore every saved pivot -> one Heartbeat
        -> zero velocities again -> enable dragging -> publish Build
```

The snapshot lives for the duration of one test only (`ComponentId`, model
pivot, root velocities, anchored state). Velocities are captured for
diagnostics but deliberately zeroed rather than restored, so repeated
TEST/RESET always starts from rest and cannot accumulate drift or duplicate
constraints - nothing recreates a constraint after BUILD.

## Networking

The whole client-facing surface is one folder:

```text
ReplicatedStorage/WorkshopZeroRemotes
    RequestSimulationAction   RemoteEvent  client -> server  "Test" | "Reset"
    RequestRotation           RemoteEvent  client -> server  { ComponentId, Operation }
    RequestDisconnect         RemoteEvent  client -> server  { ComponentId }
    DragStateChanged          RemoteEvent  server -> client  componentId | nil
    SimulationState           StringValue  server -> all      the current phase

    RequestExperimentAction   RemoteEvent  client -> server  "Restart"
    FailureToast              RemoteEvent  server -> client  flavour line
    OpenExperimentBoard       RemoteEvent  server -> client  wall panel asked for the board
    ExperimentState           StringValue  server -> all      the challenge phase
    ExperimentAttempt         IntValue     server -> all      attempts this session
    ExperimentPartsUsed       IntValue     server -> all      parts used, last test
```

Simulation and experiment requests are funneled through `ExperimentService`,
which can refuse what the kernel alone would accept (RESET during Success).

Rules:

- A client may only name things, never build them. No instances, no CFrames,
  no constraints, no Lua blobs.
- Every field is validated against a small enumerator in `ConstructionTypes`
  or `ExperimentTypes`.
- `DragStateChanged` goes only to the player who is dragging, so a snap preview
  never appears on somebody else's screen.
- Success never originates from a client. The server's own `Touched` handler on
  the goal trigger validates payload identity and experiment state.

There is no ownership or per-player plot concept yet: anybody may manipulate
any component. Multiplayer construction is explicitly out of scope.

## The payload concept

A payload is the thing an experiment asks the player to move. The duck is a
payload, not a component:

```text
Model Duck        WZ_Payload     = true
                  WZ_PayloadType = "Duck"
```

Payloads cannot be dragged, rotated, snapped or disconnected - the construction
kernel never touches them. During BUILD a payload is anchored; TEST unanchors
it; RESET restores its exact saved spawn transform with zero velocity. Goal
detection walks up from the touching part to find a model carrying
`WZ_Payload`, so a part dropped onto the trigger cannot claim to be the duck.

## Goal validation (success sequence)

```text
goal trigger Touched
  -> experiment is live (Testing) and not already succeeded
  -> the touching part's ancestors contain THIS payload
  -> success marked exactly once (ExperimentState -> Success)
  -> button reaction: cap depress, colour lift, one sound
  -> attempts and parts used are published; client renders the panel
```

Physics keeps running after success by design. RESET is refused; TRY AGAIN is
the only way out.

## Failure feedback philosophy

The FailureObserver is not a referee. It never ends an attempt; the player
does, with RESET. It watches the duck (pit, distance, speed, height) and the
structure (rigid-jointed components tipping past a threshold) and surfaces one
short flavour message per event per attempt. The only automatic action is a
safety freeze far below the world, which still does not reset anything.

## Collision policy

Five groups, registered before any part exists, matrix documented in
`src/server/CollisionGroups.luau`:

```text
                              Player  Comp  Payload  Env   Trigger
    Players                    yes    no     no      yes    no
    WorkshopComponents         no     yes    yes     yes    yes
    Payloads                   no     yes    yes     yes    yes
    Environment                yes    yes    yes     yes    yes
    GoalTrigger                no     yes    yes     yes    no
```

The design point: a player avatar can never solve, break or trigger the
experiment by walking into it. Components and payloads still collide with each
other and the world, so machines can push, carry and launch the duck. Player
parts are assigned to the group on spawn, including accessories added later.

## Mobile controls

The control panel derives its presentation from `UserInputService`: where a
hardware keyboard is absent, selected-component actions become four large
touch buttons (↺ ↻ FLIP, DISCONNECT) and the desktop `Q / E / R / X` hint line
is never shown. Desktop shortcuts keep working. There is no radial menu, no
gesture vocabulary and no UI framework.

## Ownership

```text
Filesystem / Rojo owns:      Luau, configuration, generated filesystem models
Roblox Studio owns:          Workspace layout, terrain, imported meshes,
                             lighting, manual composition
Server owns:                 components, connections, the phase, placement
Client owns:                 input, selection, presentation, snap preview
```

```text
USE:              Rojo
DO NOT ALSO USE:  Roblox Studio Script Sync
```

Two-way sync / syncback stays off.

## Generated at runtime, never saved

Two generators exist, and exactly one runs at a time:

```text
EnablePrototypeWorkshop = false (default)  ->  ExperimentService.Start()
EnablePrototypeWorkshop = true (Studio)    ->  PrototypeWorkshop.Setup()
```

`SaveTheDuckLevel` builds `Workspace.Workshop` at runtime, replacing only a
previous `WZ_Generated` workshop and never touching a hand-authored one.
`PrototypeWorkshop` creates `Workspace.WorkshopZeroRuntime` in Studio only.
Both are development harnesses in the sense that nothing is ever written back
into the place file - the level is rebuilt every session, and Workspace stays
Studio-owned.

## Open Workshop (free build)

Open Workshop is a mode, not an experiment, and it is deliberately not an
engine of its own.

```text
ExperimentDefinitions   Id = "open_workshop", Number = 0
                        in the catalogue, never in GetOrdered()
ExperimentRegistry      open_workshop -> OpenWorkshopExperiment
OpenWorkshopLevel       flat floor, one taped pad, the duck, all eight parts
```

Rules:

- **Open Workshop reuses the same physics kernel as experiments. It is not a
  separate sandbox engine.** Same `ComponentFactory`, `ConnectorService`,
  `ActuatorService`, `BehaviourService`, `SimulationService` and the same
  `ExperimentModule` contract.
- It has no goal button, so `report.Success` is never called: it cannot
  succeed, cannot fail, and cannot unlock or renumber anything.
- `Number = 0` keeps it out of `GetOrdered()` / `GetNext()`, so the numbered
  sequence and the "EXPERIMENT 00N" copy never see it. It is selected by id
  like any other definition, and `SelectExperiment` refuses it until
  `IsOpenWorkshopUnlocked` (every numbered experiment finished).
- CLEAR WORKSHOP is the ordinary experiment-layer restart wearing a label a
  child can read: disconnect, clear actuators and behaviours, pivot every
  staged part back. There is no second cleanup path.
- The duck stays as a toy payload. With no goal trigger, nothing in free
  build can finish anything.

## Deliberately absent

No ECS, no dependency injection, no event bus, no custom Promise library, no
persistence, no DataStore, no analytics, no anti-cheat framework, no UI
architecture, no custom physics framework, and no client-side physics
prediction. Complexity arrives when a proven need arrives.

## Adding dependencies later

1. Pin tools in `rokit.toml`; never upgrade a pin as a drive-by change.
2. Add the package to `wally.toml`, run `wally install`.
3. Map `ReplicatedStorage.Packages` to `Packages/` in `default.project.json`
   **at that moment** - Rojo fails on a `$path` that does not exist.
