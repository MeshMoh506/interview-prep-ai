// android/app/src/main/kotlin/com/example/frontend/MainActivity.kt
//
// ★ AUDIO FIX: Forces Android audio to loudspeaker for WebView video.
// Without this, WebView audio goes through earpiece (quiet/silent).
// The 'com.katwah/audio' MethodChannel sets MODE_IN_COMMUNICATION
// + setSpeakerphoneOn(true) so WebView audio plays loudly through speaker.

package com.example.frontend

import android.media.AudioManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.katwah/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSpeakerOn" -> {
                    try {
                        val audioManager =
                            getSystemService(AUDIO_SERVICE) as AudioManager
                        // MODE_IN_COMMUNICATION is best for WebRTC/media playback
                        // It routes audio to loudspeaker when setSpeakerphoneOn=true
                        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                        audioManager.isSpeakerphoneOn = true
                        // Also set stream volume to max
                        val maxVol = audioManager.getStreamMaxVolume(
                            AudioManager.STREAM_VOICE_CALL
                        )
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_VOICE_CALL,
                            maxVol,
                            0
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", e.message, null)
                    }
                }
                "setSpeakerOff" -> {
                    try {
                        val audioManager =
                            getSystemService(AUDIO_SERVICE) as AudioManager
                        audioManager.isSpeakerphoneOn = false
                        audioManager.mode = AudioManager.MODE_NORMAL
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        // Reset audio mode when leaving the app
        try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            audioManager.isSpeakerphoneOn = false
            audioManager.mode = AudioManager.MODE_NORMAL
        } catch (_: Exception) {}
        super.onDestroy()
    }
}