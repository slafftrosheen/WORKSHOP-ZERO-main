# Workshop Zero - Architecture

Status: **WZ-002**. The construction kernel exists, and Experiment 001 runs on
top of it. There is still no art, no persistence and no framework.

## The two phases

Everything in this repository exists to serve one loop:

```text
BUILD  ->  TEST  ->  RESET  ->  BUILD (again)
```

| Phase     | Who moves parts              | Components | Joints                       |
| --------- | ---------------------------- | ---------- | ---------------------------- |
| Build     | the player, through a drag   | anchored   | present but physically inert |
| Testing   | Roblox physics               | unanchored | live: welds weld, hinges spin |
| Resetting | nobody                       | anchored   | present, untouched           |

Only `SimulationService` changes the phase, and the phase is published to
clients as a replicated `StringValue`, so a player who joins mid-test reads
`Testing` immediately instead of guessing.

Once components are unanchored, Roblox may hand network ownership of an
assembly to a nearby client. That is desirable for feel and is left alone. It
does **not** move authority: challenge completion, attempt counts and success
are judged by the server from its own view of the duck and the machine - never
from a client touch or a client-owned assembly. Feel may be client-simulated;
truth may not.

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
  `SimulationService`: a finished experiment can only be restarted

## Module map

```text
src/shared/construction/
    ConstructionTypes      states, kinds, record shapes, wire validators
    ConnectorTypes         connector kinds and compatibility
    ComponentDefinitions   the prototype catalogue (Plank, Block, Wheel)
    ConstructionConfig     every tunable number and name

src/shared/experiments/
    ExperimentTypes        experiment vocabulary, report and module contracts
    ExperimentDefinitions  Save the Duck data: inventory, geometry, thresholds, copy

src/server/construction/
    ComponentFactory       builds components, connectors, drag detectors, socket markers
    ConnectorService       the connection registry, snapping, disconnecting
    SimulationService      the Build/Testing/Resetting state machine
    BuildService           dragging, rotation, build-area rules
src/server/experiments/
    SaveTheDuckLevel       builds Workspace.Workshop (floor, pads, dressing, duck, goal)
    SaveTheDuckExperiment  payload handling, goal detection, failure observer
    ExperimentService      attempt lifecycle, diagnostics, success, restart
src/server/
    CollisionGroups        five groups and their matrix
src/server/dev/
    PrototypeWorkshop      Studio-only runtime sandbox, behind a config flag

src/client/construction/
    BuildController        selection, requests, snap preview and snap pulse
src/client/experiments/
    ExperimentController   intro card, success panel, toast wiring, debug overlay
src/client/ui/
    PrototypeControls      action button, state line, touch controls
    ExperimentToast        one-line flavour notifications
    PartsTray              informational parts list
```

Dependencies point one way only:

```text
ConstructionTypes / ConnectorTypes / ConstructionConfig / ComponentDefinitions
        |
  ComponentFactory
        |
   ConnectorService        SimulationService
        \                       /
              BuildService
                    |
    PrototypeWorkshop, Bootstrap (wiring)

ExperimentTypes / ExperimentDefinitions
        |
  SaveTheDuckLevel -> ComponentFactory
        |
  SaveTheDuckExperiment (reports)
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
