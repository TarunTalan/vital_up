import 'package:on_audio_query_forked/on_audio_query.dart';

class LocalAudioQueryService {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Requests the appropriate permissions for reading audio files from the device.
  Future<bool> requestPermissions() async {
    return await _audioQuery.permissionsRequest();
  }

  /// Checks if the user has granted storage/audio permissions.
  Future<bool> hasPermissions() async {
    return await _audioQuery.permissionsStatus();
  }

  /// Scans and returns all audio files (songs) on the device.
  Future<List<SongModel>> getLocalSongs() async {
    if (!await hasPermissions()) return [];
    return await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }

  /// Scans and returns all audio albums on the device.
  Future<List<AlbumModel>> getLocalAlbums() async {
    if (!await hasPermissions()) return [];
    return await _audioQuery.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }

  /// Scans and returns all artists on the device.
  Future<List<ArtistModel>> getLocalArtists() async {
    if (!await hasPermissions()) return [];
    return await _audioQuery.queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }
}
