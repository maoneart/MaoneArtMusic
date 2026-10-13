package com.maoneart.music

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.audiofx.AudioEffect
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.hypot

class MainActivity: AudioServiceActivity() {
    private val EQ_CHANNEL = "com.maoneart.music/equalizer"
    private val VISUALIZER_CHANNEL = "com.maoneart.music/visualizer"
    private val VISUALIZER_STREAM_CHANNEL = "com.maoneart.music/visualizer_stream"

    private var visualizer: Visualizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val PERMISSION_REQ_CODE = 404

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Equalizer MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EQ_CHANNEL).setMethodCallHandler { call, result ->
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

        // 2. Visualizer Control MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VISUALIZER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQ_CODE)
                    }
                }
                "startVisualizer" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: 0
                    val success = startNativeVisualizer(sessionId)
                    result.success(success)
                }
                "stopVisualizer" -> {
                    stopNativeVisualizer()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 3. Visualizer Real-Time Stream EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VISUALIZER_STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopNativeVisualizer()
                }
            }
        )
    }

    private fun startNativeVisualizer(sessionId: Int): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return false
        }
        stopNativeVisualizer()
        return try {
            // Priority: Target audioSessionId, fallback to 0 (Global audio mix)
            val v = try {
                Visualizer(if (sessionId != 0) sessionId else 0)
            } catch (e: Exception) {
                Visualizer(0)
            }

            val captureSize = 128
            v.captureSize = captureSize
            v.scalingMode = Visualizer.SCALING_MODE_NORMALIZED

            val maxRate = Visualizer.getMaxCaptureRate()
            val rate = if (maxRate > 25000) 25000 else maxRate

            v.setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                override fun onWaveFormDataCapture(vis: Visualizer?, waveform: ByteArray?, samplingRate: Int) {}

                override fun onFftDataCapture(vis: Visualizer?, fft: ByteArray?, samplingRate: Int) {
                    if (fft == null || eventSink == null) return

                    // Process FFT into 24 normalized frequency bands (0.0 to 1.0)
                    val bands = ArrayList<Double>(24)
                    val n = (fft.size / 2) - 1
                    val binsPerBand = (n / 24).coerceAtLeast(1)

                    for (i in 0 until 24) {
                        var sum = 0.0
                        val start = (i * binsPerBand) + 1
                        val end = ((i + 1) * binsPerBand).coerceAtMost(n)

                        for (k in start..end) {
                            val re = fft[2 * k].toDouble()
                            val im = fft[2 * k + 1].toDouble()
                            sum += hypot(re, im)
                        }
                        val avg = if (end >= start) sum / (end - start + 1) else 0.0
                        val normalized = (avg / 60.0).coerceIn(0.0, 1.0)
                        bands.add(normalized)
                    }

                    mainHandler.post {
                        eventSink?.success(bands)
                    }
                }
            }, rate, false, true)

            v.enabled = true
            visualizer = v
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun stopNativeVisualizer() {
        try {
            visualizer?.apply {
                enabled = false
                release()
            }
        } catch (e: Exception) {}
        visualizer = null
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQ_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onDestroy() {
        stopNativeVisualizer()
        super.onDestroy()
    }
}
