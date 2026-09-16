import 'package:cloud_firestore/cloud_firestore.dart';
import 'bi_constants.dart';

/// Ligne de prestation/fourniture. Le prix unitaire (pu) est réservé au
/// bureau — jamais saisi ni visible côté technicien.
class Presta {
  String designation;
  String quantite;
  String pu;

  Presta({this.designation = '', this.quantite = '', this.pu = ''});

  Map<String, dynamic> toMap() =>
      {'d': designation, 'n': quantite, 'pu': pu};

  factory Presta.from(Map<String, dynamic> m) => Presta(
    designation: m['d']?.toString() ?? '',
    quantite: m['n']?.toString() ?? '',
    pu: m['pu']?.toString() ?? '',
  );
}

class PhotoBI {
  String type;
  String legende;
  String localPath;
  String horodatage;
  // Fichier réel sur Firebase Storage (bi_photos/…) — plus de limite de
  // taille/qualité liée aux 1 Mo par document Firestore.
  String url;

  PhotoBI({
    this.type = 'autre',
    this.legende = '',
    this.localPath = '',
    this.horodatage = '',
    this.url = '',
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'legende': legende,
    'localPath': localPath,
    'horodatage': horodatage,
    'url': url,
  };

  factory PhotoBI.from(Map<String, dynamic> m) => PhotoBI(
    type: m['type']?.toString() ?? 'autre',
    legende: m['legende']?.toString() ?? '',
    localPath: m['localPath']?.toString() ?? '',
    horodatage: m['horodatage']?.toString() ?? '',
    url: m['url']?.toString() ?? '',
  );
}

class HistoryEntry {
  final String user;
  final String date;
  final String event;
  final List<Map<String, String>> changes;

  HistoryEntry({
    required this.user,
    required this.date,
    this.event = '',
    this.changes = const [],
  });

  Map<String, dynamic> toMap() =>
      {'user': user, 'date': date, 'event': event, 'changes': changes};
}

/// Bon d'Intervention — porté depuis le module du collègue
/// (re.ogec.bi/data/Models.kt), champs identiques.
class BonIntervention {
  String id;
  String pole;
  int chrono;
  String numero;
  bool numeroProvisoire;
  String statut;

  // Client — référence le client existant du Répertoire OGEC Services,
  // pas une collection séparée.
  String clientId;
  String clientNom;
  String site;
  String adresse;
  String email;
  bool horsContrat;

  // Équipement du parc GMAO concerné — obligatoire pour les pôles
  // Remplacement à l'identique/Entretien (sous et hors contrat)/
  // Réparation d'un équipement (voir Poles.avecEquipementObligatoire),
  // absent sinon.
  String equipementId;
  String equipementNom;
  String equipementGroupe;
  String equipementLocalisation;

  // L'affaire (travaux sur devis, voir module `affaires`) dont ce bon
  // assure la réalisation — tous les pôles sauf Entretien sous contrat,
  // qui n'a jamais de devis (voir Poles.avecAffaire).
  String affaireId;
  String affaireNumeroDevis;
  String affaireNumeroCommandeClient;
  String affaireDateCommandeClient;

  // Pôles "Installation neuve"/"Remplacement à l'identique" uniquement —
  // caractéristiques du matériel posé, génériques selon la famille
  // d'équipement choisie/existante (voir types_equipement,
  // TypeEquipementModel.champsEnTeteSupplementaires) plutôt que des
  // champs fixes : ce n'est plus systématiquement un climatiseur Split.
  // Écrasent/peuplent `champsEnTete` de la fiche équipement à la
  // validation bureau (voir GmaoDatabaseService).
  String materielTypeEquipementId;
  Map<String, dynamic> materielChampsEnTete;

  // Dates — règles par pôle
  String dateDebut; // pôle 20
  String dateFin; // pôle 20
  String dateIntervention; // pôles 10/30
  String tempsPasse;
  String heureDebut; // arrivée — pôles 10/30
  String heureFin; // départ — pôles 10/30

