import 'reference_horaire_model.dart';

String _normaliser(String s) => s.trim().toLowerCase();

/// Cherche la ligne du catalogue dont Type Equipement 1/2/3 correspond
/// exactement à ceux de l'équipement (`champsEnTete['typeEquipement1']`
/// etc., insensible à la casse/espaces) — remplace l'ancienne
/// suggestion heuristique ("Split Autonome" par défaut) : plus de
/// devinette, seulement une correspondance exacte ou rien (le
/// technicien choisit alors manuellement via le sélecteur).
ReferenceHoraireModel? trouverReferenceExacte({
  required Map<String, dynamic> champsEnTete,
  required List<ReferenceHoraireModel> references,
}) {
  final t1 = _normaliser(champsEnTete['typeEquipement1']?.toString() ?? '');
  if (t1.isEmpty) return null;
  final t2 = _normaliser(champsEnTete['typeEquipement2']?.toString() ?? '');
  final t3 = _normaliser(champsEnTete['typeEquipement3']?.toString() ?? '');

  for (final r in references) {
    if (_normaliser(r.typeEquipement1) == t1 &&
        _normaliser(r.typeEquipement2) == t2 &&
        _normaliser(r.typeEquipement3) == t3) {
      return r;
    }
  }
  return null;
}
