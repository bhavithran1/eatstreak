---
name: plan-feature
description: Interview the user about a multi-file feature and write SPEC.md before any code exists. Use for anything spanning app, functions and rules.
disable-model-invocation: true
---

The feature: $ARGUMENTS

**Write no code in this session.** No edits, no new files except `SPEC.md`.

1. Read enough of the repo to ask grounded questions. Prefer a subagent for the reading
   so this conversation stays clean for the interview.

2. Check for a **platform constraint that decides the design before the user does**, and
   research it now rather than after the integration is written. Apple's 3.1.1 is why
   pricing lives on the web and not in the app; APNs behind the paid Developer Program is
   why push notifications aren't built. If the feature touches payments, notifications,
   sign-in, or anything Apple or Google gates, find the rule first and open the interview
   with it — the user cannot choose around a rule they haven't been told about.

3. Interview the user with `AskUserQuestion`. Spend the questions on what is expensive to
   get wrong, not on what the code already answers:
   - **Who physically does what**, in the real world, at the counter. Which role scans,
     which role shows, who is holding which phone.
   - **What the thing has to survive** — a screenshot, a saved link, a customer who
     leaves and comes back tomorrow.
   - **Where state lives** — device, Firestore, or derived on the server.
   - **What happens when it fails** in front of a paying customer.
   - **What is explicitly out of scope.**

4. Keep going until the *mechanism* is settled — not the wording, the mechanism. When a
   proposed design contradicts physical reality (a printed code cannot change per scan),
   say so during the interview rather than building it and discovering it after.

5. Write `SPEC.md`: the decision and why, the platform constraints that bound it, the
   files and interfaces involved, what is out of scope, the deploy and console steps the
   user must run, and an end-to-end check that proves it works.

6. Tell the user to start a fresh session and implement from `SPEC.md`.

## Why this exists

The check-in code mechanism was built three times — per-scan single-use, then
regenerate-on-scan, then daily — because the mechanism was never settled before the first
implementation. Two of the three were thrown away, each spanning the Flutter app, the
Cloud Functions and the security rules. Settling the mechanism costs minutes of
conversation. Rebuilding it costs hours.

Worse, the discarded versions left their comments behind. A note claiming codes expired
in 90 seconds outlived the mechanism it described, and later justified dropping the token
through sign-in — which broke every first-ever check-in. A design that changes has to take
its documentation with it, or the next decision is made from a fact that stopped being
true.
