// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_food.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetOfflineFoodCollection on Isar {
  IsarCollection<OfflineFood> get offlineFoods => this.collection();
}

const OfflineFoodSchema = CollectionSchema(
  name: r'OfflineFood',
  id: 2990764732878324007,
  properties: {
    r'calories': PropertySchema(
      id: 0,
      name: r'calories',
      type: IsarType.double,
    ),
    r'carbsG': PropertySchema(id: 1, name: r'carbsG', type: IsarType.double),
    r'fatG': PropertySchema(id: 2, name: r'fatG', type: IsarType.double),
    r'fiberG': PropertySchema(id: 3, name: r'fiberG', type: IsarType.double),
    r'name': PropertySchema(id: 4, name: r'name', type: IsarType.string),
    r'proteinG': PropertySchema(
      id: 5,
      name: r'proteinG',
      type: IsarType.double,
    ),
    r'servingSize': PropertySchema(
      id: 6,
      name: r'servingSize',
      type: IsarType.string,
    ),
    r'sodiumMg': PropertySchema(
      id: 7,
      name: r'sodiumMg',
      type: IsarType.double,
    ),
    r'sugarG': PropertySchema(id: 8, name: r'sugarG', type: IsarType.double),
  },

  estimateSize: _offlineFoodEstimateSize,
  serialize: _offlineFoodSerialize,
  deserialize: _offlineFoodDeserialize,
  deserializeProp: _offlineFoodDeserializeProp,
  idName: r'id',
  indexes: {
    r'name': IndexSchema(
      id: 879695947855722453,
      name: r'name',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'name',
          type: IndexType.value,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _offlineFoodGetId,
  getLinks: _offlineFoodGetLinks,
  attach: _offlineFoodAttach,
  version: '3.3.2',
);

int _offlineFoodEstimateSize(
  OfflineFood object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.servingSize.length * 3;
  return bytesCount;
}

void _offlineFoodSerialize(
  OfflineFood object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.calories);
  writer.writeDouble(offsets[1], object.carbsG);
  writer.writeDouble(offsets[2], object.fatG);
  writer.writeDouble(offsets[3], object.fiberG);
  writer.writeString(offsets[4], object.name);
  writer.writeDouble(offsets[5], object.proteinG);
  writer.writeString(offsets[6], object.servingSize);
  writer.writeDouble(offsets[7], object.sodiumMg);
  writer.writeDouble(offsets[8], object.sugarG);
}

OfflineFood _offlineFoodDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = OfflineFood();
  object.calories = reader.readDouble(offsets[0]);
  object.carbsG = reader.readDouble(offsets[1]);
  object.fatG = reader.readDouble(offsets[2]);
  object.fiberG = reader.readDouble(offsets[3]);
  object.id = id;
  object.name = reader.readString(offsets[4]);
  object.proteinG = reader.readDouble(offsets[5]);
  object.servingSize = reader.readString(offsets[6]);
  object.sodiumMg = reader.readDouble(offsets[7]);
  object.sugarG = reader.readDouble(offsets[8]);
  return object;
}

P _offlineFoodDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDouble(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _offlineFoodGetId(OfflineFood object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _offlineFoodGetLinks(OfflineFood object) {
  return [];
}

void _offlineFoodAttach(
  IsarCollection<dynamic> col,
  Id id,
  OfflineFood object,
) {
  object.id = id;
}

extension OfflineFoodQueryWhereSort
    on QueryBuilder<OfflineFood, OfflineFood, QWhere> {
  QueryBuilder<OfflineFood, OfflineFood, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhere> anyName() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'name'),
      );
    });
  }
}

extension OfflineFoodQueryWhere
    on QueryBuilder<OfflineFood, OfflineFood, QWhereClause> {
  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> idBetween(
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

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> nameEqualTo(
    String name,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'name', value: [name]),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> nameNotEqualTo(
    String name,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [],
                upper: [name],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [name],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [name],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [],
                upper: [name],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> nameGreaterThan(
    String name, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'name',
          lower: [name],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> nameLessThan(
    String name, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'name',
          lower: [],
          upper: [name],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> nameBetween(
    String lowerName,
    String upperName, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'name',
          lower: [lowerName],
          includeLower: includeLower,
          upper: [upperName],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> nameStartsWith(
    String NamePrefix,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'name',
          lower: [NamePrefix],
          upper: ['$NamePrefix\u{FFFFF}'],
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'name', value: ['']),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterWhereClause> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'name', upper: ['']),
            )
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'name', lower: ['']),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.greaterThan(indexName: r'name', lower: ['']),
            )
            .addWhereClause(
              IndexWhereClause.lessThan(indexName: r'name', upper: ['']),
            );
      }
    });
  }
}

