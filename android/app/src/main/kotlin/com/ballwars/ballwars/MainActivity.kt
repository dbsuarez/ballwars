package com.ballwars.ballwars

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    // Encoding is slow; keep it off the UI thread, one call at a time.
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var encoder: ReplayVideoEncoder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ballwars/video_export")
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    override fun onDestroy() {
        worker.execute {
            encoder?.cancel()
            encoder = null
        }
        worker.shutdown()
        super.onDestroy()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> runInBackground(result) {
                encoder?.cancel()
                val file = File(cacheDir, "ballwars_replay_${System.currentTimeMillis()}.mp4")
                encoder = ReplayVideoEncoder(
                    file,
                    call.argument<Int>("width")!!,
                    call.argument<Int>("height")!!,
                    call.argument<Int>("fps")!!,
                    call.argument<ByteArray>("audioPcm"),
                    call.argument<Int>("audioSampleRate") ?: 0,
                )
                null
            }
            "addFrame" -> runInBackground(result) {
                requireEncoder().addFrame(call.argument<ByteArray>("rgba")!!)
                null
            }
            "finish" -> runInBackground(result) {
                val path = requireEncoder().finish()
                encoder = null
                path
            }
            "cancel" -> runInBackground(result) {
                encoder?.cancel()
                encoder = null
                null
            }
            "saveToGallery" -> runInBackground(result) {
                saveToGallery(File(call.argument<String>("path")!!))
            }
            "share" -> {
                share(Uri.parse(call.argument<String>("uri")!!))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requireEncoder() = encoder ?: error("No video is being encoded")

    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("video_export", e.message ?: e.toString(), null) }
            }
        }
    }

    /** Copies the video into Movies/BallWars and returns its content URI. */
    private fun saveToGallery(file: File): String {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { "Saving videos needs Android 10 or newer" }
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, file.name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/BallWars")
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = contentResolver.insert(collection, values) ?: error("Could not create the gallery entry")
        try {
            contentResolver.openOutputStream(uri).use { out ->
                file.inputStream().use { it.copyTo(out ?: error("Could not open the gallery entry")) }
            }
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            throw e
        }
        file.delete()
        return uri.toString()
    }

    private fun share(uri: Uri) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, "Share replay"))
    }
}
