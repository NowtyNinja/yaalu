package com.yaalu.dating

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val LAUNCHER_CHANNEL = "com.yaalu.dating/launcher"
    private val IMAGE_PICKER_CHANNEL = "com.yaalu.dating/native_image_picker"
    private val AUDIO_CHANNEL = "com.yaalu.dating/native_audio"
    
    private val REQUEST_GALLERY = 1001
    private val REQUEST_CAMERA = 1002
    private val REQUEST_AUDIO_PERM = 2002
    private val REQUEST_CAMERA_PERM = 2003

    private var pendingPickerResult: MethodChannel.Result? = null
    private var pendingAudioResult: MethodChannel.Result? = null

    // Native Audio Recorder & Player
    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null
    private var currentAudioFile: File? = null
    private var recordingStartTime: Long = 0
    private var audioChannelInstance: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // HARDWARE LEVEL SECURITY: FLAG_SECURE
        // Prevents screenshots, screen recording, and unauthorized screen scraping
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // URL Launcher Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openUrl") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_URL", "URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Native Direct Photo Picker Channel (100% Native without external Gradle plugins!)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IMAGE_PICKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickImageFromGallery" -> {
                    pendingPickerResult = result
                    try {
                        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                        intent.type = "image/*"
                        startActivityForResult(Intent.createChooser(intent, "Select Photo"), REQUEST_GALLERY)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Intent.ACTION_GET_CONTENT)
                            intent.type = "image/*"
                            startActivityForResult(intent, REQUEST_GALLERY)
                        } catch (e2: Exception) {
                            pendingPickerResult = null
                            result.error("PICK_ERROR", e2.message, null)
                        }
                    }
                }
                "takePhotoWithCamera" -> {
                    pendingPickerResult = result
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA_PERM)
                    } else {
                        launchCamera()
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Native Audio Channel for True Voice Messaging & Audio Playback
        val audioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
        audioChannelInstance = audioChannel
        audioChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    val has = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    result.success(has)
                }
                "requestPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingAudioResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_AUDIO_PERM)
                    }
                }
                "startRecording" -> {
                    try {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            pendingAudioResult = result
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_AUDIO_PERM)
                            return@setMethodCallHandler
                        }

                        val file = File(cacheDir, "voice_${UUID.randomUUID()}.m4a")
                        currentAudioFile = file
                        recordingStartTime = System.currentTimeMillis()

                        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            MediaRecorder(this)
                        } else {
                            @Suppress("DEPRECATION")
                            MediaRecorder()
                        }

                        recorder.apply {
                            setAudioSource(MediaRecorder.AudioSource.MIC)
                            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                            setAudioEncodingBitRate(96000)
                            setAudioSamplingRate(44100)
                            setOutputFile(file.absolutePath)
                            prepare()
                            start()
                        }
                        mediaRecorder = recorder
                        result.success(mapOf("path" to file.absolutePath))
                    } catch (e: Exception) {
                        mediaRecorder?.release()
                        mediaRecorder = null
                        result.error("RECORD_START_FAILED", e.message, null)
                    }
                }
                "stopRecording" -> {
                    try {
                        mediaRecorder?.apply {
                            stop()
                            release()
                        }
                        mediaRecorder = null
                        val durationMs = (System.currentTimeMillis() - recordingStartTime).toInt()
                        val file = currentAudioFile
                        if (file != null && file.exists()) {
                            result.success(mapOf(
                                "path" to file.absolutePath,
                                "durationMs" to durationMs
                            ))
                        } else {
                            result.error("FILE_NOT_FOUND", "Audio recording file missing", null)
                        }
                    } catch (e: Exception) {
                        mediaRecorder?.release()
                        mediaRecorder = null
                        result.error("RECORD_STOP_FAILED", e.message, null)
                    }
                }
                "cancelRecording" -> {
                    try {
                        mediaRecorder?.apply {
                            stop()
                            release()
                        }
                        mediaRecorder = null
                        currentAudioFile?.delete()
                        currentAudioFile = null
                        result.success(true)
                    } catch (e: Exception) {
                        mediaRecorder = null
                        result.success(true)
                    }
                }
                "playAudio" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "Audio path is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        mediaPlayer?.release()
                        val player = MediaPlayer()
                        player.setDataSource(path)
                        player.setOnPreparedListener { mp ->
                            mp.start()
                            result.success(mapOf("durationMs" to mp.duration))
                        }
                        player.setOnCompletionListener {
                            audioChannel.invokeMethod("onAudioCompleted", mapOf("path" to path))
                        }
                        player.setOnErrorListener { _, _, _ ->
                            audioChannel.invokeMethod("onAudioError", mapOf("path" to path))
                            true
                        }
                        player.prepareAsync()
                        mediaPlayer = player
                    } catch (e: Exception) {
                        result.error("PLAY_FAILED", e.message, null)
                    }
                }
                "stopAudio" -> {
                    try {
                        mediaPlayer?.apply {
                            if (isPlaying) stop()
                            release()
                        }
                        mediaPlayer = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "isPlaying" -> {
                    result.success(mediaPlayer?.isPlaying == true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchCamera() {
        try {
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            startActivityForResult(intent, REQUEST_CAMERA)
        } catch (e: Exception) {
            pendingPickerResult?.error("CAMERA_ERROR", e.message, null)
            pendingPickerResult = null
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_AUDIO_PERM) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingAudioResult?.success(granted)
            pendingAudioResult = null
        } else if (requestCode == REQUEST_CAMERA_PERM) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                launchCamera()
            } else {
                pendingPickerResult?.error("PERMISSION_DENIED", "Camera permission is required to capture live photo", null)
                pendingPickerResult = null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_GALLERY) {
            if (resultCode == Activity.RESULT_OK && data != null && data.data != null) {
                try {
                    val uri = data.data!!
                    val inputStream = contentResolver.openInputStream(uri)
                    val cacheFile = File(cacheDir, "picked_photo_${UUID.randomUUID()}.jpg")
                    val outputStream = FileOutputStream(cacheFile)
                    inputStream?.copyTo(outputStream)
                    inputStream?.close()
                    outputStream.close()
                    
                    pendingPickerResult?.success(cacheFile.absolutePath)
                } catch (e: Exception) {
                    pendingPickerResult?.error("COPY_ERROR", e.message, null)
                }
            } else {
                pendingPickerResult?.success(null) // User cancelled
            }
            pendingPickerResult = null
        } else if (requestCode == REQUEST_CAMERA) {
            if (resultCode == Activity.RESULT_OK) {
                try {
                    val bitmap = data?.extras?.get("data") as? Bitmap
                    if (bitmap != null) {
                        val cacheFile = File(cacheDir, "camera_photo_${UUID.randomUUID()}.jpg")
                        val outputStream = FileOutputStream(cacheFile)
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)
                        outputStream.close()
                        pendingPickerResult?.success(cacheFile.absolutePath)
                    } else if (data?.data != null) {
                        val uri = data.data!!
                        val inputStream = contentResolver.openInputStream(uri)
                        val cacheFile = File(cacheDir, "camera_photo_${UUID.randomUUID()}.jpg")
                        val outputStream = FileOutputStream(cacheFile)
                        inputStream?.copyTo(outputStream)
                        inputStream?.close()
                        outputStream.close()
                        pendingPickerResult?.success(cacheFile.absolutePath)
                    } else {
                        pendingPickerResult?.success(null)
                    }
                } catch (e: Exception) {
                    pendingPickerResult?.error("CAMERA_SAVE_ERROR", e.message, null)
                }
            } else {
                pendingPickerResult?.success(null)
            }
            pendingPickerResult = null
        }
    }
}
