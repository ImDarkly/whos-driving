# Current spec: Crash-test dummy asset

## Approved scope — 2026-11-04

Oleksandr supplied the v1.1 crash-test dummy visual reference and requested implementation after confirming the actual cabin is on synced main. Build an original low-poly character following the pictured silhouette: oversized faceted head, simple eyes, yellow shells, charcoal joints and fixed crash-test badges. Deliver editable Blender source, a rigged GLB, yellow/red/blue/green body materials and standing, seated, steering-example and head-turn previews. Fit-study copies use the actual merged car and all four existing seat anchors.

Use rigid bone weights and separate moving pieces; the approximate mesh count is guidance, not a fixed requirement. Target 800–1,500 triangles. Preserve eye/badge colors when repainting the shell; a fourth fixed safety-yellow material is allowed to keep badges yellow on other body colors. Pose clips are static inspection poses, not adopted gameplay animations. Exact character scale and proportions may be adjusted to the cabin while retaining the reference silhouette.

No playable integration, changes to cameras, controls, physics, networking, car geometry or seat anchors; no walking, gaze replication or gameplay steering animation. Visual approval and human cabin visibility remain Oleksandr's decision. Validate actual GLB import, skinning and pose retention in Godot, inspect Blender renders and record limitations in KNOWLEDGE.md.

Follow-up authorization: Oleksandr requested running a game demo with the dummies. `tests/dummy_demo.gd` may replace heads in its own offline playable instance, retain labels/local-avatar hiding, apply the measured seated fit and expose existing F3 practice controls. Normal F5 gameplay remains unchanged; this does not adopt permanent character integration or change cameras/handling.

---

# Previous spec: Retro car visual replacement

## Approved scope — 2026-11-04

Oleksandr selected Bricchi Games' free Retro Car With Interior and requested this spec followed by implementation in a new chat, on a new branch from synced main. This authorizes the bounded visual replacement below; it does not adopt the underlying first-person experiment or approve handling changes.

### Intended feel

Make the shared car feel like a recognizable, enclosed old car with a readable dashboard, seats and windows, while keeping friends and approaching parking mistakes visible from all four seats. The chosen asset establishes a retro, low-poly textured car style. Whether its enclosed cabin improves the experience remains a playtest question.

### Scope

