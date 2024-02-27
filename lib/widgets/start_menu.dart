import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:untitled_flutter_game_project/game_view_model.dart';
import 'package:untitled_flutter_game_project/widgets/stroked_text.dart';

class StartMenu extends StatelessWidget {
  final GameViewModel viewModel;

  const StartMenu({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Stack(children: [
      Image.asset("assets_new/ui/empty small panel.png"),
      const Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 10),
            child: StrokedText(text: "MENU"),
          )),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
          child: Column(children: [
            Align(
                alignment: Alignment.center,
                child: GestureDetector(
                    onTap: () {
                      viewModel.start();
                    },
                    child: Stack(children: [
                      Image.asset("assets_new/ui/empty button.png"),
                      const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Center(child: StrokedText(text: "START")))
                    ]))),
            const SizedBox(height: 12.0),
            Align(
                alignment: Alignment.center,
                child: GestureDetector(
                    onTap: () {
                      exit(0);
                    },
                    child: Stack(children: [
                      Image.asset("assets_new/ui/empty button.png"),
                      const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Center(child: StrokedText(text: "EXIT")))
                    ])))
          ])),
    ]));
  }
}
