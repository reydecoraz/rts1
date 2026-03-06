import 'package:flutter/material.dart';
import '../data/building_data.dart';

class PlacementBanner extends StatelessWidget {
  final BuildingTypeData selectedBuilding;

  const PlacementBanner({
    super.key,
    required this.selectedBuilding,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amberAccent, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selectedBuilding.isChainingAllowed
                  ? Icons.gesture
                  : Icons.touch_app,
                color: Colors.amberAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                selectedBuilding.isChainingAllowed
                    ? "Arrastra para colocar ${selectedBuilding.name}"
                    : "Toca para colocar ${selectedBuilding.name}",
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
