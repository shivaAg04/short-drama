# 08 — Splash

## Context

Not in the brief. The first thing anyone sees is the launch, so it should be
Alright!'s, and it should not waste time: the feed loads while it plays.
The tagline is the one on alright.watch: "Stream. Binge. Drama."

## Acceptance criteria

- **SPLASH-1** On launch the splash covers the feed. The tilted "alright!"
  panel springs in from small, overshoots and settles at its tilt.
- **SPLASH-2** After the panel lands, the tagline arrives one word at a time:
  "Stream." then "Binge." then "Drama.".
- **SPLASH-3** The feed loads underneath meanwhile: the first episode's video
  starts initialising at once, but nothing plays (no sound) while the splash
  is up.
- **SPLASH-4** The splash leaves once its intro has played (1.5 s) and the
  first video is ready, or after 3 s whatever the video's state, so a slow
  network never traps the user on it.
- **SPLASH-5** It hands off by fading out while growing slightly; the first
  episode starts playing as the fade begins, so the feed is already moving
  when it is revealed. Afterwards the splash is gone from the tree.
- **SPLASH-6** Touches during the splash do nothing to the feed.
- **SPLASH-7** *(manual)* The platform launch screens (Android, Android 12+
  and iOS) are the same ink colour, so there is no white flash before the
  splash.

## Decisions

- **The splash is an overlay on the feed, not a separate route.** The feed
  and its video pool are built behind it from the first frame, so the wait
  for the first video overlaps the intro instead of following it.
- **Playback is held for a reason (`#splash`).** The pool counts holds by
  reason, so the app going to the background and coming back during the
  splash cannot start the video underneath it.
- **No spinner.** If the 3 s cap is hit, the feed's own skeleton takes over.
