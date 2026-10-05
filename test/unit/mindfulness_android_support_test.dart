import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  test('mindfulness is registered for Android reads', () {
    expect(dataTypeKeysAndroid, contains(HealthDataType.MINDFULNESS));
    expect(dataTypeToUnit[HealthDataType.MINDFULNESS], HealthDataUnit.MINUTE);
  });
}
