package com.cuehq.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.cuehq.app.widget.CueWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterFragmentActivity() {
    private val WIDGET_CHANNEL = "widget_channel"
    private val NAVIGATION_CHANNEL = "navigation_channel"
    private val ASSISTANT_CHANNEL = "assistant_channel"
    private val TAG = "MainActivity"
    
    private var assistantMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup Assistant Channel
        assistantMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSISTANT_CHANNEL)
        
        // Handle widget updates
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAndroidWidget" -> {
                    try {
                        Log.d(TAG, "📱 updateAndroidWidget method called")

                        // Check SharedPreferences content
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val data = prefs.getString("flutter.widget_data", null)
                        Log.d(TAG, "📱 Current SharedPreferences data: ${data?.take(200)}...")

                        // Get widget manager and IDs
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        val ids = appWidgetManager.getAppWidgetIds(
                            ComponentName(this, CueWidgetProvider::class.java)
                        )

                        Log.d(TAG, "📱 Found ${ids.size} widgets to update: ${ids.toList()}")

                        if (ids.isNotEmpty()) {
                            // Method 1: Direct update via provider
                            for (id in ids) {
                                CueWidgetProvider.updateAppWidget(this, appWidgetManager, id)
                            }

                            // Method 2: Send broadcast
                            val intent = Intent(this, CueWidgetProvider::class.java).apply {
                                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                            }
                            sendBroadcast(intent)

                            // Method 3: Custom action
                            val customIntent = Intent("com.cuehq.app.UPDATE_WIDGET")
                            customIntent.setComponent(ComponentName(this, CueWidgetProvider::class.java))
                            sendBroadcast(customIntent)

                            Log.d(TAG, "✅ Widget update completed (3 methods)")
                        } else {
                            Log.w(TAG, "⚠️ No widgets found to update")
                        }

                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error updating widget: ${e.message}", e)
                        result.error("WIDGET_UPDATE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Handle navigation to create reminder
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        intent?.let { receivedIntent ->
            Log.d(TAG, "🎯 Handling intent: action=${receivedIntent.action}")
            
            when (receivedIntent.action) {
                "CREATE_REMINDER" -> {
                    Log.d(TAG, "📱 Navigating to create reminder from widget")
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, NAVIGATION_CHANNEL).invokeMethod("navigateToCreateReminder", null)
                    }
                }
                "actions.intent.CREATE_THING",
                "actions.intent.CREATE_REMINDER",
                "actions.intent.SCHEDULE_EVENT",
                Intent.ACTION_VIEW -> {
                    handleAssistantIntent(receivedIntent)
                }
            }
        }
    }
    
    private fun handleAssistantIntent(intent: Intent) {
        try {
            Log.d(TAG, "🎙️ Google Assistant intent received")
            Log.d(TAG, "Intent action: ${intent.action}")
            Log.d(TAG, "Intent data: ${intent.data}")
            Log.d(TAG, "Intent extras: ${intent.extras?.keySet()?.joinToString()}")
            
            val reminderData = mutableMapOf<String, Any?>()
            
            // Parse from deep link (cue://reminder/create?text=xxx&time=xxx&date=xxx)
            intent.data?.let { uri ->
                Log.d(TAG, "📎 Deep link URI: $uri")
                uri.getQueryParameter("text")?.let { 
                    reminderData["text"] = it
                    Log.d(TAG, "  - text: $it")
                }
                uri.getQueryParameter("time")?.let { 
                    reminderData["time"] = it
                    Log.d(TAG, "  - time: $it")
                }
                uri.getQueryParameter("date")?.let { 
                    reminderData["date"] = it
                    Log.d(TAG, "  - date: $it")
                }
            }
            
            // Parse from intent extras (alternative format)
            intent.extras?.let { bundle ->
                // From Google Assistant capability (CREATE_THING)
                bundle.getString("reminder_name")?.let { 
                    reminderData["text"] = it
                    Log.d(TAG, "  - reminder_name: $it")
                }
                bundle.getString("reminder_time")?.let { 
                    parseDateTime(it, reminderData)
                    Log.d(TAG, "  - reminder_time: $it")
                }
                
                // Try to get reminder text (other formats)
                bundle.getString("reminder.text")?.let { 
                    if (!reminderData.containsKey("text")) {
                        reminderData["text"] = it
                        Log.d(TAG, "  - reminder.text: $it")
                    }
                }
                bundle.getString("android.intent.extra.TEXT")?.let { 
                    if (!reminderData.containsKey("text")) {
                        reminderData["text"] = it
                        Log.d(TAG, "  - extra.TEXT: $it")
                    }
                }
                
                // Try to get date/time from various possible fields
                bundle.getString("reminder.dateTime")?.let { 
                    if (!reminderData.containsKey("time") && !reminderData.containsKey("date")) {
                        parseDateTime(it, reminderData)
                        Log.d(TAG, "  - reminder.dateTime: $it")
                    }
                }
                bundle.getString("android.intent.extra.TIME")?.let { 
                    if (!reminderData.containsKey("time")) {
                        reminderData["time"] = it
                        Log.d(TAG, "  - extra.TIME: $it")
                    }
                }
                bundle.getLong("android.intent.extra.ALARM_TIME", -1).takeIf { it != -1L }?.let { timestamp ->
                    if (!reminderData.containsKey("time") && !reminderData.containsKey("date")) {
                        val calendar = Calendar.getInstance().apply { timeInMillis = timestamp }
                        reminderData["date"] = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)
                        reminderData["time"] = SimpleDateFormat("HH:mm", Locale.US).format(calendar.time)
                        Log.d(TAG, "  - ALARM_TIME: ${reminderData["date"]} ${reminderData["time"]}")
                    }
                }
            }
            
            // If we have data, send it to Flutter
            if (reminderData.isNotEmpty()) {
                Log.d(TAG, "✅ Sending reminder data to Flutter: $reminderData")
                sendReminderDataToFlutter(reminderData)
            } else {
                Log.w(TAG, "⚠️ No reminder data found in intent, opening empty create screen")
                // Still open create screen, but empty
                sendReminderDataToFlutter(emptyMap())
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling Assistant intent: ${e.message}", e)
            e.printStackTrace()
            // Fallback: open create screen anyway
            sendReminderDataToFlutter(emptyMap())
        }
    }
    
    private fun parseDateTime(dateTimeString: String, reminderData: MutableMap<String, Any?>) {
        try {
            // ISO 8601 format: 2024-03-15T14:30:00Z
            val formats = listOf(
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.US),
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US),
                SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US),
                SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)
            )
            
            for (format in formats) {
                try {
                    val date = format.parse(dateTimeString)
                    date?.let {
                        val calendar = Calendar.getInstance().apply { time = it }
                        reminderData["date"] = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(it)
                        reminderData["time"] = SimpleDateFormat("HH:mm", Locale.US).format(it)
                        return
                    }
                } catch (e: Exception) {
                    continue
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing dateTime: ${e.message}")
        }
    }
    
    private fun sendReminderDataToFlutter(data: Map<String, Any?>) {
        assistantMethodChannel?.invokeMethod("handleAssistantReminder", data)
            ?: Log.e(TAG, "❌ Assistant channel not initialized")
    }
}
