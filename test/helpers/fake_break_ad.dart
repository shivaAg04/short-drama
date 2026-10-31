import 'package:flutter/widgets.dart';
import 'package:rume/ads/break_ad.dart';

/// A [BreakAd] whose answer each test gives by calling [onFilled] or
/// [onEmpty] itself.
class FakeBreakAd implements BreakAd {
  FakeBreakAd(this.breakId, {required this.onFilled, required this.onEmpty});

  final String breakId;
  final VoidCallback onFilled;
  final void Function(String why) onEmpty;

  /// Thrown from [load] when set, as the plugin throws for a bad request.
  Exception? throwOnLoad;
  bool requested = false;
  bool disposed = false;
  int taps = 0;

  static const ValueKey<String> viewKey = ValueKey('fake-break-ad');

  @override
  Future<void> load() async {
    requested = true;
    if (throwOnLoad case final error?) throw error;
  }

  @override
  Future<void> dispose() async => disposed = true;

  @override
  Widget buildView() => GestureDetector(
    key: viewKey,
    behavior: HitTestBehavior.opaque,
    onTap: () => taps++,
  );
}
