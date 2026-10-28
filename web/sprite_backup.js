// Keep this synchronous so a prepared backup can download from a user click.
window.ballwarsSpriteBackup = {
  download(bytes, name) {
    const blob = new Blob([bytes], { type: 'application/octet-stream' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = name;
    document.body.appendChild(anchor);
    try { anchor.click(); }
    finally {
      anchor.remove();
      setTimeout(() => URL.revokeObjectURL(url), 60000);
    }
  }
};
