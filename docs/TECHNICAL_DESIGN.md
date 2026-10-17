# Technical Architecture — Godot Rebuild

**Engine:** Godot 4.7+ stable (pin the exact stable minor/patch at implementation).
**Language:** typed GDScript (static annotations; warnings inspected).
**Targets:** desktop first-class + browser via Godot HTML5/Compatibility renderer; test both early.
**Goal:** clean, modifiable game systems without turning a compact game into a platform project.

## Guiding principles

- **Scenes compose entities; Resources define content; nodes run behavior; signals report changes.**
- Single responsibility within meaningful boundaries; prefer composition to deep inheritance. Depend on small contracts/interfaces (typed base scripts, callable APIs, signals) as needed.
- Do not force enterprise SOLID vocabulary, service locators, reflection-heavy registries or a full ECS.
- Keep **simulation/state ownership separate from rendering, input, UI and serialization**.
- Avoid huge monolithic scripts and also avoid one script for each ten-line helper.
- Gameplay features should be authored via data (ItemDefinition/RecipeDefinition/EnemyDefinition/WeaponDefinition/DiscoveryDefinition), not condition chains in one main scene.
- Keep core simulation deterministic where meaningful, and externalize RNG seeds; gameplay timings use Godot frame delta or explicit calendar tick.

## Proposed directory boundaries

```text
godot/
  project.godot
  scenes/
    boot.tscn
    world/world_root.tscn
    world/chunks/
    interiors/starter_shelter.tscn
    interiors/mesa_refuge.tscn
    actors/yuna.tscn
    actors/robots/
    props/
  scripts/
    core/           # run/session, game calendar, save boundary
    world/          # world space, chunks, region sampling, population/events
    actors/         # movement/input, injury, composure, stats
    combat/         # weapons, hits, projectiles, enemy behaviors
    inventory/      # items and inventory transactions
    crafting/       # recipes and station interaction
    interiors/      # decor/placement, shelter facilities
    discovery/      # evidence, hypothesis, personal notes
    presentation/   # lighting, audio cues, dialog barks, camera
    ui/             # presentation-only Control scripts
  resources/
    items/
    recipes/
    weapons/
    enemies/
    regions/
    discoveries/
  assets/           # art and sound; exact workflow still TBD
  tests/
```

Directory structure may evolve. Prefer explicit names and small locally coherent folders. We keep the Gemini `.tsx` at repository root as an untouched reference; **do not import/copy its runtime** into Godot.

## Runtime ownership

- **WorldRoot:** persistent world-space coordinate frame, active chunk nodes, global outdoors environment. Never teleports the player when crossing chunk seams.
- **WorldStreamer:** selects nearby authored chunk scenes and requests loads/unloads; emits chunk lifecycle events; does not own inventory or quest facts.
- **Chunk:** authored TileMapLayer(s), placed props/spawn anchors, navigability metadata, hazards; stable `chunk_id`.
- **WorldPopulation:** seeded spawn schedules per chunk/epoch; respects persistent deltas. Spawn policy and world geography are deliberately separate.
- **Player/Yuna:** CharacterBody2D with movement/interaction controller, visuals, composure, fatigue, injury and weapon handling. A component exists only when it has real reusable responsibility.
- **Combat:** shared damage/hit contract for player and robots; target-specific resolver converts hit to physical injury or robot durability.
- **Inventory/Crafting:** transactions validate availability/capacity before consuming; recipe resources declare inputs/output/station; UI calls commands and observes results.
- **Notebook:** listens to authoritative DiscoveryEvents, stores known facts and current note state; authored texts are conditional on actual discoveries, no API needed.
- **Shelter:** placed furniture instances with persisted IDs/positions/rotation and usable facility components. Both shelters use the same furniture and persistence services.
- **Atmosphere:** environment-specific day/night interpolation, CanvasModulate, localized PointLight2D/DirectionalLight2D, occluders, authored ambience; low-cost lighting fallback for Web.
- **UI:** Control scenes observe event/state snapshots. Never run physics, global AI or inventory simulation inside UI scripts.

Avoid a single massive GameManager. Use only a few global Autoloads when persistent cross-scene ownership is essential (e.g., GameSession, SaveService); pass explicit references otherwise.

## World streaming plan

