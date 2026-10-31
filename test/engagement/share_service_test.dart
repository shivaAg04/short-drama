import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rume/engagement/data/share_service.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// The system share sheet, answering as the user would.
class _FakeShareSheet extends SharePlatform with MockPlatformInterfaceMixin {
  ShareResultStatus answer = ShareResultStatus.success;
  final List<ShareParams> opened = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    opened.add(params);
    return ShareResult('', answer);
  }
}

void main() {
  // SharePlus keeps the first platform it sees, so there is one fake sheet,
  // reset between tests.
  final sheet = _FakeShareSheet();
  setUpAll(() => SharePlatform.instance = sheet);
  setUp(() {
    sheet.opened.clear();
    sheet.answer = ShareResultStatus.success;
  });

  const episode = Episode(number: 4, videoUrl: 'v4', posterUrl: 'p4');

  test('[RAIL-5] the sheet gets the episode and the Alright! link', () async {
    await const ShareService().share(episode);
    final params = sheet.opened.single;
    expect(params.subject, 'Alright!TV');
    expect(params.text, contains('Episode 4'));
    expect(params.text, contains('https://alright.watch'));
  });

  test('[RAIL-5] only a completed share counts', () async {
    expect(await const ShareService().share(episode), isTrue);

    sheet.answer = ShareResultStatus.dismissed;
    expect(await const ShareService().share(episode), isFalse);
  });
}
