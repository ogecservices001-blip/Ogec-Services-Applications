/// Nature d'un travail — choisie par le technicien sur le terrain au
/// moment du Bon d'intervention correspondant, pas obligatoire à la
/// création de l'affaire par le bureau (le travail réel n'est parfois
/// su qu'une fois sur place). Mêmes codes que le pôle du Bon
/// d'intervention (voir Poles dans bi_constants.dart) — nature et pôle
/// désignent la même chose, une seule échelle de codes pour les deux.
class NatureAffaire {
  static const installationNeuve = '10';
  static const remplacementIdentique = '15';
  static const entretienSousContrat = '20';
  static const entretienHorsContrat = '25';
  static const reparationEquipement = '30';
  static const reparationDiverse = '35';
  static const miseADisposition = '40';
  static const livraisonMateriel = '50';

  static const Map<String, String> all = {
    installationNeuve: 'Installation neuve',
    remplacementIdentique: 'Remplacement à l\'identique',
    entretienSousContrat: 'Entretien sous contrat',
    entretienHorsContrat: 'Entretien hors contrat',
    reparationEquipement: 'Réparation d\'un équipement',
    reparationDiverse: 'Réparation diverse',
    miseADisposition: 'Mise à disposition d\'équipement',
    livraisonMateriel: 'Livraison de matériel',
  };

  static String label(String code) => all[code] ?? code;
}
