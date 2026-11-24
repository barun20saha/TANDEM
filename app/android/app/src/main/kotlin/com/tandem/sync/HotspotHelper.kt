package com.tandem.sync

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import androidx.annotation.RequiresApi

/**
 * Manages Android Local-Only Hotspot creation with QR payload generation (Section 4.6 & 5.3 Flow B).
 */
class HotspotHelper(private val context: Context) {

    private val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private var reservation: WifiManager.LocalOnlyHotspotReservation? = null

    data class HotspotCredentials(
        val ssid: String,
        val passphrase: String,
        val qrPayload: String
    )

    @RequiresApi(Build.VERSION_CODES.O)
    fun startLocalHotspot(onReady: (HotspotCredentials) -> Unit, onError: (Int) -> Unit) {
        wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
            override fun onStarted(res: WifiManager.LocalOnlyHotspotReservation) {
                reservation = res
                val config = res.wifiConfiguration
                val ssid = config?.SSID ?: "Tandem-Hotspot"
                val pass = config?.preSharedKey ?: ""

                // Format standard Wi-Fi QR code: WIFI:T:WPA;S:<ssid>;P:<pass>;;
                val qr = "WIFI:T:WPA;S:$ssid;P:$pass;;"
                onReady(HotspotCredentials(ssid, pass, qr))
            }

            override fun onStopped() {
                reservation = null
            }

            override fun onFailed(reason: Int) {
                onError(reason)
            }
        }, null)
    }

    fun stopHotspot() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            reservation?.close()
            reservation = null
        }
    }
}
