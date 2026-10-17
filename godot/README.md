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

## P4b — inhabitable mesa utilities and rear gallery

- After isolating the first room, two physical service interfaces repair the Mesa in a causally sensible order: **main power**, then **coolant circulation**. Near each control, **E** works a two-step manual mechanism, with **30 in-game minutes per stage**. **Q** can optionally use one recovered capacitor / coolant filter instead. Neither part is required or spent if the system already works; both manual paths always remain available.
- Main power lights the workspace and permits Yuna to **rest on a real bench** (E); sleep advances the wider ecology and Little Nest's passive production without replacing that home. Resting is never gated by collected story notes or chance.
- Fixing coolant circulation **physically removes the rear gallery barrier**, revealing a walkable machine area, and activates a clean drinking-water tap. Actual E interaction with the tap restores hydration only if needed; it's not an infinitely claimable bag item.
- Utility state, repair methods and progress are independently validated in **v13** saves: incomplete repairs, unrepaired power with working coolant, impossible progress and invalid resource provenance are rejected atomically. Original Little Nest decor, supplies and outdoor world remain untouched.
- Godot tests include both material-free and spare-part repair routes, progress through JSON, actual E/Q interactions, powered light, bench rest, walkable rear gate, potable water, and session persistence. Provisional shapes and no detailed furniture arrangement yet; next P4 slice may extend restoration and make the place emotionally homely.

### P4c — Sun Court and a second, personal space

After opening the Hidden Mesa, securing its first room, restoring **power**, then restoring **coolant**, find the small valve console beneath the sunlit court. Press **E twice** to repair its old grow-bed feed (30 world minutes per stage, no rare materials). The soil/lighting changes physically. One crop of fresh greens matures after **720 in-game minutes**. Press **E** at the bed to eat it **when hungry**; leaving it unharvested stores only one portion, not infinite rewards. The roots then regrow without daily watering chores, even while Yuna visits Little Nest.

The Mesa's unblocked lower living nook also supports the **same G / 1 / 2 / click / X** furniture controls as Little Nest, using the same owned rugs and lanterns but a **separate persisted layout**. Lanterns emit actual light and obstruct footsteps. Avoid keeping items under the two interior entrances or repair stations. Neither shelter is relocated or replaced by the other. **Save schema is v14**; older development saves do not load. This is the first living court, not a fully restored upper habitat or story conclusion.

### P4d — Reclaim the rear quiet nook and spend a first night (Save v15)

After repairing the Mesa's coolant loop, walk past the now-physical-open rear gallery barrier to the old **acoustic screen control**. Press **E once** to pull down the baffles and recover a small sheltered cot with a warm practical lamp. It takes 25 in-game minutes, costs **no materials**, and leaves the main gallery walking lane free. Press **E** by the cot to sleep and recover as usual: it works even if the Sun Court is still barren.

After both the **Sun Court** and quiet nook have been restored, the **next time you choose to sleep in that rear cot** becomes Yuna's one-time first night in her new place. A small handmade cloth/lamp change and an authored second-person thought acknowledge that she stayed by choice. There's no cutscene, clock deadline, mandatory new decor, notebook dependency, default residence switch or world-saving objective. Little Nest still exists, remains fully decorated and functional, and you can return there whenever you want. Later sleeps in the Mesa use the normal rest system; the first-night moment is not farmable. The rest of the deep refuge remains unfinished.

### P4e — The unanswered maintenance return (Save v16)

This is an **optional environmental mystery**, not the final Mesa story revelation. In the Coolant Basin, a benign service machine circles toward the mesa hatch on a repeating world-clock cycle. Inspect the nearby **Mesa Service Tracks** with **E** to note the grooves. They are discoverable without an enemy kill or even opening the door. Once the Mesa's coolant circulation works, enter the physical rear gallery and find the **service carrier console**. Press **E** to observe an old maintenance acknowledgement, then **E** again if you choose to route its reply to a harmless reflector; the outdoor servitor then follows that line instead of coming to the hatch. **E** again restores the original response.

The game records the exterior and interior observations independently, in either order, and connects them only after Yuna has inspected both. The resulting notebook inference is explicitly tentative: the machines may be responding to an old maintenance call, but neither the sender nor the deeper Mesa's purpose is proven. World-clock behavior and reroute persist across streaming and v16 FileAccess save/load. You need not use the console for any shelter repair, crop, first night, entrance or freeplay. Provisional geometry, pending P5 art/human/browser verification.

### P4f — Beneath the Mesa: Lower Thermal Gallery (Save v17)

After opening the scored hatch and restoring the Mesa's main **power and circulation**, walk into its opened rear gallery and inspect the **lower service lift** near the top of the corridor. **E** uses the always-available 40-in-game-minute manual release; if you previously chose to divert the P4e service carrier, **E** can release the lift without that work time. **E** again descends into an actual second Godot interior scene; its own position is saved independently of the upper level. The lift back out uses **E** and returns to the same rear gallery. Neither route requires Notebook notes, combat, a rare loot item or moving out of Little Nest.

In the lower gallery, the old **temperature archive** must be physically examined with **E** before interacting with its thermal regulator. Yuna observes a carefully maintained but **empty** climate cradle; **nothing identifies** the sender, builder, former occupant or intended purpose. With the witnessed operating range, **E** at the regulator reversibly warms or cools the room and changes actual light; a rest seat provides ordinary shelter sleep **only while warm**. No repeatable salvage or hidden forced outcome. If the older unanswered carrier clue was also observed, her notebook makes a cautious connection, not a certain theory.

Testing: `res://tests/mesa_depth_smoke.gd` and `res://tests/mesa_depth_scene_smoke.tscn` cover dependency validation, genuine Main-level keyboard E entry/exit, cold/warm physical state, alternate service signal shortcut and Save v17 disk load/re-entry. These provisional geometry scenes need visual/art and real Chromium/WebGL2/IndexedDB human validation in P5.
