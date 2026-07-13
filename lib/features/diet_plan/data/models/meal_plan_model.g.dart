// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_plan_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMealPlanModelCollection on Isar {
  IsarCollection<MealPlanModel> get mealPlanModels => this.collection();
}

const MealPlanModelSchema = CollectionSchema(
  name: r'MealPlanModel',
  id: -4039970539743865760,
  properties: {
    r'dateKey': PropertySchema(id: 0, name: r'dateKey', type: IsarType.string),
    r'meals': PropertySchema(
      id: 1,
      name: r'meals',
      type: IsarType.objectList,

      target: r'MealModel',
    ),
    r'totalCalories': PropertySchema(
      id: 2,
      name: r'totalCalories',
      type: IsarType.long,
    ),
    r'totalCarbs': PropertySchema(
      id: 3,
      name: r'totalCarbs',
      type: IsarType.long,
    ),
    r'totalFat': PropertySchema(id: 4, name: r'totalFat', type: IsarType.long),
    r'totalProtein': PropertySchema(
      id: 5,
      name: r'totalProtein',
      type: IsarType.long,
    ),
  },

  estimateSize: _mealPlanModelEstimateSize,
  serialize: _mealPlanModelSerialize,
  deserialize: _mealPlanModelDeserialize,
  deserializeProp: _mealPlanModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'dateKey': IndexSchema(
      id: 7975223786082927131,
      name: r'dateKey',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'dateKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {r'MealModel': MealModelSchema},

  getId: _mealPlanModelGetId,
  getLinks: _mealPlanModelGetLinks,
  attach: _mealPlanModelAttach,
  version: '3.3.2',
);

int _mealPlanModelEstimateSize(
  MealPlanModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.dateKey.length * 3;
  {
    final list = object.meals;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        final offsets = allOffsets[MealModel]!;
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount += MealModelSchema.estimateSize(
            value,
            offsets,
            allOffsets,
          );
        }
      }
    }
  }
  return bytesCount;
}

void _mealPlanModelSerialize(
  MealPlanModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.dateKey);
  writer.writeObjectList<MealModel>(
    offsets[1],
    allOffsets,
    MealModelSchema.serialize,
    object.meals,
  );
  writer.writeLong(offsets[2], object.totalCalories);
  writer.writeLong(offsets[3], object.totalCarbs);
  writer.writeLong(offsets[4], object.totalFat);
  writer.writeLong(offsets[5], object.totalProtein);
}

MealPlanModel _mealPlanModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MealPlanModel();
  object.dateKey = reader.readString(offsets[0]);
  object.id = id;
  object.meals = reader.readObjectList<MealModel>(
    offsets[1],
    MealModelSchema.deserialize,
    allOffsets,
    MealModel(),
  );
  object.totalCalories = reader.readLongOrNull(offsets[2]);
  object.totalCarbs = reader.readLongOrNull(offsets[3]);
  object.totalFat = reader.readLongOrNull(offsets[4]);
  object.totalProtein = reader.readLongOrNull(offsets[5]);
  return object;
}

P _mealPlanModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readObjectList<MealModel>(
            offset,
            MealModelSchema.deserialize,
            allOffsets,
            MealModel(),
          ))
          as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _mealPlanModelGetId(MealPlanModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _mealPlanModelGetLinks(MealPlanModel object) {
  return [];
}

void _mealPlanModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  MealPlanModel object,
) {
  object.id = id;
}

extension MealPlanModelByIndex on IsarCollection<MealPlanModel> {
  Future<MealPlanModel?> getByDateKey(String dateKey) {
    return getByIndex(r'dateKey', [dateKey]);
  }

  MealPlanModel? getByDateKeySync(String dateKey) {
    return getByIndexSync(r'dateKey', [dateKey]);
  }

  Future<bool> deleteByDateKey(String dateKey) {
    return deleteByIndex(r'dateKey', [dateKey]);
  }

  bool deleteByDateKeySync(String dateKey) {
    return deleteByIndexSync(r'dateKey', [dateKey]);
  }

  Future<List<MealPlanModel?>> getAllByDateKey(List<String> dateKeyValues) {
    final values = dateKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'dateKey', values);
  }

  List<MealPlanModel?> getAllByDateKeySync(List<String> dateKeyValues) {
    final values = dateKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'dateKey', values);
  }

  Future<int> deleteAllByDateKey(List<String> dateKeyValues) {
    final values = dateKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'dateKey', values);
  }

  int deleteAllByDateKeySync(List<String> dateKeyValues) {
    final values = dateKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'dateKey', values);
  }

  Future<Id> putByDateKey(MealPlanModel object) {
    return putByIndex(r'dateKey', object);
  }

  Id putByDateKeySync(MealPlanModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'dateKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDateKey(List<MealPlanModel> objects) {
    return putAllByIndex(r'dateKey', objects);
  }

  List<Id> putAllByDateKeySync(
    List<MealPlanModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'dateKey', objects, saveLinks: saveLinks);
  }
}

