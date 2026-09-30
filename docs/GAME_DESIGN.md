# Workshop Zero - Game Design

Status: **LONG-RUN-001**. This document is a compass, not a spec.

The construction kernel (BUILD / TEST / RESET) serves four fully connected, playable experiments:
- **Experiment 001 - Save the Duck**: Structure, spans, gravity, cantilever beams.
- **Experiment 002 - Uphill Delivery**: Powered motors, rotation, torque, and traction up an incline.
- **Experiment 003 - Over the Wall**: Stored energy, compression physics, spring launcher over a 12-stud obstacle.
- **Experiment 004 - Windy Business**: Directional airflow, propeller thrust, non-contact glide track mechanics.

## Core fantasy

Build ridiculous machines to solve ridiculous problems.

## Core loop

```text
problem
  -> collect / choose components
  -> construct
  -> TEST
  -> observe failure
  -> modify
  -> TEST again
  -> succeed
  -> discovery
  -> next experiment
```

## Education model

Knowledge through physical interaction and experimentation.

A player should learn why a machine failed by watching it fail, not by reading
a sentence about it. No quiz popups. No "correct answer" buttons. Educational
concepts emerge through play before explanatory copy appears.

## Failure

Failure is celebrated rather than punished. A machine that collapses in a
spectacular new way is progress. Nothing should take a component away from a
player as a punishment. Flavour messages joke about the outcome, never the child.

## Playable experiments

### Experiment 001: Save the Duck

```text
A duck. A trench. A giant red button across the gap.
2 planks, 2 blocks, 4 wheels. Build anything. TEST. Physics decides.
```

- **Inventory**: 2 Planks, 2 Blocks, 4 Wheels.
- **Problem**: 14-stud gap separating start pad and goal pad.
- **Concept**: Structure, spans, gravity, unpowered rolling.
- **Discovery**: "Longer beams bend the problem around you."

---

### Experiment 002: Uphill Delivery

```text
                    🔴 GOAL
                 ┌─────────────┐
                /              │
               /  RAMP         │
              /   (incline)    │
   START     /                 │
┌───────────┘                  │
```

```text
Get the duck up the ramp to the button.
3 planks, 3 blocks, 6 wheels, 2 motors.
```

#### Educational concept

The learning progression happens strictly through mechanical feedback:

```text
rotation
  -> torque
  -> traction
  -> mass
  -> center of gravity
  -> powered motion
```

No tutorial popups explain gear ratios or normal forces. Instead:
- **Torque & Incline**: A single-motor cart might stall or spin if it lacks sufficient torque to climb the 10-stud incline. Adding a second motor doubles available drive torque.
- **Traction & Slip**: Wheels without enough downward load will spin freely against the ramp surface (`FULL THROTTLE, NO TRACTION`).
- **Mass & Stability**: Placing the duck high or too far back causes wheelies and flips (`WHEELS UP. NOT IDEAL.`). Building a wider, lower-center-of-gravity chassis climbs stably.
- **Symmetry**: Placing motors on both sides of a cart causes their axles to point in opposite outward directions. The actuator system cooperatively coordinates rotation signs so both wheels roll forward together.

#### Inventory

- 3 Planks, 3 Blocks, 6 Wheels, 2 Motors.

#### Discovery

"Rotation becomes movement when wheels can push against the ground."

---

### Experiment 003: Over the Wall

```text
                🔴 GOAL
               ┌──────┐

        ███████████████
        █    WALL     █ (12 studs high)
        ███████████████

🦆 START
```

```text
Get the duck over the wall to the button.
3 planks, 4 blocks, 4 wheels, 1 motor, 2 springs.
```

#### Educational concept

```text
compression
  -> potential energy stored in spring
  -> rapid release
  -> kinetic energy & vertical trajectory
```

- **Compression & Release**: Placing the duck on the spring plunger or driving into it compresses the spring along its prismatic axis. Releasing or snapping upward transfers kinetic momentum to launch the payload over the wall.
- **Alternative solutions**: A high ramp with a motor car, a catapult lever, or a stacked tower are equally valid. Never encode the intended launcher as the only valid solution.

#### Inventory

- 3 Planks, 4 Blocks, 4 Wheels, 1 Motor, 2 Springs.

#### Discovery

"A compressed spring can release its energy very quickly."

---

### Experiment 004: Windy Business

```text
🦆 START ──[ low friction glide track ]──> FORBIDDEN GAP ──> 🔴 GOAL
                                            (no touch!)
```

```text
Move the duck to the button without touching it.
2 planks, 4 blocks, 2 wheels, 2 motors, 2 fans.
```

#### Educational concept

```text
motor rotation
  -> aerodynamic propeller blades
  -> directional airflow & distance falloff
  -> non-contact applied force
```

- **Non-contact Rule**: The server tracks physical collisions with the duck. If any construction component physically touches the duck during TEST, the attempt cannot succeed (`THAT COUNTS AS TOUCHING.`).
- **Fan thrust & Airflow**: Connecting a Fan's `Axle_Input` directly to a Motor axle powers the fan. Airflow blows forward with a quadratic distance falloff up to 32 studs, blowing the duck across the frictionless glide track without physical contact.
- **Reaction force**: The fan itself receives an equal and opposite reaction force, enabling propeller cars.

