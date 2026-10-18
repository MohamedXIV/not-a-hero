# P5 Visual Style Study — in-engine comparison, not an art decision

**Status:** Engineering prototype awaiting author/artist review. No production style is selected. The current game still renders its preexisting provisional actor and level shapes.

## Open the actual interactive sample

In the Godot 4.7.2 editor, launch `res://scenes/presentation/visual_study.tscn` (Play Current Scene / F6). The sample uses the **same instantiated Yuna scene**, movement/weapon controller, physical player collider, camera zoom (1.5), world-space footprints, tall occluder and practical `PointLight2D` in both alternatives. Camera and physics never change with style.

- **Z** — Graphic / Ink; explicit dark outlines and readable directional shapes.
- **X** — Soft / Layered; rounded silhouettes and subtle translucent surface highlights.
- **T** — toggle day/night illumination (CanvasModulate and the same lamp).
- **WASD** — move, **mouse** — aim, **Esc** — return to the existing main game.

The two versions share **the identical constructed environment**: warm portable lamp, steel salvage crate, tall machine pylon with real collision and light occlusion, and a muted neutral ground. Nothing is seeded or moved between toggles. Both use authored vector prototype drawing only, not a final hand-painted sprite or shipped asset.

## What the comparison actually tests

| Criterion | Graphic/Ink treatment | Soft/Layered treatment |
|---|---|---|
| Silhouette | Strong compact outline; distinct feet, tunic, braid | Softer multiple-tone silhouette; slightly lighter edge |
| Three-quarter 2D depth | Hard visual separation and graphic top faces | Overlaid soft reflections and partial faceted form |
| Home vs machines | Crisp strokes can organize the interface/props | Warm diffuse accents can feel quieter in shelter |
| Natural Yuna read | Fixed physical body and slight moving steps/tic | Identical physical body and slight moving steps/tic |
| Camera/shadow cost | No special textures or shader requirements | A few additional alpha layers; no special shader |

**Both are a limited procedural exploration**, so neither can demonstrate actual painted brushwork, final animation fidelity, texture import/filter choices, real multi-layer shadow assets or the cost of a complete production illustration pipeline. They are not being sold as finished art or fully representative pixel-art/painterly candidates. If both fail to meet the brief, the next revision should use a small set of authored production-like sprites in this *same* test harness.

The automated Compatibility renderer captures **four** frames from this exact playable scene at identical player/camera positions: `visual_study_graphic_day.png`, `visual_study_soft_day.png`, `visual_study_graphic_night.png` and `visual_study_soft_night.png`. Compare **Graphic Day vs Soft Day** or **Graphic Night vs Soft Night**. The actual reviewer should still toggle Z/X while moving because an image does not validate animation, input legibility or expressive posing.

## Acceptance gate

Choose a style only after author review **in motion** at the actual camera/viewport, including warm and cold light, ordinary/injured character posture, robot/machine silhouettes, WebGL2 compatibility and cost of creating the full game assets. If neither prototype conveys Yuna's emotional screen presence, reject both without changing the production art direction.

Do not mark P4/P5 complete on the strength of this style sample or CI.