extension MealPlanModelQueryWhereSort
    on QueryBuilder<MealPlanModel, MealPlanModel, QWhere> {
  QueryBuilder<MealPlanModel, MealPlanModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MealPlanModelQueryWhere
    on QueryBuilder<MealPlanModel, MealPlanModel, QWhereClause> {
  QueryBuilder<MealPlanModel, MealPlanModel, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterWhereClause> idBetween(
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

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterWhereClause> dateKeyEqualTo(
    String dateKey,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'dateKey', value: [dateKey]),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterWhereClause>
  dateKeyNotEqualTo(String dateKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dateKey',
                lower: [],
                upper: [dateKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dateKey',
                lower: [dateKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dateKey',
                lower: [dateKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dateKey',
                lower: [],
                upper: [dateKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension MealPlanModelQueryFilter
    on QueryBuilder<MealPlanModel, MealPlanModel, QFilterCondition> {
  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dateKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'dateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'dateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'dateKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'dateKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dateKey', value: ''),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  dateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'dateKey', value: ''),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
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

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition> idBetween(
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

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'meals'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'meals'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'meals', length, true, length, true);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'meals', 0, true, 0, true);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'meals', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'meals', 0, true, length, include);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'meals', length, include, 999999, true);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'meals',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCaloriesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'totalCalories'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCaloriesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'totalCalories'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCaloriesEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'totalCalories', value: value),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCaloriesGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalCalories',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCaloriesLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalCalories',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCaloriesBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalCalories',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCarbsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'totalCarbs'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCarbsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'totalCarbs'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCarbsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'totalCarbs', value: value),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCarbsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalCarbs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCarbsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalCarbs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalCarbsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalCarbs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalFatIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'totalFat'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalFatIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'totalFat'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalFatEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'totalFat', value: value),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalFatGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalFat',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalFatLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalFat',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalFatBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalFat',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalProteinIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'totalProtein'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalProteinIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'totalProtein'),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalProteinEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'totalProtein', value: value),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalProteinGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalProtein',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalProteinLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalProtein',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  totalProteinBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalProtein',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MealPlanModelQueryObject
    on QueryBuilder<MealPlanModel, MealPlanModel, QFilterCondition> {
  QueryBuilder<MealPlanModel, MealPlanModel, QAfterFilterCondition>
  mealsElement(FilterQuery<MealModel> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'meals');
    });
  }
}

extension MealPlanModelQueryLinks
    on QueryBuilder<MealPlanModel, MealPlanModel, QFilterCondition> {}

extension MealPlanModelQuerySortBy
    on QueryBuilder<MealPlanModel, MealPlanModel, QSortBy> {
  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> sortByDateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> sortByDateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  sortByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  sortByTotalCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> sortByTotalCarbs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCarbs', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  sortByTotalCarbsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCarbs', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> sortByTotalFat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalFat', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  sortByTotalFatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalFat', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  sortByTotalProtein() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalProtein', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  sortByTotalProteinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalProtein', Sort.desc);
    });
  }
}

extension MealPlanModelQuerySortThenBy
    on QueryBuilder<MealPlanModel, MealPlanModel, QSortThenBy> {
  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> thenByDateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> thenByDateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  thenByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  thenByTotalCaloriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCalories', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> thenByTotalCarbs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCarbs', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  thenByTotalCarbsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalCarbs', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy> thenByTotalFat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalFat', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  thenByTotalFatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalFat', Sort.desc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  thenByTotalProtein() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalProtein', Sort.asc);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QAfterSortBy>
  thenByTotalProteinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalProtein', Sort.desc);
    });
  }
}

extension MealPlanModelQueryWhereDistinct
    on QueryBuilder<MealPlanModel, MealPlanModel, QDistinct> {
  QueryBuilder<MealPlanModel, MealPlanModel, QDistinct> distinctByDateKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dateKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QDistinct>
  distinctByTotalCalories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalCalories');
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QDistinct> distinctByTotalCarbs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalCarbs');
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QDistinct> distinctByTotalFat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalFat');
    });
  }

  QueryBuilder<MealPlanModel, MealPlanModel, QDistinct>
  distinctByTotalProtein() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalProtein');
    });
  }
}

