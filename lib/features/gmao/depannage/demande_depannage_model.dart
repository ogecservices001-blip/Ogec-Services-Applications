import 'package:cloud_firestore/cloud_firestore.dart';

/// Une demande de dépannage envoyée depuis la page publique d'un
/// équipement (QR code scanné, email vérifié côté serveur) — voir les
/// Cloud Functions `verifierAccesEquipement`/`soumettreDemandeDepannage`.
class DemandeDepannageModel {
  final String id;
  final String equipementId;
  final String clientId;
  final String clientNom;
  final String clientSite;
  final String equipementNom;
  final String email;
  final String message;
  final String statut; // 'nouvelle' | 'traitee'
  final DateTime? dateCreation;

  DemandeDepannageModel({
    required this.id,
    required this.equipementId,
    required this.clientId,
    required this.clientNom,
    required this.clientSite,
    required this.equipementNom,
    required this.email,
    required this.message,
    required this.statut,
    required this.dateCreation,
  });

  factory DemandeDepannageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['dateCreation'];
    return DemandeDepannageModel(
      id: doc.id,
      equipementId: data['equipementId'] ?? '',
      clientId: data['clientId'] ?? '',
      clientNom: data['clientNom'] ?? '',
      clientSite: data['clientSite'] ?? '',
      equipementNom: data['equipementNom'] ?? '',
      email: data['email'] ?? '',
      message: data['message'] ?? '',
      statut: data['statut'] ?? 'nouvelle',
      dateCreation: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}
