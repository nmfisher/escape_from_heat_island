import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_filament/animations/animation_data.dart';
import 'package:flutter_filament/entities/entity_transform_controller.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/filament_controller_ffi.dart';

import 'package:untitled_flutter_game_project/audio_service.dart';

// const _map = """* * * * * * * *
// * * * * → ↓ * *
// * * * * ↑ ↓ * *
// * * → → ↑ ↓ * *
// * * ↑ * * F * *
// * * S * * ↓ * *
// * * * * * ↓ * *
// * * * * * ↓ * *
// * * * * * ↓ * *
// * * * * * ↓ * *
// """;

// river_straight tiiles can have rubbish on rows 0-9 and cols 3-6
// river_bend tiiles can have rubbish on:
// rows 0-1, cols 3-6
// rows 2-3, cols 4-7
// rows 4-5, cols 6-9

final _straightRubbish = """
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
""";

final _bendRubbish = """
0 0 0 0 0 0 0 0 0 0 
0 0 0 0 0 0 0 0 0 0
0 0 0 0 0 0 0 0 0 0
0 0 0 0 0 0 0 0 0 0
0 0 0 0 0 0 0 0 0 0
0 0 0 0 0 1 1 1 1 0
0 0 0 0 0 1 1 1 1 0
0 0 0 0 1 1 1 1 0 0
0 0 0 0 1 1 1 1 0 0
0 0 0 1 1 1 1 0 0 0
0 0 0 1 1 1 1 0 0 0
""";

List<List<bool>> parseRubbishCells(TileType tileType) {
  late String str;
  if (tileType.name.contains("Bend")) {
    str = _bendRubbish;
  } else {
    str = _straightRubbish;
  }
  return str.split("\n").reversed.where((line) => line.isNotEmpty).map((line) {
    return line
        .split(" ")
        .where((c) => c.isNotEmpty)
        .map((c) => c == "1")
        .toList();
  }).toList();
}

final _rubbish = {
  "styrofoam.glb": 0.05,
  "can_crushed.glb": 0.05,
  "soda_bottle.glb": 0.05,
  "candy_wrapper.glb": 0.05,
  "can_open.glb": 0.05,
};

var _map = """
* * * * → ↓
* * * * ↑ ↓
* * → → ↑ ↓
* * S * * *""";

enum TileType {
  Grass,
  RiverStraight,
  RiverStraightRotate90,
  RiverStraightRotate180,
  RiverBend,
  RiverBendRotate180,
  RiverBendRotateMinus90,
  StartTile,
  FinishTile
}

Map<TileType, List<(String, Quaternion?)>> _tiles = {
  TileType.Grass: [("grass.glb", null)],
  TileType.StartTile: [("river_straight.glb", null), ("river_bed.glb", null)],
  TileType.FinishTile: [
    ("river_straight.glb", null),
    ("river_bed.glb", null),
    ("end.glb", null)
  ],
  TileType.RiverStraight: [
    ("river_straight.glb", null),
    ("river_bed.glb", null)
  ],
  TileType.RiverStraightRotate90: [
    (
      "river_straight.glb",
      Quaternion.axisAngle(
        Vector3(0, 1, 0),
        pi / 2,
      )
    ),
    ("river_bed.glb", null)
  ],
  TileType.RiverStraightRotate180: [
    ("river_straight.glb", null),
    ("river_bed.glb", null)
  ],
  TileType.RiverBend: [("river_bend.glb", null), ("river_bed.glb", null)],
  TileType.RiverBendRotate180: [
    (
      "river_bend.glb",
      Quaternion.axisAngle(
        Vector3(0, 1, 0),
        pi,
      )
    ),
    (
      "river_bed.glb",
      Quaternion.axisAngle(
        Vector3(0, 1, 0),
        pi / 2,
      )
    )
  ],
  TileType.RiverBendRotateMinus90: [
    (
      "river_bend.glb",
      Quaternion.axisAngle(
        Vector3(0, 1, 0),
        -pi / 2,
      )
    ),
    (
      "river_bed.glb",
      Quaternion.axisAngle(
        Vector3(0, 1, 0),
        -pi / 2,
      )
    )
  ],
};

// Map<String,TileType> _asciiToTile = {
//   "*" : TileType.Grass,
//   "S" : TileType.StartTile,
//   "F" : TileType.FinishTile,
//   "→" :
//    → ↑ ↓"
// }

final _rubbishTiles = TileType.values
    .toSet()
    .difference({TileType.Grass, TileType.StartTile, TileType.FinishTile});

class SceneViewModel {
  final assets = <FilamentEntity>[];
  // final _audioService = AudioService();

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
  final player = ValueNotifier<FilamentEntity?>(null);
  late FilamentEntity _weapon;

  EntityTransformController? playerController;

  static const int _numRows = 41;
  static const double _gridHeight = 205;
  static const double _cellDim = _gridHeight / _numRows;

  late List<List<bool>> grid;
  final points = ValueNotifier<int>(0);

  bool _swipeAnimating = false;
  final _rnd = Random();

  var _prefix = //"asset://";
      "file:///Users/nickfisher/Documents/untitled_flutter_game_project/";

