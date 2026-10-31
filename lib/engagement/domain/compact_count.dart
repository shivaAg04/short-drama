/// `999`, `1.2K`, `12.4K`, `1.2M`. Rounds down, so a count never shows more
/// than it is.
String compactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${_oneDecimal(n / 1000)}K';
  return '${_oneDecimal(n / 1000000)}M';
}

String _oneDecimal(double value) {
  final text = ((value * 10).floor() / 10).toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}
