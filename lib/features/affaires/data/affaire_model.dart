import 'package:cloud_firestore/cloud_firestore.dart';

/// Une "affaire" : travaux sur devis confiés par un client (en contrat
/// ou hors contrat) en plus de son contrat d'entretien classique —
/// remplacement, réparation ou installation de matériel. Créée par le
/// bureau avant l'intervention ; la nature exacte du travail est
/// souvent précisée seulement plus tard, sur le terrain, via le Bon
/// d'intervention Petits travaux qui s'y rattache.
class AffaireModel {
  String id;
  String clientId;
  String clientNom;
  String site;

  String numeroDevis;
  String designationPrestations;
  String emailResponsableContrat;
  String dateCommandeClient;
  String numeroCommandeClient;

  /// Vide tant que non précisée — voir [NatureAffaire].
  String nature;

  int createdAt;
  int updatedAt;

  AffaireModel({
    this.id = '',
    this.clientId = '',
    this.clientNom = '',
    this.site = '',
    this.numeroDevis = '',
    this.designationPrestations = '',
    this.emailResponsableContrat = '',
    this.dateCommandeClient = '',
    this.numeroCommandeClient = '',
    this.nature = '',
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory AffaireModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AffaireModel(
      id: doc.id,
      clientId: d['clientId'] ?? '',
      clientNom: d['clientNom'] ?? '',
      site: d['site'] ?? '',
      numeroDevis: d['numeroDevis'] ?? '',
      designationPrestations: d['designationPrestations'] ?? '',
      emailResponsableContrat: d['emailResponsableContrat'] ?? '',
      dateCommandeClient: d['dateCommandeClient'] ?? '',
      numeroCommandeClient: d['numeroCommandeClient'] ?? '',
      nature: d['nature'] ?? '',
      createdAt: (d['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (d['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'clientNom': clientNom,
    'site': site,
    'numeroDevis': numeroDevis,
    'designationPrestations': designationPrestations,
    'emailResponsableContrat': emailResponsableContrat,
    'dateCommandeClient': dateCommandeClient,
    'numeroCommandeClient': numeroCommandeClient,
    'nature': nature,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
