/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { createLogger } from 'tgui/logging';

const logger = createLogger('AudioPlayer');

export class AudioPlayer {
  constructor() {
    // A fresh Audio object is created per play() call below - reassigning .src on an
    // already-used media element doesn't reliably re-fire a load in every embedded-webview
    // context without an explicit .load() call.
    this.node = null;
    this.playing = false;
    this.volume = 1;
    this.options = {};
    this.onPlaySubscribers = [];
    this.onStopSubscribers = [];
    this.playbackInterval = null;
  }

  destroy() {
    this.stop();
  }

  play(url, options = {}) {
    this.stop();

    this.options = options;
    logger.log('playing', url, options);

    const node = (this.node = new Audio(url));
    node.volume = this.volume;
    node.playbackRate = this.options.pitch || 1;
    if (this.options.start) {
      node.currentTime = this.options.start;
    }

    node.addEventListener('ended', () => {
      logger.log('ended');
      this.stop();
    });
    node.addEventListener('error', (e) => {
      logger.log('playback error', e.error);
      this.stop();
    });

    // play() returns a Promise that can reject silently (autoplay policy,
    // load failure, etc.) — without this, playback can fail with zero
    // feedback anywhere, including to the admin who triggered it.
    node.play()?.catch((error) => {
      logger.log('play() failed', error);
      this.stop();
    });

    this.playing = true;
    for (let subscriber of this.onPlaySubscribers) {
      subscriber();
    }

    // Check every second to stop the playback at the right time
    this.playbackInterval = setInterval(() => {
      if (!this.playing || !this.node) {
        return;
      }
      const shouldStop =
        this.options.end > 0 && this.node.currentTime >= this.options.end;
      if (shouldStop) {
        this.stop();
      }
    }, 1000);
  }

  stop() {
    clearInterval(this.playbackInterval);
    this.playbackInterval = null;
    if (!this.node) {
      return;
    }
    if (this.playing) {
      for (let subscriber of this.onStopSubscribers) {
        subscriber();
      }
    }
    logger.log('stopping');
    this.playing = false;
    this.node.pause();
    this.node = null;
  }

  setVolume(volume) {
    this.volume = volume;
    if (!this.node) {
      return;
    }
    this.node.volume = volume;
  }

  onPlay(subscriber) {
    this.onPlaySubscribers.push(subscriber);
  }

  onStop(subscriber) {
    this.onStopSubscribers.push(subscriber);
  }
}
