import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import '../security/secure_storage.dart';

class VoiceRecordingResult {
  final String localPath;
  final int durationSeconds;

  VoiceRecordingResult({
    required this.localPath,
    required this.durationSeconds,
  });
}

class NativeAudioService {
  static const MethodChannel _channel = MethodChannel('com.yaalu.dating/native_audio');

  static final StreamController<String> _completionController = StreamController<String>.broadcast();
  static Stream<String> get onAudioCompleted => _completionController.stream;

  static bool _initialized = false;
  static String? _currentlyPlayingPath;
  static String? get currentlyPlayingPath => _currentlyPlayingPath;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAudioCompleted') {
        final path = call.arguments?['path']?.toString() ?? '';
        _currentlyPlayingPath = null;
        _completionController.add(path);
      } else if (call.method == 'onAudioError') {
        _currentlyPlayingPath = null;
        _completionController.add('error');
      }
    });
  }

  // Request/check recording permission
  static Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  // Start Audio Recording
  static Future<String?> startRecording() async {
    init();
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('startRecording');
      return res?['path']?.toString();
    } catch (_) {
      return null;
    }
  }

  // Stop Recording
  static Future<VoiceRecordingResult?> stopRecording() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('stopRecording');
      if (res != null && res['path'] != null) {
        final path = res['path'].toString();
        final durationMs = (res['durationMs'] as num?)?.toInt() ?? 1000;
        final durationSec = (durationMs / 1000).ceil();
        return VoiceRecordingResult(
          localPath: path,
          durationSeconds: durationSec > 0 ? durationSec : 1,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Cancel Recording
  static Future<void> cancelRecording() async {
    try {
      await _channel.invokeMethod('cancelRecording');
    } catch (_) {}
  }

  // Play Audio (Supports Local File Path or Web HTTP URL)
  static Future<bool> playAudio(String pathOrUrl) async {
    init();
    try {
      final resolvedUrl = ApiEndpoints.resolveImageUrl(pathOrUrl);
      _currentlyPlayingPath = resolvedUrl;
      await _channel.invokeMethod('playAudio', {'path': resolvedUrl});
      return true;
    } catch (_) {
      _currentlyPlayingPath = null;
      return false;
    }
  }

  // Stop Audio Playback
  static Future<void> stopAudio() async {
    try {
      _currentlyPlayingPath = null;
      await _channel.invokeMethod('stopAudio');
    } catch (_) {}
  }

  // Check if Audio is Currently Playing
  static Future<bool> isPlaying() async {
    try {
      final res = await _channel.invokeMethod<bool>('isPlaying');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  // Upload Voice Recording to Yaalu Backend
  static Future<String?> uploadVoiceNote(String filePath, int durationSeconds) async {
    try {
      final token = await SecureStorageService.getAccessToken();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/chat/upload-voice');

      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final minutes = durationSeconds ~/ 60;
      final seconds = durationSeconds % 60;
      final durationStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
      request.fields['duration'] = durationStr;

      final file = File(filePath);
      if (await file.exists()) {
        final multipartFile = await http.MultipartFile.fromPath('voice', file.path);
        request.files.add(multipartFile);
      }

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['audioUrl']?.toString() ?? data['data']['fullUrl']?.toString();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
