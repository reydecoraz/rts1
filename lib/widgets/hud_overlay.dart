import 'package:flutter/material.dart';
import '../models/era.dart';

class HudOverlay extends StatelessWidget {
  final VoidCallback onRefreshPressed;
  final GameEra currentEra;

  const HudOverlay({
    super.key,
    required this.onRefreshPressed,
    required this.currentEra,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent),
            ),
            child: Text(
              currentEra.name.toUpperCase(),
              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
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