1. **One global coordinate grid** for all exterior chunks (including Yuna); scenes authored at known origins.
2. Start with player chunk plus immediate neighbors and stable 2D `chunk_id` values. Chunk size and preload radius must be measured, not guessed as production constants.
3. Preload next neighbors before boundary travel; never fade/teleport player to transition an exterior biome.
4. Unload far chunks after extracting only authoritative changes: looted containers, altered switches, persistent enemy state where necessary.
5. Do not simulate offscreen NPC physics. Use coarse event/time changes on re-entry if needed.
6. Keep authored terrain and story landmarks fixed; seed loot/spawn variation from world seed, chunk ID and world epoch. Use stable object identifiers, not array indices.
7. Prevent reload duplication, respawn exploit and blocked critical clues. Story-critical clue placement is authored, never randomized.
8. Test actual edge crossing, occlusion, AI targeting near boundaries, loading stutter, and Web memory pressure.
9. Use simple synchronous preload initially if fast enough; only add threaded loaders if profiling and platform constraints justify them.

Godot TileMapLayer's internal tile render batching **does not equal scene streaming**. Chunk lifetime belongs to the WorldStreamer.

## Injuries and combat

One solid collision shape for Yuna's physical movement. Hit outcomes go through a damage event and a logical zone resolver (arms/legs/torso), optionally refined by hit direction/projectile geometry. Do not require per-bone hitboxes unless readability testing demands them.

Physical injuries store type, zone, severity, treatment/stabilization and recovery progress; enemy robots can use a simpler durability/health component. Track computed modifiers in one place and cap stacking.

Composure modifiers likewise flow through a limited interface. Panic is a separate event channel with warning, bounded effect, cooldown and counterplay. Ordinary tics are animation/voice expressions, **not** combat RNG.

### AI

Small readable state machine (patrol, investigate, pursue, attack, search, return); use states/components where complexity warrants them. AI decisions and perception read world query/physics; presentation animates results. AI should not directly manipulate global save dictionaries.

## Data design

Custom `Resource` definitions with typed fields:
- `ItemDefinition`: id, tags, max_stack, weight/slots, icon/scene reference.
- `RecipeDefinition`: id, station, costs, outputs, unlock/evidence.
- `WeaponDefinition`: id, fire timing, ammo id, projectile definition, handling/recoil.
- `EnemyDefinition`: id, role, perception, behavior profile, salvage table.
- `RegionDefinition`: authored bounds/identity, ambient preset, population and loot tables.
- `DiscoveryDefinition`: evidence id, prerequisites/condition, note/bark candidates, follow-on hypotheses.
- `FurnitureDefinition`: id, footprint, preview, placeability and applicable facility behavior.

No data-oriented framework necessary. Prefer explicit constructors/validation and stable IDs, with resources authored in editor.

## Saving & versioned world state

Persist a **versioned save DTO/dictionary**, never raw scene instances. Include:
- world seed, calendar/epoch, player global position and active interior;
- inventory/storage and equipment;
- injuries/fatigue/composure/hunger/hydration;
- shelter furniture, facility and crop state;
- notebook evidence/notes; discovered places;
- per-chunk persistent deltas (container opened, switch activated, entry opened, significant enemies/events);
- exact main refuge security/activation state.

Use Godot FileAccess under `user://`, with atomic-ish write using temporary file + safe replace where platform permits, error checks and a recovery copy. Serialization and schema validation must be testable; planned saves shouldn't depend on JavaScript IndexedDB or Gemini prototype data shape. No obligation to migrate old prototype saves.

Browser storage persistence/reload behavior must be explicitly tested after HTML5 export. Cross-scene state transitions must be idempotent and not lose unsaved changes.

## Dynamic lighting

Choose Godot's **2D lighting system**, not Forward+ 3D pipeline:
- CanvasModulate ambient tint with interpolation over day/night.
- PointLight2D fixtures, some DirectionalLight2D ambience.
- LightOccluder2D and selected normal-mapped materials where helpful.
- Lighting zones for interior/exterior and color-mood presets.
- Controlled active light count; only nearby interactive lights need updates.
- Test Compatibility/WebGL2 output, shadows, and performance early; do not promise Forward+ features on web.
- Avoid generic flood of neon effects and loss of visual readability.

## Test strategy & playable gates

- Pure GDScript unit-style checks for inventory transactions, recipe costs, deterministic loot, saved delta replay, injury/modifier bounds and discovery gating.
- Headless import/parse startup of Godot project at each coherent milestone.
- Manual gameplay smoke: walk/aim/shoot/loot/return/decorate/save/reload, chunk seam crossing, Web export.
- Performance checks at real target viewport and machine budget; tune for stable, responsive input first.
- Prefer local/connector-independent checks; avoid GitHub Actions unless a specific need is established.

## Decisions for prototype validation

World tile/chunk size, exact normal-map/sprite workflow, handheld controller/touch support, panic loss-of-control toggles, file system persistence details in Web export, and final minimum performance target remain open. Record experimental results in design notes before overengineering.
