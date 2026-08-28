import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id;
  final String nom;
  final String site;
  final String nAffaire;
  final String codePostal;
  final String commune;
  final String adresse;
  final String complementAdresse;
  final String responsableContrat;
  final String telFixeResponsable;
  final String portableResponsable;
  final String courrielResponsable;

  ClientModel({
    required this.id,
    required this.nom,
    required this.site,
    this.nAffaire = "",
    this.codePostal = "",
    this.commune = "",
    this.adresse = "",
    this.complementAdresse = "",
    this.responsableContrat = "",
    this.telFixeResponsable = "",
    this.portableResponsable = "",
    this.courrielResponsable = "",
  });

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ClientModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      site: data['site'] ?? '',
      nAffaire: data['nAffaire'] ?? '',
      codePostal: data['codePostal'] ?? '',
      commune: data['commune'] ?? '',
      adresse: data['adresse'] ?? '',
      complementAdresse: data['complementAdresse'] ?? '',
      responsableContrat: data['responsableContrat'] ?? '',
      telFixeResponsable: data['telFixeResponsable'] ?? '',
      portableResponsable: data['portableResponsable'] ?? '',
      courrielResponsable: data['courrielResponsable'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'site': site,
      'nAffaire': nAffaire,
      'codePostal': codePostal,
      'commune': commune,
      'adresse': adresse,
      'complementAdresse': complementAdresse,
      'responsableContrat': responsableContrat,
      'telFixeResponsable': telFixeResponsable,
      'portableResponsable': portableResponsable,
      'courrielResponsable': courrielResponsable,
    };
  }
}
