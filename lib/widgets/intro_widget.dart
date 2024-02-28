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
      if (_step > -1 &&
          text[_step].startsWith(
              "Tap the footpath to open the menu and plant a tree.")) {
        if (!widget.viewModel.introTreePlanted) {
          return;
        }
      }
      setState(() {
        _step = min(_step + 1, text.length - 1);
      });
      if (text[_step].startsWith("This is a new neighbourhood")) {
        await widget.viewModel.playIntroAnimation();
      } else if (text[_step]
          .startsWith("Every new building increases the temperature")) {
        await widget.viewModel.playBuildingAnimation();
      } else if (text[_step]
          .startsWith("Tap the footpath to open the menu and plant a tree.")) {
        print("Waiting for user input");
      } else if (text[_step].startsWith("Decrease traffic by ")) {
        await widget.viewModel.playDecreaseTrafficAnimation();
        timer.cancel();
      } else {
        throw Exception("UNRECOGNIZED");
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // widget.viewModel.playCameraLandscapeAnimation();
      widget.viewModel.startCrowdMotion();
      widget.viewModel.startVehicleMotion();
    });
  }

  List<String> text =
//       """Urban environments generate and retain a lot of heat, creating an "urban heat island" effect.
// The sheer density of air-conditioning, refrigeration and emissions from vehicles generate a lot of heat.
// Surfaces like concrete and asphalt also soak up and retain heat from the sun and the surrounding environment.
// If temperatures continue to increase, this will be fatal to humans and animals. We need a more sustainable solution!
// Planting vegetation provides shade for humans and animals from the sun, and reduces the amount of heat absorbed by roads and footpaths.
// Changing the albedo (colour) of surfaces to reflect more light decreases the amount of energy retained by dark surfaces.
// Reducing energy consumption and trafffic also reduces ambient heat.
      """This is a new neighbourhood in Animal City.
New residents and families are moving in every day, meaning more roads, cars, and air-conditioners. Every new building increases the temperature by 1 degree celsius.
It's getting impossibly hot for some of these new residents to walk outside. At 35 degrees celsius, the neighbourhood will be unlivable.
Residents need your help!
Tap the footpath to open the menu and plant a tree.
Decrease traffic by installing barriers!
"""
          .split("\n");
  @override
  Widget build(BuildContext context) {
    if (_step == -1) {
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
