import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierModel {
  final String id;
  final String nom;
  final String denominationCourte;
  final String interlocuteurs;
  final String tel;
  final String portable;
  final String courriel;
  final String siteWeb;
  final String commune;
  final String codePostal;
  final String adresse;
  final String complementAdresse;
  final String produitsCles;
  final String remarques;

  SupplierModel({
    required this.id,
    required this.nom,
    this.denominationCourte = "",
    this.interlocuteurs = "",
    this.tel = "",
    this.portable = "",
    this.courriel = "",
    this.siteWeb = "",
    this.commune = "",
    this.codePostal = "",
    this.adresse = "",
    this.complementAdresse = "",
    this.produitsCles = "",
    this.remarques = "",
  });

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return SupplierModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      denominationCourte: data['denominationCourte'] ?? '',
      interlocuteurs: data['interlocuteurs'] ?? '',
      tel: data['tel'] ?? '',
      portable: data['portable'] ?? '',
      courriel: data['courriel'] ?? '',
      siteWeb: data['siteWeb'] ?? '',
      commune: data['commune'] ?? '',
      codePostal: data['codePostal'] ?? '',
      adresse: data['adresse'] ?? '',
      complementAdresse: data['complementAdresse'] ?? '',
      produitsCles: data['produitsCles'] ?? '',
      remarques: data['remarques'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'denominationCourte': denominationCourte,
      'interlocuteurs': interlocuteurs,
      'tel': tel,
      'portable': portable,
      'courriel': courriel,
      'siteWeb': siteWeb,
      'commune': commune,
      'codePostal': codePostal,
      'adresse': adresse,
      'complementAdresse': complementAdresse,
      'produitsCles': produitsCles,
      'remarques': remarques,
    };
  }
}
