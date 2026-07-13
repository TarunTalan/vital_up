import 'package:isar_community/isar.dart';

part 'favorite_audio.g.dart';

@collection
class FavoriteAudio {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String trackId = '';

  String title = '';
  String subtitle = '';
  String audioSource = ''; 
  String? localFilePath;
  String? spotifyUri;

  DateTime favoritedAt = DateTime.now();
}
