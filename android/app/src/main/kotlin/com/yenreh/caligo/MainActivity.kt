package com.yenreh.caligo

import android.location.Geocoder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Android's own geocoder: Google's, through Play services, with no
        // key or quota to manage
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "caligo/geocoder")
            .setMethodCallHandler { call, result ->
                if (call.method != "search") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (!Geocoder.isPresent()) {
                    result.success(emptyList<Map<String, Any>>())
                    return@setMethodCallHandler
                }
                val query = call.argument<String>("query").orEmpty()
                val south = call.argument<Double>("south") ?: 0.0
                val west = call.argument<Double>("west") ?: 0.0
                val north = call.argument<Double>("north") ?: 0.0
                val east = call.argument<Double>("east") ?: 0.0
                // Asked over the network: off the main thread
                thread {
                    try {
                        @Suppress("DEPRECATION")
                        val found = Geocoder(this, Locale.forLanguageTag("es-CO"))
                            .getFromLocationName(query, 5, south, west, north, east)
                            .orEmpty()
                            .map {
                                mapOf(
                                    "latitude" to it.latitude,
                                    "longitude" to it.longitude,
                                    "line" to (it.getAddressLine(0) ?: ""),
                                )
                            }
                        runOnUiThread { result.success(found) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("unavailable", e.message, null) }
                    }
                }
            }
    }
}