  List<String> techniciens;

  /// Technicien connecté qui a saisi le bon et capturé la signature
  /// technicien — distinct de [techniciens] (tous ceux intervenus sur
  /// place) : seul celui-ci signe réellement, les autres sont juste
  /// listés comme intervenants.
  String technicienSignataire;

  String compteRendu;
  String obsTech;
  String obsClient;
  List<Presta> prestas;
  List<PhotoBI> photos;

  String sigTech; // PNG base64
  String sigClient; // PNG base64
  String signataire;
  String signataireTelPortable;
  String signataireTelFixe;
  String dateSignature;

  String numeroDevis;
  String noteInterne;

  // Archivage Drive (Phase 4) — renseignés une fois le PDF généré et
  // déposé, jamais avant.
  String driveBiFolderId;
  String pdfDriveUrl;
  String jsonDriveUrl;

  List<Map<String, dynamic>> history;
  String createdBy;
  int createdAt;
  int updatedAt;

  BonIntervention({
    this.id = '',
    this.pole = '',
    this.chrono = 0,
    this.numero = '',
    this.numeroProvisoire = false,
    this.statut = Statuts.brouillon,
    this.clientId = '',
    this.clientNom = '',
    this.site = '',
    this.adresse = '',
    this.email = '',
    this.horsContrat = false,
    this.equipementId = '',
    this.equipementNom = '',
    this.equipementGroupe = '',
    this.equipementLocalisation = '',
    this.affaireId = '',
    this.affaireNumeroDevis = '',
    this.affaireNumeroCommandeClient = '',
    this.affaireDateCommandeClient = '',
    this.materielTypeEquipementId = '',
    Map<String, dynamic>? materielChampsEnTete,
    this.dateDebut = '',
    this.dateFin = '',
    this.dateIntervention = '',
    this.tempsPasse = '',
    this.heureDebut = '',
    this.heureFin = '',
    List<String>? techniciens,
    this.technicienSignataire = '',
    this.compteRendu = '',
    this.obsTech = '',
    this.obsClient = '',
    List<Presta>? prestas,
    List<PhotoBI>? photos,
    this.sigTech = '',
    this.sigClient = '',
    this.signataire = '',
    this.signataireTelPortable = '',
    this.signataireTelFixe = '',
    this.dateSignature = '',
    this.numeroDevis = '',
    this.noteInterne = '',
    this.driveBiFolderId = '',
    this.pdfDriveUrl = '',
    this.jsonDriveUrl = '',
    List<Map<String, dynamic>>? history,
    this.createdBy = '',
    this.createdAt = 0,
    this.updatedAt = 0,
  }) : techniciens = techniciens ?? [],
       prestas = prestas ?? [Presta()],
       photos = photos ?? [],
       materielChampsEnTete = materielChampsEnTete ?? {},
       history = history ?? [];

