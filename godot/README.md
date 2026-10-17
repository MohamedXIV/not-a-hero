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
