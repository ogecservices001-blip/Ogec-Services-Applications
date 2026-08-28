import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/detecteur_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _chronoDocPath = 'compteurs/chrono_cerfa';

  Future<int> getCurrentChrono() async {
    final doc = await _firestore.doc(_chronoDocPath).get();
    if (doc.exists) {
      return doc.data()?['valeur'] ?? 0;
    }
    return 0;
  }

  Future<int> incrementChrono() async {
    final docRef = _firestore.doc(_chronoDocPath);

    return await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(docRef);

      int currentValue;
      if (snapshot.exists) {
        currentValue = snapshot.data()?['valeur'] ?? 0;
      } else {
        currentValue = 0;
      }

      final newValue = currentValue + 1;

      transaction.set(docRef, {
        'valeur': newValue,
        'derniere_mise_a_jour': FieldValue.serverTimestamp(),
      });

      return newValue;
    });
  }

  String formatChrono(int chrono) {
    return chrono.toString().padLeft(3, '0');
  }

  // "Fiche N°" affiché sur le CERFA : année complète + chrono.
  // Ex : 2026-013
  String formatFicheNo(int chrono) {
    final annee = DateTime.now().year.toString();
    final chronoStr = formatChrono(chrono);
    return '$annee-$chronoStr';
  }

  // Génère l'identifiant du CERFA (nom de fichier / N° de bordereau) au
  // format : Année(2 chiffres)-Chrono-NuméroClient-NuméroSite-NomÉquipement
  // Ex : 26-027-050-01-Groupe VRV 01
  // (Ce format court reste inchangé — seul l'affichage "Fiche N°" à
  // l'écran utilise désormais l'année complète, cf. formatFicheNo.)
  String generateFileName({
    required int chrono,
    required String numeroClient,
    required String numeroSite,
    required String nomEquipement,
  }) {
    final annee = DateTime.now().year.toString().substring(2);
    final chronoStr = formatChrono(chrono);
    final clientStr = numeroClient.padLeft(3, '0');
    final siteStr = numeroSite.padLeft(2, '0');
    return '$annee-$chronoStr-$clientStr-$siteStr-$nomEquipement';
  }

  // === GESTION DES DÉTECTEURS ===
  Future<List<Detecteur>> getDetecteurs() async {
    final snapshot = await _firestore
        .collection('detecteurs')
        .orderBy('reference')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final ts = data['date_controle'];
      return Detecteur(
        id: doc.id,
        reference: data['reference'] ?? '',
        dateControle: ts != null ? ts.toDate() : DateTime.now(),
      );
    }).toList();
  }

  Future<void> addDetecteur(String reference, DateTime dateControle) async {
    await _firestore.collection('detecteurs').add({
      'reference': reference,
      'date_controle': Timestamp.fromDate(dateControle),
    });
  }

  Future<void> deleteDetecteur(String id) async {
    await _firestore.collection('detecteurs').doc(id).delete();
  }

  // === GESTION DES TECHNICIENS ===
  Future<Map<String, String>?> getTechnicien(String uid) async {
    final doc = await _firestore.collection('techniciens').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return {
      'nom': data['nom'] ?? '',
      'qualite': data['qualite'] ?? 'Frigoriste',
    };
  }

  Future<void> saveTechnicien(
    String uid, {
    required String nom,
    String qualite = 'Frigoriste',
  }) async {
    await _firestore.collection('techniciens').doc(uid).set({
      'nom': nom,
      'qualite': qualite,
      'derniere_mise_a_jour': FieldValue.serverTimestamp(),
    });
  }
}
