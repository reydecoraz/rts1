import 'dart:async';
import 'package:flutter/material.dart';
import '../models/building.dart';
import '../models/building_enums.dart';
import '../models/era.dart';
import '../data/unit_data.dart';
import '../data/building_data.dart';
import '../models/technology.dart';
import '../data/technology_data.dart';
import '../services/game_session.dart';
import '../services/data_manager.dart';
import '../models/resource_type.dart';

class BuildingInfoPanel extends StatefulWidget {
  final Building building;
  final VoidCallback onClose;
  final VoidCallback? onSetRallyPoint;
  final VoidCallback? onOpenInvestigation;   // kept for backwards compat, but no longer used
  final GameEra currentEra;
  final List<String> researchedTechs;
  final Function(Technology)? onResearchStarted;
  final VoidCallback? onEvolveEra;
  final Function(UnitTypeData)? onTrainUnit; // Called when user taps a unit to train

  const BuildingInfoPanel({
    super.key,
    required this.building,
    required this.onClose,
    this.onSetRallyPoint,
    this.onOpenInvestigation,
    required this.currentEra,
    this.researchedTechs = const [],
    this.onResearchStarted,
    this.onEvolveEra,
    this.onTrainUnit,
  });

  @override
  State<BuildingInfoPanel> createState() => _BuildingInfoPanelState();
}

