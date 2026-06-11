package com.example.guardian

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class GuardianStarterWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    companion object {
        private const val TAG = "GuardianStarterWorker"

        fun schedulePeriodicWork(context: Context) {
            val wm = GuardianNativeConfig.WorkManager
            val request = PeriodicWorkRequestBuilder<GuardianStarterWorker>(
                wm.PERIODIC_INTERVAL_MINUTES,
                TimeUnit.MINUTES,
            )
                .setInitialDelay(wm.INITIAL_DELAY_MINUTES, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                wm.STARTER_WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )

            Log.i(TAG, "Scheduled periodic guardian starter worker")
        }
    }

    override suspend fun doWork(): Result {
        try {
            Log.i(TAG, "Running guardian starter worker check")

            if (!GuardianBackgroundService.isRunning()) {
                val intent = Intent(applicationContext, GuardianBackgroundService::class.java).apply {
                    action = GuardianNativeConfig.Service.ACTION_START
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(intent)
                } else {
                    applicationContext.startService(intent)
                }

                Log.i(TAG, "Requested GuardianBackgroundService start from worker")
            } else {
                Log.i(TAG, "GuardianBackgroundService already running")
            }

            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Error in guardian starter worker: ${e.message}")
            return Result.retry()
        }
    }
}
