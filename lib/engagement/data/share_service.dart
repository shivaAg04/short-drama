import 'package:rume/feed/domain/episode.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet. Behind a class so the rail can be tested
/// without the platform plugin.
class ShareService {
  const ShareService();

  /// True when the user completed a share.
  Future<bool> share(Episode episode) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        subject: 'Alright!TV',
        text:
            'Watching Episode ${episode.number} on Alright!TV 🍿 '
            'https://alright.watch',
      ),
    );
    return result.status == ShareResultStatus.success;
  }
}
