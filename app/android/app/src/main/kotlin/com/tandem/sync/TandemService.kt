package com.tandem.sync

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
 * Foreground Service running the embedded Tandem engine in-process.
 * Manages partial wake locks, high-performance Wi-Fi locks, and multicast locks
 * exclusively during active synchronization (Section 4.6).
 */
class TandemService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    companion object {
        const val CHANNEL_ID = "tandem_sync_channel"
        const val NOTIFICATION_ID = 2001

        init {
            // Load embedded sync engine native library (libtandemd.so)
            try {
                System.loadLibrary("tandemd")
            } catch (e: UnsatisfiedLinkError) {
                // Expected when running in mock/testing environments
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        // Acquire MulticastLock for local discovery broadcasts (UDP 21027)
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifiManager.createMulticastLock("tandem:multicast_lock").apply {
            setReferenceCounted(true)
            acquire()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildForegroundNotification("Tandem is active", "Nearby devices can connect")
        startForeground(NOTIFICATION_ID, notification)

        // Native engine startup passing nativeLibraryDir/libsyncthing.so
        val syncthingPath = "${applicationInfo.nativeLibraryDir}/libsyncthing.so"
        startEngineNative(filesDir.absolutePath, syncthingPath)
        return START_STICKY
    }

    fun onTransferActive(isActive: Boolean) {
        if (isActive) {
            // Acquire wake lock and Wi-Fi lock only during active transfers to preserve battery (D4)
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (wakeLock == null) {
                wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tandem:transfer_active")
            }
            wakeLock?.acquire(30 * 60 * 1000L) // 30 min safety bound

            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (wifiLock == null) {
                wifiLock = wifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "tandem:wifi_perf")
            }
            wifiLock?.acquire()
        } else {
            // Release immediately when transfer finishes
            wakeLock?.let { if (it.isHeld) it.release() }
            wifiLock?.let { if (it.isHeld) it.release() }
        }
    }

    override fun onDestroy() {
        stopEngineNative()
        multicastLock?.let { if (it.isHeld) it.release() }
        wakeLock?.let { if (it.isHeld) it.release() }
        wifiLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Tandem Sync Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows active Tandem peer-to-peer sync status"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(true)
            .build()
    }

    // JNI Native methods implemented by libtandemd.so
    private external fun startEngineNative(configPath: String, syncthingPath: String): Int
    private external fun stopEngineNative(): Int
}
