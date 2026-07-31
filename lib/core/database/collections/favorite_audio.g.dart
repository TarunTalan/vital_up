// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_audio.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFavoriteAudioCollection on Isar {
  IsarCollection<FavoriteAudio> get favoriteAudios => this.collection();
}

const FavoriteAudioSchema = CollectionSchema(
  name: r'FavoriteAudio',
  id: 5540893982247977580,
  properties: {
    r'audioSource': PropertySchema(
      id: 0,
      name: r'audioSource',
      type: IsarType.string,
    ),
    r'favoritedAt': PropertySchema(
      id: 1,
      name: r'favoritedAt',
      type: IsarType.dateTime,
    ),
    r'localFilePath': PropertySchema(
      id: 2,
      name: r'localFilePath',
      type: IsarType.string,
    ),
    r'spotifyUri': PropertySchema(
      id: 3,
      name: r'spotifyUri',
      type: IsarType.string,
    ),
    r'subtitle': PropertySchema(
      id: 4,
      name: r'subtitle',
      type: IsarType.string,
    ),
    r'title': PropertySchema(id: 5, name: r'title', type: IsarType.string),
    r'trackId': PropertySchema(id: 6, name: r'trackId', type: IsarType.string),
  },

  estimateSize: _favoriteAudioEstimateSize,
  serialize: _favoriteAudioSerialize,
  deserialize: _favoriteAudioDeserialize,
  deserializeProp: _favoriteAudioDeserializeProp,
  idName: r'id',
  indexes: {
    r'trackId': IndexSchema(
      id: -8614467705999066844,
      name: r'trackId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'trackId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _favoriteAudioGetId,
  getLinks: _favoriteAudioGetLinks,
  attach: _favoriteAudioAttach,
  version: '3.3.2',
);

int _favoriteAudioEstimateSize(
  FavoriteAudio object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.audioSource.length * 3;
  {
    final value = object.localFilePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.spotifyUri;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.subtitle.length * 3;
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.trackId.length * 3;
  return bytesCount;
}

void _favoriteAudioSerialize(
  FavoriteAudio object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.audioSource);
  writer.writeDateTime(offsets[1], object.favoritedAt);
  writer.writeString(offsets[2], object.localFilePath);
  writer.writeString(offsets[3], object.spotifyUri);
  writer.writeString(offsets[4], object.subtitle);
  writer.writeString(offsets[5], object.title);
  writer.writeString(offsets[6], object.trackId);
}

FavoriteAudio _favoriteAudioDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FavoriteAudio();
  object.audioSource = reader.readString(offsets[0]);
  object.favoritedAt = reader.readDateTime(offsets[1]);
  object.id = id;
  object.localFilePath = reader.readStringOrNull(offsets[2]);
  object.spotifyUri = reader.readStringOrNull(offsets[3]);
  object.subtitle = reader.readString(offsets[4]);
  object.title = reader.readString(offsets[5]);
  object.trackId = reader.readString(offsets[6]);
  return object;
}

P _favoriteAudioDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _favoriteAudioGetId(FavoriteAudio object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _favoriteAudioGetLinks(FavoriteAudio object) {
  return [];
}

void _favoriteAudioAttach(
  IsarCollection<dynamic> col,
  Id id,
  FavoriteAudio object,
) {
  object.id = id;
}

extension FavoriteAudioByIndex on IsarCollection<FavoriteAudio> {
  Future<FavoriteAudio?> getByTrackId(String trackId) {
    return getByIndex(r'trackId', [trackId]);
  }

  FavoriteAudio? getByTrackIdSync(String trackId) {
    return getByIndexSync(r'trackId', [trackId]);
  }

  Future<bool> deleteByTrackId(String trackId) {
    return deleteByIndex(r'trackId', [trackId]);
  }

  bool deleteByTrackIdSync(String trackId) {
    return deleteByIndexSync(r'trackId', [trackId]);
  }

  Future<List<FavoriteAudio?>> getAllByTrackId(List<String> trackIdValues) {
    final values = trackIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'trackId', values);
  }

  List<FavoriteAudio?> getAllByTrackIdSync(List<String> trackIdValues) {
    final values = trackIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'trackId', values);
  }

  Future<int> deleteAllByTrackId(List<String> trackIdValues) {
    final values = trackIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'trackId', values);
  }

  int deleteAllByTrackIdSync(List<String> trackIdValues) {
    final values = trackIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'trackId', values);
  }

  Future<Id> putByTrackId(FavoriteAudio object) {
    return putByIndex(r'trackId', object);
  }

  Id putByTrackIdSync(FavoriteAudio object, {bool saveLinks = true}) {
    return putByIndexSync(r'trackId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByTrackId(List<FavoriteAudio> objects) {
    return putAllByIndex(r'trackId', objects);
  }

  List<Id> putAllByTrackIdSync(
    List<FavoriteAudio> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'trackId', objects, saveLinks: saveLinks);
  }
}

