import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/widgets/filament_gesture_detector.dart';
import 'package:flutter_filament/widgets/filament_widget.dart';
import 'package:flutter_filament/widgets/ibl_rotation_slider.dart';
import 'package:flutter_filament/widgets/light_slider.dart';
import 'package:untitled_flutter_game_project/game_view_model.dart';
import 'package:untitled_flutter_game_project/widgets/intro_widget.dart';
import 'package:untitled_flutter_game_project/widgets/start_menu.dart';
import 'package:untitled_flutter_game_project/widgets/stroked_text.dart';
import 'package:untitled_flutter_game_project/widgets/temperature_widget.dart';
import 'package:untitled_flutter_game_project/widgets/tile_menu.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // showPerformanceOverlay: true,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Untitled Flutter Game Project'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final viewModel = GameViewModel();

  final List<({FilamentEntity entity, String name})> cameras = [];

  int _loadingOpacity = 1;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
      ]);
    }

    _loadingTimer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
      if (_loadingOpacity == 1) {
        _loadingOpacity = 0;
      } else {
        _loadingOpacity = 1;
      }
      setState(() {});
    });

    viewModel.initialize(this).then((_) async {
      await windowManager.ensureInitialized();
      _loadingTimer!.cancel();
      // windowManager.setFullScreen(true);
    });
  }

  bool aa = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: ValueListenableBuilder(
            valueListenable: viewModel.state,
            builder: (_, state, __) => Stack(
                  children: [
                    Positioned.fill(
                        child: Listener(
                            onPointerDown: (event) {
                              viewModel.closeContextMenu();
                            },
                            onPointerUp: (event) {
                              Future.delayed(Duration(milliseconds: 100))
                                  .then((value) {
                                viewModel.setCanOpenTileMenu(true);
                              });
                            },
                            onPointerMove: (move) {
                              if (viewModel.enableCameraMovement) {
                                viewModel.setCanOpenTileMenu(false);
                                if (move.buttons == kTertiaryButton) {
                                  viewModel.moveCamera(z: move.delta.dy / 10);
                                } else {
                                  viewModel.moveCamera(x: -move.delta.dx / 10);
                                }
                              }
                            },
                            child: FilamentGestureDetector(
                                enableCamera: true,
                                enablePicking: true,
                                controller: viewModel.filamentController,
                                child:
                                    // EntityTransformMouseControllerWidget(
                                    //     transformController: null,
                                    // viewModel.cameraController,
                                    // child:
                                    FilamentWidget(
                                  controller: viewModel.filamentController,
                                  initial: Container(
                                    color: Colors.black,
                                  ),
                                  // )
                                )))),
                    Align(
                        alignment: Alignment.bottomRight,
                        child: IconButton(
                            onPressed: () {
                              if (aa) {
                                viewModel.filamentController
                                    .setAntiAliasing(false, false, false);
                              } else {
                                viewModel.filamentController
                                    .setAntiAliasing(true, true, false);
                              }
                              aa = !aa;
                            },
                            icon: const Icon(Icons.refresh))),
                    if (state == GameState.Loading)
                      Center(
                          child: AnimatedOpacity(
                              opacity: _loadingOpacity.toDouble(),
                              duration: Duration(milliseconds: 500),
                              child: StrokedText(text: "LOADING"))),
                    if (state == GameState.Play)
                      Positioned(
                          top: 100,
                          left: 100,
                          right: 100,
                          child: IntroWidget(
                            viewModel: viewModel,
                          )),
                    // Align(
                    //     alignment: Alignment.bottomLeft,
                    //     child: SizedBox(
                    //         height: 600,
                    //         width: 300,
                    //         child: CameraOptionsWidget(
                    //             cameraOrientation: viewModel.cameraOrientation,
                    //             controller: viewModel.filamentController,
                    //             cameras: cameras))),
                    // if (state == GameState.Loaded || state == GameState.Pause)
                    //   Align(
                    //       alignment: Alignment.bottomRight,
                    //       child: Container(
                    //           width: 400,
                    //           height: 400,
                    //           child: LightSliderWidget(
                    //             controller: viewModel.filamentController,
                    //             options: viewModel.lightOptions,
                    //             showControls: true,
                    //           ))),
                    if (state == GameState.Loaded || state == GameState.Pause)
                      Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                              width: 400,
                              height: 400,
                              child: IblRotationSliderWidget(
                                controller: viewModel.filamentController,
                              ))),
                    if (state == GameState.Loaded || state == GameState.Pause)
                      Center(
                          child: StartMenu(
                        viewModel: viewModel,
                      )),
                    if (state == GameState.Play)
                      Align(
                          alignment: Alignment.topLeft,
                          child: TemperatureWidget(
                            viewModel: viewModel,
                          )),
                    ValueListenableBuilder(
                        valueListenable: viewModel.contextMenu,
                        builder: (_, contextMenu, __) => contextMenu != null
                            ? Positioned(
                                left: contextMenu!.offset.dx,
                                top: contextMenu.offset.dy,
                                child: ContextMenuWidget(viewModel: viewModel))
                            : Container())
                  ],
                )));
  }
}
