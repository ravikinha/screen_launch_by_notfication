package com.example.screen_launch_by_notfication_example

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "launch_channel"
    private val NOTIFICATION_CHANNEL_ID = "test_notification_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        createNotificationChannel()
        checkNotificationIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkNotificationIntent(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Test Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Channel for test notifications"
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun checkNotificationIntent(intent: android.content.Intent) {
        val prefs = getSharedPreferences("launchStore", MODE_PRIVATE)

        // Check if app opened by notification tap
        // flutter_local_notifications uses this action when notification is tapped
        val isFromFlutterNotification = intent.action == "com.dexterous.flutterlocalnotifications.NOTIFICATION_TAPPED" ||
                intent.hasExtra("notification_launch_app") // Alternative check
        val isFromCustomNotification = intent.extras?.getBoolean("fromNotification") == true

        // Also check if payload exists (indicates notification tap)
        val hasPayload = intent.extras?.containsKey("payload") == true

        if (isFromFlutterNotification || isFromCustomNotification || hasPayload) {
            prefs.edit().putBoolean("openFromNotification", true).apply()

            // Extract notification payload
            val payload = JSONObject()
            
            // Get payload from flutter_local_notifications
            val flutterPayload = intent.extras?.getString("payload")
            if (!flutterPayload.isNullOrEmpty()) {
                try {
                    // Try to parse as JSON and merge
                    val payloadObj = JSONObject(flutterPayload)
                    payloadObj.keys().forEach { key ->
                        payload.put(key, payloadObj.get(key))
                    }
                } catch (e: Exception) {
                    // If payload is not JSON, store it as is
                    payload.put("payload", flutterPayload)
                }
            }
            
            // Also check for stored payload (in case notification was sent before)
            val storedPayload = prefs.getString("pendingNotificationPayload", null)
            if (storedPayload != null) {
                try {
                    val storedObj = JSONObject(storedPayload)
                    storedObj.keys().forEach { key ->
                        if (!payload.has(key)) { // Don't override intent payload
                            payload.put(key, storedObj.get(key))
                        }
                    }
                    // Clear stored payload after use
                    prefs.edit().remove("pendingNotificationPayload").apply()
                } catch (e: Exception) {
                    // Ignore parse errors
                }
            }
            
            // Also extract other intent extras
            intent.extras?.keySet()?.forEach { key ->
                if (key != "payload") { // Don't duplicate payload
                    when (val value = intent.extras?.get(key)) {
                        is String -> payload.put(key, value)
                        is Int -> payload.put(key, value)
                        is Boolean -> payload.put(key, value)
                        is Double -> payload.put(key, value)
                        else -> payload.put(key, value.toString())
                    }
                }
            }
            
            // Store payload as JSON string
            if (payload.length() > 0) {
                prefs.edit().putString("notificationPayload", payload.toString()).apply()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isFromNotification" -> {
                        val prefs = getSharedPreferences("launchStore", MODE_PRIVATE)
                        val isFromNotification = prefs.getBoolean("openFromNotification", false)
                        val payload = prefs.getString("notificationPayload", null)
                        
                        val response = mapOf(
                            "isFromNotification" to isFromNotification,
                            "payload" to (payload ?: "{}")
                        )
                        
                        result.success(response)

                        // clear after reading
                        prefs.edit()
                            .putBoolean("openFromNotification", false)
                            .putString("notificationPayload", null)
                            .apply()
                    }
                    "storeNotificationPayload" -> {
                        try {
                            val payload = call.arguments as? String ?: "{}"
                            val prefs = getSharedPreferences("launchStore", MODE_PRIVATE)
                            prefs.edit().putString("pendingNotificationPayload", payload).apply()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to store payload: ${e.message}", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

}
