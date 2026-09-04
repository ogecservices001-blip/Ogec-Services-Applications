import 'package:cloud_firestore/cloud_firestore.dart';

/// Une ligne de la table de référence des heures d'entretien standard
/// (source: classeur "Base horaire équipement"). [designation] reprend
/// le libellé complet du classeur (ex: "VRV UI Gainable 3 kw") — son
/// découpage en famille/sous-famille pour l'affichage et l'export est
/// géré dynamiquement par `reference_horaire_tree.dart`, pas ici.
class ReferenceHoraireModel {
  final String id;
  final String designation;
  final double hrsTechAn;
  final double hrsAssistantAn;
  final double hrsTechSem;
  final double hrsAssistantSem;
  final double hrsTechTri;
  final double hrsAssistantTri;

  ReferenceHoraireModel({
    required this.id,
    required this.designation,
    this.hrsTechAn = 0,
    this.hrsAssistantAn = 0,
    this.hrsTechSem = 0,
    this.hrsAssistantSem = 0,
    this.hrsTechTri = 0,
    this.hrsAssistantTri = 0,
  });

  factory ReferenceHoraireModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    double n(String cle) => (data[cle] as num?)?.toDouble() ?? 0;
    return ReferenceHoraireModel(
      id: doc.id,
      designation: data['designation'] ?? '',
      hrsTechAn: n('hrsTechAn'),
      hrsAssistantAn: n('hrsAssistantAn'),
      hrsTechSem: n('hrsTechSem'),
      hrsAssistantSem: n('hrsAssistantSem'),
      hrsTechTri: n('hrsTechTri'),
      hrsAssistantTri: n('hrsAssistantTri'),
    );
  }

  Map<String, dynamic> toMap() => {
    'designation': designation,
    'hrsTechAn': hrsTechAn,
    'hrsAssistantAn': hrsAssistantAn,
    'hrsTechSem': hrsTechSem,
    'hrsAssistantSem': hrsAssistantSem,
    'hrsTechTri': hrsTechTri,
    'hrsAssistantTri': hrsAssistantTri,
  };

  /// Puissance/débit affiché (ex: "3 kw", "1000 m3/h") — le premier mot
  /// commençant par un chiffre et tout ce qui suit ; vide si aucun.
  String get puissance {
    final mots = designation.trim().split(RegExp(r'\s+'));
    final index = mots.indexWhere((m) => RegExp(r'^\d').hasMatch(m));
    return index == -1 ? '' : mots.sublist(index).join(' ');
  }
}