  Future<Vector3> parse(String map, FilamentEntity playerHitbox) async {
    late Vector3 start;
    final grid = map
        .split("\n")
        .map((line) =>
            line.trim().split(" ").where((c) => c.isNotEmpty).toList())
        .where((c) => c.isNotEmpty)
        .toList();
    final numRows = grid.length;
    final numCols = grid.first.length;
    final cellDim = 100.0;

    for (int rowNum = numRows - 1; rowNum >= 0; rowNum--) {
      final cells = grid[rowNum];
      double z = (rowNum * cellDim) + cellDim / 2;
      for (int colNum = 0; colNum < numCols; colNum++) {
        double x = (colNum * cellDim) + cellDim / 2;

        late TileType tileType;

        switch (cells[colNum]) {
          case "*":
            tileType = TileType.Grass;
            break;
          case "↑":
            if (grid[rowNum][colNum - 1] == "→") {
              tileType = TileType.RiverBendRotate180;
            } else {
              tileType = TileType.RiverStraight;
            }
            break;
          case "→":
            if (grid[rowNum][colNum - 1] == "→") {
              tileType = TileType.RiverStraightRotate90;
            } else {
              tileType = TileType.RiverBend;
            }
            break;
          case "↓":
            if (grid[rowNum][colNum - 1] == "→") {
              tileType = TileType.RiverBendRotateMinus90;
            } else {
              tileType = TileType.RiverStraight;
            }
          case "F":
            tileType = TileType.FinishTile;
          case "S":
            tileType = TileType.StartTile;
            start = Vector3(x, 0, z);
          default:
            throw Exception("Unknown cell : [${cells[colNum]}]");
        }

        late FilamentEntity tileEntity;
        Quaternion? rotation;

        for (final asset in _tiles[tileType]!) {
          var entity =
              await _filamentController.loadGlb("$_prefix/assets/${asset.$1}");
          var riverMatches =
              RegExp("river_(straight|bend).glb").firstMatch(asset.$1);

          if (riverMatches != null) {
            tileEntity = entity;
            var type = riverMatches.group(1);
            var numHitboxes = type == "bend" ? 14 : 2;
            for (int i = 0; i < numHitboxes; i++) {
              var hitbox = await _filamentController.loadGlb(
                  "$_prefix/assets/river_${type}_hitbox.${i.toString().padLeft(3, "0")}.GLB");
              await _filamentController.addCollisionComponent(hitbox,
                  affectsCollingTransform: true, callback: (_, __) {});
              await _filamentController.setParent(hitbox, entity);
              await _filamentController.hide(hitbox, null);
            }
            rotation = asset.$2;
          }

          await _filamentController.setPosition(entity, x, 0, z);
          if (asset.$2 != null) {
            await _filamentController.setRotationQuat(entity, asset.$2!);
          }
        }

        if (_rubbishTiles.contains(tileType)) {
          var tileDivisions = parseRubbishCells(tileType);
          for (int rowNum = 0; rowNum < tileDivisions.length; rowNum++) {
            for (int colNum = 0;
                colNum < tileDivisions.first.length;
                colNum++) {
              if (!tileDivisions[rowNum][colNum]) {
                continue;
              }
              String? useRubbishType;
              for (final rubbishType in _rubbish.keys) {
                if (_rnd.nextDouble() < _rubbish[rubbishType]!) {
                  useRubbishType = rubbishType;
                }
              }
              if (useRubbishType == null) continue;

              var rubbishCoords = Vector3(x + (colNum * 10) - (cellDim / 2),
                  1.7, z - (rowNum * -10) + (cellDim / 2));
              var rubbishEntity = await _filamentController
                  .loadGlb("${_prefix}/assets/${useRubbishType}");

              await _filamentController.setPosition(rubbishEntity,
                  rubbishCoords.x, rubbishCoords.y, rubbishCoords.z);
              await _filamentController.setScale(rubbishEntity, 5.0);
              // await _filamentController.setParent(rubbishEntity, tileEntity);
              await _filamentController.addCollisionComponent(rubbishEntity,
                  affectsCollingTransform: false,
                  callback: (entity1, entity2) async {
                print(
                    "Collision with rubbish $useRubbishType ($entity1 $entity2) when playe rhitbox is $playerHitbox");
                if (entity2 == playerHitbox) {
                  print("Hitbox!");
                  if (_swipeAnimating) {
                    await _filamentController.removeEntity(rubbishEntity);
                    points.value = points.value + 1;
                  }
                }
              });
              print("Added addCollisionComponent to rubbish ${useRubbishType}");
            }
          }
        }
      }
    }
    return start;
  }

