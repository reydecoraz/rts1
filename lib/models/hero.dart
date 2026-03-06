import 'civilization.dart'; // Para importar CivilizationBonus

class HeroData {
  final String id;
  final String name;
  final String lore;
  final String avatarAssetPath;
  final List<CivilizationBonus> globalBonuses;

  HeroData({
    required this.id,
    required this.name,
    required this.lore,
    required this.avatarAssetPath,
    required this.globalBonuses,
  });
}
