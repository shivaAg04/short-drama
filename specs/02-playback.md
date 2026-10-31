# 02 — Vertical feed and playback

## Context

> Implement a vertical PageView containing at least seven sequential episodes
> of looping video clips. Transitions between videos must be immediate and
> snappy. Include a custom loading state ... skeleton shimmer or a branded
> ghost element.

## Acceptance criteria

- **PLAY-1** The feed is a vertical `PageView`; each episode loops.
- **PLAY-2** Only the focused episode plays; every other controller is paused.
- **PLAY-3** At most 3 controllers exist (focused ± 1). Controllers leaving
  that window are disposed.
- **PLAY-4** The next episode's controller is initialised before the user
  swipes to it, so the swipe reveals a ready first frame.
- **PLAY-5** While a video is not ready, the episode's poster is shown on
  its own, with no shimmer; no `CircularProgressIndicator` appears anywhere
  in the feed.
- **PLAY-6** Episodes locked by the paywall never get a controller (see PAY-2).
- **PLAY-7** Leaving the app pauses playback; returning resumes the focused
  episode only.
- **PLAY-8** A single tap toggles pause on the focused episode, with a play icon
  that pops in while paused. Moving to another episode clears the pause.
- **PLAY-9** Mute is one switch for the pool: it silences every ready video and
  every video that finishes loading while it is on (see TOP-4).
- **PLAY-10** The screen stays awake while an episode is actually playing, and
  only then: pausing, an ad page, the paywall, the splash or leaving the app
  hands the screen back to its normal timeout.
- **PLAY-11** Each episode is labelled with a chip, `Episode 3/7`, on the brand
  gradient at the bottom left, shown from the start: while the video loads,
  once it is ready, and on locked or failed episodes.
- **PLAY-12** Above the timeline, the time reads `0:07/0:15` (elapsed/total).
  It follows the bar, including while scrubbing, changes once per second, and
  is painted, so it rebuilds no widgets. It reads muted at rest and turns
  full white while scrubbing, fading back once the finger lifts.
- **PLAY-13** Under the chip sit the series name, with its avatar, and the
  episode's description, cut to two lines with an ellipsis. Tapping the
  description opens it in full, growing upwards; tapping it again closes it.
  That tap neither pauses nor likes the episode.

## Non-functional

- Video position updates must not rebuild the page widget tree.
- Page-to-page settle under 300 ms with a non-overshooting spring.

## Decisions

- **The pool owns the wakelock.** It is the one place that knows whether a
  video is really playing, so the lock follows playback instead of screens.

- **Window of 3 controllers.** Rejected: one per episode (memory, decoder
  limits on low-end Android) and one only (black frame on swipe).

## Out of scope

- Adaptive bitrate selection; HLS is supported only as far as `video_player` is.
