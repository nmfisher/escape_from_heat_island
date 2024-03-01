import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:untitled_flutter_game_project/game_view_model.dart';
import 'package:untitled_flutter_game_project/widgets/stroked_text.dart';

class TemperatureWidget extends StatefulWidget {
  final GameViewModel viewModel;

  const TemperatureWidget({super.key, required this.viewModel});

  @override
  State<StatefulWidget> createState() => _TemperatureWidgetState();
}

class _TemperatureWidgetState extends State<TemperatureWidget>
    with TickerProviderStateMixin {
  double _baseTemp = 25.0;
  double _maxTemp = 50.0;

  final double _baseWidth = 30.0; // width of bar at starting temp 25 degrees
  final double _maxWidth = 92.0;
  double _width = 0.0;

  double _tempDelta = 0.0;
  double _temperature = 0.0;
  late AnimationController _shakeController;
  // late AnimationController _scaleController;
  double _scale = 1.0;
  // late Animation<double> _scaleAnimation;
  late AnimationController _temperatureController;

  @override
  void initState() {
    super.initState();
    _temperature = widget.viewModel.temperature.value;

    _width = _baseWidth;

    widget.viewModel.temperature.addListener(_onTemperatureChange);

    // _scaleController = AnimationController(
    //     vsync: this, duration: const Duration(milliseconds: 200));
    _temperatureController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    // _scaleController.addListener(() {
    //   setState(() {});
    // });
    _temperatureController.addListener(() {
      var extraWidth = _maxWidth - _baseWidth;
      var numerator =
          (_temperature + (_temperatureController.value * _tempDelta)) -
              _baseTemp;
      var denominator = _maxTemp - _baseTemp;
      var tempRatio = numerator / denominator;

      _width = _baseWidth + (tempRatio * extraWidth);
      setState(() {});
    });
    // _scaleAnimation =
    //     _scaleController.drive(CurveTween(curve: Curves.easeInQuad));
  }

  Timer? _shakeTimer;
  double? _shakeDelta;

  void _onTemperatureChange() async {
    _tempDelta = widget.viewModel.temperature.value - _temperature;
    _scale = 1.5;
    setState(() {});

    await Future.wait([
      // _scaleController.animateTo(1.0),
      _temperatureController.forward()
    ]);
    _scale = 1.0;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 50));
    // await _scaleController.animateTo(0.0);

    if (widget.viewModel.temperature.value > 35.0) {
      _shakeDelta = widget.viewModel.temperature.value > 45.0 ? 2.0 : 1.0;
      _shaking = true;
      _shakeTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        setState(() {});
      });
    } else {
      _shakeTimer?.cancel();
      _shaking = false;
    }

    _temperature += _tempDelta;
    _tempDelta = 0;
    _temperatureController.reset();
    setState(() {});
  }

  final _rnd = Random();

  bool _shaking = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
        scale: _scale,
        duration: Duration(milliseconds: 750),
        alignment: Alignment.centerLeft,
        child: GestureDetector(
            onTap: () async {
              widget.viewModel.temperature.value += 10.0;
            },
            child: Transform(
                transform: Matrix4.translation(_shaking
                    ? v.Vector3((_rnd.nextDouble() * _shakeDelta!),
                        (_rnd.nextDouble() * _shakeDelta!), 0.0)
                    : v.Vector3.zero()),
                origin: Offset(1, 1),
                alignment: Alignment.centerLeft,
                // scale: 1 + (_scaleAnimation.value * 0.1),
                child: Padding(
                    padding: const EdgeInsets.only(left: 20, top: 20),
                    child: SizedBox(
                        height: 40,
                        child: Stack(children: [
                          Opacity(
                              opacity: 0.7,
                              child: Image.asset("assets_new/ui/coin bar.png")),
                          Padding(
                              padding: const EdgeInsets.only(
                                  top: 7, bottom: 10, left: 38),
                              child: Container(
                                height: 30,
                                width: _width,
                                decoration: BoxDecoration(
                                    color: Color.lerp(
                                        Colors.greenAccent.shade700,
                                        Colors.deepOrange.shade400, //0.0)
                                        ((_temperature +
                                                    (_temperatureController
                                                            .value *
                                                        _tempDelta)) -
                                                _baseTemp) /
                                            (_maxTemp - _baseTemp))),
                              )),
                          Padding(
                              padding: const EdgeInsets.only(left: 70, top: 8),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                        "${(_temperature + (_temperatureController.value * _tempDelta)).toStringAsFixed(1)}°C ",
                                        style: const TextStyle(
                                            fontFamily: "Lilita",
                                            fontSize: 14,
                                            fontWeight: FontWeight.w100,
                                            color: Colors.white)),
                                  ]))
                        ]))))));
  }
}
