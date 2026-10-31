# 07 — Top bar

## Context

Not in the brief. Short-video apps keep the brand and a sound switch at the
top, but a bar that is always there covers the video. This one stays out of
the way until the user touches the screen.

## Acceptance criteria

- **TOP-1** The feed opens with no top bar.
- **TOP-2** Any touch on an episode shows the bar (the Alright! wordmark on
  the left, a sound button on the right). It fades and slides in; the touch
  still does what it would have done (pause, like, scrub).
- **TOP-3** The bar hides itself 3 s after the last touch. Every new touch,
  including one on the bar, restarts the 3 s.
- **TOP-4** The sound button mutes or unmutes every video in the feed, including
  ones that load later, and its icon shows the current state.
- **TOP-5** The bar never shows on an ad page; landing on one hides it at once.
- **TOP-6** While hidden, the bar takes no touches: what is under it gets them.

## Decisions

- **Watched with a `Listener`, not a `GestureDetector`.** A raw pointer
  listener sees every touch without joining the gesture arena, so it cannot
  steal the tap, double-tap, scrub or swipe from the page below.
- **Mute lives in `VideoPool`.** The pool owns every controller, so it is the
  one place that can apply the volume to videos that are still loading.
- **Hidden on ads.** The ad has its own "Sponsored" badge and controls at the
  top; a sound switch there would do nothing to the ad.
