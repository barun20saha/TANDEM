package com.tandem.sync

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import java.io.FileDescriptor

/**
 * Handles network callbacks and explicit socket binding to Wi-Fi interfaces
 * on networks with no internet connection (Section 4.6).
 */
class NetworkManager(private val context: Context) {

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private var activeWifiNetwork: Network? = null

    fun registerNetworkCallback(onNetworkChanged: (Network?) -> Unit) {
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            // Explicitly do NOT require NET_CAPABILITY_INTERNET so local-only Wi-Fi connects
            .build()

        connectivityManager.registerNetworkCallback(request, object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                activeWifiNetwork = network
                onNetworkChanged(network)
            }

            override fun onLost(network: Network) {
                if (activeWifiNetwork == network) {
                    activeWifiNetwork = null
                    onNetworkChanged(null)
                }
            }
        })
    }

    /**
     * Binds an open file descriptor socket directly to the Wi-Fi network interface,
     * ensuring packets bypass cellular data even when the Wi-Fi has no upstream internet.
     */
    fun bindSocketToWifi(fileDescriptor: FileDescriptor): Boolean {
        return try {
            activeWifiNetwork?.bindSocket(fileDescriptor)
            true
        } catch (e: Exception) {
            false
        }
    }

    fun getActiveWifiNetwork(): Network? = activeWifiNetwork
}
