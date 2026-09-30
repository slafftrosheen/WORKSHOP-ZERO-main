# Workshop Zero - Development

## The daily loop

```powershell
.\scripts\doctor.ps1     # is my machine still healthy?
.\scripts\check.ps1      # formatting, lint, project builds
.\scripts\dev.ps1        # start Rojo, then use Studio
```

Then, in Roblox Studio:

```text
open place\WorkshopZeroPrototype.rbxlx
open the Rojo plugin
connect
press Play
```

Edit Luau in any text editor. Save. Rojo pushes the change into Studio while
Play is running, so the next test uses the new code.

## What each script does

| Script                | Purpose                                                        |
| --------------------- | -------------------------------------------------------------- |
| `scripts/doctor.ps1`  | Detects every tool, prints a status table, exits non-zero only if a tool required for coding/building is missing |
| `scripts/check.ps1`   | StyLua format check, Selene lint, Rojo build validation         |
| `scripts/build.ps1`   | Builds `build\WorkshopZero.rbxlx`; seeds `place\...rbxlx` once  |
| `scripts/dev.ps1`     | Starts `rojo serve` with plain-language Studio instructions     |

`scripts/_tools.ps1` is a small shared helper (finds tools, handles the Rokit
PATH). It is dot-sourced by the others; it is not meant to be run directly.

## Toolchain

Pinned in `rokit.toml` and installed by Rokit:

```text
Rojo 7.7.0   Wally 0.3.2   Selene 0.31.0   StyLua 2.5.2   Luau LSP 1.70.1
```

Useful commands:

```powershell
rokit install        # install everything rokit.toml pins
rokit list           # what is pinned and where it lives
stylua src           # format
stylua --check src   # verify formatting (what check.ps1 runs)
selene src           # lint (what check.ps1 runs)
rojo build default.project.json --output build\WorkshopZero.rbxlx
rojo serve default.project.json
rojo plugin install  # install/refresh the Studio plugin
```

## Rojo vs Studio Script Sync

```text
USE:              Rojo
DO NOT ALSO USE:  Roblox Studio Script Sync
```

Both systems own the same scripts, and mixing them causes conflicts and lost
work. Keep Script Sync off for this repository.

Two-way sync / syncback in the Rojo plugin also stays **off**. Rojo is a
one-way street: filesystem -> Studio, for code only.

## What Rojo owns, and what Studio owns

```text
Rojo:    src/client, src/server, src/shared -> mapped services
Studio:  Workspace layout, terrain, imported meshes, lighting, manual layout
```

If you need a new mapped container, change `default.project.json`
deliberately. Do not add `Workspace` to it.

## Working with the place file

- `place\WorkshopZeroPrototype.rbxlx` is the Studio working place and is
  versioned in Git. Save it in Studio when you change geometry.
- `build\WorkshopZero.rbxlx` is disposable output and is never committed.
- `scripts\build.ps1` seeds the place file **once** and never overwrites it.
  Rebuilding can therefore never destroy hand-built Workshop geometry.
- Commit place changes deliberately and separately from code changes when you
  can: a huge XML diff hides a one-line code change.

## Adding a Wally dependency later

Today there are none, on purpose.

1. Add it to `wally.toml`.
2. `wally install`
3. Add the mapping to `default.project.json`:

```json
"ReplicatedStorage": {
  "$className": "ReplicatedStorage",
  "Shared": { "$path": "src/shared" },
  "Packages": { "$path": "Packages" }
}
```

4. Commit `wally.toml` and `wally.lock`.
   Never commit `Packages/` - it is generated.

## Troubleshooting

**`rojo` is not recognised in a brand new terminal.**
Rokit installs shims to `%USERPROFILE%\.rokit\bin`. Open a new terminal, or use
the project scripts, which add that folder to PATH for themselves.

**Rojo plugin cannot connect.**
Is `scripts\dev.ps1` still running in its own window? Rojo listens on
`127.0.0.1:34872`. Press Connect in the plugin, not Play.

**Studio shows two copies of a script.**
Script Sync is probably on. Turn it off; Rojo owns code.

**`check.ps1` fails on formatting.**
Run `stylua src`, then run the check again.

**Somebody rebuilt and the Workshop disappeared.**
That is what the place-file rule prevents. Reopen
`place\WorkshopZeroPrototype.rbxlx`; geometry lives there, not in `build\`.
