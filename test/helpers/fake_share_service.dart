import 'package:rume/engagement/data/share_service.dart';
import 'package:rume/feed/domain/episode.dart';

class FakeShareService implements ShareService {
  final List<int> shared = [];
  bool completes = true;

  @override
  Future<bool> share(Episode episode) async {
    shared.add(episode.number);
    return completes;
  }
}
