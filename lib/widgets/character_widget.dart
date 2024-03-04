import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:untitled_flutter_game_project/game_view_model.dart';
import 'package:untitled_flutter_game_project/widgets/stroked_text.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class CharacterWidget extends StatefulWidget {
  final GameViewModel viewModel;

  const CharacterWidget({super.key, required this.viewModel});
  @override
  State<StatefulWidget> createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;

  Timer? _shakeTimer;
  bool _shaking = false;
  double? _shakeDelta;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    // _scaleAnimation =
    //     _scaleController.drive(CurveTween(curve: Curves.easeInQuad));
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Image.asset("assets_new/ui/character_bar.png", height: 85),
      SizedBox(width: 20),
      ValueListenableBuilder(
          valueListenable: widget.viewModel.numPassedOut,
          builder: (_, numPassedOut, __) {
            return StrokedText(
              text: (widget.viewModel.numCharacters - numPassedOut).toString(),
              fontSize: 48,
            );
          }),
      StrokedText(text: "/${widget.viewModel.numCharacters}")
    ]);
    return Transform(
        transform: Matrix4.translation(_shaking
            ? v.Vector3((_rnd.nextDouble() * _shakeDelta!),
                (_rnd.nextDouble() * _shakeDelta!), 0.0)
            : v.Vector3.zero()),
        origin: const Offset(1, 1),
        alignment: Alignment.centerLeft,
        // scale: 1 + (_scaleAnimation.value * 0.1),
        child: Padding(
            padding: const EdgeInsets.only(left: 20, top: 20),
            child: SizedBox(
                height: 40,
                child: Stack(children: [
                  Opacity(
                      opacity: 0.7,
                      child: Image.asset("assets_new/ui/character_bar.png")),
                  const Padding(
                      padding: EdgeInsets.only(left: 70, top: 8),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text("CHARS ",
                                style: TextStyle(
                                    fontFamily: "Lilita",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w100,
                                    color: Colors.white)),
                          ]))
                ]))));
  }
}
