import 'dart:async';
import 'dart:io';

import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_filament/camera/camera_orientation.dart';
import 'package:flutter_filament/entities/entity_transform_controller.dart';
import 'package:untitled_flutter_game_project/audio_service.dart';
import 'package:untitled_flutter_game_project/game.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:flutter/cupertino.dart';
import 'package:flutter_filament/lights/light_options.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as m;

import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/filament_controller_ffi.dart';

enum GameState { Loading, Loaded, Play, GameOver, Pause }

class Cell {
  bool hasFootpath = false;
  String? buildingType;
  bool hasRoad = false;

  final v.Vector3 position;

  Cell(this.position);
}

enum CharacterType { Dog, Duck, Bear }

class Footpath {
  late FilamentEntity instance;
  final children = <FilamentEntity>[];
  late v.Vector3 position;

  bool hasTree = false;
}

class Character {
  bool passedOut = false;
  late v.Vector3 position;
  late CharacterType characterType;
  bool hasLeftBaby = false;
  bool hasRightBaby = false;
  double speed = 0.0;

  FilamentEntity? instance;
  FilamentEntity? leftBaby;
  FilamentEntity? rightBaby;
}

class Building {
  FilamentEntity? instance;
  late v.Vector3 position;
  late AnimationController controller;
}

class Vehicle {
  late v.Vector3 position;
  late String type;
  double speed = 0.0;
  bool paused = false;
  FilamentEntity? instance;
  FilamentEntity? hitboxFront;
  FilamentEntity? hitboxBack;
}

class Road {
  late v.Vector3 position;
  bool hasBarrier = false;
  late FilamentEntity instance;
  final children = <FilamentEntity>[];
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

typedef PickResult = ({FilamentEntity entity, double x, double y});

class GameViewModel {
  final _footpaths = <Footpath>[];
  final _roads = <Road>[];
  final _buildings = <Building>[];

  bool enableCameraMovement = false;

  final cameraOrientation = CameraOrientation();

  final temperature = ValueNotifier<double>(25.0);
  final gameOverTemperature = 40.0;

  final _vehicles = <Vehicle>[];
  final barriers = <FilamentEntity>{};
  final _barrierCollisions = <FilamentEntity>{};
  final _rearCollisions = <FilamentEntity>{};

  final numBuildings = ValueNotifier<int>(0);

  final _rnd = Random();

  final state = ValueNotifier<GameState>(GameState.Loading);

  final _audioService = AudioService();

  final _filamentController = FilamentControllerFFI();
  FilamentController get filamentController => _filamentController;

  final ready = ValueNotifier<bool>(false);

  final contextMenu = ValueNotifier<ContextMenu?>(null);

  GameViewModel();

  var _prefix = "asset:/";
  // "file:///Users/nickfisher/Documents/untitled_flutter_game_project";

  late LightOptions lightOptions;

  (FilamentEntity, v.Vector3)? selectedTile;

  final _initialized = Completer<bool>();

  late TickerProvider tickerProvider;

  EntityTransformController? cameraController;

