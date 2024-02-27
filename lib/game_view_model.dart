import 'dart:async';

import 'dart:math';
import 'package:flutter_filament/camera/camera_orientation.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:flutter/cupertino.dart';
import 'package:flutter_filament/lights/light_options.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as m;

import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/filament_controller_ffi.dart';

enum GameState { Loading, Loaded, Play, Pause }

class GameViewModel {
  final cameraOrientation = CameraOrientation();
  final buildings = <FilamentEntity>{};
  final roads = <FilamentEntity>{};
  final paths = <FilamentEntity, v.Vector3>{};

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

  final showMenu = ValueNotifier<Offset?>(null);

  GameViewModel();

  var _prefix = //"asset://";
      "file:///Users/nickfisher/Documents/untitled_flutter_game_project/";

  late LightOptions lightOptions;

  (FilamentEntity, v.Vector3)? selectedTile;

  final _initialized = Completer<bool>();

  late TickerProvider tickerProvider;

  Future initialize(TickerProvider tickerProvider) async {
    if (_initialized.isCompleted) {
      throw Exception();
    }

    cameraOrientation.position.x = -5.104437934027778;
    cameraOrientation.position.y = 6.0522460937499964;
    cameraOrientation.position.z = 9.78990342881944;
    cameraOrientation.rotationX = -0.4324973610288678;
    cameraOrientation.rotationY = -2.163509459002932;
    cameraOrientation.rotationZ = -0.02935868785703377;

    _filamentController.pickResult.listen((event) async {
      var entity = event.entity;

      if (paths.containsKey(entity)) {
        print("TILE PICKED");
        var position = paths[entity]!;
        if (selectedTile != null) {
          await _filamentController.removeEntity(selectedTile!.$1);
        }
        var selectedTileEntity = await _filamentController
            .loadGlb("$_prefix/assets_new/selected.glb");
        await _filamentController.setPosition(
            selectedTileEntity, position.x, position.y, position.z);
        selectedTile = (selectedTileEntity, position);
        showMenu.value = Offset(event.x, event.y);
        print("SHOWING MENU AT ${event.x} ${event.y}");
      }
    });

    this.tickerProvider = tickerProvider;
    // await _audioService.initialize();
    await _filamentController.createViewer();

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

    var scene =
        await _filamentController.loadGlb("$_prefix/assets_new/scene.glb");
    // await _filamentController.setCamera(scene, null);

    await _initializeGameState();

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

    await _filamentController.setCameraPosition(cameraOrientation.position.x,
        cameraOrientation.position.y, cameraOrientation.position.z);
    var rotation = cameraOrientation.compose();
    await _filamentController.setCameraRotation(rotation);
    await _filamentController.setCameraManipulatorOptions(
        zoomSpeed: 5, mode: ManipulatorMode.ORBIT);
    await _filamentController.setToneMapping(ToneMapper.LINEAR);
    await _filamentController.setRendering(true);
    _initialized.complete(true);
  }

  Future _initializeGameState() async {
    for (int j = 0; j < 1; j++) {
      for (int i = 0; i < 25; i++) {
        var road = await _filamentController
            .loadGlb("$_prefix/assets_new/road_straight.glb");

        roads.add(road);
        _filamentController.setPosition(
            road, 1.0 + (j * 6), 0, i.toDouble() * 2);
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
          await _filamentController.setPosition(
              vehicle, 1.0, 0.17, i.toDouble() * 2);
          vehicles.add((vehicle, 0.01 + _rnd.nextDouble() * 0.1));
          await _filamentController.addCollisionComponent(vehicle,
              callback: (e1, r2) {
            vehiclePause.add(vehicle);
          });
        }

        var path = await _filamentController
            .loadGlb("$_prefix/assets_new/footpath.glb");
        var position = v.Vector3(3.0 + (j * 6), 0, i.toDouble() * 2);
        await _filamentController.setPosition(
            path, position.x, position.y, position.z);
        var renderable = await _filamentController.getChildEntity(path, "base");
        paths[renderable] = position;

        var bldIndex = (_rnd.nextDouble() * 6).toInt();
        var bldChar = "ABCDEF".substring(bldIndex, bldIndex + 1);
        var building = await _filamentController
            .loadGlb("$_prefix/assets_new/building_${bldChar}.glb");
        buildings.add(building);
        await _filamentController.setPosition(
            building, 5.0 + (j * 6), 0, i.toDouble() * 2);
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

        // only add characters for the front road
        if (j > 0) {
          continue;
        }

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

          await _filamentController.setPosition(
              char, 3.0, 0.1, i.toDouble() * 2);
          characters.add((char, speed));

          // roll for baby left
          if (_rnd.nextDouble() > 0.75) {
            char = await _filamentController
                .loadGlb("$_prefix/assets_new/$charType.glb");
            await _filamentController.setScale(char, .5);
            await _filamentController.setPosition(
                char, 3.2, 0.1, i.toDouble() * 2);
            characters.add((char, speed));
          }

          // roll for baby right
          if (_rnd.nextDouble() > 0.75) {
            char = await _filamentController
                .loadGlb("$_prefix/assets_new/$charType.glb");
            await _filamentController.setScale(char, .5);
            await _filamentController.setPosition(
                char, 2.8, 0.1, i.toDouble() * 2);
            characters.add((char, speed));
          }
        }
      }
    }

    state.value = GameState.Loaded;
  }

  late Timer _gameLoop;

  void start() {
    _gameLoop = Timer.periodic(Duration(milliseconds: 20), (timer) async {
      for (var charIdx = 0; charIdx < characters.length; charIdx++) {
        var character = characters[charIdx];

        _filamentController.queuePositionUpdate(
            character.$1, 0, 0, character.$2,
            relative: true);
      }

      for (var vIdx = 0; vIdx < vehicles.length; vIdx++) {
        var vehicle = vehicles[vIdx];
        // if (vIdx == 0) {
        // await _filamentController.testCollisions(vehicle.$1);
        // }
        if (!vehiclePause.contains(vehicle.$1)) {
          _filamentController.queuePositionUpdate(vehicle.$1, 0, 0, vehicle.$2,
              relative: true);
        }
      }
    });
    state.value = GameState.Play;
  }

  void pause() {
    _gameLoop.cancel();
    state.value = GameState.Pause;
  }

  void closeTileMenu() {
    showMenu.value = null;
  }

  void plantTree() async {
    showMenu.value = null;
    var idx = (_rnd.nextDouble() * 4).toInt();
    var char = "ABCDE".substring(idx, idx + 1);
    var position = selectedTile!.$2;
    var tree = await _filamentController
        .loadGlb("$_prefix/assets_new/tree_${char}.glb");
    await _filamentController.setPosition(
        tree, position.x - 0.75, position.y, position.z);
    var controller = AnimationController(
        vsync: tickerProvider, duration: Duration(milliseconds: 100));
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
}
