import 'reference_horaire_model.dart';

/// Un nœud de l'arborescence Famille → Sous-famille → Puissance,
/// construite directement à partir des colonnes explicites
/// [ReferenceHoraireModel.typeEquipement1]/2/3 — plus de déduction
/// depuis le texte de la désignation.
class NoeudReference {
  final String label;
  final List<NoeudReference> enfants;
  final List<ReferenceHoraireModel> feuilles;
  NoeudReference(this.label, this.enfants, this.feuilles);
}

/// Résultat de la construction : les nœuds racines (pour l'affichage) et
/// le chemin (liste de labels) de chaque référence par son id (pour
/// l'export en colonnes).
class ArbreReferences {
  final List<NoeudReference> racines;
  final Map<String, List<String>> cheminsParId;
  final int profondeurMax;
  ArbreReferences(this.racines, this.cheminsParId, this.profondeurMax);
}

/// Segments explicites d'une ligne (Type Equipement 1/2/3, non vides).
/// Si les 3 sont vides (ligne pas encore réimportée avec les nouvelles
/// colonnes), on se rabat sur la désignation entière comme unique
/// segment, pour que l'arbre reste utilisable en attendant.
List<String> _segments(ReferenceHoraireModel r) {
  final segs = [r.typeEquipement1, r.typeEquipement2, r.typeEquipement3]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return segs.isEmpty ? [r.designation.trim()] : segs;
}

/// Label utilisé au niveau [niveau] pour une référence : le segment
/// explicite s'il existe encore à ce niveau, sinon la désignation
/// complète — pour distinguer des lignes qui partagent le même
/// Type 1/2/3 (ex: les CTA, différenciées uniquement par leur
/// désignation, Type 3 étant vide).
String _labelAuNiveau(ReferenceHoraireModel r, int niveau) {
  final segs = _segments(r);
  return niveau < segs.length ? segs[niveau] : r.designation.trim();
}

ArbreReferences construireArbreReferences(List<ReferenceHoraireModel> references) {
  final cheminsParId = <String, List<String>>{};
  var profondeurMax = 0;

  NoeudReference construire(
    String label,
    List<ReferenceHoraireModel> groupe,
    int niveau,
    List<String> chemin,
  ) {
    if (groupe.length == 1) {
      final ref = groupe.first;
      profondeurMax = chemin.length > profondeurMax ? chemin.length : profondeurMax;
      cheminsParId[ref.id] = chemin;
      return NoeudReference(label, const [], [ref]);
    }

    final parLabel = <String, List<ReferenceHoraireModel>>{};
    for (final r in groupe) {
      parLabel.putIfAbsent(_labelAuNiveau(r, niveau), () => []).add(r);
    }

    // Le regroupement à ce niveau ne distingue plus rien (même clé pour
    // tout le groupe — Type 1/2/3 et désignation épuisés) : on s'arrête
    // ici pour ne pas boucler indéfiniment, ces références deviennent
    // des feuilles directes de ce nœud.
    if (parLabel.length == 1) {
      profondeurMax = chemin.length > profondeurMax ? chemin.length : profondeurMax;
      for (final ref in groupe) {
        cheminsParId[ref.id] = chemin;
      }
      return NoeudReference(label, const [], groupe);
    }

    final enfants = parLabel.entries
        .map((e) => construire(e.key, e.value, niveau + 1, [...chemin, e.key]))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return NoeudReference(label, enfants, const []);
  }

  final racineParLabel = <String, List<ReferenceHoraireModel>>{};
  for (final r in references) {
    racineParLabel.putIfAbsent(_labelAuNiveau(r, 0), () => []).add(r);
  }

  final racines = racineParLabel.entries
      .map((e) => construire(e.key, e.value, 1, [e.key]))
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));

  return ArbreReferences(racines, cheminsParId, profondeurMax);
}
