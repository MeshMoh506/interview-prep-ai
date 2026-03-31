// lib/services/tts_service.dart
// Single file — works on both web and mobile
// Web:    uses Blob URL via conditional import
// Mobile: uses BytesSource directly
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'api_service.dart';
import 'tts_service_web.dart' if (dart.library.io) 'tts_service_stub.dart'
    as platform;

class TtsService {
  final _api = ApiService();
  final _player = AudioPlayer();
  bool _speaking = false;

  Future<void> preload() async {
    try {
      await _player.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> speak(String text, {String language = 'en'}) async {
    if (text.trim().isEmpty) return;
    if (_speaking) await stop();

    try {
      _speaking = true;
      final response = await _api.dio.get(
        '/api/v1/audio/prompt-audio',
        queryParameters: {'text': text.trim(), 'language': language},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data;
      if (data == null) return;
      final bytes = data is Uint8List
          ? data
          : Uint8List.fromList(List<int>.from(data as List));

      if (bytes.isEmpty) return;

      if (kIsWeb) {
        // Web: create blob URL and play
        final url = platform.createBlobUrl(bytes, 'audio/mpeg');
        await _player.play(UrlSource(url));
        Future.delayed(const Duration(seconds: 30), () {
          try {
            platform.revokeBlobUrl(url);
          } catch (_) {}
        });
      } else {
        // Mobile: play bytes directly
        await _player.play(BytesSource(bytes));
      }

      // Reset speaking flag when audio completes
      _player.onPlayerComplete.listen((_) => _speaking = false);
    } catch (e) {
      _speaking = false;
      debugPrint('[TtsService] speak error: $e');
    }
  }

  Future<void> stop() async {
    _speaking = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}
