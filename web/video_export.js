// Ball Wars replay video export for the web build.
// Encodes RGBA frames with the browser's H.264 encoder (WebCodecs) and packs
// them into an MP4 with mp4-muxer (web/vendor/mp4-muxer.js).
// Called from Dart: lib/features/replay_export/data/web_video_export.dart.
(() => {
  // Baseline 3.1, Main 4.0, High 4.0: tried in order, first supported wins.
  const CODECS = ['avc1.42001f', 'avc1.4d0028', 'avc1.640028'];
  // Keep the encoder's queue short so memory stays flat on long matches.
  const MAX_QUEUE = 8;

  let session = null;
  let lastUrl = null; // The latest finished video (see finish).

  async function pickConfig(width, height, fps) {
    for (const codec of CODECS) {
      const config = {
        codec,
        width,
        height,
        framerate: fps,
        bitrate: Math.round((width * height * fps) / 4),
        avc: { format: 'avc' },
      };
      const support = await VideoEncoder.isConfigSupported(config);
      if (support.supported) return config;
    }
    throw new Error('This browser cannot encode H.264 video.');
  }

  function current() {
    if (!session) throw new Error('No video is being encoded.');
    if (session.error) throw session.error;
    return session;
  }

  window.ballwarsVideo = {
    isSupported() {
      return typeof VideoEncoder !== 'undefined' &&
        typeof VideoFrame !== 'undefined' &&
        typeof Mp4Muxer !== 'undefined';
    },

    async start(width, height, fps, pcm16le = null, sampleRate = 0) {
      this.cancel();
      const config = await pickConfig(width, height, fps);
      const withAudio = pcm16le && pcm16le.length > 0;
      let audioConfig = null;
      if (withAudio) {
        if (typeof AudioEncoder === 'undefined' || typeof AudioData === 'undefined') {
          throw new Error('This browser cannot encode replay audio.');
        }
        audioConfig = {
          codec: 'mp4a.40.2',
          sampleRate,
          numberOfChannels: 1,
          bitrate: 128000,
        };
        const audioSupport = await AudioEncoder.isConfigSupported(audioConfig);
        if (!audioSupport.supported) throw new Error('This browser cannot encode AAC audio.');
      }
      const target = new Mp4Muxer.ArrayBufferTarget();
      const muxer = new Mp4Muxer.Muxer({
        target,
        video: { codec: 'avc', width, height, frameRate: fps },
        ...(withAudio ? { audio: { codec: 'aac', numberOfChannels: 1, sampleRate } } : {}),
        fastStart: 'in-memory',
      });
      const s = { width, height, fps, frame: 0, error: null, muxer, target };
      s.encoder = new VideoEncoder({
        output: (chunk, meta) => muxer.addVideoChunk(chunk, meta),
        error: (e) => { s.error = e; },
      });
      s.encoder.configure(config);
      if (withAudio) {
        s.audioEncoder = new AudioEncoder({
          output: (chunk, meta) => muxer.addAudioChunk(chunk, meta),
          error: (e) => { s.error = e; },
        });
        s.audioEncoder.configure(audioConfig);
        const framesPerChunk = 1024;
        const totalFrames = Math.floor(pcm16le.length / 2);
        for (let frame = 0; frame < totalFrames; frame += framesPerChunk) {
          const frameCount = Math.min(framesPerChunk, totalFrames - frame);
          const data = pcm16le.slice(frame * 2, (frame + frameCount) * 2);
          const audio = new AudioData({
            format: 's16',
            sampleRate,
            numberOfFrames: frameCount,
            numberOfChannels: 1,
            timestamp: Math.round(frame * 1e6 / sampleRate),
            data,
          });
          try { s.audioEncoder.encode(audio); } finally { audio.close(); }
        }
      }
      session = s;
    },

    async addFrame(rgba) {
      const s = current();
      while (s.encoder.encodeQueueSize > MAX_QUEUE) {
        // Encoder errors can stop the queue from draining permanently.
        // Check on every iteration so callers can cancel/report the failure.
        if (s.error) throw s.error;
        if (session !== s) throw new Error('Video export was cancelled.');
        await new Promise((resolve) => setTimeout(resolve, 1));
      }
      if (s.error) throw s.error;
      if (session !== s) throw new Error('Video export was cancelled.');
      const frame = new VideoFrame(rgba, {
        format: 'RGBA',
        codedWidth: s.width,
        codedHeight: s.height,
        timestamp: Math.round((s.frame * 1e6) / s.fps),
        duration: Math.round(1e6 / s.fps),
      });
      try {
        s.encoder.encode(frame, { keyFrame: s.frame % s.fps === 0 });
      } finally {
        frame.close();
      }
      s.frame++;
    },

    /**
     * Finishes the MP4 and returns a blob: URL for it. The previous export's
     * URL is released here, so at most one video stays in memory (the current
     * one stays valid for Save and Share).
     */
    async finish() {
      const s = current();
      await s.encoder.flush();
      if (s.audioEncoder) await s.audioEncoder.flush();
      s.encoder.close();
      if (s.audioEncoder) s.audioEncoder.close();
      s.muxer.finalize();
      session = null;
      if (s.error) throw s.error;
      if (lastUrl) URL.revokeObjectURL(lastUrl);
      lastUrl = URL.createObjectURL(new Blob([s.target.buffer], { type: 'video/mp4' }));
      return lastUrl;
    },

    cancel() {
      if (!session) return;
      try { session.encoder.close(); } catch (_) { /* already closed */ }
      try { session.audioEncoder?.close(); } catch (_) { /* already closed */ }
      session = null;
    },

    download(url, fileName) {
      const link = document.createElement('a');
      link.href = url;
      link.download = fileName;
      document.body.appendChild(link);
      link.click();
      link.remove();
    },

    /** Opens the share sheet with the video; false if the browser can't. */
    async share(url, fileName) {
      const blob = await (await fetch(url)).blob();
      const file = new File([blob], fileName, { type: 'video/mp4' });
      if (!navigator.canShare || !navigator.canShare({ files: [file] })) return false;
      await navigator.share({ files: [file], title: 'Ball Wars replay' });
      return true;
    },
  };
})();
