# Workshop Zero - Game Design

Status: **WZ-001**. This document is a compass, not a spec.

The construction kernel (BUILD / TEST / RESET) now exists as infrastructure.
Experiment 001 is still not implemented, and none of the systems below have
been designed yet - the kernel is there so that the first experiment can be
about a duck rather than about plumbing.

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

## First planned prototype

**Experiment 001 - Save the Duck.**

Not implemented yet. It is the first thing built once this pipeline is proven.

## Components

| Component | State                                        |
| --------- | -------------------------------------------- |
| Plank     | functional prototype (Rigid ends, Axle sides) |
| Block     | functional prototype (Rigid faces, Axle sides) |
| Wheel     | functional prototype (spins on an Axle)       |
| Spring    | placeholder - defined, refused by the factory |
| Motor     | placeholder - defined, refused by the factory |

## Interactions

| Interaction | State in WZ-001                                   |
| ----------- | ------------------------------------------------- |
| Grab / Move | dragging a component, with its assembly following |
| Rotate      | `Q` / `E` in 15 degree steps, `R` to flip 90      |
| Connect     | automatic snap to a nearby compatible connector   |
| Disconnect  | `X` releases every joint on the selected component |
| Test        | TEST button: unanchor and let physics run          |
| Reset       | RESET button: restore the exact build, zero velocity |

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
