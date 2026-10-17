# Not a Hero — Godot development

**Engine:** Godot 4.7.2, typed GDScript; Compatibility renderer for HTML5.

## Foundation + first scavenging loop

- WASD move, Shift sprint, E interact, F6 / on-screen Save.
- Little Nest → fixed connected outdoor chunks → authored scrap cache (3 scrap + wire) → Workbench relay fuse crafting → repair/activate maintenance relay.
- Loot and relay state persist with a versioned `user://` save; also verified on Chromium with IndexedDB and reload. Source is a clean rebuild, not a port of the Gemini TSX reference.
- Current art and room geometry are **visual placeholders**. They do not establish the final art style.

## P1 combat preview (work in progress)

- Outdoors: aim with the mouse, left mouse shoot, 1/2 selects Pistol/Rifle, R reloads.
- Fire interval, magazine/reserves, damage, range and sound profile are weapon Resources.
- Cover blocks hitscan shots. Ammunition persists between saves.
- Cable Forest edge has an aggressive Survey Guard that patrols, hears shots, investigates, detects exposed Yuna, pursues and loses her after retreat. Attacks cause a short **stagger** without displaying an HP bar; full injury mechanics belong to P2.
- Ash Flats contains a **neutral maintainer**; it doesn't chase or attack.
- Destroying the guard permanently records its world state in the current save. Intermediate robot damage is not persistent yet; no randomized respawns in this slice.

## Actual tests

```text
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/inventory_smoke.gd
godot --headless --path godot --script res://tests/session_state_smoke.gd
godot --headless --path godot res://tests/world_chunk_smoke.tscn --quit-after 180
godot --headless --path godot res://tests/movement_smoke.tscn --quit-after 180
godot --headless --path godot res://tests/combat_smoke.tscn --quit-after 300
```

CI also runs a graphics preview with Xvfb and a separate, expensive optional HTML5/Chromium test.

## Out of scope in the current combat PR

True wounds/first aid, composure, resource-driven ammo crafting, enemy population ecology and region-weighted dynamic loot. This P1 batch should be reviewed as mechanics rather than finished art or an entire game.

## New: storage & region-aware salvage

- The Little Nest has a working **StorageChest** near the living space. Walk close: **E** deposits the complete bag; **Shift+E** withdraws stored contents (all-or-nothing if carrying capacity allows). Chest stores up to 120 unit-items; the bag carries 24.
- The guaranteed authored cache still provides the ingredients for the relay fuse, so progression never depends on good luck.
- Extra salvage caches exist in the Ash Flats, Cable Edge and Relay Waste chunks. They use distinct `LootTableDefinition` Resources with weighted entry resources and deterministic seeds. Terrain itself is unchanged between worlds.
- New games generate a world seed; it is saved with inventory/storage/looted flags. Opened caches remain depleted through chunk reload and save/reload. Region content is not rerolled by walking away.

## P2a — embodied Yuna (first slice)

- Yuna has no HP bar: contact causes a short stagger and a leg condition. The saved condition tracks arm/leg/torso severities independently, with slow rest recovery.
- Stamina fuels sprinting, recovering during calm movement. Fatigue, nourishment and hydration shift *slowly*, separately; penalties to movement/reloading/aim are explicitly capped.
- Sustained direct robot sight lowers **composure**. It is execution under stress, never intelligence. When overwhelmed Yuna defers precision crafting, but recovering in the small shelter always unlocks it again.
- Near the original bed, **E rests** and advances six in-game hours. This restores focus and some injury condition; no daily excursion or forced task.
- **Tab** opens condition details. During ordinary play, only pertinent fatigue/injury/stress cues appear, not six permanent bars.
- Ordinary motor/vocal tics remain independent of fear and stealth. No random panic scream is implemented.
- First aid, actual drinking/cooking, contextual bark selection and shelter decoration are later P2 slices, not falsely claimed by P2a.

## P2b — first aid & finite home supplies

- A new run starts with two `Field Dressing` items. **F** applies one to an untreated injured body part (prioritizing torso, then leg, then arm). Treatment consumes exactly one dressing, marks the wound dressed and eases its penalty; it does **not** instantly erase injuries. Sleeping gradually heals injuries and can clear the dressing once healed.
- The Little Nest has a cooker station (walk close, **E** to eat) and a water vessel (**E** to drink). Starting supplies are **four meals and six waters**, consumed only if needed. No endless refills or required daily sortie yet; later shelter systems can provide replenishment.
- Food/water and bandaging status are validated and saved with the condition. No HP bar, arbitrary panic, or cloud inference.

## P2c — character voice, accessible subtitles and ordinary tics

