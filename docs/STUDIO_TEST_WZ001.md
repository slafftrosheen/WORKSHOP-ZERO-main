# WZ-001 - the ten minute Studio test

One human session decides whether the interaction model survives contact with a
person. This is **not** a lab measurement and not a performance benchmark.

The single question:

```text
Does dragging still feel like physically holding the object,
or does it start feeling like remote-controlling it?
```

If the answer is "holding", the next batch builds Save the Duck.
If the answer is "remote-controlling", the interaction model gets fixed first.

Fill this in as you go. Anything not observed is unknown, not passed.

---

## Before you start

```text
1. .\scripts\dev.ps1                        (leave the window open)
2. open place\WorkshopZeroPrototype.rbxlx in Studio
3. Rojo plugin -> Connect
4. Play
```

Keep Studio's Output window visible - it is part of the test.

Expect, in Output:

```text
[WorkshopZero] Server bootstrap 0.0.1-dev
[WorkshopZero] Client bootstrap 0.0.1-dev
[WZ] Runtime workshop ready with 8 components
```

The joint count on the TEST and RESET lines is how you check "no duplicate
constraints" without opening the Explorer:

```text
[WZ] ... started a test: N component(s), J joint(s)
[WZ] ... reset the machine: J joint(s) still intact
```

`J` must be the same before and after every cycle. If it grows, stop and
report it - that is the one defect that would invalidate the reset model.

---

## 1. The mechanical pass (2 minutes, desktop)

```text
[ ] Prototype floor, build area and 8 components appear
[ ] Click a plank - blue outline
[ ] Drag it - it follows
[ ] Q / E rotates it, R flips it
[ ] Drag a plank end onto a block face - it snaps
[ ] Drag a wheel onto a plank side socket - it snaps
[ ] Press TEST - components fall, physics runs
[ ] Dragging does nothing while TESTING
[ ] Wheel spins, it is not welded
[ ] Press RESET - the machine returns exactly
[ ] Interaction works again
[ ] X disconnects the selected component
```

---

## 2. The five observations (5 minutes)

Rate each on desktop, then again in Device Simulator, then under Network
Simulator. One line per cell, in your own words.

| # | Observation | What you are judging | Desktop | Touch | Latency |
| - | ----------- | -------------------- | ------- | ----- | ------- |
| 1 | Grab latency | finger/mouse starts moving -> object visibly follows | | | |
| 2 | Drag smoothness | rubber-banding, stepping, trailing behind the cursor | | | |
| 3 | Release | does it stop where you expect | | | |
| 4 | Snap | feels intentional, not surprising or magnet-y | | | |
| 5 | TEST -> RESET | five violent tests, machine must return exactly | | | |

For #4, the interesting failure is the opposite of a miss: a snap that happens
when you did **not** mean it. Note every unintended snap.

For #5, "exactly" means: same positions, same orientation, same joints, and the
machine does not creep on the fifth cycle.

---

## 3. Abuse it (2 minutes)

Deliberate, not accidental. Write down what happened, not whether you liked it.

```text
[ ] drag connected wheels               (do the joined parts travel together?)
[ ] rotate a connected assembly          (does the whole assembly turn?)
[ ] drag outside the build area          (does it come back, and does the message make sense?)
[ ] rapid TEST -> RESET                  (any drift? any duplicate joints? any stuck part?)
[ ] spam Q / E / R                       (any part lost, overlapping, or flung?)
[ ] disconnect a connected assembly      (X, then does it still drag normally?)
[ ] drop a part onto a connector at a weird angle
                                         (should NOT snap - alignment tolerance)
[ ] push two joined components through each other
                                         (see "expected surprises" below)
```

---

## 4. Device Simulator (phone and tablet)

Studio's Device Simulator drives touch input directly, so this needs no extra
code.

```text
[ ] Phone profile    - select, drag, TEST, RESET
[ ] Tablet profile   - same, plus snapping
```

Watch specifically:

- Is the TEST / RESET panel reachable with a thumb, and does tapping it ever
  pick up a part behind it?
- Can a finger (not a precise cursor) get connectors close enough to snap, or
  does the alignment tolerance make touch frustrating?

---

## 5. Network Simulator (the remote-control question)

Enable Network Simulator and walk the ladder. Do not chase numbers; chase the
moment the feeling changes.

```text
[ ] ~50 ms     - should feel like holding
[ ] ~150 ms    - where does it stop feeling direct?
[ ] ~300 ms    - remote-controlling?
[ ] with jitter + packet loss - does a drag ever get stuck open?
```

Note the **first setting where it stops feeling like holding something** - that
number is the whole output of this section.

Because the drag is server-run (`RunLocally = false`), some trailing is
expected and is exactly what we are measuring. The snap preview is drawn from
replicated positions, so it will visibly lag before the object does; that is
expected, not a bug.

---

## 6. The kid test (more valuable than all of the above)

Say one sentence and nothing else:

> "Move these pieces and try connecting them."

Then be quiet and watch. Do not explain, do not point, do not help.

```text
[ ] discovers dragging within ~15 seconds
[ ] discovers snapping without being told
[ ] reaction to a machine falling apart:
        laughing / curious        -> the loop is working
        frustrated / asking for help -> the loop is not working yet
[ ] what did they try to do that the game would not let them do?
```

That last line is the most valuable sentence on this page.

---

## Expected surprises (not bugs)

Note these so they are not misreported:

1. **Q / E / R must be used before dragging, not during.** While a drag is live,
   the drag detector keeps proposing the part's position and the engine's
   proposal wins. Rotate, then drag.
2. **Two unconnected assemblies can be moved through each other.** Anchored
   parts do not collide with each other in BUILD. At TEST, physics resolves the
   overlap - sometimes violently. That is correct physics, not a snapped joint.
3. **The button refuses a wrong-phase press.** TEST only works in BUILD MODE,
   RESET only works while TESTING, and both are ignored during RESETTING.
4. **A drop outside the build area returns to the last valid transform**, which
   may be further back than the last frame of the drag.
5. **The snap preview can disagree with reality under latency** - the server
   decides, and it decides on the drag's end position.

---

## Verdict

```text
Feels like holding the object?          yes / no / depends on ____
Feels like remote-controlling it?       yes / no / only above ____ ms

Blocking problems found:
  1.
  2.
  3.

Non-blocking annoyances:
  1.
  2.

Decision:
  [ ] interaction model holds -> start WZ-002 (Save the Duck)
  [ ] fix interaction first -> what exactly:
```

---

## What this test does not cover

Nothing here is scored, saved or validated, so no part of the result depends on
network ownership:

- TEST physics may be simulated by whichever client owns the assembly - that is
  good for feel.
- But challenge completion, attempt counts and unlocks must always be judged on
  the **server**, from the server's own view of the duck and the machine, never
  from a client touch or a client-owned assembly.

That rule is written into `AGENTS.md` and `docs/ARCHITECTURE.md` now, before
WZ-002 needs it.
