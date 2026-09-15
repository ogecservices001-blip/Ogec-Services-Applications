/// Hors web (Android...) : pas de rechargement de page possible, jamais
/// appelé en pratique — la vérification de version est elle-même gardée
/// par kIsWeb côté appelant.
Future<void> rechargerPage() async {}
