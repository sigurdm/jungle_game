import 'dart:js_interop';
import 'dart:typed_data';

import 'sound_player_stub.dart';

export 'sound_player_stub.dart' show PlatformSoundPlayer;

@JS('AudioContext')
extension type _JSAudioContext._(JSObject _) implements JSObject {
  external factory _JSAudioContext();
  external String get state;
  external JSPromise<JSAny?> resume();
  external _JSAudioNode get destination;
  external _JSAudioBuffer createBuffer(
    int numOfChannels,
    int length,
    int sampleRate,
  );
  external _JSAudioBufferSourceNode createBufferSource();
}

@JS()
extension type _JSAudioNode._(JSObject _) implements JSObject {
  external void connect(_JSAudioNode destination);
}

@JS()
extension type _JSAudioBuffer._(JSObject _) implements JSObject {
  external void copyToChannel(JSFloat32Array source, int channelNumber);
}

@JS()
extension type _JSAudioBufferSourceNode._(JSObject _) implements _JSAudioNode {
  external set buffer(_JSAudioBuffer? b);
  external void start([double when]);
}

@JS('Audio')
extension type _JSHtmlAudio._(JSObject _) implements JSObject {
  external factory _JSHtmlAudio(String src);
  external JSPromise<JSAny?> play();
}

/// Web Audio API 2-channel stereo implementation of [PlatformSoundPlayer].
final class _WebSoundPlayer implements PlatformSoundPlayer {
  _JSAudioContext? _ctx;

  _JSAudioContext? _ensureContext() {
    try {
      final ctx = _ctx ??= _JSAudioContext();
      if (ctx.state == 'suspended') {
        ctx.resume();
      }
      return ctx;
    } catch (_) {
      return null;
    }
  }

  @override
  void unlock() {
    _ensureContext();
  }

  @override
  void playStereoPcm({
    required Float32List left,
    required Float32List right,
    required int sampleRate,
    required double pan,
    required String wavDataUrlFallback,
  }) {
    final ctx = _ensureContext();
    if (ctx != null) {
      try {
        // Create a true 2-channel (Left = 0, Right = 1) stereo AudioBuffer.
        final audioBuffer = ctx.createBuffer(2, left.length, sampleRate);
        audioBuffer.copyToChannel(left.toJS, 0);
        audioBuffer.copyToChannel(right.toJS, 1);
        final source = ctx.createBufferSource();
        source.buffer = audioBuffer;
        source.connect(ctx.destination);
        source.start(0);
        return;
      } catch (_) {
        // Fall through to 2-channel stereo WAV data URI playback if needed.
      }
    }
    try {
      final audio = _JSHtmlAudio(wavDataUrlFallback);
      audio.play();
    } catch (_) {}
  }
}

/// Creates the Web Audio API [PlatformSoundPlayer].
PlatformSoundPlayer createPlatformSoundPlayer() => _WebSoundPlayer();
