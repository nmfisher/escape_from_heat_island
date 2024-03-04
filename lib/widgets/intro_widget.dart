import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:untitled_flutter_game_project/game_view_model.dart';
import 'package:untitled_flutter_game_project/widgets/stroked_text.dart';

class IntroWidget extends StatefulWidget {
  final GameViewModel viewModel;
  const IntroWidget({super.key, required this.viewModel});

  @override
  State<StatefulWidget> createState() => _IntroWidgetState();
}

class _IntroWidgetState extends State<IntroWidget> {
  int _step = -1;

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_step > -1) {
        if (text[_step].startsWith(
                "Tap the footpath to open the menu and plant a tree.") &&
            !widget.viewModel.introTreePlanted) {
          return;
        } else if (text[_step].startsWith("Tap the road") &&
            !widget.viewModel.introBarrierErected) {
          return;
        }
      }

      setState(() {
        _step = min(_step + 1, text.length);
      });
      if (_step >= text.length) {
        timer.cancel();
        return;
      }
      if (text[_step].startsWith("This is a new neighbourhood")) {
        await widget.viewModel.playIntroAnimation();
      } else if (text[_step].startsWith("New residents")) {
        widget.viewModel.temperature.value += 2.5;
      } else if (text[_step].startsWith("It's getting impossibly hot")) {
        widget.viewModel.temperature.value += 2.5;
      } else if (text[_step].startsWith("Residents need your help!")) {
        widget.viewModel.temperature.value += 2.5;
      } else if (text[_step]
          .startsWith("Tap the footpath to open the menu and plant a tree.")) {
        widget.viewModel.temperature.value += 2.5;
        await widget.viewModel.stopCameraLandscapeAnimation();
      } else if (text[_step].startsWith("Tap the road to install a barrier ")) {
        await widget.viewModel.stopCameraLandscapeAnimation();
        timer.cancel();
      } else if (text[_step].startsWith("Plant trees")) {
        await widget.viewModel.stopCameraLandscapeAnimation();
        widget.viewModel.startBuildingLoop();
      } else {
        throw Exception("UNRECOGNIZED");
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await widget.viewModel.startCrowdMotion();
      await widget.viewModel.startVehicleMotion();
    });
  }

  List<String> text =
      """City areas that generate and retain heat are called "urban heat islands".
Concrete and asphalt absorb heat from the sun, air-conditioning, refrigeration and vehicles.
Increasing temperatures will be fatal to humans and animals. We need a more sustainable solution!
Planting vegetation provides shade for humans and animals from the sun, and reduces the amount of heat absorbed by roads and footpaths.
Better energy efficiency and less traffic will also lower the ambient temperature.
This is a new neighbourhood in Animal City.
New residents move in every day, meaning more roads, cars, and air-conditioners.
It's getting impossibly hot to walk outside. At 35°C, the neighbourhood will be unlivable.
Every new building increases the temperature by 1°C. They need your help! 
Tap the footpath to open the menu and plant a tree.
Tap the road to install a barrier. Fewer cars means less heat!
Plant trees as quickly as possible before all the residents faint from the heat!"""
          .split("\n");
  @override
  Widget build(BuildContext context) {
    if (_step == -1 || _step == text.length) {
      return Container();
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: StrokedText(
          text: text[_step],
          fontSize: 36,
        ));
  }
}
