/// Pôles métier OGEC — chaque pôle a son propre chrono annuel de
/// numérotation. Porté depuis le module Kotlin du collègue
/// (re.ogec.bi/data/Models.kt), sans le pôle 40 "Location groupe
/// froid" — pas utilisé chez OGEC Services.
class Poles {
  static const petitsTravaux = '10';
  static const maintenance = '20';
  static const depannage = '30';
  static const livraison = '40';

  static const Map<String, String> all = {
    petitsTravaux: 'Petits travaux',
    maintenance: 'Maintenance',
    depannage: 'Dépannage',
    livraison: 'Livraison',
  };

  static String label(String code) => all[code] ?? code;

  /// Pôles où l'on propose (en option) de rattacher un équipement du
  /// parc GMAO du site — Petits travaux ne cible pas forcément un
  /// équipement enregistré.
  static bool avecEquipement(String code) =>
      code == maintenance || code == depannage;
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
