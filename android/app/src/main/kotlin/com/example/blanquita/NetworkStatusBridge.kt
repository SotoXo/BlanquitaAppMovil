package com.example.blanquita

import android.app.Activity
import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.SocketTimeoutException
import java.util.concurrent.Executors

/** Observes Wi-Fi and probes configured TCP endpoints. No SSID, scans or binding. */
class NetworkStatusBridge(private val activity: Activity, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val connectivity = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val wifi = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val methodChannel = MethodChannel(messenger, "blanquita/network")
    private val eventChannel = EventChannel(messenger, "blanquita/network/events")
    private val lock = Any()
    private val capabilities = mutableMapOf<Network, NetworkCapabilities>()
    private val properties = mutableMapOf<Network, LinkProperties>()
    private var defaultNetwork: Network? = null
    private var defaultCapabilities: NetworkCapabilities? = null
    private var wifiCallback: ConnectivityManager.NetworkCallback? = null
    private var defaultCallback: ConnectivityManager.NetworkCallback? = null
    private var events: EventChannel.EventSink? = null
    @Volatile private var generation = 0
    private val probes = Executors.newSingleThreadExecutor()

    init {
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "probeWifiTcp") {
                val host = call.argument<String>("host")
                val port = call.argument<Int>("port")
                if (host.isNullOrBlank() || port == null || port !in 1..65535) {
                    result.error("INVALID_ENDPOINT", "Dirección o puerto no válido.", null)
                } else {
                    probeWifiTcp(host, port, result)
                }
            } else if (call.method != "getWifiStatus") {
                result.notImplemented()
            } else {
                try {
                    seedCurrentState()
                    result.success(snapshot("refresh"))
                } catch (error: Exception) {
                    Log.e("BLANQUITA_NETWORK", "Network observation failed", error)
                    result.error("NETWORK_OBSERVATION_FAILED", "No se pudo consultar el estado Wi-Fi de Android.", error.javaClass.simpleName)
                }
            }
        }
        eventChannel.setStreamHandler(this)
    }

    // A snapshot is also used to initialize callbacks and explicitly refresh.
    @Suppress("DEPRECATION")
    private fun seedCurrentState() = synchronized(lock) {
        capabilities.clear()
        properties.clear()
        for (network in connectivity.allNetworks) {
            val caps = connectivity.getNetworkCapabilities(network) ?: continue
            if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) && !caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                capabilities[network] = caps
                connectivity.getLinkProperties(network)?.let { properties[network] = it }
            }
        }
        defaultNetwork = connectivity.activeNetwork
        defaultCapabilities = defaultNetwork?.let { connectivity.getNetworkCapabilities(it) }
    }

    private fun ipv4(network: Network): String? = properties[network]?.linkAddresses
        ?.map { it.address }?.firstOrNull { it is Inet4Address && !it.isLoopbackAddress }?.hostAddress

    // Only an explicitly configured host/port. No application data is sent.
    private fun probeWifiTcp(host: String, port: Int, result: MethodChannel.Result) {
        seedCurrentState()
        val network = synchronized(lock) { capabilities.keys.firstOrNull { ipv4(it) != null } }
        if (network == null) {
            result.success(mapOf("connected" to false, "errorCode" to "WIFI_UNAVAILABLE", "technicalMessage" to "No available Wi-Fi network"))
            return
        }
        probes.execute {
            val started = System.nanoTime()
            val value = try {
                network.socketFactory.createSocket().use { socket ->
                    socket.connect(InetSocketAddress(network.getByName(host), port), 3000)
                }
                mapOf("connected" to true, "errorCode" to null, "technicalMessage" to "TCP connected through Wi-Fi; no application bytes sent")
            } catch (error: Exception) {
                val code = if (error is SocketTimeoutException) "CONNECT_TIMEOUT"
                    else if (error.message?.contains("refused", true) == true) "CONNECTION_REFUSED"
                    else if (error.message?.contains("EHOSTUNREACH", true) == true ||
                        error.message?.contains("ENETUNREACH", true) == true ||
                        error.message?.contains("No route to host", true) == true) "HOST_UNREACHABLE"
                    else if (error is java.net.UnknownHostException) "HOST_LOOKUP_FAILED"
                    else if (error is SecurityException) "NETWORK_PERMISSION" else "TCP_ERROR"
                mapOf("connected" to false, "errorCode" to code, "technicalMessage" to "${error.javaClass.simpleName}: ${error.message}")
            }
            activity.runOnUiThread { result.success(value + mapOf("elapsedMs" to (System.nanoTime() - started) / 1_000_000, "host" to host, "port" to port, "route" to "wifi")) }
        }
    }

    @Suppress("DEPRECATION")
    private fun snapshot(reason: String): Map<String, Any?> = synchronized(lock) {
        val selected = defaultNetwork?.takeIf { capabilities.containsKey(it) }
            ?: capabilities.keys.firstOrNull { ipv4(it) != null }
            ?: capabilities.keys.firstOrNull()
        val caps = selected?.let { capabilities[it] }
        val enabled = wifi.isWifiEnabled
        val connected = enabled && caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        val info = if (connected) {
            if (Build.VERSION.SDK_INT >= 29) caps?.transportInfo as? WifiInfo else null
        } else null
        val fallback = if (connected && (info == null || info.rssi !in -126..-1)) wifi.connectionInfo else null
        val rssi = info?.rssi?.takeIf { it in -126..-1 } ?: fallback?.rssi?.takeIf { it in -126..-1 }
        val speed = (info?.linkSpeed ?: fallback?.linkSpeed)?.takeIf { it > 0 }
        mapOf(
            "supported" to true,
            "wifiEnabled" to enabled,
            "connected" to connected,
            "localIpv4" to selected?.let { ipv4(it) },
            "rssiDbm" to rssi,
            "linkSpeedMbps" to speed,
            "defaultRouteWifi" to defaultCapabilities?.let {
                it.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) && !it.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            },
            "internetValidated" to caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED),
            "networkHandle" to selected?.networkHandle?.toString(),
            "reason" to reason
        )
    }

    private fun publish(token: Int, reason: String) {
        if (token != generation) return
        val value = try { snapshot(reason) } catch (error: Exception) {
            Log.e("BLANQUITA_NETWORK", "Network event failed", error)
            activity.runOnUiThread {
                if (token == generation) events?.error("NETWORK_OBSERVATION_FAILED", "No se pudo actualizar el estado Wi-Fi.", error.javaClass.simpleName)
            }
            return
        }
        activity.runOnUiThread { if (token == generation) events?.success(value) }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        stopCallbacks()
        events = sink
        val token = generation
        try {
            seedCurrentState()
            val listener = object : ConnectivityManager.NetworkCallback() {
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                    if (token != generation) return
                    synchronized(lock) { if (token != generation) return; capabilities[network] = caps }
                    publish(token, "capabilities_changed")
                }
                override fun onLinkPropertiesChanged(network: Network, link: LinkProperties) {
                    if (token != generation) return
                    synchronized(lock) { if (token != generation) return; properties[network] = link }
                    publish(token, "link_changed")
                }
                override fun onLost(network: Network) {
                    if (token != generation) return
                    synchronized(lock) { if (token != generation) return; capabilities.remove(network); properties.remove(network) }
                    publish(token, "wifi_lost")
                }
            }
            connectivity.registerNetworkCallback(NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build(), listener)
            wifiCallback = listener
            val routeListener = object : ConnectivityManager.NetworkCallback() {
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                    if (token != generation) return
                    synchronized(lock) { if (token != generation) return; defaultNetwork = network; defaultCapabilities = caps }
                    publish(token, "default_route_changed")
                }
                override fun onLost(network: Network) {
                    if (token != generation) return
                    synchronized(lock) {
                        if (token != generation) return
                        if (defaultNetwork == network) { defaultNetwork = null; defaultCapabilities = null }
                    }
                    publish(token, "default_route_lost")
                }
            }
            connectivity.registerDefaultNetworkCallback(routeListener)
            defaultCallback = routeListener
            publish(token, "observation_started")
        } catch (error: Exception) {
            stopCallbacks()
            Log.e("BLANQUITA_NETWORK", "Could not observe network", error)
            sink.error("NETWORK_OBSERVATION_FAILED", "No se pudo observar el enlace Wi-Fi de Android.", error.javaClass.simpleName)
        }
    }

    private fun stopCallbacks() {
        ++generation
        for (callback in listOfNotNull(wifiCallback, defaultCallback)) {
            try { connectivity.unregisterNetworkCallback(callback) }
            catch (error: Exception) { Log.w("BLANQUITA_NETWORK", "Callback cleanup failed", error) }
        }
        wifiCallback = null
        defaultCallback = null
        events = null
    }

    override fun onCancel(arguments: Any?) = stopCallbacks()
    fun dispose() {
        stopCallbacks()
        probes.shutdownNow()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
