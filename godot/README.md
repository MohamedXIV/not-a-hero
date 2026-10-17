# Not a Hero — Godot P0 Foundation

**Target:** Godot 4.7.2 stable (standard/GDScript), using Compatibility renderer for HTML5 feasibility.

## Current status

**Source scaffold only. NOT yet verified in an installed Godot runtime.**

This is an early P0 interactive proof, **not** the complete P0 acceptance gate:
- Provisional large Yuna drawn procedurally, with WASD movement and shift sprint.
- Tiny initial shelter with a hatch; E moves to the exterior and back.
- Three **fixed, hand-authored** neighboring outdoor chunks; one contiguous 2D coordinate frame, nearby scenes loaded/unloaded without a region-selection screen.
- Basic day/night modulation and local PointLight2D with an occluder.
- Tiny save/load skeleton: saves scene/position/clock to `user://not_a_hero_save.json`. F5 save; transitions autosave.
- No combat, loot, full persistence deltas, elaborate tiles, animated character sprites, complete shelter, or final art. They belong to upcoming work.

## Open

1. Install Godot 4.7.2 Standard and import `godot/project.godot` as a Godot project.
2. Run the main scene. WASD move, Shift sprint, E near hatch, F5 save.
3. Watch Yuna cross chunk seam at world X = 640 / 1280; verify there is no teleport.
4. Confirm warm/cold scenes and nearby lights; note actual shadow results.
5. Save and relaunch. Verify scene/position/clock restore.
6. Export HTML5 **with Compatibility renderer** when Web templates are available; test persistent save across reloads.

## Important

This branch requires actual Godot verification before it can be declared a playable P0 delivery or merged. No claim of successful headless validation or browser export is made here.

Next foundation work: importer/headless parse test, bug fixes, real authored obstacle/world collision tests, starter shelter usability and save/persistence deltas. See [P0 issue](https://github.com/MohamedXIV/not-a-hero/issues/2).

The one-file Gemini React experiment is retained at the repository root for design comparison only, not ported.
