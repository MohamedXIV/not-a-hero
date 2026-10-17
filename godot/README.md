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