  void _onPickResult(PickResult event) async {
    if (!_canOpenTileMenu) {
      print("Ignoring pick result");
      return;
    }

    var entity = event.entity;
    var x = event.x;
    var y = event.y;
    if (_footpaths
        .where((f) => f.instance == entity || f.children.contains(entity))
        .isNotEmpty) {
      final footpath = _footpaths.firstWhere(
          (f) => f.instance == entity || f.children.contains(entity));
      if (!footpath.hasTree) {
        if (selectedTile == null) {
          var selectedTileEntity = await _filamentController.loadGlbFromBuffer(
              "$_prefix/assets_new/selected.glb",
              cache: true);
          selectedTile = (selectedTileEntity, footpath.position);
        }
        selectedTile!.$2.x = footpath.position.x;
        selectedTile!.$2.y = footpath.position.y;
        selectedTile!.$2.z = footpath.position.z;

        await _filamentController.setParent(selectedTile!.$1, _root);
        await _filamentController.setPosition(selectedTile!.$1,
            footpath.position.x, footpath.position.y, footpath.position.z);

        if (_canOpenTileMenu) {
          contextMenu.value = ContextMenu(Offset(x, y), [
            "Plant Tree"
          ], [
            () async {
              await plantTree();
            }
          ]);
        }
      }
    } else if (_roads
        .where((f) => f.instance == entity || f.children.contains(entity))
        .isNotEmpty) {
      final road = _roads.firstWhere(
          (f) => f.instance == entity || f.children.contains(entity));
      if (!road.hasBarrier) {
        var position = road.position;
        if (selectedTile == null) {
          var selectedTileEntity = await _filamentController.loadGlbFromBuffer(
              "$_prefix/assets_new/selected.glb",
              cache: true);
          selectedTile = (selectedTileEntity, position);
        }
        selectedTile!.$2.x = position.x;
        selectedTile!.$2.y = position.y;
        selectedTile!.$2.z = position.z;

        await _filamentController.setParent(selectedTile!.$1, _root);
        await _filamentController.setPosition(
            selectedTile!.$1, position.x, position.y, position.z);

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
    }
  }

  Future initialize(TickerProvider tickerProvider) async {
    if (_initialized.isCompleted) {
      throw Exception();
    }

    await _audioService.play("assets_new/music_loop.wav",
        source: AudioSource.Asset, loop: true);

    _filamentController.pickResult.listen(_onPickResult);

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

    await _filamentController.setCameraManipulatorOptions(
        zoomSpeed: 5, mode: ManipulatorMode.ORBIT);
    await _filamentController.setToneMapping(ToneMapper.LINEAR);
    await _filamentController.setPostProcessing(true);
    await _filamentController.setRendering(true);
    playCameraLandscapeAnimation();
    _initialized.complete(true);
  }

  late FilamentEntity? _intro;
  Timer? _introTimer;

  Future playIntroAnimation() async {
    _buildingLoop?.cancel();
    for (final building in _buildings) {
      building.controller.reset();
    }

    await stopCameraLandscapeAnimation();
    int buildingNum = 0;
    _introTimer?.cancel();
    _introTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (buildingNum < _buildings.length) {
        _buildings[buildingNum].controller.forward();
        buildingNum++;
      }
    });

    await _filamentController.playAnimationByName(_intro!, "CameraIntro",
        replaceActive: true);

    await _filamentController.playAnimationByName(_intro!, "EmptyIntro",
        replaceActive: false);

    await _filamentController.playAnimationByName(_intro!, "CharacterIntro",
        replaceActive: false);
    print("EMPTY INTRO COMPLETE");
  }

  Future _loadIntro() async {
    _intro = await _filamentController
        .loadGlbFromBuffer("$_prefix/assets_new/intro.glb");
    await _filamentController.addAnimationComponent(_intro!);
    await _filamentController.setParent(_intro!, _root);
    await _filamentController.setPosition(
        _intro!, 4.0 - _gridWidth, 0.19, 8.0 - _gridDepth);
    await _filamentController.setCamera(_intro!, null);
  }

  Timer? _cameraLandscapeAnimation;

  Future stopCameraLandscapeAnimation() async {
    print("Stopping camera landcsape");
    _cameraLandscapeAnimation?.cancel();
  }

  Future playCameraLandscapeAnimation() async {
    await stopCameraLandscapeAnimation();
    var camera = await _filamentController.getChildEntity(_intro!, "Camera");
    double xOffset = 0.0;
    int buildingNum = 2;
    _cameraLandscapeAnimation =
        Timer.periodic(const Duration(microseconds: 16670), (timer) {
      xOffset += 0.007;
      if (xOffset >= 1.0 && buildingNum <= _buildings.length - 1) {
        _buildings[buildingNum].controller.forward();
        xOffset = 0;
        buildingNum++;
      }
      filamentController.queuePositionUpdate(camera, 0.01, 0, 0,
          relative: true);
    });
  }

  String _getRandomVehicle() {
    var roll = _rnd.nextDouble();
    if (roll > 0.80) {
      return "car_police.glb";
    } else if (roll > 0.6) {
      return "car_taxi.glb";
    } else if (roll > 0.4) {
      return "car_hatchback.glb";
    } else if (roll > 0.2) {
      return "car_sedan.glb";
    } else {
      return "car_stationwagon.glb";
    }
  }

