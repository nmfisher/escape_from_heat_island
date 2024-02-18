import 'package:flutter/material.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/widgets/camera_options_widget.dart';
import 'package:flutter_filament/widgets/entity_controller_mouse_widget.dart';
import 'package:flutter_filament/widgets/filament_gesture_detector.dart';
import 'package:flutter_filament/widgets/filament_widget.dart';
import 'package:flutter_filament/widgets/light_slider.dart';
import 'package:untitled_flutter_game_project/scene_view_model.dart';
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

class _MyHomePageState extends State<MyHomePage> {
  final viewModel = SceneViewModel();

  final List<({FilamentEntity entity, String name})> cameras = [];

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();

    viewModel.player.addListener(() {
      setState(() {
        cameras.add((entity: viewModel.player.value!, name: "MainCamera"));
      });
    });

    viewModel.initialize().then((_) async {
      await windowManager.ensureInitialized();
      // windowManager.setFullScreen(true);
      setState(() {});
    });
  }

  bool aa = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Positioned.fill(
            child: FilamentGestureDetector(
                enabled: false,
                controller: viewModel.filamentController,
                child: EntityTransformMouseControllerWidget(
                    transformController: viewModel.playerController,
                    child: FilamentWidget(
                      controller: viewModel.filamentController,
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
                icon: Icon(Icons.refresh))),
        Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
                height: 100,
                width: 300,
                child: CameraOptionsWidget(
                    controller: viewModel.filamentController,
                    cameras: cameras)))
        // ValueListenableBuilder(
        //     valueListenable: viewModel.ready,
        //     builder: (_, ready, __) => ready
        //         ? Align(
        //             alignment: Alignment.bottomCenter,
        //             child: Container(
        //                 width: 400,
        //                 height: 400,
        //                 child: LightSliderWidget(
        //                   controller: viewModel.filamentController,
        //                   showControls: true,
        //                 )))
        //         : Container())
      ],
    ));
  }
}
