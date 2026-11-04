import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'sound_player_stub.dart'
    if (dart.library.js_interop) 'sound_player_web.dart';

/// Procedurally synthesized sound cues in the jungle world.
enum SoundCue {
  /// Warm harmonic buzzing of calm honeybees orbiting a hive or flower.
  beeBuzzCalm(label: 'Gentle Bee Buzz', icon: '🐝', defaultDuration: 0.42),

  /// High-intensity FM-modulated buzzing of an angry, stinging bee swarm.
  beeBuzzAngry(label: 'Angry Swarm Buzz!', icon: '🐝', defaultDuration: 0.48),

  /// Deep guttural roar of a prowling or attacking Shadow Jaguar.
  jaguarRoar(label: 'Jaguar Roar!', icon: '🐆', defaultDuration: 0.68),

  /// Sibilant high-frequency hiss of an Emerald Viper striking or fleeing herbs.
  snakeHiss(label: 'Viper Hiss!', icon: '🐍', defaultDuration: 0.36),

  /// Bubbly water splash and snap of a Red-Bellied Piranha or hooked river fish.
  piranhaSplash(label: 'River Splash!', icon: '🐟', defaultDuration: 0.32),

  /// Melodic two-note tropical croak/chirp of a frugivorous Rainbow Toucan.
  toucanCall(label: 'Toucan Call', icon: '🦜', defaultDuration: 0.42),

  /// Piercing, raspy two-burst tropical scream of an excited or alarmed Rainbow Toucan.
  toucanScream(label: 'Toucan Scream!', icon: '🦜', defaultDuration: 0.56),

  /// Playful staccato pitch-gliding chatter of a Capuchin Monkey.
  monkeyChatter(label: 'Monkey Chatter', icon: '🐒', defaultDuration: 0.40),

  /// Soft ascending earthen chime when sowing a seed or sapling.
  sowSeed(label: 'Seed Sowed', icon: '🌱', defaultDuration: 0.22),

  /// Bright three-note botanical arpeggio when harvesting ripe crops or honey.
  harvestCrop(label: 'Harvest Chime', icon: '🧺', defaultDuration: 0.30);

  const SoundCue({
    required this.label,
    required this.icon,
    required this.defaultDuration,
  });

  /// Human-readable description shown in the HUD audio indicator.
  final String label;

  /// Emoji icon representing this sound cue.
  final String icon;

  /// Default synthesized duration in seconds.
  final double defaultDuration;
}

/// A spatial stereo sound event emitted relative to the explorer's position.
final class SoundEvent {
  /// Creates a [SoundEvent] for [cue] with distance [volume] (`0.0..1.0`) and
  /// stereo [pan] (`-1.0` = left of explorer, `+1.0` = right of explorer).
  const SoundEvent({required this.cue, this.volume = 0.85, this.pan = 0.0});

  /// Which procedural sound effect to synthesize and play.
  final SoundCue cue;

  /// Normalized playback gain (`0.0..1.0`) attenuated by distance to explorer.
  final double volume;

  /// Stereo pan in `-1.0..1.0` relative to the explorer (`-1.0` = left ear,
  /// `0.0` = center, `+1.0` = right ear).
  final double pan;

  /// Human-readable direction label (`◀ L`, `● C`, or `R ▶`) for HUD display.
  String get directionBadge {
    if (pan <= -0.18) return '◀ L';
    if (pan >= 0.18) return 'R ▶';
    return '● C';
  }

  /// Formatted HUD badge text for this sound event including stereo direction.
  String get badgeText => '${cue.icon} ${cue.label} ($directionBadge)';
}

/// Pure-Dart DSP synthesizer that procedurally generates mono and 2-channel
/// stereo PCM waveforms and RIFF/WAVE audio buffers for jungle wildlife, bees,
/// and explorer actions.
final class JungleSoundSynthesizer {
  JungleSoundSynthesizer._();