  // we only put vehicles on the road (i.e. at cell (0,6), (1,6), etc)
  // and we only load one of each type
  Future _loadVehicles() async {
    for (int i = 0; i < _gridWidth; i++) {
      var vehicleRoll = _rnd.nextDouble();
      if (vehicleRoll < 0.75) {
        continue;
      }

      var type = _getRandomVehicle();

      var vehicle = Vehicle();
      _vehicles.add(vehicle);
      vehicle.position =
          v.Vector3((i * 2.0) - _gridWidth, 0.17, 12.0 - _gridDepth);
      vehicle.type = type;
      vehicle.speed = 0.01 + _rnd.nextDouble() * 0.01;
      vehicle.instance =
          await _filamentController.loadGlb("$_prefix/assets_new/$type");
      await _filamentController.setParent(vehicle.instance!, _root);
      vehicle.hitboxFront = await _filamentController.loadGlbFromBuffer(
          "$_prefix/assets_new/car_hitbox_front.glb",
          cache: true);

      vehicle.hitboxBack = await _filamentController.loadGlbFromBuffer(
          "$_prefix/assets_new/car_hitbox_back.glb",
          cache: true);

      await _filamentController.setParent(
          vehicle.hitboxFront!, vehicle.instance!);
      await _filamentController.setParent(
          vehicle.hitboxBack!, vehicle.instance!);
      await _filamentController.setPosition(vehicle.instance!,
          vehicle.position.x, vehicle.position.y, vehicle.position.z);
      await _filamentController.setRotationQuat(vehicle.instance!,
          v.Quaternion.axisAngle(v.Vector3(0, 1, 0), pi / 2));

      await _filamentController.hide(vehicle.hitboxFront!, null);
      await _filamentController.hide(vehicle.hitboxBack!, null);

      var hitboxFrontChild1 = await _filamentController.getChildEntity(
          vehicle.hitboxFront!, "hitbox_front");

      await _filamentController.addCollisionComponent(vehicle.hitboxFront!,
          callback: (e1, e2) async {
        vehicle.paused = true;

        var _timer =
            Timer(Duration(milliseconds: (1000 * _rnd.nextDouble()).toInt()),
                () async {
          if (!_barrierCollisions.contains(vehicle.hitboxFront) &&
              !_barrierCollisions.contains(hitboxFrontChild1) &&
              !_barrierCollisions.contains(e1) &&
              !_barrierCollisions.contains(e2) &&
              !_rearCollisions.contains(e1) &&
              !_rearCollisions.contains(e2)) {
            // await _filamentController.queuePositionUpdate(
            //     vehicle.instance!, 0, 0, -0.01,
            //     relative: true);
            vehicle.paused = false;
          }
        });
      });
      await _filamentController.addCollisionComponent(vehicle.hitboxBack!,
          callback: (e1, e2) {
        // _rearCollisions.add(e1);
        // _rearCollisions.add(e2);
        // vehicle.paused = false;
        // Future.delayed(Duration(milliseconds: 100)).then((value) async {
        //   await _filamentController.testCollisions(vehicle.hitboxBack!);
        // });
      });
    }
  }

  late FilamentEntity _footpathAsset;
  final _footpathInstances = <FilamentEntity>[];
  final _roadInstances = <FilamentEntity>[];
  final _buildingAssets = <FilamentEntity>[];
  final _buildingInstances = <List<FilamentEntity>>[];

  late FilamentEntity _roadAsset;

  int _gridWidth = 21;
  int _gridDepth = 11;
  int cellDim = 2;

  // initialize to a 20x20 grid
  // (0,0) is bottom left corner, (20,20) is top right
  // each row is either all road, all footpath, or buildings, like so:
  //
  // PATH PATH PATH PATH ...
  // PATH HOUS HOUS PATH ...
  // PATH PATH PATH PATH ...
  // ROAD ROAD ROAD ROAD ...
  // PATH PATH PATH PATH ...

  // (though actually every cell has footpath)

  // camera starts looking down at (3,3)
  final _grid = <Cell>[];
  Future _initializeGrid() async {
    _grid.clear();

    for (int y = 0; y < _gridDepth; y++) {
      for (int x = 0; x < _gridWidth; x++) {
        var position =
            v.Vector3((x * 2.0) - _gridWidth, 0, (y * 2.0) - _gridDepth);
        var cell = Cell(position);
        cell.hasFootpath = true;
        cell.hasRoad = (y - 1) % 5 == 0;
        if (y == 2 || y == 8) {
          var bldType = _rnd.nextInt(6);
          cell.buildingType = "ABCDEF".substring(bldType, bldType + 1);
        }
        _grid.add(cell);
      }
    }
  }

