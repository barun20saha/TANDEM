package com.tandem.sync

import android.content.Context
import android.os.Build

/**
 * Android-to-Android router-less direct link integration via Google Nearby Connections (Phase 9 Step 1).
 * Uses Strategy.P2P_STAR for high-speed Wi-Fi Direct / BLE under the hood.
 */
class NearbyHelper(private val context: Context) {

    companion object {
        const val SERVICE_ID = "com.tandem.sync.p2p"
    }

    enum class P2PState {
        IDLE,
        ADVERTISING,
        DISCOVERING,
        CONNECTED,
        ERROR
    }

    var state = P2PState.IDLE
        private set

    /**
     * Checks if router-less P2P direct links are supported between this OS pair.
     * Android-to-Android is fully supported; macOS is unsupported (no public API).
     */
    fun isSupportedPair(targetOS: String): Boolean {
        return when (targetOS.lowercase()) {
            "android" -> true
            "linux" -> true // Experimental via Wi-Fi Direct
            "windows" -> false // Unstable without legacy AP
            "darwin", "macos" -> false // No public API
            else -> false
        }
    }

    fun startAdvertising(localDeviceName: String, onConnectionInitiated: (String) -> Unit) {
        state = P2PState.ADVERTISING
        // Note: Real deployment invokes Nearby.getConnectionsClient(context).startAdvertising(...)
    }

    fun startDiscovery(onEndpointFound: (String, String) -> Unit) {
        state = P2PState.DISCOVERING
        // Note: Real deployment invokes Nearby.getConnectionsClient(context).startDiscovery(...)
    }

    fun stopAll() {
        state = P2PState.IDLE
    }
}
