import 'package:flutter/material.dart';
import '../models/unit_group.dart';
import '../models/unit.dart';
import '../data/unit_data.dart';

/// A compact button that floats above the construction FAB.
/// When tapped, it opens a bottom sheet listing all unit groups.
class GroupsPanelButton extends StatelessWidget {
  final List<UnitGroup> groups;
  final List<Unit> selectedUnits;
  final void Function(UnitGroup group) onSelectGroup;
  final void Function(UnitGroup group) onDeleteGroup;

  const GroupsPanelButton({
    super.key,
    required this.groups,
    required this.selectedUnits,
    required this.onSelectGroup,
    required this.onDeleteGroup,
  });

  // Active groups (at least 1 alive unit)
  List<UnitGroup> get _active => groups.where((g) => !g.isEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final active = _active;
    // Check if the current selection itself is a saved group
    final isGroupSelected = selectedUnits.isNotEmpty;

    return GestureDetector(
      onTap: () => _openPanel(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isGroupSelected
              ? Colors.amberAccent.withValues(alpha: 0.92)
              : Colors.blueGrey[800]!.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isGroupSelected ? Colors.amber : Colors.blueGrey[400]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group,
              size: 18,
              color: isGroupSelected ? Colors.black87 : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              isGroupSelected
                  ? '${selectedUnits.length} sel.'
                  : '${active.length} grupo${active.length != 1 ? "s" : ""}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isGroupSelected ? Colors.black87 : Colors.white,
              ),
            ),
            if (active.isNotEmpty) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_up, size: 16, color: Colors.white60),
            ],
          ],
        ),
      ),
    );
  }

  void _openPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _GroupsSheet(
        groups: _active,
        selectedUnits: selectedUnits,
        onSelectGroup: (g) {
          Navigator.pop(ctx);
          onSelectGroup(g);
        },
        onDeleteGroup: (g) {
          onDeleteGroup(g);
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//  Bottom Sheet
// ────────────────────────────────────────────────────────────────

class _GroupsSheet extends StatelessWidget {
  final List<UnitGroup> groups;
  final List<Unit> selectedUnits;
  final void Function(UnitGroup) onSelectGroup;
  final void Function(UnitGroup) onDeleteGroup;

  const _GroupsSheet({
    required this.groups,
    required this.selectedUnits,
    required this.onSelectGroup,
    required this.onDeleteGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2035),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.group_work, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Grupos de Unidades',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (selectedUnits.isNotEmpty)
                  Chip(
                    label: Text(
                      '${selectedUnits.length} seleccionadas',
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                    backgroundColor: Colors.amberAccent,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Sin grupos guardados.\nArrastra para seleccionar unidades — el grupo se guarda automáticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                itemCount: groups.length,
                itemBuilder: (_, i) => _GroupTile(
                  group: groups[i],
                  isCurrentSelection: _isCurrentSelection(groups[i]),
                  onTap: () => onSelectGroup(groups[i]),
                  onDelete: () => onDeleteGroup(groups[i]),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  bool _isCurrentSelection(UnitGroup g) {
    final alive = g.aliveUnits;
    if (alive.length != selectedUnits.length) return false;
    return alive.every((u) => selectedUnits.contains(u));
  }
}

// ────────────────────────────────────────────────────────────────
//  Single group tile
// ────────────────────────────────────────────────────────────────

class _GroupTile extends StatelessWidget {
  final UnitGroup group;
  final bool isCurrentSelection;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GroupTile({
    required this.group,
    required this.isCurrentSelection,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final comp = group.composition;
    final alive = group.aliveUnits;

    // Aggregate HP percentage
    int totalHp = 0;
    int maxHp = 0;
    for (final u in alive) {
      totalHp += u.currentHealth;
      maxHp += u.currentStats.maxHealth;
    }
    final hpPct = maxHp > 0 ? totalHp / maxHp : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentSelection
              ? Colors.amberAccent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentSelection
                ? Colors.amberAccent.withValues(alpha: 0.6)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            // Group icon badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isCurrentSelection
                    ? Colors.amberAccent.withValues(alpha: 0.25)
                    : Colors.blueGrey[700],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${group.id}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCurrentSelection ? Colors.amberAccent : Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Composition
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Composition chips
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: comp.entries.map((e) {
                      final label = _unitLabel(e.key);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[600],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.value}× $label',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  // HP bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: hpPct,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        hpPct > 0.6 ? Colors.greenAccent : hpPct > 0.3 ? Colors.orange : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Unit count + delete
            Column(
              children: [
                Text(
                  '${alive.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Text('u.', style: TextStyle(color: Colors.white38, fontSize: 10)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _unitLabel(String typeId) {
    try {
      final data = UnitData.units.firstWhere((u) => u.id == typeId);
      return data.name.split(' ').first; // First word only
    } catch (_) {
      return typeId;
    }
  }
}
