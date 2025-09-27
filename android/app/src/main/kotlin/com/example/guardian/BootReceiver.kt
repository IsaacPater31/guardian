package com.example.guardian

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.WorkManager

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i("BootReceiver", "Received broadcast: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED) {

            try {
                val serviceIntent = Intent(context, GuardianBackgroundService::class.java).apply {
                    setAction("START_SERVICE")
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }

                Log.i("BootReceiver", "Requested GuardianBackgroundService start")
                // Schedule WorkManager periodic starter as fallback
                try {
                    GuardianStarterWorker.schedulePeriodicWork(context)
                    Log.i("BootReceiver", "Scheduled GuardianStarterWorker as fallback")
                } catch (e: Exception) {
                    Log.e("BootReceiver", "Failed to schedule WorkManager: ${e.message}")
                }
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to start GuardianBackgroundService: ${e.message}")
            }
        }
    }
}
