# 06 — Engagement rail

## Context

Not in the brief; asked for by the product (Alright!TV): the familiar
short-video rail on the right of each episode, as Instagram Reels, TikTok and
Shorts have it, with the double-tap heart travelling into it.

## Acceptance criteria

- **RAIL-1** Every playable episode shows a vertical rail on the right: like,
  comment and share with compact counts, then save.
- **RAIL-2** Tapping like toggles it: the heart fills red with a spring pop and
  the count moves by one.
- **RAIL-3** Tapping save toggles it with a spring pop to a filled, brand-blue
  bookmark.
- **RAIL-4** Tapping comment opens a sheet listing the episode's comments,
  newest first; posting one adds it to the top and bumps the count.
- **RAIL-5** Tapping share opens the system share sheet with the episode's
  link; a completed share bumps the count.
- **RAIL-6** Counts are compact: `999`, `1.2K`, `12.4K`, `1.2M`.
- **RAIL-7** Likes, saves, comments and shares live in `EngagementCubit`, keyed
  by episode, so they survive swiping away and back.
- **RAIL-8** Locked episodes and ad pages have no rail.
- **RAIL-9** Turning like on sends a ripple out of the heart: a red ring
  that grows and fades, with small dots thrown outwards. Turning it off does
  not. A double-tap heart landing in the icon sets it off too.

## Decisions

- **Session-only state.** There is no backend; seeds come from the catalogue.
- **Share goes through `ShareService`**, so the rail is testable without the
  platform plugin.
