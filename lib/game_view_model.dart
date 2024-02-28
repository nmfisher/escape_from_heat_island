import 'dart:async';

import 'dart:math';
import 'package:flutter_filament/camera/camera_orientation.dart';
import 'package:flutter_filament/entities/entity_transform_controller.dart';
import 'package:untitled_flutter_game_project/game.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:flutter/cupertino.dart';
import 'package:flutter_filament/lights/light_options.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as m;

import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/filament_controller_ffi.dart';

enum GameState { Loading, Loaded, Play, Pause }

abstract class GameEntity {
  final FilamentEntity entity;
  final v.Vector3 position;

  GameEntity(this.entity, this.position);
}

class Footpath extends GameEntity {
  bool hasTree = false;

  Footpath(super.entity, super.position);
}

class Road extends GameEntity {
  bool hasBarrier = false;

  Road(super.entity, super.position);
}

class ContextMenu {
  final Offset offset;
  final List<String> labels;
  final List<Future Function()> _callbacks;

  Future click(String label) async {
    await this._callbacks[labels.indexOf(label)].call();
  }

  ContextMenu(this.offset, this.labels, this._callbacks);
}

class GameViewModel {
  int newHouseInterval = 5;

  final numTiles = 30;

  final cameraOrientation = CameraOrientation();
  final buildings = <FilamentEntity>{};
  final roads = <FilamentEntity, Road>{};
  final paths = <FilamentEntity, Footpath>{};

  final temperature = ValueNotifier<double>(25.0);

  final _scales = <FilamentEntity, AnimationController>{};

  final characters = <(FilamentEntity, double)>[];
  final vehicles = <(FilamentEntity, double)>[];
  final vehiclePause = <FilamentEntity>{};

  final _rnd = Random();

  final state = ValueNotifier<GameState>(GameState.Loading);

  // final _audioService = AudioService();

  final _filamentController = FilamentControllerFFI();
  FilamentController get filamentController => _filamentController;

  final ready = ValueNotifier<bool>(false);

  final contextMenu = ValueNotifier<ContextMenu?>(null);

  GameViewModel();

  var _prefix = //"asset://";
      "file:///Users/nickfisher/Documents/untitled_flutter_game_project/";

  late LightOptions lightOptions;

  (FilamentEntity, v.Vector3)? selectedTile;

  final _initialized = Completer<bool>();

  late TickerProvider tickerProvider;

  EntityTransformController? cameraController;

  Future initialize(TickerProvider tickerProvider) async {
    if (_initialized.isCompleted) {
      throw Exception();
    }

    cameraOrientation.position.x = 0.5;
    cameraOrientation.position.y = 2;
    cameraOrientation.position.z = numTiles / 2;
    cameraOrientation.rotationX = -pi / 6;
    cameraOrientation.rotationY = -pi / 2;
    cameraOrientation.rotationZ = 0;

    _filamentController.pickResult.listen((event) async {
      var entity = event.entity;

      if (paths.containsKey(entity) && !paths[event.entity]!.hasTree) {
        var position = paths[entity]!.position;
        if (selectedTile != null) {
          await _filamentController.removeEntity(selectedTile!.$1);
        }
        var selectedTileEntity = await _filamentController
            .loadGlb("$_prefix/assets_new/selected.glb");
        await _filamentController.setPosition(
            selectedTileEntity, position.x, position.y, position.z);
        selectedTile = (selectedTileEntity, position);
        if (_canOpenTileMenu) {
          contextMenu.value = ContextMenu(Offset(event.x, event.y), [
            "Plant Tree"
          ], [
            () async {
              await plantTree();
            }
          ]);
        }
      } else if (roads.containsKey(entity) &&
          !roads[event.entity]!.hasBarrier) {
        var position = roads[entity]!.position;
        if (selectedTile != null) {
          await _filamentController.removeEntity(selectedTile!.$1);
        }
        var selectedTileEntity = await _filamentController
            .loadGlb("$_prefix/assets_new/selected.glb");
        await _filamentController.setPosition(
            selectedTileEntity, position.x, position.y, position.z);
        selectedTile = (selectedTileEntity, position);
        if (_canOpenTileMenu) {
          contextMenu.value = ContextMenu(Offset(event.x, event.y), [
            "Erect Barrier"
          ], [
            () async {
              await erectBarrier();
            }
          ]);
        }
      }
    });

    this.tickerProvider = tickerProvider;
    // await _audioService.initialize();
    await _filamentController.createViewer();
    // await _filamentController.setCameraFocusDistance(0.3);

    // cameraController = await _filamentController.control(
    //     await _filamentController.getMainCamera(),
    //     translationSpeed: 10);

    lightOptions = LightOptions(
        iblPath: "$_prefix/assets_new/ibl/ibl_ibl.ktx",
        iblIntensity: 40000,
        directionalType: 0,
        directionalColor: 4909,
        directionalIntensity: 187500,
        directionalCastShadows: true,
        directionalDirection: v.Vector3(0.8, -1.0, 1));
    await _filamentController.setBackgroundColor(m.Colors.blueGrey.shade100);
    await _filamentController
        .loadSkybox("$_prefix/assets_new/ibl/ibl_skybox.ktx");

    await _filamentController.setAntiAliasing(true, true, false);

    // var scene =
    //     await _filamentController.loadGlb("$_prefix/assets_new/scene.glb");
    // await _filamentController.setCamera(scene, null);

    await _initializeGameState();

    await _loadIntro();

    await _filamentController.setBloom(0.1);

    await _filamentController.clearLights();

    if (lightOptions.iblPath != null) {
      await _filamentController.loadIbl(lightOptions.iblPath!,
          intensity: lightOptions.iblIntensity);
    }

    await _filamentController.addLight(
        lightOptions.directionalType,
        lightOptions.directionalColor,
        lightOptions.directionalIntensity,
        lightOptions.directionalPosition.x,
        lightOptions.directionalPosition.y,
        lightOptions.directionalPosition.z,
        lightOptions.directionalDirection.x,
        lightOptions.directionalDirection.y,
        lightOptions.directionalDirection.z,
        lightOptions.directionalCastShadows);

    // await _filamentController.setCameraPosition(cameraOrientation.position.x,
    //     cameraOrientation.position.y, cameraOrientation.position.z);
    // var rotation = cameraOrientation.compose();
    // await _filamentController.setCameraRotation(rotation);
    // await _filamentController.setCameraManipulatorOptions(
    //     zoomSpeed: 5, mode: ManipulatorMode.ORBIT);
    await _filamentController.setToneMapping(ToneMapper.LINEAR);
    await _filamentController.setRendering(true);
    _initialized.complete(true);
  }

