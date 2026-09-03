# SAÑLAQ — Project Context & Development Brief

> **Purpose of this file:** This document is the single source of truth for an AI coding assistant (Claude, Codex, etc.).  
> After reading it, the assistant should understand what SAÑLAQ is, why it exists, how the game works, what has already been implemented, what remains to be done, and what constraints must not be violated.

---

# 1. Project Overview

## Name

**SAÑLAQ (Саңлақ)**

## Concept

SAÑLAQ is a **2D mobile game inspired by the traditional Kazakh children's game “Соқыртеке”**.

The goal is to transform the traditional game into a modern, accessible, visually polished digital experience while preserving its cultural identity.

The game should feel like a **real game first**, not like an educational presentation about Kazakh culture.

Culture is expressed through:

- gameplay rules;
- character clothing;
- environment;
- architecture;
- visual motifs;
- naming;
- atmosphere.

The project should combine:

**Kazakh cultural identity + simple multiplayer/social gameplay + modern mobile game UX + stylized 2D art.**

---

# 2. Core Game Idea

The basic gameplay is inspired by “Соқыртеке”.

There are two types of players:

1. **Соқыртеке**
2. **Ordinary players**

At the beginning of a round, the role is determined randomly.

## Ordinary player

The ordinary player:

- can see the environment;
- can see other players;
- moves around the map;
- tries to avoid Соқыртеке;
- can be caught.

## Соқыртеке

Соқыртеке has the special role of catching another player.

The important gameplay twist is:

> Catching a player is not necessarily the end of the interaction.

After catching someone, Соқыртеке must identify the captured player's clothing.

The captured player's appearance/clothing therefore becomes a meaningful gameplay mechanic rather than purely cosmetic decoration.

---

# 3. Gameplay Loop

The intended basic loop:

```text
Start game
    ↓
Assign roles
    ↓
Players spawn
    ↓
Round begins
    ↓
Ordinary players move and avoid Соқыртеке
    ↓
Соқыртеке searches for players
    ↓
Соқыртеке catches a player
    ↓
Identification / clothing guessing phase
    ↓
Result
    ↓
Round continues or roles change
```

The exact scoring, win conditions, round duration, and progression system can be refined later.

Do NOT invent complex systems unless they are required by the current task.

---

# 4. Product Vision

SAÑLAQ should eventually become a polished mobile game with:

- simple controls;
- short, replayable rounds;
- memorable characters;
- recognizable Kazakh visual identity;
- readable gameplay;
- attractive maps;
- multiple clothing combinations;
- clear role feedback;
- satisfying catch/guess interactions;
- mobile-friendly UI.

The priority is **quality and coherence**, not feature quantity.

---

# 5. Target Platform

Primary target:

**Mobile**

The game is designed around a mobile screen and touch interaction.

The visual layout should therefore account for:

- portrait/landscape decision made by the project;
- safe areas;
- readable UI;
- touch-friendly controls;
- limited screen space;
- performance on mobile hardware.

Do not introduce desktop-first UI patterns unless necessary.

---

# 6. Technology

## Engine

**Godot**

The project is being developed in Godot.

## Programming / Architecture

The existing project uses Godot's scene/node architecture and GDScript.

Important principle:

> Preserve the existing architecture unless there is a clear technical reason to change it.

Do not rewrite functioning systems just because another architecture may look cleaner.

---

# 7. Current Project Architecture

The project already has a functioning gameplay foundation.

The player is represented by a `CharacterBody2D`.

Important existing concepts include:

- player movement;
- collision;
- catch area;
- player roles;
- bots / other players;
- character visual system.

The player currently has:

- approximately **12 px movement collision**;
- approximately **28 px catch area**.

The project also uses a separate character visual structure.

---

# 8. Character Visual Architecture

The player gameplay object and visual appearance are intentionally separated.

Existing concept:

```text
Player
├── Movement / gameplay
├── Collision
├── Catch area
└── CharacterVisual
    ├── Body
    ├── UpperClothing
    ├── LowerClothing
    ├── Headwear
    ├── Footwear
    └── Other visual layers
```

The exact node names and implementation in the repository are authoritative.

When modifying the project:

1. inspect the actual scene tree;
2. inspect existing scripts;
3. understand current signals and references;
4. preserve working connections;
5. avoid creating duplicate systems.

---

# 9. Character Design

