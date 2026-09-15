/// Nature d'une affaire (travaux sur devis) — choisie par le technicien
/// sur le terrain au moment du Bon d'intervention Petits travaux
/// correspondant, pas obligatoire à la création de la fiche par le
/// bureau (le travail réel n'est parfois su qu'une fois sur place).
class NatureAffaire {
  static const remplacement = 'remplacement';
  static const reparation = 'reparation';
  static const installation = 'installation';
  static const entretien = 'entretien';
  static const divers = 'divers';

  static const Map<String, String> all = {
    remplacement: 'Remplacement',
    reparation: 'Réparation',
    installation: 'Installation',
    entretien: 'Entretien',
    divers: 'Travaux divers',
  };

  static String label(String code) => all[code] ?? code;
}
