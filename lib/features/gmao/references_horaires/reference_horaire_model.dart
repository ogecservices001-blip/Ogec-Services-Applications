import 'package:cloud_firestore/cloud_firestore.dart';

/// Une ligne de la table de référence des heures d'entretien standard
/// (source: classeur "Base horaire équipement", feuille "Base Horaire").
/// [typeEquipement1]/[typeEquipement2]/[typeEquipement3] forment la
/// hiérarchie explicite (Famille / Sous-type / Puissance) utilisée pour
/// construire l'arbre de navigation (`reference_horaire_tree.dart`) et
/// pour le rapprochement automatique exact avec un équipement — plus de
/// déduction depuis le texte de [designation], qui reste le libellé
/// complet affiché (ex: "VRV UI Gainable 3 kw").
class ReferenceHoraireModel {
  final String id;
  final String designation;
  final String typeEquipement1;
  final String typeEquipement2;
  final String typeEquipement3;
  final double hrsTechAn;
  final double hrsAssistantAn;
  final double hrsTechSem;
  final double hrsAssistantSem;
  final double hrsTechTri;
  final double hrsAssistantTri;

  ReferenceHoraireModel({
    required this.id,
    required this.designation,
    this.typeEquipement1 = '',
    this.typeEquipement2 = '',
    this.typeEquipement3 = '',
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
      typeEquipement1: data['typeEquipement1'] ?? '',
      typeEquipement2: data['typeEquipement2'] ?? '',
      typeEquipement3: data['typeEquipement3'] ?? '',
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
    'typeEquipement1': typeEquipement1,
    'typeEquipement2': typeEquipement2,
    'typeEquipement3': typeEquipement3,
    'hrsTechAn': hrsTechAn,
    'hrsAssistantAn': hrsAssistantAn,
    'hrsTechSem': hrsTechSem,
    'hrsAssistantSem': hrsAssistantSem,
    'hrsTechTri': hrsTechTri,
    'hrsAssistantTri': hrsAssistantTri,
  };

  /// Puissance/débit affiché (ex: "3 kw", "1000 m3/h") : [typeEquipement3]
  /// si renseigné, sinon déduit de [designation] (ancien format, tant
  /// qu'une ligne n'a pas été réimportée avec les nouvelles colonnes).
  String get puissance {
    if (typeEquipement3.trim().isNotEmpty) return typeEquipement3.trim();
    final mots = designation.trim().split(RegExp(r'\s+'));
    final index = mots.indexWhere((m) => RegExp(r'^\d').hasMatch(m));
    return index == -1 ? '' : mots.sublist(index).join(' ');
  }
}