  late FilamentEntity _root;
  final rootRotation = ValueNotifier<double>(0);

  void rotateRoot(double rotation) async {
    rootRotation.value = rotation;
    await _filamentController.setRotationQuat(
        _root, v.Quaternion.axisAngle(v.Vector3(0, 1, 0), rotation));
  }

  Future _loadInstances() async {
    _root = await _filamentController.createGeometry([
      -1,
      0,
      -1,
      -1,
      0,
      1,
      1,
      0,
      1,
      1,
      0,
      -1,
    ], [
      0,
      1,
      2,
      2,
      3,
      0
    ], null);

    var numFootpaths = _gridWidth * _gridDepth;
    _footpathAsset = await _filamentController.loadGlb(
        "$_prefix/assets_new/footpath.glb",
        numInstances: numFootpaths);
    _footpathInstances
        .addAll(await _filamentController.getInstances(_footpathAsset!));
    for (final instance in _footpathInstances!) {
      await _filamentController.setParent(instance, _root);
      await _filamentController.hide(instance, null);
    }

    for (var building in "ABCDEFG".split("")) {
      var numInstances =
          _grid.where((element) => element.buildingType == building).length;
      var entity = await _filamentController.loadGlb(
          "$_prefix/assets_new/building_${building}.glb",
          numInstances: numInstances);
      _buildingAssets.add(entity);
      _buildingInstances.add(await _filamentController.getInstances(entity));

      for (final instance in _buildingInstances.last!) {
        await _filamentController.hide(instance, null);
      }
    }

    var numRoads = _grid.where((element) => element.hasRoad).length;
    _roadAsset = await _filamentController.loadGlb(
        "$_prefix/assets_new/road_straight.glb",
        numInstances: numRoads);
    _roadInstances.addAll(await _filamentController.getInstances(_roadAsset));
    for (final instance in _roadInstances) {
      await _filamentController.hide(instance, null);
    }
  }

  Future _setCellPositions() async {
    int footpathOffset = 0;
    int roadOffset = 0;
    List<int> buildingOffsets = "ABCDEFG".split("").map((_) => 0).toList();
    for (int x = 0; x < _gridWidth; x++) {
      for (int y = 0; y < _gridDepth; y++) {
        var cell = _grid[(x * _gridDepth) + y];
        if (cell.hasRoad) {
          var entity = _roadInstances[roadOffset];
          await _filamentController.setParent(entity, _root);
          await _filamentController.setPosition(
              entity, cell.position.x, 0, cell.position.z);
          await _filamentController.setRotationQuat(
              entity, v.Quaternion.axisAngle(v.Vector3(0, 1, 0), pi / 2));
          roadOffset++;
          await _filamentController.reveal(entity, null);
          var road = Road();
          road.instance = entity;
          road.position = cell.position.clone();
          _roads.add(road);
          road.children.add(await _filamentController.getChildEntity(
              road.instance, "road_straight"));
        }
        if (cell.buildingType != null) {
          var buildingTypeIndex = "ABCDEFG".indexOf(cell.buildingType!);
          var offset = buildingOffsets[buildingTypeIndex];
          var entity = _buildingInstances[buildingTypeIndex][offset];
          var bld = Building();
          bld.position = cell.position.clone();
          await _filamentController.setPosition(
              entity, bld.position.x, 0, bld.position.z);
          await _filamentController.reveal(entity, null);
          buildingOffsets[buildingTypeIndex]++;

          bld.instance = entity;
          await _filamentController.setParent(bld.instance!, _root);

          bld.controller = AnimationController(
              vsync: tickerProvider, duration: Duration(milliseconds: 250));
          var tween =
              bld.controller.drive(CurveTween(curve: Curves.easeInOutBack));
          bld.controller.addListener(() async {
            await _filamentController.setScale(bld.instance!, tween.value);
          });
          await _filamentController.setScale(bld.instance!, 0);
          _buildings.add(bld);
        }

        if (!cell.hasRoad && cell.hasFootpath) {
          var entity = _footpathInstances[footpathOffset];
          await _filamentController.setPosition(
              entity, cell.position.x, 0, cell.position.z);
          await _filamentController.reveal(entity, null);
          footpathOffset++;
          var footpath = Footpath();
          footpath.instance = entity;
          footpath.position = cell.position;
          footpath.children.add(await _filamentController.getChildEntity(
              footpath.instance, "base"));
          _footpaths.add(footpath);
        }
      }
    }
  }

