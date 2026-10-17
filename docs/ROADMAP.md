# Not a Hero — Execution Roadmap

**Status:** planning baseline. Each milestone is **a playable, verifiable increment**, not a license to produce placeholder UI. Complete the smallest coherent feature and validate before moving forward.
**North star:** a 1–3 hour intimate first experience in a small home and continuous machine landscape, leading organically toward discovery and entry into a contested mesa refuge; ongoing sandbox after.

## Delivery principles

- Ship Godot, not a port of the 5,533-line React prototype.
- Maintain continuous outdoors from the earliest walking build; interiors may use entrances and separate scenes.
- Write GDScript with meaningful types; reusable Scenes and data Resources; avoid giant scripts or needless factory hierarchies.
- Build to the smallest **playable end-to-end loop** early; use hand-authored content rather than infrastructure-first overdesign.
- Dynamic lighting and character scale/readability are features, not last-minute polish.
- Every finished milestone includes reproducible manual checks and relevant automated GDScript tests when feasible.
- Keep Web/Compatibility render target viable early, without making it the sole release determinant.
- Maintain deterministic seeded loot/spawns and stateful persistence; don't build random terrain.
- Treat “~1–3 hours” as a **playtest target**, never achieved just by long wait timers.
- Game should be welcoming to cozy players; avoid permanent death and disproportionate upkeep.

## P0 — Reboot foundation and visual proof

**Deliverable:** A running Godot 4.7+ project, built cleanly from scratch under `godot/`.

Implement:
- Project setup, typed scripts, input actions, bootstrap/main world scenes, minimal HUD.
- Yuna locomotion in a mock authored exterior tile-space, visible large character, responsive camera.
- At least 2 adjoining hand-authored areas/chunks with world-space continuity and a simple streaming/load strategy; no teleport/loading screen at seam.
- A separate **small starter shelter** scene with entrance/exit round trip.
- Basic ambient day/night + lamp dynamic light and occluder, visible difference indoors/outdoors.
- Initial data Resource definitions and world/session ownership boundaries.
- First save/load round-trip for location and changed world data, and a simple offline smoke checklist.

**Gate:** user launches Godot project, moves Yuna, crosses a chunk seam fluidly, enters/leaves her small home, sees warm/cold lighting and confirms save restores her position/state. Headless project parse starts. Desktop and initial HTML5 Compatibility feasibility smoke noted. Art can be provisional but consistent.

## P1 — First complete scavenging loop

**Deliverable:** Take a trip out, collect something, survive a robot, return, use loot.

Implement:
- Inventory + storage transactions, interaction prompts, lootable world props and resource definitions.
- Pistol + rifle aim/fire/reload/swap with collision/hit feedback.
- One hostile robot with readable patrol/investigate/chase/attack/search/return behavior; one neutral worker.
- Basic stealth/retreat, one sound/decoy interaction if practical.
- Repair/craft a useful item at a home bench; autosave world loot changes.
- Minimum audio and self-talk event to convey Yuna's voice.

**Gate:** a fresh save supports continuous home → exterior → encounter → salvage → home → craft; saves and reloads do not reroll opened container or duplicate loot. No obvious softlocks.

## P2 — Yuna's lived condition and cozy core

**Deliverable:** Survival that feels like *her*, plus meaningful, non-compulsory home life.

Implement:
- Stamina, accumulative fatigue/rest, hunger and hydration (measured slow rates).
- Logical arms/legs/torso injuries with severity, stabilization, healing and understandable status view; no Yuna HP bar.
- Composure state, warnings and effects on focus/aim. Ordinary tics separate from stress responses. Panic penalties opt-in via prototype test before irreversible tuning decision.
- Contextual second-person self-talk (anti-repeat, subtitles, no cloud dependency).
- Decorate small shelter with a modest furniture set; interaction, placement validation, persistent arrangement.
- Sleep, food prep and a shelter comfort/recovery loop.

**Gate:** entering/leaving stress changes how Yuna behaves, no unseen instant shout hard-fails stealth, field first aid and home rest work, one in-game peaceful day at home is feasible, placement survives save/reload.

## P3 — World ecology and discoverable progression

