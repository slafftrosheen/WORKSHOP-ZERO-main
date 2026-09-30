# AGENTS.md - Workshop Zero

Instructions for AI coding agents (Codex and friends) working in this repository.
Read this before changing anything.

## What this project is

Workshop Zero is a Roblox physics/building game. Players solve ridiculous
problems by building ridiculous machines, testing them, watching them fail,
changing one thing and testing again.

The first planned prototype is **Experiment 001 - Save the Duck**.
It is not implemented yet. Do not start it opportunistically.

## Hard rules

- Luau uses `--!strict`.
- Server owns authoritative game state.
- Client owns input, presentation and local prediction only.
- Do not trust client claims for challenge completion, inventory, unlocks or
  future currency.
- Prefer small modules.
- Avoid frameworks until complexity proves they are needed.
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
