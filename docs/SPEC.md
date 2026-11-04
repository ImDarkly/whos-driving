# Current spec: Milestone 1 — Wheel-controlled online parking

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
