abstract final class AdConfig {
  // Google's published sample unit for Ad Manager native ads (AD-5); no
  // real unit ever goes in this file. The native *video* sample serves
  // nothing on test devices, so every break uses this one.
  static const _nativeTestUnit = '/21775744923/example/native';

  // `flutter run --dart-define=AD_NO_FILL=true` asks for a unit that does
  // not exist, so every break comes back empty: a way to watch breaks
  // leave the feed on a device.
  static const _forceNoFill = bool.fromEnvironment('AD_NO_FILL');
  static const _missingTestUnit = '/21775744923/example/no-such-unit';

  /// Name of the native factory registered in MainActivity / AppDelegate.
  static const factoryId = 'fullScreen';

  static String unitFor(String breakId) =>
      _forceNoFill ? _missingTestUnit : _nativeTestUnit;

  /// How many pages ahead of the user a break's ad is requested.
  static const warmAhead = 2;

  /// An ad still pending after this long is treated as empty.
  static const loadTimeout = Duration(seconds: 8);
}