  String getPathForCharType(CharacterType charType) {
    return "$_prefix/assets_new/${charType.name.toLowerCase()}.glb";
  }

  final _characters = <Character>[];
  final numPassedOut = ValueNotifier<int>(0);

  // we only put characters on the footpath near the main road (i.e. at (0,4), (1,4), etc)
  Future _loadCharacters() async {
    for (int i = 0; i < _gridWidth; i++) {
      if (_rnd.nextDouble() < 0.5) {
        continue;
      }
      var character = Character();
      character.position =
          v.Vector3((i * 2.0) - _gridWidth, 0.16, 8.0 - _gridDepth);
      double charRoll = _rnd.nextDouble();

      character.characterType = charRoll > 0.66
          ? CharacterType.Bear
          : charRoll > 0.33
              ? CharacterType.Dog
              : CharacterType.Duck;

      character.hasLeftBaby = _rnd.nextDouble() > 0.75;
      character.hasRightBaby = _rnd.nextDouble() > 0.75;
      character.speed = 0.001 + _rnd.nextDouble() * 0.005;
      _characters.add(character);
    }

    var rotation = v.Quaternion.axisAngle(v.Vector3(0, 1, 0), pi / 2);

    for (final charType in CharacterType.values) {
      var ofType = _characters.where((x) => x.characterType == charType);
      var numInstances = ofType.fold(0, (value, element) {
        value++;
        if (element.hasLeftBaby) {
          value++;
        }
        if (element.hasRightBaby) {
          value++;
        }
        return value;
      });
      var path = getPathForCharType(charType);
      var entity =
          await _filamentController.loadGlb(path, numInstances: numInstances);
      var instances = await _filamentController.getInstances(entity);
      var instanceIterator = instances.iterator;
      instanceIterator.moveNext();

      for (final char in ofType) {
        char.instance = instanceIterator.current;
        await _filamentController.addAnimationComponent(char.instance!);
        await _filamentController.setParent(char.instance!, _root);
        await _filamentController.setPosition(
            char.instance!, char.position.x, char.position.y, char.position.z);
        await _filamentController.setRotationQuat(char.instance!, rotation);

        instanceIterator.moveNext();
        if (char.hasLeftBaby) {
          char.leftBaby = instanceIterator.current;
          instanceIterator.moveNext();
          await _filamentController.setPosition(char.leftBaby!, 0.25, 0, 0);
          await _filamentController.setScale(char.leftBaby!, 0.35);
          await _filamentController.setParent(char.leftBaby!, char.instance!);
        }
        if (char.hasRightBaby) {
          char.rightBaby = instanceIterator.current;
          instanceIterator.moveNext();
          await _filamentController.setPosition(char.rightBaby!, -0.25, 0, 0);
          await _filamentController.setScale(char.rightBaby!, 0.5);
          await _filamentController.setParent(char.rightBaby!, char.instance!);
        }
      }
    }
  }

  void _onTemperatureUpdate() {
    if (numPassedOut.value == _characters.length) {
      state.value = GameState.GameOver;
    }
  }

  void _onGameStateUpdate() {
    if (state.value == GameState.GameOver) {
      _canOpenTileMenu = false;
      _crowdLoop?.cancel();
      _vehicleLoop?.cancel();
      _buildingLoop?.cancel();
    }
  }

  Future _initializeGameState() async {
    await _initializeGrid();
    await _loadInstances();
    await _setCellPositions();
    await _loadCharacters();

    await _loadVehicles();

    state.value = GameState.Loaded;
    temperature.removeListener(_onTemperatureUpdate);
    temperature.addListener(_onTemperatureUpdate);
    state.removeListener(_onGameStateUpdate);
    state.addListener(_onGameStateUpdate);
  }

  Timer? _crowdLoop;
  Timer? _vehicleLoop;

