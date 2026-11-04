import 'dart:typed_data';

/// Abstract platform stereo sound player interface used by [JungleSoundscape].
abstract interface class PlatformSoundPlayer {
  /// Unlocks audio context on user interaction (needed on Web).
  void unlock();

  /// Plays 2-channel stereo ([left], [right]) PCM buffers at [sampleRate] with
  /// stereo [pan] (`-1.0..1.0` relative to the explorer).
  void playStereoPcm({
    required Float32List left,
    required Float32List right,
    required int sampleRate,
    required double pan,
    required String wavDataUrlFallback,
  });
}

/// No-op sound player used in VM unit tests and headless environments.
final class _StubSoundPlayer implements PlatformSoundPlayer {
  @override
  void unlock() {}

  @override
  void playStereoPcm({
    required Float32List left,
    required Float32List right,
    required int sampleRate,
    required double pan,
    required String wavDataUrlFallback,
  }) {}
}

/// Creates the platform-appropriate [PlatformSoundPlayer].
PlatformSoundPlayer createPlatformSoundPlayer() => _StubSoundPlayer();
