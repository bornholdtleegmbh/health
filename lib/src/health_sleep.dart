part of '../health.dart';

/// A recorded interval. Unknown and awake stages have [isAsleep] set to false.
/// No time outside an explicitly asleep interval is counted as sleep.
class HealthSleepStage {
  final DateTime startTime;
  final DateTime endTime;
  final bool isAsleep;

  const HealthSleepStage({required this.startTime, required this.endTime, required this.isAsleep});

  factory HealthSleepStage.fromMethodChannel(Map<dynamic, dynamic> map) {
    final start = DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int, isUtc: true);
    final end = DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int, isUtc: true);
    if (!end.isAfter(start)) {
      throw const FormatException('Invalid sleep stage interval');
    }
    return HealthSleepStage(startTime: start, endTime: end, isAsleep: map['isAsleep'] as bool);
  }
}

/// A HealthKit sleep sample with its original source, not the reading phone.
class HealthSleepSample extends HealthSleepStage {
  final String uuid;
  final String sourceId;
  final String sourceName;
  final String? deviceId;
  final String? productType;

  const HealthSleepSample({
    required super.startTime,
    required super.endTime,
    required super.isAsleep,
    required this.uuid,
    required this.sourceId,
    required this.sourceName,
    this.deviceId,
    this.productType,
  });

  factory HealthSleepSample.fromMethodChannel(Map<dynamic, dynamic> map) {
    final stage = HealthSleepStage.fromMethodChannel(map);
    return HealthSleepSample(
      startTime: stage.startTime,
      endTime: stage.endTime,
      isAsleep: stage.isAsleep,
      uuid: map['uuid'] as String,
      sourceId: map['sourceId'] as String,
      sourceName: map['sourceName'] as String,
      deviceId: map['deviceId'] as String?,
      productType: map['productType'] as String?,
    );
  }
}

/// A complete Health Connect session with its own stages and record ID.
/// Session duration must not be used as a replacement for missing asleep stages.
class HealthSleepSession {
  final String uuid;
  final String sourceId;
  final DateTime startTime;
  final DateTime endTime;
  final List<HealthSleepStage> stages;

  HealthSleepSession({
    required this.uuid,
    required this.sourceId,
    required this.startTime,
    required this.endTime,
    required List<HealthSleepStage> stages,
  }) : stages = List.unmodifiable(stages);

  factory HealthSleepSession.fromMethodChannel(Map<dynamic, dynamic> map) {
    final start = DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int, isUtc: true);
    final end = DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int, isUtc: true);
    if (!end.isAfter(start)) {
      throw const FormatException('Invalid sleep session interval');
    }
    final stages = (map['stages'] as List)
        .map((stage) => HealthSleepStage.fromMethodChannel(stage as Map<dynamic, dynamic>))
        .toList();
    if (stages.any((stage) => stage.startTime.isBefore(start) || stage.endTime.isAfter(end))) {
      throw const FormatException('Sleep stage is outside its session');
    }
    return HealthSleepSession(
      uuid: map['uuid'] as String,
      sourceId: map['sourceId'] as String,
      startTime: start,
      endTime: end,
      stages: stages,
    );
  }
}
