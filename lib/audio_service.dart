import 'dart:async';

import 'dart:io';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_player.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_platform_interface.dart'
    as s;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart' show Level, Logger;
import 'package:wave_builder/wave_builder.dart';

enum AudioSource { Asset, File }

class AudioService {
  ///
  /// Plays the audio located at the specified [path] (interpreted as either a file or asset path, depending on [source])
  ///
  Future play(String path,
      {AudioSource source = AudioSource.File,
      Function? onBegin,
      int sampleRate = 16000,
      double speed = 1.0,
      bool loop = false,
      s.Codec codec = s.Codec.pcm16WAV}) async {
    Completer _completer = Completer();
if(Platform.isWindows) {
      ap.AudioCache.instance = ap.AudioCache(prefix: '');
      
      final _player = ap.AudioPlayer();
          late StreamSubscription listener;

      listener = _player.onPlayerStateChanged.listen((event) async {
        if(event == ap.PlayerState.completed) {
          if (loop) {
            await _player.stop();
            await _player.seek(Duration.zero);
            _player.seek(Duration.zero);
            _player.resume();
          } else if (!_completer.isCompleted) {
            _completer.complete();
            listener.cancel();
          }
        }
      });
      _player.play(ap.AssetSource(path));
      return Playing(
          onCancel: () async {
            await _player!.stop();
          },
          completed: _completer.future);
}
    final _player = ja.AudioPlayer();
    await _player.setVolume(1.0);
    await _player.setAudioSource(
        source == AudioSource.Asset
            ? ja.AudioSource.asset("asset:///$path")
            : ja.AudioSource.file(path),
        preload: true);
    late StreamSubscription listener;
    listener = _player.playbackEventStream.listen((event) async {
      if (event.processingState == ja.ProcessingState.completed) {
        if (loop) {
          await _player.stop();
          await _player.seek(Duration.zero);
          _player.play();
        } else if (!_completer.isCompleted) {
          _completer.complete();
          listener.cancel();
        }
      }
    });
    _player.play();
    return Playing(
        onCancel: () async {
          await _player.stop();
        },
        completed: _completer.future);
  }
}

// Feed your own stream of bytes into the player
class MyCustomSource extends ja.StreamAudioSource {
  final List<int> bytes;
  MyCustomSource(this.bytes);

  @override
  Future<ja.StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return ja.StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

class Playing {
  late final Future Function() _onCancel;
  late Future completed;

  Playing({required Future Function() onCancel, required this.completed}) {
    this._onCancel = onCancel;
  }

  Future<void> cancel() {
    return _onCancel.call();
  }
}
