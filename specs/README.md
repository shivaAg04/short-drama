# Specs

This project is built spec-first. Every feature goes through the same loop:

1. **Spec** — a file in this folder states the behaviour, quoting the brief
   where it applies, as numbered acceptance criteria (`FEED-5`, `PAY-3`, ...).
   Decisions and assumptions are written down here, before code.
2. **Test** — each criterion gets at least one test whose name starts with its
   ID, e.g. `test('[FEED-6] a slot behind the user ...')`.
3. **Code** — implementation is written until those tests pass.
4. **Trace** — `dart run tool/spec_coverage.dart` lists every criterion and the
   tests that cover it. Criteria that can only be judged on a device (haptics,
   feel) are marked *(manual)* in the spec and reported separately.

If behaviour changes, the spec changes first.

| Spec | Prefix | Area |
|---|---|---|
| [01-feed-composition.md](01-feed-composition.md) | `FEED` | Page order, ad slot removal |
| [02-playback.md](02-playback.md) | `PLAY` | Vertical feed, video pool, skeleton |
| [03-ads.md](03-ads.md) | `AD` | GAM native ads |
| [04-micro-interactions.md](04-micro-interactions.md) | `LIKE`, `SCRUB` | Double-tap like, scrubbing |
| [05-paywall.md](05-paywall.md) | `PAY` | Episode 7 lock and unlock |
| [06-engagement.md](06-engagement.md) | `RAIL` | Like, comment, share, save rail |
| [07-top-bar.md](07-top-bar.md) | `TOP` | Wordmark and sound switch on touch |
| [08-splash.md](08-splash.md) | `SPLASH` | Branded launch, feed loading behind it |
| [09-offline.md](09-offline.md) | `OFF` | Failed videos, retry, recovery |

## Format

Each spec has: **Context** (brief excerpt), **Acceptance criteria**
(Given/When/Then, one ID each), **Non-functional** constraints,
**Decisions** (with the alternative rejected and why), and **Out of scope**.
