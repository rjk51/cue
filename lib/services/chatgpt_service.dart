import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../shared/constants/api_keys.dart';

class ReminderParseResult {
  final String reminderText;
  final DateTime scheduledTime;

  ReminderParseResult({
    required this.reminderText,
    required this.scheduledTime,
  });
}

class ChatGPTService {
  ChatGPTService._internal();
  static final ChatGPTService instance = ChatGPTService._internal();

  /// Parse voice transcription into reminder text and time
  /// Uses ChatGPT to intelligently extract reminder details
  Future<ReminderParseResult?> parseReminderFromVoice(String voiceText) async {
    final uri = Uri.parse('${ApiKeys.openaiBaseUrl}/chat/completions');
    
    final now = DateTime.now();
    final currentTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    final currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dayOfWeek = _getDayOfWeek(now.weekday);

    final systemPrompt = '''You are a reminder parser. Extract the reminder text and scheduled time from user's voice input.

Current context:
- Current time: $currentTime
- Current date: $currentDate ($dayOfWeek)

Rules:
1. Parse natural language time expressions (e.g., "in 30 minutes", "at 3pm", "tomorrow at 9am", "next Monday at 10am")
2. Return JSON with: {"reminder": "task description", "time": "YYYY-MM-DD HH:MM"}
3. If no specific time mentioned, default to 1 hour from now
4. Use 24-hour format for time
5. Be smart about relative times (tomorrow, next week, etc.)
6. Extract only the core reminder task, excluding time phrases

Examples:
Input: "Remind me to call John at 3pm"
Output: {"reminder": "Call John", "time": "$currentDate 15:00"}

Input: "Buy groceries in 2 hours"
Output: {"reminder": "Buy groceries", "time": "${_addHours(now, 2)}"}

Input: "Meeting tomorrow at 9am"
Output: {"reminder": "Meeting", "time": "${_addDays(now, 1)} 09:00"}

Input: "Take medicine"
Output: {"reminder": "Take medicine", "time": "${_addHours(now, 1)}"}

Respond ONLY with valid JSON, no other text.''';

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${ApiKeys.chatgptApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': voiceText},
          ],
          'temperature': 0.3,
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        debugPrint('🤖 [ChatGPT] Response: $content');

        // Parse JSON response
        final parsed = jsonDecode(content.trim());
        final reminderText = parsed['reminder'] as String;
        final timeString = parsed['time'] as String;

        // Parse the time string (format: YYYY-MM-DD HH:MM)
        final scheduledTime = DateTime.parse(timeString.replaceFirst(' ', 'T'));

        return ReminderParseResult(
          reminderText: reminderText,
          scheduledTime: scheduledTime,
        );
      } else {
        debugPrint('ChatGPT Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error parsing reminder: $e');
      return null;
    }
  }

  String _getDayOfWeek(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  String _addHours(DateTime time, int hours) {
    final newTime = time.add(Duration(hours: hours));
    return '${newTime.year}-${newTime.month.toString().padLeft(2, '0')}-${newTime.day.toString().padLeft(2, '0')} ${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
  }

  String _addDays(DateTime time, int days) {
    final newTime = time.add(Duration(days: days));
    return '${newTime.year}-${newTime.month.toString().padLeft(2, '0')}-${newTime.day.toString().padLeft(2, '0')}';
  }
}
