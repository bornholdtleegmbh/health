import Flutter
import HealthKit

/// A sleep-specific query keeps overlapping HealthKit samples and their source
/// identity. Authorization remains with the existing health plugin.
final class HealthSleepReader {
  private let store: HKHealthStore

  init(store: HKHealthStore) {
    self.store = store
  }
  private static let millisecondsPerSecond = 1000.0

  func getSleepSamples(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let start = arguments["startTime"] as? NSNumber,
          let end = arguments["endTime"] as? NSNumber,
          start.doubleValue <= end.doubleValue else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid sleep interval", details: nil))
      return
    }
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "HEALTH_UNAVAILABLE", message: "HealthKit is unavailable", details: nil))
      return
    }
    let dayStart = Date(timeIntervalSince1970: start.doubleValue / Self.millisecondsPerSecond)
    // Preload yesterday to avoid one query per phase across midnight. This is
    // only the initial window; read() expands it for older connected samples.
    guard let readStart = Calendar.current.date(byAdding: .day, value: -1, to: dayStart) else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid sleep date", details: nil))
      return
    }
    read(
      from: readStart,
      through: Date(timeIntervalSince1970: end.doubleValue / Self.millisecondsPerSecond),
      result: result
    )
  }

  private func read(from start: Date, through end: Date, result: @escaping FlutterResult) {
    let sleepType = HKCategoryType(.sleepAnalysis)
    let asleepValues: [HKCategoryValueSleepAnalysis]
    if #available(iOS 16.0, *) {
      asleepValues = [.asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM]
    } else {
      asleepValues = [.asleep]
    }
    let states = asleepValues + [.awake]
    let statePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: states.map {
      HKQuery.predicateForCategorySamples(with: .equalTo, value: $0.rawValue)
    })
    // Inclusive boundaries keep a predecessor ending exactly at the first sample
    // and a sleep ending at local midnight. In-bed is not an asleep state.
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      NSPredicate(format: "%K >= %@", HKPredicateKeyPathEndDate, start as NSDate),
      NSPredicate(format: "%K <= %@", HKPredicateKeyPathStartDate, end as NSDate),
      statePredicate,
    ])
    let query = HKSampleQuery(
      sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
    ) { [self] _, samples, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "SLEEP_READ_FAILED", message: error.localizedDescription, details: nil))
        }
        return
      }
      guard let samples = samples as? [HKCategorySample] else {
        DispatchQueue.main.async {
          result(FlutterError(code: "SLEEP_READ_FAILED", message: "Missing sleep query response", details: nil))
        }
        return
      }
      // Expand to the actual earliest record until the connected left boundary
      // is complete. No fixed bedtime, lookback duration or gap tolerance.
      if let earliest = samples.map({ $0.startDate }).min(), earliest < start {
        read(from: earliest, through: end, result: result)
        return
      }
      let records: [[String: Any]] = samples.map { sample in
        var record: [String: Any] = [
          "uuid": sample.uuid.uuidString,
          "startTime": Int64((sample.startDate.timeIntervalSince1970 * Self.millisecondsPerSecond).rounded()),
          "endTime": Int64((sample.endDate.timeIntervalSince1970 * Self.millisecondsPerSecond).rounded()),
          "isAsleep": asleepValues.contains { $0.rawValue == sample.value },
          "sourceId": sample.sourceRevision.source.bundleIdentifier,
          "sourceName": sample.sourceRevision.source.name,
        ]
        record["deviceId"] = sample.device?.localIdentifier
        record["productType"] = sample.sourceRevision.productType
        return record
      }
      DispatchQueue.main.async { result(records) }
    }
    store.execute(query)
  }
}
