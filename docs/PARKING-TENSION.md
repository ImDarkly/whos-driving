# Parking tension — design recommendation (research, not approval)
Date: 2026-11-09
Status: **proposal only**. No gameplay, controls, handling, approved-spec, or production changes authorized by this document.

## Decision in one sentence

**Prototype a single parking bay with two viable, visibly different *commitment lines*—a wide nose-first setup and a tighter reverse setup—where the crew's early alignment changes which corners need help later, and a bad commitment can be undone by cooperative repositioning.** Preserve wheel ownership and the ordinary parking objective. Do **not** add a timer, a new ability, Shove, special brakes, ramps, damage, automatic hazards, or a new game loop as prerequisites.

The hook to test is not "park accurately"; it is **"our reasonable choice created a different problem for one of us, and now we have to recover together."** That statement is a hypothesis, not an observed outcome.

## Current evidence and limits — do not conflate branches or dates

- [AGENTS.md](https://github.com/ImDarkly/whos-driving/blob/main/AGENTS.md) requires reading GAME/SPEC/KNOWLEDGE, separating playtest observations from approvals, surgical changes, and explicit Oleksandr approval for changes to handling, difficulty, controls, or player experience. This file is design research, not a request to implement.
- [GAME.md](https://github.com/ImDarkly/whos-driving/blob/main/docs/GAME.md) describes online friends sharing one car and parking; it also says the first-person experiment is implemented on a wheel-controlled foundation but adoption is undecided. The fresh Godot + EOSG decision **supersedes** older Chum-code reuse language in Notion.
- [SPEC.md](https://github.com/ImDarkly/whos-driving/blob/main/docs/SPEC.md) records the approved small readable lot revision: one clear aisle, a few parked cars, turning into a bay between neighbours, harmless collision, immediate shared reset, and unchanged existing control/handling/parking rules. Approval of a bounded experiment does not equal adoption of a new permanent direction.
- [KNOWLEDGE.md](https://github.com/ImDarkly/whos-driving/blob/main/docs/KNOWLEDGE.md) reports a **human duo session** in which driving was fun but the then-open approach was too easy. The exact build and details of that session are unspecified. It separately reports scripted driven parking success for one through four owners and localhost network regression on the smaller lot; these are **technical checks**, not evidence of four-player fun or internet/EOS acceptance. Cabin view has rear-headrest occlusion; warning visibility during human play is unverified.
- The Nov 4 small-lot checkpoint is recorded on `codex/constrained-parking-approach`, not proven here to be the live scene on the user's latest machine. This analysis read GitHub's **default-branch documents** and reachable Notion pages; it did not check a working tree, launch Godot, review every development branch, or inspect an actual playtest video. No Hop/Shove implementation was independently verified. The user reports Hop seemed okay but unproven; Shove felt strange; separate brakes/ramp felt generic. Treat these as reported design feedback, not measurements of the presently checked-out build.

## One authored parking problem

A compact ordinary parking lot contains the same green target bay and parked neighbours. Leave a readable aisle and enough apron to reverse away. Show both intended approaches from the driving space, without arrows that label a correct answer.

**Approach A — wide setup / nose-first.** The crew takes the outside of the aisle before cutting inward. It has an easier initial heading and a larger turning radius, but its near front corner approaches a neighbouring bumper; the rear can then drift toward the opposite curb. One side can ask for less turning now; the other may need more rotation to reach the bay. A correction requires making room for the *other* end, rather than turning harder.

**Approach B — tight setup / reverse-in.** The crew passes the bay, aligns further along the aisle, and backs toward it. It initially preserves the near front corner but puts the rear corner nearest the neighbour, while the front nose sweeps outward into aisle space. It may offer a straighter final parked heading, but asks players to judge rear clearance from seated views. Either approach must remain feasible with present car dimensions and commands, including one safe reversal out of a poor setup.

The two approaches are **not** "easy but slow" and "fast but dangerous" by assertion; no stopwatch or scoring proves that. Their candidate trade-off is spatial: the first protects rear access at the expense of front turning clearance; the second protects an entry heading but consumes rear clearance and front swing room. Which route is actually better depends on readable vehicle pose and crew coordination, not a colored gate or mandatory mode.

### What players do, decide, and repair

- **Before entry:** Each owner contributes wheel inputs to choose the initial line. A person noticing their own exposed corner asks to take more or less aisle, *before* the car reaches a restrictive pose. The group chooses a nose-first or reverse-in plan; one participant's preferred line must not automatically erase the other's concern.
- **During commitment:** The front/rear clearance priority changes with the angle. An owner reduces, reverses, or moderates wheel contribution to let another wheel group correct the heading. A useful callout identifies a physical corner and an action ("rear-right is closing; straighten, then reverse"), not only "stop!"
- **At a mistake:** Contact is harmless under the current approved experiment. They stop, identify which corner cannot sweep freely, unwind to the open apron (potentially one player backing while the other prevents a counter-swing), and either retry the same line or switch to the other. No hidden penalty, elimination, instant explosion, or full-level restart is needed.
- **At success:** The existing parking success condition remains the finish. The new value, if real, is the social history of a decision and a rescue that led there, not an extra score screen.

For **two players**, the active question is whether left/right ownership actually creates different responses during this geometry; otherwise it is just one driver distributed over two controllers. For **three**, inspect whether the linked wheel group has an independent correction rather than waiting. For **four**, check whether all four corners exert materially distinct decisions over the manoeuvre. An offset car or obstacle is acceptable only if readable; forced role asymmetry is not assumed. If the physical input model doesn't make each owner consequential, this level cannot cure it by rhetoric.

## Why it could be more than awkward controls or precision parking

This proposal creates a *sequence of changing interdependencies* inside parking: the crew first agrees on a setup, then discovers the cost of that setup at a particular corner, then chooses whether to salvage or abandon it. Both early and late inputs matter. A failure can be attributable ("I cut in before the rear had space") and repairable without a generic reset. This contrasts with a single narrow bay where players merely adjust all wheels until the car fits.

**Counterargument:** This could still be ordinary precision parking disguised as a choice. If one approach dominates, the occupants memorize a steering script; if a single caller can solve both, conversation becomes decoration; if clearance isn't visible from cabin seats, frustration replaces a fair mistake. The existing reported easy duo run is evidence of this risk, not evidence that new geometry solves it. The Nov 7 [SHIFT exploration](https://app.notion.com/p/411351013fca817ea291c6a57d3e2c84) also suggests track transfers and pivot anchors, but neither establishes a tested benefit and both introduce new control/physics scope. A jam-sized test should first falsify the no-new-mechanic case.

## Smallest discriminating experiment (requires separate approval)

**Design only now.** Once approved, use an isolated copy of the existing playable and retain the same authoritative controls, car, collision, parking success, and reset. Make *one* target bay and *two* feasible setup lines. Do not add mechanics. Verify actual footprint, seated visibility, front/rear swept paths, and a reversibly misaligned pose before any friends play. Compare two conditions with the same crew:

1. **Baseline:** the current small lot and target, unchanged.
2. **Candidate:** same target with deliberate open staging positions allowing the wide nose-first or tight reverse-in approaches, and enough space to undo either.

Run two-player pairs first; then four players if feasible. Let crews play without prescribing a route; swap order of baseline/candidate across groups if possible. Record per attempt: chosen line, voluntary plan changes, who named a specific corner, which person changed input in response, corrections without reset, contacts, waiting/idleness, repeat attempts, and reported laughter versus annoyance. Ask each participant which moment genuinely required another person, which mistake was their team's to fix, and whether they'd retry. With consent, capture input/view footage; note unexpected dominant paths. A simple completion-time comparison is insufficient.

**Falsify/retire:** one approach is chosen every time after learning; the same participant directs everyone; the remaining owners become passive; the alternative exists only visually; wrong approaches demand a reset; success takes longer but produces no additional distinct shared decisions or recoveries. If the geometry produces an actual trade-off, consider variations **after** accepting it, not procedurally generated lots or extra abilities first. If it fails, do not "fix" the result by forcing a SHIFT button or a countdown.

## Rejected or unresolved alternatives

- **Shove:** user-reported strange; no measured rescue use. Not selected.
- **Independent brakes + ramp:** user-reported generic; not selected.
- **Hop:** user-reported acceptable but unproven; no adoption.
- **Blind driver / seeing navigator:** appealing as a dependence reference, but the user declined direct imitation; not selected.
- **Separate jobs, moving obstacles, trailer, damage, timed pressure, SHIFT abilities, generated lots:** possible later investigations, not required to test parking tension; increasing scope would confound the question.
- **Track Transfer / Pivot Handoff / Ballast Relay:** documented creative concepts in [SHIFT exploration](https://app.notion.com/p/411351013fca817ea291c6a57d3e2c84), not accepted implementation decisions.

## Sources and provenance

Project: [AGENTS.md](https://github.com/ImDarkly/whos-driving/blob/main/AGENTS.md), [GAME.md](https://github.com/ImDarkly/whos-driving/blob/main/docs/GAME.md), [SPEC.md](https://github.com/ImDarkly/whos-driving/blob/main/docs/SPEC.md), [KNOWLEDGE.md](https://github.com/ImDarkly/whos-driving/blob/main/docs/KNOWLEDGE.md); Notion: [Parking Game](https://app.notion.com/p/40e351013fca80428cccc909d05cd3f5), [Cooperative Parking Research](https://app.notion.com/p/410351013fca811e88cac0f0d7a0e5b6), [SHIFT Exploration](https://app.notion.com/p/411351013fca817ea291c6a57d3e2c84). For outside precedent and evidence limitations see the Cooperative Parking Research page, especially the [Overcooked developer account](https://www.gamedeveloper.com/design/game-design-deep-dive-building-truly-cooperative-play-in-i-overcooked-i-) and [Shared RC](https://store.steampowered.com/app/3475680/Shared_RC/). These external sources were **cited from existing Notion research**, not freshly replayed or independently verified in this pass.

Missing: actual latest local checkout/branch, full current gameplay scripts and footage, completed newer friend tests, EOS internet validation, the chat/research archive beyond accessible Notion content and supplied conversation context. No claim of complete archive or observed new design performance.
