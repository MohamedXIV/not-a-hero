# P5 — real browser acceptance & visual baseline

**Captured on the merged P5 PR #29, 17–18 October 2026.** This is an evidence-bound review of actual 1280×720 screenshots exported from Godot 4.7.2 and driven in Chromium WebGL2. It is not a chosen production style, a human blind-playtest, or a 1–3h completion report.

## Exact evidence, not a proxy

- [PR #29](https://github.com/MohamedXIV/not-a-hero/pull/29) — merged to `main` at `b8bcc977116f603b0ceef54466b8f4ad8e3d8483`.
- [Browser check — SUCCESS](https://github.com/MohamedXIV/not-a-hero/actions/runs/39072221346), exact PR head `89a7a7124869f35c249a46526943da0e83509859`. Its [temporary CI artifact](https://github.com/MohamedXIV/not-a-hero/actions/runs/39072221346) contains `browser-v17.log` and screenshots `nah-fresh-nest.png`, `nah-nest-reload.png`, `nah-depth-cold.png`, `nah-depth-warm.png`, `nah-depth-warm-reload.png`, `nah-depth-exit-ready.png`, `nah-mesa-return.png`. Actions retention is **three days**, so this is not an archival image library.
- [Godot engine/Compatibility smoke — SUCCESS](https://github.com/MohamedXIV/not-a-hero/actions/runs/39072221382); [GitGuardian check](https://github.com/MohamedXIV/not-a-hero/pull/29) also passed on the same exact head.

**What genuinely passed in Chromium:** fresh game camera + 2D renderer, keyboard movement in Little Nest, actual on-screen Save, JSON v17 in Emscripten IndexedDB, page reload and preserved Little Nest position; coherent lower-level startup with no unobserved journal clue; real E to inspect the archived log; real E to warm the cradle; lower-level save with preserved warmth/notes/position across browser reload; real E transition out to upper Mesa, with lower state preserved. Browser logs explicitly say PASS, not merely that the WASM file exists.

**What was accelerated (must not be disguised):** to avoid deeply timing-dependent movement in the software WebGL runner, test-only v17 saved **position waypoints** near the lower regulator and lift were seeded while the game page was closed, then the real exported Godot engine loaded them and executed E/Save/scene transition itself. Engine scene tests separately validate actual path and collision. This does **not** verify that a new player can discover the lower level from Little Nest, nor end-to-end manual browser traversal on a real GPU.

## Actual visual observations from the Chromium screenshots

| Frame | What is visible | Judgment / next acceptance question |
| --- | --- | --- |
| Fresh Little Nest | Amber practical light; recognizably small protected room, visible Yuna; save control | The warmth-versus-exposure idea reads, but all primary objects and Yuna use provisional block/simple polygon art. Needs a coherent in-engine art treatment and natural animated gestures |
| Cold lower gallery | Industrial blue-gray room; solid dark empty chamber; inspectable external log panel | Cold equipment contrasts visibly with refuge. Check archive terminal silhouette/contrast at normal camera zoom with moving Yuna |
| Warm lower gallery | Same actual scene; amber glow strongly changes the center and Yuna makes a witnessed-only line | Clear physical consequence and quiet emotional premise, but dramatic change could still use softer falloff/material response and coherent source-light animation |
| Warm lower gallery after page reload | Room returns warm; Yuna stays inside same level | Visually corroborates v17 state preservation, not just JSON values |
| Lower lift ready | Lower door and E prompt visible with Yuna approaching | Need actual human look at doorway readability and legibility of return without a quest arrow |
| Upper Mesa after E | Actual original main gallery with upper equipment and stair returned | Functionally proves the return is not a black screen. The portal/home geometry remains placeholder art |

**Delivered P5 usability repairs:** narrow always-on location/status line instead of the original giant instruction inventory; **H** for controls; focused action hint/feedback moved near screen bottom; a solid protected cradle (Yuna no longer stands inside); a reachable archival terminal in the aisle; keyboard repeat/held-E suppression to avoid immediate transition ping-pong.

**Unresolved visual deficits:** provisional vector/polygon characters and props are still too flat and geometric to convey the expressive hand-drawn/elevated top-down world described in [ART_DIRECTION.md](ART_DIRECTION.md); Yuna's posture, hand actions and everyday fidgets do not yet carry enough screen-level acting; material hierarchy and edge detail are sparse; environmental scale varies between rooms, and machine silhouettes/landmarks need more varied, readable shapes; default HUD still needs checking against real desktop and narrower device viewports. The screenshot comparison does not justify a specific final artistic style.

## Next steps, in a sensible order

1. **In-engine art comparison, not arbitrary generated mockups:** follow the existing [ART_DIRECTION.md](ART_DIRECTION.md) decision gate. One identical playable sample with Yuna + practical lamp + tall occluder + machine prop, in at most three coherent styles under the *same* camera/lighting/movement constraints. Compare Yuna silhouette/animation, visible three-quarter prop volume, affordability of asset production, warm/cold response and HTML5 draw cost. Get explicit creative approval before locking an art family.
2. **Fresh blind player session:** start from untouched Little Nest at normal viewport; track whether they find the outdoors route, survive/avoid one machine encounter, organically notice two clues, find/enter Mesa, restore power/flow, choose or decline first night, look into the lower room, return and keep living. Don't give them code coordinates; log route stumbles and 1–3h pacing. This is a **human acceptance**, not a scripted CI.
3. **Audio/motion/legibility pass:** compare daytime/dusk, older laptop and WebGL2 fallback, gamepad/keyboard focus, mobile-size viewport, E text contrast, and accessibility (subtitle and controls visibility) after art direction is chosen.
4. **Narrative closure decision:** decide after a human playthrough whether the first voluntary Mesa night and optional lower discovery provide sufficient compact closure; leave the final occupant/creator/secret unspecified unless the author approves a reveal.

P5 #7 remains OPEN for art, player experience, pacing and release decisions; P4 #6 remains OPEN for genuinely accepted narrative arc. The real browser v17 checkpoint above is **complete**.
