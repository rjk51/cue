import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../../shared/constants/api_keys.dart';

class WhisperSpeechService {
  WhisperSpeechService._internal();
  static final WhisperSpeechService instance = WhisperSpeechService._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _currentFilePath;
  bool _initialised = false;

  Future<void> init() async {
    print('🎤 WhisperService: init() called, _initialised = $_initialised');
    if (_initialised) return;
    
    // Check current permission status first
    print('🎤 WhisperService: Checking current microphone permission status...');
    var status = await Permission.microphone.status;
    print('🎤 WhisperService: Current status = $status');
    print('🎤 WhisperService: isGranted = ${status.isGranted}, isDenied = ${status.isDenied}, isPermanentlyDenied = ${status.isPermanentlyDenied}');
    
    // If denied or not determined, request permission
    if (!status.isGranted) {
      print('🎤 WhisperService: Permission not granted, requesting...');
      status = await Permission.microphone.request();
      print('🎤 WhisperService: Request result = $status');
      print('🎤 WhisperService: After request - isGranted = ${status.isGranted}, isDenied = ${status.isDenied}, isPermanentlyDenied = ${status.isPermanentlyDenied}');
    }
    
    // Handle different permission states
    if (status.isDenied) {
      print('🎤 WhisperService: Permission DENIED');
      throw Exception('Microphone permission denied. Please allow microphone access in Settings.');
    } else if (status.isPermanentlyDenied) {
      print('🎤 WhisperService: Permission PERMANENTLY DENIED');
      throw Exception('Microphone permission permanently denied. Please enable it in Settings > Cue > Microphone.');
    } else if (!status.isGranted) {
      print('🎤 WhisperService: Permission NOT GRANTED (unknown state)');
      throw Exception('Microphone permission not granted');
    }
    
    print('🎤 WhisperService: Permission granted! Opening recorder...');
    await _recorder.openRecorder();
    _initialised = true;
    print('🎤 WhisperService: Recorder opened successfully');
  }

  Future<void> startRecording() async {
    print('🎤 WhisperService: startRecording() called, _initialised = $_initialised');
    if (!_initialised) {
      print('🎤 WhisperService: Not initialized, calling init()...');
      await init();
    }

    final Directory tempDir = await getTemporaryDirectory();
    final String filePath = '${tempDir.path}/whisper_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentFilePath = filePath;
    print('🎤 WhisperService: Starting recording to: $filePath');

    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.aacMP4,
    );
    print('🎤 WhisperService: Recording started successfully');
  }

  Future<File?> stopRecording() async {
    if (!_recorder.isRecording) return null;
    await _recorder.stopRecorder();
    
    if (_currentFilePath == null) return null;
    final file = File(_currentFilePath!);
    
    // Minimal file size check (just to catch 0-byte errors)
    if (!await file.exists() || await file.length() < 500) {
      return null;
    }
    return file;
  }

  /// New smarter filter that uses accurate word matching
  bool _isLikelyHallucination(String text) {
    if (text.trim().isEmpty) return true;
    
    final cleaned = text.trim().toLowerCase();

    // 1. Specific Hallucination Phrases (exact matches or starts-with)
    // We removed generic 'you' to avoid blocking 'your', 'young', etc.
    const strictMatches = [
      'you',
      'thank you',
      'thanks for watching',
      'thank you for watching',
      'subtitles by',
      'copyright',
      'all rights reserved'
    ];

    // Check if the text IS exactly one of these, or ENDS with them (common in subtitles)
    for (final phrase in strictMatches) {
      if (cleaned == phrase || cleaned.endsWith(phrase)) {
        return true;
      }
    }

    // 2. Check for "Thank you." at the start (common hallucination)
    if (cleaned.startsWith('thank you.')) return true;

    // 3. Non-Latin characters (Whisper often outputs Chinese/Korean for silence)
    if (RegExp(r'[\u4E00-\u9FFF\u3040-\u309F\uAC00-\uD7AF]').hasMatch(text)) {
      return true;
    }

    return false;
  }

  Future<String?> transcribeWithWhisper(File audioFile) async {
    final uri = Uri.parse('${ApiKeys.openaiBaseUrl}/audio/transcriptions');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${ApiKeys.chatgptApiKey}'
      ..fields['model'] = 'whisper-1'
      ..fields['language'] = 'en'
      // IMPORTANT: Request verbose_json to get silence probability
      ..fields['response_format'] = 'verbose_json' 
      ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Clean up file
      try { await audioFile.delete(); } catch (_) {}

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String?;
        
        // --- 1. CHECK SILENCE PROBABILITY ---
        // verbose_json returns a list of segments. We check the first segment.
        final segments = data['segments'] as List<dynamic>?;
        if (segments != null && segments.isNotEmpty) {
          final firstSegment = segments.first;
          final noSpeechProb = firstSegment['no_speech_prob'] as double?;
          
          debugPrint('🎤 [Whisper] No Speech Prob: $noSpeechProb');

          // If Whisper is >50% sure it's silence, ignore it.
          if (noSpeechProb != null && noSpeechProb > 0.5) {
             debugPrint('🎤 [Whisper] 🤫 Detected Silence (Probability: $noSpeechProb). Skipping.');
             return null;
          }
        }

        // --- 2. CHECK HALLUCINATIONS ---
        if (text != null && _isLikelyHallucination(text)) {
          debugPrint('🎤 [Whisper] ❌ Filtered Hallucination: "$text"');
          return null;
        }

        return text;
      } else {
        debugPrint('Whisper Error: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error: $e');
      return null;
    }
  }

  bool get isRecording => _recorder.isRecording;

  Future<void> dispose() async {
    if (_initialised) {
      await _recorder.closeRecorder();
      _initialised = false;
    }
  }
}
