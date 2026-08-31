import 'package:cloud_firestore/cloud_firestore.dart';

class CollaborateurModel {
  final String id;
  final String nom;
  final String prenom;
  final String portable;
  final String emailOgec;
  final String emailPerso;
  final String communeHabitation;
  final String vehicule;

  CollaborateurModel({
    required this.id,
    required this.nom,
    this.prenom = "",
    this.portable = "",
    this.emailOgec = "",
    this.emailPerso = "",
    this.communeHabitation = "",
    this.vehicule = "",
  });

  String get nomComplet => [nom, prenom].where((s) => s.isNotEmpty).join(' ');

  factory CollaborateurModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return CollaborateurModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      portable: data['portable'] ?? '',
      emailOgec: data['emailOgec'] ?? '',
      emailPerso: data['emailPerso'] ?? '',
      communeHabitation: data['communeHabitation'] ?? '',
      vehicule: data['vehicule'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'portable': portable,
      'emailOgec': emailOgec,
      'emailPerso': emailPerso,
      'communeHabitation': communeHabitation,
      'vehicule': vehicule,
    };
  }
}
