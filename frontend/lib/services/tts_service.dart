// lib/services/tts_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

// Web-only imports
import 'tts_service_web.dart' if (dart.library.io) 'tts_service_stub.dart'
    as platform;

class TtsService {
  final _api = ApiService();
  final AudioPlayer _player = AudioPlayer();

  Future<void> preload() async {
    try {
      await _player.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> speak(String text, {String language = 'en'}) async {
    try {
      final response = await _api.dio.get(
        '/api/v1/audio/prompt-audio',
        queryParameters: {'text': text, 'language': language},
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data as List<int>);

      if (kIsWeb) {
        // On web: create a Blob URL and play via UrlSource
        final url = platform.createBlobUrl(bytes, 'audio/mpeg');
        await _player.play(UrlSource(url));
        // Revoke blob URL after playback starts (small delay)
        Future.delayed(const Duration(seconds: 30), () {
          platform.revokeBlobUrl(url);
        });
      } else {
        // On mobile: BytesSource works fine
        await _player.play(BytesSource(bytes));
      }
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
