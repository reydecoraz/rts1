import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/building_enums.dart';
import '../data/building_data.dart';

class ConstructionModal extends StatelessWidget {
  final Function(BuildingTypeData) onBuildingSelected;

  const ConstructionModal({super.key, required this.onBuildingSelected});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            height: 480,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blueGrey[900]!.withOpacity(0.85),
                  Colors.black.withOpacity(0.9),
                ],
              ),
              border: Border.all(color: Colors.white24, width: 1.5),
              borderRadius: BorderRadius.circular(24),
            ),
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      border: const Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TabBar(
                            isScrollable: true,
                            labelColor: Colors.amber[400],
                            unselectedLabelColor: Colors.white38,
                            indicatorColor: Colors.amber[400],
                            indicatorWeight: 3,
                            dividerColor: Colors.transparent,
                            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            tabs: const [
                              Tab(text: "CIVIL", icon: Icon(Icons.home_work, size: 18)),
                              Tab(text: "MILITAR", icon: Icon(Icons.security, size: 18)),
                              Tab(text: "DEFENSA", icon: Icon(Icons.shield, size: 18)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),



            // Content
              Expanded(
                child: TabBarView(
                  children: [
                    _buildCategoryGrid(context, BuildingCategory.civil),
                    _buildCategoryGrid(context, BuildingCategory.military),
                    _buildCategoryGrid(context, BuildingCategory.defense),
                  ],
                ),
              ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, BuildingCategory category) {
    final buildings = BuildingData.buildings.where((b) => b.category == category).toList();

    if (buildings.isEmpty) {
      return Center(child: Text("No hay edificios disponibles", style: TextStyle(color: Colors.white54)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // Aumentado para botones más grandes y legibles
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: buildings.length,
      itemBuilder: (context, index) {
        final building = buildings[index];
        return _buildBuildingCard(context, building);
      },
    );
  }

  Widget _buildBuildingCard(BuildContext context, BuildingTypeData building) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onBuildingSelected(building);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber[400]!.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(building.icon, size: 24, color: Colors.amber[400]),
              ),
              const SizedBox(height: 8),
              Text(
                building.name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (building.costWood > 0) _costBadge(Icons.forest, building.costWood, Colors.greenAccent),
                  if (building.costStone > 0) _costBadge(Icons.landscape, building.costStone, Colors.blueGrey[200]!),
                  if (building.costGold > 0) _costBadge(Icons.monetization_on, building.costGold, Colors.amberAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _costBadge(IconData icon, int amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(
          "$amount",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
