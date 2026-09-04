import 'reference_horaire_model.dart';

/// Corrections de frappe repérées dans le classeur source (variantes
/// d'un même mot qui casseraient le regroupement automatique si on ne
/// les unifiait pas).
const Map<String, String> _correctionsOrthographe = {
  'entrainement': 'Entraînement',
  'entraînement': 'Entraînement',
  'glacé': 'Glacée',
  'glacée': 'Glacée',
  'réarmment': 'Réarmement',
  'réarmement': 'Réarmement',
};

String _normaliserMot(String mot) {
  final corrige = _correctionsOrthographe[mot.toLowerCase()];
  return corrige ?? mot;
}

/// Un mot qui termine par "VRV" (ex: "UEVRV") perd ce suffixe pour
/// l'affichage (ex: "UE") — cas spécifique confirmé par l'utilisateur
/// pour que "UEVRV"/"UIVRV" apparaissent comme des sous-branches de la
/// famille "VRV" plutôt que comme leur propre mot-racine.
String _sansSuffixeVrv(String mot) {
  if (mot.length > 3 && mot.toUpperCase().endsWith('VRV') && mot.toUpperCase() != 'VRV') {
    return mot.substring(0, mot.length - 3);
  }
  return mot;
}

/// Découpe une désignation en mots de catégorie (avant la puissance) et
/// la puissance elle-même (premier mot commençant par un chiffre, et
/// tout ce qui suit).
class _DesignationDecoupee {
  final List<String> motsCategorie;
  final String puissance;
  _DesignationDecoupee(this.motsCategorie, this.puissance);
}

_DesignationDecoupee _decouper(String designation) {
  final mots = designation
      .trim()
      .split(RegExp(r'\s+'))
      .where((m) => m.isNotEmpty)
      .toList();
  final indexPuissance = mots.indexWhere((m) => RegExp(r'^\d').hasMatch(m));
  if (indexPuissance == -1) {
    return _DesignationDecoupee(mots.map(_normaliserMot).map(_sansSuffixeVrv).toList(), '');
  }
  return _DesignationDecoupee(
    mots.sublist(0, indexPuissance).map(_normaliserMot).map(_sansSuffixeVrv).toList(),
    mots.sublist(indexPuissance).join(' '),
  );
}

/// Un nœud de l'arborescence Famille → Sous-famille → ... construite
/// dynamiquement : un niveau n'existe que s'il y a un vrai choix à ce
/// point (plusieurs valeurs possibles) — sinon les mots sont fusionnés
/// dans le label du niveau parent, pour éviter des niveaux à un seul
/// enfant qui n'apportent rien.
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

ArbreReferences construireArbreReferences(List<ReferenceHoraireModel> references) {
  final entrees = references
      .map((r) => MapEntry(_decouper(r.designation).motsCategorie, r))
      .toList();

  final cheminsParId = <String, List<String>>{};
  var profondeurMax = 0;

  NoeudReference construire(String label, List<MapEntry<List<String>, ReferenceHoraireModel>> groupe, List<String> chemin) {
    final directes = groupe.where((e) => e.key.isEmpty).map((e) => e.value).toList();
    final avecSuite = groupe.where((e) => e.key.isNotEmpty).toList();

    final parMot = <String, List<MapEntry<List<String>, ReferenceHoraireModel>>>{};
    for (final e in avecSuite) {
      parMot.putIfAbsent(e.key.first, () => []).add(MapEntry(e.key.sublist(1), e.value));
    }

    final enfants = parMot.entries
        .map((entry) => construire(entry.key, entry.value, [...chemin, entry.key]))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    // Compression : un seul enfant et aucune feuille directe à ce
    // niveau -> on fusionne le label avec celui de l'enfant unique.
    if (enfants.length == 1 && directes.isEmpty) {
      final seul = enfants.first;
      final labelFusionne = label.isEmpty ? seul.label : '$label ${seul.label}';
      return NoeudReference(labelFusionne, seul.enfants, seul.feuilles);
    }

    if (directes.isNotEmpty) {
      profondeurMax = chemin.length > profondeurMax ? chemin.length : profondeurMax;
      for (final ref in directes) {
        cheminsParId[ref.id] = chemin;
      }
    }

    return NoeudReference(label, enfants, directes);
  }

  final racineParMot = <String, List<MapEntry<List<String>, ReferenceHoraireModel>>>{};
  for (final e in entrees) {
    if (e.key.isEmpty) continue;
    racineParMot.putIfAbsent(e.key.first, () => []).add(MapEntry(e.key.sublist(1), e.value));
  }

  final racines = racineParMot.entries
      .map((entry) => construire(entry.key, entry.value, [entry.key]))
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));

  return ArbreReferences(racines, cheminsParId, profondeurMax);
}
