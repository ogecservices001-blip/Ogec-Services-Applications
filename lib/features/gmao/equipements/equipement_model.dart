import 'package:cloud_firestore/cloud_firestore.dart';

/// Un équipement physique installé chez un client, rattaché à une
/// famille du référentiel [TypeEquipementModel]. Les valeurs des champs
/// d'en-tête spécifiques à la famille (marque, référence, n° série...)
/// sont capturées une fois à la création de la fiche, puis réutilisées
/// en lecture seule sur chaque relevé — elles ne changent pas d'une
/// visite à l'autre.
class EquipementModel {
  final String id;
  final String clientId;
  final String typeEquipementId;
  final String nom;
  final String numeroEquipement;
  final String localisation;
  final String groupe;

  /// Id du document `references_horaires` choisi pour cet équipement
  /// (catalogue des heures d'entretien standard) — vide si non défini.
  final String referenceHoraireId;
  final Map<String, dynamic> champsEnTete;

  /// true si cet équipement précis est hors contrat, indépendamment du
  /// client (ex: matériel installé en plus chez un client par ailleurs
  /// en contrat — voir l'automatisation "Installation" du Bon
  /// d'intervention Petits travaux). Un client déjà entièrement hors
  /// contrat n'a pas besoin de ce marquage sur chacun de ses équipements.
  final bool horsContrat;

  /// Note libre pour le prochain technicien (ex: suite à une réparation
  /// ou un remplacement via un Bon d'intervention) — affichée en
  /// évidence sur la fiche, pas un champ d'en-tête classique.
  final String remarqueTechnicien;

  EquipementModel({
    required this.id,
    required this.clientId,
    required this.typeEquipementId,
    required this.nom,
    this.numeroEquipement = '',
    this.localisation = '',
    this.groupe = '',
    this.referenceHoraireId = '',
    this.champsEnTete = const {},
    this.horsContrat = false,
    this.remarqueTechnicien = '',
  });

  factory EquipementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EquipementModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      typeEquipementId: data['typeEquipementId'] ?? '',
      nom: data['nom'] ?? '',
      numeroEquipement: data['numeroEquipement'] ?? '',
      localisation: data['localisation'] ?? '',
      groupe: data['groupe'] ?? '',
      referenceHoraireId: data['referenceHoraireId'] ?? '',
      champsEnTete: Map<String, dynamic>.from(data['champsEnTete'] ?? {}),
      horsContrat: data['horsContrat'] ?? false,
      remarqueTechnicien: data['remarqueTechnicien'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'typeEquipementId': typeEquipementId,
    'nom': nom,
    'numeroEquipement': numeroEquipement,
    'localisation': localisation,
    'groupe': groupe,
    'referenceHoraireId': referenceHoraireId,
    'champsEnTete': champsEnTete,
    'horsContrat': horsContrat,
    'remarqueTechnicien': remarqueTechnicien,
  };
}

/// Concatène "Type Equipement 1-2-3" (ex: "Split Autonome-Murale-3.5 kw")
/// pour l'affichage — les 3 valeurs restent stockées séparément dans
/// `champsEnTete`, seule leur affichage est fusionné. Segments vides
/// ignorés ; chaîne vide si aucun des 3 n'est renseigné.
String concatTypeEquipement(Map<String, dynamic> champsEnTete) {
  return ['typeEquipement1', 'typeEquipement2', 'typeEquipement3']
      .map((cle) => champsEnTete[cle]?.toString().trim() ?? '')
      .where((s) => s.isNotEmpty)
      .join('-');
}
