# Workshop Zero - Asset Wishlist

Status: **future production notes only.** WZ-002 deliberately ships with Roblox
primitives, because the point of the first playable is to validate challenge,
interaction, feedback and fun before spending any time dressing it.

Nothing here is imported yet. When assets do get made, they follow
`docs/ASSET_PIPELINE.md`: Hyper3D originals into `assets/source/hyper3d/`,
cleanup in Blender, clean renamed exports into `assets/export/roblox/`.

Shared visual direction for every asset:

```text
warm workshop, chunky geometry, toy-like proportions
big readable silhouettes, minimal small detail
handmade rather than industrial, friendly rather than realistic
clean topology, no text, no logos, isolated objects
```

---

## Rubber duck

**Replaces:** the primitive `Duck` model in `SaveTheDuckLevel`
**Direction:** recognisably yellow, small next to a plank, reads as "me, the
point of the experiment" from across the level. Cheerful, not sarcastic.

### Hyper3D prompt

```text
Stylized chunky yellow rubber duck toy for a family-friendly Roblox physics
building game. Rounded exaggerated silhouette, cheerful, simple forms, minimal
small detail, slightly handmade toy appearance, clean topology-friendly shape,
no text, no stand, isolated object.
```

## Giant red goal button

**Replaces:** the primitive `GoalButton` model in `SaveTheDuckLevel`
**Direction:** absurdly oversized, broad red cap on a simple metal base,
obviously pressable, friendly rather than dangerous.

### Hyper3D prompt

```text
Oversized comical mechanical red push button for a stylized maker workshop
game. Chunky industrial-toy proportions, broad red cap, simple metal base,
visible screws, friendly rather than dangerous, clear readable silhouette,
suitable for Roblox.
```

## Plank

**Replaces:** the primitive Plank component root
**Direction:** warm wood, slightly worn edges, proportions identical to the
gameplay size (8 x 0.6 x 2 studs) so connector offsets stay valid.

### Hyper3D prompt

```text
Stylized wooden plank building piece for a family Roblox construction game.
Long flat board with softly rounded worn edges, warm honey wood color, subtle
grain, toy-like chunky proportions, clean simple geometry, no text, isolated
object.
```

## Wood / metal block

**Replaces:** the primitive Block component root
**Direction:** reads as heavier than a plank. Either warm wood or painted
metal; one material, no greebles.

### Hyper3D prompt

```text
Stylized square wooden building block for a family Roblox construction game.
Chunky cube with softly beveled edges, painted workshop finish, slight hand-made
irregularity, simple readable silhouette, clean topology, no text, isolated
object.
```

## Workshop wheel

**Replaces:** the primitive Wheel component root (still needs a true axle hole
or hub visual)
**Direction:** rubber tyre over a simple hub, spinning is the point, so the
silhouette must stay round from every angle.

### Hyper3D prompt

```text
Stylized toy wheel for a Roblox physics building game. Chunky rubber tire with
simple rounded hub, dark matte finish, slightly oversized cartoon proportions,
clean circular silhouette from every angle, no spokes detail, no text, isolated
object.
```

## Workbench

**Replaces:** the primitive bench in the level dressing
**Direction:** sturdy, scarred by use, reads instantly as "machines are made
here".

### Hyper3D prompt

```text
Stylized wooden maker workbench for a family Roblox workshop game. Chunky
planked top with visible clamps and light wear, sturdy legs, warm handmade
feel, exaggerated toy proportions, clean simple geometry, no tools attached, no
text, isolated object.
```

## Toolbox

**Replaces:** the primitive toolboxes on the bench
**Direction:** bright painted metal, handle up, slightly too big for the
objects it could hold. One colour plus metal, no logos.

### Hyper3D prompt

```text
Stylized vintage metal toolbox for a family Roblox workshop game. Chunky
rounded box with bright painted finish, simple handle on top, subtle dents and
scuffs, friendly toy proportions, clean topology, no logos, no text, isolated
object.
```

## Shelves

**Replaces:** the primitive wall shelves and crates
**Direction:** heavy timber brackets, mostly empty so the level stays readable;
crates as separate pieces.

### Hyper3D prompt

```text
Stylized wooden workshop shelf for a family Roblox game. Thick timber plank on
heavy brackets, warm wood tones, light sawdust wear, chunky toy proportions,
clean simple geometry, no clutter, no text, isolated object.
```

## Workshop clutter

**Replaces:** nothing yet - optional dressing pass
**Direction:** a few silhouettes only (barrel, crate, lamp, cable spool).
Never near the build area; clutter exists at the edges of the frame.

### Hyper3D prompt

```text
Small set of stylized workshop clutter props for a family Roblox game: wooden
barrel, crate, cable spool and hanging lamp. Chunky warm toy-like proportions,
handmade feel, simple readable silhouettes, clean topology, no text, isolated
objects.
```

## Warning barrier

**Replaces:** nothing yet - optional framing of the pit / goal area
**Direction:** striped sawhorse, toy-like, communicates "edge" without reading
as danger. Colour stripes do the work, not detail.

### Hyper3D prompt

```text
Stylized wooden sawhorse warning barrier for a playful Roblox workshop game.
A-frame legs with striped plank, chunky toy proportions, warm painted stripes,
friendly rather than industrial, clean simple geometry, no text, no symbols,
isolated object.
```

---

## When this list is opened

Not before the family playtest of WZ-002 says the game is fun with primitives.
Swapping a primitive for a mesh must not change gameplay sizes: gameplay
dimensions stay in `ExperimentDefinitions` and `ComponentDefinitions`, and the
mesh is dressed onto them.
