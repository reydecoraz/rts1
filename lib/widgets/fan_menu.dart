import 'package:flutter/material.dart';
import 'investigation_modal.dart';
import 'tech_tree_viewer.dart';

class FanMenu extends StatelessWidget {
  final VoidCallback onConstructionPressed;

  const FanMenu({super.key, required this.onConstructionPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildActionButton(
          context,
          icon: Icons.account_tree,
          color: Colors.blueGrey[600]!,
          label: "Árbol Tech",
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => const TechTreeViewer(),
            );
          },
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          context,
          icon: Icons.foundation,
          color: Colors.amber[700]!,
          label: "Construir",
          isMain: true,
          onPressed: onConstructionPressed,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
    bool isMain = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: isMain ? 40 : 32,
          height: isMain ? 40 : 32,
          child: FloatingActionButton(
            heroTag: "btn_$label",
            onPressed: onPressed,
            backgroundColor: color,
            child: Icon(icon, size: isMain ? 20 : 16, color: Colors.white),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}
