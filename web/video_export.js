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

    async start(width, height, fps) {
      this.cancel();
      const config = await pickConfig(width, height, fps);
      const target = new Mp4Muxer.ArrayBufferTarget();
      const muxer = new Mp4Muxer.Muxer({
        target,
        video: { codec: 'avc', width, height, frameRate: fps },
        fastStart: 'in-memory',
      });
      const s = { width, height, fps, frame: 0, error: null, muxer, target };
      s.encoder = new VideoEncoder({
        output: (chunk, meta) => muxer.addVideoChunk(chunk, meta),
        error: (e) => { s.error = e; },
      });
      s.encoder.configure(config);
      session = s;
    },

    async addFrame(rgba) {
      const s = current();
      while (s.encoder.encodeQueueSize > MAX_QUEUE) {
        await new Promise((resolve) => setTimeout(resolve, 1));
      }
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

    /** Finishes the MP4 and returns a blob: URL for it. */
    async finish() {
      const s = current();
      await s.encoder.flush();
      s.encoder.close();
      s.muxer.finalize();
      session = null;
      if (s.error) throw s.error;
      return URL.createObjectURL(new Blob([s.target.buffer], { type: 'video/mp4' }));
    },

    cancel() {
      if (!session) return;
      try { session.encoder.close(); } catch (_) { /* already closed */ }
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
