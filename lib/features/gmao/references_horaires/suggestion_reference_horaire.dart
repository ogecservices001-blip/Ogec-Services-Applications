import 'reference_horaire_model.dart';

/// Correspondance entre la valeur du champ "Type d'équipement" (MOD
/// SPLIT) et le sous-type utilisé dans le catalogue "Heures de
/// référence".
const Map<String, String> _sousTypeParTypeEquipement = {
  'climatiseur type mural': 'murale',
  'climatiseur type cassette': 'cassette',
  'climatiseur type plafonnier': 'plafonnier',
  'climatiseur type allège': 'allège',
};

double? _extrairePuissance(String texte) {
  final m = RegExp(r'[\d.,]+').firstMatch(texte);
  if (m == null) return null;
  return double.tryParse(m.group(0)!.replaceAll(',', '.'));
}

/// Suggère une ligne du catalogue à partir du type d'équipement et de
/// la puissance — hypothèse "Split Autonome" (cas standard), pas
/// "VRV" (raccordé à un réseau) : à corriger manuellement si ce n'est
/// pas le bon cas. Puissance arrondie au palier supérieur disponible.
ReferenceHoraireModel? suggererReferenceHoraire({
  required String typeEquipement,
  required String puissanceBrute,
  required List<ReferenceHoraireModel> references,
}) {
  final sousType = _sousTypeParTypeEquipement[typeEquipement.trim().toLowerCase()];
  if (sousType == null) return null;

  final puissanceEquipement = _extrairePuissance(puissanceBrute);
  if (puissanceEquipement == null) return null;

  final candidats = references.where((r) {
    final d = r.designation.toLowerCase();
    return d.startsWith('split autonome') && d.contains(sousType);
  }).toList()
    ..sort((a, b) {
      final pa = _extrairePuissance(a.puissance) ?? double.infinity;
      final pb = _extrairePuissance(b.puissance) ?? double.infinity;
      return pa.compareTo(pb);
    });
  if (candidats.isEmpty) return null;

  for (final c in candidats) {
    final p = _extrairePuissance(c.puissance);
    if (p != null && p >= puissanceEquipement) return c;
  }
  return candidats.last;
}
