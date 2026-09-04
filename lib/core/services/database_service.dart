import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/annuaire/clients/client_model.dart';
import '../../features/annuaire/suppliers/supplier_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- OUTILS DE GÉNÉRATION D'ID ---

  // ID simple (utilisé pour les fournisseurs)
  String _generateIdFromName(String name) {
    String id = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : id;
  }

  // NOUVEAU : ID basé sur le N° d'Affaire pour les clients (Anti-doublons simplifié)
  String _generateIdFromAffaire(String nAffaire) {
    String id = nAffaire.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '_',
    );
    return id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : id;
  }

  // ==========================================
  //                SECTION CLIENTS
  // ==========================================

  Stream<List<ClientModel>> getClients() {
    return _db
        .collection('clients')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClientModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> addClient(ClientModel client) async {
    await _db.collection('clients').doc(client.id).set(client.toMap());
  }

  Future<void> updateClient(ClientModel client) async {
    await _db.collection('clients').doc(client.id).update(client.toMap());
  }

  Future<void> deleteClient(String clientId) async {
    await _db.collection('clients').doc(clientId).delete();
  }

  /// Importe des clients depuis les lignes de la feuille "SITES" du
  /// fichier Excel maître ("Base clients OGS ....xlsm") : [rows][0] est
  /// l'en-tête, ignoré. Mapping des colonnes selon "Ordre affichage.xlsx"
  /// (index Chrono = index dans la feuille SITES).
  Future<String> importClientsFromExcelRows(List<List<String>> rows) async {
    final WriteBatch batch = _db.batch();
    final collection = _db.collection('clients');
    int successCount = 0;
    int errorCount = 0;

    for (int i = 1; i < rows.length; i++) {
      final values = rows[i];
      if (values.isEmpty || values.every((v) => v.trim().isEmpty)) continue;

      String v(int index) => index < values.length ? values[index].trim() : '';

      final nAffaire = v(5);
      if (nAffaire.isEmpty) {
        errorCount++;
        continue;
      }

      final String customId = _generateIdFromAffaire(nAffaire);

      final client = ClientModel(
        id: customId,
        nom: v(1),
        site: v(2),
        nAffaire: nAffaire,
        commune: v(11),
        codePostal: v(12),
        adresse: v(13),
        complementAdresse: v(14),
        epiSpecifique: v(35),
        habilitationSpecifique: v(36),
        moyenAcces: v(37),
        jourAcces: v(38),
        heuresAcces: v(39),
        delaiIntervention: v(54),
        interlocuteurSite: v(15),
        telFixeInterlocuteurSite: v(16),
        portableInterlocuteurSite: v(17),
        courrielInterlocuteurSite: v(18),
        freqEntretienAn: v(10),
        interlocuteurTiers: v(31),
        telFixeTiers: v(32),
        portableTiers: v(33),
        courrielTiers: v(34),
        remarquesLibres: v(66),
        nbHeuresVendues: v(6),
        nbHeuresVenduesAssistant: v(7),
        qteHeuresProgrammees: v(8),
        qteHeuresRestantes: v(9),
        tauxHoraireRegie: v(48),
        tauxHoraireVendu: v(47),
        forfaitDeplacement: v(49),
        dateOffre: v(40),
        datePriseEffetContrat: v(41),
        dateFinContrat: v(44),
        dureeContrat: v(42),
        montantContratAv: v(43),
        referenceOffreOgs: v(50),
        responsableContrat: v(19),
        telFixeResponsable: v(20),
        portableResponsable: v(21),
        courrielResponsable: v(22),
        adresseFacturation: v(25),
        codePostalFacturation: v(24),
        communeFacturation: v(23),
        complementAdresseFacturation: v(26),
        interlocuteurFacturation: v(27),
        telFixeInterlocuteurFacturation: v(28),
        portableInterlocuteurFacturation: v(29),
        courrielInterlocuteurFacturation: v(30),
        freqFactuAnnuelle: v(53),
        dateRevision: v(57),
        formuleRevisionEntretien: v(55),
        formuleRevisionDepannage: v(56),
        dateIndiceS: v(58),
        valeurIndiceS: v(59),
        dateIndiceCh: v(60),
        valeurIndiceCh: v(61),
        dateIndiceSPrime: v(45),
        valeurIndiceSPrime: v(51),
        dateIndiceChPrime: v(46),
        valeurIndiceChPrime: v(52),
        montantContratAvRevise: v(62),
        tauxHoraireRevise: v(63),
        forfaitDeplacementRevise: v(64),
        modifRiOuBg: v(65),
      );

      batch.set(collection.doc(customId), client.toMap());
      successCount++;
    }

    if (successCount > 0) {
      await batch.commit();
      return "Succès : $successCount dossiers clients importés/mis à jour ($errorCount ignorés)";
    } else {
      return "Échec : Aucune ligne valide. Vérifiez que la feuille SITES est bien sélectionnée.";
    }
  }

  // ==========================================
  //             SECTION FOURNISSEURS
  // ==========================================

  Stream<List<SupplierModel>> getSuppliers() {
    return _db
        .collection('suppliers')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupplierModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> addSupplier(SupplierModel supplier) async {
    await _db.collection('suppliers').doc(supplier.id).set(supplier.toMap());
  }

  Future<void> updateSupplier(SupplierModel supplier) async {
    await _db.collection('suppliers').doc(supplier.id).update(supplier.toMap());
  }

  Future<void> deleteSupplier(String supplierId) async {
    await _db.collection('suppliers').doc(supplierId).delete();
  }

  Future<String> importSuppliersFromCSV(String csvData) async {
    final List<String> lines = csvData.split(RegExp(r'\r?\n'));
    final WriteBatch batch = _db.batch();
    final collection = _db.collection('suppliers');
    int successCount = 0;
    int errorCount = 0;

    for (int i = 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      String separator = line.contains(';') ? ';' : ',';
      List<String> values = line.split(separator);

      if (values.length < 12) {
        debugPrint(
          "Ligne $i rejetée : ${values.length} colonnes trouvées (12 requises)",
        );
        errorCount++;
        continue;
      }

      final String customId = _generateIdFromName(values[0]);
      final supplier = SupplierModel(
        id: customId,
        nom: values[0].trim(),
        denominationCourte: values[1].trim(),
        interlocuteurs: values[2].trim(),
        tel: values[3].trim(),
        portable: values[4].trim(),
        courriel: values[5].trim(),
        siteWeb: values[6].trim(),
        commune: values[7].trim(),
        codePostal: values[8].trim(),
        adresse: values[9].trim(),
        complementAdresse: values[10].trim(),
        produitsCles: values[11].trim(),
        remarques: values.length > 12 ? values[12].trim() : "",
      );

      batch.set(collection.doc(customId), supplier.toMap());
      successCount++;
    }

    if (successCount > 0) {
      await batch.commit();
      return "Succès : $successCount importés/mis à jour ($errorCount ignorés)";
    } else {
      return "Échec : Aucune ligne valide. Vérifiez le format (12 colonnes).";
    }
  }

  // ==========================================
  //        FONCTIONS DE RECHERCHE & FILTRES
  // ==========================================

  Future<QuerySnapshot> searchByName(String collection, String searchEntry) {
    return _db
        .collection(collection)
        .where('nom', isGreaterThanOrEqualTo: searchEntry)
        .where('nom', isLessThanOrEqualTo: '$searchEntry')
        .get();
  }

  Future<bool> checkFirebaseConnection() async {
    try {
      await _db
          .collection('clients')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint("Erreur de diagnostic Firebase : $e");
      return false;
    }
  }
}
