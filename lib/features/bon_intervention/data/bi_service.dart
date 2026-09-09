import 'package:cloud_firestore/cloud_firestore.dart';
import 'bi_model.dart';
import 'bi_format.dart';

/// Dépôt de données des bons d'intervention — collections `bis` (un
/// document par bon) et `chronos` (compteur unique par année, partagé
/// entre les 3 pôles, pour une numérotation sans doublon).
class BiService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<BonIntervention>> bisFlow() {
    return _db
        .collection('bis')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(BonIntervention.fromFirestore).toList());
  }

  /// Réserve le prochain chrono pour l'année via une transaction
  /// Firestore : aucun doublon possible en ligne. Un seul compteur pour
  /// les 3 pôles (Petits travaux/Maintenance/Dépannage), chaque année
  /// repart à 1.
  Future<int> allouerChrono(int annee) async {
    final ref = _db.collection('chronos').doc(annee.toString());
    return _db.runTransaction<int>((tr) async {
      final snap = await tr.get(ref);
      final current = (snap.data()?['BI'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      tr.set(ref, {'BI': next}, SetOptions(merge: true));
      return next;
    });
  }

  /// Détecte la première utilisation d'une nouvelle année.
  Future<bool> anneeExiste(int annee) async {
    final snap = await _db.collection('chronos').doc(annee.toString()).get();
    return snap.exists;
  }

  /// Hors ligne : un numéro provisoire est utilisé. À la
  /// synchronisation, on vérifie qu'aucun autre bon ne porte le même
  /// numéro ; sinon on réattribue le prochain chrono disponible.
  Future<BonIntervention> resoudreDoublonSiBesoin(BonIntervention bi) async {
    if (!bi.numeroProvisoire) return bi;
    final same = await _db
        .collection('bis')
        .where('numero', isEqualTo: bi.numero)
        .get();
    final autres = same.docs.where((d) => d.id != bi.id);
    if (autres.isEmpty) {
      bi.numeroProvisoire = false;
      await saveBI(bi);
      return bi;
    }
    final annee = BiFormat.currentYear();
    final chrono = await allouerChrono(annee);
    bi.chrono = chrono;
    bi.numero = BiFormat.numeroBI(bi.pole, annee, chrono);
    bi.numeroProvisoire = false;
    await saveBI(bi);
    return bi;
  }

  Future<String> saveBI(BonIntervention bi) async {
    final doc = bi.id.isEmpty
        ? _db.collection('bis').doc()
        : _db.collection('bis').doc(bi.id);
    bi.id = doc.id;
    bi.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await doc.set(bi.toMap());
    return doc.id;
  }

  Future<void> updateBI(String id, Map<String, dynamic> fields) async {
    await _db.collection('bis').doc(id).update({
      ...fields,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> pushHistory(String id, HistoryEntry entry) async {
    await _db.collection('bis').doc(id).update({
      'history': FieldValue.arrayUnion([entry.toMap()]),
    });
  }
}