## Main Character

The visual identity is based on a **young Kazakh boy**, roughly in the **10–15 age range**.

The character should be:

- friendly;
- expressive;
- stylized;
- culturally recognizable;
- suitable for a family-friendly game;
- visually readable at small mobile sizes.

Avoid photorealism.

Avoid overly detailed anatomy.

Avoid generic fantasy clothing.

---

# 10. Clothing System

Clothing is an important part of SAÑLAQ.

It is not only cosmetic.

Because Соқыртеке has to identify the captured player based on clothing, clothing contributes directly to gameplay.

Planned clothing categories include:

- **Upper clothing**
- **Lower clothing**
- **Headwear**
- **Footwear**

The project has been planned around multiple variants, approximately:

- 5 upper clothing variants;
- 5 lower clothing variants;
- 5 headwear variants;
- 5 footwear variants.

These numbers are a design target, not a reason to block development.

The clothing should be inspired by historically and culturally appropriate Kazakh clothing.

Do not create random “Central Asian-looking” clothing.

---

# 11. Visual Direction

## Overall Style

The desired visual style is:

**soft stylized 2D cartoon**

Characteristics:

- clean silhouettes;
- simple readable shapes;
- soft forms;
- friendly proportions;
- controlled details;
- polished mobile-game appearance;
- no unnecessary realism.

## Explicitly Avoid

- photorealism;
- realistic textures;
- pixel art;
- excessive gradients;
- noisy backgrounds;
- visual clutter;
- generic AI-art appearance;
- excessive decorative details;
- neon aesthetics.

---

# 12. Color Direction

The core visual identity uses:

- **deep navy blue**
- **sand / warm yellow**

Supporting colors may be used where necessary.

The palette should feel:

- warm;
- modern;
- culturally compatible;
- calm;
- playful.

Do not randomly introduce neon colors.

Do not redesign the entire palette without a strong reason.

---

# 13. Cultural Direction

SAÑLAQ must have authentic Kazakh cultural references.

Important visual areas:

- traditional clothing;
- Kazakh ornamentation;
- environment;
- yurts;
- natural landscape;
- traditional objects;
- naming.

However:

> Cultural authenticity must be combined with modern game design.

Do not make the game look like a museum exhibit.

Do not overload every object with ornaments.

Use cultural elements intentionally.

---

# 14. Main Map

A major current development area is the **main gameplay map**.

The map should be a stylized 2D environment designed specifically for gameplay.

Planned environmental elements include:

- stones;
- logs;
- bushes;
- grass / natural ground;
- water;
- yurt;
- other environmental props.

The map should provide:

- enough open space for movement;
- readable paths;
- obstacles;
- hiding / movement opportunities;
- clear player visibility;
- visual landmarks.

---

# 15. Map Design Principles

The map is not just a background.

Every major element should be evaluated for gameplay.

For each object ask:

1. Does it affect movement?
2. Does it provide a landmark?
3. Does it improve readability?
4. Does it fit the cultural setting?
5. Does it create unnecessary collision problems?

Avoid putting decorative objects everywhere.

Gameplay readability has priority over decoration.

---

# 16. Asset Production

Assets are being created/generated separately and then integrated into Godot.

Important assets include:

### Characters
- body;
- upper clothing;
- lower clothing;
- headwear;
- footwear.

### Environment
- rocks;
- logs;
- bushes;
- grass;
- water;
- yurt;
- other map decorations.

Assets should be created so that they can be integrated cleanly into the existing Godot project.

---

# 17. Camera / Screen Constraints

The game is designed for mobile screens.

The map and assets should account for:

- camera bounds;
- player visibility;
- mobile screen dimensions;
- scaling;
- object readability.

Do not create an enormous detailed world if the camera only shows a small gameplay area.

The visible gameplay area should be deliberately composed.

---

# 18. Current Development Status

## Phase 1 — Foundation

**Status: completed / substantially completed**

The project has:

- Godot project foundation;
- basic gameplay architecture;
- player object;
- movement;
- role-related logic;
- catch-related logic;
- bots / other player concepts;
- initial character integration.

---

## Phase 2 — Character Integration

**Status: completed**

The SAÑLAQ boy was integrated as the default static player visual without changing the existing gameplay mechanics.

The existing player remains a gameplay object and the character visual is handled separately.

The principle was:

