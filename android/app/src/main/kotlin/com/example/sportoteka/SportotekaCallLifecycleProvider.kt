package com.example.sportoteka

import android.app.Activity
import android.app.Application
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ProviderInfo
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

/**
 * Native fallback specifically for the Android locked incoming-call screen.
 *
 * Flutter/FCM remains the main lifecycle path.
 * This watcher starts only while flutter_callkit_incoming's full-screen
 * CallkitIncomingActivity exists.
 */
class SportotekaCallLifecycleProvider : ContentProvider() {

    companion object {
        private const val TAG =
            "SPORTOTEKA_CALL_WATCH"

        private const val CALLKIT_ACTIVITY =
            "com.hiennv.flutter_callkit_incoming.CallkitIncomingActivity"

        private const val CALLKIT_RECEIVER =
            "com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver"

        private const val EXTRA_DATA =
            "EXTRA_CALLKIT_INCOMING_DATA"

        private const val EXTRA_EXTRA =
            "EXTRA_CALLKIT_EXTRA"

        private const val ACTION_CALL_ENDED =
            "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ENDED"

        private const val ACTION_END_ACTIVITY =
            "com.hiennv.flutter_callkit_incoming.ACTION_ENDED_CALL_INCOMING"
    }

    private val mainHandler =
        Handler(Looper.getMainLooper())

    private val executor =
        Executors.newSingleThreadExecutor()

    @Volatile
    private var watching = false

    @Volatile
    private var requestRunning = false

    private var watchedCallId = ""
    private var watchedUserId = ""
    private var watchedData: Bundle? = null

    private var callkitActivityRef:
        WeakReference<Activity>? = null

    private val pollRunnable =
        object : Runnable {
            override fun run() {
                if (!watching) return

                pollStatus()

                if (watching) {
                    mainHandler.postDelayed(
                        this,
                        1000L
                    )
                }
            }
        }

    override fun onCreate(): Boolean {
        val app =
            context?.applicationContext
                as? Application
                ?: return true

        app.registerActivityLifecycleCallbacks(
            object :
                Application.ActivityLifecycleCallbacks {

                override fun onActivityCreated(
                    activity: Activity,
                    savedInstanceState: Bundle?
                ) {
                    if (
                        activity.javaClass.name ==
                        CALLKIT_ACTIVITY
                    ) {
                        startFromActivity(activity)
                    }
                }

                override fun onActivityDestroyed(
                    activity: Activity
                ) {
                    if (
                        activity.javaClass.name ==
                        CALLKIT_ACTIVITY
                    ) {
                        Log.i(
                            TAG,
                            "ACTIVITY destroyed " +
                                "taskId=${activity.taskId}"
                        )

                        callkitActivityRef = null

                        stopWatcher(
                            "Callkit activity destroyed"
                        )
                    }
                }

                override fun onActivityStarted(
                    activity: Activity
                ) = Unit

                override fun onActivityResumed(
                    activity: Activity
                ) = Unit

                override fun onActivityPaused(
                    activity: Activity
                ) = Unit

                override fun onActivityStopped(
                    activity: Activity
                ) = Unit

                override fun onActivitySaveInstanceState(
                    activity: Activity,
                    outState: Bundle
                ) = Unit
            }
        )

        Log.i(
            TAG,
            "native locked-call watcher registered"
        )

        return true
    }

