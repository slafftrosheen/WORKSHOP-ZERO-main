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

Edit Luau in any text editor. Save. Rojo pushes the change into Studio, so the
next Play (or the running session) uses the new code.

## What each script does

| Script                | Purpose                                                        |
| --------------------- | -------------------------------------------------------------- |
| `scripts/doctor.ps1`  | Detects every tool, prints a status table, fails only when a tool required for coding/building is missing |
| `scripts/check.ps1`   | StyLua format check, Selene lint, Rojo build validation         |
| `scripts/build.ps1`   | Builds `build\WorkshopZero.rbxlx`; seeds `place\...rbxlx` once  |
| `scripts/dev.ps1`     | Starts `rojo serve` with plain-language Studio instructions     |

`scripts/_tools.ps1` is a small shared helper (finds tools, handles the Rokit
PATH). It is dot-sourced by the others; it is not meant to be run directly.

## Continuous integration

`.github/workflows/ci.yml` runs on every push and pull request on a Windows
runner:

```text
checkout -> install Rokit -> rokit install -> scripts/check.ps1 -> scripts/build.ps1
```

It deliberately installs neither Roblox Studio nor Blender: neither is needed to
verify code, and neither has a supported headless path here. If CI is green,
formatting, lint and the Rojo project are sound - it does **not** prove that
anything behaves correctly in a running game. That still needs a human in Play
mode.

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

## Playing with the construction kernel

Everything below happens in Studio, in Play mode.

### The prototype workshop

There is no authored level yet, so the server builds a runtime sandbox when it
is running in Studio:

```text
Workspace/WorkshopZeroRuntime
    Floor          big anchored slab
    BuildBounds    transparent volume a placement must stay inside
    WorkshopSpawn  where you start, just outside the build area
    Components     2 planks, 2 blocks, 4 wheels
    Connections    created as you snap things together
```

The harness steps aside if `Workspace.Workshop` ever exists, and it never
touches the place file: runtime content disappears when the session ends.

### Controls

| Input        | Result                                          |
| ------------ | ----------------------------------------------- |
| Click / tap  | Select a component (blue outline)               |
| Drag         | Move the selected component; connected parts come along |
| `Q` / `E`    | Rotate 15 degrees left / right                  |
| `R`          | Flip 90 degrees on the local X axis             |
| `X`          | Disconnect the selected component from everything |
| TEST button  | Unanchor everything and let physics run         |
| RESET button | Anchor, restore the exact build, come back to BUILD MODE |

While dragging, a green marker shows the connector pair that would be joined:
a sphere sits on the target connector and the target component is outlined.
The server decides for real when the drag is released.

### Reading the logs

The server prints a small set of lines, in Studio only, when useful things
happen:

```text
[WZ] State Build -> Testing
[WZ] State Testing -> Resetting
[WZ] State Resetting -> Build
[WZ] Connected Plank.Rigid_A -> Block.Rigid_B (Rigid)
[WZ] Disconnected Plank.Rigid_A - Block.Rigid_B
```

Nothing logs per frame. If a log line would fire every Heartbeat, it does not
belong.

### Where the numbers live

Snap distance, angle tolerance, build area, rotation steps and every scene name
are in `src/shared/construction/ConstructionConfig.luau`. Change a number there
before touching geometry code - the client preview and the server decision read
the same file.

## Rojo vs Studio Script Sync

```text
USE:              Rojo
DO NOT ALSO USE:  Roblox Studio Script Sync
```

Both systems own the same scripts, and mixing them causes conflicts and lost
work. Keep Script Sync off for this repository. Two-way sync / syncback in the
Rojo plugin also stays **off**: Rojo is a one-way street, filesystem -> Studio,
for code only.

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

**Nothing to build with: no components appear.**
The runtime workshop only exists in Studio. Check the server Output for
`[WZ] Runtime workshop ready with 8 components`. If it is missing, the server
script did not start - confirm the Rojo plugin is connected and that the place
was opened from `place\`.

**A machine will not snap.**
Alignment matters: a connector must face the connector it is joining, within
`SnapAngleToleranceDegrees`. Use `Q`/`E`/`R` to face it, then release the drag
closer. `Rigid` only meets `Rigid`, and `Axle` only meets `Axle`.

**TEST does not respond.**
Only the phase you are in accepts its action: TEST works in BUILD MODE, RESET
works while TESTING, and a request during RESETTING is ignored on purpose.

**Somebody rebuilt and the Workshop disappeared.**
That is what the place-file rule prevents. Reopen
`place\WorkshopZeroPrototype.rbxlx`; geometry lives there, not in `build\`.
