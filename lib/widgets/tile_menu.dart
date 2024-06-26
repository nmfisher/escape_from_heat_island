import 'package:flutter/material.dart';
import 'package:untitled_flutter_game_project/game_view_model.dart';

class ContextMenuWidget extends StatefulWidget {
  final GameViewModel viewModel;

  const ContextMenuWidget({super.key, required this.viewModel});
  @override
  State<StatefulWidget> createState() => _TileMenuState();
}

class _TileMenuState extends State<ContextMenuWidget>
    with SingleTickerProviderStateMixin {
  // late AnimationController _scaleController;
  @override
  void initState() {
    super.initState();
    // _scaleController = AnimationController(
    //     vsync: this, duration: const Duration(milliseconds: 50));
    // WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
    //   _scaleController.forward();
    // });
  }

  @override
  void dispose() {
    super.dispose();
    // _scaleController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return
        // ScaleTransition(
        //     scale: _scaleController,
        //     child:
        Column(
            children: widget.viewModel.contextMenu.value!.labels
                .map((label) => MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Listener(
                        onPointerDown: (_) {
                          widget.viewModel.contextMenu.value!.click(label);
                        },
                        child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.transparent,
                                image: DecorationImage(
                                    image: AssetImage(
                                        "assets_new/ui/empty button.png"))),
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: Text(label,
                                    style: const TextStyle(
                                        fontFamily: "Lilita",
                                        color: Color(0xFF391f00))))))))
                .toList()
            // )
            );
  }
}
