class Equipement {
  final String client;
  final String site;
  final String numeroClient;
  final String numeroSite;
  final String numeroChantier;
  final String nomEquipement;
  final String marque;
  final String dateMES;
  final String reference;
  final String localisation;
  final String refrigerants;
  final String charge;
  final String adresse;
  final String complementAdresse;
  final String codePostal;
  final String commune;
  final String dateDernierControle;
  final String dateProchainControle;
  final String numeroDernierBordereau;
  final String lienRepertoireDrive;
  final String nomSignataireClient;
  final String qualiteSignataire;
  final String emailSignataireClient;
  final String operateur;
  final int rowIndex; // Ligne réelle dans le Google Sheet (ex: 5)

  Equipement({
    required this.client,
    required this.site,
    required this.numeroClient,
    required this.numeroSite,
    required this.numeroChantier,
    required this.nomEquipement,
    required this.marque,
    required this.dateMES,
    required this.reference,
    required this.localisation,
    required this.refrigerants,
    required this.charge,
    required this.adresse,
    required this.complementAdresse,
    required this.codePostal,
    required this.commune,
    required this.dateDernierControle,
    required this.dateProchainControle,
    required this.numeroDernierBordereau,
    required this.lienRepertoireDrive,
    required this.nomSignataireClient,
    required this.qualiteSignataire,
    required this.emailSignataireClient,
    required this.operateur,
    this.rowIndex = -1,
  });

  factory Equipement.fromMap(Map<String, dynamic> map) {
    return Equipement(
      client: map['Client'] ?? '',
      site: map['Site'] ?? '',
      numeroClient: map['Numéro Client'] ?? '',
      numeroSite: map['Numéro Site'] ?? '',
      numeroChantier: map['Numéro Chantier'] ?? '',
      nomEquipement: map['Nom Équipement'] ?? '',
      marque: map['Marque'] ?? '',
      dateMES: map['Date M.E.S.'] ?? '',
      reference: map['Référence'] ?? '',
      localisation: map['Localisation'] ?? '',
      refrigerants: map['Réfrigérant'] ?? '',
      charge: map['Charge'] ?? '',
      adresse: map['Adresse'] ?? '',
      complementAdresse: map['Complément d\'adresse'] ?? '',
      codePostal: map['Code Postal'] ?? '',
      commune: map['Commune'] ?? '',
      dateDernierControle: map['Date dernier contrôle'] ?? '',
      dateProchainControle: map['Date prochain contrôle'] ?? '',
      numeroDernierBordereau: map['N° dernier bordereau'] ?? '',
      lienRepertoireDrive: map['Lien répertoire Drive'] ?? '',
      nomSignataireClient: map['Nom Signataire client'] ?? '',
      qualiteSignataire: map['Qualité du Signataire'] ?? '',
      emailSignataireClient: map['Email Signataire client'] ?? '',
      operateur: map['Opérateur'] ?? '',
    );
  }

  static List<String> getClients(List<Equipement> equipements) {
    return equipements.map((e) => e.client).toSet().toList()..sort();
  }

  static List<String> getSites(List<Equipement> equipements, String client) {
    return equipements
        .where((e) => e.client == client)
        .map((e) => e.site)
        .toSet()
        .toList()
      ..sort();
  }

  static List<Equipement> getEquipementsBySite(
    List<Equipement> equipements,
    String site,
  ) {
    return equipements.where((e) => e.site == site).toList();
  }
}
