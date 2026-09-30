# Workshop Zero - Architecture

Status: **WZ-001**. The construction kernel exists and is playable in principle.
There is still no challenge, no art and no persistence.

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

## Module map

```text
src/shared/construction/
    ConstructionTypes      states, kinds, record shapes, wire validators
    ConnectorTypes         connector kinds and compatibility
    ComponentDefinitions   the prototype catalogue (Plank, Block, Wheel)
    ConstructionConfig     every tunable number and name

src/server/construction/
    ComponentFactory       builds components, connectors, drag detectors
    ConnectorService       the connection registry, snapping, disconnecting
    SimulationService      the Build/Testing/Resetting state machine
    BuildService           dragging, rotation, build-area rules
src/server/dev/
    PrototypeWorkshop      Studio-only runtime sandbox and starter parts

src/client/construction/
    BuildController        selection, requests, snap preview
src/client/ui/
    PrototypeControls      the TEST/RESET panel
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
```

Rules:

- A client may only name things, never build them. No instances, no CFrames,
  no constraints, no Lua blobs.
- Every field is validated against a small enumerator in `ConstructionTypes`.
- `DragStateChanged` goes only to the player who is dragging, so a snap preview
  never appears on somebody else's screen.

There is no ownership or per-player plot concept yet: anybody may manipulate
any component. Multiplayer construction is explicitly out of scope.

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

`PrototypeWorkshop` creates `Workspace.WorkshopZeroRuntime` in Studio only, and
only when no authored `Workspace.Workshop` exists. It is a development harness:
a live server never fabricates level geometry, and no runtime content is ever
written back into the place file.

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
