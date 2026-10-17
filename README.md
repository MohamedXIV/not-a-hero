# Not a Hero

**A quiet life in a machine world.** An intimate, single-player 2D cozy survival sandbox about Yuna, an anxious but extraordinarily capable engineer who scavenges to keep her small underground home safe while uncovering a much larger, contested refuge.

> **Development status — design foundation, not yet a Godot build.**
> The new implementation will use **Godot 4.7+ and typed GDScript** under `godot/`; the original Gemini experiment is preserved for reference.

## The game

- **Exploration:** one continuous, hand-authored machine-world exterior, with distinct landscapes and procedural **loot/enemies/events**, not procedural terrain.
- **Home:** start in a tiny, warmly lit underground shelter; cook, repair, store and decorate at your own pace.
- **Discovery:** no imposed quests or mission arrow. Yuna notices clues, addresses herself in occasional second-person remarks and writes hypotheses/plans into her notebook.
- **Late-game milestone:** uncover and gain access to a hidden fortified mesa refuge sought by other machines. Both homes stay meaningful.
- **Action:** top-down real-time movement, pistol/rifle combat, stealth and evasion.
- **Humanity:** dynamic lighting/mood and Yuna's physical injuries, stamina, rest, hunger, thirst and composure matter; no conventional player HP bar.
- **Scope:** a compact ~1–3 hour initial journey and continued sandbox, not a 100-hour RPG.

## Design source of truth

| Document | Purpose |
|---|---|
| [Decisions & open questions](docs/DECISIONS.md) | What is approved, provisional and unknown |
| [Game design](docs/GAME_DESIGN.md) | Pillars, loop, mechanics, pacing |
| [Yuna character & systems](docs/YUNA.md) | Personality, self-talk, tics, bodily and composure systems |
| [World & shelter design](docs/WORLD_DESIGN.md) | Machine geography, starter nest, mesa refuge, discoveries |
| [Technical design](docs/TECHNICAL_DESIGN.md) | Godot scenes/resources, composition, persistence, chunking |
| [Art direction](docs/ART_DIRECTION.md) | Camera, lighting, character legibility, art-style experiment |
| [Roadmap](docs/ROADMAP.md) | Build milestones with playable acceptance gates |
| [Contributor instructions](AGENTS.md) | Development guardrails |

## Original Gemini experiment

The repository still includes `yuna_the_warmth_below (1).tsx`, a single-file React/Canvas experiment containing gameplay and art concepts. **Do not split, port, or silently modify it** when developing the Godot reboot. It is reference material only. Its historical presence in this repo does not mean it is the new engine or build entry point.

## Development plan

1. Establish new Godot 4.7+ project under `godot/`.
2. Prove large readable Yuna, 2D dynamic light and seamless exterior chunk crossing.
3. Add the first complete shelter → scavenging → combat/evasion → return/craft loop.
4. Add embodied survival/cozy systems, authored discovery and the mesa refuge.
5. Validate desktop **and Web export** and balance through playtesting.

See [the roadmap](docs/ROADMAP.md) for exact acceptance criteria. No verified Godot executable or Web export is claimed yet.