extension OfflineFoodQueryFilter
    on QueryBuilder<OfflineFood, OfflineFood, QFilterCondition> {
  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> caloriesEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'calories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  caloriesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'calories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  caloriesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'calories',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> caloriesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'calories',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> carbsGEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'carbsG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  carbsGGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'carbsG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> carbsGLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'carbsG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> carbsGBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'carbsG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> fatGEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fatG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> fatGGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fatG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> fatGLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fatG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> fatGBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fatG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> fiberGEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fiberG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  fiberGGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fiberG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> fiberGLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fiberG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> fiberGBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fiberG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> idBetween(
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

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> proteinGEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'proteinG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  proteinGGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'proteinG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  proteinGLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'proteinG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> proteinGBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'proteinG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'servingSize',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'servingSize',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'servingSize',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'servingSize',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'servingSize',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'servingSize',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'servingSize',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'servingSize',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'servingSize', value: ''),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  servingSizeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'servingSize', value: ''),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> sodiumMgEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sodiumMg',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  sodiumMgGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sodiumMg',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  sodiumMgLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sodiumMg',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> sodiumMgBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sodiumMg',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> sugarGEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'sugarG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition>
  sugarGGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sugarG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> sugarGLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sugarG',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterFilterCondition> sugarGBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sugarG',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }
}

extension OfflineFoodQueryObject
    on QueryBuilder<OfflineFood, OfflineFood, QFilterCondition> {}

extension OfflineFoodQueryLinks
    on QueryBuilder<OfflineFood, OfflineFood, QFilterCondition> {}

extension OfflineFoodQuerySortBy
    on QueryBuilder<OfflineFood, OfflineFood, QSortBy> {
  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calories', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calories', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByCarbsG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbsG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByCarbsGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbsG', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByFatG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByFatGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatG', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByFiberG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fiberG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByFiberGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fiberG', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByProteinG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByProteinGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinG', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByServingSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingSize', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortByServingSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingSize', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortBySodiumMg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sodiumMg', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortBySodiumMgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sodiumMg', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortBySugarG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sugarG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> sortBySugarGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sugarG', Sort.desc);
    });
  }
}

extension OfflineFoodQuerySortThenBy
    on QueryBuilder<OfflineFood, OfflineFood, QSortThenBy> {
  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calories', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'calories', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByCarbsG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbsG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByCarbsGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'carbsG', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByFatG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByFatGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fatG', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByFiberG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fiberG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByFiberGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fiberG', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByProteinG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByProteinGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proteinG', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByServingSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingSize', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenByServingSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'servingSize', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenBySodiumMg() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sodiumMg', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenBySodiumMgDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sodiumMg', Sort.desc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenBySugarG() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sugarG', Sort.asc);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QAfterSortBy> thenBySugarGDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sugarG', Sort.desc);
    });
  }
}

extension OfflineFoodQueryWhereDistinct
    on QueryBuilder<OfflineFood, OfflineFood, QDistinct> {
  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctByCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'calories');
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctByCarbsG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'carbsG');
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctByFatG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fatG');
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctByFiberG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fiberG');
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctByProteinG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proteinG');
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctByServingSize({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'servingSize', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctBySodiumMg() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sodiumMg');
    });
  }

  QueryBuilder<OfflineFood, OfflineFood, QDistinct> distinctBySugarG() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sugarG');
    });
  }
}

extension OfflineFoodQueryProperty
    on QueryBuilder<OfflineFood, OfflineFood, QQueryProperty> {
  QueryBuilder<OfflineFood, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<OfflineFood, double, QQueryOperations> caloriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'calories');
    });
  }

  QueryBuilder<OfflineFood, double, QQueryOperations> carbsGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'carbsG');
    });
  }

  QueryBuilder<OfflineFood, double, QQueryOperations> fatGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fatG');
    });
  }

  QueryBuilder<OfflineFood, double, QQueryOperations> fiberGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fiberG');
    });
  }

  QueryBuilder<OfflineFood, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<OfflineFood, double, QQueryOperations> proteinGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proteinG');
    });
  }

  QueryBuilder<OfflineFood, String, QQueryOperations> servingSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'servingSize');
    });
  }

  QueryBuilder<OfflineFood, double, QQueryOperations> sodiumMgProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sodiumMg');
    });
  }

  QueryBuilder<OfflineFood, double, QQueryOperations> sugarGProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sugarG');
    });
  }
}
