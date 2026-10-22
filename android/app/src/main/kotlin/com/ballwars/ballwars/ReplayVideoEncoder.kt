package com.ballwars.ballwars

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File

/**
 * Encodes RGBA frames into an H.264 MP4 with the device's own encoder.
 * Not thread-safe: call every method from the same (background) thread.
 */
class ReplayVideoEncoder(
    private val output: File,
    private val width: Int,
    private val height: Int,
    private val fps: Int,
) {
    private val codec: MediaCodec = MediaCodec.createEncoderByType(MIME)
    private val muxer = MediaMuxer(output.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private val info = MediaCodec.BufferInfo()
    private var track = -1
    private var muxerStarted = false
    private var frameIndex = 0L

    init {
        val format = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, width * height * fps / 4) // ~6.9 Mbps at 720x1280@30
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
        } catch (e: Exception) {
            codec.release()
            muxer.release()
            throw e
        }
    }

    fun addFrame(rgba: ByteArray) {
        require(rgba.size == width * height * 4) { "Expected ${width * height * 4} bytes, got ${rgba.size}" }
        val index = dequeueInput()
        val image = codec.getInputImage(index) ?: error("Encoder returned no input image")
        writeYuv(rgba, image)
        codec.queueInputBuffer(index, 0, width * height * 3 / 2, presentationTimeUs(frameIndex++), 0)
        drain(endOfStream = false)
    }

    /** Finishes the file and returns its path. */
    fun finish(): String {
        val index = dequeueInput()
        codec.queueInputBuffer(index, 0, 0, presentationTimeUs(frameIndex), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(endOfStream = true)
        release()
        return output.path
    }

    fun cancel() {
        try {
            release()
        } finally {
            output.delete()
        }
    }

    private fun release() {
        try {
            codec.stop()
        } catch (_: Exception) {
        }
        codec.release()
        try {
            if (muxerStarted) muxer.stop()
        } catch (_: Exception) {
        }
        muxer.release()
    }

    private fun presentationTimeUs(frame: Long) = frame * 1_000_000L / fps

    private fun dequeueInput(): Int {
        repeat(500) {
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index >= 0) return index
            // Encoder is full: let it hand back output before trying again.
            drain(endOfStream = false)
        }
        error("Encoder stopped accepting frames")
    }

    private fun drain(endOfStream: Boolean) {
        var idleTries = 0
        while (true) {
            val index = codec.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT_US else 0)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream || ++idleTries > 500) return
                }
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                index >= 0 -> {
                    val buffer = codec.getOutputBuffer(index) ?: error("Encoder returned no output buffer")
                    val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (!isConfig && info.size > 0 && muxerStarted) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buffer, info)
                    }
                    codec.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    /** RGBA -> YUV 4:2:0 (BT.601, limited range) into the encoder's planes. */
    private fun writeYuv(rgba: ByteArray, image: Image) {
        val (yPlane, uPlane, vPlane) = image.planes
        val yBuffer = yPlane.buffer
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        val yRow = yPlane.rowStride
        val yPixel = yPlane.pixelStride
        val uRow = uPlane.rowStride
        val uPixel = uPlane.pixelStride
        val vRow = vPlane.rowStride
        val vPixel = vPlane.pixelStride

        for (y in 0 until height) {
            var i = y * width * 4
            val chromaRow = y % 2 == 0
            for (x in 0 until width) {
                val r = rgba[i].toInt() and 0xFF
                val g = rgba[i + 1].toInt() and 0xFF
                val b = rgba[i + 2].toInt() and 0xFF
                yBuffer.put(y * yRow + x * yPixel, (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte())
                if (chromaRow && x % 2 == 0) {
                    val cx = x / 2
                    val cy = y / 2
                    uBuffer.put(cy * uRow + cx * uPixel, (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte())
                    vBuffer.put(cy * vRow + cx * vPixel, (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte())
                }
                i += 4
            }
        }
    }

    private companion object {
        const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
        const val TIMEOUT_US = 10_000L
    }
}
