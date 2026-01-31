package com.cuehq.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.util.Log
import org.json.JSONArray
import org.json.JSONException
import com.cuehq.app.R
import com.cuehq.app.MainActivity
import android.net.Uri
import java.text.SimpleDateFormat
import java.util.*

class CueWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "onReceive: ${intent.action}")

        if (intent.action == "com.cuehq.app.UPDATE_WIDGET") {
            Log.d(TAG, "Custom update action received")
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, CueWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "Widget disabled")
    }

    companion object {
        private const val TAG = "CueWidget"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WIDGET_DATA_KEY = "flutter.widget_data"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            Log.d(TAG, "updateAppWidget called for widget ID: $appWidgetId")
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // Try multiple SharedPreferences sources
            var widgetDataJson: String? = null

            // Try FlutterSharedPreferences
            val flutterPrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            widgetDataJson = flutterPrefs.getString(WIDGET_DATA_KEY, null)
            Log.d(TAG, "FlutterSharedPreferences ($PREFS_NAME) - Data: $widgetDataJson")

            // List all keys in FlutterSharedPreferences
            val allKeys = flutterPrefs.all.keys
            Log.d(TAG, "All keys in FlutterSharedPreferences (${allKeys.size}): ${allKeys.take(10)}")

            // Try to read the raw XML file directly
            try {
                val prefsFile = java.io.File(context.applicationInfo.dataDir + "/shared_prefs/FlutterSharedPreferences.xml")
                if (prefsFile.exists()) {
                    val fileContent = prefsFile.readText()
                    Log.d(TAG, "XML file exists, size: ${prefsFile.length()} bytes")
                    Log.d(TAG, "XML content (first 500 chars): ${fileContent.take(500)}")
                } else {
                    Log.w(TAG, "FlutterSharedPreferences.xml file does not exist!")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading XML file: ${e.message}", e)
            }

            // If not found, try default SharedPreferences
            if (widgetDataJson == null) {
                val defaultPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
                widgetDataJson = defaultPrefs.getString(WIDGET_DATA_KEY, null)
                Log.d(TAG, "Default preferences (${context.packageName}_preferences) - Data: $widgetDataJson")
            }

            // List all SharedPreferences files for debugging
            val prefsDir = context.applicationInfo.dataDir + "/shared_prefs"
            val prefsFiles = java.io.File(prefsDir).listFiles()
            Log.d(TAG, "Available SharedPreferences files:")
            prefsFiles?.forEach { file ->
                Log.d(TAG, "  - ${file.name}")
            }

            if (widgetDataJson != null && widgetDataJson.isNotEmpty()) {
                try {
                    val reminders = JSONArray(widgetDataJson)
                    Log.d(TAG, "Successfully parsed ${reminders.length()} reminders")
                    updateWidgetContent(context, views, reminders)
                } catch (e: JSONException) {
                    Log.e(TAG, "Error parsing JSON: ${e.message}", e)
                    showEmptyState(views)
                }
            } else {
                Log.w(TAG, "No widget data found in any SharedPreferences")
                showEmptyState(views)
            }

            // Set up click intent to open app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            Log.d(TAG, "Widget updated successfully")
        }

        private fun updateWidgetContent(
            context: Context,
            views: RemoteViews,
            reminders: JSONArray
        ) {
            val count = reminders.length()
            Log.d(TAG, "updateWidgetContent: $count reminders")

            if (count == 0) {
                showEmptyState(views)
                return
            }

            // Show reminder count
            views.setTextViewText(R.id.reminder_count, "$count reminder${if (count == 1) "" else "s"} today")

            // Update up to 5 reminders
            val reminderIds = listOf(
                R.id.reminder_1,
                R.id.reminder_2,
                R.id.reminder_3,
                R.id.reminder_4,
                R.id.reminder_5
            )

            for (i in 0 until minOf(5, count)) {
                try {
                    val reminder = reminders.getJSONObject(i)
                    val name = reminder.getString("name")
                    val time = reminder.getString("time")

                    Log.d(TAG, "Reminder $i: $name at $time")
                    views.setTextViewText(reminderIds[i], "• $time - $name")
                    views.setViewVisibility(reminderIds[i], android.view.View.VISIBLE)
                } catch (e: JSONException) {
                    Log.e(TAG, "Error reading reminder $i: ${e.message}", e)
                }
            }

            // Hide unused reminder slots
            for (i in count until 5) {
                views.setViewVisibility(reminderIds[i], android.view.View.GONE)
            }
        }

        private fun showEmptyState(views: RemoteViews) {
            Log.d(TAG, "Showing empty state")
            views.setTextViewText(R.id.reminder_count, "No reminders today")

            // Hide all reminder items
            val reminderIds = listOf(
                R.id.reminder_1,
                R.id.reminder_2,
                R.id.reminder_3,
                R.id.reminder_4,
                R.id.reminder_5
            )

            for (id in reminderIds) {
                views.setViewVisibility(id, android.view.View.GONE)
            }
        }

        fun updateWidgets(context: Context) {
            Log.d(TAG, "updateWidgets called")
            val intent = Intent(context, CueWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(android.content.ComponentName(context, CueWidgetProvider::class.java))
            Log.d(TAG, "Updating ${ids.size} widgets")
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
        }
    }
}
