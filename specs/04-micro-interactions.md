# 04 — Micro-interactions

## Context

> On double-tap, a heart icon must appear at the exact touch location ...
> scale and fade animation with spring physics. Build a custom-painted progress
> bar ... As the user drags across the screen, the progress bar should expand
> vertically and show a time preview (e.g., 00:05 / 00:15) that follows the
> finger position.

## Acceptance criteria

### Double-tap to like

- **LIKE-1** A double-tap shows a heart centred on the touch point.
- **LIKE-2** The heart scales in on an underdamped spring (visible overshoot)
  and fades out; it removes itself when done.
- **LIKE-3** Rapid double-taps stack independent hearts; none cancels another.
- **LIKE-4** *(manual)* A light haptic fires on like.
- **LIKE-5** After its pop, the heart flies on a curve from the touch point into
  the rail's like icon, shrinking as it goes; when it lands the episode is
  liked and the rail icon pops. A double-tap never unlikes.

### Progress scrubbing

- **SCRUB-1** The progress bar is drawn with a `CustomPainter`.
- **SCRUB-2** A horizontal drag *anywhere* on an episode starts scrubbing, with
  no long-press first.
- **SCRUB-3** A vertical drag still pages the feed; the two never both fire.
- **SCRUB-4** While scrubbing the bar grows from 3 px to 10 px on a spring, and
  shrinks back on release.
- **SCRUB-5** A preview `mm:ss / mm:ss` sits just above the finger and follows
  it in both axes, clamped to stay on screen. The finger's x maps directly to
  the time (left edge 0:00, right edge the end).
- **SCRUB-6** The video seeks on release and the bar holds the target until the
  player catches up, so it never snaps back for a frame. Playback position
  updates repaint the bar only and rebuild no widgets.
- **SCRUB-7** Between the plugin's position updates (about every 500 ms) the bar
  advances smoothly, interpolated per frame, never running more than 600 ms
  ahead of the last reported position.
- **SCRUB-8** While scrubbing, a 9:16 thumbnail of the frame at the nearest
  second sits above the time and travels with it. Moving between seconds keeps
  the previous frame up until the next one is ready, so it never blinks.
- **SCRUB-9** An episode's thumbnails, one per second of video, are requested
  on its first scrub and kept for the session; later scrubs request nothing
  new.
- **SCRUB-10** Frames are rendered by the video host: for a Cloudinary video,
  any second is an image at a URL derived from the video's own. For a video
  the host cannot render, the preview is the time alone, as before.
- **SCRUB-11** The part of the video the player has already downloaded shows
  as a lighter band on the track, ahead of the played fill, like YouTube's.
  It follows the player's buffered ranges, and only repaints the bar when
  they change.

## Decisions

- **Absolute scrub mapping.** The brief asks for a preview that follows the
  finger, so finger x *is* the time. Rejected: relative (delta) scrubbing,
  where the preview and the finger drift apart.
- **Scrubbing anywhere, no long-press.** A long-press first adds ~500 ms before
  anything responds. Horizontal and vertical drags are told apart by the
  gesture arena on direction.

- **Frames come from the server, not the phone.** Decoding frames on the
  device while the finger moves means a second decoder seeking constantly,
  which stutters on mid-range phones. Server-rendered stills are ~10 KB each,
  and a 20 s episode needs 20 of them, fetched once.

## Out of scope

- Sprite sheets (many frames in one image): worth it for long episodes, not
  for 20 s clips.