  late FilamentEntity? _intro;

  Future playIntroAnimation() async {
    _cameraLandscapeAnimation?.cancel();
    await _filamentController.playAnimationByName(_intro!, "CameraIntro",
        replaceActive: false);
    await _filamentController.playAnimationByName(_intro!, "EmptyIntro",
        replaceActive: false);
    await _filamentController.playAnimationByName(_intro!, "CharacterIntro",
        replaceActive: false);
  }

  Future _loadIntro() async {
    _intro = await _filamentController.loadGlb("$_prefix/assets_new/intro.glb");
    await _filamentController.setPosition(_intro!, 3.5, 0.19, 0);
    await _filamentController.setRotation(_intro!, -pi / 2, 0, 1, 0);
    await _filamentController.setCamera(_intro!, null);
  }

  Future playBuildingAnimation() async {}

  Future playDecreaseTrafficAnimation() async {}

  Timer? _cameraLandscapeAnimation;

  Future playCameraLandscapeAnimation() async {
    var camera = await _filamentController.getChildEntity(_intro!, "Camera");
    _cameraLandscapeAnimation =
        Timer.periodic(Duration(milliseconds: 16), (timer) {
      filamentController.queuePositionUpdate(camera, 0.01, 0, 0,
          relative: true);
    });
  }

  Future addBuilding(int rowNum, int cellNum) async {
    var zOffset = (rowNum.toDouble() * 2) - numTiles / 2;
    var bldIndex = (_rnd.nextDouble() * 6).toInt();
    var bldChar = "ABCDEF".substring(bldIndex, bldIndex + 1);
    var building = await _filamentController
        .loadGlb("$_prefix/assets_new/building_${bldChar}.glb");
    buildings.add(building);
    await _filamentController.setPosition(
        building, 5.0 + (cellNum * 6), 0, zOffset);
    await _filamentController.setRotation(building, -pi / 2, 0, 1.0, 0.0);
    _scales[building] = AnimationController(
        vsync: tickerProvider, duration: Duration(milliseconds: 500));
    var animation =
        _scales[building]!.drive(CurveTween(curve: Curves.easeInOutBack));

    await _filamentController.setScale(building, 0.01);
    _scales[building]!.addListener(() async {
      await _filamentController.setScale(building, animation!.value);
      await _filamentController.setRotation(building, -pi / 2, 0, 1.0, 0.0);
    });

    Future.delayed(Duration(milliseconds: _scales.length * 100), () {
      _scales[building]!.forward();
    });

    bldIndex = (_rnd.nextDouble() * 6).toInt();
    bldChar = "ABCDEF".substring(bldIndex, bldIndex + 1);
    var building2 = await _filamentController
        .loadGlb("$_prefix/assets_new/building_${bldChar}.glb");
    buildings.add(building2);

    await _filamentController.setPosition(
        building2, -5.0 + (cellNum * 6), 0, zOffset);
    await _filamentController.setRotation(building2, pi / 2, 0, 1.0, 0.0);
  }