  Future startCrowdMotion() async {
    for (final char in _characters) {
      Future.delayed(Duration(milliseconds: (100 * _rnd.nextDouble()).toInt()))
          .then((value) async {
        await _filamentController.playAnimationByName(char.instance!, "Walk",
            loop: true, replaceActive: true);
        if (char.leftBaby != null) {
          await _filamentController.playAnimationByName(char.leftBaby!, "Walk",
              loop: true);
        }
        if (char.rightBaby != null) {
          await _filamentController.playAnimationByName(char.rightBaby!, "Walk",
              loop: true);
        }
      });
    }

    _crowdLoop =
        Timer.periodic(const Duration(microseconds: 16670), (timer) async {
      for (final char in _characters) {
        if (char.passedOut) {
          continue;
        }
        char.position.x += char.speed;

        if (char.position.x > _gridWidth) {
          char.position.x = -_gridWidth.toDouble();
          await _filamentController.setPosition(char.instance!, char.position.x,
              char.position.y, char.position.z);
        } else {
          await _filamentController.queuePositionUpdate(
              char.instance!, 0, 0, char.speed,
              relative: true);
        }
      }
    });
  }

  bool introTreePlanted = false;
  Future playReviveAnimation() async {
    await _filamentController.playAnimationByName(_intro!, "Revive",
        replaceActive: true, loop: false);
  }