    private fun startFromActivity(
        activity: Activity
    ) {
        callkitActivityRef =
            WeakReference(activity)

        Log.i(
            TAG,
            "ACTIVITY attached " +
                "taskId=${activity.taskId} " +
                "finishing=${activity.isFinishing}"
        )

        val data =
            activity.intent
                ?.getBundleExtra(EXTRA_DATA)
                ?: run {
                    Log.w(
                        TAG,
                        "Callkit activity has no data"
                    )
                    return
                }

        val extra =
            readExtraMap(data)

        val callId =
            extra["call_id"]
                ?.toString()
                ?.trim()
                .orEmpty()

        val calleeId =
            extra["callee_id"]
                ?.toString()
                ?.trim()
                .orEmpty()

        if (
            callId.isEmpty() ||
            calleeId.isEmpty()
        ) {
            Log.w(
                TAG,
                "missing IDs " +
                    "callId=$callId " +
                    "calleeId=$calleeId"
            )
            return
        }

        watchedCallId = callId
        watchedUserId = calleeId
        watchedData = Bundle(data)

        watching = true
        requestRunning = false

        mainHandler.removeCallbacks(
            pollRunnable
        )

        Log.i(
            TAG,
            "START call=$callId user=$calleeId"
        )

        mainHandler.postDelayed(
            pollRunnable,
            700L
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun readExtraMap(
        data: Bundle
    ): Map<String, Any?> {
        return try {
            val raw =
                if (
                    Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.TIRAMISU
                ) {
                    data.getSerializable(
                        EXTRA_EXTRA,
                        HashMap::class.java
                    )
                } else {
                    @Suppress("DEPRECATION")
                    data.getSerializable(EXTRA_EXTRA)
                }

            when (raw) {
                is Map<*, *> ->
                    raw.entries.associate {
                        it.key.toString() to
                            it.value
                    }

                else ->
                    emptyMap()
            }
        } catch (e: Exception) {
            Log.e(
                TAG,
                "read extra error",
                e
            )

            emptyMap()
        }
    }

    private fun pollStatus() {
        if (
            !watching ||
            requestRunning
        ) {
            return
        }

        val callId = watchedCallId
        val userId = watchedUserId

        if (
            callId.isEmpty() ||
            userId.isEmpty()
        ) {
            return
        }

        requestRunning = true

        executor.execute {
            try {
                val body =
                    "call_id=" +
                    encode(callId) +
                    "&user_id=" +
                    encode(userId)

                val url =
                    URL(
                        "https://sportotekaapp.ru/" +
                            "api/calls/status.php"
                    )

                val conn =
                    (url.openConnection()
                        as HttpURLConnection)
                        .apply {
                            requestMethod =
                                "POST"

                            connectTimeout =
                                3500

                            readTimeout =
                                3500

                            doOutput =
                                true

                            setRequestProperty(
                                "Content-Type",
                                "application/" +
                                    "x-www-form-urlencoded"
                            )
                        }

                conn.outputStream.use {
                    it.write(
                        body.toByteArray(
                            Charsets.UTF_8
                        )
                    )
                }

                val code =
                    conn.responseCode

                val text =
                    if (code in 200..299) {
                        conn.inputStream
                            .bufferedReader()
                            .use {
                                reader ->
                                reader.readText()
                            }
                    } else {
                        ""
                    }

                conn.disconnect()

                if (
                    code in 200..299 &&
                    text.isNotEmpty()
                ) {
                    val status =
                        extractCallStatus(text)

                    if (
                        status == "canceled" ||
                        status == "cancelled" ||
                        status == "declined" ||
                        status == "missed" ||
                        status == "ended"
                    ) {
                        Log.i(
                            TAG,
                            "TERMINAL " +
                                "call=$callId " +
                                "status=$status"
                        )

                        mainHandler.post {
                            endNativeCall(
                                status
                            )
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(
                    TAG,
                    "poll error: ${e.message}"
                )
            } finally {
                requestRunning = false
            }
        }
    }

    private fun extractCallStatus(
        json: String
    ): String {
        val regex =
            Regex(
                """"call_status"\s*:\s*"([^"]+)""""
            )

        return regex
            .find(json)
            ?.groupValues
            ?.getOrNull(1)
            ?.trim()
            ?.lowercase()
            .orEmpty()
    }

    private fun endNativeCall(
        status: String
    ) {
        if (!watching) return

        val ctx =
            context?.applicationContext
                ?: return

        val data =
            watchedData
                ?: return

        // Не допускаем второй terminal action.
        watching = false

        mainHandler.removeCallbacks(
            pollRunnable
        )

        Log.i(
            TAG,
            "END NATIVE " +
                "call=$watchedCallId " +
                "status=$status"
        )

        /*
         * Это тот же native путь,
         * которым flutter_callkit_incoming
         * реализует endCall/endAllCalls.
         *
         * 1. CallkitIncomingBroadcastReceiver:
         *    - markEnded Telecom Connection
         *    - stop ringtone
         *    - clear incoming notification
         *    - remove active call
         */
        val endedIntent =
            Intent().apply {
                setClassName(
                    ctx.packageName,
                    CALLKIT_RECEIVER
                )

                action =
                    "${ctx.packageName}." +
                    ACTION_CALL_ENDED

                putExtra(
                    EXTRA_DATA,
                    Bundle(data)
                )

                `package` =
                    ctx.packageName
            }

        ctx.sendBroadcast(
            endedIntent
        )

        /*
         * 2. Дополнительная страховка именно
         *    для заблокированного full-screen
         *    CallkitIncomingActivity.
         */
        val closeScreenIntent =
            Intent(
                "${ctx.packageName}." +
                    ACTION_END_ACTIVITY
            ).apply {
                setClassName(
                    ctx.packageName,
                    CALLKIT_ACTIVITY
                )

                setPackage(
                    ctx.packageName
                )

                putExtra(
                    "ACCEPTED",
                    false
                )
            }

        ctx.sendBroadcast(
            closeScreenIntent
        )

        Log.i(
            TAG,
            "END broadcasts sent"
        )

        // Последняя страховка для Samsung/lock screen.
        //
        // Сначала даём flutter_callkit_incoming самому
        // обработать ACTION_CALL_ENDED и очистить Telecom,
        // notification и ringtone. Если его full-screen
        // Activity всё ещё жива — закрываем сам task напрямую.
        mainHandler.postDelayed(
            {
                val activity =
                    callkitActivityRef?.get()

                if (
                    activity != null &&
                    !activity.isFinishing &&
                    !activity.isDestroyed
                ) {
                    Log.i(
                        TAG,
                        "FORCE FINISH activity " +
                            "taskId=${activity.taskId}"
                    )

                    try {
                        activity.finishAndRemoveTask()
                    } catch (e: Exception) {
                        Log.w(
                            TAG,
                            "finishAndRemoveTask failed: " +
                                e.message
                        )

                        try {
                            activity.finish()
                        } catch (_: Exception) {}
                    }
                } else {
                    Log.i(
                        TAG,
                        "FORCE FINISH not needed"
                    )
                }

                callkitActivityRef = null
            },
            180L
        )
    }

    private fun stopWatcher(
        reason: String
    ) {
        if (!watching) return

        Log.i(
            TAG,
            "STOP " +
                "call=$watchedCallId " +
                "reason=$reason"
        )

        watching = false
        requestRunning = false

        mainHandler.removeCallbacks(
            pollRunnable
        )

        watchedCallId = ""
        watchedUserId = ""
        watchedData = null
    }

    private fun encode(
        value: String
    ): String =
        URLEncoder.encode(
            value,
            "UTF-8"
        )

    // ContentProvider нужен только как очень ранняя
    // точка инициализации процесса.
    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor? = null

    override fun getType(
        uri: Uri
    ): String? = null

    override fun insert(
        uri: Uri,
        values: ContentValues?
    ): Uri? = null

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0
}
