# Not a Hero — Godot P0 Foundation

**Target:** Godot 4.7.2 stable (standard/GDScript), using Compatibility renderer for HTML5 feasibility.

## Current status

**Draft implementation. Godot 4.7.2 automated smoke tests validate parsing, running and chunk persistence. Rendering and Web export have separate checks; they do not replace manual gameplay review.**

This is an early P0 interactive proof, **not** the complete P0 acceptance gate:
- Provisional large Yuna drawn procedurally, with WASD movement and shift sprint.
- Tiny initial shelter with a hatch; E moves to the exterior and back.
- Three **fixed, hand-authored** neighboring outdoor chunks; one contiguous 2D coordinate frame, nearby scenes loaded/unloaded without a region-selection screen.
- Basic day/night modulation and local PointLight2D with an occluder.
- Tiny versioned save/load skeleton: persists level, position, clock and stable relay switch states to `user://not_a_hero_save.json`. F6 save; hatch transitions and relay interactions autosave.
- No combat, loot, full persistence deltas, elaborate tiles, animated character sprites, complete shelter, or final art. They belong to upcoming work.

## Open

1. Install Godot 4.7.2 Standard and import `godot/project.godot` as a Godot project.
2. Run the main scene. WASD move, Shift sprint, E near hatch, F6 save.
3. Activate the small relay at approximately **X=510, Y=285** outside by standing near it and pressing **E**. The lamp should toggle and the HUD report the state.
4. Cross chunk seams at global **X=640 and X=1280**. The first chunk should unload once you are sufficiently far away. Return to it and verify the relay is still active.
5. Confirm warm/cold scenes, dynamically updated ambient light and lamp shadows. Verify furniture blocks Yuna in the Little Nest.
6. Save and relaunch. Verify level/position/clock and relay state restore (no duplicated props).
7. Run unit-style smoke scripts after importing the project:
   - `godot --headless --path godot --script res://tests/session_state_smoke.gd`
   - `godot --headless --path godot res://tests/world_chunk_smoke.tscn --quit-after 180`
8. Export HTML5 **with Compatibility renderer** when Web templates are available; test persistent save across browser reloads.

## Important

This branch requires passing Godot parsing, scene load and smoke tests **plus** visual/interaction and browser checks before it becomes finished P0. CI headless tests do not prove FPS, camera feel, actual shadow appearance or browser persistence. The GitHub Actions smoke workflow is deliberately limited to `godot/**` changes.

Next foundation work: importer/headless parse test, bug fixes, real authored obstacle/world collision tests, starter shelter usability and save/persistence deltas. See [P0 issue](https://github.com/MohamedXIV/not-a-hero/issues/2).

The one-file Gemini React experiment is retained at the repository root for design comparison only, not ported.

## Additional checks (CI)

- `godot/tests/render_smoke.tscn` captures the Little Nest and exterior dusk under **Xvfb/Compatibility**, and uploads short-lived preview PNGs to the PR run. This is a rendering diagnostic, **not** the approved art style.
- `.github/workflows/godot-web-export.yml` tests export of HTML5 + WASM from the official matching Godot export templates. Because that archive is very large, a matching Web export has already passed; rechecking this expensive export is **manual workflow dispatch only**, never automatic on each PR push.
- A real browser session, persistence across page reload and actual player movement/camera/lighting feel are still manual review gates.

### Browser save button

Use the visible **Save** button in the top-right corner for browser persistence. **F6** is also mapped to quick save; do not use F5 for save in a browser because it is commonly the page reload key. Browser IndexedDB persistence and reload restoration remain a separate acceptance test.
