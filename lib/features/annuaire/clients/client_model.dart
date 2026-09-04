import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id;

  // --- Identité & Site ---
  final String nom;
  final String site;
  final String nAffaire;
  final String commune;
  final String codePostal;
  final String adresse;
  final String complementAdresse;

  // --- Accès & Sécurité ---
  final String epiSpecifique;
  final String habilitationSpecifique;
  final String moyenAcces;
  final String jourAcces;
  final String heuresAcces;
  final String delaiIntervention;

  // --- Contacts & Suivi ---
  final String interlocuteurSite;
  final String telFixeInterlocuteurSite;
  final String portableInterlocuteurSite;
  final String courrielInterlocuteurSite;
  final String freqEntretienAn;
  final String interlocuteurTiers;
  final String telFixeTiers;
  final String portableTiers;
  final String courrielTiers;
  final String remarquesLibres;

  // --- Heures & Tarifs (admin) ---
  final String nbHeuresVendues;
  final String nbHeuresVenduesAssistant;
  final String qteHeuresProgrammees;
  final String qteHeuresRestantes;
  final String tauxHoraireRegie;
  final String tauxHoraireVendu;
  final String forfaitDeplacement;

  // --- Contrat (admin) ---
  final String dateOffre;
  final String datePriseEffetContrat;
  final String dateFinContrat;
  final String dureeContrat;
  final String montantContratAv;
  final String referenceOffreOgs;
  final String responsableContrat;
  final String telFixeResponsable;
  final String portableResponsable;
  final String courrielResponsable;

  // --- Facturation (admin) ---
  final String adresseFacturation;
  final String codePostalFacturation;
  final String communeFacturation;
  final String complementAdresseFacturation;
  final String interlocuteurFacturation;
  final String telFixeInterlocuteurFacturation;
  final String portableInterlocuteurFacturation;
  final String courrielInterlocuteurFacturation;
  final String freqFactuAnnuelle;

  // --- Révision & Indices (admin) ---
  final String dateRevision;
  final String formuleRevisionEntretien;
  final String formuleRevisionDepannage;
  final String dateIndiceS;
  final String valeurIndiceS;
  final String dateIndiceCh;
  final String valeurIndiceCh;
  final String dateIndiceSPrime;
  final String valeurIndiceSPrime;
  final String dateIndiceChPrime;
  final String valeurIndiceChPrime;
  final String montantContratAvRevise;
  final String tauxHoraireRevise;
  final String forfaitDeplacementRevise;
  final String modifRiOuBg;

  ClientModel({
    required this.id,
    required this.nom,
    required this.site,
    this.nAffaire = "",
    this.commune = "",
    this.codePostal = "",
    this.adresse = "",
    this.complementAdresse = "",
    this.epiSpecifique = "",
    this.habilitationSpecifique = "",
    this.moyenAcces = "",
    this.jourAcces = "",
    this.heuresAcces = "",
    this.delaiIntervention = "",
    this.interlocuteurSite = "",
    this.telFixeInterlocuteurSite = "",
    this.portableInterlocuteurSite = "",
    this.courrielInterlocuteurSite = "",
    this.freqEntretienAn = "",
    this.interlocuteurTiers = "",
    this.telFixeTiers = "",
    this.portableTiers = "",
    this.courrielTiers = "",
    this.remarquesLibres = "",
    this.nbHeuresVendues = "",
    this.nbHeuresVenduesAssistant = "",
    this.qteHeuresProgrammees = "",
    this.qteHeuresRestantes = "",
    this.tauxHoraireRegie = "",
    this.tauxHoraireVendu = "",
    this.forfaitDeplacement = "",
    this.dateOffre = "",
    this.datePriseEffetContrat = "",
    this.dateFinContrat = "",
    this.dureeContrat = "",
    this.montantContratAv = "",
    this.referenceOffreOgs = "",
    this.responsableContrat = "",
    this.telFixeResponsable = "",
    this.portableResponsable = "",
    this.courrielResponsable = "",
    this.adresseFacturation = "",
    this.codePostalFacturation = "",
    this.communeFacturation = "",
    this.complementAdresseFacturation = "",
    this.interlocuteurFacturation = "",
    this.telFixeInterlocuteurFacturation = "",
    this.portableInterlocuteurFacturation = "",
    this.courrielInterlocuteurFacturation = "",
    this.freqFactuAnnuelle = "",
    this.dateRevision = "",
    this.formuleRevisionEntretien = "",
    this.formuleRevisionDepannage = "",
    this.dateIndiceS = "",
    this.valeurIndiceS = "",
    this.dateIndiceCh = "",
    this.valeurIndiceCh = "",
    this.dateIndiceSPrime = "",
    this.valeurIndiceSPrime = "",
    this.dateIndiceChPrime = "",
    this.valeurIndiceChPrime = "",
    this.montantContratAvRevise = "",
    this.tauxHoraireRevise = "",
    this.forfaitDeplacementRevise = "",
    this.modifRiOuBg = "",
  });

  /// Un client est "hors contrat" quand son N°Affaire commence par "362-"
  /// (le N° Client 362 sert de regroupement générique pour les sites hors
  /// contrat dans la base OGEC Services, chacun avec son propre N°Site).
  bool get horsContrat => nAffaire.trim().startsWith('362-');

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    String s(String key) => data[key] ?? '';
    return ClientModel(
      id: doc.id,
      nom: s('nom'),
      site: s('site'),
      nAffaire: s('nAffaire'),
      commune: s('commune'),
      codePostal: s('codePostal'),
      adresse: s('adresse'),
      complementAdresse: s('complementAdresse'),
      epiSpecifique: s('epiSpecifique'),
      habilitationSpecifique: s('habilitationSpecifique'),
      moyenAcces: s('moyenAcces'),
      jourAcces: s('jourAcces'),
      heuresAcces: s('heuresAcces'),
      delaiIntervention: s('delaiIntervention'),
      interlocuteurSite: s('interlocuteurSite'),
      telFixeInterlocuteurSite: s('telFixeInterlocuteurSite'),
      portableInterlocuteurSite: s('portableInterlocuteurSite'),
      courrielInterlocuteurSite: s('courrielInterlocuteurSite'),
      freqEntretienAn: s('freqEntretienAn'),
      interlocuteurTiers: s('interlocuteurTiers'),
      telFixeTiers: s('telFixeTiers'),
      portableTiers: s('portableTiers'),
      courrielTiers: s('courrielTiers'),
      remarquesLibres: s('remarquesLibres'),
      nbHeuresVendues: s('nbHeuresVendues'),
      nbHeuresVenduesAssistant: s('nbHeuresVenduesAssistant'),
      qteHeuresProgrammees: s('qteHeuresProgrammees'),
      qteHeuresRestantes: s('qteHeuresRestantes'),
      tauxHoraireRegie: s('tauxHoraireRegie'),
      tauxHoraireVendu: s('tauxHoraireVendu'),
      forfaitDeplacement: s('forfaitDeplacement'),
      dateOffre: s('dateOffre'),
      datePriseEffetContrat: s('datePriseEffetContrat'),
      dateFinContrat: s('dateFinContrat'),
      dureeContrat: s('dureeContrat'),
      montantContratAv: s('montantContratAv'),
      referenceOffreOgs: s('referenceOffreOgs'),
      responsableContrat: s('responsableContrat'),
      telFixeResponsable: s('telFixeResponsable'),
      portableResponsable: s('portableResponsable'),
      courrielResponsable: s('courrielResponsable'),
      adresseFacturation: s('adresseFacturation'),
      codePostalFacturation: s('codePostalFacturation'),
      communeFacturation: s('communeFacturation'),
      complementAdresseFacturation: s('complementAdresseFacturation'),
      interlocuteurFacturation: s('interlocuteurFacturation'),
      telFixeInterlocuteurFacturation: s('telFixeInterlocuteurFacturation'),
      portableInterlocuteurFacturation: s('portableInterlocuteurFacturation'),
      courrielInterlocuteurFacturation: s('courrielInterlocuteurFacturation'),
      freqFactuAnnuelle: s('freqFactuAnnuelle'),
      dateRevision: s('dateRevision'),
      formuleRevisionEntretien: s('formuleRevisionEntretien'),
      formuleRevisionDepannage: s('formuleRevisionDepannage'),
      dateIndiceS: s('dateIndiceS'),
      valeurIndiceS: s('valeurIndiceS'),
      dateIndiceCh: s('dateIndiceCh'),
      valeurIndiceCh: s('valeurIndiceCh'),
      dateIndiceSPrime: s('dateIndiceSPrime'),
      valeurIndiceSPrime: s('valeurIndiceSPrime'),
      dateIndiceChPrime: s('dateIndiceChPrime'),
      valeurIndiceChPrime: s('valeurIndiceChPrime'),
      montantContratAvRevise: s('montantContratAvRevise'),
      tauxHoraireRevise: s('tauxHoraireRevise'),
      forfaitDeplacementRevise: s('forfaitDeplacementRevise'),
      modifRiOuBg: s('modifRiOuBg'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'site': site,
      'nAffaire': nAffaire,
      'commune': commune,
      'codePostal': codePostal,
      'adresse': adresse,
      'complementAdresse': complementAdresse,
      'epiSpecifique': epiSpecifique,
      'habilitationSpecifique': habilitationSpecifique,
      'moyenAcces': moyenAcces,
      'jourAcces': jourAcces,
      'heuresAcces': heuresAcces,
      'delaiIntervention': delaiIntervention,
      'interlocuteurSite': interlocuteurSite,
      'telFixeInterlocuteurSite': telFixeInterlocuteurSite,
      'portableInterlocuteurSite': portableInterlocuteurSite,
      'courrielInterlocuteurSite': courrielInterlocuteurSite,
      'freqEntretienAn': freqEntretienAn,
      'interlocuteurTiers': interlocuteurTiers,
      'telFixeTiers': telFixeTiers,
      'portableTiers': portableTiers,
      'courrielTiers': courrielTiers,
      'remarquesLibres': remarquesLibres,
      'nbHeuresVendues': nbHeuresVendues,
      'nbHeuresVenduesAssistant': nbHeuresVenduesAssistant,
      'qteHeuresProgrammees': qteHeuresProgrammees,
      'qteHeuresRestantes': qteHeuresRestantes,
      'tauxHoraireRegie': tauxHoraireRegie,
      'tauxHoraireVendu': tauxHoraireVendu,
      'forfaitDeplacement': forfaitDeplacement,
      'dateOffre': dateOffre,
      'datePriseEffetContrat': datePriseEffetContrat,
      'dateFinContrat': dateFinContrat,
      'dureeContrat': dureeContrat,
      'montantContratAv': montantContratAv,
      'referenceOffreOgs': referenceOffreOgs,
      'responsableContrat': responsableContrat,
      'telFixeResponsable': telFixeResponsable,
      'portableResponsable': portableResponsable,
      'courrielResponsable': courrielResponsable,
      'adresseFacturation': adresseFacturation,
      'codePostalFacturation': codePostalFacturation,
      'communeFacturation': communeFacturation,
      'complementAdresseFacturation': complementAdresseFacturation,
      'interlocuteurFacturation': interlocuteurFacturation,
      'telFixeInterlocuteurFacturation': telFixeInterlocuteurFacturation,
      'portableInterlocuteurFacturation': portableInterlocuteurFacturation,
      'courrielInterlocuteurFacturation': courrielInterlocuteurFacturation,
      'freqFactuAnnuelle': freqFactuAnnuelle,
      'dateRevision': dateRevision,
      'formuleRevisionEntretien': formuleRevisionEntretien,
      'formuleRevisionDepannage': formuleRevisionDepannage,
      'dateIndiceS': dateIndiceS,
      'valeurIndiceS': valeurIndiceS,
      'dateIndiceCh': dateIndiceCh,
      'valeurIndiceCh': valeurIndiceCh,
      'dateIndiceSPrime': dateIndiceSPrime,
      'valeurIndiceSPrime': valeurIndiceSPrime,
      'dateIndiceChPrime': dateIndiceChPrime,
      'valeurIndiceChPrime': valeurIndiceChPrime,
      'montantContratAvRevise': montantContratAvRevise,
      'tauxHoraireRevise': tauxHoraireRevise,
      'forfaitDeplacementRevise': forfaitDeplacementRevise,
      'modifRiOuBg': modifRiOuBg,
    };
  }
}

/// Libellé "X client(s) — Y site(s)" pour une liste de sites : chaque
/// document [ClientModel] est un site, plusieurs sites peuvent partager
/// le même client (même `nom`) — utile partout où le compteur affiché
/// mélangeait jusqu'ici les deux notions.
String clientsSitesLabel(List<dynamic> sites) {
  final nomsUniques = sites
      .whereType<ClientModel>()
      .map((s) => s.nom)
      .toSet();
  return '${nomsUniques.length} client(s) — ${sites.length} site(s)';
}
