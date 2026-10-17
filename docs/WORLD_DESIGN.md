# World, Shelters & Discovery — Design

## World rule: machine civilization, not human ruins

No cars, streets, skyscrapers, houses, shopfronts, highways, streetlights, billboards or abandoned human urban infrastructure. Terrain is engineered by and for machines: conduits, pylons, fabrication bays, coolant basins, suspended gantries, servo assemblies, maintenance channels, robotic scrap fields and giant purpose-built installations. The contrast is that Yuna's shelters are tiny human nests *within* an inhuman landscape.

The world should feel large in **scale cues, sightlines and ambient sound**, not necessarily by map square kilometers.

## One continuous exterior

A single persistent global world coordinate space. Four **authored geographical identities** may graduate across the same terrain; region labels are optional and must not imply disconnected level selection:

| Provisional region | Landscape | Salvage affinities | Machine ecology |
|---|---|---|---|
| Ash Flats | powdery metal-silicate flats, derelict frames, buried conduits | common scrap, batteries, insulation | scavengers, sweepers, small drones |
| Cable Forest | transmission trunks, hanging wires, relay trenches | wiring, sensors, capacitors | drones, watch patrols, non-hostile maintainers |
| Dead Foundry | autonomous presses, conveyors, furnaces, robotic arms | alloys, heavy parts, advanced components | guardians, heavy reclaimers |
| Coolant Basin | pipes, basins, mist, siphon pumps, synthetic fluids | filters, chemicals, thermal hardware | utility machines, heavy protectors |

Players walk between regions; landmarks, hazards and silhouettes teach navigation. Some building interiors, caves and shelters can have controlled scene transitions. Roads and human-world urban ruins must not sneak into the art.

### Geography authority

- Hand-author terrain, paths, natural transition bands, hard barriers, refuge site, major landmarks, clue locations, safe return routes and critical supplies.
- Procedurally vary **population**, not geography: local salvage selection and amounts, wandering patrols, machine malfunctions, short events, and rare finds.
- Preserve coherent environmental stories: active machine routes, reason for resources and noise, functional machinery.
- Multi-route traversal and cover; do not funnel every player into a shootout.

## Chunking without building a streaming engine

- Chunk boundaries are an **implementation concern**, not in-world borders or loading screens.
- For first slice, hand-author a few neighboring chunk scenes on a shared grid and test crossing without teleportation.
- Stream player chunk + neighbors, preload early and retire distant scenes after persisting meaningful state. Tune chunk dimensions/radius using actual camera and browser profiling rather than document fiction.
- Stable world-space IDs: `world/<chunk-id>/<entity-id>`. Record persistent deltas (looted/changed/disabled/visited), not enormous serialized SceneTrees.
- Authored scenery is stable. Procedural population comes from `world_seed + chunk_id + spawn_epoch + table_revision`; persistent changes override generation.
- Important discoveries exist in stable authored positions, *never* behind weighted RNG, including all viable ways to understand the mesa entrance.
- Offscreen world follows a coarse calendar/event model if needed, **not** a full constantly running AI simulation.
- No loading stutter at borders; if complexity appears, simplify scene count/geometry before custom threading.

## Shelter I — The Little Nest

### Story identity

Yuna's first home: a **small, modest underground hideout** repurposed from a machine-era service cavity or carved passage. Do not depict the full two-level mesa compound as her starting home.

### Playable interior

- A sleeping corner with practical quilt and light personal items.
- Tiny heater/lamp, improvised cooking setup, basic workbench and salvage storage.
- A few editable furnishings/decor spots without blocking hatch or work areas.
- Limited water storage/filtration and backup power; little or no developed indoor farming.
- Sealed, concealed hatch leading to the open exterior. Warm audio, small rituals, hints of past life with Mother.
- Short meaningful activities: eat, rest, make repairs, tidy/decorate and prepare for sortie.

It is not a tutorial room to abandon. Keep it accessible after discovering the larger shelter. Objects and decorations stay where the player left them.

### Continuity with Gemini experiment

The older `yuna_the_warmth_below (1).tsx` implemented a visually larger **two-level mesa shelter** with garden sun court, living area, fixed bench/cook/storage, placed furniture and exit. Treat its **small domestic living arrangement, lighting, furniture categories and interactions** as a reference for the Little Nest. Do **not** copy the two-level architecture into the starting scene. Reserve the sun court and expanded facilities for the hidden mesa.

## Shelter II — Hidden Mesa Refuge

### Design identity

A secluded, secured multi-level facility carved into a giant rocky mesa. It contains a protected sun shaft/court, larger living and growing areas, upgraded power/water capacity, maintenance access and concealed routes. It is a physically discoverable destination, not an automatically awarded property.

### Its secrets and opposition

- Machinery nearby appears to be responding to something still operating deep within.
- A credible robot interest (power source, protected archive, fabrication utility or security protocol) motivates their attempted entry.
- Old and new attempts to access it leave environmental clues. Some machines can inadvertently reveal pathways.
- Entrance might demand a recovered sequence, repaired interface, mechanical reroute or alternate access. Exact answer **TBD**; several clue paths and at least one fair solution required.
- Discovering the entrance does not automatically make its interior safe or habitable.
- Player may secure/restore enough of the facility to use it, then continue improving it in sandbox.

### Emotional counterpoint

Yuna can be impressed by the mesa's potential and still hesitate to leave her tiny first home. Familiarity and personalization can make a less secure shelter more restorative until the new space becomes known. Avoid a formula where square meters or rug count literally equals mental health.

## Discoveries, notes & player agency

Discovery events should come from actual world interactions: inspecting a corroded service mark, triangulating a faint relay, watching a patrol attack a sealed door, finding a wiring diagram, returning to re-examine a mechanism.

Notebook entries have a staged structure:
- **Observation:** what Yuna definitely saw/heard.
- **Hypothesis:** her current possible explanation (may be incomplete).
- **Personal plan:** something she *chooses to try*, optionally pinned.

Support overlapping clue orders and updating conclusions. No quest giver, no full-world markers for unseen objectives, no predetermined list of “Restore water / Restore power / Restore sun” in the HUD.

Yuna's own voice is the diegetic hint surface, frequently in second person (supportive, sardonic, nervous); notes are authored and offline-first. Do not hard-couple notebook generation to an LLM API or online account.

## Dynamic events — examples, not required exhaustive set

Repair patrol moves through relay valley; abandoned machine briefly powers on; scrappers attempt to open sealed mesa vent; electrical interference disrupts visibility; a wreck exposes a fresh salvage pocket; neutral sweeper inadvertently opens a maintenance bypass.

Use modest encounter pools keyed by local ecology and time. Respawns are bounded and inspectable. Changes affecting discoveries and entry routes persist.

## Release-scale level design limits

Small enough to traverse by foot in meaningful minutes; landmarks distinct; every important area connects to at least one safe-ish return route; rare materials have grounded sources. Exact square footage, tiles, region counts and chunk dimensions to be determined by prototype observation and performance, not locked now.
