import 'civilization.dart'; // Para importar CivilizationBonus

class HeroData {
  final String id;
  final String name;
  final String lore;
  final String avatarAssetPath;
  final List<CivilizationBonus> globalBonuses;
  final List<String> uniqueUnits;
  final String heroUnitId;

  HeroData({
    required this.id,
    required this.name,
    required this.lore,
    required this.avatarAssetPath,
    this.globalBonuses = const [],
    this.uniqueUnits = const [],
    required this.heroUnitId,
  });
}
