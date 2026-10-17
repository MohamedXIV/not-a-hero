# Not a Hero — AI/Contributor Working Contract

Read `docs/DECISIONS.md`, `docs/GAME_DESIGN.md`, `docs/YUNA.md`, `docs/WORLD_DESIGN.md`, `docs/TECHNICAL_DESIGN.md`, `docs/ART_DIRECTION.md` and `docs/ROADMAP.md` before making gameplay or architectural decisions.

## Core directives

- This is a **new Godot 4.7+ typed GDScript implementation**, not a refactor, split, transpilation or copy of the old one-file React experiment.
- Existing `yuna_the_warmth_below (1).tsx` is **read-only reference material**; do not edit/remove/port without explicit instruction.
- Godot project belongs under `godot/` while reference material remains at repository root.
- One continuous **handcrafted** exterior map with simple chunk streaming; seeded loot/enemies/events, not randomized geography.
- Starting hideout is **small**; the large mesa refuge is a discovered, contested destination.
- No quest givers, imposed objectives or omniscient task UI. Notebook facts and Yuna's contextual self-talk are discovery-led.
- Dynamic 2D lighting and large readable Yuna must be proven early, including HTML5 Compatibility smoke.
- Distinguish normal tics from panic. Never treat Yuna's intelligence as a variable stat.
- Needs: localized injuries, stamina, fatigue/rest, composure, hunger, hydration. No visible HP bar for Yuna.
- Use Scenes/Nodes, Signals and typed Resources for modular responsibilities. Design patterns only when useful.
- Don't create monolithic god classes or pointless files for trivial helpers.
- Save state by stable IDs and authoritative deltas, not raw SceneTree copies. No old save compatibility requirement.
- Avoid hidden progression RNG: critical clues and access must be attainable with authored paths.
- Provide working interactive gameplay, not mock UI with buttons that pretend to work.
- Verify headless project start and manual or automated smoke for every deliverable; report if a check could not be run.
- Avoid GitHub Actions minutes unless needed; prefer local checks.
- If a design question isn't resolved, use a reversible default, label it as such and record the alternative instead of silently treating it as canon.
