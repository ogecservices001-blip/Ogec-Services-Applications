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

  Future<String> importClientsFromCSV(String csvData) async {
    final List<String> lines = csvData.split(RegExp(r'\r?\n'));
    final WriteBatch batch = _db.batch();
    final collection = _db.collection('clients');
    int successCount = 0;
    int errorCount = 0;

    for (int i = 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      String separator = line.contains(';') ? ';' : ',';
      List<String> values = line.split(separator);

      if (values.length < 11) {
        debugPrint(
          "Ligne $i rejetée : ${values.length} colonnes trouvées (11 requises)",
        );
        errorCount++;
        continue;
      }

      // Génération de l'ID unique basé sur le N° d'Affaire (index 2 du CSV)
      final String customId = _generateIdFromAffaire(values[2]);

      final client = ClientModel(
        id: customId,
        nom: values[0].trim(),
        site: values[1].trim(),
        nAffaire: values[2].trim(),
        codePostal: values[3].trim(),
        commune: values[4].trim(),
        adresse: values[5].trim(),
        complementAdresse: values[6].trim(),
        responsableContrat: values[7].trim(),
        telFixeResponsable: values[8].trim(),
        portableResponsable: values[9].trim(),
        courrielResponsable: values[10].trim(),
      );

      batch.set(collection.doc(customId), client.toMap());
      successCount++;
    }

    if (successCount > 0) {
      await batch.commit();
      return "Succès : $successCount dossiers clients importés/mis à jour ($errorCount ignorés)";
    } else {
      return "Échec : Aucune ligne valide. Vérifiez le format (11 colonnes).";
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