class _BuildingInfoPanelState extends State<BuildingInfoPanel> {
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh UI every 100ms so progress bars and queue counts stay live
    // (driven by the real _onTick in GameScreen, not a fake timer)
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(140, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueGrey[900]!.withOpacity(0.9),
            Colors.black.withOpacity(0.95),
          ],
        ),
        border: Border.all(color: Colors.white24, width: 1.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 15, offset: Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Centrado
          Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [widget.building.playerColor.withOpacity(0.4), widget.building.playerColor.withOpacity(0.1)],
                        ),
                        border: Border.all(color: widget.building.playerColor, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: widget.building.playerColor.withOpacity(0.2), blurRadius: 8)],
                      ),
                      child: Icon(_categoryIcon(widget.building.category), color: widget.building.playerColor, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.building.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(width: 140, child: _hpBar()),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Acciones en la misma fila (Producción e Investigación)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.building.availableActions.contains(BuildingAction.production))
                Expanded(
                  child: Column(
                    children: [
                      const Text("PRODUCCIÓN", style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 70,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _buildInlineProductionItems(),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.building.availableActions.contains(BuildingAction.production) &&
                  widget.building.availableActions.contains(BuildingAction.investigation))
                const SizedBox(width: 8), // Separación si están ambas
              if (widget.building.availableActions.contains(BuildingAction.investigation))
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("INVESTIGACIÓN", style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 70,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _buildInlineResearchItems(),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Botón Avanzar de Era (EXCLUSIVO Centro Urbano)
          if (widget.building.name == "Centro Urbano" &&
              widget.currentEra.nextEra != null &&
              widget.onEvolveEra != null) ...[
            const SizedBox(height: 6),
            _buildEvolveEraButton(),
          ],
          
          if (widget.building.availableActions.contains(BuildingAction.trade)) ...[
            const SizedBox(height: 6),
            const Text("MERCADO", style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildTradeControls(),
            const SizedBox(height: 6),
          ],

          if (widget.building.availableActions.contains(BuildingAction.gather)) ...[
            const SizedBox(height: 6),
            const Text("EXTRACCIÓN", style: TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildWorkerControls(),
            const SizedBox(height: 6),
          ],
          
          // Evolución (cuando se agota el recurso)
          if (widget.building.availableActions.contains(BuildingAction.evolve) && widget.building.isDepleted) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                onPressed: _evolveBuilding,
                icon: const Icon(Icons.upgrade, size: 14),
                label: const Text("Evolucionar a Torre"),
              ),
            ),
          ],

          // Acciones residuales (Destruir, Atacar)
          if (widget.building.availableActions.contains(BuildingAction.destruction) || widget.building.availableActions.contains(BuildingAction.attack))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.building.availableActions
                  .where((a) => a == BuildingAction.destruction || a == BuildingAction.attack)
                  .map((action) => _actionButton(action))
                  .toList(),
            ),

          // Rally Point
          if (widget.building.availableActions.contains(BuildingAction.production) && widget.onSetRallyPoint != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                onPressed: widget.onSetRallyPoint,
                icon: const Icon(Icons.flag, size: 14),
                label: const Text("Definir Punto de Reunión"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hpBar() {
    final double ratio = (widget.building.health / widget.building.maxHealth).clamp(0.0, 1.0);
    final Color barColor = ratio > 0.6 ? Colors.green : (ratio > 0.3 ? Colors.orange : Colors.red);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white.withOpacity(0.05),
              color: barColor,
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "${widget.building.health.toInt()}/${widget.building.maxHealth.toInt()}",
          style: const TextStyle(color: Colors.white54, fontSize: 8),
        ),
      ],
    );
  }

  Widget _actionButton(BuildingAction action) {
    final (label, icon, color) = switch (action) {
      BuildingAction.attack => ("Atacar", Icons.gps_fixed, Colors.red[400]!),
      BuildingAction.destruction => ("Demoler", Icons.delete_forever, Colors.orange[400]!),
      _ => ("", Icons.error, Colors.white),
    };

    return ElevatedButton.icon(
      onPressed: () {}, // Handlers for other actions
      icon: Icon(icon, size: 10),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.6), width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        textStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
        minimumSize: const Size(0, 24),
      ),
    );
  }
  List<Widget> _buildInlineProductionItems() {
    final session = GameSession();
    final List<UnitTypeData> units = UnitData.units.where((u) => u.producedIn == widget.building.name).toList();

    if (widget.building.name == "Centro Urbano" && session.activeHeroId != null) {
      final hero = DataManager().getHero(session.activeHeroId!);
      if (hero != null) {
        for (var uniqueId in hero.uniqueUnits) {
          final uData = UnitData.units.where((u) => u.id == uniqueId).firstOrNull;
          if (uData != null && !units.contains(uData)) {
            units.add(uData);
          }
        }
      }
    }

    return units.map((unit) {
      final bool isLocked = widget.currentEra.level < unit.requiredEra.level;
      final bool canAffordResources = session.canAfford(
        f: unit.costFood, w: unit.costWood, g: unit.costGold, s: unit.costStone, c: unit.costCoal,
      );
      final bool hasPopRoom = session.currentPopulation + unit.populationCost <= session.maxPopulation;
      final bool canTrain = !isLocked && canAffordResources && hasPopRoom;
      
      // Contar cuántos hay de este tipo en cola
      int queueCount = widget.building.productionQueue.where((id) => id == unit.id).length;
      bool isCurrentlyProducing = widget.building.productionQueue.isNotEmpty && widget.building.productionQueue.first == unit.id;

      return GestureDetector(
        onTap: canTrain && widget.onTrainUnit != null
            ? () => widget.onTrainUnit!(unit)
            : null,
        child: Opacity(
          opacity: canTrain ? 1.0 : 0.45,
          child: Container(
            width: 64,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: canTrain ? Colors.black45 : Colors.black26,
              border: Border.all(
                color: isLocked
                    ? Colors.red.withOpacity(0.4)
                    : canTrain
                        ? Colors.blueGrey.withOpacity(0.7)
                        : Colors.orange.withOpacity(0.5),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(unit.icon, color: canTrain ? Colors.blue[300] : Colors.white30, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      unit.name,
                      style: TextStyle(
                        color: canTrain ? Colors.white : Colors.white54,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // ── Cost row ──────────────────────────────────
                    Wrap(
                      spacing: 2,
                      runSpacing: 0,
                      children: [
                        if (unit.costFood > 0)
                          _miniCost(Icons.restaurant, unit.costFood, session.food < unit.costFood),
                        if (unit.costWood > 0)
                          _miniCost(Icons.forest, unit.costWood, session.wood < unit.costWood),
                        if (unit.costGold > 0)
                          _miniCost(Icons.monetization_on, unit.costGold, session.gold < unit.costGold),
                        if (unit.costStone > 0)
                          _miniCost(Icons.landscape, unit.costStone, session.stone < unit.costStone),
                        if (unit.costCoal > 0)
                          _miniCost(Icons.bolt, unit.costCoal, session.coal < unit.costCoal),
                        _miniCost(Icons.person, unit.populationCost, !hasPopRoom, isRed: !hasPopRoom),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Progress indicator if producing
                    if (isCurrentlyProducing)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: widget.building.currentProductionProgress,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: Colors.greenAccent,
                          minHeight: 4,
                        ),
                      )
                    else
                      const SizedBox(height: 2),
                  ],
                ),
                if (queueCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text("$queueCount", style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (isLocked)
                  const Positioned(
                    top: -2,
                    left: -2,
                    child: Icon(Icons.lock, color: Colors.redAccent, size: 10),
                  ),
                if (!isLocked && !canTrain)
                  const Positioned(
                    top: -2,
                    left: -2,
                    child: Icon(Icons.block, color: Colors.orangeAccent, size: 10),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _miniCost(IconData icon, int amount, bool lacking, {bool isRed = false}) {
    final Color c = lacking || isRed ? Colors.redAccent : Colors.white60;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: c),
        Text('$amount', style: TextStyle(color: c, fontSize: 7)),
      ],
    );
  }

  Widget _buildCostRow(UnitTypeData unit, bool isLocked) {
    return Wrap(
      spacing: 6,
      children: [
        if (unit.costFood > 0) _costItem(Icons.restaurant, unit.costFood, isLocked ? Colors.white30 : Colors.green[300]!),
        if (unit.costWood > 0) _costItem(Icons.forest, unit.costWood, isLocked ? Colors.white30 : Colors.brown[300]!),
        if (unit.costGold > 0) _costItem(Icons.monetization_on, unit.costGold, isLocked ? Colors.white30 : Colors.yellow[300]!),
        if (unit.costStone > 0) _costItem(Icons.landscape, unit.costStone, isLocked ? Colors.white30 : Colors.grey[400]!),
        _costItem(Icons.timer, unit.productionTime, isLocked ? Colors.white30 : Colors.blueAccent),
      ],
    );
  }

  Widget _costItem(IconData icon, int amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text("$amount", style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  List<Widget> _buildInlineResearchItems() {
    // Show techs available for the current era
    final List<Technology> techs = mockTechnologies
        .where((t) => t.requiredEra.level <= widget.currentEra.level)
        .toList();

    if (techs.isEmpty) {
      return [const Center(child: Text("Sin tecnologías disponibles", style: TextStyle(color: Colors.white54, fontSize: 9)))];
    }

    return techs.map((tech) {
      final bool isResearched = widget.researchedTechs.contains(tech.id);
      final bool reqsMet = tech.requiredTechnologies.every((req) => widget.researchedTechs.contains(req));
      
      final session = GameSession();
      final bool canAfford = session.canAfford(
        w: tech.costWood,
        s: tech.costStone,
        g: tech.costGold,
        c: tech.costCoal,
      );

      final bool isAvailable = !isResearched && reqsMet && canAfford;
      final bool isLocked = !isResearched && (!reqsMet || !canAfford);

      Color borderColor = isResearched
          ? Colors.greenAccent.withOpacity(0.8)
          : (isLocked ? Colors.white24 : Colors.purple.withOpacity(0.7));
      Color iconColor = isResearched
          ? Colors.greenAccent
          : (isLocked ? Colors.white30 : Colors.purple[200]!);

      return GestureDetector(
        onTap: (isAvailable && widget.onResearchStarted != null)
            ? () {
                session.wood -= tech.costWood;
                session.stone -= tech.costStone;
                session.gold -= tech.costGold;
                session.coal -= tech.costCoal;
                widget.onResearchStarted!(tech);
              }
            : null,
        child: Container(
          width: 62,
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isResearched
                ? Colors.green.withOpacity(0.12)
                : Colors.black45,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(tech.icon, color: iconColor, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    tech.name,
                    style: TextStyle(
                      color: isLocked ? Colors.white30 : Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (isResearched)
                    const Text("✓", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold))
                  else
                    const SizedBox(height: 2),
                ],
              ),
              if (isLocked)
                Positioned(
                  top: -2,
                  left: -2,
                  child: Icon(!reqsMet ? Icons.lock : Icons.monetization_on, color: Colors.white30, size: 10),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }




  IconData _categoryIcon(BuildingCategory category) {
    return switch (category) {
      BuildingCategory.civil => Icons.home_work,
      BuildingCategory.military => Icons.security,
      BuildingCategory.defense => Icons.shield,
    };
  }

  Widget _buildWorkerControls() {
    final bData = BuildingData.buildings.firstWhere((b) => b.name == widget.building.name);
    final int maxWorkers = bData.maxWorkers;
    if (maxWorkers <= 0) {
      return const SizedBox();
    }

    String mechanicsText = (bData.name == "Campamento Maderero")
        ? "Asignar Leñadores (Mecánica Especial)"
        : "Asignar Trabajadores (Calculado en Población)";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mechanicsText, style: const TextStyle(color: Colors.amberAccent, fontSize: 9)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, color: Colors.amberAccent, size: 16),
              const SizedBox(width: 6),
              Text(
                "${widget.building.currentWorkers} / $maxWorkers",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(width: 12),
              _workerBtn(Icons.remove, () {
                if (widget.building.currentWorkers > 0) {
                  setState(() {
                    widget.building.currentWorkers--;
                    GameSession().releasePopulation(1);
                  });
                }
              }),
              const SizedBox(width: 6),
              _workerBtn(Icons.add, () {
                if (widget.building.currentWorkers < maxWorkers) {
                  if (GameSession().tryConsumePopulation(1)) {
                    setState(() {
                      widget.building.currentWorkers++;
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Población llena (${GameSession().currentPopulation}/${GameSession().maxPopulation}). Construye una Casa.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTradeControls() {
    return Column(
      children: [
        _tradeRow(ResourceType.wood, "Madera", Icons.forest, Colors.brown[300]!),
        _tradeRow(ResourceType.food, "Comida", Icons.restaurant, Colors.green[300]!),
        _tradeRow(ResourceType.stone, "Piedra", Icons.landscape, Colors.grey[400]!),
        _tradeRow(ResourceType.coal, "Carbón", Icons.bolt, Colors.black87),
      ],
    );
  }

  Widget _tradeRow(ResourceType type, String name, IconData icon, Color color) {
    final session = GameSession();
    int buyCost = 150;
    int sellReward = 50;
    int amount = 100;
    
    // Check if player has enough resource to sell
    bool canSell = false;
    switch(type) {
      case ResourceType.wood: canSell = session.wood >= amount; break;
      case ResourceType.food: canSell = session.food >= amount; break;
      case ResourceType.stone: canSell = session.stone >= amount; break;
      case ResourceType.coal: canSell = session.coal >= amount; break;
      default: break;
    }
    
    // Check if player has enough gold to buy
    bool canBuy = session.gold >= buyCost;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Row(
             children: [
               Icon(icon, color: color, size: 14),
               const SizedBox(width: 4),
               Text(name, style: const TextStyle(color: Colors.white, fontSize: 10)),
             ],
           ),
           Row(
             children: [
               ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.green.withOpacity(0.2),
                   foregroundColor: Colors.greenAccent,
                   padding: const EdgeInsets.symmetric(horizontal: 4),
                   minimumSize: const Size(60, 24),
                 ),
                 onPressed: canSell ? () {
                   setState(() {
                     switch(type) {
                       case ResourceType.wood: session.wood -= amount; break;
                       case ResourceType.food: session.food -= amount; break;
                       case ResourceType.stone: session.stone -= amount; break;
                       case ResourceType.coal: session.coal -= amount; break;
                       default: break;
                     }
                     session.gold += sellReward;
                   });
                 } : null,
                 child: Text("Vender x$amount\n(+$sellReward Oro)", textAlign: TextAlign.center, style: const TextStyle(fontSize: 7)),
               ),
               const SizedBox(width: 4),
               ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.blue.withOpacity(0.2),
                   foregroundColor: Colors.lightBlueAccent,
                   padding: const EdgeInsets.symmetric(horizontal: 4),
                   minimumSize: const Size(60, 24),
                 ),
                 onPressed: canBuy ? () {
                   setState(() {
                     session.gold -= buyCost;
                     switch(type) {
                       case ResourceType.wood: session.wood += amount; break;
                       case ResourceType.food: session.food += amount; break;
                       case ResourceType.stone: session.stone += amount; break;
                       case ResourceType.coal: session.coal += amount; break;
                       default: break;
                     }
                   });
                 } : null,
                 child: Text("Comprar x$amount\n(-$buyCost Oro)", textAlign: TextAlign.center, style: const TextStyle(fontSize: 7)),
               )
             ]
           )
        ]
      )
    );
  }

  Widget _workerBtn(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueGrey[700]!, Colors.blueGrey[900]!],
          ),
          border: Border.all(color: Colors.white24, width: 1.0),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  void _evolveBuilding() {
     final currentData = BuildingData.buildings.firstWhere((b) => b.name == widget.building.name);
     if (currentData.evolvesInto == null) return;
     
     final targetData = BuildingData.buildings.firstWhere((b) => b.name == currentData.evolvesInto);
     
     setState(() {
        // Transformar el edificio in-place
        widget.building.name = targetData.name;
        widget.building.category = targetData.category;
        widget.building.availableActions.clear();
        widget.building.availableActions.addAll(targetData.availableActions);
        
        widget.building.isDepleted = false;
        widget.building.currentWorkers = 0;
        
        widget.building.isUnderConstruction = true;
        widget.building.constructionTotalSeconds = targetData.constructionTime;
        widget.building.constructionRemainingSeconds = targetData.constructionTime;
     });
     
     widget.onClose(); // Cerrar el panel para que el usuario vea la transformación
  }

  Widget _buildEvolveEraButton() {
    final nextEra = widget.currentEra.nextEra!;
    final session = GameSession();
    
    final bool canAfford = session.canAfford(
      f: widget.currentEra.evolutionCostFood,
      w: widget.currentEra.evolutionCostWood,
      s: widget.currentEra.evolutionCostStone,
      g: widget.currentEra.evolutionCostGold,
      c: widget.currentEra.evolutionCostCoal,
    );

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 30,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? Colors.purpleAccent.withOpacity(0.2) : Colors.black45,
              foregroundColor: canAfford ? Colors.purpleAccent[100] : Colors.white54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: canAfford ? Colors.purpleAccent : Colors.white24, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: canAfford ? () {
              session.wood -= widget.currentEra.evolutionCostWood;
              session.food -= widget.currentEra.evolutionCostFood;
              session.gold -= widget.currentEra.evolutionCostGold;
              session.stone -= widget.currentEra.evolutionCostStone;
              session.coal -= widget.currentEra.evolutionCostCoal;
              widget.onEvolveEra!();
            } : null,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              "AVANZAR A ${nextEra.name.toUpperCase()}",
              style: const TextStyle(letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: [
            if (widget.currentEra.evolutionCostFood > 0)
              _miniCost(Icons.restaurant, widget.currentEra.evolutionCostFood, session.food < widget.currentEra.evolutionCostFood),
            if (widget.currentEra.evolutionCostWood > 0)
              _miniCost(Icons.forest, widget.currentEra.evolutionCostWood, session.wood < widget.currentEra.evolutionCostWood),
            if (widget.currentEra.evolutionCostGold > 0)
              _miniCost(Icons.monetization_on, widget.currentEra.evolutionCostGold, session.gold < widget.currentEra.evolutionCostGold),
            if (widget.currentEra.evolutionCostStone > 0)
              _miniCost(Icons.landscape, widget.currentEra.evolutionCostStone, session.stone < widget.currentEra.evolutionCostStone),
            if (widget.currentEra.evolutionCostCoal > 0)
              _miniCost(Icons.bolt, widget.currentEra.evolutionCostCoal, session.coal < widget.currentEra.evolutionCostCoal),
          ],
        ),
      ],
    );
  }
}