- Yuna's self-talk is **authored** and only fires from facts she experienced: a robot spotting her, injuries, a dangerous escape, scavenging, workbench crafting, successful repair, safe return, bed rest, first aid and home meals/water. No AI API, guessing unseen secrets, or generated dialogue.
- Independent `YunaVoice` applies priorities, global and per-event cooldowns, and rotating alternate authored lines. Threat/injury can preempt incidental thoughts; everyday comments never interrupt urgent warnings.
- Spoken text appears in a bottom subtitle with no audio/TTS dependency. **V** toggles incidental remarks while urgent warning events remain eligible. **B** toggles the subtitle display; critical gameplay feedback still appears in the existing HUD. Settings persist in the versioned save v7.
- Ordinary brief shoulder/strap tics continue whether she is calm or distressed. They are purely visual, not tied to stress, stealth detection, AI hearing or a random scream. Further art/animation variety is planned later.
- Added pure scheduler and real-scene tests for subtitle visibility, workbench speech, priority/cooldown, settings restore and calm/distressed tic independence.

## P2d — Actual Little Nest furniture arrangement

- New-game bag holds one **Patchwork Rug** and one **Little Warm Lantern**. In the starter shelter, **G** enters/exits decor mode, **1** selects rug, **2** lantern, **left click** places at a snapped 16-unit grid position, and **X** retrieves the piece beneath the pointer.
- Placement previews use green/red outlines. It is impossible to block the bed, kitchen, workbench, storage, water station, hatch or clear exit path, or overlap existing furnishings. Invalid placement never consumes an item.
- Rug is floor decor; lantern has a true Godot PointLight2D and a physical collider, both rebuilt from the authoritative placements when reloading the shelter.
- Pickup returns the exact piece to the inventory only when space permits. Placements persist in validated save schema v8, with exact coordinates and invalid-save rejection.
- Assets are provisional color blocks; the approved art style still needs human review. Further crafted furnishings/comfort uses may be added in P2 later.

## P2e — small renewable life-support and quiet routine

- Passive, **bounded** Little Nest life support uses *in-game elapsed minutes*: condenser matures **one water portion per 240 minutes** (up to four uncollected); the home nutrient culture yields **one meal + one fiber every 480 minutes** (up to two uncollected). Nothing respawns because a scene reloads, and reaching the capacity halts further production.
- The condenser lives by the right wall and the culture tray near the left lower wall: approach and press **E** to collect. Finished meals and clean water are still consumed at the original cooker/water vessel. Home stockpiles cap at twelve portions each. Harvesting culture needs one free bag slot for fiber; if it is full, *no materials or food are lost*. Both stations retain their progress after game save and reload.
- In the workbench, **C** makes one Field Dressing from two harvested culture fibers; **E** still makes the relay fuse. Existing composure/focus gate applies to both crafts.
- A nearby familiar radio offers **E — unwind**, a 20-minute short personal ritual. It gently improves composure/fatigue and has a 180-minute cooldown. It never produces random stealth warnings, consumes supplies or grants compounding furniture happiness multipliers.
- Sleeping advances six in-game hours of production. GameSave v9 persists progress, ready reserves and radio cooldown. Temporary visuals and story/audio remain unapproved.
- This is a forgiving renewable safety floor for cozy play, **not a complete ecological/nutrient/energy simulation**. Tuning remains a future human playtest task.

## P3a — Observe first, write later

- Two **hand-authored** mechanical observation markers are placed in the existing continuous Ash Flats/Cable Forest scenes. Inspect with **E** to record facts Yuna actually sees. They are *not* random drops; either may be examined first and chunk reload never erases their entries.
- Press **N** for the personal Notebook, **J** to read the next entry and **P** to pin/unpin it. Entries distinguish a concrete **observation**, a tentative **hypothesis**, and Yuna's optional **personal plan**. The notebook starts empty, not a list of predefined quests or tasks.
- A tentative connection between the two findings appears **only after observing both**. It does not reveal a destination, code, hidden entrance, or story fact Yuna could not yet know.
- Authored local remarks use the existing YunaVoice cooldown system. No LLM, network call or HUD quest arrow.
- Validated v10 saves persist discovered IDs, order and selected pin. Malformed/unknown discoveries are rejected with no partial load. Geometry and clue locations remain fixed.
- This is the **first P3 slice**, not the complete four-region world, advanced machine ecology, full notebook editing or the hidden mesa clue chain.

## P3b — four continuous authored machine regions

