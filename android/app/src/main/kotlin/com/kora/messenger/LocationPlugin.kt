package com.kora.messenger

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Real GPS support for the "Send Location" attachment and Live Location
 * sharing. Uses Android's built-in LocationManager — no extra
 * dependencies. Returns the freshest fix available: last known location
 * if it is recent (< 2 minutes), otherwise a one-shot fresh request.
 */
class LocationPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "kora.location"
        private const val MAX_LAST_KNOWN_AGE_MS = 2 * 60 * 1000L
        private const val FRESH_TIMEOUT_MS = 12 * 1000L
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentLocation" -> getCurrentLocation(result)
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun payload(loc: Location): Map<String, Any> = mapOf(
        "latitude" to loc.latitude,
        "longitude" to loc.longitude,
        "accuracy" to loc.accuracy.toDouble(),
        "timestamp" to loc.time
    )

    @SuppressLint("MissingPermission")
    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("permission_denied", "Location permission has not been granted", null)
            return
        }

        val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val main = Handler(Looper.getMainLooper())

        // 1. Freshest recent last-known fix wins immediately.
        var best: Location? = null
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)) {
            try {
                val loc = lm.getLastKnownLocation(provider)
                if (loc != null && (best == null || loc.time > best!!.time)) best = loc
            } catch (_: SecurityException) {
                // Permission revoked between check and use — fall through.
            } catch (_: IllegalArgumentException) {
                // Provider not available on this device.
            }
        }
        if (best != null && System.currentTimeMillis() - best.time < MAX_LAST_KNOWN_AGE_MS) {
            result.success(payload(best))
            return
        }

        // 2. Otherwise request one fresh fix (with a timeout).
        var settled = false
        var listener: LocationListener? = null
        fun finish(loc: Location?) {
            val alreadySettled = synchronized(this) {
                if (settled) return@synchronized true
                settled = true
                false
            }
            if (alreadySettled) return
            try {
                listener?.let { lm.removeUpdates(it) }
            } catch (_: Exception) {}
            if (loc != null) result.success(payload(loc))
            else result.error("unavailable", "No location available. Make sure location services are on.", null)
        }
        listener = object : LocationListener {
            override fun onLocationChanged(location: Location) { finish(location) }
            override fun onProviderDisabled(provider: String) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }

        var requested = false
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            try {
                if (lm.isProviderEnabled(provider)) {
                    lm.requestLocationUpdates(provider, 0L, 0f, listener!!, Looper.getMainLooper())
                    requested = true
                }
            } catch (_: SecurityException) {
            } catch (_: IllegalArgumentException) {
            }
        }
        if (!requested) {
            // No provider enabled — fall back to stale last-known if any.
            if (best != null) result.success(payload(best))
            else result.error("unavailable", "Location services are turned off.", null)
            return
        }
        // Safety timeout — use the stale fix if we got one.
        main.postDelayed({
            val alreadySettled = synchronized(this) {
                if (settled) true
                else {
                    settled = true
                    false
                }
            }
            if (alreadySettled) return@postDelayed
            try { listener?.let { lm.removeUpdates(it) } } catch (_: Exception) {}
            if (best != null) result.success(payload(best))
            else result.error("timeout", "Could not get a location fix in time.", null)
        }, FRESH_TIMEOUT_MS)
    }
}
