import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/reminders/domain/reminder_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class WidgetService {
  static const String _appGroupId = 'group.com.cue.app';
  static const String _widgetKey = 'todayReminders';
  static const MethodChannel _channel = MethodChannel('widget_channel');

  /// Update widget data with today's reminders (works on both iOS and Android)
  Future<void> updateWidget(List<Reminder> reminders) async {
    try {
      // Filter for today's reminders only using effectiveNextDueAt (same as home screen)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayReminders = reminders.where((reminder) {
        final reminderDate = DateTime(
          reminder.effectiveNextDueAt.year,
          reminder.effectiveNextDueAt.month,
          reminder.effectiveNextDueAt.day,
        );
        return reminderDate.isAtSameMomentAs(today) && !reminder.isCompleted;
      }).toList();

      // Sort by effectiveNextDueAt
      todayReminders.sort((a, b) => a.effectiveNextDueAt.compareTo(b.effectiveNextDueAt));

      // Convert to widget data format
      final widgetData = todayReminders.take(6).map((reminder) {
        final timeFormat = DateFormat('h:mm a');

        return {
          'id': reminder.id,
          'name': reminder.name,
          'time': timeFormat.format(reminder.effectiveNextDueAt),
          'iconName': _getSystemIconName(reminder.icon),
          'colorHex': _colorToHex(reminder.color),
        };
      }).toList();

      // Convert to JSON string
      final jsonString = jsonEncode(widgetData);

      print('📱 Widget Update - Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      print('📱 Widget Data JSON: $jsonString');
      print('📱 Number of reminders: ${widgetData.length}');

      if (Platform.isIOS) {
        // iOS: Send to native via method channel
        await _channel.invokeMethod('updateWidgetData', {'data': jsonString});
        await _channel.invokeMethod('reloadWidget');
        print('✅ iOS widget updated via method channel');
      } else if (Platform.isAndroid) {
        // Android: Save to SharedPreferences and update widget
        final prefs = await SharedPreferences.getInstance();

        // Important: Don't use "flutter." prefix - the plugin adds it automatically!
        // So "widget_data" becomes "flutter.widget_data" in the XML
        final key = 'widget_data';

        // Write the data
        final success = await prefs.setString(key, jsonString);
        print('📱 SharedPreferences write success: $success');
        print('📱 Stored key: $key (will be stored as flutter.$key)');

        // Force commit to disk
        await prefs.commit();
        print('📱 SharedPreferences committed to disk');

        // Wait a moment for the file to be written
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify data was written
        final storedData = prefs.getString(key);
        if (storedData != null) {
          print('📱 ✅ Verification SUCCESS - Data length: ${storedData.length} chars');
          print('📱 First 100 chars: ${storedData.substring(0, storedData.length > 100 ? 100 : storedData.length)}');
        } else {
          print('📱 ❌ Verification FAILED - Data is null after writing!');
        }

        // List all keys in SharedPreferences
        final allKeys = prefs.getKeys();
        print('📱 All SharedPreferences keys (${allKeys.length}): ${allKeys.take(10).toList()}');

        // Trigger widget update via method channel
        try {
          await _channel.invokeMethod('updateAndroidWidget');
          print('✅ Android widget update broadcast sent');
        } catch (e) {
          print('❌ Method channel error: $e');
          print('⚠️ Widget will update on next refresh');
        }
      }

      print('✅ Widget data updated: ${widgetData.length} reminders');
    } catch (e) {
      print('❌ Error updating widget: $e');
    }
  }

  /// Map Flutter IconData to SF Symbol name
  String _getSystemIconName(IconData icon) {
    // Map common Flutter icons to SF Symbols
    final iconCode = icon.codePoint;
    final iconMap = {
      0xe566: 'figure.run', // Icons.directions_run
      0xe566: 'figure.walk', // Icons.directions_walk
      0xe7ef: 'person.3', // Icons.group
      0xe56c: 'fork.knife', // Icons.restaurant
      0xe318: 'house', // Icons.home
      0xe59c: 'briefcase', // Icons.work
      0xe87d: 'cart', // Icons.shopping_cart
      0xe7f4: 'heart.fill', // Icons.favorite
      0xe878: 'calendar', // Icons.event
      0xe153: 'figure.run', // Icons.fitness_center
      0xe1c3: 'moon.stars.fill', // Icons.bedtime
      0xe1c3: 'bed.double.fill', // Icons.hotel
      0xe1fd: 'pills.fill', // Icons.medication
      0xe1b0: 'book.fill', // Icons.menu_book
      0xe1b2: 'building.2.fill', // Icons.business
      0xe531: 'laptopcomputer', // Icons.computer
      0xe30b: 'graduationcap.fill', // Icons.school
      0xe558: 'airplane', // Icons.flight
      0xe531: 'desktopcomputer', // Icons.desktop_windows
    };

    return iconMap[iconCode] ?? 'bell.fill';
  }

  /// Convert Flutter Color to hex string
  String _colorToHex(Color color) {
    try {
      return color.value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase();
    } catch (e) {
      return '2D7A78'; // Default teal color
    }
  }
}
