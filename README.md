# Workshop Zero

Build ridiculous machines to solve ridiculous problems.

Workshop Zero is a family-built educational physics and construction game for
Roblox. Players meet a silly problem, physically construct something to solve
it, test it, watch it fail, change one thing, and test again. Learning happens
through the machine, not through a quiz.

**The Four Experiments Suite** is now fully playable, built on the
construction kernel that every experiment shares:

```text
BUILD  ->  TEST  ->  RESET  ->  BUILD again
problem -> build -> TEST -> fail -> modify -> TEST again -> succeed -> discovery -> next
```

1. **Experiment 001 — Save the Duck**: Passive construction, beams, gap traversal, and structural physics.
2. **Experiment 002 — Uphill Delivery**: Powered motors and driven wheels, overcoming gravity and traction up a ramp.
3. **Experiment 003 — Over the Wall**: Stored energy and compression physics with a spring launcher to clear a 12-stud obstacle.
4. **Experiment 004 — Windy Business**: Motor-powered propeller fan generating directional airflow to glide the duck without touching it.

## What is in here

```text
src/client    StarterPlayer.StarterPlayerScripts.WorkshopZero
src/server    ServerScriptService.WorkshopZero
src/shared    ReplicatedStorage.Shared

assets/       source art, Blender files, Roblox-ready exports, references
place/        the Studio-owned working place
build/        disposable build output (never committed)
docs/         design, architecture, asset pipeline, environment, development
scripts/      doctor / check / build / dev PowerShell commands
```

> [!IMPORTANT]
> **Core Architecture Invariants:**
> - **Visual assets are replaceable skins over stable Workshop Zero physics contracts.**
> - **Missing art must never make an experiment unplayable.**

You can already play the first experiment end to end: a duck, a gap, a giant
red button, eight parts on a rack. Everything works out of the box with procedural
primitives, while the new `AssetProvider` bridge allows custom Hyper3D/Blender
models to be dropped in without changing physics code. See **Experiment 001 - Save the Duck** below.

## Prerequisites

| Need                | Why                                    |
| ------------------- | -------------------------------------- |
| Windows 10/11       | primary development machine            |
| Git + Git LFS       | version control, large art files       |
| Rokit               | manages every Roblox tool below        |
| Roblox Studio       | opening the place, testing in Play     |
| Blender             | asset cleanup before Roblox import     |
| A code editor       | Codex, VS Code or anything else        |

Roblox Studio is installed and signed in manually - never from the command
line, never from a mirror.

## First machine setup

Run these once per machine.

```powershell
# 1. Git (skip if git --version already works)
winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
git lfs install

# 2. Blender (skip if blender --version already works)
winget install --id BlenderFoundation.Blender -e --source winget --accept-source-agreements --accept-package-agreements

# 3. Rokit, the Roblox toolchain manager
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression

# 4. Roblox Studio: install and sign in by hand
#    https://create.roblox.com/  (official page only, no mirrors)
```

Then, in this repository:

```powershell
rokit install          # installs everything pinned in rokit.toml
rojo plugin install    # installs the Studio plugin (needs Studio on the machine)
```

## Verify the environment

```powershell
.\scripts\doctor.ps1
```

It prints one row per tool: `OK`, `MISSING` or `WARN`.

- `MISSING` on Git, Git LFS, Rokit, Rojo, Wally, Selene, StyLua or Luau LSP
  makes the script exit non-zero: fix it before coding.
- `WARN` on Roblox Studio or Blender is fine for code work. Studio is still
  required for Play testing, Blender for art.

The recorded state of the current machine is in `docs/ENVIRONMENT.md`.

## Run checks

```powershell
.\scripts\check.ps1
```

This runs, in order:

```text
StyLua format check   stylua --check src
Selene lint           selene src
Rojo build check      rojo build default.project.json -> throwaway file
```

Exit code 0 means the batch is safe to commit. Run it before calling any
coding batch complete.

The same three checks run in CI on every push and pull request
(`.github/workflows/ci.yml`), on a Windows runner, followed by
`scripts/build.ps1`. CI proves code health only - it never opens Studio.

## Build

```powershell
.\scripts\build.ps1
```

Produces `build\WorkshopZero.rbxlx` from `default.project.json`.

On the very first run it also seeds `place\WorkshopZeroPrototype.rbxlx`, the
place you actually work in. After that the seed never happens again: a rebuild
can never delete hand-built Workshop geometry, lighting or imported meshes.

To verify the build without generating anything real, use `check.ps1`: it
builds to a throwaway file and deletes it.

## Start Rojo

```powershell
.\scripts\dev.ps1
```

Keep that window open. It prints the human instructions, then runs:

```text
rojo serve default.project.json     (127.0.0.1:34872)
```

## Open the place in Studio

```text
place\WorkshopZeroPrototype.rbxlx
```

Double-click it, or open it from Studio's File menu. Studio owns this file:
geometry, terrain, lighting, imported meshes.

## Connect Studio to Rojo

1. In Studio, open the **Rojo** plugin (Plugins tab).
2. Press **Connect** (localhost, default port 34872).
3. Press **Play**.

Studio's Output window should show:

```text
[WorkshopZero] Server bootstrap 0.0.1-dev
[WorkshopZero] Client bootstrap 0.0.1-dev
```

If both lines appear, the whole pipeline works: Git -> Rokit tools -> Rojo ->
Studio -> running Luau.

