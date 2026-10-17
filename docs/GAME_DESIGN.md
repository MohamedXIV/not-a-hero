# Not a Hero — Game Design Document

**Working title:** Not a Hero (Yuna: The Warmth Below is the earlier prototype title)
**Format:** single-player, 2D, real-time top-down, seamless-world cozy survival sandbox
**First-playthrough target:** ~1–3 hours to reach a meaningful refuge discovery/activation milestone; continued sandbox thereafter.
**Status:** design, not production-ready balance.

## Vision

The player lives as **Yuna**, an 18-year-old technically brilliant but frightened young woman who has built a fragile little home underground in an inhuman robot-made world. She does not have a mission to save humanity. She wants water, food, working equipment, safety and somewhere that feels like home. Curiosity slowly draws her deeper into the mechanical landscape, eventually revealing a much larger hidden refuge with consequences beyond real estate.

**Emotional promise:** the relief of returning home from a dangerous salvage run; the quiet pride of improving a personal space; the frightening beauty of discovering something she did not intend to seek.

### Pillars

1. **Yuna is the game:** personality, body language, self-talk, small tics, ingenuity, fear and resilience show up in moment-to-moment play.
2. **Cozy is real gameplay:** shelter decoration, cooking, repair, storage, gardening eventually and resting are rewarding without being compulsory chores.
3. **Explore by observation:** discover clues in world geometry, signals, debris, machine behavior and objects. No quest-arrow chain.
4. **A living machine world:** coherent robot behaviors, region-appropriate salvage, patrols and periodic events, not a loot-shooter arena.
5. **Risk is comprehensible:** stealth, preparation, injury, stamina and composure affect choices without unfair hidden rolls or cascading softlocks.
6. **Compact, extensible production:** authored world, small cast, limited weapons, minimal essential systems, elegant data authoring.

## Moment-to-moment loop

**At home:** assess practical supplies and physical/mental state → cook / repair / craft / decorate / rest → decide whether and where to venture out.

**Outside:** walk from the starter-hatch into a **continuous** machine landscape → notice clues / routes / salvage / machines → choose evade, fight, distract or investigate → gather what can be carried → navigate home (or another unlocked safe place).

**After return:** unpack and use resources, treat injuries, discover recipes or note a hypothesis; familiar activities aid recovery. The player is free to spend entire in-game days at home.

The player may interrupt, reorder or skip parts of the loop. No forced daily sortie and no arbitrary “must kill N enemies” objective.

## Core controls & feel (desktop baseline)

WASD movement, pointer aim, left mouse fire, 1/2 weapon change, R reload, E contextual interaction, Shift sprint, Tab inventory, Esc pause. Input actions centralized in Godot Input Map and modifiable later.

Yuna is visibly large on screen. Camera is smooth but responsive; exterior camera may zoom out somewhat for combat awareness. Short 2D colliders are gameplay geometry, independent from tall visual props. Allow modest recoil, audible reloads, obstacle cover and clear hit/telegraph feedback.

## Combat and evasion

Two long-lived weapons rather than a growing arsenal:
- **Pistol:** quick, forgiving, relatively common ammo, short-mid range.
- **Rifle:** higher impact and range, slower reload/recoil, rarer ammo.

Hostile automata have readable states (patrol, investigate, chase, attack, search/return). Neutral workers are part of the world and may be avoided. Line-of-sight and audio cues should matter. The player can run, break contact or lure patrols with decoys. No arbitrary enemies spawned onto the player.

Enemies are machines with function, not monsters with robot skins. Movement, danger, salvage and ambient sound should express their jobs.

## Needs & consequences

| System | Meaning | Effect | Recovery/interaction |
|---|---|---|---|
| **Localized injury** | Arms/legs/torso; minor/moderate/severe | Affects aim/reload, movement or exertion; serious injuries demand care | First aid stabilizes; shelter care/rest heals |
| **Stamina** | Immediate exertion capacity | Sprinting, evasion, actions | Stops or slows expenditure, naturally replenishes |
| **Rest / fatigue** | Accumulated wear and lost sleep | Limits effective stamina recovery and steady focus | Sleep and rest in safe spaces |
| **Composure** | Ability to remain collected and execute under pressure | Aim sway, focus, behavior and possible warned overwhelmed response | Safety, familiarity, self-regulation, successful repair, food, rest |
| **Hunger** | Longer-term nourishment | Energy and injury recovery when neglected | Food, cooking, growing, salvage |
| **Hydration** | Distinct water need | Exertion/concentration when neglected | Carry water, treat water, upgrade purifier |

