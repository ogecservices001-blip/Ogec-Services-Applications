import 'package:cloud_firestore/cloud_firestore.dart';
import 'affaire_model.dart';

class AffaireService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AffaireModel>> getAffairesForClient(String clientId) {
    return _db
        .collection('affaires')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((qs) => qs.docs.map(AffaireModel.fromFirestore).toList());
  }

  Stream<List<AffaireModel>> getAllAffaires() {
    return _db
        .collection('affaires')
        .snapshots()
        .map((qs) => qs.docs.map(AffaireModel.fromFirestore).toList());
  }

  Future<String> saveAffaire(AffaireModel affaire) async {
    final doc = affaire.id.isEmpty ? _db.collection('affaires').doc() : _db.collection('affaires').doc(affaire.id);
    affaire.id = doc.id;
    affaire.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (affaire.createdAt == 0) affaire.createdAt = affaire.updatedAt;
    await doc.set(affaire.toMap());
    return doc.id;
  }

  Future<void> deleteAffaire(String id) async {
    await _db.collection('affaires').doc(id).delete();
  }
}
