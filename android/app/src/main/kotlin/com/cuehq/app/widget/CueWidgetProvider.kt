package com.cuehq.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.cuehq.app.R
import com.cuehq.app.MainActivity
import org.json.JSONArray
import org.json.JSONException

class CueWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WIDGET_TASKS_KEY = "flutter.widget_data"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_cue)

            // Read tasks from SharedPreferences
            val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val tasksJson = prefs.getString(WIDGET_TASKS_KEY, "[]")
            val tasks = parseTasksFromJson(tasksJson)

            // Update header
            views.setTextViewText(R.id.header_title, "TODAY")
            views.setTextViewText(R.id.task_count, "${tasks.size} Tasks")

            // Update tasks (show up to 3)
            if (tasks.isNotEmpty()) {
                views.setTextViewText(R.id.task_1_name, tasks[0].name)
                views.setTextViewText(R.id.task_1_time, tasks[0].time)
                views.setTextViewText(R.id.task_1_icon, tasks[0].icon)
                views.setViewVisibility(R.id.task_1, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.task_1, View.GONE)
            }

            if (tasks.size > 1) {
                views.setTextViewText(R.id.task_2_name, tasks[1].name)
                views.setTextViewText(R.id.task_2_time, tasks[1].time)
                views.setTextViewText(R.id.task_2_icon, tasks[1].icon)
                views.setViewVisibility(R.id.task_2, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.task_2, View.GONE)
            }

            if (tasks.size > 2) {
                views.setTextViewText(R.id.task_3_name, tasks[2].name)
                views.setTextViewText(R.id.task_3_time, tasks[2].time)
                views.setTextViewText(R.id.task_3_icon, tasks[2].icon)
                views.setViewVisibility(R.id.task_3, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.task_3, View.GONE)
            }

            // Open app when widget is tapped
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Add button to open create reminder screen
            val addReminderIntent = Intent(context, MainActivity::class.java).apply {
                action = "CREATE_REMINDER"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val addReminderPendingIntent = PendingIntent.getActivity(
                context, 1, addReminderIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.add_reminder_button, addReminderPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun parseTasksFromJson(jsonString: String?): List<Task> {
            val tasks = mutableListOf<Task>()
            if (jsonString.isNullOrEmpty()) return tasks

            try {
                val jsonArray = JSONArray(jsonString)
                for (i in 0 until jsonArray.length()) {
                    val jsonObject = jsonArray.getJSONObject(i)
                    val name = jsonObject.optString("name", "")
                    val time = jsonObject.optString("time", "")
                    val icon = jsonObject.optString("icon", "")
                    if (name.isNotEmpty()) {
                        tasks.add(Task(name, time, icon))
                    }
                }
            } catch (e: JSONException) {
                // Handle parsing error, return empty list
            }
            return tasks
        }
    }

    data class Task(val name: String, val time: String, val icon: String)
}