  /// Standard synthesis sample rate in Hz.
  static const int sampleRate = 22050;

  static final Map<SoundCue, Float32List> _cachedUnitSamples = {};

  /// Returns cached normalized mono PCM samples (`-1.0..1.0`) for [cue],
  /// scaled by [volume] (`0.0..1.0`).
  static Float32List synthesizeSamples(SoundCue cue, {double volume = 0.85}) {
    final unit = _cachedUnitSamples[cue] ??= _generateUnitSamples(cue);
    final gain = volume.clamp(0.0, 1.0);
    if ((gain - 1.0).abs() < 1e-4) {
      return Float32List.fromList(unit);
    }
    final scaled = Float32List(unit.length);
    for (int i = 0; i < unit.length; i++) {
      scaled[i] = (unit[i] * gain).clamp(-1.0, 1.0);
    }
    return scaled;
  }

  /// Synthesizes 2-channel stereo (`left`, `right`) PCM buffers for [cue]
  /// spatialized relative to the explorer using equal-power stereo panning
  /// (`cos`/`sin` law) and interaural time delay (Haas effect up to ~0.63 ms).
  static ({Float32List left, Float32List right}) synthesizeStereo(
    SoundCue cue, {
    double volume = 0.85,
    double pan = 0.0,
  }) {
    final unit = _cachedUnitSamples[cue] ??= _generateUnitSamples(cue);
    final clampedGain = volume.clamp(0.0, 1.0);
    final clampedPan = pan.clamp(-1.0, 1.0);

    // Equal-power panning law: theta in [0, pi/2], L = cos(theta), R = sin(theta).
    final theta = (clampedPan + 1.0) * (math.pi * 0.25);
    final leftGain = clampedGain * math.cos(theta);
    final rightGain = clampedGain * math.sin(theta);

    // Interaural time difference (Haas delay up to 14 samples ~= 0.63 ms) for
    // the ear farther from the sound source.
    const maxItdSamples = 14;
    final leftDelay = clampedPan > 0 ? (clampedPan * maxItdSamples).round() : 0;
    final rightDelay =
        clampedPan < 0 ? (-clampedPan * maxItdSamples).round() : 0;

    final totalLen = unit.length + maxItdSamples;
    final left = Float32List(totalLen);
    final right = Float32List(totalLen);

    for (int i = 0; i < unit.length; i++) {
      final s = unit[i];
      left[i + leftDelay] = (s * leftGain).clamp(-1.0, 1.0);
      right[i + rightDelay] = (s * rightGain).clamp(-1.0, 1.0);
    }
    return (left: left, right: right);
  }

  /// Returns a 2-channel stereo `data:audio/wav;base64,...` URI for [cue] at
  /// the given [volume] and stereo [pan].
  static String stereoWavDataUrlFor(
    SoundCue cue, {
    double volume = 0.85,
    double pan = 0.0,
  }) {
    final stereo = synthesizeStereo(cue, volume: volume, pan: pan);
    final wavBytes = encodeStereoWavBytes(
      left: stereo.left,
      right: stereo.right,
    );
    return 'data:audio/wav;base64,${base64Encode(wavBytes)}';
  }

  /// Encodes normalized mono [samples] (`-1.0..1.0`) into a 16-bit mono PCM
  /// RIFF WAVE byte buffer (`Uint8List`).
  static Uint8List encodeWavBytes(
    Float32List samples, {
    int sampleRate = sampleRate,
  }) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2;
    final buffer = ByteData(44 + dataSize);

    _writeRiffWaveHeader(
      buffer,
      numChannels: 1,
      sampleRate: sampleRate,
      dataSize: dataSize,
    );