  factory BonIntervention.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BonIntervention(
      id: doc.id,
      pole: d['pole'] ?? '',
      chrono: (d['chrono'] as num?)?.toInt() ?? 0,
      numero: d['numero'] ?? '',
      numeroProvisoire: d['numeroProvisoire'] ?? false,
      statut: d['statut'] ?? Statuts.brouillon,
      clientId: d['clientId'] ?? '',
      clientNom: d['clientNom'] ?? '',
      site: d['site'] ?? '',
      adresse: d['adresse'] ?? '',
      email: d['email'] ?? '',
      horsContrat: d['horsContrat'] ?? false,
      equipementId: d['equipementId'] ?? '',
      equipementNom: d['equipementNom'] ?? '',
      equipementGroupe: d['equipementGroupe'] ?? '',
      equipementLocalisation: d['equipementLocalisation'] ?? '',
      affaireId: d['affaireId'] ?? '',
      affaireNumeroDevis: d['affaireNumeroDevis'] ?? '',
      affaireNumeroCommandeClient: d['affaireNumeroCommandeClient'] ?? '',
      affaireDateCommandeClient: d['affaireDateCommandeClient'] ?? '',
      materielTypeEquipementId: d['materielTypeEquipementId'] ?? '',
      materielChampsEnTete: Map<String, dynamic>.from(d['materielChampsEnTete'] ?? {}),
      dateDebut: d['dateDebut'] ?? '',
      dateFin: d['dateFin'] ?? '',
      dateIntervention: d['dateIntervention'] ?? '',
      tempsPasse: d['tempsPasse'] ?? '',
      heureDebut: d['heureDebut'] ?? '',
      heureFin: d['heureFin'] ?? '',
      techniciens: List<String>.from(d['techniciens'] ?? []),
      technicienSignataire: d['technicienSignataire'] ?? '',
      compteRendu: d['compteRendu'] ?? '',
      obsTech: d['obsTech'] ?? '',
      obsClient: d['obsClient'] ?? '',
      prestas: (d['prestas'] as List<dynamic>? ?? [])
          .map((m) => Presta.from(Map<String, dynamic>.from(m)))
          .toList(),
      photos: (d['photos'] as List<dynamic>? ?? [])
          .map((m) => PhotoBI.from(Map<String, dynamic>.from(m)))
          .toList(),
      sigTech: d['sigTech'] ?? '',
      sigClient: d['sigClient'] ?? '',
      signataire: d['signataire'] ?? '',
      signataireTelPortable: d['signataireTelPortable'] ?? '',
      signataireTelFixe: d['signataireTelFixe'] ?? '',
      dateSignature: d['dateSignature'] ?? '',
      numeroDevis: d['numeroDevis'] ?? '',
      noteInterne: d['noteInterne'] ?? '',
      driveBiFolderId: d['driveBiFolderId'] ?? '',
      pdfDriveUrl: d['pdfDriveUrl'] ?? '',
      jsonDriveUrl: d['jsonDriveUrl'] ?? '',
      history: (d['history'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (d['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'pole': pole,
    'chrono': chrono,
    'numero': numero,
    'numeroProvisoire': numeroProvisoire,
    'statut': statut,
    'clientId': clientId,
    'clientNom': clientNom,
    'site': site,
    'adresse': adresse,
    'email': email,
    'horsContrat': horsContrat,
    'equipementId': equipementId,
    'equipementNom': equipementNom,
    'equipementGroupe': equipementGroupe,
    'equipementLocalisation': equipementLocalisation,
    'affaireId': affaireId,
    'affaireNumeroDevis': affaireNumeroDevis,
    'affaireNumeroCommandeClient': affaireNumeroCommandeClient,
    'affaireDateCommandeClient': affaireDateCommandeClient,
    'materielTypeEquipementId': materielTypeEquipementId,
    'materielChampsEnTete': materielChampsEnTete,
    'dateDebut': dateDebut,
    'dateFin': dateFin,
    'dateIntervention': dateIntervention,
    'tempsPasse': tempsPasse,
    'heureDebut': heureDebut,
    'heureFin': heureFin,
    'techniciens': techniciens,
    'technicienSignataire': technicienSignataire,
    'compteRendu': compteRendu,
    'obsTech': obsTech,
    'obsClient': obsClient,
    'prestas': prestas.map((p) => p.toMap()).toList(),
    'photos': photos.map((p) => p.toMap()).toList(),
    'sigTech': sigTech,
    'sigClient': sigClient,
    'signataire': signataire,
    'signataireTelPortable': signataireTelPortable,
    'signataireTelFixe': signataireTelFixe,
    'dateSignature': dateSignature,
    'numeroDevis': numeroDevis,
    'noteInterne': noteInterne,
    'driveBiFolderId': driveBiFolderId,
    'pdfDriveUrl': pdfDriveUrl,
    'jsonDriveUrl': jsonDriveUrl,
    'history': history,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
