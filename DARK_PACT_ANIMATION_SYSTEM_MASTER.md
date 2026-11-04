# DARK PACT — ANIMATION SYSTEM 1.0
## Technical specification for Claude Code
Version: 1.0 | Target: Godot 4.3 / Android | Language: Russian

> **Mission:** Repair and extend the *existing* animation system, not rewrite it blindly. First player characters; subsequently NPCs, pets and monsters. Preserve gameplay, Cardinal compatibility, mobile performance and current assets.

## 0. Non-negotiable rules
1. Inspect the actual repository before implementation. Treat all paths, nodes, skeletons, animation names, class and weapon lists in this specification as unknown until discovered.
2. Back up or branch the project before edits; record Godot version, commit/hash and import state. Never delete original animations or overwrite source assets irreversibly.
3. Do not change gameplay balance, damage, cooldowns, movement speeds, skill logic, network protocols or save formats without explicit approval. If integration requires a change, propose a migration and request confirmation.
4. Preserve existing working animation paths and the graphics/performance bot. Use feature flags and rollback options for replacements.
5. All new code must run on the project's real Godot version (currently reported 4.3); verify APIs rather than assuming a newer engine.
6. Work in small independently testable increments. Never claim a feature is tested without an actual test log and device/build evidence.
7. Android-only user workflow: do not make a PC a prerequisite for operating or testing the feature. Blender may be used to prepare assets if available, but runtime cannot depend on Blender.
8. Cardinal integration is diagnostic only: Cardinal may run animation checks and generate reports, not edit animation assets or gameplay automatically.

## 1. Desired outcome
A unified, data-driven animation selection and playback layer for playable characters that supports shared base locomotion, optional male/female variants, weapon-dependent poses/attacks, skill-dependent casts and actions, reliable event timing, smooth transitions and robust fallbacks. Expand the same conventions to NPCs, pets and monsters **after** the player pipeline is proven.

**Existing assets:** some weapon animations already exist and must be audited, fixed and reused when sound. Do not assume that every class or weapon has bespoke animation clips.

## 2. Mandatory repository audit (no coding before this report)
Discover and document:
- Godot engine and renderer settings, mobile target, asset import options and plugin dependencies.
- Scene graph for playable character, AnimationPlayer/AnimationTree, Skeleton3D, bone maps, AnimationLibrary resources, root motion and movement controller.
- All playable races, sex/body variants, classes, equipped weapon categories (including dual wield, shields, unarmed, ranged, staves where present), skill identifiers and skill activation pathways.
- All existing clips: source file, animation name, skeleton, duration, loop, events, root translation, import status, current usage and visible defects.
- How attacks, damage, projectile spawn, VFX, audio, casting, interruption, death, stun, knockback, movement, equipment attachments and network sync currently work.
- Existing avatar customization and equipment attach points; differences in body proportions, bone orientation and handedness.
- Existing admin testing bot and planned Cardinal entry points; current automated tests.
- FPS/frame-time, memory and animation resource usage on target devices where measurable.

Deliver `AUDIT_REPORT.md`, `ANIMATION_INVENTORY.csv`, `RISK_REGISTER.md`, `PROPOSED_ARCHITECTURE.md` and a change plan. Mark every unknown explicitly. Obtain approval before major refactors.

## 3. Functional taxonomy
### 3.1 Base states
Idle, locomotion (walk/run and any existing sprint/strafe/backpedal), start/stop, turn, jump/fall/land if game supports them, combat idle, hit reaction, knockdown/death/revive where present, interaction, equip/unequip. Only implement states that exist in or are required by actual game mechanics; do not fabricate unnecessary gameplay.

### 3.2 Weapon layers
Each actual weapon category should map to an idle/locomotion stance, one or more basic attacks, equip/unequip (where supported), optional blocking, and compatible skill gestures. Support left/right-hand equipment and attachments. Verify grip and blade/arrow orientation, hand intersections, shield position, projectile origin and upper-body motion. Prefer shared clips and selective overrides over full cross-product explosion.

### 3.3 Skills
Build an inventory mapping skill ID -> action archetype (melee swing, thrust, ranged shot, cast, channel, heal, summon, buff, AoE etc. as present) -> animation key -> playback policy -> authoritative gameplay event timing. One animation may serve multiple skills, but VFX and effect timing must be separately configurable when needed. Gameplay effects must not become dependent on client FPS or a missing animation.

### 3.4 Male/female variants
Shared canonical base locomotion. Optional body/sex-specific overrides where proportions, silhouette or style justify them. Fall back to shared clips for any missing variant. Avoid gender stereotypes; focus on rig compatibility and coherent motion. Keep class and weapon selection orthogonal to variant choice.

## 4. Architecture requirements (adapt after audit)
- Prefer a single animation resolver interface that accepts an explicit state/context: actor archetype, skeleton profile, body variant, equipped weapon, current skill, movement/combat state and interruption flags.
- Use data resources/configuration to map states to clip names, animation speed, transitions, priority and event markers; avoid sprawling hardcoded conditionals. Exact resource formats are Claude's decision.
- Fallback chain example: exact skill+weapon+variant -> skill archetype+weapon -> weapon action+variant -> shared action -> safe neutral idle. Report missing coverage in diagnostics.
- Centralize state ownership and interruption priorities (e.g. death > hard crowd control > hit reaction where gameplay allows > skill action > basic attack > locomotion). **Do not impose this illustrative ordering without confirming current mechanics.**
- Support blend transitions, cancellation windows, combo sequences if existing gameplay uses them, movement while casting only where permitted, and independent upper/lower-body blending if compatible with rig and performance.
- Ensure reentrancy: rapid weapon swaps, interrupted casts, repeated attacks, respawns, scene changes and loading cannot leave stale animations or detached weapon models.
- Avoid using animation completion as the only trigger for gameplay resolution. Authoritative combat/skill systems own effects; animation event tracks can trigger visuals/audio and signal action phases without double applying damage.
- If root motion is used, specify how it interacts with CharacterBody3D/nav/physics and networking. No silent change from in-place to root-motion clips.
- All behavior must remain deterministic enough for reproducible tests; do not couple gameplay progression to rendering frames.

