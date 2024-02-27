import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StrokedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double strokeWidth;

  const StrokedText(
      {super.key,
      required this.text,
      this.fontSize = 24,
      this.strokeWidth = 1.0});
  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.topCenter, children: [
      Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: "Lilita",
              color: Colors.white)),
      Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: "Lilita",
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..color = Color.fromRGBO(71, 43, 3, 1)
                ..strokeWidth = strokeWidth))
    ]);
  }
}
