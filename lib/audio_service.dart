// import 'dart:async';

// import 'dart:io';
// import 'package:audio_session/audio_session.dart';
// import 'package:audioplayers/audioplayers.dart' as ap;
// import 'package:flutter/services.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:flutter_sound_platform_interface/flutter_sound_platform_interface.dart'
//     as s;
// import 'package:just_audio/just_audio.dart' as ja;
// import 'package:path_provider/path_provider.dart';
// import 'package:logger/logger.dart' show Level, Logger;
// import 'package:wave_builder/wave_builder.dart';

// enum AudioSource { Asset, File }

// class AudioService {
//   Future<bool> initialize() async {
//     final session = await AudioSession.instance;

//     try {
//       await session.configure(AudioSessionConfiguration(
//         avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
//         avAudioSessionCategoryOptions:
//             AVAudioSessionCategoryOptions.defaultToSpeaker,
//         avAudioSessionMode: AVAudioSessionMode.defaultMode,
//         // avAudioSessionRouteSharingPolicy:
//         //     AVAudioSessionRouteSharingPolicy.defaultPolicy,
//         // avAudioSessionSetActiveOptions:
//         //     AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
//         androidAudioAttributes: AndroidAudioAttributes(
//             contentType: AndroidAudioContentType.speech,
//             flags: AndroidAudioFlags.none,
//             usage: AndroidAudioUsage.media),
//         androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
//         androidWillPauseWhenDucked: true,
//       ));
//     } catch (err) {
//       print("WARNING: Audio initialization error. $err ");
//       // this will regularly throw exceptions on iOS during dev mode
//       // what to do here?
//     }
//     print("Audio player initialized");
//     return true;
//   }

//   static void encodeWav(File outfile, Uint8List data,
//       {int sampleRate = 16000}) {
//     var waveBuilder = WaveBuilder(frequency: sampleRate, stereo: false);
//     waveBuilder.appendFileContents(data);
//     outfile.writeAsBytesSync(waveBuilder.fileBytes);
//   }

//   ///
//   /// Plays the provided stream. Must be PCM16 encoded audio.
//   ///
//   Future<Playing> playBuffer(
//     Uint8List data,
//     int length, {
//     int sampleRate = 16000,
//     void Function()? onStart,
//   }) async {
//     final done = Completer();
//     if (Platform.isLinux) {
//       var file = File((await getTemporaryDirectory()).path +
//           "/flutter_tts_onnx_stream.pcm");
//       file.writeAsBytesSync(data);
//       onStart?.call();
//       await Process.run(
//           "ffplay",
//           "-nodisp -ar 16000 -f s16le ${file.path} -autoexit"
//               .split(" ")
//               .toList());
//       done.complete();
//       print("Wrote to ${file.path}");
//       return Playing(
//           onCancel: () {
//             throw Exception("TODO");
//           },
//           completed: done.future);
//     } else if (Platform.isWindows) {
//       var file = File((await getTemporaryDirectory()).path +
//           Platform.pathSeparator +
//           "flutter_tts_onnx_stream.wav");
//       encodeWav(file, data);

//       print("Wrote to ${file.path}");
//       final _player = ja.AudioPlayer();
//       await _player.setAudioSource(ja.AudioSource.file(file.path),
//           preload: true);
//       onStart?.call();
//       var completed = _player.play();
//       return Playing(
//           onCancel: () async {
//             await _player!.stop();
//           },
//           completed: completed);
//     } else {
//       final _player =
//           await FlutterSoundPlayer(logLevel: Level.error).openPlayer()!;
//       _player?.setLogLevel(Level.error);
//       onStart?.call();
//       await _player!.startPlayer(
//           fromDataBuffer: data,
//           codec: s.Codec.pcm16,
//           numChannels: 1,
//           sampleRate: sampleRate,
//           whenFinished: () {
//             done.complete();
//           });
//       return Playing(
//           onCancel: () async {
//             await _player!.stopPlayer();
//           },
//           completed: done.future);
//     }
//   }

//   ///
//   /// Plays the audio located at the specified [path] (interpreted as either a file or asset path, depending on [source])
//   ///
//   Future play(String path,
//       {AudioSource source = AudioSource.File,
//       Function? onBegin,
//       int sampleRate = 16000,
//       double speed = 1.0,
//       s.Codec codec = s.Codec.pcm16WAV}) async {
//     print("Playing audio at $path ($source)");

//     Completer _completer = Completer();

//     if (Platform.isLinux || Platform.isMacOS) {
//       final _linuxPlayer = ap.AudioPlayer();

//       bool started = false;
//       late StreamSubscription listener;

//       listener = _linuxPlayer.onPlayerComplete.listen((_) {
//         _completer.complete();
//         listener.cancel();
//         _linuxPlayer.release();
//       });

//       _linuxPlayer.onPlayerStateChanged.listen((event) {
//         if (event == PlayerState.isStopped && !_completer.isCompleted) {
//           _completer.complete();
//           listener.cancel();
//         }
//       });

//       // listener = _linuxPlayer.processingStateStream.listen((state) {
//       //   if (state == ja.ProcessingState.completed) {
//       //     _completer.complete();
//       //     listener.cancel();
//       //   }
//       // });
//       // if (source == AudioSource.Asset) {
//       //   await _linuxPlayer.setAsset(path);
//       // } else if (source == AudioSource.File) {
//       //   await _linuxPlayer.setFilePath(path);
//       // }

//       await _linuxPlayer.setSource(source == AudioSource.Asset
//           ? ap.AssetSource(path)
//           : ap.DeviceFileSource(path));
//       await _linuxPlayer.seek(Duration.zero);
//       await _linuxPlayer.resume();
//       // await _linuxPlayer.play();
//       await onBegin?.call();
//       return Playing(
//           onCancel: () {
//             return _linuxPlayer.stop();
//           },
//           completed: _completer.future);
//     } else {
//       final _player =
//           await FlutterSoundPlayer(logLevel: Level.error).openPlayer();
//       if (source == AudioSource.Asset) {
//         var asset = await rootBundle.load(path);
//         await _player!.startPlayer(
//             fromDataBuffer: asset.buffer.asUint8List(),
//             sampleRate: sampleRate,
//             codec: codec,
//             whenFinished: () {
//               _completer.complete();
//             });
//         await onBegin?.call();
//       } else {
//         await _player!.startPlayer(
//             fromURI: path,
//             codec: codec,
//             whenFinished: () {
//               _completer.complete();
//             });
//         await onBegin?.call();
//       }
//       return Playing(
//           onCancel: () async {
//             await _player.stopPlayer();
//           },
//           completed: _completer.future);
//     }
//   }
// }

// // Feed your own stream of bytes into the player
// class MyCustomSource extends ja.StreamAudioSource {
//   final List<int> bytes;
//   MyCustomSource(this.bytes);

//   @override
//   Future<ja.StreamAudioResponse> request([int? start, int? end]) async {
//     start ??= 0;
//     end ??= bytes.length;
//     return ja.StreamAudioResponse(
//       sourceLength: bytes.length,
//       contentLength: end - start,
//       offset: start,
//       stream: Stream.value(bytes.sublist(start, end)),
//       contentType: 'audio/wav',
//     );
//   }
// }

// class Playing {
//   late final Future Function() _onCancel;
//   late Future completed;

//   Playing({required Future Function() onCancel, required this.completed}) {
//     this._onCancel = onCancel;
//   }

//   Future<void> cancel() {
//     return _onCancel.call();
//   }
// }
