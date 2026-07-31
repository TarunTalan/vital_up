// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_log_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMealLogCacheCollection on Isar {
  IsarCollection<MealLogCache> get mealLogCaches => this.collection();
}

const MealLogCacheSchema = CollectionSchema(
  name: r'MealLogCache',
  id: 7704444788216307460,
  properties: {
    r'capturedAt': PropertySchema(
      id: 0,
      name: r'capturedAt',
      type: IsarType.dateTime,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'imagePath': PropertySchema(
      id: 2,
      name: r'imagePath',
      type: IsarType.string,
    ),
    r'itemConfidences': PropertySchema(
      id: 3,
      name: r'itemConfidences',
      type: IsarType.doubleList,
    ),
    r'itemIds': PropertySchema(
      id: 4,
      name: r'itemIds',
      type: IsarType.stringList,
    ),
    r'itemNames': PropertySchema(
      id: 5,
      name: r'itemNames',
      type: IsarType.stringList,
    ),
    r'itemQuantities': PropertySchema(
      id: 6,
      name: r'itemQuantities',
      type: IsarType.doubleList,
    ),
    r'itemServingDescriptions': PropertySchema(
      id: 7,
      name: r'itemServingDescriptions',
      type: IsarType.stringList,
    ),
    r'itemUnits': PropertySchema(
      id: 8,
      name: r'itemUnits',
      type: IsarType.stringList,
    ),
    r'mealLogId': PropertySchema(
      id: 9,
      name: r'mealLogId',
      type: IsarType.string,
    ),
    r'mealType': PropertySchema(id: 10, name: r'mealType', type: IsarType.long),
    r'nutritionCalories': PropertySchema(
      id: 11,
      name: r'nutritionCalories',
      type: IsarType.doubleList,
    ),
    r'nutritionCarbsG': PropertySchema(
      id: 12,
      name: r'nutritionCarbsG',
      type: IsarType.doubleList,
    ),
    r'nutritionFatG': PropertySchema(
      id: 13,
      name: r'nutritionFatG',
      type: IsarType.doubleList,
    ),
    r'nutritionFiberG': PropertySchema(
      id: 14,
      name: r'nutritionFiberG',
      type: IsarType.doubleList,
    ),
    r'nutritionProteinG': PropertySchema(
      id: 15,
      name: r'nutritionProteinG',
      type: IsarType.doubleList,
    ),
    r'nutritionSodiumMg': PropertySchema(
      id: 16,
      name: r'nutritionSodiumMg',
      type: IsarType.doubleList,
    ),
    r'nutritionSugarG': PropertySchema(
      id: 17,
      name: r'nutritionSugarG',
      type: IsarType.doubleList,
    ),
    r'totalCalories': PropertySchema(
      id: 18,
      name: r'totalCalories',
      type: IsarType.double,
    ),
    r'userConfirmed': PropertySchema(
      id: 19,
      name: r'userConfirmed',
      type: IsarType.bool,
    ),
  },

  estimateSize: _mealLogCacheEstimateSize,
  serialize: _mealLogCacheSerialize,
  deserialize: _mealLogCacheDeserialize,
  deserializeProp: _mealLogCacheDeserializeProp,
  idName: r'id',
  indexes: {
    r'mealLogId': IndexSchema(
      id: 2117357569295848037,
      name: r'mealLogId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'mealLogId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'capturedAt': IndexSchema(
      id: 7947551681198035194,
      name: r'capturedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'capturedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'mealType': IndexSchema(
      id: -959027890258449294,
      name: r'mealType',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'mealType',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _mealLogCacheGetId,
  getLinks: _mealLogCacheGetLinks,
  attach: _mealLogCacheAttach,
  version: '3.3.2',
);

int _mealLogCacheEstimateSize(
  MealLogCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.imagePath.length * 3;
  bytesCount += 3 + object.itemConfidences.length * 8;
  bytesCount += 3 + object.itemIds.length * 3;
  {
    for (var i = 0; i < object.itemIds.length; i++) {
      final value = object.itemIds[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.itemNames.length * 3;
  {
    for (var i = 0; i < object.itemNames.length; i++) {
      final value = object.itemNames[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.itemQuantities.length * 8;
  bytesCount += 3 + object.itemServingDescriptions.length * 3;
  {
    for (var i = 0; i < object.itemServingDescriptions.length; i++) {
      final value = object.itemServingDescriptions[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.itemUnits.length * 3;
  {
    for (var i = 0; i < object.itemUnits.length; i++) {
      final value = object.itemUnits[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.mealLogId.length * 3;
  bytesCount += 3 + object.nutritionCalories.length * 8;
  bytesCount += 3 + object.nutritionCarbsG.length * 8;
  bytesCount += 3 + object.nutritionFatG.length * 8;
  bytesCount += 3 + object.nutritionFiberG.length * 8;
  bytesCount += 3 + object.nutritionProteinG.length * 8;
  bytesCount += 3 + object.nutritionSodiumMg.length * 8;
  bytesCount += 3 + object.nutritionSugarG.length * 8;
  return bytesCount;
}

void _mealLogCacheSerialize(
  MealLogCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.capturedAt);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.imagePath);
  writer.writeDoubleList(offsets[3], object.itemConfidences);
  writer.writeStringList(offsets[4], object.itemIds);
  writer.writeStringList(offsets[5], object.itemNames);
  writer.writeDoubleList(offsets[6], object.itemQuantities);
  writer.writeStringList(offsets[7], object.itemServingDescriptions);
  writer.writeStringList(offsets[8], object.itemUnits);
  writer.writeString(offsets[9], object.mealLogId);
  writer.writeLong(offsets[10], object.mealType);
  writer.writeDoubleList(offsets[11], object.nutritionCalories);
  writer.writeDoubleList(offsets[12], object.nutritionCarbsG);
  writer.writeDoubleList(offsets[13], object.nutritionFatG);
  writer.writeDoubleList(offsets[14], object.nutritionFiberG);
  writer.writeDoubleList(offsets[15], object.nutritionProteinG);
  writer.writeDoubleList(offsets[16], object.nutritionSodiumMg);
  writer.writeDoubleList(offsets[17], object.nutritionSugarG);
  writer.writeDouble(offsets[18], object.totalCalories);
  writer.writeBool(offsets[19], object.userConfirmed);
}

MealLogCache _mealLogCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MealLogCache();
  object.capturedAt = reader.readDateTime(offsets[0]);
  object.createdAt = reader.readDateTimeOrNull(offsets[1]);
  object.id = id;
  object.imagePath = reader.readString(offsets[2]);
  object.itemConfidences = reader.readDoubleList(offsets[3]) ?? [];
  object.itemIds = reader.readStringList(offsets[4]) ?? [];
  object.itemNames = reader.readStringList(offsets[5]) ?? [];
  object.itemQuantities = reader.readDoubleList(offsets[6]) ?? [];
  object.itemServingDescriptions = reader.readStringList(offsets[7]) ?? [];
  object.itemUnits = reader.readStringList(offsets[8]) ?? [];
  object.mealLogId = reader.readString(offsets[9]);
  object.mealType = reader.readLong(offsets[10]);
  object.nutritionCalories = reader.readDoubleList(offsets[11]) ?? [];
  object.nutritionCarbsG = reader.readDoubleList(offsets[12]) ?? [];
  object.nutritionFatG = reader.readDoubleList(offsets[13]) ?? [];
  object.nutritionFiberG = reader.readDoubleList(offsets[14]) ?? [];
  object.nutritionProteinG = reader.readDoubleList(offsets[15]) ?? [];
  object.nutritionSodiumMg = reader.readDoubleList(offsets[16]) ?? [];
  object.nutritionSugarG = reader.readDoubleList(offsets[17]) ?? [];
  object.totalCalories = reader.readDouble(offsets[18]);
  object.userConfirmed = reader.readBool(offsets[19]);
  return object;
}

P _mealLogCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 4:
      return (reader.readStringList(offset) ?? []) as P;
    case 5:
      return (reader.readStringList(offset) ?? []) as P;
    case 6:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 7:
      return (reader.readStringList(offset) ?? []) as P;
    case 8:
      return (reader.readStringList(offset) ?? []) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 12:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 13:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 14:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 15:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 16:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 17:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 18:
      return (reader.readDouble(offset)) as P;
    case 19:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mealLogCacheGetId(MealLogCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mealLogCacheGetLinks(MealLogCache object) {
  return [];
}

void _mealLogCacheAttach(
  IsarCollection<dynamic> col,
  Id id,
  MealLogCache object,
) {
  object.id = id;
}

extension MealLogCacheQueryWhereSort
    on QueryBuilder<MealLogCache, MealLogCache, QWhere> {
  QueryBuilder<MealLogCache, MealLogCache, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhere> anyCapturedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'capturedAt'),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhere> anyMealType() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'mealType'),
      );
    });
  }
}

extension MealLogCacheQueryWhere
    on QueryBuilder<MealLogCache, MealLogCache, QWhereClause> {
  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> idBetween(
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

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> mealLogIdEqualTo(
    String mealLogId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'mealLogId', value: [mealLogId]),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause>
  mealLogIdNotEqualTo(String mealLogId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mealLogId',
                lower: [],
                upper: [mealLogId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mealLogId',
                lower: [mealLogId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mealLogId',
                lower: [mealLogId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mealLogId',
                lower: [],
                upper: [mealLogId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> capturedAtEqualTo(
    DateTime capturedAt,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'capturedAt', value: [capturedAt]),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause>
  capturedAtNotEqualTo(DateTime capturedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'capturedAt',
                lower: [],
                upper: [capturedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'capturedAt',
                lower: [capturedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'capturedAt',
                lower: [capturedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'capturedAt',
                lower: [],
                upper: [capturedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause>
  capturedAtGreaterThan(DateTime capturedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'capturedAt',
          lower: [capturedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause>
  capturedAtLessThan(DateTime capturedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'capturedAt',
          lower: [],
          upper: [capturedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> capturedAtBetween(
    DateTime lowerCapturedAt,
    DateTime upperCapturedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'capturedAt',
          lower: [lowerCapturedAt],
          includeLower: includeLower,
          upper: [upperCapturedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> mealTypeEqualTo(
    int mealType,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'mealType', value: [mealType]),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause>
  mealTypeNotEqualTo(int mealType) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mealType',
                lower: [],
                upper: [mealType],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mealType',
                lower: [mealType],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mealType',
                lower: [mealType],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mealType',
                lower: [],
                upper: [mealType],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause>
  mealTypeGreaterThan(int mealType, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mealType',
          lower: [mealType],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> mealTypeLessThan(
    int mealType, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mealType',
          lower: [],
          upper: [mealType],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterWhereClause> mealTypeBetween(
    int lowerMealType,
    int upperMealType, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mealType',
          lower: [lowerMealType],
          includeLower: includeLower,
          upper: [upperMealType],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MealLogCacheQueryFilter
    on QueryBuilder<MealLogCache, MealLogCache, QFilterCondition> {
  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  capturedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'capturedAt', value: value),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  capturedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'capturedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  capturedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'capturedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  capturedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'capturedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'createdAt'),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  createdAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  createdAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
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

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition> idBetween(
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

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'imagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'imagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'imagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'imagePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'imagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'imagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'imagePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'imagePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'imagePath', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  imagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'imagePath', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemConfidences',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemConfidences',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemConfidences',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemConfidences',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemConfidences', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemConfidences', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemConfidences', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemConfidences', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemConfidences',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemConfidencesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemConfidences',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemIds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'itemIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'itemIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'itemIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'itemIds',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'itemIds', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'itemIds', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemIds', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemIds', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemIds', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemIds', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemIds', length, include, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemNames',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemNames',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemNames',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemNames',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'itemNames',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'itemNames',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'itemNames',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'itemNames',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'itemNames', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'itemNames', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemNames', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemNames', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemNames', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemNames', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemNames', length, include, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemNamesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemNames',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesElementEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemQuantities',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemQuantities',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemQuantities',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemQuantities',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemQuantities', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemQuantities', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemQuantities', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemQuantities', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemQuantities', length, include, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemQuantitiesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemQuantities',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemServingDescriptions',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemServingDescriptions',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemServingDescriptions',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemServingDescriptions',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'itemServingDescriptions',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'itemServingDescriptions',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'itemServingDescriptions',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'itemServingDescriptions',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemServingDescriptions',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'itemServingDescriptions',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemServingDescriptions',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemServingDescriptions', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemServingDescriptions',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemServingDescriptions',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemServingDescriptions',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemServingDescriptionsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemServingDescriptions',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'itemUnits',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'itemUnits',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'itemUnits',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'itemUnits',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'itemUnits',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'itemUnits',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'itemUnits',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'itemUnits',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'itemUnits', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'itemUnits', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemUnits', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemUnits', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemUnits', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemUnits', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'itemUnits', length, include, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  itemUnitsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'itemUnits',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'mealLogId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mealLogId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mealLogId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mealLogId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'mealLogId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'mealLogId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'mealLogId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'mealLogId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mealLogId', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealLogIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'mealLogId', value: ''),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealTypeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mealType', value: value),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealTypeGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mealType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealTypeLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mealType',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  mealTypeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mealType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nutritionCalories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nutritionCalories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nutritionCalories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nutritionCalories',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionCalories', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionCalories', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionCalories', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionCalories', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionCalories',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCaloriesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionCalories',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nutritionCarbsG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nutritionCarbsG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nutritionCarbsG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nutritionCarbsG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionCarbsG', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionCarbsG', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionCarbsG', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionCarbsG', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionCarbsG',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionCarbsGLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionCarbsG',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGElementEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nutritionFatG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nutritionFatG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nutritionFatG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nutritionFatG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFatG', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFatG', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFatG', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFatG', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFatG', length, include, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFatGLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionFatG',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nutritionFiberG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nutritionFiberG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nutritionFiberG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nutritionFiberG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFiberG', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFiberG', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFiberG', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionFiberG', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionFiberG',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionFiberGLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionFiberG',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nutritionProteinG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nutritionProteinG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nutritionProteinG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nutritionProteinG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionProteinG', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionProteinG', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionProteinG', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionProteinG', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionProteinG',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionProteinGLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionProteinG',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nutritionSodiumMg',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nutritionSodiumMg',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nutritionSodiumMg',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nutritionSodiumMg',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionSodiumMg', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionSodiumMg', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionSodiumMg', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionSodiumMg', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionSodiumMg',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSodiumMgLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionSodiumMg',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'nutritionSugarG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'nutritionSugarG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'nutritionSugarG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'nutritionSugarG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionSugarG', length, true, length, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionSugarG', 0, true, 0, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionSugarG', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'nutritionSugarG', 0, true, length, include);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionSugarG',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  nutritionSugarGLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'nutritionSugarG',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  totalCaloriesEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'totalCalories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  totalCaloriesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalCalories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  totalCaloriesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalCalories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  totalCaloriesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalCalories',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterFilterCondition>
  userConfirmedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'userConfirmed', value: value),
      );
    });
  }
}

extension MealLogCacheQueryObject
    on QueryBuilder<MealLogCache, MealLogCache, QFilterCondition> {}

extension MealLogCacheQueryLinks
    on QueryBuilder<MealLogCache, MealLogCache, QFilterCondition> {}

extension MealLogCacheQuerySortBy
    on QueryBuilder<MealLogCache, MealLogCache, QSortBy> {
  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByCapturedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capturedAt', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy>
  sortByCapturedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capturedAt', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByMealLogId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealLogId', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByMealLogIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealLogId', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByMealType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealType', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByMealTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealType', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy>
  sortByTotalCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> sortByUserConfirmed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userConfirmed', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy>
  sortByUserConfirmedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userConfirmed', Sort.desc);
    });
  }
}

extension MealLogCacheQuerySortThenBy
    on QueryBuilder<MealLogCache, MealLogCache, QSortThenBy> {
  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByCapturedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capturedAt', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy>
  thenByCapturedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'capturedAt', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByMealLogId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealLogId', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByMealLogIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealLogId', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByMealType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealType', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByMealTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mealType', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy>
  thenByTotalCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.desc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy> thenByUserConfirmed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userConfirmed', Sort.asc);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QAfterSortBy>
  thenByUserConfirmedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userConfirmed', Sort.desc);
    });
  }
}

extension MealLogCacheQueryWhereDistinct
    on QueryBuilder<MealLogCache, MealLogCache, QDistinct> {
  QueryBuilder<MealLogCache, MealLogCache, QDistinct> distinctByCapturedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'capturedAt');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct> distinctByImagePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imagePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByItemConfidences() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemConfidences');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct> distinctByItemIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemIds');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct> distinctByItemNames() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemNames');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByItemQuantities() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemQuantities');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByItemServingDescriptions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemServingDescriptions');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct> distinctByItemUnits() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemUnits');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct> distinctByMealLogId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mealLogId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct> distinctByMealType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'mealType');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByNutritionCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nutritionCalories');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByNutritionCarbsG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nutritionCarbsG');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByNutritionFatG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nutritionFatG');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByNutritionFiberG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nutritionFiberG');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByNutritionProteinG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nutritionProteinG');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByNutritionSodiumMg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nutritionSodiumMg');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByNutritionSugarG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nutritionSugarG');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalCalories');
    });
  }

  QueryBuilder<MealLogCache, MealLogCache, QDistinct>
  distinctByUserConfirmed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userConfirmed');
    });
  }
}

extension MealLogCacheQueryProperty
    on QueryBuilder<MealLogCache, MealLogCache, QQueryProperty> {
  QueryBuilder<MealLogCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MealLogCache, DateTime, QQueryOperations> capturedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'capturedAt');
    });
  }

  QueryBuilder<MealLogCache, DateTime?, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<MealLogCache, String, QQueryOperations> imagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imagePath');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  itemConfidencesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemConfidences');
    });
  }

  QueryBuilder<MealLogCache, List<String>, QQueryOperations> itemIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemIds');
    });
  }

  QueryBuilder<MealLogCache, List<String>, QQueryOperations>
  itemNamesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemNames');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  itemQuantitiesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemQuantities');
    });
  }

  QueryBuilder<MealLogCache, List<String>, QQueryOperations>
  itemServingDescriptionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemServingDescriptions');
    });
  }

  QueryBuilder<MealLogCache, List<String>, QQueryOperations>
  itemUnitsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemUnits');
    });
  }

  QueryBuilder<MealLogCache, String, QQueryOperations> mealLogIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mealLogId');
    });
  }

  QueryBuilder<MealLogCache, int, QQueryOperations> mealTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mealType');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  nutritionCaloriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nutritionCalories');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  nutritionCarbsGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nutritionCarbsG');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  nutritionFatGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nutritionFatG');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  nutritionFiberGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nutritionFiberG');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  nutritionProteinGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nutritionProteinG');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  nutritionSodiumMgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nutritionSodiumMg');
    });
  }

  QueryBuilder<MealLogCache, List<double>, QQueryOperations>
  nutritionSugarGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nutritionSugarG');
    });
  }

  QueryBuilder<MealLogCache, double, QQueryOperations> totalCaloriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalCalories');
    });
  }

  QueryBuilder<MealLogCache, bool, QQueryOperations> userConfirmedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userConfirmed');
    });
  }
}
