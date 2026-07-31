// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_database.dart';

// ignore_for_file: type=lint
class $DriftActivitySessionsTable extends DriftActivitySessions
    with TableInfo<$DriftActivitySessionsTable, DriftActivitySession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftActivitySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityTypeMeta = const VerificationMeta(
    'activityType',
  );
  @override
  late final GeneratedColumn<String> activityType = GeneratedColumn<String>(
    'activity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalDistanceMetersMeta =
      const VerificationMeta('totalDistanceMeters');
  @override
  late final GeneratedColumn<double> totalDistanceMeters =
      GeneratedColumn<double>(
        'total_distance_meters',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _totalDurationSecondsMeta =
      const VerificationMeta('totalDurationSeconds');
  @override
  late final GeneratedColumn<int> totalDurationSeconds = GeneratedColumn<int>(
    'total_duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgPaceSecondsPerKmMeta =
      const VerificationMeta('avgPaceSecondsPerKm');
  @override
  late final GeneratedColumn<int> avgPaceSecondsPerKm = GeneratedColumn<int>(
    'avg_pace_seconds_per_km',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepCountReliableMeta = const VerificationMeta(
    'stepCountReliable',
  );
  @override
  late final GeneratedColumn<bool> stepCountReliable = GeneratedColumn<bool>(
    'step_count_reliable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("step_count_reliable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _targetTypeMeta = const VerificationMeta(
    'targetType',
  );
  @override
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetValueMeta = const VerificationMeta(
    'targetValue',
  );
  @override
  late final GeneratedColumn<double> targetValue = GeneratedColumn<double>(
    'target_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetAchievedMeta = const VerificationMeta(
    'targetAchieved',
  );
  @override
  late final GeneratedColumn<bool> targetAchieved = GeneratedColumn<bool>(
    'target_achieved',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("target_achieved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityType,
    startTime,
    endTime,
    totalDistanceMeters,
    totalDurationSeconds,
    avgPaceSecondsPerKm,
    calories,
    steps,
    stepCountReliable,
    targetType,
    targetValue,
    targetAchieved,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_activity_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftActivitySession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_type')) {
      context.handle(
        _activityTypeMeta,
        activityType.isAcceptableOrUnknown(
          data['activity_type']!,
          _activityTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityTypeMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('total_distance_meters')) {
      context.handle(
        _totalDistanceMetersMeta,
        totalDistanceMeters.isAcceptableOrUnknown(
          data['total_distance_meters']!,
          _totalDistanceMetersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalDistanceMetersMeta);
    }
    if (data.containsKey('total_duration_seconds')) {
      context.handle(
        _totalDurationSecondsMeta,
        totalDurationSeconds.isAcceptableOrUnknown(
          data['total_duration_seconds']!,
          _totalDurationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalDurationSecondsMeta);
    }
    if (data.containsKey('avg_pace_seconds_per_km')) {
      context.handle(
        _avgPaceSecondsPerKmMeta,
        avgPaceSecondsPerKm.isAcceptableOrUnknown(
          data['avg_pace_seconds_per_km']!,
          _avgPaceSecondsPerKmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_avgPaceSecondsPerKmMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    if (data.containsKey('step_count_reliable')) {
      context.handle(
        _stepCountReliableMeta,
        stepCountReliable.isAcceptableOrUnknown(
          data['step_count_reliable']!,
          _stepCountReliableMeta,
        ),
      );
    }
    if (data.containsKey('target_type')) {
      context.handle(
        _targetTypeMeta,
        targetType.isAcceptableOrUnknown(data['target_type']!, _targetTypeMeta),
      );
    }
    if (data.containsKey('target_value')) {
      context.handle(
        _targetValueMeta,
        targetValue.isAcceptableOrUnknown(
          data['target_value']!,
          _targetValueMeta,
        ),
      );
    }
    if (data.containsKey('target_achieved')) {
      context.handle(
        _targetAchievedMeta,
        targetAchieved.isAcceptableOrUnknown(
          data['target_achieved']!,
          _targetAchievedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftActivitySession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftActivitySession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      ),
      totalDistanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_distance_meters'],
      )!,
      totalDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_duration_seconds'],
      )!,
      avgPaceSecondsPerKm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_pace_seconds_per_km'],
      )!,
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
      stepCountReliable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}step_count_reliable'],
      )!,
      targetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_type'],
      ),
      targetValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_value'],
      ),
      targetAchieved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}target_achieved'],
      ),
    );
  }

  @override
  $DriftActivitySessionsTable createAlias(String alias) {
    return $DriftActivitySessionsTable(attachedDatabase, alias);
  }
}

class DriftActivitySession extends DataClass
    implements Insertable<DriftActivitySession> {
  final String id;
  final String activityType;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final int avgPaceSecondsPerKm;
  final int calories;
  final int steps;
  final bool stepCountReliable;
  final String? targetType;
  final double? targetValue;
  final bool? targetAchieved;
  const DriftActivitySession({
    required this.id,
    required this.activityType,
    required this.startTime,
    this.endTime,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.avgPaceSecondsPerKm,
    required this.calories,
    required this.steps,
    required this.stepCountReliable,
    this.targetType,
    this.targetValue,
    this.targetAchieved,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_type'] = Variable<String>(activityType);
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['total_distance_meters'] = Variable<double>(totalDistanceMeters);
    map['total_duration_seconds'] = Variable<int>(totalDurationSeconds);
    map['avg_pace_seconds_per_km'] = Variable<int>(avgPaceSecondsPerKm);
    map['calories'] = Variable<int>(calories);
    map['steps'] = Variable<int>(steps);
    map['step_count_reliable'] = Variable<bool>(stepCountReliable);
    if (!nullToAbsent || targetType != null) {
      map['target_type'] = Variable<String>(targetType);
    }
    if (!nullToAbsent || targetValue != null) {
      map['target_value'] = Variable<double>(targetValue);
    }
    if (!nullToAbsent || targetAchieved != null) {
      map['target_achieved'] = Variable<bool>(targetAchieved);
    }
    return map;
  }

  DriftActivitySessionsCompanion toCompanion(bool nullToAbsent) {
    return DriftActivitySessionsCompanion(
      id: Value(id),
      activityType: Value(activityType),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      totalDistanceMeters: Value(totalDistanceMeters),
      totalDurationSeconds: Value(totalDurationSeconds),
      avgPaceSecondsPerKm: Value(avgPaceSecondsPerKm),
      calories: Value(calories),
      steps: Value(steps),
      stepCountReliable: Value(stepCountReliable),
      targetType: targetType == null && nullToAbsent
          ? const Value.absent()
          : Value(targetType),
      targetValue: targetValue == null && nullToAbsent
          ? const Value.absent()
          : Value(targetValue),
      targetAchieved: targetAchieved == null && nullToAbsent
          ? const Value.absent()
          : Value(targetAchieved),
    );
  }

  factory DriftActivitySession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftActivitySession(
      id: serializer.fromJson<String>(json['id']),
      activityType: serializer.fromJson<String>(json['activityType']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      totalDistanceMeters: serializer.fromJson<double>(
        json['totalDistanceMeters'],
      ),
      totalDurationSeconds: serializer.fromJson<int>(
        json['totalDurationSeconds'],
      ),
      avgPaceSecondsPerKm: serializer.fromJson<int>(
        json['avgPaceSecondsPerKm'],
      ),
      calories: serializer.fromJson<int>(json['calories']),
      steps: serializer.fromJson<int>(json['steps']),
      stepCountReliable: serializer.fromJson<bool>(json['stepCountReliable']),
      targetType: serializer.fromJson<String?>(json['targetType']),
      targetValue: serializer.fromJson<double?>(json['targetValue']),
      targetAchieved: serializer.fromJson<bool?>(json['targetAchieved']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityType': serializer.toJson<String>(activityType),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'totalDistanceMeters': serializer.toJson<double>(totalDistanceMeters),
      'totalDurationSeconds': serializer.toJson<int>(totalDurationSeconds),
      'avgPaceSecondsPerKm': serializer.toJson<int>(avgPaceSecondsPerKm),
      'calories': serializer.toJson<int>(calories),
      'steps': serializer.toJson<int>(steps),
      'stepCountReliable': serializer.toJson<bool>(stepCountReliable),
      'targetType': serializer.toJson<String?>(targetType),
      'targetValue': serializer.toJson<double?>(targetValue),
      'targetAchieved': serializer.toJson<bool?>(targetAchieved),
    };
  }

  DriftActivitySession copyWith({
    String? id,
    String? activityType,
    DateTime? startTime,
    Value<DateTime?> endTime = const Value.absent(),
    double? totalDistanceMeters,
    int? totalDurationSeconds,
    int? avgPaceSecondsPerKm,
    int? calories,
    int? steps,
    bool? stepCountReliable,
    Value<String?> targetType = const Value.absent(),
    Value<double?> targetValue = const Value.absent(),
    Value<bool?> targetAchieved = const Value.absent(),
  }) => DriftActivitySession(
    id: id ?? this.id,
    activityType: activityType ?? this.activityType,
    startTime: startTime ?? this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
    totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
    avgPaceSecondsPerKm: avgPaceSecondsPerKm ?? this.avgPaceSecondsPerKm,
    calories: calories ?? this.calories,
    steps: steps ?? this.steps,
    stepCountReliable: stepCountReliable ?? this.stepCountReliable,
    targetType: targetType.present ? targetType.value : this.targetType,
    targetValue: targetValue.present ? targetValue.value : this.targetValue,
    targetAchieved: targetAchieved.present
        ? targetAchieved.value
        : this.targetAchieved,
  );
  DriftActivitySession copyWithCompanion(DriftActivitySessionsCompanion data) {
    return DriftActivitySession(
      id: data.id.present ? data.id.value : this.id,
      activityType: data.activityType.present
          ? data.activityType.value
          : this.activityType,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      totalDistanceMeters: data.totalDistanceMeters.present
          ? data.totalDistanceMeters.value
          : this.totalDistanceMeters,
      totalDurationSeconds: data.totalDurationSeconds.present
          ? data.totalDurationSeconds.value
          : this.totalDurationSeconds,
      avgPaceSecondsPerKm: data.avgPaceSecondsPerKm.present
          ? data.avgPaceSecondsPerKm.value
          : this.avgPaceSecondsPerKm,
      calories: data.calories.present ? data.calories.value : this.calories,
      steps: data.steps.present ? data.steps.value : this.steps,
      stepCountReliable: data.stepCountReliable.present
          ? data.stepCountReliable.value
          : this.stepCountReliable,
      targetType: data.targetType.present
          ? data.targetType.value
          : this.targetType,
      targetValue: data.targetValue.present
          ? data.targetValue.value
          : this.targetValue,
      targetAchieved: data.targetAchieved.present
          ? data.targetAchieved.value
          : this.targetAchieved,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftActivitySession(')
          ..write('id: $id, ')
          ..write('activityType: $activityType, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('totalDistanceMeters: $totalDistanceMeters, ')
          ..write('totalDurationSeconds: $totalDurationSeconds, ')
          ..write('avgPaceSecondsPerKm: $avgPaceSecondsPerKm, ')
          ..write('calories: $calories, ')
          ..write('steps: $steps, ')
          ..write('stepCountReliable: $stepCountReliable, ')
          ..write('targetType: $targetType, ')
          ..write('targetValue: $targetValue, ')
          ..write('targetAchieved: $targetAchieved')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityType,
    startTime,
    endTime,
    totalDistanceMeters,
    totalDurationSeconds,
    avgPaceSecondsPerKm,
    calories,
    steps,
    stepCountReliable,
    targetType,
    targetValue,
    targetAchieved,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftActivitySession &&
          other.id == this.id &&
          other.activityType == this.activityType &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.totalDistanceMeters == this.totalDistanceMeters &&
          other.totalDurationSeconds == this.totalDurationSeconds &&
          other.avgPaceSecondsPerKm == this.avgPaceSecondsPerKm &&
          other.calories == this.calories &&
          other.steps == this.steps &&
          other.stepCountReliable == this.stepCountReliable &&
          other.targetType == this.targetType &&
          other.targetValue == this.targetValue &&
          other.targetAchieved == this.targetAchieved);
}

class DriftActivitySessionsCompanion
    extends UpdateCompanion<DriftActivitySession> {
  final Value<String> id;
  final Value<String> activityType;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<double> totalDistanceMeters;
  final Value<int> totalDurationSeconds;
  final Value<int> avgPaceSecondsPerKm;
  final Value<int> calories;
  final Value<int> steps;
  final Value<bool> stepCountReliable;
  final Value<String?> targetType;
  final Value<double?> targetValue;
  final Value<bool?> targetAchieved;
  final Value<int> rowid;
  const DriftActivitySessionsCompanion({
    this.id = const Value.absent(),
    this.activityType = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.totalDistanceMeters = const Value.absent(),
    this.totalDurationSeconds = const Value.absent(),
    this.avgPaceSecondsPerKm = const Value.absent(),
    this.calories = const Value.absent(),
    this.steps = const Value.absent(),
    this.stepCountReliable = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetValue = const Value.absent(),
    this.targetAchieved = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DriftActivitySessionsCompanion.insert({
    required String id,
    required String activityType,
    required DateTime startTime,
    this.endTime = const Value.absent(),
    required double totalDistanceMeters,
    required int totalDurationSeconds,
    required int avgPaceSecondsPerKm,
    required int calories,
    required int steps,
    this.stepCountReliable = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetValue = const Value.absent(),
    this.targetAchieved = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityType = Value(activityType),
       startTime = Value(startTime),
       totalDistanceMeters = Value(totalDistanceMeters),
       totalDurationSeconds = Value(totalDurationSeconds),
       avgPaceSecondsPerKm = Value(avgPaceSecondsPerKm),
       calories = Value(calories),
       steps = Value(steps);
  static Insertable<DriftActivitySession> custom({
    Expression<String>? id,
    Expression<String>? activityType,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<double>? totalDistanceMeters,
    Expression<int>? totalDurationSeconds,
    Expression<int>? avgPaceSecondsPerKm,
    Expression<int>? calories,
    Expression<int>? steps,
    Expression<bool>? stepCountReliable,
    Expression<String>? targetType,
    Expression<double>? targetValue,
    Expression<bool>? targetAchieved,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityType != null) 'activity_type': activityType,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (totalDistanceMeters != null)
        'total_distance_meters': totalDistanceMeters,
      if (totalDurationSeconds != null)
        'total_duration_seconds': totalDurationSeconds,
      if (avgPaceSecondsPerKm != null)
        'avg_pace_seconds_per_km': avgPaceSecondsPerKm,
      if (calories != null) 'calories': calories,
      if (steps != null) 'steps': steps,
      if (stepCountReliable != null) 'step_count_reliable': stepCountReliable,
      if (targetType != null) 'target_type': targetType,
      if (targetValue != null) 'target_value': targetValue,
      if (targetAchieved != null) 'target_achieved': targetAchieved,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DriftActivitySessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? activityType,
    Value<DateTime>? startTime,
    Value<DateTime?>? endTime,
    Value<double>? totalDistanceMeters,
    Value<int>? totalDurationSeconds,
    Value<int>? avgPaceSecondsPerKm,
    Value<int>? calories,
    Value<int>? steps,
    Value<bool>? stepCountReliable,
    Value<String?>? targetType,
    Value<double?>? targetValue,
    Value<bool?>? targetAchieved,
    Value<int>? rowid,
  }) {
    return DriftActivitySessionsCompanion(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm ?? this.avgPaceSecondsPerKm,
      calories: calories ?? this.calories,
      steps: steps ?? this.steps,
      stepCountReliable: stepCountReliable ?? this.stepCountReliable,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      targetAchieved: targetAchieved ?? this.targetAchieved,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityType.present) {
      map['activity_type'] = Variable<String>(activityType.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (totalDistanceMeters.present) {
      map['total_distance_meters'] = Variable<double>(
        totalDistanceMeters.value,
      );
    }
    if (totalDurationSeconds.present) {
      map['total_duration_seconds'] = Variable<int>(totalDurationSeconds.value);
    }
    if (avgPaceSecondsPerKm.present) {
      map['avg_pace_seconds_per_km'] = Variable<int>(avgPaceSecondsPerKm.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (stepCountReliable.present) {
      map['step_count_reliable'] = Variable<bool>(stepCountReliable.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetValue.present) {
      map['target_value'] = Variable<double>(targetValue.value);
    }
    if (targetAchieved.present) {
      map['target_achieved'] = Variable<bool>(targetAchieved.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftActivitySessionsCompanion(')
          ..write('id: $id, ')
          ..write('activityType: $activityType, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('totalDistanceMeters: $totalDistanceMeters, ')
          ..write('totalDurationSeconds: $totalDurationSeconds, ')
          ..write('avgPaceSecondsPerKm: $avgPaceSecondsPerKm, ')
          ..write('calories: $calories, ')
          ..write('steps: $steps, ')
          ..write('stepCountReliable: $stepCountReliable, ')
          ..write('targetType: $targetType, ')
          ..write('targetValue: $targetValue, ')
          ..write('targetAchieved: $targetAchieved, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DriftTrackPointsTable extends DriftTrackPoints
    with TableInfo<$DriftTrackPointsTable, DriftTrackPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftTrackPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES drift_activity_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    latitude,
    longitude,
    timestamp,
    accuracy,
    speed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_track_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftTrackPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    } else if (isInserting) {
      context.missing(_speedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftTrackPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftTrackPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
    );
  }

  @override
  $DriftTrackPointsTable createAlias(String alias) {
    return $DriftTrackPointsTable(attachedDatabase, alias);
  }
}

class DriftTrackPoint extends DataClass implements Insertable<DriftTrackPoint> {
  final int id;
  final String sessionId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double speed;
  const DriftTrackPoint({
    required this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.speed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['accuracy'] = Variable<double>(accuracy);
    map['speed'] = Variable<double>(speed);
    return map;
  }

  DriftTrackPointsCompanion toCompanion(bool nullToAbsent) {
    return DriftTrackPointsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      timestamp: Value(timestamp),
      accuracy: Value(accuracy),
      speed: Value(speed),
    );
  }

  factory DriftTrackPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftTrackPoint(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      accuracy: serializer.fromJson<double>(json['accuracy']),
      speed: serializer.fromJson<double>(json['speed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'accuracy': serializer.toJson<double>(accuracy),
      'speed': serializer.toJson<double>(speed),
    };
  }

  DriftTrackPoint copyWith({
    int? id,
    String? sessionId,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? accuracy,
    double? speed,
  }) => DriftTrackPoint(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    timestamp: timestamp ?? this.timestamp,
    accuracy: accuracy ?? this.accuracy,
    speed: speed ?? this.speed,
  );
  DriftTrackPoint copyWithCompanion(DriftTrackPointsCompanion data) {
    return DriftTrackPoint(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      speed: data.speed.present ? data.speed.value : this.speed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftTrackPoint(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('timestamp: $timestamp, ')
          ..write('accuracy: $accuracy, ')
          ..write('speed: $speed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    latitude,
    longitude,
    timestamp,
    accuracy,
    speed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftTrackPoint &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.timestamp == this.timestamp &&
          other.accuracy == this.accuracy &&
          other.speed == this.speed);
}

class DriftTrackPointsCompanion extends UpdateCompanion<DriftTrackPoint> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<DateTime> timestamp;
  final Value<double> accuracy;
  final Value<double> speed;
  const DriftTrackPointsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.speed = const Value.absent(),
  });
  DriftTrackPointsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required double accuracy,
    required double speed,
  }) : sessionId = Value(sessionId),
       latitude = Value(latitude),
       longitude = Value(longitude),
       timestamp = Value(timestamp),
       accuracy = Value(accuracy),
       speed = Value(speed);
  static Insertable<DriftTrackPoint> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<DateTime>? timestamp,
    Expression<double>? accuracy,
    Expression<double>? speed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (timestamp != null) 'timestamp': timestamp,
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null) 'speed': speed,
    });
  }

  DriftTrackPointsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<DateTime>? timestamp,
    Value<double>? accuracy,
    Value<double>? speed,
  }) {
    return DriftTrackPointsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftTrackPointsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('timestamp: $timestamp, ')
          ..write('accuracy: $accuracy, ')
          ..write('speed: $speed')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DriftActivitySessionsTable driftActivitySessions =
      $DriftActivitySessionsTable(this);
  late final $DriftTrackPointsTable driftTrackPoints = $DriftTrackPointsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    driftActivitySessions,
    driftTrackPoints,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'drift_activity_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('drift_track_points', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DriftActivitySessionsTableCreateCompanionBuilder =
    DriftActivitySessionsCompanion Function({
      required String id,
      required String activityType,
      required DateTime startTime,
      Value<DateTime?> endTime,
      required double totalDistanceMeters,
      required int totalDurationSeconds,
      required int avgPaceSecondsPerKm,
      required int calories,
      required int steps,
      Value<bool> stepCountReliable,
      Value<String?> targetType,
      Value<double?> targetValue,
      Value<bool?> targetAchieved,
      Value<int> rowid,
    });
typedef $$DriftActivitySessionsTableUpdateCompanionBuilder =
    DriftActivitySessionsCompanion Function({
      Value<String> id,
      Value<String> activityType,
      Value<DateTime> startTime,
      Value<DateTime?> endTime,
      Value<double> totalDistanceMeters,
      Value<int> totalDurationSeconds,
      Value<int> avgPaceSecondsPerKm,
      Value<int> calories,
      Value<int> steps,
      Value<bool> stepCountReliable,
      Value<String?> targetType,
      Value<double?> targetValue,
      Value<bool?> targetAchieved,
      Value<int> rowid,
    });

final class $$DriftActivitySessionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DriftActivitySessionsTable,
          DriftActivitySession
        > {
  $$DriftActivitySessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DriftTrackPointsTable, List<DriftTrackPoint>>
  _driftTrackPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.driftTrackPoints,
    aliasName: 'drift_activity_sessions__id__drift_track_points__session_id',
  );

  $$DriftTrackPointsTableProcessedTableManager get driftTrackPointsRefs {
    final manager = $$DriftTrackPointsTableTableManager(
      $_db,
      $_db.driftTrackPoints,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _driftTrackPointsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DriftActivitySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $DriftActivitySessionsTable> {
  $$DriftActivitySessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalDistanceMeters => $composableBuilder(
    column: $table.totalDistanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDurationSeconds => $composableBuilder(
    column: $table.totalDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgPaceSecondsPerKm => $composableBuilder(
    column: $table.avgPaceSecondsPerKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get stepCountReliable => $composableBuilder(
    column: $table.stepCountReliable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get targetAchieved => $composableBuilder(
    column: $table.targetAchieved,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> driftTrackPointsRefs(
    Expression<bool> Function($$DriftTrackPointsTableFilterComposer f) f,
  ) {
    final $$DriftTrackPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.driftTrackPoints,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriftTrackPointsTableFilterComposer(
            $db: $db,
            $table: $db.driftTrackPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DriftActivitySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DriftActivitySessionsTable> {
  $$DriftActivitySessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalDistanceMeters => $composableBuilder(
    column: $table.totalDistanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDurationSeconds => $composableBuilder(
    column: $table.totalDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgPaceSecondsPerKm => $composableBuilder(
    column: $table.avgPaceSecondsPerKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get stepCountReliable => $composableBuilder(
    column: $table.stepCountReliable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get targetAchieved => $composableBuilder(
    column: $table.targetAchieved,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftActivitySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DriftActivitySessionsTable> {
  $$DriftActivitySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<double> get totalDistanceMeters => $composableBuilder(
    column: $table.totalDistanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalDurationSeconds => $composableBuilder(
    column: $table.totalDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avgPaceSecondsPerKm => $composableBuilder(
    column: $table.avgPaceSecondsPerKm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<bool> get stepCountReliable => $composableBuilder(
    column: $table.stepCountReliable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetValue => $composableBuilder(
    column: $table.targetValue,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get targetAchieved => $composableBuilder(
    column: $table.targetAchieved,
    builder: (column) => column,
  );

  Expression<T> driftTrackPointsRefs<T extends Object>(
    Expression<T> Function($$DriftTrackPointsTableAnnotationComposer a) f,
  ) {
    final $$DriftTrackPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.driftTrackPoints,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DriftTrackPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.driftTrackPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DriftActivitySessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DriftActivitySessionsTable,
          DriftActivitySession,
          $$DriftActivitySessionsTableFilterComposer,
          $$DriftActivitySessionsTableOrderingComposer,
          $$DriftActivitySessionsTableAnnotationComposer,
          $$DriftActivitySessionsTableCreateCompanionBuilder,
          $$DriftActivitySessionsTableUpdateCompanionBuilder,
          (DriftActivitySession, $$DriftActivitySessionsTableReferences),
          DriftActivitySession,
          PrefetchHooks Function({bool driftTrackPointsRefs})
        > {
  $$DriftActivitySessionsTableTableManager(
    _$AppDatabase db,
    $DriftActivitySessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DriftActivitySessionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DriftActivitySessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DriftActivitySessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityType = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime?> endTime = const Value.absent(),
                Value<double> totalDistanceMeters = const Value.absent(),
                Value<int> totalDurationSeconds = const Value.absent(),
                Value<int> avgPaceSecondsPerKm = const Value.absent(),
                Value<int> calories = const Value.absent(),
                Value<int> steps = const Value.absent(),
                Value<bool> stepCountReliable = const Value.absent(),
                Value<String?> targetType = const Value.absent(),
                Value<double?> targetValue = const Value.absent(),
                Value<bool?> targetAchieved = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftActivitySessionsCompanion(
                id: id,
                activityType: activityType,
                startTime: startTime,
                endTime: endTime,
                totalDistanceMeters: totalDistanceMeters,
                totalDurationSeconds: totalDurationSeconds,
                avgPaceSecondsPerKm: avgPaceSecondsPerKm,
                calories: calories,
                steps: steps,
                stepCountReliable: stepCountReliable,
                targetType: targetType,
                targetValue: targetValue,
                targetAchieved: targetAchieved,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityType,
                required DateTime startTime,
                Value<DateTime?> endTime = const Value.absent(),
                required double totalDistanceMeters,
                required int totalDurationSeconds,
                required int avgPaceSecondsPerKm,
                required int calories,
                required int steps,
                Value<bool> stepCountReliable = const Value.absent(),
                Value<String?> targetType = const Value.absent(),
                Value<double?> targetValue = const Value.absent(),
                Value<bool?> targetAchieved = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DriftActivitySessionsCompanion.insert(
                id: id,
                activityType: activityType,
                startTime: startTime,
                endTime: endTime,
                totalDistanceMeters: totalDistanceMeters,
                totalDurationSeconds: totalDurationSeconds,
                avgPaceSecondsPerKm: avgPaceSecondsPerKm,
                calories: calories,
                steps: steps,
                stepCountReliable: stepCountReliable,
                targetType: targetType,
                targetValue: targetValue,
                targetAchieved: targetAchieved,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DriftActivitySessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({driftTrackPointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (driftTrackPointsRefs) db.driftTrackPoints,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (driftTrackPointsRefs)
                    await $_getPrefetchedData<
                      DriftActivitySession,
                      $DriftActivitySessionsTable,
                      DriftTrackPoint
                    >(
                      currentTable: table,
                      referencedTable: $$DriftActivitySessionsTableReferences
                          ._driftTrackPointsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DriftActivitySessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).driftTrackPointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DriftActivitySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DriftActivitySessionsTable,
      DriftActivitySession,
      $$DriftActivitySessionsTableFilterComposer,
      $$DriftActivitySessionsTableOrderingComposer,
      $$DriftActivitySessionsTableAnnotationComposer,
      $$DriftActivitySessionsTableCreateCompanionBuilder,
      $$DriftActivitySessionsTableUpdateCompanionBuilder,
      (DriftActivitySession, $$DriftActivitySessionsTableReferences),
      DriftActivitySession,
      PrefetchHooks Function({bool driftTrackPointsRefs})
    >;
typedef $$DriftTrackPointsTableCreateCompanionBuilder =
    DriftTrackPointsCompanion Function({
      Value<int> id,
      required String sessionId,
      required double latitude,
      required double longitude,
      required DateTime timestamp,
      required double accuracy,
      required double speed,
    });
typedef $$DriftTrackPointsTableUpdateCompanionBuilder =
    DriftTrackPointsCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<double> latitude,
      Value<double> longitude,
      Value<DateTime> timestamp,
      Value<double> accuracy,
      Value<double> speed,
    });

final class $$DriftTrackPointsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DriftTrackPointsTable, DriftTrackPoint> {
  $$DriftTrackPointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DriftActivitySessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.driftActivitySessions.createAlias(
        'drift_track_points__session_id__drift_activity_sessions__id',
      );

  $$DriftActivitySessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$DriftActivitySessionsTableTableManager(
      $_db,
      $_db.driftActivitySessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DriftTrackPointsTableFilterComposer
    extends Composer<_$AppDatabase, $DriftTrackPointsTable> {
  $$DriftTrackPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  $$DriftActivitySessionsTableFilterComposer get sessionId {
    final $$DriftActivitySessionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.driftActivitySessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DriftActivitySessionsTableFilterComposer(
                $db: $db,
                $table: $db.driftActivitySessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DriftTrackPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $DriftTrackPointsTable> {
  $$DriftTrackPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  $$DriftActivitySessionsTableOrderingComposer get sessionId {
    final $$DriftActivitySessionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.driftActivitySessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DriftActivitySessionsTableOrderingComposer(
                $db: $db,
                $table: $db.driftActivitySessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DriftTrackPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DriftTrackPointsTable> {
  $$DriftTrackPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  $$DriftActivitySessionsTableAnnotationComposer get sessionId {
    final $$DriftActivitySessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.driftActivitySessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DriftActivitySessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.driftActivitySessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$DriftTrackPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DriftTrackPointsTable,
          DriftTrackPoint,
          $$DriftTrackPointsTableFilterComposer,
          $$DriftTrackPointsTableOrderingComposer,
          $$DriftTrackPointsTableAnnotationComposer,
          $$DriftTrackPointsTableCreateCompanionBuilder,
          $$DriftTrackPointsTableUpdateCompanionBuilder,
          (DriftTrackPoint, $$DriftTrackPointsTableReferences),
          DriftTrackPoint,
          PrefetchHooks Function({bool sessionId})
        > {
  $$DriftTrackPointsTableTableManager(
    _$AppDatabase db,
    $DriftTrackPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DriftTrackPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DriftTrackPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DriftTrackPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<double> accuracy = const Value.absent(),
                Value<double> speed = const Value.absent(),
              }) => DriftTrackPointsCompanion(
                id: id,
                sessionId: sessionId,
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
                accuracy: accuracy,
                speed: speed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required double latitude,
                required double longitude,
                required DateTime timestamp,
                required double accuracy,
                required double speed,
              }) => DriftTrackPointsCompanion.insert(
                id: id,
                sessionId: sessionId,
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
                accuracy: accuracy,
                speed: speed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DriftTrackPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$DriftTrackPointsTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$DriftTrackPointsTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DriftTrackPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DriftTrackPointsTable,
      DriftTrackPoint,
      $$DriftTrackPointsTableFilterComposer,
      $$DriftTrackPointsTableOrderingComposer,
      $$DriftTrackPointsTableAnnotationComposer,
      $$DriftTrackPointsTableCreateCompanionBuilder,
      $$DriftTrackPointsTableUpdateCompanionBuilder,
      (DriftTrackPoint, $$DriftTrackPointsTableReferences),
      DriftTrackPoint,
      PrefetchHooks Function({bool sessionId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DriftActivitySessionsTableTableManager get driftActivitySessions =>
      $$DriftActivitySessionsTableTableManager(_db, _db.driftActivitySessions);
  $$DriftTrackPointsTableTableManager get driftTrackPoints =>
      $$DriftTrackPointsTableTableManager(_db, _db.driftTrackPoints);
}
