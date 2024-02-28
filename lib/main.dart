import 'package:flutter/material.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/widgets/filament_gesture_detector.dart';
import 'package:flutter_filament/widgets/filament_widget.dart';
import 'package:untitled_flutter_game_project/game_view_model.dart';
import 'package:untitled_flutter_game_project/widgets/intro_widget.dart';
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

  bool _ready = false;

  final List<({FilamentEntity entity, String name})> cameras = [];

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();

    viewModel.initialize(this).then((_) async {
      await windowManager.ensureInitialized();
      // windowManager.setFullScreen(true);
      setState(() {});
      _ready = true;
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
                              viewModel.setCanOpenTileMenu(true);
                            },
                            onPointerMove: (move) {
                              // viewModel.setCanOpenTileMenu(false);
                              // viewModel.cameraOrientation.position.x -=
                              //     move.delta.dx / 10;
                              // viewModel.filamentController.setCameraPosition(
                              //     viewModel.cameraOrientation.position.x,
                              //     viewModel.cameraOrientation.position.y,
                              //     viewModel.cameraOrientation.position.z);
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
                    if (state == GameState.Loaded)
                      Positioned(
                          top: 20,
                          left: 20,
                          right: 20,
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
                    //       alignment: Alignment.bottomCenter,
                    //       child: Container(
                    //           width: 400,
                    //           height: 400,
                    //           child: LightSliderWidget(
                    //             controller: viewModel.filamentController,
                    //             options: viewModel.lightOptions,
                    //             showControls: true,
                    //           ))),
                    // if (state == GameState.Loaded || state == GameState.Pause)
                    //   Center(
                    //       child: SizedBox(
                    //           height: 350,
                    //           width: 250,
                    //           child: StartMenu(
                    //             viewModel: viewModel,
                    //           ))),
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