extension MealPlanModelQueryProperty
    on QueryBuilder<MealPlanModel, MealPlanModel, QQueryProperty> {
  QueryBuilder<MealPlanModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MealPlanModel, String, QQueryOperations> dateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dateKey');
    });
  }

  QueryBuilder<MealPlanModel, List<MealModel>?, QQueryOperations>
  mealsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'meals');
    });
  }

  QueryBuilder<MealPlanModel, int?, QQueryOperations> totalCaloriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalCalories');
    });
  }

  QueryBuilder<MealPlanModel, int?, QQueryOperations> totalCarbsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalCarbs');
    });
  }

  QueryBuilder<MealPlanModel, int?, QQueryOperations> totalFatProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalFat');
    });
  }

  QueryBuilder<MealPlanModel, int?, QQueryOperations> totalProteinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalProtein');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const MealModelSchema = Schema(
  name: r'MealModel',
  id: -8574582237306330440,
  properties: {
    r'calories': PropertySchema(id: 0, name: r'calories', type: IsarType.long),
    r'carbs': PropertySchema(id: 1, name: r'carbs', type: IsarType.long),
    r'fat': PropertySchema(id: 2, name: r'fat', type: IsarType.long),
    r'items': PropertySchema(id: 3, name: r'items', type: IsarType.stringList),
    r'name': PropertySchema(id: 4, name: r'name', type: IsarType.string),
    r'protein': PropertySchema(id: 5, name: r'protein', type: IsarType.long),
  },

  estimateSize: _mealModelEstimateSize,
  serialize: _mealModelSerialize,
  deserialize: _mealModelDeserialize,
  deserializeProp: _mealModelDeserializeProp,
);

int _mealModelEstimateSize(
  MealModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final list = object.items;
    if (list != null) {
      bytesCount += 3 + list.length * 3;
      {
        for (var i = 0; i < list.length; i++) {
          final value = list[i];
          bytesCount += value.length * 3;
        }
      }
    }
  }
  {
    final value = object.name;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _mealModelSerialize(
  MealModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.calories);
  writer.writeLong(offsets[1], object.carbs);
  writer.writeLong(offsets[2], object.fat);
  writer.writeStringList(offsets[3], object.items);
  writer.writeString(offsets[4], object.name);
  writer.writeLong(offsets[5], object.protein);
}

MealModel _mealModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MealModel();
  object.calories = reader.readLongOrNull(offsets[0]);
  object.carbs = reader.readLongOrNull(offsets[1]);
  object.fat = reader.readLongOrNull(offsets[2]);
  object.items = reader.readStringList(offsets[3]);
  object.name = reader.readStringOrNull(offsets[4]);
  object.protein = reader.readLongOrNull(offsets[5]);
  return object;
}

P _mealModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readStringList(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension MealModelQueryFilter
    on QueryBuilder<MealModel, MealModel, QFilterCondition> {
  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> caloriesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'calories'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  caloriesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'calories'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> caloriesEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'calories', value: value),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> caloriesGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'calories',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> caloriesLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'calories',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> caloriesBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'calories',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> carbsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'carbs'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> carbsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'carbs'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> carbsEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'carbs', value: value),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> carbsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'carbs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> carbsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'carbs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> carbsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'carbs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> fatIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fat'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> fatIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fat'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> fatEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fat', value: value),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> fatGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fat',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> fatLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fat',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> fatBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fat',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'items'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'items'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'items',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  itemsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'items',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  itemsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'items',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'items',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  itemsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'items',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  itemsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'items',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  itemsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'items',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsElementMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'items',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  itemsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'items', value: ''),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  itemsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'items', value: ''),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsLengthEqualTo(
    int length,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', length, true, length, true);
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, true, 0, true);
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, false, 999999, true);
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', 0, true, length, include);
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition>
  itemsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'items', length, include, 999999, true);
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> itemsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'items',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'name'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'name'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameEqualTo(
    String? value, {
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

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameGreaterThan(
    String? value, {
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

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameLessThan(
    String? value, {
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

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameStartsWith(
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

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameEndsWith(
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

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameContains(
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

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameMatches(
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

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> proteinIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'protein'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> proteinIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'protein'),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> proteinEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'protein', value: value),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> proteinGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'protein',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> proteinLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'protein',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<MealModel, MealModel, QAfterFilterCondition> proteinBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'protein',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension MealModelQueryObject
    on QueryBuilder<MealModel, MealModel, QFilterCondition> {}