> Change the appearance, not the functioning gameplay system.

---

## Phase 3 — Environment / Main Map

**Status: current / in progress**

The next major focus is the main gameplay map and its visual assets.

This includes:

- map composition;
- terrain;
- obstacles;
- rocks;
- logs;
- bushes;
- water;
- yurt;
- environmental decoration;
- collision where needed;
- camera framing.

The map must fit the established SAÑLAQ visual language.

---

# 19. What Is Already Working

The AI assistant should assume that the following systems may already exist and must be inspected before changing them:

- player movement;
- player `CharacterBody2D`;
- collision;
- catch area;
- role assignment;
- catch mechanics;
- bots;
- character visual instantiation;
- basic gameplay flow.

**Do not recreate these systems blindly.**

First inspect the repository.

---

# 20. What We Want to Build Next

The immediate goal is to move from a technically functioning prototype toward a visually coherent playable MVP.

Priority order:

### P0 — Must work

- Main map
- Player visual
- Player movement
- Catch interaction
- Roles
- Basic round flow
- Mobile-friendly camera
- Basic UI

### P1 — Important

- Clothing variants
- Clothing identification / guessing UI
- Better character animations
- Better environmental assets
- Improved map readability
- Sound effects
- Basic feedback animations

### P2 — Later

- Progression
- More maps
- More character customization
- Advanced scoring
- Online multiplayer
- Accounts
- Cosmetics
- Achievements
- Leaderboards

Do not jump to P2 while P0 is unfinished.

---

# 21. MVP Definition

The MVP should allow a player to:

1. launch the game;
2. enter a playable scene;
3. control a character;
4. see the SAÑLAQ environment;
5. have a role assigned;
6. interact with other players/bots;
7. catch a player;
8. enter the clothing identification interaction;
9. receive a result;
10. finish/restart a round.

The MVP does NOT need every planned feature.

---

# 22. UI Direction

UI should be:

- minimal;
- clean;
- readable;
- mobile-friendly;
- consistent with the navy/sand identity.

Avoid:

- excessive panels;
- complicated HUD;
- tiny text;
- unnecessary buttons;
- generic template UI.

UI should communicate gameplay state immediately.

Examples of information that may need to be visible:

- current role;
- round state;
- catch status;
- timer, if implemented;
- identification prompt;
- result.

---

# 23. Animation Direction

Animations should be simple and readable.

Potential animations:

- idle;
- running;
- catching;
- caught;
- role transition;
- clothing selection;
- success/failure feedback.

The game does not require AAA-level animation.

A few polished, readable animations are better than many unfinished ones.

---

# 24. Sound Direction

Sound is planned but is not the highest priority during the current environment phase.

Potential sounds:

- footsteps;
- movement;
- catch;
- role assignment;
- UI click;
- successful identification;
- incorrect identification;
- round start/end.

Audio should support the atmosphere without becoming distracting.

---

# 25. Code Quality Rules

When working on the repository:

### Always

- inspect existing files before editing;
- understand dependencies;
- preserve existing gameplay;
- make the smallest safe change;
- keep naming consistent;
- reuse existing systems;
- test the scene after changes.

### Avoid

- rewriting entire scripts;
- duplicating functionality;
- introducing unnecessary dependencies;
- changing node names without checking references;
- changing gameplay while doing visual work;
- adding systems that are not currently needed.

---

# 26. Asset Integration Rules

When adding a new asset:

1. determine its intended scale;
2. determine its pivot/origin;
3. determine whether it needs collision;
4. determine whether it is decorative or gameplay-relevant;
5. place it in the appropriate asset directory;
6. connect it to the correct Godot scene;
7. test it in-game.

Do not merely place PNG files into the project and assume the task is finished.

---

# 27. Important AI Assistant Behavior

This section is critical.

When Claude/Codex works on SAÑLAQ, it should behave like a **senior Godot game developer + technical artist**, not like a generic code generator.

Before making changes:

```text
1. Inspect repository.
2. Understand current architecture.
3. Identify what already works.
4. Identify the smallest required change.
5. Implement.
6. Test / validate.
7. Report exactly what changed.
```

Do not assume that the project is empty.

Do not replace existing systems without evidence.

---

# 28. Visual Quality Standard

Every visual asset should answer:

### Does it look like SAÑLAQ?

If the answer is no, reject or revise it.

The visual identity should remain consistent across:

