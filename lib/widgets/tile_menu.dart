import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:untitled_flutter_game_project/game_view_model.dart';

class TileMenu extends StatefulWidget {
  final GameViewModel viewModel;

  const TileMenu({super.key, required this.viewModel});
  @override
  State<StatefulWidget> createState() => _TileMenuState();
}

class _TileMenuState extends State<TileMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  @override
  void initState() {
    super.initState();
    _scaleController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 250));
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _scaleController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
        scale: _scaleController,
        child: Listener(
            onPointerDown: (_) {
              widget.viewModel.plantTree();
            },
            child: Container(
                color: Colors.white, child: const Text("PLANT TREE"))));
  }
}
