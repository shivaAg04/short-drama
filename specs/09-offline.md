# 09 — Offline and failed videos

## Context

Not in the brief, but a feed that streams every episode has to say something
when a stream cannot start. Before this spec, a video that failed to load
left its page on the loading skeleton forever: the user could not tell
"loading" from "broken".

## Acceptance criteria

- **OFF-1** An episode whose video fails to load shows a card instead of the
  skeleton: an icon, "Couldn't load this episode", a line saying it will
  start once it loads, and a "Try again" button. The poster stays behind it.
- **OFF-2** While an episode in the window has failed, the pool retries it on
  its own every 3 s. The card stays up through the retries (no flicker back to
  the skeleton); when one succeeds the video fades in, and plays if it is the
  focused episode, without the user doing anything.
- **OFF-3** "Try again" retries at once instead of waiting for the next tick.
- **OFF-4** One episode failing does not touch the others: a video that is
  already loaded keeps playing.
- **OFF-5** Episodes that leave the window are no longer retried; coming back
  to one starts it fresh (skeleton, then a new attempt).
- **OFF-6** *(manual)* On a device in airplane mode the card appears; turning
  the network back on starts the focused episode within about 3 s.

## Decisions

- **The retry is the connectivity check.** A connectivity plugin reports Wi-Fi
  that has no internet as "online"; trying the video itself is the only test
  that answers the real question. It costs one small request per failed
  episode, and at most three episodes are in the window.
- **A fixed 3 s, not backoff.** Retries only run while the user is looking at
  the failed part of the feed, and the point is to recover quickly.
- **One message for every failure.** A dropped connection and a broken file
  look the same to the player; the copy ("Couldn't load this episode … we'll
  keep trying") is true for both.
- **Ads are unchanged.** An ad that cannot load offline already leaves the
  feed (AD-3); it gets no card.

## Out of scope

- Saving videos to disk for offline playback (see the README's production
  notes).
