import 'dart:typed_data';
import 'equipement_model.dart';

class CerfaData {
  // === Contexte / navigation ===
  final Equipement equipement;
  // chrono/chronoStr/nomFichier ne sont plus attribués à la création
  // (Écran 1) mais à la toute fin du parcours (validation Écran 5b),
  // pour éviter de consommer un numéro si le CERFA est abandonné en
  // cours de route.
  int chrono;
  String chronoStr;
  String nomFichier;
  String statut; // "En cours", "Finalisé", "Annulé"

  // === Écran 1 : Informations générales ===
  String ficheNo = '';
  String operateur = '';
  String attestationNo = '1139819';
  String detenteur = '';
  String equipementId = '';

  // === Écran 2 : Informations équipement (modifiables) ===
  String equipementMarque = '';
  String equipementDateMES = '';
  String equipementReference = '';
  String equipementLocalisation = '';

  // === Écran 2 : Fluide & Intervention ===
  String equipementFluide = '';
  String equipementCharge = '';
  String equipementTeqCO2 = '';
  bool caseAssemblage = false;
  bool caseMiseService = false;
  bool caseModif = false;
  bool caseMaintenance = false;
  bool caseCtrlPerio = false;
  bool caseCtrlNonPerio = false;
  bool caseDemantel = false;
  bool caseAutre = false;
  String autreTexte = '';

  // === Écran 3 : Détection de fuite & Périodicité ===
  String detecteurId = '';
  String controleJour = '';
  String controleMois = '';
  String controleAnnee = '';
  String boutonOui = '-';

  bool caseHcfc2 = false;
  bool caseHcfc30 = false;
  bool caseHcfc300 = false;
  bool caseHfc5 = false;
  bool caseHfo1 = false;
  bool caseHfc50 = false;
  bool caseHfo10 = false;
  bool caseHfc500 = false;
  bool caseHfo100 = false;

  bool caseSans12m = false;
  bool caseSans6m = false;
  bool caseSans3m = false;
  bool caseAvec24m = false;
  bool caseAvec12m = false;
  bool caseAvec6m = false;

  bool caseFuiteOui = false;
  bool caseFuiteNon = false;
  String fuiteLoca1 = '';
  bool caseRepFuite1Realisee = false;
  bool caseRepFuite1AFaire = false;
  String fuiteLoca2 = '';
  bool caseRepFuite2Realisee = false;
  bool caseRepFuite2AFaire = false;
  String fuiteLoca3 = '';
  bool caseRepFuite3Realisee = false;
  bool caseRepFuite3AFaire = false;

  // === Écran 4 : Manipulation du fluide ===
  String quantite = '';
  String qa = '';
  String denom = '';
  String qb = '';
  String qc = '';
  String qde = '';
  String qd = '';
  String bsff = '';
  String qe = '';
  String contenantId = '';
  bool caseUN1078 = false;
  bool caseUN1078Autre140601 = false;
  String autreFFNonInflammable = '';
  bool caseUN3161 = false;
  bool caseUN3161Autre160504 = false;
  String autreFFInflammable = '';

  String instal13 = '';
  String observations = '';

  // === Écran 5b : Signatures ===
  String signOperateurNom = '';
  String signOperateurQualite = 'Frigoriste';
  String signOperateurDate = '';
  String signDetenteurNom = '';
  String signDetenteurQualite = '';
  String signDetenteurDate = '';
  Uint8List? signatureOperateurImage;
  Uint8List? signatureDetenteurImage;

  // === Écran 5b : Signataire client (base Sheets) ===
  String nomSignataireClient = '';
  String qualiteSignataire = '';
  String emailSignataireClient = '';

  CerfaData({
    required this.equipement,
    this.chrono = 0,
    this.chronoStr = '',
    this.nomFichier = '',
    this.statut = 'En cours',
  });
}
