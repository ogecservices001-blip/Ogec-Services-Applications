import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'reference_horaire_model.dart';
import '../equipements/download/download.dart';

class ReferencesHorairesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ReferenceHoraireModel>> getReferences() {
    return _db
        .collection('references_horaires')
        .orderBy('designation')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReferenceHoraireModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> addReference(ReferenceHoraireModel reference) async {
    await _db.collection('references_horaires').add(reference.toMap());
  }

  Future<void> updateReference(String id, Map<String, dynamic> data) async {
    await _db.collection('references_horaires').doc(id).update(data);
  }

  Future<void> deleteReference(String id) async {
    await _db.collection('references_horaires').doc(id).delete();
  }

  Future<ReferenceHoraireModel?> getReferenceById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _db.collection('references_horaires').doc(id).get();
    if (!doc.exists) return null;
    return ReferenceHoraireModel.fromFirestore(doc);
  }

  /// Importe le classeur "Base horaire équipement" (colonnes : Type
  /// Equipement 1/2/3, Désignation, Hrs Tech An, Hrs assistant An,
  /// Hrs Tech Sem, Hrs assistant Sem, Hrs Tech Tri, Hrs assistant Tri)
  /// — remplace entièrement le référentiel existant par le contenu du
  /// fichier.
  Future<int> importerClasseur() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xlsm', 'xls'],
      withData: true,
    );
    if (result == null) return 0;

    final fileBytes = result.files.first.bytes;
    final Uint8List bytes =
        fileBytes ?? await File(result.files.first.path!).readAsBytes();
    if (bytes.isEmpty) return 0;

    final excelFile = excel_pkg.Excel.decodeBytes(bytes);
    if (excelFile.tables.isEmpty) return 0;
    final sheet = excelFile.tables[excelFile.tables.keys.first]!;
    if (sheet.rows.isEmpty) return 0;

    // Repère les colonnes par en-tête (insensible aux espaces/casse) plutôt
    // que par position fixe — robuste que le fichier soit la source
    // originale ou notre propre export (qui ajoute Famille/Sous-type).
    String normaliser(String s) =>
        s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    final headerRow = sheet.rows.first;
    final indexParEntete = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final texte = normaliser(headerRow[i]?.value?.toString() ?? '');
      if (texte.isNotEmpty) indexParEntete[texte] = i;
    }

    int? colDesignation = indexParEntete['désignation'];
    final colType1 = indexParEntete['type equipement 1'];
    final colType2 = indexParEntete['type equipement 2'];
    final colType3 = indexParEntete['type equipement 3'];
    const colonnesHeures = {
      'hrsTechAn': 'hrs tech an',
      'hrsAssistantAn': 'hrs assistant an',
      'hrsTechSem': 'hrs tech sem',
      'hrsAssistantSem': 'hrs assistant sem',
      'hrsTechTri': 'hrs tech tri',
      'hrsAssistantTri': 'hrs assistant tri',
    };
    if (colDesignation == null) return 0;

    final existants = await _db.collection('references_horaires').get();
    final batchSuppr = _db.batch();
    for (final doc in existants.docs) {
      batchSuppr.delete(doc.reference);
    }
    await batchSuppr.commit();

    double valeur(List<excel_pkg.Data?> row, int? index) {
      if (index == null || index >= row.length) return 0;
      final v = row[index]?.value;
      if (v == null) return 0;
      return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
    }

    String texte(List<excel_pkg.Data?> row, int? index) {
      if (index == null || index >= row.length) return '';
      return row[index]?.value?.toString().trim() ?? '';
    }

    final batch = _db.batch();
    var compte = 0;
    for (final row in sheet.rows.skip(1)) {
      if (row.isEmpty) continue;
      final designation = colDesignation < row.length
          ? (row[colDesignation]?.value?.toString().trim() ?? '')
          : '';
      if (designation.isEmpty) continue;

      final ref = ReferenceHoraireModel(
        id: '',
        designation: designation,
        typeEquipement1: texte(row, colType1),
        typeEquipement2: texte(row, colType2),
        typeEquipement3: texte(row, colType3),
        hrsTechAn: valeur(row, indexParEntete[colonnesHeures['hrsTechAn']]),
        hrsAssistantAn: valeur(
          row,
          indexParEntete[colonnesHeures['hrsAssistantAn']],
        ),
        hrsTechSem: valeur(row, indexParEntete[colonnesHeures['hrsTechSem']]),
        hrsAssistantSem: valeur(
          row,
          indexParEntete[colonnesHeures['hrsAssistantSem']],
        ),
        hrsTechTri: valeur(row, indexParEntete[colonnesHeures['hrsTechTri']]),
        hrsAssistantTri: valeur(
          row,
          indexParEntete[colonnesHeures['hrsAssistantTri']],
        ),
      );
      batch.set(_db.collection('references_horaires').doc(), ref.toMap());
      compte++;
    }
    await batch.commit();
    return compte;
  }

  /// Exporte le référentiel actuel en classeur Excel (même format que
  /// l'import — modifiable puis réimportable tel quel).
  Future<void> exporterClasseur() async {
    final snapshot = await _db
        .collection('references_horaires')
        .orderBy('designation')
        .get();
    final references = snapshot.docs
        .map((doc) => ReferenceHoraireModel.fromFirestore(doc))
        .toList();

    final excelFile = excel_pkg.Excel.createExcel();
    final nomFeuille = excelFile.getDefaultSheet()!;
    excelFile.rename(nomFeuille, 'Base Horaire');

    final colonnes = [
      'Type Equipement 1',
      'Type Equipement 2',
      'Type Equipement 3',
      'Désignation',
      'Hrs Tech An',
      'Hrs assistant An',
      'Hrs Tech Sem',
      'Hrs assistant Sem',
      'Hrs Tech Tri',
      'Hrs assistant Tri',
    ];
    excelFile.appendRow(
      'Base Horaire',
      colonnes.map((c) => excel_pkg.TextCellValue(c)).toList(),
    );

    for (final ref in references) {
      excelFile.appendRow('Base Horaire', [
        excel_pkg.TextCellValue(ref.typeEquipement1),
        excel_pkg.TextCellValue(ref.typeEquipement2),
        excel_pkg.TextCellValue(ref.typeEquipement3),
        excel_pkg.TextCellValue(ref.designation),
        excel_pkg.DoubleCellValue(ref.hrsTechAn),
        excel_pkg.DoubleCellValue(ref.hrsAssistantAn),
        excel_pkg.DoubleCellValue(ref.hrsTechSem),
        excel_pkg.DoubleCellValue(ref.hrsAssistantSem),
        excel_pkg.DoubleCellValue(ref.hrsTechTri),
        excel_pkg.DoubleCellValue(ref.hrsAssistantTri),
      ]);
    }

    final bytes = excelFile.encode();
    if (bytes == null) return;
    downloadBytes(Uint8List.fromList(bytes), 'Base_horaire_equipement.xlsx');
  }
}
