package com.cuehq.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.cuehq.app.widget.CueWidgetProvider

class MainActivity : FlutterFragmentActivity() {
    private val WIDGET_CHANNEL = "widget_channel"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
    }
}