    for (int i = 0; i < numSamples; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final pcm16 = (clamped * 32767.0).round().clamp(-32768, 32767);
      buffer.setInt16(44 + i * 2, pcm16, Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  /// Encodes 2-channel stereo (`left`, `right`) normalized PCM buffers into an
  /// interleaved 16-bit stereo RIFF WAVE byte buffer (`Uint8List`).
  static Uint8List encodeStereoWavBytes({
    required Float32List left,
    required Float32List right,
    int sampleRate = sampleRate,
  }) {
    final numFrames = math.min(left.length, right.length);
    final dataSize = numFrames * 4; // 2 channels * 2 bytes per sample
    final buffer = ByteData(44 + dataSize);

    _writeRiffWaveHeader(
      buffer,
      numChannels: 2,
      sampleRate: sampleRate,
      dataSize: dataSize,
    );

    for (int i = 0; i < numFrames; i++) {
      final l16 = (left[i].clamp(-1.0, 1.0) * 32767.0).round().clamp(
        -32768,
        32767,
      );
      final r16 = (right[i].clamp(-1.0, 1.0) * 32767.0).round().clamp(
        -32768,
        32767,
      );
      final offset = 44 + i * 4;
      buffer.setInt16(offset, l16, Endian.little);
      buffer.setInt16(offset + 2, r16, Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  static void _writeRiffWaveHeader(
    ByteData buffer, {
    required int numChannels,
    required int sampleRate,
    required int dataSize,
  }) {
    final blockAlign = numChannels * 2;
    final byteRate = sampleRate * blockAlign;

    // RIFF header ("RIFF", fileSize, "WAVE").
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // fmt subchunk ("fmt ", 16, PCM=1, numChannels, sampleRate, byteRate, align, 16-bit).
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little); // PCM = 1
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, 16, Endian.little); // 16 bits per sample

    // data subchunk ("data", dataSize).
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little);
  }

  /// Computes the root-mean-square (RMS) amplitude of [samples].
  static double computeRms(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double sumSq = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sumSq += samples[i] * samples[i];
    }
    return math.sqrt(sumSq / samples.length);
  }

  /// Estimates the dominant zero-crossing rate in Hz for [samples].
  static double estimateZeroCrossingHz(
    Float32List samples, {
    int sampleRate = sampleRate,
  }) {
    if (samples.length < 2) return 0.0;
    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i - 1] >= 0 && samples[i] < 0) ||
          (samples[i - 1] < 0 && samples[i] >= 0)) {
        crossings++;
      }
    }
    final durationSeconds = samples.length / sampleRate;
    return (crossings * 0.5) / durationSeconds;
  }

  static Float32List _generateUnitSamples(SoundCue cue) {
    final count = (cue.defaultDuration * sampleRate).round();
    final out = Float32List(count);
    final rng = math.Random(cue.index * 997 + 42);

    switch (cue) {
      case SoundCue.beeBuzzCalm:
      case SoundCue.beeBuzzAngry:
        final isAngry = cue == SoundCue.beeBuzzAngry;
        final baseFreq = isAngry ? 285.0 : 192.0;
        final flutterHz = isAngry ? 42.0 : 27.0;
        final vibratoHz = isAngry ? 13.5 : 7.0;
        final vibratoDepth = isAngry ? 22.0 : 8.5;
        double phase = 0.0;
        for (int i = 0; i < count; i++) {
          final t = i / sampleRate;
          final env = _smoothEnvelope(
            i,
            count,
            attackFrac: 0.12,
            releaseFrac: 0.18,
          );
          final instFreq =
              baseFreq +
              math.sin(2 * math.pi * vibratoHz * t) * vibratoDepth +
              math.sin(2 * math.pi * 3.2 * t) * 5.0;
          phase += instFreq / sampleRate;
          final saw = 2.0 * (phase - phase.floorToDouble()) - 1.0;
          final harmonic2 = math.sin(4 * math.pi * phase) * 0.55;
          final harmonic3 =
              math.sin(6 * math.pi * phase) * (isAngry ? 0.45 : 0.25);
          final wingFlutter =
              0.68 + 0.32 * math.sin(2 * math.pi * flutterHz * t);
          out[i] = ((saw * 0.48 + harmonic2 + harmonic3) *
                  0.58 *
                  wingFlutter *
                  env)
              .clamp(-1.0, 1.0);
        }

      case SoundCue.jaguarRoar:
        double phase1 = 0.0;
        double phase2 = 0.0;
        double lpNoise = 0.0;
        for (int i = 0; i < count; i++) {
          final t = i / sampleRate;
          final progress = i / count;
          final env = _smoothEnvelope(
            i,
            count,
            attackFrac: 0.08,
            releaseFrac: 0.28,
          );
          final pitchCurve =
              progress < 0.22
                  ? 78.0 + (progress / 0.22) * 28.0
                  : 106.0 - ((progress - 0.22) / 0.78) * 58.0;
          final growlMod = 1.0 + 0.28 * math.sin(2 * math.pi * 29.0 * t);
          final freq = pitchCurve * growlMod;
          phase1 += freq / sampleRate;
          phase2 += (freq * 2.08) / sampleRate;

          final subSaw = 2.0 * (phase1 - phase1.floorToDouble()) - 1.0;
          final formant1 = math.sin(2 * math.pi * phase1);
          final formant2 = math.sin(2 * math.pi * phase2) * 0.45;

          final white = rng.nextDouble() * 2.0 - 1.0;
          lpNoise = lpNoise * 0.82 + white * 0.18;

          final raw =
              (subSaw * 0.46 + formant1 * 0.42 + formant2 + lpNoise * 0.55) *
              env;
          out[i] = _softClip(raw * 1.35);
        }

      case SoundCue.snakeHiss:
        double prevWhite = 0.0;
        for (int i = 0; i < count; i++) {
          final t = i / sampleRate;
          final env = _smoothEnvelope(
            i,
            count,
            attackFrac: 0.05,
            releaseFrac: 0.35,
          );
          final white = rng.nextDouble() * 2.0 - 1.0;
          final highPassed = (white - prevWhite) * 0.65;
          prevWhite = white;
          final tremor = 0.78 + 0.22 * math.sin(2 * math.pi * 34.0 * t);
          out[i] = (highPassed * tremor * env).clamp(-1.0, 1.0);
        }

      case SoundCue.piranhaSplash:
        double phase = 0.0;
        double bandNoise = 0.0;
        for (int i = 0; i < count; i++) {
          final t = i / sampleRate;
          final env = _smoothEnvelope(
            i,
            count,
            attackFrac: 0.04,
            releaseFrac: 0.45,
          );
          final bubbleFreq =
              260.0 +
              190.0 * math.sin(2 * math.pi * 19.0 * t) +
              (i / count) * 220.0;
          phase += bubbleFreq / sampleRate;
          final white = rng.nextDouble() * 2.0 - 1.0;
          bandNoise = bandNoise * 0.72 + white * 0.28;
          out[i] = ((math.sin(2 * math.pi * phase) * 0.55 + bandNoise * 0.45) *
                  env)
              .clamp(-1.0, 1.0);
        }

      case SoundCue.toucanCall:
        double phase = 0.0;
        for (int i = 0; i < count; i++) {
          final t = i / sampleRate;
          final progress = i / count;
          final inFirstNote = progress < 0.44;
          final inGap = progress >= 0.44 && progress < 0.54;
          if (inGap) {
            out[i] = 0.0;
            continue;
          }
          final noteProg =
              inFirstNote
                  ? (progress / 0.44)
                  : ((progress - 0.54) / 0.46).clamp(0.0, 1.0);
          final croakTrill = 1.0 + 0.08 * math.sin(2 * math.pi * 46.0 * t);
          final freq =
              (inFirstNote
                  ? 660.0 + math.sin(noteProg * math.pi) * 310.0
                  : 560.0 + math.sin(noteProg * math.pi) * 260.0) *
              croakTrill;
          phase += freq / sampleRate;
          final noteEnv = math.sin(noteProg * math.pi);
          final tone =
              math.sin(2 * math.pi * phase) * 0.65 +
              math.sin(4 * math.pi * phase) * 0.25 +
              math.sin(6 * math.pi * phase) * 0.10;
          out[i] = (tone * noteEnv * 0.88).clamp(-1.0, 1.0);
        }

      case SoundCue.toucanScream:
        // Piercing, raspy two-burst Ramphastos toucan scream ("KRRR-AAAK! KRR-EEEEK!")
        // combining a sharp upward-then-downward vocal sweep, 58 Hz pharyngeal
        // rattle modulation, nasal beak formants, and breathy rasp noise.
        double phase1 = 0.0;
        double phase2 = 0.0;
        double bandNoise = 0.0;
        for (int i = 0; i < count; i++) {
          final t = i / sampleRate;
          final progress = i / count;
          final inFirstBurst = progress < 0.45;
          final inGap = progress >= 0.45 && progress < 0.53;
          if (inGap) {
            out[i] = 0.0;
            continue;
          }
          final burstProg =
              inFirstBurst
                  ? (progress / 0.45)
                  : ((progress - 0.53) / 0.47).clamp(0.0, 1.0);
          // Fast attack, sustained raspy peak, falling tail.
          final env =
              burstProg < 0.12
                  ? (burstProg / 0.12)
                  : math
                      .pow(1.0 - ((burstProg - 0.12) / 0.88), 0.55)
                      .toDouble();

          final baseSweep =
              inFirstBurst
                  ? (burstProg < 0.35
                      ? 780.0 + (burstProg / 0.35) * 720.0
                      : 1500.0 - ((burstProg - 0.35) / 0.65) * 580.0)
                  : (burstProg < 0.30
                      ? 860.0 + (burstProg / 0.30) * 790.0
                      : 1650.0 - ((burstProg - 0.30) / 0.70) * 740.0);

          // Pharyngeal rattle (58 Hz FM + AM rasp characteristic of toucan screams).
          final rattleFm = 1.0 + 0.16 * math.sin(2 * math.pi * 58.0 * t);
          final rattleAm = 0.72 + 0.28 * math.cos(2 * math.pi * 58.0 * t);
          final freq = baseSweep * rattleFm;
          phase1 += freq / sampleRate;
          phase2 += (freq * 1.98) / sampleRate;

          final carrier = math.sin(2 * math.pi * phase1);
          final nasalFormant = math.sin(2 * math.pi * phase2) * 0.52;
          final thirdHarmonic = math.sin(6 * math.pi * phase1) * 0.30;

          final white = rng.nextDouble() * 2.0 - 1.0;
          bandNoise = bandNoise * 0.68 + white * 0.32;

          final raw =
              ((carrier * 0.58 + nasalFormant + thirdHarmonic) * rattleAm +
                  bandNoise * 0.28) *
              env;
          out[i] = _softClip(raw * 1.45);
        }

      case SoundCue.monkeyChatter:
        double phase = 0.0;
        for (int i = 0; i < count; i++) {
          final progress = i / count;
          final syllable = (progress * 3.0).floor();
          final sylProg = (progress * 3.0) - syllable;
          if (sylProg > 0.78) {
            out[i] = 0.0;
            continue;
          }
          final norm = sylProg / 0.78;
          final base = 520.0 + syllable * 140.0;
          final freq = base + math.sin(norm * math.pi) * 320.0;
          phase += freq / sampleRate;
          final env = math.sin(norm * math.pi);
          final voice =
              math.sin(2 * math.pi * phase) * 0.68 +
              math.sin(4 * math.pi * phase) * 0.32;
          out[i] = (voice * env * 0.85).clamp(-1.0, 1.0);
        }

      case SoundCue.sowSeed:
        double phase = 0.0;
        for (int i = 0; i < count; i++) {
          final progress = i / count;
          final freq = progress < 0.48 ? 392.0 : 523.25;
          phase += freq / sampleRate;
          final env = _smoothEnvelope(
            i,
            count,
            attackFrac: 0.05,
            releaseFrac: 0.45,
          );
          out[i] = (math.sin(2 * math.pi * phase) * env * 0.75).clamp(
            -1.0,
            1.0,
          );
        }

      case SoundCue.harvestCrop:
        double phase = 0.0;
        for (int i = 0; i < count; i++) {
          final progress = i / count;
          final freq =
              progress < 0.33 ? 523.25 : (progress < 0.66 ? 659.25 : 783.99);
          phase += freq / sampleRate;
          final env = _smoothEnvelope(
            i,
            count,
            attackFrac: 0.04,
            releaseFrac: 0.35,
          );
          final chime =
              math.sin(2 * math.pi * phase) * 0.78 +
              math.sin(4 * math.pi * phase) * 0.22;
          out[i] = (chime * env * 0.80).clamp(-1.0, 1.0);
        }
    }
    return out;
  }

  static double _smoothEnvelope(
    int index,
    int total, {
    required double attackFrac,
    required double releaseFrac,
  }) {
    final frac = index / math.max(1, total - 1);
    if (frac < attackFrac) {
      return frac / attackFrac;
    }
    if (frac > 1.0 - releaseFrac) {
      return ((1.0 - frac) / releaseFrac).clamp(0.0, 1.0);
    }
    return 1.0;
  }

  static double _softClip(double x) {
    if (x >= 1.5) return 1.0;
    if (x <= -1.5) return -1.0;
    return x - (x * x * x) / 6.75;
  }
}

