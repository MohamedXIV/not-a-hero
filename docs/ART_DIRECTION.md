# Visual Language & Atmosphere Brief

**Known:** expressive 2D elevated top-down; Yuna takes a significant part of the frame; warm, intimate shelter contrasted with alien industrial wilderness; responsive dynamic lighting.
**Unknown:** final pixel density, exact sprite method, painterly vs crisp/graphic vs pixel art aesthetic. **Do not lock an art style in implementation prematurely.**

## Camera & projection

- Ground motion and gameplay collision use normal **2D orthogonal coordinates**; art uses angled visible sides / three-quarter props for apparent height.
- Readable human-sized Yuna at standard zoom: loose braid, soft silhouette, outfit, stance and gestures clearly visible. Not a tiny tactical marker.
- Slightly closer camera in shelters, a bit wider outside for enemy awareness and ranged aim; minimize zoom shock at transitions.
- Props tall enough to show shape but not occlude Yuna indefinitely. Fade obstructing upper walls, sort visuals by lower-foot anchor/appropriate Y-sorting.
- Avoid perspective shifts between interiors/exteriors; their visual art language should agree.

## Yuna visuals

18-year-old petite (~155 cm), very pale, light green eyes, muted auburn braid, worn tunic/socks/sneakers, simple backpack. Natural softness, not hyper-stylized baby features, not glamorous. Hands and posture show anxiety **and** dexterity, not helplessness.

Animatic/readability targets: relaxed vs alert idle; braid/fabric fidgets and everyday tics; purposeful hands at bench; injured-arm/leg variants; guarded aim. When she fixes something, animation should visibly calm and concentrate.

## Environment contrast

| Domain | Light | Material | Emotion |
|---|---|---|---|
| Little Nest | low, amber practical lamps, soft shadow, occasional warm highlights | patched fabric, reused wood/metal, warm stone | intimate, familiar, quiet |
| Ash Flats | dusty cold daylight, long machine shadows | oxidized plates, ash, conduit ribs | exposed, lonely |
| Cable Forest | fragmented light, flickering sources and blocked sky | wiring, pylons, relay housings | uneasy, watchful |
| Foundry | hot pinpoints, strong industrial contrasts | heavy steel, old castings, conveyors | oppressive, purposeful |
| Coolant Basin | cyan-grey scattering, sparse utility lights, vapor | tanks, pipes, fluid | eerie, unfamiliar |
| Hidden Mesa | initially dark/unknown; gradually opens to functional sun/warmth | protected stone, engineered shelter volumes | awe, suspicion, eventual belonging |

No human city ruins, streets, cars or human-industrial urban skyline clichés.

## Lighting implementation goals

- Use CanvasModulate/day-night tonal interpolation and localized PointLight2D + occluders in Godot.
- Some materials may use 2D normal maps for tactile detail, **if** the selected art direction benefits.
- Lamps, damaged machinery, inspection beams and transient sparks should be visible meaningful sources, not unlimited VFX.
- Light can function as navigational feedback: home/entry comfort vs unknown hostile region.
- Maintain player/enemy/readable interactable silhouettes in darkness. No reliance on full-black vision.
- Author mobile/Web fallback knobs for shadow counts and visual effects, test Compatibility renderer.

## Sound and character mood

Warm at home: low ventilation, kettle/stove, lamp hum, cloth and footsteps, softly repaired radio.
Outside: enormous distant servos, cable resonance, far-off machine movement, environmental warnings.
Music sparse and optional; ambient sound carries loneliness.

Vocal sounds/tics exist as gentle everyday details (not a reaction sound mechanically revealing her position). Panic noises are separately telegraphed and contextual. Self-addressed Yuna lines should be intimate, occasionally dry, sometimes reassuring, with anti-spam rules.

## Art-style comparison gate

Create **the same small 2D Godot scene** with Yuna, a warm lamp, metal crate, tall occluder, movement/aim and dynamic day/night. Try up to three coherent treatments (e.g., painterly illustrated sprites, clean graphic/inked, crisp low-res art) against the **same** movement/lighting constraints.

Judge in motion, not via single stills: Yuna readability, shadow aesthetics, asset production cost, natural fit with both warm interiors and machine world, zoom/filtering and Web performance.

Do **not** generate a random batch of incompatible images and call it an art direction. Style selection is a recorded decision following an in-engine comparison.
