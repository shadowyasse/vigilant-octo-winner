# BIND & DELIVER

A 3D physics-based co-op comedy-horror game for Godot 4.3+. One to four
exorcists break into a cursed house, tackle and bind a ragdoll demon, and
shove it into the back of a van.

This repository currently contains **Stage 1**: the project foundation, the
atmospheric cursed house and yard, the extraction van, the physics player
controller and the HUD. Everything is generated in GDScript from engine
primitives, so there are no textures, models or audio files to import.

## Running it

1. Open the folder in Godot 4.3 or newer (Forward+ renderer) and press **F5**,
   or run `godot --path .` from the repository root.
2. `scenes/Main.tscn` is the main scene. It holds a single node; `Main.gd`
   builds the environment, level, player and HUD when the scene starts.

Volumetric fog and SSAO need the Forward+ renderer. On Mobile or Compatibility
the level still builds and plays, with the moonbeam meshes standing in for the
missing fog shafts.

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` | Move |
| `Shift` | Sprint (drains stamina) |
| `Space` | Jump |
| `Ctrl` | Crouch (hold) |
| Mouse | Look |
| `LMB` / `E` (hold) | Grab a physics prop within 3.2 m |
| `RMB` (while holding) | Throw / shove the prop |
| `F` | Use doors (van rear doors, front doors) |
| `V` | Toggle first / third person |
| `T` | Toggle headlamp |
| `Esc` | Release the mouse (click to recapture) |

Bindings live in **Project Settings > Input Map**.

## Layout

```
project.godot            Input map, GameState autoload, physics layer names, render settings
autoload/
  GameState.gd           Physics layer bits, groups, contract objective chain, HUD signals
scenes/
  Main.tscn              Entry scene (one node + Main.gd)
  Player.tscn            CharacterBody3D, capsule, head, spring-arm camera, headlamp, model
  HUD.tscn               CanvasLayer + HUD.gd
scripts/
  Main.gd                WorldEnvironment (ACES, SSAO, fog, volumetric fog, glow) and moonlight
  LevelBuilder.gd        Yard, house shell, rooms, lamps, moonbeams, markings, triggers, props
  ExtractionVan.gd       Van body, cargo cage, ramp, lights, hinged rear doors, cargo zone
  HingedDoor.gd          RigidBody3D door leaf on a HingeJoint3D with a driven swing and latch
  PropFactory.gd         The throwable clutter, with per-prop mass / friction / bounce
  OccultMarkings.gd      Procedural chalk pentagrams, rune circles, sigils and rune rows
  MaterialLibrary.gd     Cached procedural materials (noise-textured, glow, glass, shafts)
  FlickerLight.gd        Noise-driven flicker and brown-outs for any Light3D
  Player.gd              Movement, stamina, camera modes, headlamp, grab / throw, interaction
  ExorcistModel.gd       Rigged hazmat exorcist: skeletal clips plus procedural crouch, lean and arm IK
  HUD.gd                 Objective banner, stamina bar, gadget slots, prompts
  Crosshair.gd           Reactive reticle
```

## How the pieces fit

- **Physics layers**: `1 world`, `2 player`, `3 props`, `4 interactable`.
  Props carry the `grabbable` group and a `display_name` meta used in prompts.
- **Grabbing** never freezes the prop. Each physics tick the distance between
  the grab point and the hands becomes a target velocity, and the velocity
  error becomes a capped force applied at the grab point, so props swing, snag
  on door frames and sag under their own weight. Tune it under **Grab** on the
  Player node (`pull_stiffness`, `pull_response`, `max_pull_force`,
  `throw_impulse`). The sofa weighs more than one exorcist can lift.
- **Doors** are rigid bodies pinned by a `HingeJoint3D`. A damped torque drives
  them open or shut, swing limits are enforced in `_integrate_forces`, and a
  shut leaf latches until someone uses it. Anything with `interact()` and
  `get_prompt()` on the interactable layer works with `F`.
- **Stairs** are visible steps with a hidden ramp along their nosings, so
  players and dragged bodies do not catch on every riser.
- **Objectives** are steps in `GameState.STEPS`; world objects call
  `GameState.complete_step()` and the HUD follows `objective_changed`.
- **Suit colours**: set `suit_variant` on the Main node (0 orange, 1 teal,
  2 olive, 3 purple) or call `Player.set_suit()`. The idle crew by the van takes the other three.
- **Gadget slots** are empty in Stage 1; `HUD.set_gadget_slot(index, name)` is
  the hook for Stage 3.

## Stage 1.5: visual overhaul

- **Assets**: `tools/fetch_assets.py` downloads and verifies the CC0 `.glb` models and
  1K PBR texture sets listed in `assets/asset_manifest.json`; everything lives under
  `assets/`, so the game runs offline.
- **Exorcist**: the rigged CC0 worker is re-dressed in code (suit fabric in four team
  colours, split-out rubber gloves, full-face gas mask with glowing lenses, hardhat lamp,
  harness, twin canisters, hose, belt). Idle / walk / run are skeletal clips; crouch,
  airborne tuck, sprint lean, head pitch and arm reach are layered on by a
  `SkeletonModifier3D` with two-bone IK.
- **First person**: the same body stays visible with the head hidden; the gloves are
  IK-posed in view with stride bob and look sway, and reach toward a grabbed prop.
- **Grab tether**: a soft camera-facing thread from the right glove to a contact ring on
  the grab point. It sags when slack and turns amber as the grip nears breaking.
- **Lighting**: ACES, SSAO, SSIL, thresholded glow, volumetric fog (cold outside, a warm
  `FogVolume` indoors), four-split moon shadows, and one shadow-tuning pass over every lamp
  in `Main._tune_lights()`.

## Checks

```
godot --headless --path . --import          # first run only: builds the import cache
godot --headless --path . -s tools/smoke_test.gd
```

The smoke test boots the real game and plays the contract through the player's own
input paths (F on the van doors, grab, haul up the ramp, throw, house triggers, V / T /
Ctrl / Space). `tools/setup_sandbox.sh` installs Godot 4.3 and a software Vulkan stack
for headless Linux machines.
