// lib/services/tts_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class TtsService {
  final _api = ApiService();
  final AudioPlayer _player = AudioPlayer();

  Future<void> preload() async {
    try {
      await _player.setVolume(1.0);
    } catch (_) {
      // Silent fail on preload
    }
  }

  Future<void> speak(String text, {String language = 'en'}) async {
    try {
      final response = await _api.dio.get(
        '/api/v1/audio/prompt-audio',
        queryParameters: {'text': text, 'language': language},
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data as List<int>);
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
