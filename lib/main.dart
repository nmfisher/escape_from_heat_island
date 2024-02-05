import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();

    viewModel.initialize().then((_) async {
      await windowManager.ensureInitialized();
      windowManager.setFullScreen(true);
      setState(() {});
      print("viewModel.playerController ${viewModel.playerController}");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Positioned.fill(
            child: FilamentGestureDetector(
                controller: viewModel.filamentController,
                child: EntityTransformMouseControllerWidget(
                    transformController: viewModel.playerController,
                    child: FilamentWidget(
                      controller: viewModel.filamentController,
                    )))),
        ValueListenableBuilder(
            valueListenable: viewModel.ready,
            builder: (_, ready, __) => ready
                ? LightSliderWidget(controller: viewModel.filamentController)
                : Container())
      ],
    ));
  }
}