**Deliverable:** A coherent, continuous machine world and clues that players *find*.

Implement:
- Author and connect the major region identities (names/location counts subject to scale).
- Region-driven seeded loot tables, enemy populations, occasional dynamic events, no random geography.
- More machine archetypes (e.g., small scavenger, sensor drone, guardian, heavy reclaimer), neutral machines, credible ecology.
- Landmark inspection, discovery facts, Yuna's hypothesis/plan notes, optional notebook pinning.
- Multiple clue paths about the contested mesa. Missing critical materials/clues must have alternate reliable sources.
- Persist explored/cleared/activated changes across chunk streaming and save/load.

**Gate:** walk between different biomes with no forced region menu; rest/save/load preserves discoveries and cleared containers; two different observation orders can lead to a coherent note without triggering undiscovered facts.

## P4 — Hidden mesa refuge and full compact arc

**Deliverable:** A significant non-forced discovery that pays off.

Implement:
- Physically reachable mesa exterior landmarks and credible robot competition.
- Sealed entrance, clue chain(s), security/bypass interactions and non-random opening requirements.
- Large refuge interior scene, danger/cleanup/activation and new facility/decor/growing possibilities.
- Keep original shelter alive; player can return and keep customizing it.
- Milestone payoff as an intimate discovery/quiet evening, **not** a world-saving cutscene.
- Post-milestone continuation: persistent free play, dynamic salvage and optional discoveries.

**Gate:** a fresh player can discover, understand and enter the refuge without a quest giver, HUD checklist or procedural key luck. The world continues afterward.

## P5 — Completion, performance and feel

**Deliverable:** The intended short indie game, not merely implemented system names.

Implement/verify:
- Choose art style from in-engine animation/lighting comparison; replace temporary visuals cohesively.
- Richer character expressions, cozy action feedback, dynamic shadows, atmospheric sound and UI comfort settings.
- Balance hunger/thirst/fatigue/injuries/composure so ordinary player decisions aren't punished by grind.
- Playtest several blind runs toward **1–3 hours**; adjust content density and hints.
- Verify no critical-clue softlock, duplicate loot exploit or panic death spiral.
- Test Web HTML5 Compatibility build, persistence, audio and graphics; document unsupported browser/graphics edge cases.
- Test gamepad/extra control schemes only if justified; preserve keyboard+mouse baseline.
- Produce build/run instructions, release notes, known limitations and a save-in/out regression checklist.

**Gate:** reliable browser/desktop sessions from New Game through mesa activation and continued sandbox, no dead UI controls, clean errors, load/reload and respectable performance.

## Risk register and spikes

| Risk | Cheap experiment | Fallback |
|---|---|---|
| Large Yuna sprites occlude combat/props | One lamp + Yuna + enemy at both zoom levels | Adjust camera and hit/occlusion anchor |
| Godot 2D dynamic lighting varies on Web | Compatibility-renderer HTML5 export with shadows and normal map | Reduce live lights/occluders; baked fill + limited key lights |
| Chunk seam hitches | 2–3 authored adjoining chunks at normal sprint speed | Preload neighbors; simplify active props before threads |
| Composure panic becomes unfair | Scripted stealth case with clear buildup/counterplay | Keep cosmetic-only/aim penalties until tuned |
| Body injury makes play tedious | Field first aid + fast forward rest/recovery scenario | Cap severity, lower downtime and avoid compound penalties |
| Freedom makes objective invisible | Blind player explores mesa clues without quest marker | Improve placed environmental hints and notebook, not arrows |
| Art production becomes bottleneck | Small comparative in-engine art spike | Choose economical sprite pipeline |
| Too many systems spread thin | End-to-end tiny play loop in P1 | Reduce item/enemy counts, **not** basic mechanical completeness |

## Working cadence

At each coding milestone: verify live `main`, issues and PRs; avoid competing branches; document decisions that change scope; develop on feature branch and review via PR. Do not enable CI spending by default. Update this roadmap based on measured gameplay, not optimistic implementation claims.

**First actionable issue:** P0 foundation (Godot project structure, Yuna movement, two contiguous chunks, little starter shelter, lighting + save smoke).
