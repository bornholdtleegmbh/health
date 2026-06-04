# Fork Notes

This repository is a fork of the upstream `health` package.

Base package version: `13.3.1`

Use one section per forked version so it is always clear what changed and why.

## 13.3.1-fork.1

### Android `HealthDataReader`

- `handleWorkoutData()` now checks whether the app actually has read permission for `DistanceRecord`, `TotalCaloriesBurnedRecord`, and `StepsRecord` before querying those records.
- If a permission is missing, the reader skips that metric instead of issuing the query and relying on Health Connect to fail it.
- This keeps workout enrichment stable when the app only requested a subset of workout-related permissions.

### Why this was needed

- The upstream reader assumed those metric reads were always available once a workout record was being processed.
- In this fork, workout summaries can be requested with a smaller permission set, so the reader needs to guard each metric read explicitly.
- Without these checks, the workout path could trigger avoidable permission-related failures even when the base workout record itself was accessible.

### Notes

- The forked file also ends with a newline, which is just a formatting cleanup and not a behavior change.

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
