import 'dart:io';
import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/animations/animation_data.dart';
import 'package:flutter_filament/entities/entity_transform_controller.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/filament_controller_ffi.dart';

import 'package:untitled_flutter_game_project/audio_service.dart';

class SceneViewModel {
  final assets = <FilamentEntity>[];
  final _audioService = AudioService();

  MorphAnimationData? _morphAnimation;
  late BoneAnimationData _boneAnimation;
  late Map<String, List<String>> _morphTargetNames;
  final _filamentController = FilamentControllerFFI();
  FilamentController get filamentController => _filamentController;

  final playing = ValueNotifier<String?>(null);
  final ready = ValueNotifier<bool>(false);

  final animations = ValueNotifier<List<String>>([]);

  SceneViewModel();

  late FilamentEntity _sky;
  late FilamentEntity _player;

  EntityTransformController? playerController;

  Future initialize() async {
    await _audioService.initialize();
    await _filamentController.createViewer();
    await _filamentController.setRendering(true);
    // await _filamentController
    //     .loadSkybox("asset://assets/default_env_skybox.ktx");
    await _filamentController.loadIbl("asset://assets/default_env_ibl.ktx",
        intensity: 100);

    _sky = await _filamentController.loadGlb("asset://assets/scene.glb");

    _player = await _filamentController.loadGlb("asset://assets/character.glb");

    playerController = await _filamentController.control(_player,
        translationSpeed: 20.0, forwardAnimation: "tmp3i0h3box_remap.002");

    await _filamentController.setCamera(_player, null);
    // await _filamentController.setCameraPosition(0, 1, 5);
    // var posMat = Matrix3.rotationY(pi / 8);
    // print(posMat);
    // var trans = Vector3(0, 0, -10);
    // trans = posMat * trans;
    // print(trans);

    // await _filamentController.setPosition(_player, trans.x, trans.y, trans.z);
    // await _filamentController.setRotation(_player, pi / 8, 0, 1, 0);

    await _filamentController.setBloom(0.0);
    await _filamentController.setCameraExposure(20.0, 1.2, 907.0);
    await _filamentController.setCameraManipulatorOptions(zoomSpeed: 1);
    await _filamentController.addLight(
        0, 7500, 100, -100, 10, 0, 100, 0, 0, true);
    // _filamentController.setCameraPosition(0, 1, 10);
    this.ready.value = false;
  }
}
