# Fork Notes

This repository is a fork of the upstream `health` package.

Base package version: `13.3.2`

Use one section per forked version so it is always clear what changed and why.

## 13.3.1-fork.1

### Android `HealthDataReader`

- `handleWorkoutData()` checks whether the app has read permission for `DistanceRecord`, `TotalCaloriesBurnedRecord`, and `StepsRecord` before querying those records.
- If a permission is missing, the reader skips that metric instead of issuing the query and relying on Health Connect to fail it.
- This keeps workout enrichment stable when the app only requested a subset of workout-related permissions.

### Why this was needed

- The upstream reader assumed those metric reads were always available once a workout record was being processed.
- In this fork, workout summaries can be requested with a smaller permission set, so each enrichment read must be guarded explicitly.
- Without these checks, the workout path could trigger avoidable permission-related failures even when the base workout record itself was accessible.

## 13.3.2-fork.1

### Android mindfulness availability

- Adds `isMindfulnessAvailable()` and the corresponding Health Connect feature check.
- Mindfulness data is rejected on Android devices where the Health Connect feature is unavailable.

### Why this was needed

- Mindfulness support needs a device capability check because Health Connect availability is device-specific.

## 13.3.2-fork.2

### Android mindfulness reads

- Registers `MINDFULNESS` in the Android-supported data types.
- Allows supported devices to read mindfulness sessions after granting permission instead of failing the Dart platform availability check.
- Adds a regression test for the Android registration and minutes unit.

## 13.3.2-fork.3 (unreleased)

### Complete sleep records

- Adds `getSleepSamples(startTime:, endTime:)` on iOS and `getSleepSessions(startTime:, endTime:)` on Android.
- On iOS, the read includes records that overlap the requested range. It also reads older connected records until the start of the sleep is complete. Yesterday is loaded first to keep the number of queries small; it is not a limit on sleep length.
- iOS returns asleep and awake records with their real source, sample ID, and optional device information. Time in bed is excluded because it does not prove the person was asleep.
- On Android, each session comes with its own record ID, source, and stages. Separate requests for light, deep, REM, and awake sleep are no longer needed for this API.
- Android reads all pages of the history the app is allowed to access and selects sessions by their end time. A session can start before the requested range. No extra history permission is requested.
- The start and end bounds for Android session ends are inclusive. Callers that read adjacent ranges should use record IDs to remove repeated boundary records.
- Read failures and invalid responses throw errors. The app can keep its last valid value instead of saving an empty or incomplete result.
- Unknown or awake stages are marked as not asleep. Empty stage lists stay empty. The plugin does not turn session length into an estimated sleep value.
- Request sleep read access before using these methods. HealthKit does not reveal whether read access was denied, so an empty iOS result can mean no records or no read access.
- The plugin only reads records. The app still decides which recorded sleep is the main sleep and which local day it belongs to.
- Existing health read APIs are unchanged. The new APIs use the existing `flutter_health` channel and normal plugin registration; apps do not need their own native bridge.
- Adds tests for source identity, cross-midnight records, parent sessions, missing stages, read errors, malformed records, and query arguments.

### Dependency compatibility

- Allows `device_info_plus` from 12.3 up to the end of version 13. The plugin only uses device APIs available in both versions. This avoids a dependency conflict with storage packages that still need version 12. Tests cover the existing plugin APIs with both versions.

### Why this was needed

- The standard iOS reader uses a strict start-date filter. A sleep record that starts before the query can be missed.
- The standard Android reader fetches sleep types separately and turns some errors into empty results. That can hide a failed or incomplete sleep read.

## Older fork changes added to the change log

These features were already in the repository before fork.3. This section documents them now; it does not claim they were added in this update.

### Health Connect change tokens

- `getChangesToken()` creates a token for selected health data types. `getChanges()` reads later additions, updates, and deleted record IDs.
- The response includes the next token, whether more pages are available, and whether the token has expired. Apps must handle these fields when keeping their own copy of health records.
- Changes written by the calling app are excluded from upserts by default. Set `includeSelf: true` to include them.
- BMI requests use height and weight records. Workout route requests also include workout records, because routes belong to workouts.
- These APIs are Android-only. Their existing error behavior is unchanged; it is different from the new sleep APIs.

### Client record IDs for Android writes

- Supported Android write methods accept a client record ID and version. Apps can use these fields to identify their own records and avoid creating a new record on every repeated upload.
- `deleteByClientRecordId()` can delete records using the app's client ID or a supplied provider record ID.
- The normal Health Connect permissions still apply. These helpers do not grant access to other apps' records.

### Android mindfulness records

- In addition to the capability check and Dart registration listed above, the native reader maps mindfulness sessions to `MindfulnessSessionRecord` and returns their recorded duration in minutes.

### Test support

- The fork includes a shared method-channel test harness, sample data, device-info stubs, unit tests, and device integration test examples. This allows API arguments and responses to be checked without a real health store.

## Upstream 13.3.1 → 13.3.2

The upstream release preserved in this fork includes:

- Write APIs now return the UUID of the created record instead of only a boolean.
- Fixes for issue #502 and iOS issue #480.
- The iOS native plugin class is now `HealthPlugin`, replacing the Objective-C shim around `SwiftHealthPlugin`.
- The minimum iOS deployment target is now iOS 15.0.
- Dependency updates, including `carp_serializable` 3.0.0, `device_info_plus` 13.2.0, and `intl` 0.20.2.

## How to use this file

- Add a new section for each future fork update.
- Keep the version label aligned with the fork state you are shipping.
- Keep the wording short and concrete.
- Prefer listing the user-facing effect of the change over the implementation detail.

## Upstream sync note

When pulling in upstream changes, re-check:

- `README.md` for the top-level pointer
- `CHANGELOG.md` for any local release notes
- this file for any new or resolved fork-specific items
