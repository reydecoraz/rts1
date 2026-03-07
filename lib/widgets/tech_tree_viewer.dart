import 'package:flutter/material.dart';
import '../models/era.dart';
import '../models/building_enums.dart';
import '../models/technology.dart';
import '../data/building_data.dart';
import '../data/technology_data.dart';
import '../data/unit_data.dart';
import '../services/data_manager.dart';
import '../services/game_session.dart';

class TechTreeViewer extends StatelessWidget {
  const TechTreeViewer({super.key});

  @override
  Widget build(BuildContext context) {
    // Escogemos los edificios que realmente figuran en el árbol de progreso (Militares, Centro Urbano, Defensas, Mercado).
    final rootBuildings = BuildingData.buildings.where((b) {
      return b.category == BuildingCategory.military || 
             b.category == BuildingCategory.defense || 
             b.name == "Centro Urbano" || 
             b.name == "Mercado";
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.blueGrey[900]?.withValues(alpha: 0.95),
          border: Border.all(color: Colors.amber[700]!, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15)],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: Colors.amber[700]!, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_tree, color: Colors.amber[400], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        "ÁRBOL TECNOLÓGICO",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            
            // Area Principal
            Expanded(
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(100),
                minScale: 0.5,
                maxScale: 2.0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezados de Columna (Eras)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(width: 120), // Espacio de encabezados de filas (Building)
                          ...GameEra.values.map((era) => _buildEraHeader(era)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Filas (Edificios)
                      ...rootBuildings.map((bg) => _buildBuildingRow(context, bg)),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer (Leyenda)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(Icons.architecture, "Edificio", Colors.brown[400]!),
                  const SizedBox(width: 16),
                  _buildLegendItem(Icons.person, "Unidad", Colors.blueGrey[600]!),
                  const SizedBox(width: 16),
                  _buildLegendItem(Icons.lightbulb, "Tecnología", Colors.indigo[400]!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEraHeader(GameEra era) {
    return Container(
      width: 280, // Ancho fijo por Era
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.amber[700]!, width: 2)),
      ),
      child: Center(
        child: Text(
          era.name.toUpperCase(),
          style: TextStyle(
            color: Colors.amber[400],
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBuildingRow(BuildContext context, BuildingTypeData building) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Y-Axis Header (Nombre del edificio)
          SizedBox(
            width: 120,
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.brown[600],
                  radius: 20,
                  child: Icon(building.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  building.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Celdas por Era (Columnas)
          ...GameEra.values.map((era) {
             return _buildEraCell(context, building, era);
          }),
        ],
      ),
    );
  }

  Widget _buildEraCell(BuildContext context, BuildingTypeData building, GameEra era) {
    final activeCivId = GameSession().activeCivilizationId;
    
    // 1. Filtrar Unidades
    var units = UnitData.units.where((u) => u.producedIn == building.name && u.requiredEra == era).toList();
    units = units.where((u) => DataManager().isItemAllowedForCiv(u.id, activeCivId)).toList();
    
    // 2. Filtrar Tecnologías (Como no tienen 'producedIn', asignamos lógicamente según nuestra preferencia estética)
    List<Technology> techs = [];
    if (building.name == "Centro Urbano") {
      techs = mockTechnologies.where((t) => t.requiredEra == era && (t.id.contains("agriculture") || t.id.contains("wheel") || t.id.contains("architecture"))).toList();
    } else if (building.name == "Cuartel") {
      techs = mockTechnologies.where((t) => t.requiredEra == era && (t.id.contains("stone_tools") || t.id.contains("bronze_working") || t.id.contains("iron_working"))).toList();
    } else if (building.name == "Torre" || building.name == "Muro") {
      techs = mockTechnologies.where((t) => t.requiredEra == era && t.id.contains("fortification")).toList();
    } else if (building.name == "Galería de Tiro") {
       techs = mockTechnologies.where((t) => t.requiredEra == era && t.id.contains("gunpowder")).toList();
    }
    techs = techs.where((t) => DataManager().isItemAllowedForCiv(t.id, activeCivId)).toList();
    
    // Si es la Era en la que se desbloquea el edificio según el juego
    bool isBuildingIntro = false;
    if (era == GameEra.stone && (building.name == "Centro Urbano" || building.name == "Cuartel" || building.category == BuildingCategory.defense)) isBuildingIntro = true;
    if (era == GameEra.bronze && (building.name == "Galería de Tiro" || building.name == "Mercado")) isBuildingIntro = true;
    if (era == GameEra.iron && (building.name == "Establo")) isBuildingIntro = true;
    if (era == GameEra.imperial && (building.name == "Taller de Asedio")) isBuildingIntro = true;

    if (!isBuildingIntro && units.isEmpty && techs.isEmpty) {
      // Celda vacía
      return Container(
        width: 280,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          height: 2,
          color: Colors.white10,
        ), // Línea continua sutil
      );
    }

    return Container(
       width: 280,
       margin: const EdgeInsets.symmetric(horizontal: 8),
       child: Column(
          children: [
            if (isBuildingIntro) ...[
              _buildItemCard(context, building, Colors.brown[400]!),
              if (units.isNotEmpty || techs.isNotEmpty) _buildConnector(),
            ],
            
            if (units.isNotEmpty || techs.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 1),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black12,
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    ...units.map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: _buildItemCard(context, u, Colors.blueGrey[600]!),
                    )),
                    ...techs.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: _buildItemCard(context, t, Colors.indigo[400]!),
                    )),
                  ],
                ),
              )
         ],
       ),
    );
  }

  Widget _buildItemCard(BuildContext context, dynamic item, Color bgColor) {
    String title = "";
    IconData icon = Icons.help;
    
    if (item is BuildingTypeData) {
      title = item.name;
      icon = item.icon;
    } else if (item is UnitTypeData) {
      title = item.name;
      icon = item.icon;
    } else if (item is Technology) {
      title = item.name;
      icon = item.icon;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showItemDetails(context, item),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(BuildContext context, dynamic item) {
    String title = "";
    String description = "";
    IconData icon = Icons.help;
    int costWood = 0;
    int costStone = 0;
    int costGold = 0;
    int costCoal = 0;
    int costFood = 0;
    int time = 0;

    if (item is BuildingTypeData) {
      title = item.name;
      description = item.description;
      icon = item.icon;
      costWood = item.costWood;
      costStone = item.costStone;
      costGold = item.costGold;
      costCoal = item.costCoal;
      time = item.constructionTime;
    } else if (item is UnitTypeData) {
      title = item.name;
      description = item.description;
      icon = item.icon;
      costFood = item.costFood;
      costWood = item.costWood;
      costStone = item.costStone;
      costGold = item.costGold;
      costCoal = item.costCoal;
      time = item.productionTime;
    } else if (item is Technology) {
      title = item.name;
      description = item.description;
      icon = item.icon;
      costWood = item.costWood ?? 0;
      costStone = item.costStone ?? 0;
      costGold = item.costGold ?? 0;
      time = item.researchTimeSeconds;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey[900],
            border: Border.all(color: Colors.amber[700]!, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blueGrey[800],
                    child: Icon(icon, color: Colors.amber[400]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text("Costos y Tiempo", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (costFood > 0) _buildStatBadge(Icons.restaurant, costFood.toString(), Colors.redAccent),
                    if (costWood > 0) _buildStatBadge(Icons.forest, costWood.toString(), Colors.green),
                    if (costStone > 0) _buildStatBadge(Icons.landscape, costStone.toString(), Colors.grey),
                    if (costGold > 0) _buildStatBadge(Icons.monetization_on, costGold.toString(), Colors.amber),
                    if (costCoal > 0) _buildStatBadge(Icons.terrain, costCoal.toString(), Colors.grey[800]!),
                    if (time > 0) _buildStatBadge(Icons.access_time, "${time}s", Colors.lightBlue),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildConnector() {
    return Container(
      width: 2,
      height: 16,
      color: Colors.white30,
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
