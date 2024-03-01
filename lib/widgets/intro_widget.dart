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
      } else if (text[_step]
          .startsWith("New residents and families are moving in every")) {
        // await widget.viewModel.playBuildingAnimation();
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
        timer.cancel();
      } else if (text[_step]
          .startsWith("Now let's do it for the whole neighbourhood!")) {
        widget.viewModel.startBuildingLoop();
      } else {
        throw Exception("UNRECOGNIZED");
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      widget.viewModel.playCameraLandscapeAnimation();
      widget.viewModel.startCrowdMotion();
      widget.viewModel.startVehicleMotion();
    });
  }

  List<String> text =
      """Urban heat islands refer to inner-city areas that generate and retain a lot of heat.
Surfaces like concrete and asphalt retain heat from both the sun and the ambient environment, from things like air-conditioning, refrigeration and vehicles.
If temperatures continue to increase, this will be fatal to humans and animals. We need a more sustainable solution!
Planting vegetation provides shade for humans and animals from the sun, and reduces the amount of heat absorbed by roads and footpaths.
Changing the albedo (colour) of surfaces to reflect more light decreases the amount of energy retained by dark surfaces.
Reducing energy consumption and trafffic also reduces ambient heat.
This is a new neighbourhood in Animal City.
New residents and families are moving in every day, meaning more roads, cars, and air-conditioners. Every new building increases the temperature by 1 degree celsius.
It's getting impossibly hot for some of these new residents to walk outside. At 35 degrees celsius, the neighbourhood will be unlivable.
Residents need your help!
Tap the footpath to open the menu and plant a tree.
Tap the road to install a barrier. Fewer cars on the road will cool the neighbourhood!
Now let's do it for the whole neighbourhood!"""
          .split("\n");
  @override
  Widget build(BuildContext context) {
    if (_step == -1 || _step == text.length) {
      return Container();
    }
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(20)),
        child: StrokedText(
          text: text[_step],
          fontSize: 36,
        ));
  }
}
