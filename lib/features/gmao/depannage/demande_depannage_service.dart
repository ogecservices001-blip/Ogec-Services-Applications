import 'package:cloud_firestore/cloud_firestore.dart';
import 'demande_depannage_model.dart';

class DemandeDepannageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<DemandeDepannageModel>> getDemandes() {
    return _db
        .collection('demandes_depannage')
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(DemandeDepannageModel.fromFirestore).toList());
  }

  Future<void> marquerTraitee(String id) async {
    await _db.collection('demandes_depannage').doc(id).update({
      'statut': 'traitee',
    });
  }
}
