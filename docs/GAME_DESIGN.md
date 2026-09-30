# Workshop Zero - Game Design

Status: **WZ-002**. This document is a compass, not a spec.

The construction kernel (BUILD / TEST / RESET) exists as infrastructure, and
the first experiment is now playable on top of it. Everything after Experiment
001 is still undesigned - the kernel is there so that the next experiment can
also be about a duck-level idea rather than about plumbing.

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
  -> succeed ... or discover something better
```

## Education model

Knowledge through physical interaction and experimentation.

A player should learn why a machine failed by watching it fail, not by reading
a sentence about it. No quiz popups. No "correct answer" buttons.

## Failure

Failure is celebrated rather than punished. A machine that collapses in a
spectacular new way is progress. Nothing should take a component away from a
player as a punishment.

## First playable: Experiment 001 - Save the Duck

Implemented in WZ-002 with Roblox primitives only.

```text
A duck. A trench. A giant red button across the gap.
2 planks, 2 blocks, 4 wheels. Build anything. TEST. Physics decides.
```

### Rules

- The player receives exactly 2 Planks, 2 Blocks, 4 Wheels, staged on a rack
  inside the build area.
- Any physically valid solution wins. There is no hidden solution and no
  scripted expected machine. A bridge, a cart, a ramp, a catapult-shaped
  accident and a collapsing tower are all equally valid.
- Only the duck activates the goal. The server validates payload identity, not
  names, and never trusts a client claim.
- The level is readable and exaggerated: pads a step high, a 14-stud trench,
  everything at ground level so nobody gets stranded.

### The experiment lifecycle

```text
Loading -> Build -> Testing -> Success
                ^          |
                +-- RESET -+   (machine restored, duck re-marked)

TRY AGAIN = full restart (Build): joints removed, parts re-racked,
attempts zeroed, duck and button restored
```

`ExperimentState` (challenge lifecycle) is deliberately separate from
`SimulationState` (physics truth). Success freezes the *experiment*, not
physics: the player watches what their machine did before the success panel
even appears.

### Normal RESET vs TRY AGAIN

This distinction is a core Workshop Zero principle:

- **RESET** (after a failed test) restores the machine exactly as built. Parts
  stay where the player put them. The loop is build -> test -> fail ->
  change one thing -> test again.
- **TRY AGAIN** (`RestartExperiment`) removes every connection, returns every
  part to its rack position, restores rotation, duck, button and attempts.
  It exists only on the success panel.

### Failure is content

> Failure is part of gameplay. Never automatically reset a funny failure unless
> continuing would break the runtime.

The FailureObserver surfaces short flavour lines at most once per event per
attempt: DUCK DOWN. / UNSCHEDULED DUCK DEPARTURE. / BALLISTIC DUCK. / SPACE
PROGRAM STARTED. / STRUCTURAL OPTIMISM DETECTED. It never ends an attempt and
never judges the player - the laugh is aimed at the machine. The only automatic
intervention is freezing a payload that falls below the cleanup threshold, so
physics cannot grind forever; the player still chooses RESET.

> Do not tell the player how to solve an experiment if the physics can teach
> them.

The intro card is three short lines. No tutorial wall, no solution hints, no
quiz.

## Components

| Component | State                                        |
| --------- | -------------------------------------------- |
| Plank     | in Experiment 001 inventory (2 available)     |
| Block     | in Experiment 001 inventory (2 available)     |
| Wheel     | in Experiment 001 inventory (4 available)     |
| Spring    | placeholder - defined, refused by the factory |
| Motor     | placeholder - defined, refused by the factory |

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
