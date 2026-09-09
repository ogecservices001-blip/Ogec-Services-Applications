import 'package:cloud_firestore/cloud_firestore.dart';
import 'releve_model.dart';

/// Avant cette date, aucune visite n'est comptée (base de test à vider
/// avant la vraie mise en production) — évite que des relevés de test
/// faussent le calcul de "Fréquence courante".
final DateTime coupureComptageVisites = DateTime(2026, 1, 1);

class ReleveService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addReleve(ReleveModel releve) async {
    await _db.collection('releves').add(releve.toMap());
  }

  Stream<List<ReleveModel>> getRelevesForEquipement(String equipementId) {
    return _db
        .collection('releves')
        .where('equipementId', isEqualTo: equipementId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ReleveModel.fromFirestore).toList());
  }

  /// Nombre de relevés déjà enregistrés pour [equipementId] durant
  /// l'année civile [annee].
  Future<int> compterVisitesAnnee({
    required String equipementId,
    required int annee,
  }) async {
    final debut = DateTime(annee);
    final fin = DateTime(annee + 1);
    final query = _db
        .collection('releves')
        .where('equipementId', isEqualTo: equipementId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut))
        .where('date', isLessThan: Timestamp.fromDate(fin));
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  /// "Fréquence courante" calculée pour la visite en cours d'un
  /// équipement : nombre de relevés déjà faits cette année + 1. `null`
  /// avant [coupureComptageVisites] (rien ne compte encore).
  Future<int?> freqCouranteCalculee(String equipementId) async {
    final maintenant = DateTime.now();
    if (maintenant.isBefore(coupureComptageVisites)) return null;
    final visites = await compterVisitesAnnee(
      equipementId: equipementId,
      annee: maintenant.year,
    );
    return visites + 1;
  }
}