- The contiguous 640-unit exterior grid is now **Ash Flats → Cable Forest → Dead Foundry → Coolant Basin**. The formerly named Relay Waste chunk retains its stable scene/node/world identity for existing saved machine/cache state, but has a distinct Dead Foundry regional landscape of autonomous presses and conveyance machinery. The fourth Coolant Basin has fixed channels, siphons, cold light and powered pumps. The camera/physical boundary extends through world X=2560 without any region loading screen.
- The Coolant Basin has a region-specific deterministic loot table (recovered filter/capacitor/alloy), a fixed filter cache that stays depleted once taken, and a distinct harmless Coolant Servitor following an authored maintenance path. Geometry and clues are authored, not randomized.
- Both the Foundry press and basin siphon support **E to examine**. Each contributes a genuine observation, tentative hypothesis and personal plan to the existing notebook in any order. A connection between their timing pulses is inferred only after witnessing both; it is not a revealed quest marker or knowledge of the hidden mesa.
- Godot scene smoke verifies all four chunk resources, Foundry/Coolant player transition, actual inspection, nonhostile servitor, loot persistence, streaming unload/reload and Notebook snapshot. Earlier P0–P3a regressions remain in the suite.
- Visual geometry and robot animation are *provisional*; broader ecology, environmental events, multiple mesa access routes and full 1–3h balancing remain future work.

## P3c — a coarse living machine world, even when Yuna is away

- `MachineEcology` stores a **monotonic elapsed-world clock** in addition to the familiar 24-hour dial. The clock advances during ordinary play, six-hour bed rest and twenty-minute radio rituals. Events are derived in O(1) from **world seed + region + 360-minute epoch**, never an always-running offscreen AI or mutable RNG state.
- The Dead Foundry and Coolant Basin now each have an *optional* maintenance site, inspector-authored `MachineEventDefinition` Resource, and occasionally active neutral crew. Shifts are visible on authored terrain and do not target or detect the player. Idle and active states reflect what happened while Yuna was away.
- During an active shift, an optional spare **alloy** (Foundry) or **coolant filter** (Basin) can be collected **once per region per shift**. Overflowing carry capacity never marks the loot collected; chunk unload/reload, repeat clicking or save/reload never duplicates it. This is bounded optional content, not critical progression or a hidden clue.
- State persistence is **O(regions)** (last claim per region, not one world flag per event epoch). Save schema v11 validates elapsed minutes/claims atomically. Authored clue locations and existing static salvage caches are unchanged.
- The two event nodes use existing non-hostile robot scenes and are intentionally a narrow ecology foundation, not a claim that rival machines fight one another or a complete simulated society.

## P3d — two evidence-based ways to suspect the eastern stone shelf

- Two hand-placed, fixed and inspectable engineering artifacts: the **Eastbound Feeder** in Cable Forest and **Buried Return Manifold** in Coolant Basin. Both are distinct machine structures rather than random loot, quest arrows or automatically awarded notes.
- Yuna can deduce an *uncertain* possible eastern-shelf installation via **either independent route**: warm Ash Flats conduit + eastbound Cable feeder (power route), **or** Dead Foundry shift-cycle press + buried Basin return manifold (service route). Each route needs just two witnessed observations, in either order. One clue alone reveals no route and nothing provides a door location, access code or obligation to go there.
- Existing older clue connections are unchanged. Notebook `available_connections`/ `mesa_leads` are authored data associations; on-screen journal shows only conclusions related to the currently open entry. No hidden clues or synthesized page information from an unvisited biome.
- The small articulated silhouettes of these two artifacts are provisional engineering markers (feeder bus vs pipe header), pending P5 art. P4 owns the *physical* eastern mesa site, its approach choices and actual opening sequence; these observations never gate P4 entry.
- Automated tests validate both real in-world inspection routes, distinct observation order, no unseen fact leaks, streamer reload, disk save and scoped notebook UI, plus all older regressions.

## P4a — playable mesa access and first secure interior

- An authored rocky mesa shelf and scored physical hatch appear at the east side of Coolant Basin, with a non-hostile servitor visibly investigating the site. The location exists independently of the optional Notebook leads.
- `MesaState` records inspection, a three-stage slow emergency handwheel release, an alternative relay-fuse coupling, the single successful opening method, and whether the initial interior sector is safe. These facts are validated in v12 session saves.
- A separate large mesa interior scene has a shaft of real daylight, initial utility room, sealed rear sectors and a safety control that the player can activate once. The Little Nest remains unchanged and can be revisited; returning outside preserves both locations.
- **Playable exterior access:** approach the hatch near the eastern rock shelf, press **E** to inspect it, then either **E** three times to release the manual cams (takes 20 in-game minutes per stage) or **Q** to install an optional carried relay fuse. Press **E** at the opened hatch to enter the mesa; **E** at the safety panel isolates the first sector; **E** near the interior exit returns Yuna outside. She can still travel back to the Little Nest.
- A dedicated `mesa_player_route_smoke.tscn` test sends real mapped E/Q key events through Main's scene transitions using **both opening methods**, then returns to the original home and reloads both home states from disk. [Godot 4.7.2 full CI #39050032333](https://github.com/MohamedXIV/not-a-hero/actions/runs/39050032333) passed the complete P0–P4a regression suite and Compatibility screenshots.
- The shelter remains partially dark/unpowered. Full restoration, customization and broader P4 emotional milestone are further slices, not complete here.