#### Inventory

- 2 Planks, 4 Blocks, 2 Wheels, 2 Motors, 2 Fans.

#### Discovery

"You can move something without touching it directly."

---

## Session progression & Unlocks

- **Authoritative Unlocks**: Starts with Experiment 001 unlocked (`unlockedIndex = 1`). Success in experiment $N$ unlocks experiment $N + 1$.
- **Experiment Board**: Accessible anytime via the HUD button `[ ☰ EXPERIMENTS ]` or after success. Displays experiment cards; locked experiments display `???`.
- **Altered-Machine Confirmation**: Selecting another experiment while having modified the current machine displays a clean confirmation (`LEAVE THIS EXPERIMENT? Your current machine will be cleared.`).
- **No Persistence**: All progression is session-local. No DataStore is used.

## Components

| Component | State                                                  | Description |
| --------- | ------------------------------------------------------ | ----------- |
| Plank     | Active                                                 | Long structural beam (12x1x2), 6 rigid mounts |
| Block     | Active                                                 | Modular structural cube (3x3x3), 6 rigid mounts |
| Wheel     | Active                                                 | Rolling cylinder (1x4x4), 2 axle connectors |
| Motor     | Active                                                 | Powered rotary drive (2x2x2), 1 rigid mount, 1 axle output |
| Spring    | Active                                                 | Compression launcher (3x2.5x3), 1 rigid mount, internal plunger |
| Fan       | Active                                                 | Aerodynamic propeller (0.8x3.2x3.2), 1 rigid mount, 1 axle input |

`ExperimentState` (challenge lifecycle) is deliberately separate from
`SimulationState` (physics truth). Success freezes the *experiment*, not
physics: the player watches what their machine did before the success panel
even appears.

### Normal RESET vs TRY AGAIN

This distinction is a core Workshop Zero principle:

- **RESET** (after a failed test) restores the machine exactly as built. Parts
  stay where the player put them. Actuators are disabled first before snapshot
  transforms are restored. The loop is build -> test -> fail -> change one thing
  -> test again.
- **TRY AGAIN** (`RestartExperiment`) removes every connection, returns every
  part to its rack position, restores rotation, duck, button and attempts.
  It exists on the success panel.
- **NEXT EXPERIMENT** (`NextExperiment`) tears down the completed workshop, clears
  the connector and actuator registries, and builds the next level in-place.

## Components

| Component | State                                                  |
| --------- | ------------------------------------------------------ |
| Plank     | Active (Exp 001: 2 available, Exp 002: 4 available)    |
| Block     | Active (Exp 001: 2 available, Exp 002: 4 available)    |
| Wheel     | Active (Exp 001: 4 available, Exp 002: 6 available)    |
| Motor     | Active in Exp 002 (2 available, 1 rigid mount, 1 axle) |
| Spring    | Placeholder - defined, refused by the factory          |

Spring and Motor exist in the catalogue as placeholders and MUST NOT appear in
any playable inventory until they actually do something.

## Interactions

| Interaction | State in WZ-002                                   |
| ----------- | ------------------------------------------------- |
| Grab / Move | dragging a component, with its assembly following |
| Rotate      | `Q` / `E` in 15 degree steps, `R` to flip 90; large touch buttons on mobile |
| Connect     | automatic snap, with preview while dragging and a pulse on the joint made |
| Disconnect  | `X` on desktop, DISCONNECT button on touch; releases every joint on the selection |
| Test        | TEST MACHINE button: unanchor everything, duck included  |
| Reset       | RESET button: restore the exact build, zero velocity |
| Restart     | TRY AGAIN on the success panel: full experiment restart |

Delete is deliberately not implemented yet: nothing in the loop should be able
to lose a component while the kernel is being proven.

## Construction kernel (WZ-001)

Infrastructure, not gameplay. It gives every future experiment the same three
phases, so a challenge only has to describe a problem and a win condition:

```text
BUILD   anchored parts, drag, rotate, snap, disconnect
TEST    unanchored, Roblox physics owns the machine
RESET   restore the exact build, return to BUILD
```

Design rules that follow from it:

- Failure is cheap: RESET always returns the machine exactly, so experimenting
  is free.
- Joints are recorded as data, not just physics, so future teaching moments can
  read the machine without guessing.
- Nothing is punished, saved or scored yet. That is the point.

## Explicitly out of scope

There is currently:

```text
NO currency
NO monetization
NO pets
NO loot boxes
NO battle pass
NO XP grind
NO trading
```

Those systems stay out of scope until the core construction loop is fun.

## Future hooks (do not build now)

Ideas worth remembering, and worth ignoring until the loop is fun:

- Team builds: two children building one machine together.
- Experiment 002+ as a family of physics problems, escalating in absurdity.
- A "family wall" of saved machine snapshots to compare attempts.
