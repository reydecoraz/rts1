import 'package:flutter/material.dart';
import '../models/era.dart';

class HudOverlay extends StatelessWidget {
  final VoidCallback onRefreshPressed;

  const HudOverlay({
    super.key,
    required this.onRefreshPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          FloatingActionButton(
            heroTag: "refresh_btn",
            onPressed: onRefreshPressed,
            tooltip: "Reiniciar partida",
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
