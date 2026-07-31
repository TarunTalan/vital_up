import 'package:isar_community/isar.dart';

part 'downloaded_track.g.dart';

@collection
class DownloadedTrack {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String trackId = '';

  String localFilePath = '';
  String title = '';
  String subtitle = '';
  DateTime downloadedAt = DateTime.now();
}
