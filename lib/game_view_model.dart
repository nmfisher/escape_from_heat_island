import 'dart:async';

import 'dart:math';
import 'dart:typed_data';
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

class GameViewModel {
  final _footpaths = <Footpath>[];
  final _roads = <Road>[];

  final roadLengthInTiles = 30;

  bool enableCameraMovement = false;

  final cameraOrientation = CameraOrientation();
  final buildings = <FilamentEntity>[];

  final temperature = ValueNotifier<double>(25.0);

  final _vehicles = <Vehicle>[];
  final barriers = <FilamentEntity>{};

  final numBuildings = ValueNotifier<int>(0);

  final _rnd = Random();

  final state = ValueNotifier<GameState>(GameState.Loading);

  // final _audioService = AudioService();

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

  Future initialize(TickerProvider tickerProvider) async {
    if (_initialized.isCompleted) {
      throw Exception();
    }

    cameraOrientation.position.x = 0.5;
    cameraOrientation.position.y = 2;
    cameraOrientation.position.z = roadLengthInTiles / 2;
    cameraOrientation.rotationX = -pi / 6;
    cameraOrientation.rotationY = -pi / 2;
    cameraOrientation.rotationZ = 0;

    _filamentController.pickResult.listen((event) async {
      var entity = event.entity;

      if (_footpaths
          .where((f) => f.instance == entity || f.children.contains(entity))
          .isNotEmpty) {
        final footpath = _footpaths.firstWhere(
            (f) => f.instance == entity || f.children.contains(entity));
        if (!footpath.hasTree) {
          if (selectedTile != null) {
            await _filamentController.removeEntity(selectedTile!.$1);
          }
          var selectedTileEntity = await _filamentController.loadGlbFromBuffer(
              "$_prefix/assets_new/selected.glb",
              cache: true);
          await _filamentController.setPosition(selectedTileEntity,
              footpath.position.x, footpath.position.y, footpath.position.z);
          selectedTile = (selectedTileEntity, footpath.position);
          if (_canOpenTileMenu) {
            contextMenu.value = ContextMenu(Offset(event.x, event.y), [
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
          if (selectedTile != null) {
            await _filamentController.removeEntity(selectedTile!.$1);
          }
          var selectedTileEntity = await _filamentController.loadGlbFromBuffer(
              "$_prefix/assets_new/selected.glb",
              cache: true);
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
    await _filamentController.setCameraManipulatorOptions(
        zoomSpeed: 5, mode: ManipulatorMode.ORBIT);
    await _filamentController.setToneMapping(ToneMapper.LINEAR);
    await _filamentController.setRendering(true);
    playCameraLandscapeAnimation();
    _initialized.complete(true);
  }

  late FilamentEntity? _intro;

  Future playIntroAnimation() async {
    await stopCameraLandscapeAnimation();
    await _filamentController.playAnimationByName(_intro!, "CameraIntro",
        replaceActive: false);
    await _filamentController.playAnimationByName(_intro!, "EmptyIntro",
        replaceActive: false);
    await _filamentController.playAnimationByName(_intro!, "CharacterIntro",
        replaceActive: false);
  }

  Future _loadIntro() async {
    _intro = await _filamentController
        .loadGlbFromBuffer("$_prefix/assets_new/intro.glb");
    await _filamentController.setPosition(_intro!, 4, 0.19, 8);
    await _filamentController.setCamera(_intro!, null);
    // var camera = await _filamentController.getChildEntity(_intro!, "Camera");
    // await _filamentController.setPosition(camera, 0, 0.19, 0);
    // await _filamentController.setRotation(camera!, 0, 0, 1, 0);
  }

  Timer? _cameraLandscapeAnimation;

  Future stopCameraLandscapeAnimation() async {
    _cameraLandscapeAnimation?.cancel();
  }

  Future playCameraLandscapeAnimation() async {
    stopCameraLandscapeAnimation();
    var camera = await _filamentController.getChildEntity(_intro!, "Camera");
    double xOffset = 0.0;
    int buildingNum = 6;
    _cameraLandscapeAnimation =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      xOffset += 0.007;
      if (xOffset >= 1.0) {
        _scales[buildings[buildingNum]]!.forward();
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
      if (vehicleRoll < 0.5) {
        continue;
      }

      var type = _getRandomVehicle();

      var vehicle = Vehicle();
      _vehicles.add(vehicle);
      vehicle.position = v.Vector3(i * 2, 0.17, 12);
      vehicle.type = type;
      vehicle.speed = 0.01 + _rnd.nextDouble() * 0.01;
      vehicle.instance =
          await _filamentController.loadGlb("$_prefix/assets_new/$type");
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

      Timer? _timer;

      await _filamentController.addCollisionComponent(vehicle.hitboxFront!,
          callback: (e1, e2) {
        vehicle.paused = true;
        _timer?.cancel();
        _timer = Timer(Duration(milliseconds: 1000), () async {
          if (!barriers.contains(e2)) {
            vehicle.paused = false;
          }
        });
      });
      await _filamentController.addCollisionComponent(vehicle.hitboxBack!,
          callback: (e1, e2) {
        Future.delayed(Duration(milliseconds: 900)).then((value) async {
          await _filamentController.testCollisions(vehicle.hitboxBack!);
        });
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
  int _gridDepth = 21;
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
    for (int x = 0; x < _gridWidth; x++) {
      for (int y = 0; y < _gridDepth; y++) {
        var position = v.Vector3(x * 2, 0, y * 2);
        var cell = Cell(position);
        cell.hasFootpath = true;
        cell.hasRoad = (y - 1) % 5 == 0;
        if ((y - 3) % 5 == 0) {
          var bldType = _rnd.nextInt(6);
          cell.buildingType = "ABCDEF".substring(bldType, bldType + 1);
        }
        _grid.add(cell);
      }
    }
  }

  Future _loadInstances() async {
    var numFootpaths = _gridWidth * _gridDepth;
    _footpathAsset = await _filamentController.loadGlb(
        "$_prefix/assets_new/footpath.glb",
        numInstances: numFootpaths);
    _footpathInstances
        .addAll(await _filamentController.getInstances(_footpathAsset!));
    for (final instance in _footpathInstances!) {
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
        var cell = _grid[(y * _gridWidth) + x];
        if (cell.hasRoad) {
          var entity = _roadInstances[roadOffset];
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
          await _filamentController.setPosition(
              entity, cell.position.x, 0, cell.position.z);
          await _filamentController.reveal(entity, null);
          buildingOffsets[buildingTypeIndex]++;
        }

        if (!cell.hasRoad && cell.buildingType == null && cell.hasFootpath) {
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

  // we only put characters on the footpath near the main road (i.e. at (0,4), (1,4), etc)
  Future _loadCharacters() async {
    for (int i = 0; i < _gridWidth; i++) {
      if (_rnd.nextDouble() < 0.5) {
        continue;
      }
      var character = Character();
      character.position = v.Vector3(i * 2, 0, 8);
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
        await _filamentController.setPosition(
            char.instance!, char.position.x, 0.16, char.position.z);
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

  Future _initializeGameState() async {
    await _initializeGrid();
    await _loadInstances();
    await _setCellPositions();
    await _loadCharacters();

    await _loadVehicles();

    state.value = GameState.Loaded;
  }

  late Timer _gameLoop;
  late Timer _crowdLoop;
  late Timer _vehicleLoop;

  void startCrowdMotion() {
    for (final char in _characters) {
      Future.delayed(Duration(milliseconds: (_rnd.nextDouble() * 1000).toInt()))
          .then((value) {
        _filamentController.playAnimationByName(char.instance!, "Walk",
            loop: true);
        if (char.leftBaby != null) {
          _filamentController.playAnimationByName(char.leftBaby!, "Walk",
              loop: true);
        }
        if (char.rightBaby != null) {
          _filamentController.playAnimationByName(char.rightBaby!, "Walk",
              loop: true);
        }
      });
    }
    _crowdLoop =
        Timer.periodic(const Duration(milliseconds: 20), (timer) async {
      for (final char in _characters) {
        char.position.x += char.speed;

        if (char.position.x > _gridWidth * 2) {
          char.position.x = 0;
          _filamentController.queuePositionUpdate(
              char.instance!, char.position.x, 0, char.position.z);
        } else {
          _filamentController.queuePositionUpdate(
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
    _buildingLoop?.cancel();
    Timer.periodic(Duration(seconds: 2), (timer) {
      var idx = _rnd.nextInt(buildings.length);
      // _scales[buildings[idx]]!.forward();
    });
  }

  void startVehicleMotion() {
    _vehicleLoop = Timer.periodic(Duration(milliseconds: 16), (timer) async {
      for (final barrier in barriers) {
        await _filamentController.testCollisions(barrier);
      }

      for (final vehicle in _vehicles) {
        // await _filamentController.testCollisions(vehicle.hitboxFront!);

        if (!vehicle.paused) {
          vehicle.position.x += vehicle.speed;

          if (vehicle.position.x > _gridWidth * 2) {
            vehicle.position.x = 0;
            print(vehicle.position.x);
            _filamentController.queuePositionUpdate(vehicle.instance!,
                vehicle.position.x, vehicle.position.y, vehicle.position.z);
          } else {
            _filamentController.queuePositionUpdate(
                vehicle.instance!, 0, 0, vehicle.speed,
                relative: true);
          }
        }
      }
    });
  }

  void start() {
    // playCameraLandscapeAnimation();
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
    if (_intro != null && !introTreePlanted) {
      introTreePlanted = true;
      Future.delayed(const Duration(milliseconds: 500)).then((_) async {
        await playReviveAnimation();
        await Future.delayed(const Duration(seconds: 3));
        await _filamentController.playAnimationByName(
            _intro!, "CameraRoadView");
        await _loadVehicles();
      });
    }
    closeContextMenu();
    var idx = (_rnd.nextDouble() * 4).toInt();
    var char = "ABCDE".substring(idx, idx + 1);
    var position = selectedTile!.$2;
    var tree = await _filamentController
        .loadGlbFromBuffer("$_prefix/assets_new/tree_${char}.glb", cache: true);
    await _filamentController.setPosition(tree, position.x - 0.75, position.y,
        position.z + (_rnd.nextDouble() > 0.5 ? 0.75 : -0.75));
    var controller = AnimationController(
        vsync: tickerProvider, duration: const Duration(milliseconds: 100));
    // _scales[tree] = controller;
    controller.addListener(() async {
      await _filamentController.setScale(tree, controller.value * 2.0);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        // _scales.remove(tree);
        temperature.value = max(25, temperature.value - 1.0);
      }
    });
    controller.forward();
  }

  late Matrix4 _cameraModelMatrix;

  Future moveCamera({double x = 0.0, double z = 0.0}) async {
    var trans = _cameraModelMatrix.getTranslation();

    if (trans.z > (roadLengthInTiles + 5.0) && x > 0) {
      return;
    } else if (trans.z < -(roadLengthInTiles / 2) && x < 0) {
      return;
    }

    if (trans.x > -0.5 && z < 0) {
      return;
    } else if (trans.x < -20.0 && z > 0) {
      return;
    }
    _cameraModelMatrix.translate(x, 0.0, z);
    await _filamentController.setCameraModelMatrix(_cameraModelMatrix.storage);
  }

  bool introBarrierErected = false;
  Future erectBarrier() async {
    if (_intro != null) {
      introBarrierErected = true;
      Future.delayed(const Duration(milliseconds: 500)).then((_) async {
        await Future.delayed(const Duration(seconds: 3));
        await _filamentController.playAnimationByName(_intro!, "CameraReturn");
        await Future.delayed(const Duration(milliseconds: 500));
        _cameraModelMatrix = await _filamentController.getCameraModelMatrix();

        var newModelMatrix =
            Matrix4.translation(_cameraModelMatrix.getTranslation());
        // var rot = _cameraModelMatrix.getRotation();
        var rot = v.Quaternion.axisAngle(v.Vector3(0, 1, 0), -pi / 2) *
            v.Quaternion.axisAngle(
                v.Vector3(1, 0, 0), (2 * pi) * (-20.8 / 360));

        newModelMatrix.rotate(rot.axis, rot.radians);

        _cameraModelMatrix = newModelMatrix;
        await _filamentController.setMainCamera();
        await _filamentController.setCameraModelMatrix(newModelMatrix.storage);
        enableCameraMovement = true;
      });
    }

    closeContextMenu();

    var position = selectedTile!.$2;
    var barrier = await _filamentController
        .loadGlbFromBuffer("$_prefix/assets_new/barrier.glb", cache: true);
    barriers.add(barrier);
    await _filamentController.setPosition(
        barrier, position.x, position.y, position.z);
    // await _filamentController.setRotation(entity, rads, x, y, z)
    var controller = AnimationController(
        vsync: tickerProvider, duration: const Duration(milliseconds: 100));
    // _scales[barrier] = controller;
    controller.addListener(() async {
      await _filamentController.setScale(barrier, controller.value);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
        // _scales.remove(barrier);
      }
    });
    controller.forward();
    await _filamentController.addCollisionComponent(barrier);
    temperature.value = max(25, temperature.value - 1.0);
  }

  bool _canOpenTileMenu = true;

  void setCanOpenTileMenu(bool canOpenTileMenu) {
    this._canOpenTileMenu = canOpenTileMenu;
  }
}
