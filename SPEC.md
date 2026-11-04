# Current spec: Milestone 1 — Online parking prototype

## Approval and purpose

Oleksandr approved the first-playable scope and control details in chat on 2026-11-04. Gameplay implementation is authorized. This supersedes the setup-only gate and the older individual-wheel experiment.

Question: can friends sharing directional controls of one car make parking engaging enough to voluntarily retry? This remains a hypothesis until playtested and explicitly adopted.

Original brief: [Milestone 1 — Temporary Wheel Controls](https://app.notion.com/p/40e351013fca81f38c95fea08baa1c96), read 2026-11-04. Current chat decisions take precedence. Fresh-project direction is in GAME.md.

## Approved scope

- One flat lot, primitive car, marked bay and readable follow camera. No obstacles initially, passengers or character controllers. No optional asset dependency.
- 1–4 total players including host share W/A/S/D. Each action has exactly one owner. No Space or separate brake button. W drives forward; S slows forward motion, then reverses; A/D steer. Opposing drive inputs cancel; opposing steering inputs cancel. W similarly slows reverse motion before driving forward.
- Deterministic assignment in player order: 1 gets WASD; 2 get W/S and A/D; 3 get W, S and A/D; 4 get W, A, S and D. Show mapping and each player's owned controls. No independent wheel commands.
- Player-count changes safely reset the attempt and mapping. Local independent channel injection permits ownership checks without four logins.
- Stable arcade approximation with built-in 3D collision and fixed steps; no realistic tire model. One editable tuning resource documents forward axis, steering signs, acceleration/braking, speed limits, coast drag, steering limits and parking thresholds. Physical wheel forces/torque and center of mass are unnecessary for a kinematic implementation.
- Instant reset to the start, zero velocity, cleared inputs/success/timers, without restarting the room. Held controls must be released before acting again. Any player may request reset.
- Parking requires full oriented vehicle containment in the bay, low linear/angular speed and a short hold, with explained editable thresholds. Shared success feedback once per attempt.
- New EOSG login and room-code host/join flow; no Chum code. Defer voice.
- Development-only addition approved in chat: opt-in EOS Dev Auth Tool with distinct named accounts for same-PC testing. Preserve player Device-ID login; fresh implementation using Chum's documented testing approach only. No portal permission changes as part of this work.
- Host owns car simulation, parking and reset. Clients submit only their owned actions using sequenced/time-stamped inputs at a bounded rate. Host uses newest valid input each physics tick, enforces ownership, and neutralizes stale/disconnected inputs.
- Replicate car transform, linear/angular velocity, steering visuals and parking state. Interpolate remote visuals. Add prediction/reconciliation only if measured latency requires it.
- Join-in-progress gets mapping and a car snapshot. Host departure clearly ends the room; no host migration. Shared success/reset and attempt IDs prevent repeat events and stale inputs.
- Inspect player count, mapping, connection state, authority, inputs and latency where available.

## Technical freedom and non-goals

Choose the smallest stable physics and session structure within scope. Controls and tuning remain replaceable. Verify EOSG APIs against the installed addon; never invent calls. Report integration blockers and the smallest fallback; do not silently change networking technology or control model.

No scoring, damage, replays, progression, role rotation, multiple vehicles/control schemes, elaborate menus, cosmetics, voice or new modes. No final adoption of shared directional controls.

## Build checkpoints and acceptance

1. Local handling checkpoint: visible car/bay, solo forward/reverse/steer/stop/park/reset; 2–4 independent channels affect only their assigned actions; readable mapping and safe remapping.
2. Online playable: EOSG room-code host/join with up to four total players; one host simulation; shared success and repeated reset; safe disconnect and inspectable connection/latency.

Validate separate peers/exported or multi-instance builds, not only one editor. Record exact commands, environment, failures and limits. Automated checks establish behavior, not fun.

Playtest available solo/duo/trio/four-player counts. Record responsiveness, confusion, laughs and voluntary retries as observations. Explicitly decide retain/revise/discard afterward; one session does not prove fun for every count.
