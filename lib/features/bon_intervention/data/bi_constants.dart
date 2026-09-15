import '../../affaires/data/affaire_constants.dart';

/// Pôles métier OGEC — chaque pôle a son propre chrono annuel de
/// numérotation. Réexporte directement les codes [NatureAffaire] : le
/// pôle du Bon d'intervention EST la nature du travail, même liste,
/// même sens — un seul point de vérité pour les deux (voir
/// affaire_constants.dart). Remplace l'ancien schéma à 4 pôles (Petits
/// travaux/Maintenance/Dépannage/Livraison).
class Poles {
  static const installationNeuve = NatureAffaire.installationNeuve;
  static const remplacementIdentique = NatureAffaire.remplacementIdentique;
  static const entretienSousContrat = NatureAffaire.entretienSousContrat;
  static const entretienHorsContrat = NatureAffaire.entretienHorsContrat;
  static const reparationEquipement = NatureAffaire.reparationEquipement;
  static const reparationDiverse = NatureAffaire.reparationDiverse;
  static const miseADisposition = NatureAffaire.miseADisposition;
  static const livraisonMateriel = NatureAffaire.livraisonMateriel;

  /// Pôle propre au Bon d'intervention, hors de l'échelle des natures
  /// de devis — un raccourci simple et familier pour les techniciens
  /// (voir avecAffaire/avecEquipementOptionnel/avecTempsLibre), qui
  /// évite d'exiger les codes devis pour un appel SAV express.
  static const depannage = '60';

  static const Map<String, String> all = {
    ...NatureAffaire.all,
    depannage: 'Dépannage',
  };

  static String label(String code) => all[code] ?? code;

  /// Devis (Affaire) obligatoire — ni l'entretien sous contrat (visite
  /// périodique déjà couverte par le contrat) ni le dépannage (appel
  /// SAV, pas de devis préétabli) n'en ont.
  static bool avecAffaire(String code) => code != entretienSousContrat && code != depannage;

  /// Dates en période (début/fin) plutôt qu'une date unique — hérite de
  /// l'ancien pôle Maintenance, dont l'entretien sous contrat est
  /// l'équivalent direct.
  static bool avecPeriode(String code) => code == entretienSousContrat;

  /// Équipement du parc GMAO obligatoire à la création du bon.
  static bool avecEquipementObligatoire(String code) =>
      code == remplacementIdentique ||
      code == entretienHorsContrat ||
      code == reparationEquipement ||
      code == entretienSousContrat;

  /// Équipement du parc GMAO proposé mais pas exigé — Dépannage
  /// uniquement (l'appel SAV ne cible pas toujours un équipement
  /// enregistré).
  static bool avecEquipementOptionnel(String code) => code == depannage;

  /// Temps passé saisi librement puis multiplié par l'effectif plutôt
  /// que calculé sur une journée type — hérite de l'ancien pôle
  /// Dépannage (SAV, pas de journée standard fiable), aussi pour
  /// Réparation d'un équipement/diverse qui en découlent.
  static bool avecTempsLibre(String code) =>
      code == reparationEquipement || code == reparationDiverse || code == depannage;
}

/// Statuts du workflow d'un bon d'intervention.
class Statuts {
  static const brouillon = 'brouillon';
  static const aVerifier = 'averif';
  static const valide = 'valide';
  static const pdfGenere = 'pdf';
  static const pretEnvoi = 'prete';
  static const envoye = 'envoye';
  static const erreurSync = 'erreur';

  static String label(String s) => switch (s) {
    brouillon => 'Brouillon',
    aVerifier => 'À vérifier (bureau)',
    valide => 'Validé bureau',
    pdfGenere => 'PDF généré',
    pretEnvoi => 'PDF prêt · à envoyer',
    envoye => 'Envoyé au client',
    erreurSync => 'Erreur de synchronisation',
    _ => s,
  };
}

const Map<String, String> photoTypes = {
  'avant': 'Avant intervention',
  'defaut': 'Défaut constaté',
  'pendant': 'Pendant intervention',
  'apres': 'Après intervention',
  'autre': 'Autre',
};

/// Dossier Drive racine de l'archivage des bons d'intervention — donné
/// par l'utilisateur, appelé à changer plus tard (structure définitive
/// pas encore figée).
/// https://drive.google.com/drive/folders/1ghjg8PvSRyaGTm0aq77DQwgO2cy_kzeu
const String biDriveRootFolderId = '1ghjg8PvSRyaGTm0aq77DQwgO2cy_kzeu';
