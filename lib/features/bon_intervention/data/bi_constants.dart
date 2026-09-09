/// Pôles métier OGEC — chaque pôle a son propre chrono annuel de
/// numérotation. Porté depuis le module Kotlin du collègue
/// (re.ogec.bi/data/Models.kt), sans le pôle 40 "Location groupe
/// froid" — pas utilisé chez OGEC Services.
class Poles {
  static const petitsTravaux = '10';
  static const maintenance = '20';
  static const depannage = '30';

  static const Map<String, String> all = {
    petitsTravaux: 'Petits travaux',
    maintenance: 'Maintenance',
    depannage: 'Dépannage',
  };

  static String label(String code) => all[code] ?? code;

  /// Pôles qui portent une heure d'arrivée et une heure de départ —
  /// indispensable au SAV (plusieurs interventions dans la même
  /// journée) et utile en petits travaux. La maintenance en est
  /// exclue : elle raisonne en période, pas en horaire.
  static bool avecHeures(String code) =>
      code == petitsTravaux || code == depannage;
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

const natureEntretien = 'entretien';
const natureTravaux = 'travaux';
const natureDepannage = 'depannage';
const natureAutre = 'autre';

const Map<String, String> natures = {
  natureEntretien: 'Entretien',
  natureTravaux: 'Travaux',
  natureDepannage: 'Dépannage',
  natureAutre: 'Autre',
};

const Map<String, String> photoTypes = {
  'avant': 'Avant intervention',
  'defaut': 'Défaut constaté',
  'pendant': 'Pendant intervention',
  'apres': 'Après intervention',
  'autre': 'Autre',
};