  Future _loadVehicles() async {
    for (int j = 0; j < 1; j++) {
      for (int i = 0; i < numTiles; i++) {
        var zOffset = (i.toDouble() * 2) - numTiles / 2;

        var vehicleRoll = _rnd.nextDouble();

        if (vehicleRoll > 0.5) {
          FilamentEntity vehicle;
          if (vehicleRoll > 0.9) {
            vehicle = await _filamentController
                .loadGlb("$_prefix/assets_new/car_police.glb");
          } else if (vehicleRoll > 0.8) {
            vehicle = await _filamentController
                .loadGlb("$_prefix/assets_new/car_taxi.glb");
          } else if (vehicleRoll > 0.7) {
            vehicle = await _filamentController
                .loadGlb("$_prefix/assets_new/car_hatchback.glb");
          } else if (vehicleRoll > 0.6) {
            vehicle = await _filamentController
                .loadGlb("$_prefix/assets_new/car_sedan.glb");
          } else {
            vehicle = await _filamentController
                .loadGlb("$_prefix/assets_new/car_stationwagon.glb");
          }
          await _filamentController.setPosition(vehicle, 1.0, 0.17, zOffset);
          vehicles.add((vehicle, 0.01 + _rnd.nextDouble() * 0.1));
          await _filamentController.addCollisionComponent(vehicle,
              callback: (e1, e2) {
            print(
                "Vehicle collision between vehicle $vehicle entities $e1 and $e2");
            vehiclePause.add(vehicle);
            vehiclePause.add(e1);
            vehiclePause.add(e2);
          });
        }
      }
    }
  }

  Future _initializeGameState() async {
    for (int j = 0; j < 1; j++) {
      for (int i = 0; i < numTiles; i++) {
        var zOffset = (i.toDouble() * 2) - numTiles / 2;
        var road = await _filamentController
            .loadGlb("$_prefix/assets_new/road_straight.glb");
        var roadPosition = v.Vector3(1.0 + (j * 6), 0, zOffset);

        await _filamentController.setPosition(
            road, roadPosition.x, roadPosition.y, roadPosition.z);
        var children = await _filamentController.getMeshNames(road);
        var roadRenderable =
            await _filamentController.getChildEntity(road, "road_straight");
        roads[roadRenderable] = Road(road, roadPosition);
        // footpath in front
        var path = await _filamentController
            .loadGlb("$_prefix/assets_new/footpath.glb");
        var position = v.Vector3(3.0 + (j * 6), 0, zOffset);

        await _filamentController.setPosition(
            path, position.x, position.y, position.z);
        var renderable = await _filamentController.getChildEntity(path, "base");
        paths[renderable] = Footpath(path, position);

        // slope behind
        var behind_flat = await _filamentController
            .loadGlb("$_prefix/assets_new/footpath.glb");
        await _filamentController.setPosition(
            behind_flat, 7.0 + (j * 6), 0, zOffset);

        var behind_angle = await _filamentController
            .loadGlb("$_prefix/assets_new/footpath.glb");
        await _filamentController.setPosition(
            behind_angle, 9.0 + (j * 6), 0.5, zOffset);
        await _filamentController.setRotationQuat(
            behind_angle, v.Quaternion.axisAngle(v.Vector3(0, 0, 1), pi / 8));

        var behind_elevated = await _filamentController
            .loadGlb("$_prefix/assets_new/footpath.glb");
        await _filamentController.setPosition(
            behind_elevated, 11.0 + (j * 6), 1.0, zOffset);

        // only add characters for the front road
        if (j > 0) {
          continue;
        }

        // footpath on other side of road
        for (int k = 0; k < 5; k++) {
          var path2 = await _filamentController
              .loadGlb("$_prefix/assets_new/footpath.glb");
          var position2 = v.Vector3((k * -2) + -1.0, 0, zOffset);
          await _filamentController.setPosition(
              path2, position2.x, position2.y, position2.z);
        }
        if (i > 0 && i < numTiles - 1) addBuilding(i, j);

        var charRoll = _rnd.nextDouble();
        double speed = 0.001 + _rnd.nextDouble() * 0.005;
        if (charRoll > 0.5) {
          FilamentEntity char;
          String charType;
          if (charRoll > 0.9) {
            charType = "dog";
          } else if (charRoll > 0.7) {
            charType = "duck";
          } else {
            charType = "bear";
          }
          char = await _filamentController
              .loadGlb("$_prefix/assets_new/$charType.glb");

          await _filamentController.setPosition(char, 3.0, 0.1, zOffset);
          characters.add((char, speed));

          // roll for baby left
          if (_rnd.nextDouble() > 0.75) {
            var char = await _filamentController
                .loadGlb("$_prefix/assets_new/$charType.glb");
            await _filamentController.setScale(char, .5);
            await _filamentController.setPosition(char, 3.2, 0.1, zOffset);
            characters.add((char, speed));
          }

          // roll for baby right
          if (_rnd.nextDouble() > 0.75) {
            var char = await _filamentController
                .loadGlb("$_prefix/assets_new/$charType.glb");
            await _filamentController.setScale(char, .5);
            await _filamentController.setPosition(char, 2.8, 0.1, zOffset);
            characters.add((char, speed));
          }
        }
      }
    }

    await _loadVehicles();

    state.value = GameState.Loaded;
  }

