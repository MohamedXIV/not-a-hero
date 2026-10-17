# Not a Hero — Decisions & Open Questions

**Status:** design baseline (17 October 2026). This document separates agreed direction from hypotheses; do not silently turn an open choice into a requirement.

## Agreed / non-negotiable

- **Identity:** Yuna's quiet, personal survival and cozy life amid an immense robot-only world. She is not a soldier, chosen hero, or blank avatar.
- **Engine:** Godot 4.7+ stable, **typed GDScript**, native 2D. Target desktop and HTML5; the browser matters but does not dictate the engine.
- **Camera:** elevated/three-quarter top-down *art presentation* over a consistent 2D orthographic gameplay plane. Yuna should be relatively large and legible, with expressive animation.
- **Lighting:** dynamic 2D light, shadow, ambience, day/night and mood contrast are first-class requirements. Validate browser compatibility early.
- **Exterior:** one **continuous, hand-authored, connected open world**, with geographical regions flowing into each other. No region-selection fast travel in place of walking; small caves/complex interiors and shelters may load separate scenes.
- **Streaming:** simple authored chunks near the player with stable world coordinates and state persistence. Do not build a general-purpose streaming engine prematurely.
- **Variation:** region-sensitive seeded dynamic loot, enemy populations, patrols and events; **NOT** randomized world geography on every new game.
- **Progression:** no quest givers, imposed objective lists, or omniscient quest markers. Yuna observes, deduces, speaks to herself, and optionally records plans in her notebook. Important clues are authored and always obtainable; randomness may not gate completion.
- **Shelters:** start in a **small, modest underground hideout** with a bed, basic cooking, workbench, storage, light and a few decorations. Later discover and potentially secure/open a substantial fortified refuge in a rocky mesa; it is an aspirational destination, not a starting home or a guaranteed automatic upgrade. Old home remains usable and emotionally meaningful.
- **Character:** Yuna is 18, short (~155 cm), pale, light green eyes, muted auburn braided hair, petite/soft/slightly chubby; kind, reserved, fearful, technically exceptional, stubborn, funny, self-aware. Small vocal/motor tics are part of her normal rhythm; **not a diagnosis, joke or an exclusively stress-triggered effect**.
- **Character self-talk:** often second-person address to herself (“Yuna, you idiot”; “Brilliant plan, Yuna”), plus gentler reassurance. Serves characterization and contextual hints; not a disguised quest narrator.
- **Needs:** localized injuries + recovery instead of a visible numerical HP bar; stamina; accumulated rest/fatigue; composure; hunger; hydration. Keep meaningful distinctions and avoid six permanently visible meters.
- **Composure:** impacts steadiness, focus and panic responses when strained, but **never changes Yuna's actual intelligence**. Low-state involuntary outbursts/brief hesitation may affect stealth with legible warnings, cooldowns and recovery options; do not randomly punish ordinary tics.
- **Combat:** real-time pistol + rifle with fast weapon switch; robotic enemies can be fought, evaded or distracted. Combat is dangerous but not mandatory for every interaction. No default permadeath.
- **Cozy play:** cooking, decoration, maintenance and eventual growing should be genuine gameplay, not window dressing. No forced daily combat, overbearing need timers, or punishing quiet home days.
- **Duration:** deliberately compact **1–3 hours for an ordinary first guided-by-discovery playthrough**, then free-form sandbox.

## Strong direction but subject to playtesting

- Godot composition through small reusable Scenes/Nodes, signals, custom Resource definitions, thin services and minimal Autoloads; SOLID where useful, not architecture for architecture's sake.
- A small world with authored landmarks and a few varied regions (Ash Flats, Cable Forest, Dead Foundry, Coolant Basin are provisional place names from the previous experiment).
- 3 logical hit zones for Yuna: arms, legs, torso; three severities with first aid and rest; player-facing symptoms rather than arbitrary damage numbers.
- Composure modeled as one value with context-sensitive ranges; recovery from familiar shelters, rest and meaningful activities; thresholds are tuning data, **not fixed numbers yet**.
- Keep hydration and hunger separate and relatively slow, with environmental/resources relevance and readable contextual warnings.
- The mesa refuge attracts machine attention for intelligible systemic/story reasons. Several ways to learn about it and potentially enter, without a random rare-drop key or a mandatory boss.
- Use a single authoritative gameplay state flow; do not use the UI layer as the simulation host.

## Deliberately undecided

- Final **art style** (pixel art, illustrated/sprite-based, painterly, other), sprite dimensions and animation production pipeline.
- Exact size of the world, chunk size, preload radius, population counts and item recipes.
- Whether extreme composure can briefly interrupt control; test fairness with explicit cues and escape paths before committing.
- Granularity of injury hit detection (logical zone vs directional 2D hitboxes), severity/recovery rates and whether fatal outcomes are possible.
- Final narrative details of the hidden refuge, its code/secret, machine motivations and the sandbox's end-state.
- Input support and final minimum target browser/device specifications.

## Baseline & migration boundary

The existing `yuna_the_warmth_below (1).tsx` on `main` is a **playable reference only**. It is a 5,533-line React/Canvas single file containing content catalogs, seeded region generation, procedural sprites, audio, interactions and saves. Do not port, divide, or auto-translate it. Reimplement cleanly in Godot from first principles. Review for *what felt good or bad*, not for code to copy.

Documentation is the current work product. Do not treat future roadmap items as already implemented.

## P4e working interpretation — not final Mesa canon (2026-10-17)

The present **gameplay evidence**, not an omniscient plot reveal: a nonhostile servitor repeats a clock-based approach to the Mesa hatch; an ancient live carrier in the accessible rear gallery acknowledges maintenance through buried utility lines. Inspecting both permits Yuna to **hypothesize** a connection. At the local terminal she can reversibly divert the service reply toward an old reflector; the robot visibly changes route, even after world streaming/saving. No machine is slain, and none locks her out of the home.

This does **not** settle who originally sent that service request, whether the machines' wider interest is benign, or what lies in deeper sealed equipment. Those aspects remain open story decisions. The observable motive for *this one* ordinary servitor is a maintenance acknowledgement, not a universe-saving MacGuffin; alternative future explanations remain possible. No clue note appears before direct player observation, and neither optional note nor diversion gates the hatch, Sun Court, chosen first night or sandbox.

## P4f provisional lower gallery evidence — final mystery still deliberately open (2026-10-17)

Under the already recovered rear corridor, a working but pressure-isolated **service lift** leads into a distinct lower thermal gallery. Yuna can release the lift mechanically (40 world minutes, no drops or combat) after restoring circulation, **or** use an already diverted maintenance return as an optional instant shortcut. Neither notebook discovery nor the redirected signal is a required unlock.

The lower gallery physically contains an **empty environmental cradle**, sealed temperature records, two pieces of solid machinery, and a reversible warmth/standby control. Reading the log (direct E inspection) adds only what Yuna can verify: narrow preserved temperature conditions, repeated maintenance traces, and nothing identifying the occupant, manufacturer, sender or wider purpose. The optional connection to the earlier P4e service carrier exists **only after witnessing both**. Resting in the lower alcove becomes possible once Yuna restores gentle heat; it grants ordinary shelter sleep, not an infinite pickup/resource faucet. The choice persists and remains reversible on re-entry.

This is an atmospheric working interpretation of the lower installation, **not** a canonical declaration of what was protected here, who/what lived here, or why other machine groups might want it. No world-saving reveal, no identity link to Yuna, no claims about lost humanity or definite maker. Those unresolved questions stay open for deliberate story design. Little Nest and the upper Mesa remain independently usable.
