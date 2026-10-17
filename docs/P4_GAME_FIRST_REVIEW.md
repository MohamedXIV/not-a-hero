# P4 Game-First Review — evidence and remaining acceptance

**Status:** engineering-led review, 17 October 2026, after merged P4f PR #27. This is **not** a human blind playtest, a paced 1–3h run, or an art-direction sign-off. No final Mesa secret is approved here. Re-evaluate after human play.

## The journey as a player can actually experience it

| Play step | Actual gameplay currently implemented | Verification | Experience risk |
| --- | --- | --- | --- |
| Little Nest | Real rest/cooking/water, bench/storage, decoration and bounded passive food/water output; no forced expedition | P1–P2 model and scene smokes | First-time control discoverability, cognitive load, daily rhythm untested by blind player |
| First outdoors excursion | Continuous authored four-region machine landscape, salvage, actual avoidable combat, independent observed evidence and offscreen maintenance changes | Combat, world-region, notebook and ecology scene tests | Automated tests use synthetic positions to inspect evidence; blind line-of-sight/legibility unresolved |
| Mesa approach | Large authored eastern shelf, service tracks, curious harmless machine, inspectable hatch; fuse or always-available three-stage manual release | P3d / P4a route E/Q engine tests | How naturally a person follows either clue pair to the correct rock shelf is **unknown** |
| Make a safe foothold | E isolates first sector; working power/circulation physically changes light, available water/rest and opened rear walking passage | P4a / P4b actual-E tests | Repeated E repair stages are close to a checklist in play; they must *feel* tactile or may be dull |
| Make a home | Restored growing Sun Court, slow bounded meal, room decorations, optional acoustic screen/cot, one chosen first night after garden+cot | P4c / P4d scene E and save regressions | Emotional payoff and pacing of self-talk not human-evaluated; Little Nest must remain emotionally viable |
| Pursue machine question | Outside service wear + inside repeating carrier; player may route a nonhostile servitor elsewhere and reverse | P4e full stream/E/save tests | Robot response needs visible animation, sound and recognition at real camera scale |
| Go deeper or not | Repaired rear lower lift by manual service or optional signal route; second physical scene with preserved temperature log and reversible warm rest | P4f Main/E/save tests | New scene may be a curiosity with too little lasting payoff; deeper secret remains explicitly undecided |
| Return to life | All three interiors/nests can be revisited; furniture, production, warmth, ecology and observations remain saved | P0–P4f persistence/round-trip checks | Long-session motivation, perceived closure and freeplay purpose cannot be proven by headless tests |

## Proven code-level friction discovered in this review

1. **Interaction priority could contradict the hint.** `Outdoors` historically selected the first streamed `world_interactables` node inside a fixed radius, *not the nearest*. Basin manifold and Mesa hatch have overlapping radii, so a prompt/action could select the wrong object depending on chunk order. `MesaRefuge` hints checked the old fixed panels first, but actual E checked the new lift, carrier and nook first; these new rooms also have overlapping ranges. **P4g fix:** single nearest target per scene, shared by hint/E; Q only operates on the focused compatible machine. Test overlapping actual world props with mapped physical keyboard events.
2. **A warmed lower room did not count as a safe home to Yuna's condition controller.** Despite optional live heat and actual rest, its update loop treated every `mesa_depth` frame as outdoors. **P4g fix:** at-home recovery rates apply only with the warmed lower gallery, preserving cold service-floor contrast and Little Nest's unconditional familiarity.
3. **Tests don't prove enjoyable movement.** Existing P4 scenes verify real E/Q key input, access, usable collision, persistence and some actual walking, but often teleport Yuna to the focus point to avoid long automated travel. This is solid *engine correctness*, **not** proof of intuitively discovering the area, comfortably reaching a control, or being entertained for 1–3 hours. Do not infer pacing from smoke runtime.

## What should be done before declaring P4's compact arc complete

**Highest-value human test:** Start one **genuinely fresh game** without reading repo coordinates, docs or objectives. Stay a while in Little Nest; walk the entire outdoors on normal camera; encounter and avoid or fight a guard; discover whichever two clues are noticed organically; inspect and open the Mesa; repair essential safety/flow; optionally settle first night; explore the lower floor; return to both homes and play another day. Log where the player stops, misunderstanding of controls/notes, visible affordances, and whether the climax feels *earned*. The test is not a pass until someone other than the implementer can find the Mesa and return unaided.

**Acceptance still missing:**
- A proper *in-engine moving art comparison* and measured legibility at the actual camera/viewport, especially Mesa hatch, basin overlapped markers, lift, regulator and narrator-less home tasks.
- A measured first-time playthrough against the ~1–3h target (including dead time, injuries, repair stage repetitions and navigation).
- Actual browser WebGL2 + IndexedDB **v17** persistence with a page reload while downstairs; existing Godot compatibility renderer smokes don't exercise Chromium IndexedDB.
- An explicit conscious design decision on whether the first chosen night + optional warm archive is enough closure and on the depth of the Mesa's still-unknown secret; don't invent a lore reveal as an engineering completion trick.
- User/author judgment of story tone, human-machine confrontation frequency and quality of optional activity after the one-time milestones.

**Recommendation:** After P4g focus/recovery correctness, **do not add another interior automatically**. Prioritize one blind playable run and the most painful observed friction; if the narrative payoff still feels thin, author one emotionally meaningful *existing-room* moment before expanding geography. Keep P4 #6 OPEN until the game-first acceptance is evidenced; place art/browser/balance fixes in P5 #7.