extension FavoriteAudioQueryWhereSort
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QWhere> {
  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension FavoriteAudioQueryWhere
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QWhereClause> {
  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterWhereClause> trackIdEqualTo(
    String trackId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'trackId', value: [trackId]),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterWhereClause>
  trackIdNotEqualTo(String trackId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'trackId',
                lower: [],
                upper: [trackId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'trackId',
                lower: [trackId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'trackId',
                lower: [trackId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'trackId',
                lower: [],
                upper: [trackId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension FavoriteAudioQueryFilter
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QFilterCondition> {
  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'audioSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'audioSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'audioSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'audioSource',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'audioSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'audioSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'audioSource',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'audioSource',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'audioSource', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  audioSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'audioSource', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  favoritedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'favoritedAt', value: value),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  favoritedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'favoritedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  favoritedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'favoritedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  favoritedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'favoritedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'localFilePath'),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'localFilePath'),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'localFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'localFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'localFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'localFilePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'localFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'localFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'localFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'localFilePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'localFilePath', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  localFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'localFilePath', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'spotifyUri'),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'spotifyUri'),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'spotifyUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'spotifyUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'spotifyUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'spotifyUri',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'spotifyUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'spotifyUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'spotifyUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'spotifyUri',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'spotifyUri', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  spotifyUriIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'spotifyUri', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'subtitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'subtitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'subtitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'subtitle',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'subtitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'subtitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'subtitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'subtitle',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'subtitle', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  subtitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'subtitle', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'trackId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'trackId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trackId', value: ''),
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterFilterCondition>
  trackIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'trackId', value: ''),
      );
    });
  }
}

extension FavoriteAudioQueryObject
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QFilterCondition> {}

extension FavoriteAudioQueryLinks
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QFilterCondition> {}

extension FavoriteAudioQuerySortBy
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QSortBy> {
  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> sortByAudioSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioSource', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  sortByAudioSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioSource', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> sortByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favoritedAt', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  sortByFavoritedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favoritedAt', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  sortByLocalFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  sortByLocalFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> sortBySpotifyUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spotifyUri', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  sortBySpotifyUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spotifyUri', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> sortBySubtitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtitle', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  sortBySubtitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtitle', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> sortByTrackId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackId', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> sortByTrackIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackId', Sort.desc);
    });
  }
}

extension FavoriteAudioQuerySortThenBy
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QSortThenBy> {
  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenByAudioSource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioSource', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  thenByAudioSourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioSource', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favoritedAt', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  thenByFavoritedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'favoritedAt', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  thenByLocalFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  thenByLocalFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localFilePath', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenBySpotifyUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spotifyUri', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  thenBySpotifyUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spotifyUri', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenBySubtitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtitle', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy>
  thenBySubtitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'subtitle', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenByTrackId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackId', Sort.asc);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QAfterSortBy> thenByTrackIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackId', Sort.desc);
    });
  }
}

extension FavoriteAudioQueryWhereDistinct
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QDistinct> {
  QueryBuilder<FavoriteAudio, FavoriteAudio, QDistinct> distinctByAudioSource({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioSource', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QDistinct>
  distinctByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'favoritedAt');
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QDistinct>
  distinctByLocalFilePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'localFilePath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QDistinct> distinctBySpotifyUri({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'spotifyUri', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QDistinct> distinctBySubtitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'subtitle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<FavoriteAudio, FavoriteAudio, QDistinct> distinctByTrackId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trackId', caseSensitive: caseSensitive);
    });
  }
}

extension FavoriteAudioQueryProperty
    on QueryBuilder<FavoriteAudio, FavoriteAudio, QQueryProperty> {
  QueryBuilder<FavoriteAudio, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<FavoriteAudio, String, QQueryOperations> audioSourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioSource');
    });
  }

  QueryBuilder<FavoriteAudio, DateTime, QQueryOperations>
  favoritedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'favoritedAt');
    });
  }

  QueryBuilder<FavoriteAudio, String?, QQueryOperations>
  localFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localFilePath');
    });
  }

  QueryBuilder<FavoriteAudio, String?, QQueryOperations> spotifyUriProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'spotifyUri');
    });
  }

  QueryBuilder<FavoriteAudio, String, QQueryOperations> subtitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'subtitle');
    });
  }

  QueryBuilder<FavoriteAudio, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<FavoriteAudio, String, QQueryOperations> trackIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trackId');
    });
  }
}
