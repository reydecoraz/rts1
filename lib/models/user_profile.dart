class UserProfile {
  final String id;
  String name;
  String? customEmblemPath; // Sobrescribe el emblema por defecto

  // Monetización y Progresión
  List<String> unlockedCivilizationIds;
  List<String> unlockedHeroIds;
  List<String> unlockedSkinIds;

  // Equipamiento Actual
  String activeCivilizationId;
  String? equippedHeroId;
  
  // Mapa de CivID -> SkinID activa
  Map<String, String> activeSkinPerCivilization;

  UserProfile({
    required this.id,
    required this.name,
    this.customEmblemPath,
    this.unlockedCivilizationIds = const [],
    this.unlockedHeroIds = const [],
    this.unlockedSkinIds = const [],
    required this.activeCivilizationId,
    this.equippedHeroId,
    this.activeSkinPerCivilization = const {},
  });
}