  Timer? _buildingLoop;
  void startBuildingLoop() {
    _introTimer?.cancel();
    _buildingLoop?.cancel();
    _buildingLoop = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      var idx = _rnd.nextInt(_buildings.length);
      _buildings[idx].controller.forward();
      temperature.value += 1;
      _checkCharacters();
    });
  }

  Future _checkCharacters() async {
    if (temperature.value > 35) {
      for (final character in _characters) {
        if (!character.passedOut && _rnd.nextDouble() > 0.75) {
          character.passedOut = true;
          _audioService.play("assets_new/passout.wav",
              source: AudioSource.Asset);
          numPassedOut.value++;
          await _filamentController.stopAnimationByName(
              character.instance!, "Walk");
          await _filamentController.playAnimationByName(
              character.instance!, "Passout",
              replaceActive: true);
        }
      }
    }
  }

  Future startVehicleMotion() async {
    _vehicleLoop?.cancel();
    _vehicleLoop = Timer.periodic(Duration(microseconds: 16670), (timer) async {
      for (final barrier in barriers) {
        await _filamentController.testCollisions(barrier);
      }
      for (final vehicle in _vehicles) {
        if (vehicle.hitboxBack != null)
          await _filamentController.testCollisions(vehicle.hitboxBack!);
        if (vehicle.paused) {
          continue;
        }
        if (vehicle.hitboxFront != null)
          await _filamentController.testCollisions(vehicle.hitboxFront!);

        vehicle.position.x += vehicle.speed;

        if (vehicle.position.x > (_gridWidth - 2.0)) {
          vehicle.paused = true;
          Future.delayed(
                  Duration(milliseconds: (1000 * _rnd.nextDouble()).toInt()))
              .then((_) async {
            vehicle.position.x = -_rnd.nextDouble() - _gridWidth;
            await _filamentController.setPosition(vehicle.instance!,
                vehicle.position.x, vehicle.position.y, vehicle.position.z);
            vehicle.paused = false;
          });
        } else {
          if (vehicle.instance != null) {
            _filamentController.queuePositionUpdate(
                vehicle.instance!, 0, 0, vehicle.speed,
                relative: true);
          }
        }
      }
    });
  }

  int get numCharacters => _characters.length;

  void start() {
    _introTimer?.cancel();
    for (final char in _characters) {
      char.passedOut = false;
    }
    numPassedOut.value = 0;
    temperature.value = 25.0;
    state.value = GameState.Play;
  }

  void pause() {
    state.value = GameState.Pause;
  }

  void closeContextMenu() {
    contextMenu.value = null;
  }

  Future plantTree() async {
    closeContextMenu();
    var idx = (_rnd.nextDouble() * 4).toInt();
    var char = "ABCDE".substring(idx, idx + 1);
    var position = selectedTile!.$2;
    _audioService.play("assets_new/swipe.wav", source: AudioSource.Asset);
    var tree = await _filamentController
        .loadGlbFromBuffer("$_prefix/assets_new/tree_${char}.glb", cache: true);

    await _filamentController.setParent(tree, _root);
    await _filamentController.setPosition(tree, position.x - 0.75, position.y,
        position.z + (_rnd.nextDouble() > 0.5 ? 0.75 : -0.75));
    var controller = AnimationController(
        vsync: tickerProvider, duration: const Duration(milliseconds: 100));
    controller.addListener(() async {
      await _filamentController.setScale(tree, controller.value * 2.0);
    });

    await controller.forward();

    temperature.value = max(25, temperature.value - 1.0);

    if (_intro != null && !introTreePlanted) {
      introTreePlanted = true;
      await playReviveAnimation();
      await Future.delayed(const Duration(seconds: 3));
      print("Playing CameraRoadView");
      await _filamentController.playAnimationByName(_intro!, "CameraRoadView");
    }
  }

  late Matrix4 _cameraModelMatrix;

  Future moveCamera(
      {double x = 0.0,
      double y = 0.0,
      double z = 0.0,
      bool modelspace = false}) async {
    // var camera = await _filamentController.getMainCamera();
    // _filamentController.queuePositionUpdate(camera, x, y, z, relative: true);
    var trans = _cameraModelMatrix.getTranslation();

    if (modelspace) {
      var rot = _cameraModelMatrix.getRotation();
      var rotInverse = v.Matrix3.identity();
      rotInverse.copyInverse(rot);

      trans = rotInverse * trans;

      trans.z -= z;
      // trans.z = min(69, max(trans.z - z, 16.5));
      trans = rot * trans;
    } else {
      trans.x = min(max(trans.x + x, -30), 0);

      trans.z = min(13.0, max(trans.z + z, -13.7));
    }
    _cameraModelMatrix.setTranslation(trans);
    await _filamentController.setCameraModelMatrix(_cameraModelMatrix.storage);
  }

  Future setCameraToGameStart() async {
    _cameraLandscapeAnimation?.cancel();
    var animations = await _filamentController.getAnimationNames(_intro!);
    var animIdx = animations.indexOf("CameraReturn");
    var cameraReturnLength =
        await _filamentController.getAnimationDuration(_intro!, animIdx);
    await _filamentController.playAnimation(_intro!, animIdx,
        replaceActive: true);
    await Future.delayed(
        Duration(milliseconds: (cameraReturnLength * 1000).toInt() + 1));
    _cameraModelMatrix = await _filamentController.getCameraModelMatrix();

    await _filamentController.setMainCamera();
    await _filamentController.setCameraModelMatrix(_cameraModelMatrix.storage);
    enableCameraMovement = true;
    await _filamentController.hide(_intro!, "Bear");
  }

  bool introBarrierErected = false;
  Future erectBarrier() async {
    closeContextMenu();

    var position = selectedTile!.$2;
    var barrier = await _filamentController
        .loadGlbFromBuffer("$_prefix/assets_new/barrier.glb", cache: true);
    await _filamentController.setParent(barrier, _root);
    barriers.add(barrier);
    await _filamentController.setPosition(
        barrier, position.x, position.y, position.z);
    await _filamentController.setRotationQuat(
        barrier, v.Quaternion.axisAngle(v.Vector3(0, 1, 0), -pi / 2));
    var controller = AnimationController(
        vsync: tickerProvider, duration: const Duration(milliseconds: 100));
    controller.addListener(() async {
      await _filamentController.setScale(barrier, controller.value);
      await _filamentController.setRotationQuat(
          barrier, v.Quaternion.axisAngle(v.Vector3(0, 1, 0), -pi / 2));
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });
    controller.forward();
    await _filamentController.addCollisionComponent(barrier,
        callback: (e1, e2) {
      _barrierCollisions.add(e2);
      _barrierCollisions.add(e1);
      print("BARRIER COLLISION");
    });
    temperature.value = max(25, temperature.value - 1.0);

    if (_intro != null) {
      introBarrierErected = true;
      await setCameraToGameStart();
      await _filamentController.removeEntity(_intro!);
      _intro = null;
    }
  }

  bool _canOpenTileMenu = true;

  void setCanOpenTileMenu(bool canOpenTileMenu) {
    this._canOpenTileMenu = canOpenTileMenu;
  }
}
