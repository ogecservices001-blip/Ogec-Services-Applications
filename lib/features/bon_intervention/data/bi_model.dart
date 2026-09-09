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
  // JPEG encodé en base64 — la seule copie durable de la photo (pas de
  // Firebase Storage/Drive avant la Phase 4), compressée à la capture
  // pour rester sous la limite Firestore (1 Mo par document, 4 photos max).
  String data;

  PhotoBI({
    this.type = 'autre',
    this.legende = '',
    this.localPath = '',
    this.horodatage = '',
    this.data = '',
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'legende': legende,
    'localPath': localPath,
    'horodatage': horodatage,
    'data': data,
  };

  factory PhotoBI.from(Map<String, dynamic> m) => PhotoBI(
    type: m['type']?.toString() ?? 'autre',
    legende: m['legende']?.toString() ?? '',
    localPath: m['localPath']?.toString() ?? '',
    horodatage: m['horodatage']?.toString() ?? '',
    data: m['data']?.toString() ?? '',
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

  // Dates — règles par pôle
  String dateDebut; // pôle 20
  String dateFin; // pôle 20
  String dateIntervention; // pôles 10/30
  String tempsPasse;
  String heureDebut; // arrivée — pôles 10/30
  String heureFin; // départ — pôles 10/30

  List<String> techniciens;
  Map<String, bool> nature;
  String natureAutre;
  String compteRendu;
  String obsTech;
  String obsClient;
  List<Presta> prestas;
  List<PhotoBI> photos;

  String sigTech; // PNG base64
  String sigClient; // PNG base64
  String signataire;
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
    this.dateDebut = '',
    this.dateFin = '',
    this.dateIntervention = '',
    this.tempsPasse = '',
    this.heureDebut = '',
    this.heureFin = '',
    List<String>? techniciens,
    Map<String, bool>? nature,
    this.natureAutre = '',
    this.compteRendu = '',
    this.obsTech = '',
    this.obsClient = '',
    List<Presta>? prestas,
    List<PhotoBI>? photos,
    this.sigTech = '',
    this.sigClient = '',
    this.signataire = '',
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
       nature = nature ?? {},
       prestas = prestas ?? [Presta()],
       photos = photos ?? [],
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
      dateDebut: d['dateDebut'] ?? '',
      dateFin: d['dateFin'] ?? '',
      dateIntervention: d['dateIntervention'] ?? '',
      tempsPasse: d['tempsPasse'] ?? '',
      heureDebut: d['heureDebut'] ?? '',
      heureFin: d['heureFin'] ?? '',
      techniciens: List<String>.from(d['techniciens'] ?? []),
      nature: Map<String, bool>.from(d['nature'] ?? {}),
      natureAutre: d['natureAutre'] ?? '',
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
    'dateDebut': dateDebut,
    'dateFin': dateFin,
    'dateIntervention': dateIntervention,
    'tempsPasse': tempsPasse,
    'heureDebut': heureDebut,
    'heureFin': heureFin,
    'techniciens': techniciens,
    'nature': nature,
    'natureAutre': natureAutre,
    'compteRendu': compteRendu,
    'obsTech': obsTech,
    'obsClient': obsClient,
    'prestas': prestas.map((p) => p.toMap()).toList(),
    'photos': photos.map((p) => p.toMap()).toList(),
    'sigTech': sigTech,
    'sigClient': sigClient,
    'signataire': signataire,
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
