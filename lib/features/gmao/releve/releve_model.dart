import 'package:cloud_firestore/cloud_firestore.dart';

/// Un relevé (visite) réellement effectué et enregistré pour un
/// équipement — historique complet, utilisé entre autres pour calculer
/// automatiquement "Fréquence courante" (nombre de relevés déjà faits
/// cette année civile pour cet équipement).
class ReleveModel {
  final String id;
  final String equipementId;
  final String clientId;
  final DateTime date;
  final String nomTech;
  final Map<String, dynamic> checklistValues;
  final Map<String, List<Map<String, String>>> groupesMesures;
  final String? validationFonctionnement;
  final String remarque1;
  final String remarque2;
  final String informationsInternes;

  ReleveModel({
    required this.id,
    required this.equipementId,
    required this.clientId,
    required this.date,
    required this.nomTech,
    this.checklistValues = const {},
    this.groupesMesures = const {},
    this.validationFonctionnement,
    this.remarque1 = '',
    this.remarque2 = '',
    this.informationsInternes = '',
  });

  factory ReleveModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final groupesBrut = Map<String, dynamic>.from(data['groupesMesures'] ?? {});
    return ReleveModel(
      id: doc.id,
      equipementId: data['equipementId'] ?? '',
      clientId: data['clientId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nomTech: data['nomTech'] ?? '',
      checklistValues: Map<String, dynamic>.from(data['checklistValues'] ?? {}),
      groupesMesures: groupesBrut.map(
        (cle, occurrences) => MapEntry(
          cle,
          (occurrences as List<dynamic>)
              .map((o) => Map<String, String>.from(o as Map))
              .toList(),
        ),
      ),
      validationFonctionnement: data['validationFonctionnement'],
      remarque1: data['remarque1'] ?? '',
      remarque2: data['remarque2'] ?? '',
      informationsInternes: data['informationsInternes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'equipementId': equipementId,
    'clientId': clientId,
    'date': Timestamp.fromDate(date),
    'nomTech': nomTech,
    'checklistValues': checklistValues,
    'groupesMesures': groupesMesures,
    'validationFonctionnement': validationFonctionnement,
    'remarque1': remarque1,
    'remarque2': remarque2,
    'informationsInternes': informationsInternes,
  };
}