- Obtain the free asset from [Bricchi Games](https://bricchi-games.itch.io/retro-car-with-interior), without payment or account sign-in. Inspect the actual archive and license before incorporating files. The listing permits commercial use with attribution, describes a detailed interior, four doors, separate wheels and steering wheel, and provides FBX/Blend files. These are listing claims, not verified import results.
- Replace the primitive car body, cabin and wheel meshes with this one vehicle. Keep the existing authoritative physics body, collision footprint, wheel force positions, tuning and parking rules. Fit the visual model to that contract using local transforms or small mesh adjustments; do not resize gameplay collision, move barriers or retune forces to fit the asset. Check visible wheel alignment and body bounds against the existing footprint.
- Repair material/texture references, normals, glass transparency and import settings as needed for Godot 4.6.2 Compatibility. Use supplied textures and emissive headlights; no new postprocessing, PSX shader, camera wobble or lighting overhaul. Select one supplied body color; no vehicle/color selection UI. Comment reports about broken diffuse/emissive references are a lead to inspect, not a confirmed defect in our copy.
- Place four editable camera/passenger seat anchors inside the actual cabin, retaining front-left/front-right/rear-left/rear-right assignment and the current local free-look behavior. Adjust anchor positions to fit the model; retain FOV, sensitivity and look limits. Preserve labelled colored heads, hide the local head, leave unused seats empty, and verify friends are not embedded in seats or the roof.
- Keep the interior, doors and roof visible in normal play. Routine material or small geometry fixes may remove accidental occlusion/clipping; do not silently remove the roof, introduce a cutaway camera or materially redesign visibility. If the model cannot support four usable seated views within this scope, report the concrete blocker and recommend the smallest decision needed.
- Retain existing wheel command feedback and HUD readability. Wheels remain fixed in steering orientation; any retained wheel spin follows existing behavior. The decorative steering wheel, doors, hood and trunk remain static. Their separate pivots do not authorize new controls or animations.
- Preserve authorship and the exact supplied license. Add an asset provenance/attribution file with source URL, author, license/version as actually established, and modifications. Include an accessible in-game credit to Bricchi Games in the existing room/help UI without covering the windshield. Oleksandr approved proceeding on the creator's stated commercial-use-with-attribution terms on 2026-11-04 despite the absent exact variant. Preserve the listing wording verbatim; do not claim a precise Creative Commons variant such as CC BY 4.0. This decision supersedes the earlier exact-variant prerequisite. Never commit private configuration or downloaded archives/cache.

### Technical freedom and non-goals

Use a small reusable visual scene and the existing gameplay structure. Prefer an engine-ready FBX or a locally converted glTF/GLB; keep only needed distributable assets and attribution. Existing installed tooling may be used, but no software installation, global settings changes, sign-in or paid assets. Ask only if missing software/access or unresolved license terms actually block this scope.

This revision supersedes the earlier primitive-only/no-external-art restriction for this specific car. No environment overhaul, characters beyond current heads, walking, opening doors, mirrors rendering, dashboard simulation, audio, new controls, physics/networking redesign, difficulty changes or additional vehicles. Existing gameplay and first-person contracts below remain in force otherwise.

### Acceptance and playable checkpoint

1. Import and launch the actual playable with no missing dependencies or textures. Inspect native rendered captures from every seat facing forward, toward a friend and behind. Check dashboard/door/roof surfaces, window visibility, local-head hiding, occupied/empty seats, clipping, and room/F3/success UI. Headless checks alone cannot establish visual quality.
2. Execute the existing gameplay, cabin, command-only parking and multi-process localhost networking checks appropriate to the change. Keep meaningful behavioral assertions; adapt geometry-specific expectations only where this visual replacement supersedes them. Verify unchanged collision/handling and parking feasibility, seat identity, remapping and repeated reset. Distinguish scripted feasibility from human difficulty and localhost results from EOS/Internet evidence.
3. Confirm asset import and attribution work without external absolute file paths. Verify the in-game credit and preserve the actual license. Record exact commands/results, modifications, import limitations and outstanding manual checks in KNOWLEDGE.md; do not report prior checks as newly executed.
4. Leave a playable checkpoint with the shortest playtest: inspect all seats, look at friends and through each window, coordinate an approach/contact, reset and park. Oleksandr judges visibility, appearance and whether the change ships. Do not claim fun or adequate human visibility from scripts.

### Implementation handoff

Reuse this checkout in the requested new local chat; no worktree. Read AGENTS.md, GAME.md, SPEC.md and KNOWLEDGE.md first. Fetch origin, safely fast-forward local main to origin/main, then create a fresh `codex/retro-car-visuals` branch from that synced main. Carry only this documentation revision into it, not the previous feature branch's implementation commits. Preserve unrelated local work; no reset-hard, forced branch switch, push or merge. If synced main lacks the first-person shared-car foundation, do not silently build on the old feature branch or merge it: report that dependency and request Oleksandr's decision. A verified local commit is allowed. No global configuration, installation, account sign-in or orchestration changes.

---

# Retained contract: First-person shared-car experiment

## Approved revision — 2026-11-04

Oleksandr identified the current view and car as a poor fit for friendslop and clarified that the game should generate moments and emotions. He approved the proposed bounded experiment: a first-person seated view with free look, simple visible friends, unchanged wheel controls, one tight parking situation beside a harmless drop or barrier, and immediate reset. He then requested that this spec be written first and implemented in a separate session on a branch from synced main. Approval authorizes building the experiment; adoption still requires a group playtest.

### Intended feel and hypothesis

Friends should feel together inside one badly coordinated car. An approaching mistake should be visible long enough to provoke a warning, conflicting inputs, blame, panic or relief. Hypothesis: being inside the car with limited visibility makes shared wheel control emotionally engaging. Risk: players feel blind and powerless instead. Neither outcome is established by automated checks.

### Scope

- Replace the outside follow camera with a perspective camera seated inside the shared car. Each participant gets a stable seat derived from the existing player order. Use front-left, front-right, rear-left and rear-right for players 1–4; seat assignment does not change wheel ownership, including trio's linked rear wheels.
- Mouse free look is local to each participant and turns the view only. Keep the eye inside the cabin, limit vertical look to avoid flipping, and allow looking sideways and behind. Do not add camera shake, forced view changes or steering tied to looking. Choose sensible initial framing, field of view and mouse sensitivity within this scope.
- Make mouse capture explicit: click to look, Escape releases the pointer for room/debug UI, and focus loss releases it. Starting the game must leave Host/Join accessible. Preserve safe held-key behavior through focus changes and reset. Reset restores a forward-facing view.
- Replace the solid cabin block with a primitive interior that supports looking out: readable front/back, floor/dashboard, seats and a lightweight frame. Preserve the collision footprint, wheel positions, forces and all handling values. Interior pieces are visual; avoid blocking the view with the existing opaque roof/cabin.
- Represent other connected participants with simple colored heads and clear player identifiers at their seats. Hide the local head from its own camera; unused seats are empty. Heads may remain static: networked gaze, expressions, bodies and avatar customization are unnecessary for this experiment. Seat presence updates after joins, departures and local debug remapping.
- Build one parking setup beside a solid harmless barrier, choosing the barrier option rather than adding falling physics. Use a short side wall and end barrier around the existing bay, leave a clear entrance and enough clearance for the unchanged vehicle footprint, and use visible markings so an approaching collision is readable from the cabin. Collision stops/deflects the car using existing physics; no damage, penalty, failure timer or new failure state. Keep the rest of the flat lot and the existing spawn/bay location unless an actual feasibility check establishes a blocker.
- Retain a readable view of local bindings, owned wheels, authoritative wheel commands, parking hold/success and reset. Compact or reposition the current HUD so it does not cover the main windshield view. Room controls and F3 diagnostics remain accessible with the pointer released. Do not add a minimap or outside-camera switch that bypasses the experiment.
- Preserve immediate shared R reset, parking containment/rest/hold rules, ownership for 1–4 players, host authority, client interpolation, room-code flow and existing authentication/recovery behavior.

### Technical freedom and non-goals

Use primitive Godot geometry and the smallest scene/script changes needed. No external assets or software installation. Derive seat presence from the existing authoritative player list; do not add a separate passenger protocol for static placeholders. The camera and mouse look are presentation only and must not apply forces or modify heading. Keep barrier placement editable and outside the parking containment volume.

No walking/exiting, real character controllers, animated/networked gaze, voice, damage, falling, extra courses, scoring, new driving inputs, handling retuning, cutscenes or production art. This revision supersedes the earlier outside-camera/no-passengers/no-obstacles restrictions only to the extent explicitly scoped above. The retained wheel-drive contract follows below.

### Checkpoint and acceptance

Implementation is available on `codex/first-person-shared-car`; executed validation and remaining manual/online checks are in KNOWLEDGE.md. This remains an experiment awaiting Oleksandr's group-playtest decision.

1. Import and launch the actual scene. Inspect native rendered captures from all four seats, forward and looking toward a friend/rear, with room/debug UI and success feedback. Verify the eye is inside the cabin, the local head is hidden, other occupied seats are visible, and important UI and outside cues are legible.
2. Exercise mouse look, capture/release, focus loss, reset and seat remapping. Confirm look does not alter the car or another peer's camera. Confirm all counts have unique occupied seats and no phantom passengers after departure. Use bounded meaningful checks for these behaviors and report any manual-only checks explicitly.
3. Run the existing gameplay and multi-process networking checks appropriate to the changes. Demonstrate an owned-command-only driven approach that can enter and park in the new barrier setup; do not use teleport/success fixtures as evidence of driving feasibility. Adjust a test route if needed, without changing handling or weakening real parking rules. Verify actual barrier collision and reset while touching it. Automated feasibility does not establish human difficulty or fun.
4. Exercise separate peers for seat identity, shared car motion, join/departure/remapping and repeated reset. Use existing local test tooling; distinguish localhost protocol evidence from real EOS/Internet evidence. Do not sign into accounts, change portal permissions or silently replace production networking. Record exact executed checks, failures and remaining limits in KNOWLEDGE.md.
5. Leave a playable checkpoint and the shortest group-playtest instructions. Ask players to coordinate an approach, experience a near miss/contact, recover or reset, and try again. Collect observations about warnings, visible reactions, blame/laughter, frustration, visibility and voluntary retries. Oleksandr decides retain/revise/discard after playtesting; do not report emotions or fun as verified by scripts.

### Implementation handoff

In the separate implementation chat, fetch origin, safely fast-forward local main to origin/main, and create a new `codex/` working branch from that synced main. Carry only this documentation revision into it; do not base implementation on the previous feature branch. Preserve unrelated local changes and stop only if they prevent a safe switch. Reuse this checkout; no worktree, global settings changes, installation, push or merge. A verified local commit is allowed. Read AGENTS.md, GAME.md, this spec and KNOWLEDGE.md before implementation, then update only durable facts that actually change.

---

# Retained contract: Milestone 1 — Wheel-controlled online parking

## Decision and approval status

Design revision in chat on 2026-11-04. Oleksandr selected independent wheel drive/reverse, no steering and no brake control, with support for 1–4 total players. His subsequent implementation request approved the ownership and handling contract below. This replaces shared WASD and the previous steering/braking model. The revised playable is implemented; execution evidence and outstanding checks are in KNOWLEDGE.md. Approval to build is separate from adopting the experiment after playtesting.

After the local demo, Oleksandr authorized committing and publishing this revision for PR review. Merging remains his decision; the remaining player-count and online playtests still apply.

Question: can friends coordinating individual wheel forces make parking awkward, understandable and engaging enough to voluntarily retry? Extra difficulty is intended; enjoyment remains a hypothesis until playtested and explicitly adopted.

Original brief: [Milestone 1 — Temporary Wheel Controls](https://app.notion.com/p/40e351013fca81f38c95fea08baa1c96), read in the previous session on 2026-11-04. This revision follows current chat decisions; the source page has not been reread for this revision. Fresh-project direction is in GAME.md; existing implementation evidence is in KNOWLEDGE.md.

## Selected direction

- One shared car with four fixed, non-steering wheels: front-left, front-right, rear-left and rear-right.
- Each wheel has one owner and accepts forward drive, reverse drive or neutral. Players cannot command steering or a separate brake.
- Turning results from unequal forces at wheel positions. Opposite drive directions on opposite sides can create a turning moment; there is no direct player yaw command.
- Support solo, duo, trio and four-player sessions from the first revised playable. Multiplayer remains the priority.
- One flat lot, primitive car, marked bay and readable follow camera. No obstacles initially, passengers, character controllers or optional asset dependency.

## Approved ownership and inputs

Assign in stable player order; all four wheels remain owned:

| Players | Player 1 | Player 2 | Player 3 | Player 4 |
| --- | --- | --- | --- | --- |
| 1 | All wheels, separate left/right controls | — | — | — |
| 2 | Both left wheels | Both right wheels | — | — |
| 3 | Front-left | Front-right | Both rear wheels | — |
| 4 | Front-left | Front-right | Rear-left | Rear-right |

Grouped wheels receive the same command. This makes solo manageable, duo coordination about the two sides, trio asymmetric, and four-player coordination about individual corners. Every wheel is still simulated individually. No role rotation in this milestone.

Keyboard bindings (physical key positions):

| Session | Forward / reverse |
| --- | --- |
| Solo, left wheels | W / S |
| Solo, right wheels | Up / Down arrows |
| Multiplayer, all wheels assigned to you | W / S |
| Any player | R resets; F3 shows connection state and local channel tests |

The arrow pair has no effect in multiplayer. A/D and Space have no driving action. The persistent two-by-two wheel diagram labels front/rear, owner, local ownership and authoritative command. Green/up means forward, red/down reverse, neutral is explicitly labelled.

- Holding forward/reverse applies force in that direction at the owned wheel(s). Reverse against forward motion first opposes that motion; it does not instantly reverse velocity. Forward acts similarly against reverse motion.
- Release means neutral/coasting with passive rolling resistance, without automatic active braking. Both directions held together produce neutral.
- Show a wheel diagram with owners, local controls and each wheel's current command. Ownership must be understandable without a debug panel.
- Player-count changes safely reset the attempt and mapping. Local independent channel injection permits ownership checks without four logins.

## Approved handling contract

Use a stable arcade approximation with built-in 3D collision and fixed steps. Forces at wheel positions must affect translation and rotation. The previous bicycle-steering implementation cannot establish this behavior.

Fixed wheels resist sideways movement, so lateral grip must permit enough slip for differential drive to turn the car on the lot. Realistic tire simulation is unnecessary. Tune for visible cause and effect: equal forward inputs move roughly straight; one side driving harder produces a turn; opposing sides can turn tightly. Exact turn radius, spin behavior and difficulty remain playtest questions.

Keep one editable tuning resource for wheel positions, drive force, passive resistance, lateral grip, speed limits and parking thresholds. Physics implementation is technical freedom within this contract. Do not silently add steering assistance, active braking or automatic alignment. No precise force/grip values are approved here.

## Retained scope

- Instant reset to the start, zero velocity, cleared inputs/success/timers, without restarting the room. Held controls must be released before acting again. Any player may request reset.
- Parking requires full oriented vehicle containment in the bay, low linear/angular speed and a short hold, with explained editable thresholds. Shared success feedback once per attempt. Coast to rest or counter-drive; there is no brake button.
- Existing EOSG login and room-code host/join flow; no Chum code. Defer voice.
- Preserve player Device-ID login and the opt-in development-only EOS Dev Auth Tool path for distinct named accounts on one PC. No portal permission changes.
- Host owns car simulation, parking and reset. Clients submit only owned wheel commands using sequenced/time-stamped inputs at a bounded rate. Host uses newest valid input each physics tick, enforces ownership, and neutralizes stale/disconnected inputs.
- Replicate car transform, linear/angular velocity, wheel drive visuals and parking state. Interpolate remote visuals. Add prediction/reconciliation only if measured latency requires it.
- Join-in-progress gets mapping and a car snapshot. Host departure clearly ends the room; no host migration. Shared success/reset and attempt IDs prevent repeat events and stale inputs.
- Inspect player count, wheel ownership, connection state, authority, commands and latency where available.

## Technical freedom and non-goals

Choose the smallest stable physics and session structure within scope. Verify EOSG APIs against the installed addon; never invent calls. Report integration blockers and the smallest fallback; do not silently change networking technology or control model.

No steering controls, separate brake controls, scoring, damage, replays, progression, role rotation, multiple vehicles/control schemes, elaborate menus, cosmetics, voice or new modes. No final adoption of the experiment before playtesting.

## Build checkpoints

1. Local handling: visible wheel ownership and commands; forward/reverse/coast, force-driven turning, parking and reset. Verify ownership and safe remapping for all four player counts. Demonstrate turning without steer input or directly setting heading from input.
2. Online playable: EOSG room-code host/join with up to four total players; one host simulation; shared motion/success and repeated reset; safe disconnect and inspectable connection/latency. Preserve session recovery behavior.

Validate separate peers/exported or multi-instance builds, not only one editor. Record exact commands, environment, failures and limits. Revise shared-WASD tests where their behavior is superseded; previous passes do not validate wheel handling. Automated checks establish behavior, not fun.

Playtest solo/duo/trio/four-player counts. Observe whether players understand their wheels, can deliberately turn and stop, can park, and voluntarily retry. Record responsiveness, confusion and laughs as observations. Explicitly decide retain/revise/discard afterward; one session does not prove fun for every count.