Save the place afterwards so your geometry stays in `place\`.

## Experiment 001 - Save the Duck

The workshop floor has a trench cut through it. A duck waits on the start pad;
a giant red button waits across the gap. You get two planks, two blocks and
four wheels, staged on a rack beside you. Build anything. Press
**TEST MACHINE**. Physics decides.

| Input         | Result                                                    |
| ------------- | --------------------------------------------------------- |
| Click / tap   | Select a part (blue outline)                               |
| Drag          | Move it - parts that are joined come along                 |
| `Q` / `E`     | Rotate 15 degrees left / right (desktop)                   |
| `R`           | Flip 90 degrees (desktop)                                  |
| `X`           | Disconnect the selected part (desktop)                     |
| ↺ ↻ FLIP / DISCONNECT | The same actions as large buttons (phones/tablets) |
| TEST MACHINE  | Unanchor everything - duck included - and let physics run   |
| RESET         | Restore the exact machine you built; duck back to its mark  |
| TRY AGAIN     | Full restart: joints removed, parts re-racked, attempts zeroed |

Rules of the world:

- Only the duck can press the button. A plank on the trigger wins nothing.
- RESET keeps your machine exactly as built - change one thing, test again.
- TRY AGAIN is the full restart and lives only on the success panel.
- Failure messages ("BALLISTIC DUCK.") are flavour, not judgement. You decide
  when an attempt is over.
- The avatar cannot kick the machine or the duck: players pass through parts
  and payloads by design.

Drag a plank's end near a block and the connectors snap together: rigids weld,
axles become spinning hinges. While dragging, a green marker shows the joint
that would be made, and a pulse confirms the joint the server actually made.

More detail, log lines and troubleshooting live in `docs/DEVELOPMENT.md`.

## The one synchronization rule

```text
USE:              Rojo
DO NOT ALSO USE:  Roblox Studio Script Sync
```

Rojo owns code. Studio owns the scene. Two syncing systems over the same files
is how a family loses an afternoon of work.

Two-way sync / syncback in the Rojo plugin also stays off.

## Where art goes

| Kind                         | Folder                        |
| ---------------------------- | ----------------------------- |
| Hyper3D / Rodin originals    | `assets/source/hyper3d/<name>/` |
| Editable Blender sources     | `assets/source/blender/`      |
| Roblox-ready exports (GLB)   | `assets/export/roblox/`       |
| Sketches and references      | `assets/references/`          |

Large binaries are stored through Git LFS. Origins are never overwritten, and
clean exports are renamed properly (`wheel_rubber_01`, not `mesh3`).

Details, budgets and the Studio import checklist: `docs/ASSET_PIPELINE.md`.

## Repository rules in one glance

- Luau uses `--!strict`. The server is authoritative; the client presents.
- Small modules. No frameworks until complexity proves they are needed.
- `wally.toml` exists and is intentionally empty today.
- Never commit `Packages/`, `ServerPackages/`, `DevPackages/` or `build/`.
- Never commit secrets, and never put API keys in Roblox code.
- Agent-facing rules live in `AGENTS.md`.

## Documentation

| Document                     | Contents                                  |
| ---------------------------- | ----------------------------------------- |
| `docs/GAME_DESIGN.md`        | fantasy, core loop, scope, and non-goals  |
| `docs/ARCHITECTURE.md`       | mapping, ownership, code rules            |
| `docs/ASSET_PIPELINE.md`     | Hyper3D -> Blender -> Studio, budgets     |
| `docs/ASSET_WISHLIST.md`     | future assets and Hyper3D prompts         |
| `docs/ENVIRONMENT.md`        | detected tools, versions, manual steps    |
| `docs/DEVELOPMENT.md`        | daily workflow and troubleshooting        |
| `AGENTS.md`                  | rules for AI coding sessions              |

## Status

**LONG-RUN-001** — From Prototype to Small Playable Game.
Four complete, connected experiments in an authoritative session loop:
1. `save_the_duck`: Passive construction, cantilever beams, gap crossing.
2. `uphill_delivery`: Powered motor, traction wheels, climbing a broad incline.
3. `over_the_wall`: Real compression spring launcher with internal prismatic/spring constraints, clearing a 12-stud barrier.
4. `windy_business`: Motor-driven aerodynamic propeller fan with distance falloff, clearing the glide track without physical contact.

**Features in place:**
- Modular experiment lifecycle (`ExperimentRegistry`, `ExperimentService.LoadExperiment`).
- Powered mechanical actuators (`ActuatorService`) driving axle hinges during TEST without per-frame scripting.
- Physical aerodynamic forces (`BehaviourService`) applying constraint `VectorForce` during TEST.
- Multi-part components with internal constraint simulation (`SpringBuilder`, `FanBuilder`).
- Component-aware anchoring and drift-free transform restoration.
- Session unlocks (001 -> 004) with authoritative server validation and locked Experiment Board UI.
- Discovery cards on experiment success with grounded physics copy.
- Mobile-responsive UI with HUD tray, top-left experiment cards, and Altered-Machine leave confirmation.
- Asset bridge (`AssetProvider`) supporting drop-in replacement art without breaking physics.

**What explicitly remains out of scope:**
DataStore persistence, currency, XP/stars, loot, pets, trading, monetization, gears/chains/winches, logic gates/sensors, multiplayer construction plots.