Not all six are bars. Prefer one momentary stamina indicator, contextual composure cues, textual injuries and infrequent hunger/thirst/rest warnings. Players can inspect a full status panel. Needs are *slow pressures*, not constant bills.

No HP bar on Yuna. Internally numeric damage/severity may be used for deterministic resolution, but injuries are exposed as bodily condition with treatment requirements. Enemies may have health/durability if helpful. Injury behavior must remain fair and reversible; never let a moderate injury turn an ordinary run into an unwinnable spiral.

Composure **does not reduce intelligence**, only available concentration under pressure. Ordinary tics persist at all levels; extreme stress responses are distinct. If brief loss of control or an involuntary loud sound is used, signal it in advance, bound its impact, permit counterplay and playtest it.

## Shelters

**Starter:** a small handmade underground nest: bed, lamp, cooking setup, bench, storage, personal effects and few decor positions. Limited utility, still playable/cozy; retain it even after late-game progress.

**Hidden mesa:** an authored, meaningful discovery at the far end of player curiosity. A secure, larger facility with sunlight, room for growing/engineering and contested access. Explore clues and activation methods without a quest-giver. Securing it should be a milestone, not an instantaneous “free mansion”. It can remain partly unusable until repaired, and Yuna may emotionally prefer her original home.

Both shelters have separate interior scenes, persistent object placement and sensible placement validation. Interior improvements can affect recuperation **through activity and comfort**; avoid numeric '+5 happiness per rug' exploitation.

## Discovery & notebook instead of quests

Authored world events and examined objects emit **discoveries**; Yuna comments in second-person self-talk and may write a note. A note is an observation, hypothesis or self-chosen plan. Notes can be pinned or dismissed; they are not a mandatory sequence of pre-authored objectives shown in advance.

Never show knowledge Yuna has not learned. An observation may be mistaken until refined by evidence. Major story progress is governed by world facts (found hatch, decoded signal, opened door, restored system), not visible task completion flags masquerading as world state.

**Illustrative chain:** hear atypical transmission → observe machines converging on mesa → find service marking → deduce likely access system → investigate or bypass threat → enter/secure refuge. Clues may be found in different orders, with reliable paths to essential information.

## Progression & pacing

- **Opening (~15–30 min, estimate):** first mornings in small shelter, basic maintenance, small exploration radius, first avoidable threat; Yuna starts writing notes from things she sees.
- **Middle (~40–80 min):** reach neighboring machine regions on foot; upgrade gear and home; discover strange machine movements/signals; choose leads to follow or ignore.
- **Milestone (~20–40 min):** locate/refine knowledge of mesa entrance, overcome or outthink security and rival machines, enter and make at least one part safe; quiet payoff rather than epic boss spectacle.
- **Continuing sandbox:** decorate two homes, explore unvisited landmarks, forage, fight/avoid, repair, garden and investigate machine activity.

These are **design targets, not timed gates**. No exhaustive list of mandatory tutorial tasks or a forced three-device restoration ending.

## Sandbox safeguards

- Story/lock clues authored and discoverable, never random-drop gated.
- Crafting/material routes have fallback acquisition to prevent softlocks.
- Salvage and machine events renew at controlled cadence without reloading exploits.
- Defeat uses forgiving recovery with tangible but bounded cost; preserve decorated homes.
- Exploration retains cleared and looted state appropriately.
- Audio and self-talk use cooldowns and contextual relevance to avoid repetition.

## Non-goals for the compact release

No multiplayer, procedural geography replacing authored world, player character creator, dozens of guns, extensive dialogue trees, faction-economy simulation, mandatory AI inference, online account, or sweeping main-story revelations (Apex / Fenix / Facility exposition).

## “Feels done” checklist

A new player can enjoy a whole evening in the little shelter, leave and walk seamlessly to distinct robot-made landmarks, loot and craft, react to danger through stealth or combat, sustain/recover injuries, understand Yuna through gestures and self-talk, infer the mesa refuge without an objective marker, work toward opening it, continue a living sandbox after the milestone, and save/reload without losing meaningful changes.
