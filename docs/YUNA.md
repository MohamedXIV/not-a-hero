# Yuna — Character & Embodied Systems Bible

**Character status:** agreed baseline; exact balance, visuals and barks remain iterative.

## Who she is

Yuna, age **18**. Irish-English ancestry, pale complexion, muted reddish-brown/auburn loose practical braid, light green eyes, freckles optional, short (~155 cm), petite with soft/slightly chubby natural proportions. Clothes are handmade/worn: short practical tunic, imperfect knee socks, worn sneakers; outdoor jacket/backpack when appropriate.

**Important:** 18-year-old with adult moral agency and exceptional engineering talent. She is socially inexperienced, hesitant in the hostile world and emotionally attached to security, not a child or an incompetent caricature. Her competence is most obvious when she can focus on machinery.

Core qualities: sweet, reserved, considerate, anxious, curious, technically gifted, awkwardly witty and quietly stubborn. Contradictions matter: she can be caring yet self-protective, scared yet persistent, shy yet absorbed and talkative about tools. She does not volunteer to be a hero.

## Ordinary rhythm: tics, habits and reactions

Yuna naturally has brief small vocal/motor tics (soft click, short sound, small movement); these exist **even when safe, happy or concentrated**. They are not framed in-game as a diagnosis or illness, not a moral flaw, not comic punishment, and not a mandatory indicator of anxiety. They must not automatically betray stealth.

Separate three channels:
1. **Involuntary tics:** independent of the panic mechanic; low frequency, varied, unremarked by the game.
2. **Repetitive speech/self-talk:** “Okay, okay…”; speaking to machinery as if it listens; often addressing herself by name in the second person.
3. **Self-soothing habits:** smoothing tunic, gripping backpack strap, holding braid, aligning tools; voluntary or habitual coping behavior.

A stressed state may change voice, pacing and body language and **could** provoke a separate panicked gasp/shout, but do not equate panic with her usual tics.

Mother knew and accepted Yuna naturally; the missing reply after self-talk or a familiar habit can carry subtle emotion. Do not turn this into repetitive trauma exposition.

## Second-person self-talk

Authentic examples, to be written contextually rather than repeated verbatim:
- Exposed: “Yes, Yuna. Just walk into the open. Brilliant way to get shot.”
- After clumsy cooking: “Well done, Yuna. You burned water.”
- Thinking through device: “Come on, Yuna. You've fixed worse than this.”
- After narrow escape: “You're alive. Everything's fine… Everything is absolutely not fine.”
- Finding a conduit clue: “Wait, where does that cable go? Think, Yuna.”
- Growing self-trust: “Okay, Yuna. You've done this before.”

Balance barbed humor with gentleness, ingenuity, gratitude and pride. Avoid constant self-abuse. Self-talk is a personal coping/observation medium, not an omniscient game announcer.

### Contextual bark rules

- World or need system raises event with facts Yuna knows.
- Bark selection chooses an authored, condition-matched candidate with priorities, anti-repeat and cooldown; no continuous talking.
- Observations may update notebook; most incidental barks do not.
- Player may reduce/mute incidental voice while retaining written essential hints/subtitles.
- No AI/cloud API required; the previous Gemini experiment's API journal/TTS is a **reference idea**, not a runtime dependency.
- Do not write facts from discoveries not yet encountered.

## Physical condition instead of an HP bar

Injury model: location (**arm, leg, torso**) and severity (**minor, moderate, severe**); exact left/right granularity and collision algorithm remain TBD. A movement collider is separate from the logical injury zone resolver.

- **Arm:** less stable aiming/reloading, difficult precision work.
- **Leg:** compromised speed, sprint and stamina efficiency.
- **Torso:** exertion and endurance impaired; severe cases need immediate stabilization.
- **Field first aid:** stops deterioration/mitigates risk, not magical instant full healing.
- **Shelter care + rest:** long-term healing and return to normal; serious injuries may make a trip inadvisable but should not freeze all gameplay.
- **Defeat:** consequence and recovery, no default permadeath; protect decorated homes and essential story clues.

Use internal numerical quantities if deterministic calculations need them. Present readable status (“Bruised leg”, “Bandaged arm”, “Needs rest”), with optional detail panel. Avoid graphical gore and long-term punishment loops.

## Stamina, rest, hunger and hydration

- **Stamina:** short-cycle action exertion; primarily affects sprinting/evading; recovers when not exerting.
- **Rest/fatigue:** accumulates from missed sleep and prolonged work; changes stamina recovery and concentration, resolves through sleep/rest.
- **Hunger:** slow need reflecting nourishment and cooking/growing gameplay. Neglect affects exertion/recovery.
- **Hydration:** separate, somewhat faster need connected to water filtration, resources and physical conditions. Neglect affects exertion/focus.
- Build gentle rates, good supply affordances and contextual warnings. **No constant micro-managing all needs**.

## Composure — the distinguishing system

Composure = Yuna's *current ability to stay collected and apply her skills*, **not her courage, happiness, IQ or worth**.

Potential drivers (balance TBD):
- Down: being hunted, darkness in risky spaces, hurt, exhaustion, uncertainty, a frightening near miss.
- Up: reaching safety, familiarity with surroundings, warmth, food/rest, deliberate calming, repairing something, quiet routine.
- Recovery is contextual: a familiar small nest can feel more secure than a large, unexplored, physically safer mesa refuge.
- Decorations support comfort **through plausible use and environmental atmosphere**, not arbitrary stacked happiness numbers.

State language may be `settled`, `steady`, `uneasy`, `distressed`, `overwhelmed`; exact thresholds are playtest-only tuning.

Under strain: slight aim sway, longer focus time and more strained voice. In very low composure: slow intricate crafting/hacking, or make it temporarily unsafe to start until she settles. Her *ability to execute now* declines, not her intelligence.

### Fairness contract for panic

Any strong penalty (momentary hesitation, gasp/shout in stealth, brief control interruption) must:
1. Be telegraphed through unmissable but subtle visuals/audio.
2. Follow sustained exposure; no random instant betrayal.
3. Be bounded in duration/severity and use cooldowns.
4. Offer practical responses (cover, calming pause, retreat, decoy).
5. Be testable/optionally softened by accessibility or difficulty settings.
6. Never be triggered merely by ordinary tics.

Do not stack composure, hunger, thirst, fatigue and injury penalties into an inescapable death spiral. Cap compound modifiers and preserve viable routes home.

## Animation & expression priorities

Distinct idle inside/outside, walk/run, aim pistol/rifle, shoot/reload, interact, inspect/repair, cook, rest, mild injury reactions, nervous self-soothing and occasional tics. When working on electronics, show assured hands and concentration. Outside, show alertness without converting her into a generic action hero.

Camera and sprite scale must make these readable. Final animation method (sprite sheets/cutout/other) awaits art prototype.

## UI

A clean condition view: stamina mainly during use, composure when relevant; need icons/text for hungry/thirsty/tired; injuries as named conditions. Details in status panel. The player's decision should come from Yuna's animation, spoken/written cues and the environment—not a six-bar dashboard.
