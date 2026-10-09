import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/health_test_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HealthTestContext ctx;
  final start = DateTime.utc(2026, 10, 9);
  final end = DateTime.utc(2026, 10, 9, 18);
  final stage = {
    'startTime': DateTime.utc(2026, 10, 8, 23).millisecondsSinceEpoch,
    'endTime': DateTime.utc(2026, 10, 9, 7).millisecondsSinceEpoch,
    'isAsleep': true,
  };
  final sample = {
    ...stage,
    'uuid': 'sample-1',
    'sourceId': 'watch-source',
    'sourceName': 'Watch',
    'deviceId': 'watch-1',
    'productType': 'Watch',
  };
  final session = {
    'uuid': 'session-1',
    'sourceId': 'tracker.app',
    'startTime': stage['startTime'],
    'endTime': stage['endTime'],
    'stages': [stage],
  };

  setUp(() async {
    ctx = HealthTestContext();
    await ctx.setUp();
  });
  tearDown(() async => ctx.tearDown());

  test('getSleepSamples preserves complete intervals and original source metadata', () async {
    ctx.channel.when('getSleepSamples', [sample]);
    final result = await ctx.health.getSleepSamples(startTime: start, endTime: end);
    expect(result.single.startTime, DateTime.utc(2026, 10, 8, 23));
    expect(result.single.endTime, DateTime.utc(2026, 10, 9, 7));
    expect(result.single.isAsleep, isTrue);
    expect(result.single.uuid, 'sample-1');
    expect(result.single.sourceId, 'watch-source');
    expect(result.single.sourceName, 'Watch');
    expect(result.single.deviceId, 'watch-1');
    expect(result.single.productType, 'Watch');
    expect(ctx.channel.lastCallFor('getSleepSamples')!.arguments, {
      'startTime': start.millisecondsSinceEpoch,
      'endTime': end.millisecondsSinceEpoch,
    });
  });

  test('getSleepSamples accepts absent optional device metadata and preserves awake', () async {
    ctx.channel.when('getSleepSamples', [
      {...sample, 'deviceId': null, 'productType': null, 'isAsleep': false},
    ]);
    final result = await ctx.health.getSleepSamples(startTime: start, endTime: end);
    expect(result.single.deviceId, isNull);
    expect(result.single.productType, isNull);
    expect(result.single.isAsleep, isFalse);
  });

  test('getSleepSessions preserves separate sessions, stages and source IDs', () async {
    ctx.channel.when('getSleepSessions', [
      session,
      {...session, 'uuid': 'session-2', 'stages': <Object?>[]},
    ]);
    final result = await ctx.health.getSleepSessions(startTime: start, endTime: end);
    expect(result, hasLength(2));
    expect(result.first.uuid, 'session-1');
    expect(result.first.sourceId, 'tracker.app');
    expect(result.first.stages.single.isAsleep, isTrue);
    expect(result.last.uuid, 'session-2');
    expect(result.last.stages, isEmpty);
    expect(() => result.first.stages.clear(), throwsUnsupportedError);
    expect(ctx.channel.lastCallFor('getSleepSessions')!.arguments, {
      'startTime': start.millisecondsSinceEpoch,
      'endTime': end.millisecondsSinceEpoch,
    });
  });

  for (final sessions in [false, true]) {
    final method = sessions ? 'getSleepSessions' : 'getSleepSamples';
    Future<Object> read(DateTime from, DateTime through) => sessions
        ? ctx.health.getSleepSessions(startTime: from, endTime: through)
        : ctx.health.getSleepSamples(startTime: from, endTime: through);

    test('$method returns empty data only for an empty native response', () async {
      ctx.channel.when(method, []);
      expect(await read(start, end), isEmpty);
    });
    test('$method rejects missing responses', () async {
      ctx.channel.when(method, null);
      await expectLater(read(start, end), throwsFormatException);
    });
    test('$method rejects reversed query bounds before calling native code', () async {
      await expectLater(read(end, start), throwsArgumentError);
      expect(ctx.channel.lastCallFor(method), isNull);
    });
    test('$method propagates permission and page errors without partial data', () async {
      await ctx.channel.setUp(
        responder: (call) async {
          if (call.method == method) throw PlatformException(code: 'SLEEP_READ_FAILED');
          return null;
        },
      );
      await expectLater(read(start, end), throwsA(isA<PlatformException>()));
    });
    test('$method rejects malformed native records', () async {
      ctx.channel.when(method, [
        sessions
            ? {
                ...session,
                'stages': [
                  {...stage, 'endTime': stage['startTime']},
                ],
              }
            : {...sample, 'endTime': stage['startTime']},
      ]);
      await expectLater(read(start, end), throwsFormatException);
    });
  }
  test('getSleepSessions rejects a stage outside its parent session', () async {
    ctx.channel.when('getSleepSessions', [
      {
        ...session,
        'stages': [
          {...stage, 'endTime': end.millisecondsSinceEpoch},
        ],
      },
    ]);
    await expectLater(ctx.health.getSleepSessions(startTime: start, endTime: end), throwsFormatException);
  });
}
