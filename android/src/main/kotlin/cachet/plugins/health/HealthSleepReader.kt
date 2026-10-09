package cachet.plugins.health

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

/** Reads each session with its own stages; a failed page never becomes partial sleep data. */
class HealthSleepReader(
    private val client: HealthConnectClient,
    private val scope: CoroutineScope
) {
    fun getSleepSessions(call: MethodCall, result: MethodChannel.Result) {
        val dayStartMillis = call.argument<Number>("startTime")?.toLong()
        val endMillis = call.argument<Number>("endTime")?.toLong()
        if (dayStartMillis == null || endMillis == null || dayStartMillis > endMillis) {
            result.error("INVALID_ARGUMENTS", "Invalid sleep interval", null)
            return
        }
        val dayStart = Instant.ofEpochMilli(dayStartMillis)
        val end = Instant.ofEpochMilli(endMillis)
        scope.launch {
            try {
                val sessions = mutableListOf<Map<String, Any>>()
                var pageToken: String? = null
                do {
                    // Reading by start time with a fixed lookback would miss long
                    // sessions ending today. Read the permitted history and filter
                    // by the session's actual end. Health Connect enforces access.
                    val page = client.readRecords(
                        ReadRecordsRequest(
                            recordType = SleepSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.before(end),
                            pageToken = pageToken
                        )
                    )
                    for (session in page.records) {
                        if (session.endTime < dayStart || session.endTime > end) continue
                        sessions.add(
                            mapOf(
                                "uuid" to session.metadata.id,
                                "sourceId" to session.metadata.dataOrigin.packageName,
                                "startTime" to session.startTime.toEpochMilli(),
                                "endTime" to session.endTime.toEpochMilli(),
                                "stages" to session.stages.map { stage ->
                                    mapOf(
                                        "startTime" to stage.startTime.toEpochMilli(),
                                        "endTime" to stage.endTime.toEpochMilli(),
                                        "isAsleep" to (stage.stage in asleepStages)
                                    )
                                }
                            )
                        )
                    }
                    pageToken = page.pageToken
                } while (!pageToken.isNullOrEmpty())
                result.success(sessions)
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                result.error("SLEEP_READ_FAILED", "Could not read sleep sessions", null)
            }
        }
    }

    private companion object {
        val asleepStages = setOf(
            SleepSessionRecord.STAGE_TYPE_SLEEPING,
            SleepSessionRecord.STAGE_TYPE_LIGHT,
            SleepSessionRecord.STAGE_TYPE_DEEP,
            SleepSessionRecord.STAGE_TYPE_REM
        )
    }
}
