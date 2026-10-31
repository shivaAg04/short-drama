import 'package:flutter_test/flutter_test.dart';
import 'package:rume/engagement/domain/compact_count.dart';

void main() {
  test('[RAIL-6] counts are compact', () {
    expect(compactCount(0), '0');
    expect(compactCount(999), '999');
    expect(compactCount(1000), '1K');
    expect(compactCount(1240), '1.2K');
    expect(compactCount(12480), '12.4K');
    expect(compactCount(999999), '999.9K');
    expect(compactCount(1200000), '1.2M');
  });
}
