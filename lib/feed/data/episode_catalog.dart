import 'package:rume/feed/domain/episode.dart';

/// The catalogue. Swapping content only touches this file.
abstract final class EpisodeCatalog {
  static const _base = 'https://res.cloudinary.com/hujow0iw/video/upload';

  static const _series = 'Alright Originals';

  // Seven demo clips, at most 20 s each, cut at scene changes
  // (720x1280, H.264, faststart).
  static const List<({String id, String description})> _clips = [
    (
      id: 'ep1',
      description:
          'A stranger shows up at the door with a name nobody has said out '
          'loud in years. Everyone pretends not to recognise it. Not everyone '
          'is good at pretending.',
    ),
    (
      id: 'ep2',
      description:
          'A phone left face down, a message nobody was meant to see, and a '
          'dinner that goes very quiet. Somebody at this table is lying, and '
          'they know who.',
    ),
    (
      id: 'ep3',
      description:
          'The old house keeps its secrets well, until tonight. One locked '
          'drawer, one missing key, and a promise made long before any of '
          'them knew what it would cost.',
    ),
    (
      id: 'ep4',
      description:
          'Two people who swore never to speak again end up stuck in the same '
          'room. What starts as an argument turns into the truth neither of '
          'them was ready to hear.',
    ),
    (
      id: 'ep5',
      description:
          'A deal is struck in the dark. By morning the whole family will '
          'feel it, but only one of them will understand what was really '
          'traded away.',
    ),
    (
      id: 'ep6',
      description:
          'The plan was simple and it should have worked. Then someone came '
          'home early, and every careful lie started falling apart at once.',
    ),
    (
      id: 'ep7',
      description:
          'Everything comes to a head. Old debts are called in, sides are '
          'chosen, and the one person they all trusted finally says what they '
          'did.',
    ),
  ];

  /// Cloudinary renders a still from a video URL: `so_0` picks the frame at
  /// 0 s, and the `.jpg` extension asks for an image.
  static String _poster(String id) =>
      '$_base/c_fill,h_1280,w_720,so_0,q_auto/$id.jpg';

  static final List<Episode> episodes = [
    for (final (i, clip) in _clips.indexed)
      Episode(
        number: i + 1,
        title: 'Episode ${i + 1}',
        series: _series,
        description: clip.description,
        videoUrl: '$_base/${clip.id}.mp4',
        posterUrl: _poster(clip.id),
        // Demo counts, falling off over the season as real ones tend to.
        counts: (
          likes: 48200 - i * 5300,
          comments: 1260 - i * 140,
          shares: 3400 - i * 380,
        ),
      ),
  ];
}
