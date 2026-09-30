# Workshop Zero - Architecture

Status: **BOOTSTRAP-001**. There is almost no code yet, and that is deliberate.

## What exists

```text
ReplicatedStorage.Shared.ProjectInfo          immutable project facts
ServerScriptService.WorkshopZero.Bootstrap    prints the server banner
StarterPlayerScripts.WorkshopZero.Bootstrap   prints the client banner
```

Rojo mapping lives in `default.project.json`:

```text
ReplicatedStorage
└── Shared
    └── src/shared

ServerScriptService
└── WorkshopZero
    └── src/server

StarterPlayer
└── StarterPlayerScripts
    └── WorkshopZero
        └── src/client
```

Nothing else is mapped. `Workspace` is explicitly **not** mapped, so a Rojo
sync can never delete hand-built Workshop geometry.

## Ownership

```text
Filesystem / Rojo owns:      Luau, configuration, generated models later
Roblox Studio owns:          Workspace layout, terrain, imported meshes,
                             lighting iteration, manual composition
```

## Sync rule

```text
USE:              Rojo
DO NOT ALSO USE:  Roblox Studio Script Sync
```

Two synchronization systems over the same files is how work disappears.
Rojo is the only one in this repository. Two-way sync / syncback stays off.

## Code rules

- Every Luau file starts with `--!strict`.
- Server is authoritative. The client asks; the server decides.
- Prefer small modules with one clear job.
- No frameworks yet. `wally.toml` is configured and intentionally empty.
- Generated folders (`Packages/`, `ServerPackages/`, `DevPackages/`, `build/`)
  are never edited or committed.

## State ownership (for later, not now)

```text
Server owns:
    challenge state, machine validation, unlocks, future currency

Client owns:
    input, presentation, local prediction
```

## Deliberately absent

No ECS, no dependency injection, no event bus, no custom Promise library, no
persistence, no DataStore, no analytics, no anti-cheat framework, no UI
architecture, no custom physics framework.

Complexity is added when a proven need appears - not before.

## Adding dependencies later

1. `rokit` version stays pinned in `rokit.toml`.
2. Add the package to `wally.toml`, run `wally install`.
3. Map `ReplicatedStorage.Packages` to `Packages/` in `default.project.json`
   **at that moment**, not before - Rojo fails on a `$path` that does not exist.
