import 'package:equatable/equatable.dart';

class Episode extends Equatable {
  const Episode({
    required this.number,
    required this.videoUrl,
    required this.posterUrl,
    this.title = '',
    this.series = '',
    this.description = '',
    this.counts = (likes: 0, comments: 0, shares: 0),
  });

  /// 1-based episode number shown to the user. Ad slots never affect it.
  final int number;
  final String videoUrl;

  /// Still image used for the skeleton hand-off and the paywall backdrop,
  /// so a locked episode never has to touch its video.
  final String posterUrl;
  final String title;

  /// The show this episode belongs to, and what happens in it (PLAY-13).
  final String series;
  final String description;

  /// What the catalogue reports; the session's engagement counts from here.
  final ({int likes, int comments, int shares}) counts;

  @override
  List<Object?> get props => [
    number,
    videoUrl,
    posterUrl,
    title,
    series,
    description,
  ];
}
