package com.maoneart.music

import android.content.Intent
import android.media.audiofx.AudioEffect
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.maoneart.music/equalizer"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openEqualizer") {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                val intent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
                    putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                    putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                    if (sessionId != 0) {
                        putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                    }
                }
                if (intent.resolveActivity(packageManager) != null) {
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    val altIntent = Intent("android.media.action.DISPLAY_AUDIO_EFFECT_CONTROL_PANEL").apply {
                        putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                    }
                    if (altIntent.resolveActivity(packageManager) != null) {
                        try {
                            startActivity(altIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

