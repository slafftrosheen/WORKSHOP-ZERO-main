# AGENTS.md - Workshop Zero

Instructions for AI coding agents (Codex and friends) working in this repository.
Read this before changing anything.

## What this project is

Workshop Zero is a Roblox physics/building game. Players solve ridiculous
problems by building ridiculous machines, testing them, watching them fail,
changing one thing and testing again.

**Experiments 001 through 007** form the active 7-experiment playable suite:
- **Experiment 001 - Save the Duck** (passive construction, structures, gravity)
- **Experiment 002 - Uphill Delivery** (motors, wheels, torque, traction)
- **Experiment 003 - Over the Wall** (stored energy, spring launcher, compression)
- **Experiment 004 - Windy Business** (motors + fans, directional force, non-contact)
- **Experiment 005 - Lift Off** (tension, lifting force, load, rope, hook, winch)
- **Experiment 006 - Don't Hit the Wall** (sensors, feedback, logic inversion)
- **Experiment 007 - Two to Go** (logic AND, dual conditions, automation)
- **Open Workshop** (free sandbox, full mechanical and automation catalogue)

## Hard rules

- Luau uses `--!strict`.
- Server owns authoritative game state.
- Client owns input, presentation and local prediction only.
- The Workshop is persistent (`Workspace.Workshop.Shell`). Experiments occupy the Experiment Bay (`Workspace.Workshop.ExperimentBay`).
- Rope is a user construction connection; internal ropes inside future components are not automatically construction topology.
- A winch pulls by changing rope target length through physics. It never teleports loads.
- Do not trust client claims for challenge completion, inventory, unlocks or
  future currency.
- Prefer small modules.
- Avoid frameworks until complexity proves they are needed.
- Visual assets are replaceable skins over stable Workshop Zero physics contracts.
- Missing art must never make an experiment unplayable.
- Never encode the intended solution as the only valid solution.
- New components must remain useful outside the experiment that introduces them.
- Internal component constraints are not user construction connections.
- Physics should come from Roblox constraints and forces, not scripted CFrame animation.
- Educational concepts should emerge through play before explanatory copy appears.
- Never edit generated dependency folders manually
  (`Packages/`, `ServerPackages/`, `DevPackages/`, `build/`).
- Never commit secrets.
- Never commit Hyper3D/Rodin API keys.
- Never store API keys in Roblox code.
- Run `scripts/check.ps1` before considering a coding batch complete.
- Workspace scene composition is Studio-owned for now.
- Rojo owns code.
- Do not enable Rojo two-way sync/syncback without an explicit future decision.
- Do not replace handmade/child-designed mechanics with generic simulator
  systems without an explicit design decision.
- Educational mechanics must happen through interaction and experimentation,
  not quiz popups.

## Toolchain

Managed by Rokit (`rokit.toml`). Never install these tools by hand and never
upgrade a pinned version as a drive-by change.

| Tool     | Pin      |
| -------- | -------- |
| Rojo     | 7.7.0    |
| Wally    | 0.3.2    |
| Selene   | 0.31.0   |
| StyLua   | 2.5.2    |
| Luau LSP | 1.70.1   |

Rokit puts the tool shims in `%USERPROFILE%\.rokit\bin`.

## Commands

```powershell
.\scripts\doctor.ps1   # what is installed, what is missing
.\scripts\check.ps1    # StyLua + Selene + Rojo build validation
.\scripts\build.ps1    # build\WorkshopZero.rbxlx (seeds place\ once)
.\scripts\dev.ps1      # rojo serve, for use with Roblox Studio
```

## Construction kernel invariants (WZ-001)

Do not break these without an explicit decision:

- A client may only name a component by `ComponentId`. The server resolves the
  instance. Never accept an Instance, CFrame, constraint or Lua blob.
- Connector kind decides the joint: `Rigid` -> `WeldConstraint`,
  `Axle` -> `HingeConstraint`. An axle is never welded.
- The connection registry in `ConnectorService` is the truth about the machine;
  the physical constraint is one field of a record.
- RESET restores. It never rebuilds the machine, and it never recreates a
  constraint. TEST captures a snapshot; RESET puts every pivot back and zeroes
  velocities.
- DragDetectors run on the server (`RunLocally = false`). Client-side previews
  are guesses; the server always decides.
- A connected component moves with its whole assembly, so joints are never
  stretched during BUILD.
- Every tunable number and scene name lives in
  `src/shared/construction/ConstructionConfig.luau`. Server decisions and
  client previews read the same file.
- `PrototypeWorkshop` is a Studio-only harness. It never fabricates geometry in
  a live server, never overwrites `Workspace.Workshop`, and never writes
  runtime content back into the place file.
- `--!strict` everywhere. New Luau files start with it; existing files keep it.
- Physics feel and physics truth are different things. During TEST, Roblox may
  hand network ownership of an assembly to a nearby client - good for
  responsiveness. Challenge completion, attempt counts, scoring and unlocks
  must still be judged by the **server**, from its own view of the duck and the
  machine. Never from a client touch, a client-owned assembly, or a client
  claim.

## Automation & Logic invariants (WZ-LR3)

- Mechanical topology and signal topology are separate systems (`ConnectorService` vs `WiringService`).
- Signal wires never create physical constraints. They are massless, collisionless Beams representing information flow.
- Connector kinds (`Rigid`, `Axle`, `Rope`) belong to mechanics. Signal port directions (`Input`, `Output`) belong to logic.
- An unconnected actuator retains legacy automatic TEST behaviour.
- Connecting a control signal opts that actuator into automated control (`true` = ON, `false` = OFF).
- Workshop Zero simulates control logic, not electrical power distribution (no short circuits, voltages, or battery limits).
- Logic cycles must remain safe and deterministic (15 Hz tick evaluation, double-buffered state updates, non-recursive).
- RESET restores logic state and zeros velocities, but preserves signal wires; RESTART / CLEAR removes wires and resets inventory to rack.

## Repository map

```text
src/client    StarterPlayer.StarterPlayerScripts.WorkshopZero
src/server    ServerScriptService.WorkshopZero
src/shared    ReplicatedStorage.Shared

assets/source/hyper3d    untouched Hyper3D/Rodin originals
assets/source/blender    editable Blender sources
assets/export/roblox     clean Roblox-ready exports (named properly)
assets/references        sketches, photos, inspiration

place/      Studio-owned working place (geometry, lighting, meshes)
build/      generated, never committed
docs/       design, architecture, asset pipeline, environment, development
```

`default.project.json` maps **only** those three code containers. It must never
map `Workspace` or imported art: a Rojo rebuild that destroys hand-built Studio
content is the one failure this repository is designed to prevent.

## The sync rule

```text
USE:              Rojo
DO NOT ALSO USE:  Roblox Studio Script Sync
```

Mixing two script synchronization systems over the same files causes avoidable
conflicts and lost work. Rojo is the only one.

## Division of ownership

```text
Filesystem/Rojo owns:
    Luau
    configuration
    generated filesystem models later

Studio owns:
    Workspace level layout
    terrain
    imported meshes
    lighting iteration
    manual visual composition
```

## Not in scope yet

Do not add any of these until an explicit decision says otherwise:

```text
gameplay framework        ECS                      dependency injection
custom event bus          custom Promise system    persistence / DataStore
multiplayer building      currency                 inventory
analytics                 monetization             anti-cheat framework
complex UI architecture   custom physics framework
```

No Wally dependencies either. `wally.toml` exists so packages can be added
later without a migration, not so a framework can be pulled in today.
