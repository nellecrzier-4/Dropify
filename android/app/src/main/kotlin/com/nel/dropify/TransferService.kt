package com.nel.dropify

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service yang menjaga proses tetap hidup selama upload/download
 * berjalan, supaya transfer tidak berhenti saat aplikasi ditinggalkan.
 */
class TransferService : Service() {

    companion object {
        private const val CHANNEL_ID = "dropify_transfer"
        private const val NOTIFICATION_ID = 7301

        /** false kalau sistem menolak foreground service (kuota dataSync habis). */
        @Volatile
        var unavailable: Boolean = false

        fun start(context: Context, text: String) {
            if (unavailable) return
            val intent = Intent(context, TransferService::class.java)
                .putExtra("text", text)
            try {
                if (Build.VERSION.SDK_INT >= 26) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                unavailable = true
                android.util.Log.w("Dropify", "foreground service ditolak: ${e.message}")
            }
        }

        fun update(context: Context, text: String) {
            if (unavailable) return
            val intent = Intent(context, TransferService::class.java)
                .putExtra("text", text)
            try {
                context.startService(intent)
            } catch (e: Exception) {
                unavailable = true
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TransferService::class.java))
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        acquireLocks()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra("text") ?: "Transfer berjalan"
        return try {
            startForeground(NOTIFICATION_ID, buildNotification(text))
            START_STICKY
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException: kuota dataSync
            // perangkat sudah habis. Jangan biarkan exception ini naik —
            // dulu ia mematikan seluruh proses aplikasi. Transfer tetap
            // berjalan selama aplikasi di depan.
            unavailable = true
            android.util.Log.w("Dropify", "startForeground ditolak: ${e.message}")
            stopSelf()
            START_NOT_STICKY
        }
    }

    private fun buildNotification(text: String): Notification {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Transfer",
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply {
                        description = "Menjaga upload/download tetap berjalan"
                        setShowBadge(false)
                    }
                )
            }
        }

        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Dropify")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun acquireLocks() {
        try {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "dropify:transfer",
            ).apply { acquire(60 * 60 * 1000L) }
        } catch (_: Exception) {
        }

        try {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiLock = wifi.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                "dropify:transfer",
            ).apply { acquire() }
        } catch (_: Exception) {
        }
    }

    private fun releaseLocks() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        try {
            if (wifiLock?.isHeld == true) wifiLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
        wifiLock = null
    }

    /**
     * Android 15+ memanggil ini kalau service tipe dataSync melewati batas
     * waktunya. Kalau aplikasi tidak berhenti sendiri dalam beberapa detik,
     * sistem melempar ForegroundServiceDidNotStopInTimeException dan mematikan
     * proses — inilah crash yang terjadi saat aplikasi ditinggalkan.
     */
    override fun onTimeout(startId: Int) {
        try {
            super.onTimeout(startId)
        } catch (_: Throwable) {
        }
        stopSelf()
    }

    override fun onDestroy() {
        releaseLocks()
        super.onDestroy()
    }
}
