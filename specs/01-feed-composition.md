# 01 — Feed composition

## Context

> Insert an interactive ad slot after every 3 episodes ... E1 E2 E3 AD E4 E5
> E6 AD E7. Ad slots are full-screen pages in the same PageView and must not
> count toward episode numbering. If an ad fails to load or returns no fill,
> the slot must be removed gracefully without a visible jump or broken page.

## Acceptance criteria

- **FEED-1** Given 7 episodes, the feed is `E1 E2 E3 AD E4 E5 E6 AD E7`.
- **FEED-2** The feed never ends on an ad slot.
- **FEED-3** Removing an ad slot never changes any episode's number.
- **FEED-4** Every page has an id (`episode:4`, `break:1`) that does not
  depend on its index and is unchanged when other pages are removed.
- **FEED-5** Given a failed slot *ahead* of the user, it is removed and the
  focused page does not change.
- **FEED-6** Given a failed slot *behind* the user, it is removed and the
  same episode stays on screen: its page index drops by one and the pager is
  re-seated on it before the next frame (no animation).
- **FEED-7** Given a failed slot *on screen*, the user is animated to the next
  page first; the slot is removed once scrolling settles (then FEED-6 applies).
- **FEED-8** No slot is removed while the user is dragging or the feed is
  flinging; pending removals run when scrolling ends.
- **FEED-9** The locked episode's page index is looked up in the current
  layout, so it follows removals (E7: page 8 → 7).

## Non-functional

- The layout (`layoutFeed`) is a pure function with no Flutter imports, so it
  is unit-testable.
- The layout is computed on read from `episodes + dropped`; there is no
  separately stored list that could drift.

## Decisions

- **Focus is held by id, not by page index.** The bloc stores the id of the
  entry in view and derives the index from the layout, so dropping a break
  behind the user needs no index arithmetic: the screen just moves the
  controller to wherever that id now sits. Rejected: storing page indices
  and issuing correction commands, because every removal would have to
  rewrite them.
- **Glide-then-remove for an on-screen slot (FEED-7).** Rejected: removing it in
  place, which would swap the page under the user's eyes.

## Out of scope

- Server-driven ad cadence; `runLength` is a parameter of `layoutFeed`.
