import 'package:flutter/material.dart';
import '../models/technology.dart';
import '../models/era.dart';
import '../data/technology_data.dart';

class InvestigationModal extends StatefulWidget {
  final BuildContext parentContext;
  final List<String> researchedTechs;
  final GameEra currentEra;
  final Function(Technology) onResearchStarted;
  final VoidCallback onEvolveEra;

  const InvestigationModal({
    super.key,
    required this.parentContext,
    required this.researchedTechs,
    required this.currentEra,
    required this.onResearchStarted,
    required this.onEvolveEra,
  });

  @override
  State<InvestigationModal> createState() => _InvestigationModalState();
}

class _InvestigationModalState extends State<InvestigationModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: GameEra.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.blueGrey[900]?.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyanAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              // Header con Tabs y Botón Cerrar
              Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.cyanAccent,
                        labelColor: Colors.cyanAccent,
                        unselectedLabelColor: Colors.white54,
                        isScrollable: true,
                        tabs: GameEra.values.map((era) {
                          return Tab(
                            child: Text(
                              era.name.toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),



              // Contenido por Era
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: GameEra.values.map((era) {
                    return _buildEraTechnologies(era);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEraTechnologies(GameEra era) {
    final techs = mockTechnologies.where((t) => t.requiredEra == era).toList();

    if (techs.isEmpty) {
      return Center(
        child: Text(
          "No hay tecnologías disponibles para esta era.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // 5 columnas para que sean más pequeñas
        childAspectRatio: 0.75, 
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: techs.length + 1, // +1 para el botón de evolucionar
      itemBuilder: (context, index) {
        if (index == techs.length) {
          return _buildEvolveCard(era);
        }
        return _buildTechCard(techs[index]);
      },
    );
  }

  Widget _buildTechCard(Technology tech) {
    bool isResearched = widget.researchedTechs.contains(tech.id);
    
    // Verificamos si cumple requisitos
    bool reqsMet = true;
    for (var req in tech.requiredTechnologies) {
      if (!widget.researchedTechs.contains(req)) {
        reqsMet = false;
        break;
      }
    }

    // Una tecnología se puede investigar si cumple requisitos Y su era es <= a la actual
    bool isAvailable = !isResearched && reqsMet && tech.requiredEra.level <= widget.currentEra.level;
    bool isLocked = !isResearched && !isAvailable;

    Color borderColor = isResearched 
      ? Colors.greenAccent 
      : (isAvailable ? Colors.cyanAccent : Colors.white24);
      
    Color bgColor = isResearched 
      ? Colors.green.withOpacity(0.2) 
      : (isAvailable ? Colors.blueGrey[800]! : Colors.black45);

    return InkWell(
      onTap: isAvailable ? () {
        widget.onResearchStarted(tech);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Investigando ${tech.name}...")),
        );
      } : () {
        if (isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Requisitos no cumplidos o Era incorrecta.")),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isResearched || isAvailable ? 2 : 1),
        ),
        padding: EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  tech.icon, 
                  size: 32, 
                  color: isLocked ? Colors.white30 : Colors.amber[200]
                ),
                if (isResearched)
                  Positioned(
                    bottom: -5,
                    right: -5,
                    child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                  ),
                if (isLocked)
                  Positioned(
                    bottom: -5,
                    right: -5,
                    child: Icon(Icons.lock, color: Colors.redAccent, size: 16),
                  ),
              ],
            ),
            SizedBox(height: 6),
            Expanded(
              child: Text(
                tech.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLocked ? Colors.white54 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            SizedBox(height: 4),
            // Costos
            if (!isResearched)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 3,
                runSpacing: 2,
                children: [
                  if (tech.costWood > 0) _costBadge(Icons.forest, tech.costWood, isLocked),
                  if (tech.costStone > 0) _costBadge(Icons.landscape, tech.costStone, isLocked),
                  if (tech.costGold > 0) _costBadge(Icons.monetization_on, tech.costGold, isLocked),
                ],
              ),
            if (isResearched)
              Text("COMPLETADO", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _costBadge(IconData icon, int amount, bool isLocked) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: isLocked ? Colors.white30 : Colors.amber),
        SizedBox(width: 2),
        Text(
          "$amount",
          style: TextStyle(color: isLocked ? Colors.white30 : Colors.white70, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildEvolveCard(GameEra era) {
    bool isCurrentEra = widget.currentEra == era;
    bool isPastEra = widget.currentEra.level > era.level;
    bool isNextEra = widget.currentEra.level == era.level - 1;
    
    // Si la era actual ya pasó o es mayor, no se muestra este botón activo
    if (isPastEra || widget.currentEra == GameEra.imperial) {
      return const SizedBox.shrink(); // Podríamos mostrar un "Completado" en la era correspondiente
    }

    // Solo se puede evolucionar si estás en la era inmediatamente anterior a la tab que estás viendo
    // o si estás viendo la de tu propia era y quieres avanzar a la siguiente.
    // Vamos a colocar el botón de evolucionar SOLO en la tab de la era actual para saltar a la próxima.
    if (!isCurrentEra) {
       return const SizedBox.shrink();
    }

    GameEra? nextEra = widget.currentEra.nextEra;
    if (nextEra == null) return const SizedBox.shrink(); // Estás en Imperial

    // Costo mock de evolucionar. Debería venir de datos.
    int costWood = 500 * nextEra.level;
    int costGold = 250 * nextEra.level;

    return InkWell(
      onTap: () {
        widget.onEvolveEra();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("¡Avanzando a ${nextEra.name}!")),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.purple[900]?.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purpleAccent, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.purpleAccent.withOpacity(0.4), blurRadius: 4, spreadRadius: 1),
          ]
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.upgrade, size: 36, color: Colors.purpleAccent),
            const SizedBox(height: 6),
            const Text(
              "EVOLUCIONAR ERA",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 3,
              runSpacing: 2,
              children: [
                _costBadge(Icons.forest, costWood, false),
                _costBadge(Icons.monetization_on, costGold, false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