  late Timer _gameLoop;
  late Timer _crowdLoop;
  late Timer _vehicleLoop;

  void startCrowdMotion() {
    for (final char in characters) {
      Future.delayed(Duration(milliseconds: (_rnd.nextDouble() * 1000).toInt()))
          .then((value) => _filamentController
              .playAnimationByName(char.$1, "Walk", loop: true));
    }
    _crowdLoop =
        Timer.periodic(const Duration(milliseconds: 20), (timer) async {
      for (var charIdx = 0; charIdx < characters.length; charIdx++) {
        var character = characters[charIdx];

        _filamentController.queuePositionUpdate(
            character.$1, 0, 0, character.$2,
            relative: true);
      }
    });
  }

  bool introTreePlanted = false;
  Future playReviveAnimation() async {
    await _filamentController.playAnimationByName(_intro!, "Revive",
        replaceActive: true, loop: false);
  }

  void startVehicleMotion() {
    _vehicleLoop = Timer.periodic(Duration(milliseconds: 16), (timer) async {
      for (var vIdx = 0; vIdx < vehicles.length; vIdx++) {
        var vehicle = vehicles[vIdx];
        if (!vehiclePause.contains(vehicle.$1)) {
          _filamentController.queuePositionUpdate(vehicle.$1, 0, 0, vehicle.$2,
              relative: true);
        }
      }
    });
  }

  void start() {
    _gameLoop = Timer.periodic(Duration(seconds: newHouseInterval), (_) async {
      print(await _filamentController.getCameraModelMatrix());
    });

    state.value = GameState.Play;
  }

  void pause() {
    _gameLoop.cancel();
    state.value = GameState.Pause;
  }

  void closeContextMenu() {
    contextMenu.value = null;
  }

  Future plantTree() async {
    if (_intro != null) {
      introTreePlanted = true;
      Future.delayed(const Duration(milliseconds: 500)).then((_) async {
        await playReviveAnimation();
        await Future.delayed(const Duration(seconds: 3));
        await _filamentController.playAnimationByName(
            _intro!, "CameraRoadView");
      });
    }
    closeContextMenu();
    var idx = (_rnd.nextDouble() * 4).toInt();
    var char = "ABCDE".substring(idx, idx + 1);
    var position = selectedTile!.$2;
    var tree = await _filamentController
        .loadGlb("$_prefix/assets_new/tree_${char}.glb");
    await _filamentController.setPosition(tree, position.x - 0.75, position.y,
        position.z + (_rnd.nextDouble() > 0.5 ? 0.75 : -0.75));
    var controller = AnimationController(
        vsync: tickerProvider, duration: const Duration(milliseconds: 100));
    _scales[tree] = controller;
    controller.addListener(() async {
      await _filamentController.setScale(tree, controller.value * 2.0);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        _scales.remove(tree);
      }
    });
    controller.forward();
  }

  bool introBarrierErected = false;
  Future erectBarrier() async {
    if (_intro != null) {
      introBarrierErected = true;
    }
    closeContextMenu();

    var position = selectedTile!.$2;
    var barrier =
        await _filamentController.loadGlb("$_prefix/assets_new/barrier.glb");
    await _filamentController.setPosition(
        barrier, position.x, position.y, position.z);
    // await _filamentController.setRotation(entity, rads, x, y, z)
    var controller = AnimationController(
        vsync: tickerProvider, duration: const Duration(milliseconds: 100));
    _scales[barrier] = controller;
    controller.addListener(() async {
      await _filamentController.setScale(barrier, controller.value);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        _scales.remove(barrier);
      }
    });
    controller.forward();
    await _filamentController.addCollisionComponent(barrier,
        callback: (e1, e2) {
      vehiclePause.add(e2);
    });
  }

  bool _canOpenTileMenu = true;

  void setCanOpenTileMenu(bool canOpenTileMenu) {
    this._canOpenTileMenu = canOpenTileMenu;
  }
}
