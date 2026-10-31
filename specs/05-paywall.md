# 05 — Retention paywall (Episode 7)

## Context

> When the user lands on Episode 7, the paywall overlay must appear immediately.
> Episode 7 must not play at all ... The user must not be able to scroll
> forward past Episode 7 ... custom scroll physics ... Returning to Episode 7
> must re-trigger the paywall.

## Acceptance criteria

- **PAY-1** Landing on a locked episode shows the paywall in the same frame.
  The poster is already blurred while the user swipes in, so the locked
  episode is never seen unblurred.
- **PAY-2** A locked episode never creates a video controller; its background
  is the poster image.
- **PAY-3** Custom `ScrollPhysics` stop forward scrolling at the locked page,
  allowing at most 6 % of resistance overscroll so the next page never shows.
  Scrolling back is unaffected.
- **PAY-4** Leaving and returning to the locked page replays the entrance.
- **PAY-5** The background is blurred live with `BackdropFilter`.
- **PAY-6** The card slides up from the bottom on an underdamped spring
  (overshoot), with title, body and CTA staggered.
- **PAY-7** A light sweep crosses the "Unlock Episode" button once every 3 s.
- **PAY-8** Tapping unlock shows a short purchasing state (simulated, ~700 ms),
  then dismisses the paywall (card drops, blur clears), removes the forward
  lock and starts playback of the episode. Repeated taps purchase once.
- **PAY-9** The lock follows the locked episode's page when an earlier ad slot
  is removed (see FEED-9).
- **PAY-10** *(manual)* Pushing against the lock gives one light haptic per
  gesture; a successful unlock gives a medium one.
- **PAY-11** The card opens on a fan of clips: the locked episode's poster
  up front with a lock and its number, the two nearest episodes tilted out
  behind it on a soft glow. They fan out as the card rises.

## Decisions

- **Purchase state lives in `PaywallCubit`, not the widget.** A swipe away
  mid-purchase must not lose the result.
- **The glint is painted, and only while it runs.** A `CustomPainter` draws a
  slanted band over the button; between glints its controller is stopped and
  a periodic timer starts the next one, so the button costs no frames while
  the blur sits behind the card.
- **The lock is an exponential rubber band.** Past the locked page the stretch
  approaches 6 % of a page and never reaches it, however far the drag goes.

- **Unlock lasts for the session.** The brief asks for a simulated unlock.

## Out of scope

- Real purchases and restoring them.
