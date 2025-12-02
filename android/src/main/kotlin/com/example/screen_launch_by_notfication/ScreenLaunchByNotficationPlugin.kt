package com.example.screen_launch_by_notfication

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject

/** ScreenLaunchByNotficationPlugin */
class ScreenLaunchByNotficationPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {
    // The MethodChannel that will the communication between Flutter and native Android
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "launch_channel")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        checkNotificationIntent(binding.activity.intent)
        
        // Listen for new intents (when app is brought to foreground)
        binding.addOnNewIntentListener { intent ->
            binding.activity.setIntent(intent)
            checkNotificationIntent(intent)
            true
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        checkNotificationIntent(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    private fun checkNotificationIntent(intent: Intent?) {
        val ctx = context ?: return
        val prefs = ctx.getSharedPreferences("launchStore", Context.MODE_PRIVATE)

        // Check if app opened by notification tap
        // flutter_local_notifications uses this action when notification is tapped
        val isFromFlutterNotification = intent?.action == "com.dexterous.flutterlocalnotifications.NOTIFICATION_TAPPED" ||
                intent?.hasExtra("notification_launch_app") == true
        val isFromCustomNotification = intent?.extras?.getBoolean("fromNotification") == true

        // Also check if payload exists (indicates notification tap)
        val hasPayload = intent?.extras?.containsKey("payload") == true

        if (isFromFlutterNotification || isFromCustomNotification || hasPayload) {
            prefs.edit().putBoolean("openFromNotification", true).apply()

            // Extract notification payload
            val payload = JSONObject()
            
            // Get payload from flutter_local_notifications
            val flutterPayload = intent?.extras?.getString("payload")
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
            intent?.extras?.keySet()?.forEach { key ->
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

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "isFromNotification" -> {
                val ctx = context ?: run {
                    result.error("ERROR", "Context not available", null)
                    return
                }
                val prefs = ctx.getSharedPreferences("launchStore", Context.MODE_PRIVATE)
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
                    val ctx = context ?: run {
                        result.error("ERROR", "Context not available", null)
                        return
                    }
                    val payload = call.arguments as? String ?: "{}"
                    val prefs = ctx.getSharedPreferences("launchStore", Context.MODE_PRIVATE)
                    prefs.edit().putString("pendingNotificationPayload", payload).apply()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to store payload: ${e.message}", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}