  Future initialize() async {
    // await _audioService.initialize();
    await _filamentController.createViewer();
    await _filamentController.setRendering(true);

    final rnd = Random();

    grid = List.generate(_numRows,
        (index) => List.generate(_numRows, (_) => rnd.nextDouble() > 0.5));

    await _filamentController.loadIbl("asset://assets/default_env_ibl.ktx",
        intensity: 30000);

    // await _filamentController
    //     .loadSkybox("asset://assets/default_env_skybox.ktx");
    await _filamentController.setBackgroundColor(m.Colors.blue.shade200);
    player.value =
        await _filamentController.loadGlb("$_prefix/assets/character.glb");
    var playerHitbox = await _filamentController
        .loadGlb("$_prefix/assets/character_hitbox.glb");
    await _filamentController.hide(playerHitbox, null);
    await _filamentController.setParent(playerHitbox, player.value!);
    var startPos = await parse(_map, playerHitbox);
    await _filamentController.playAnimationByName(player.value!, "Surf",
        loop: true, replaceActive: false);

    await _filamentController.setPosition(
        player.value!, startPos.x, startPos.y, startPos.z);

    // var end = await _filamentController.loadGlb(
    //     "$_prefix/assets/end.glb");
    // await _filamentController.playAnimation(end, 0, loop: true);

    // _weapon = await _filamentController.loadGlb(
    //     "$_prefix/assets/weapon.glb");
    // await _filamentController.setParent(_weapon, _player);

    playerController = await _filamentController.control(player.value!,
        translationSpeed: 30.0);

    for (int i = 0; i < 10; i++) {
      var drift =
          await _filamentController.loadGlb("$_prefix/assets/drift.glb");
      await _filamentController.setParent(drift, player.value!);
      Future.delayed(Duration(milliseconds: i * 250)).then((value) async {
        await _filamentController.playAnimation(drift, 0,
            loop: true, replaceActive: false);
      });
    }
    var animations = await _filamentController.getAnimationNames(player.value!);
    var swipeAnimationIndex = animations.indexOf("scoop");
    var swipeAnimationDuration = await _filamentController.getAnimationDuration(
        player.value!, swipeAnimationIndex);
    playerController!.onMouse1Down(() async {
      _swipeAnimating = true;
      await _filamentController.playAnimation(
          player.value!, swipeAnimationIndex,
          replaceActive: false, loop: false);
      await Future.delayed(Duration(milliseconds: 250));
      await _filamentController.testCollisions(playerHitbox);
      // await _filamentController.playAnimation(_weapon, 0,
      //     replaceActive: false, loop: false);
      await Future.delayed(
          Duration(milliseconds: (swipeAnimationDuration * 1000).toInt()));
      _swipeAnimating = false;
    });
    for (final cam in ["MainCamera", "FrontCamera"].reversed) {
      await _filamentController.setCamera(player.value!, cam);
      await _filamentController.setBloom(0.0);
      await _filamentController.setCameraExposure(11.0, 0.005, 70.0);

      await _filamentController.setCameraManipulatorOptions(zoomSpeed: 50);
      await _filamentController.setToneMapping(ToneMapper.LINEAR);
      await _filamentController.addLight(
          0, 9500, 50000, -1.5, 1.25, -4.7, -8, -2.5, -7.7, true);
      await _filamentController.setAntiAliasing(true, true, false);
    }
    // await _filamentController.setMainCamera();
    // await _filamentController.setCameraPosition(200, 500, 200.0);
    // await _filamentController.setCameraRotation(-pi / 2, 1, 0, 0);

    // await _filamentController.markNonTransformableCollidable(_weapon);

    // int rowNum = 20, colNum = 20;
    // for (int rowNum = 0; rowNum < grid.length; rowNum++) {
    //   for (int colNum = 0; colNum < grid.length; colNum++) {
    //     var cell = grid[rowNum][colNum];
    //     if (!cell) {
    //       continue;
    //     }
    //     if (cell) {
    //       var plank = await _filamentController.loadGlb(
    //           "$_prefix/assets/plank.glb");
    //       var x = (-_cellDim * (grid.length / 2)) +
    //           colNum * _cellDim +
    //           (_cellDim / 2);
    //       var y = 0.0;
    //       var z = (-_cellDim * (grid.length / 2)) +
    //           rowNum * _cellDim +
    //           (_cellDim / 2);
    //       await _filamentController.setPosition(plank, x, y, z);

    //       bool canMoveLeft = colNum != 0 && grid[rowNum][colNum - 1];
    //       bool canMoveRight =
    //           colNum != grid.length - 1 && grid[rowNum][colNum + 1];
    //       bool canMoveFront =
    //           rowNum != grid.length - 1 && grid[rowNum + 1][colNum];
    //       bool canMoveBack = rowNum != 0 && grid[rowNum - 1][colNum];

    //       if (!canMoveLeft) {
    //         _addWall(x - _cellDim / 2, y, z, pi / 2);
    //       }

    //       if (!canMoveRight) {
    //         _addWall(x + _cellDim / 2, y, z, pi / 2);
    //       }

    //       if (!canMoveFront) {
    //         _addWall(x, y, z - _cellDim / 2, 0);
    //       }

    //       if (!canMoveBack) {
    //         _addWall(x, y, z + _cellDim / 2, 0);
    //       }
    //     }
    //   }
    // }
    var playerTimer = Timer.periodic(Duration(milliseconds: 16), (_) {
      // _filamentController.queuePositionUpdate(player.value!, 0, 0, -0.75,
      //     relative: true);
    });
    this.ready.value = true;
  }
}
