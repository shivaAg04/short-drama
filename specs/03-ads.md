# 03 — Ad slots (Google Ad Manager)

## Context

> Ads must be preloaded ahead of the user reaching the slot ... Use the same
> branded skeleton while an ad is still loading. Episode gestures must be
> disabled on ad pages, while the ad's own interactive elements must remain
> fully functional. Use GAM test ad units only.

## Acceptance criteria

- **AD-1** The next ad break ahead of the user (or the one on screen) is
  always loading: the first is requested at launch, behind the splash, and
  each later one as soon as the user passes the break before it.
- **AD-2** A slot still loading shows the branded shimmer skeleton.
- **AD-3** An error, no fill, or a load longer than 8 s reports the slot as
  failed to the feed (handled by FEED-5..8).
- **AD-4** Ad pages have no episode gesture layer: double-tap and scrubbing do
  nothing; the ad's CTA and taps work; vertical swipes still page the feed.
- **AD-5** Only Google's GAM test ad units and test app IDs are configured.
- **AD-6** Every ad object is disposed when its slot is removed or the feed is
  disposed. A late load result for a released slot is disposed on arrival.
- **AD-7** The ad fills the page (native ad, custom layout), not a banner box.
  The skeleton fades off a loaded ad; the ad itself (a platform view) is never
  faded or transformed.

## Decisions

- **Native ad over banner/interstitial.** A banner cannot fill a page; an
  interstitial is not a page in the feed.
- **Custom native factory over Google's templates.** The medium template tops
  out at ~400 px tall; a full-bleed `MediaView` with our own headline, CTA and
  "Sponsored" badge (Android XML, iOS UIKit) makes the ad a real page.
- **The ad layer is behind an interface (`BreakAd`).** `BreakAdLoader` and
  `AdBreakPage` are tested with fakes; only `GamBreakAd` touches the plugin.
- **One record per break in the loader.** Each break's status, ad and load
  deadline live together, so discarding or failing a break is one place to
  clean up. Failures reach the feed through the `onEmpty` callback.
- **Image native unit for every slot.** Verified on an Android emulator:
  Google's `native-video` sample unit returns no fill (code 3) for test
  devices, while `native` fills. `--dart-define=AD_NO_FILL=true` forces no fill
  everywhere to demo graceful removal.
- **Request the next break as early as possible (AD-1).** A real-network GAM
  load takes 1–3 s, more for the session's first request while the SDK is
  still starting. Requesting only two pages ahead was verified on a phone to
  show the skeleton when the user swiped quickly. Rejected: a fixed page
  distance, which is only as early as the user is slow. Cost: one request for
  a break the user may never reach; an impression only counts when shown.
- **Ad pages are kept alive** once built, so swiping back to one doesn't
  rebuild the native view.

## Out of scope

- Mediation, consent (UMP) flows, frequency capping.