## 5. Asset pipeline and retargeting
- Establish canonical rig requirements only after inventory: humanoid bone mapping, neutral pose, orientation, scale, bone naming, hand sockets and transform conventions.
- Audit GLB/GLTF/FBX source and Godot imports; avoid editing generated `.godot/imported` data as the source of truth.
- For each retargeted clip, verify hips/root, feet planting, hand contact, bone twist, proportions, scale and loop seam; flag incompatible rigs rather than forcing destructive retargeting.
- Separate animation assets from character mesh where practical, preserving existing working import pipeline.
- Define naming conventions for clip IDs, skeleton profiles, weapon profiles, skill archetypes and variant tags; use a manifest to record source and license/provenance.
- Mobile optimization: limit unnecessary skeleton updates, blend complexity, simultaneous tracks and memory duplication; profile before optimization.

## 6. Event synchronization contract
For each animation-driven action define:
- action ID and skill/attack ID;
- request/start time, windup, impact or projectile release, recovery, cancel/interruption rules;
- animation visual marker(s) and VFX/SFX marker(s);
- which subsystem is authoritative for damage, healing, mana, cooldown and inventory;
- network implications (if networking is present), and what happens if clip is absent or interrupted.

Required tests: no double hits, no missed hits, no projectile from wrong hand, no VFX after canceled action, no ability to bypass cooldown by animation switching, no speed mismatch due to animation duration changes.

## 7. Incremental delivery plan
**Phase A — Baseline & audit.** Inventory, bug reproduction clips/screenshots where possible, regression baselines, proposed design. No broad rewrites.

**Phase B — One vertical slice.** Choose one representative male/female playable rig pair and one existing weapon family; fix idle -> move -> attack -> skill -> hit -> idle transitions, attachments, event timing and fallback. Preserve original paths behind a flag. Demonstrate on both Android devices where possible.

**Phase C — Player coverage.** Expand across actual weapon categories and skill archetypes discovered. Add shared base clips, selective male/female overrides, missing-animation reporting and tests. Track coverage matrix rather than asserting completeness.

**Phase D — Robustness and optimization.** Rapid equip swaps, cancel windows, performance and memory on mobile, long-play stability, automated smoke/regression tests. Confirm no unintended changes to gameplay numbers.

**Phase E — NPCs.** Apply conventions to humanoid NPCs where compatible; support interaction and locomotion variations.

**Phase F — Pets and monsters.** Separate rig families (quadrupeds, fish, tentacles, undead etc. if present); never assume humanoid retargeting. Use archetype-specific controllers/sets with common diagnostics and event contracts.

**Phase G — Cardinal integration.** Instrument action/state traces, missing clips, invalid transitions, animation event mismatches, weapon grip errors detectable by heuristics, and performance anomalies. Expose test presets in admin panel, with read-only findings and suggestions. Actual visual defects still require manual inspection.

## 8. Acceptance criteria
1. Existing movement, combat, skill effects, save/load and bot behavior remain intact; no unexplained regression.
2. Chosen vertical slice functions for both selected body variants with the selected weapon, one attack and one skill; clip selection and fallbacks are logged.
3. Damage/heal/projectile timings are correct under low FPS, interruptions and rapid inputs; no duplicate gameplay effects.
4. Missing clips do not crash or freeze the actor; neutral fallback and diagnostic entry exist.
5. Weapon attachments remain aligned through idle/move/attack/cast for supported models.
6. All claimed weapon/skill/variant coverage is enumerated in a machine-readable matrix with status `verified`, `implemented_unverified`, `missing`, or `not_applicable`.
7. Test on Samsung Galaxy S24 Ultra and Galaxy Tab S10 FE+ where builds/devices are accessible. Log actual FPS/frame time and memory; do not invent performance targets or results.
8. Feature flag allows rollback; no destructive migration; change log and known issues delivered.

## 9. Deliverables per iteration
- Short progress report: changed files, purpose, before/after behavior, tests executed and evidence, performance, regressions, blockers, next step.
- Updated animation inventory/coverage matrix and risk register.
- Reproducible test scenes or scripts, and clear on-device manual test steps.
- Rollback instructions, with exact toggles or version control references.
- Documentation of assumptions and decisions, including tradeoffs for Android.

## 10. Claude's initial assignment
**Do not implement the entire system immediately.** First audit the project and produce the inventory and architecture proposal. Identify the smallest safe vertical slice. Then implement only that slice after approval, validating movement, combat and skill timings. Do not silently modify balance or create new animations by guessing asset content. If a new animation clip is needed, specify a precise asset brief for the creator, including skeleton, pose, duration, loop behavior and markers.

## 11. Coordination with Cardinal System
Cardinal is implemented first as a narrow benchmark and testing framework. Animation changes must be a separate commit/branch or equivalent rollback unit. Cardinal tests should capture gameplay outcomes and animation telemetry but must not rely on rendering to advance game logic. Compare baseline vs new controller for quest progress, combat events, deaths, ability activation, timing and performance. Avoid running a full simulation rebuild as part of animation changes.