- characters;
- map;
- props;
- UI;
- icons;
- menus;
- effects.

The project should feel like **one game made by one art team**.

---

# 29. AI-Generated Art Rules

AI-generated assets are acceptable as part of production.

However, generated assets must be cleaned and adapted for the game.

Common problems to avoid:

- inconsistent perspective;
- inconsistent outlines;
- different art styles;
- unnecessary shadows;
- random ornaments;
- incorrect anatomy;
- overly realistic textures;
- inconsistent proportions;
- backgrounds baked into assets that should be transparent.

The final asset should match the established game style, not simply be copied from an AI generation.

---

# 30. Current Priority

### RIGHT NOW

The highest priority is:

> **Build the main SAÑLAQ gameplay map in the established stylized 2D visual style and integrate it into the existing Godot project without breaking gameplay.**

This means:

```text
Map
 ↓
Environment assets
 ↓
Collision
 ↓
Camera
 ↓
Player placement
 ↓
Gameplay test
 ↓
Visual polish
```

---

# 31. Definition of “Done” for the Current Phase

The current environment phase is considered complete when:

- the main map exists in Godot;
- the map fits the mobile camera;
- player movement works correctly on it;
- obstacles are correctly placed;
- gameplay remains readable;
- environmental assets use one coherent art style;
- the yurt/water/natural elements fit the composition;
- collisions work where necessary;
- no existing gameplay systems are broken.

---

# 32. Known Project Philosophy

SAÑLAQ should follow three principles:

## 1. Gameplay first

The game must actually be fun and understandable.

## 2. Culture with purpose

Kazakh culture should be integrated naturally, not used only as decoration.

## 3. Modern presentation

The final product should look like a modern indie/mobile game, not an old educational game.

---

# 33. Long-Term Vision

If the MVP succeeds, SAÑLAQ can expand into a broader platform of culturally inspired games.

Possible future directions:

- additional Kazakh traditional games;
- multiple maps;
- additional characters;
- customization;
- seasonal content;
- local multiplayer;
- online multiplayer;
- progression;
- achievements;
- educational/cultural information as optional content.

But these are **future possibilities**, not current requirements.

---

# 34. Current State Summary

```text
PROJECT: SAÑLAQ
TYPE: 2D Mobile Game
ENGINE: Godot
GENRE: Social / Chase / Party-style gameplay
CULTURAL BASIS: Kazakh traditional game “Соқыртеке”

CORE GAMEPLAY:
Role assignment
→ Movement
→ Chase
→ Catch
→ Clothing identification
→ Result
→ Continue round

TECHNICAL FOUNDATION:
██████████  Mostly complete

CHARACTER INTEGRATION:
██████████  Complete

MAIN MAP:
██████░░░░  In progress

ENVIRONMENT ASSETS:
██████░░░░  In progress

CLOTHING VARIANTS:
████░░░░░░  Planned / partially implemented

UI POLISH:
███░░░░░░░  Later

AUDIO:
██░░░░░░░░  Later

ADVANCED FEATURES:
░░░░░░░░░░  Future
```

---

# 35. Golden Rule for Future Development

**Never break working gameplay to make visual changes.**

If the task is visual:

> modify the visual layer.

If the task is gameplay:

> modify the gameplay layer.

If the task requires both:

> clearly separate the changes.

The architecture should remain understandable and maintainable.

---

# 36. First Action for Any New AI Coding Session

When this file is provided to Claude/Codex, the first response/action should NOT immediately modify code.

Instead:

1. inspect the repository;
2. locate the Godot project;
3. inspect `project.godot`;
4. inspect the main gameplay scene;
5. inspect the `Player` implementation;
6. inspect `CharacterVisual`;
7. inspect current asset directories;
8. determine the exact current state;
9. compare it with this document;
10. only then begin implementation.

If the repository differs from this document, **the actual repository is the source of truth for implementation details**, while this file is the source of truth for product vision and requirements.

---

# 37. Final Context

SAÑLAQ is not being built as a generic prototype.

It is intended to become a **polished, culturally grounded Kazakh mobile game**.

The project already has a functional technical foundation.

The current challenge is to transform that foundation into a coherent visual and gameplay experience.

The immediate mission is:

> **Finish the main playable environment, integrate it safely into Godot, preserve existing mechanics, and move the project toward a polished MVP.**

