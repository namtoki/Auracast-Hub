package com.auracast.auracast_hub.network

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Plugin to manage Android network features required for multicast discovery.
 * Acquires and releases MulticastLock to allow UDP multicast reception.
 */
class NetworkPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.spatialsync.network")
        channel.setMethodCallHandler(this)

        // Automatically acquire multicast lock when plugin is attached
        acquireMulticastLock()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        releaseMulticastLock()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "acquireMulticastLock" -> {
                acquireMulticastLock()
                result.success(true)
            }
            "releaseMulticastLock" -> {
                releaseMulticastLock()
                result.success(true)
            }
            "isMulticastLockHeld" -> {
                result.success(multicastLock?.isHeld == true)
            }
            else -> result.notImplemented()
        }
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return

        try {
            val wifiManager = context.applicationContext
                .getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock("SpatialSyncMulticast")
            multicastLock?.setReferenceCounted(true)
            multicastLock?.acquire()
        } catch (e: Exception) {
            // Log but don't crash
        }
    }

    private fun releaseMulticastLock() {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
            multicastLock = null
        } catch (e: Exception) {
            // Ignore
        }
    }
}