/// High-level controller that bridges [JungleWorld] stereo sound events and
/// continuous spatial bee buzzing to the platform audio backend.
final class JungleSoundscape {
  /// Creates a [JungleSoundscape] controller.
  JungleSoundscape();

  final PlatformSoundPlayer _player = createPlatformSoundPlayer();

  double _beeLoopCooldown = 0.0;

  /// Unlocks browser audio playback on a user gesture (tap, click, or key).
  void unlockAudio() {
    _player.unlock();
  }

  /// Plays a discrete stereo [SoundEvent] spatialized relative to the explorer.
  void playEvent(SoundEvent event, {required bool soundEnabled}) {
    if (!soundEnabled || event.volume <= 0.02) return;
    final stereo = JungleSoundSynthesizer.synthesizeStereo(
      event.cue,
      volume: event.volume,
      pan: event.pan,
    );
    _player.playStereoPcm(
      left: stereo.left,
      right: stereo.right,
      sampleRate: JungleSoundSynthesizer.sampleRate,
      pan: event.pan,
      wavDataUrlFallback: JungleSoundSynthesizer.stereoWavDataUrlFor(
        event.cue,
        volume: event.volume,
        pan: event.pan,
      ),
    );
  }

  /// Updates continuous spatial stereo bee buzzing based on proximity
  /// [intensity] (`0.0..1.0`), whether a swarm [isAngry], and stereo [pan]
  /// (`-1.0..1.0` relative to the explorer).
  void updateAmbientBeeBuzz(
    double dt, {
    required bool soundEnabled,
    required double intensity,
    required bool isAngry,
    required double pan,
  }) {
    if (_beeLoopCooldown > 0) {
      _beeLoopCooldown = math.max(0.0, _beeLoopCooldown - dt);
    }
    if (!soundEnabled || intensity <= 0.04) {
      return;
    }
    if (_beeLoopCooldown <= 0) {
      final cue = isAngry ? SoundCue.beeBuzzAngry : SoundCue.beeBuzzCalm;
      final gain = (intensity * (isAngry ? 0.88 : 0.58)).clamp(0.05, 0.92);
      playEvent(
        SoundEvent(cue: cue, volume: gain, pan: pan),
        soundEnabled: soundEnabled,
      );
      _beeLoopCooldown = isAngry ? 0.34 : 0.38;
    }
  }
}
