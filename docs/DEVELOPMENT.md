# Workshop Zero - Development

> [!IMPORTANT]
> **Core Architecture Rules:**
> - **Visual assets are replaceable skins over stable Workshop Zero physics contracts.**
> - **Missing art must never make an experiment unplayable.**

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

## Playing the Experiments

Everything below happens in Studio, in Play mode.

### The Levels

By default the server builds the first experiment (`save_the_duck`) and progresses through the suite. You can also override the starting experiment in Studio by setting `DevExperimentId` in `src/shared/construction/ConstructionConfig.luau`:
- `"save_the_duck"` (Experiment 001)
- `"uphill_delivery"` (Experiment 002)
- `"over_the_wall"` (Experiment 003)
- `"windy_business"` (Experiment 004)
- `"lift_off"` (Experiment 005)
- `"dont_hit_the_wall"` (Experiment 006)
- `"two_to_go"` (Experiment 007)
- `"open_sesame"` (Experiment 008)
- `"make_room"` (Experiment 009)
- `"open_workshop"` (Open Workshop free build)

The Workshop structure is strictly partitioned:
```text
Workspace/Workshop
    Shell               persistent workshop environment (workbench, rack, wall panels, board, crates, spawn)
    ExperimentBay       swappable level container (cleared and rebuilt on experiment transition)
        Level geometry  (trenches, ramps, barrier walls, glide tracks, high platforms & gantries)
        BuildBounds     invisible legal build volume
        Duck            the payload (WZ_Payload), anchored while building
        GoalButton      giant red button with an invisible trigger
        Components      parts rack tailored to the active experiment
        Connections     created as you snap things together (welds, hinges, ropes)
```

The old kernel sandbox (`Workspace/WorkshopZeroRuntime`) is still available for
kernel work: set `EnablePrototypeWorkshop = true` in
`src/shared/construction/ConstructionConfig.luau` and Play again.

### Controls

| Input        | Result                                          |
| ------------ | ----------------------------------------------- |
| Click / tap  | Select a component (blue outline)               |
| Click empty space | Deselect active component                  |
| `Escape`     | Clear selection (desktop)                       |
| Drag         | Move the selected component; connected parts come along |
| `Q` / `E`    | Rotate 15 degrees left / right (desktop)        |
| `R`          | Flip 90 degrees on the local X axis (desktop)   |
| `X`          | Disconnect the selected component (desktop)     |
| ↺ ↻ FLIP DISCONNECT | Touch buttons, shown while a component is selected on touch devices |
| Click Output socket | Enter wiring mode: highlights compatible inputs, draws preview beam |
| Click Input socket | Connect wire (or disconnect existing wire if already wired) |
| `Escape` / empty click | Cancel wiring preview mode |
| [ ☰ EXPERIMENTS ] | Top-left HUD button to open the Experiment Board selector |
| TEST MACHINE | Unanchor everything - duck included - physics runs |
| RESET button | Restore the exact build, duck back to its mark, BUILD MODE |
| NEXT EXPERIMENT | Success panel: progress to the next experiment  |
| TRY AGAIN    | Success panel only: full experiment restart     |
| F8           | Studio-only debug overlay (states, attempt, speeds, axles, fans, logic nodes, wires, active signals, controlled actuators, tick rate) |

While dragging, a green marker shows the connector pair that would be joined:
a sphere sits on the target connector and the target component is outlined.
The held component is also outlined. The server decides for real when the drag
is released; a green pulse marks the joint it actually made.

### Reading the logs

The server prints a small set of lines, in Studio only, when useful things
happen:

```text
[WZ Assets]
  Duck         primitive
  GoalButton   primitive
  Plank        primitive
  Block        primitive
  Wheel        primitive
  Motor        primitive
  Spring       primitive
  Fan          primitive
[WZ] Loaded Experiment 002: UPHILL DELIVERY
[WZ Motor] 2 powered axle(s) active
[WZ Spring] reset 2 spring(s)
[WZ Fan] 1 active fan(s) engaged
[WZ] State Build -> Testing
[WZ] State Testing -> Resetting
[WZ] State Resetting -> Build
[WZ] Experiment Build -> Testing
[WZ] Attempt 1 started: 5 part(s) used
[WZ] Flavour event WheelsUp: WHEELS UP. NOT IDEAL.
[WZ] Experiment Testing -> Success
```

### Playtest diagnostics

With `PlaytestDiagnostics = true` (the default, Studio only) every attempt
prints a summary when it ends:

```text
[WZ] Attempt 3
    Duration before Reset: 9.4s
    Connections: 3
    Parts moved: 5
    Duck max speed: 26.1
    Duck max height: 12.8
    Result: Reset
```

This is how a parent observes how their children actually solve the challenge.
It is Output only: nothing is stored, uploaded or shown to players.

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
The level is built by the server at the start of Play. Check the server Output
for `[WZ] SAVE THE DUCK is ready (Get the duck to the button.)`. If it is
missing, the server script did not start - confirm the Rojo plugin is connected
and that the place was opened from `place\`. If `Workspace.Workshop` already
exists and was **not** generated this session (no `WZ_Generated` attribute),
the builder refuses to touch it and the workshop stays empty by design.

**A machine will not snap.**
Alignment matters: a connector must face the connector it is joining, within
`SnapAngleToleranceDegrees`. Use `Q`/`E`/`R` to face it, then release the drag
closer. `Rigid` only meets `Rigid`, and `Axle` only meets `Axle`.

**TEST does not respond.**
Only the phase you are in accepts its action: TEST MACHINE works in BUILD MODE,
RESET works while TESTING, a request during RESETTING is ignored on purpose,
and a finished experiment (Success) can only be restarted with TRY AGAIN - not
reset.

**The duck fell through the world and vanished / froze.**
Below the cleanup threshold the payload is anchored where it stopped so physics
cannot grind forever. It is not a bug and not a reset: press RESET when you are
done inspecting the disaster.

**Somebody rebuilt and the Workshop disappeared.**
That is what the place-file rule prevents. Reopen
`place\WorkshopZeroPrototype.rbxlx`; geometry lives there, not in `build\`.
