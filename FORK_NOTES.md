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
