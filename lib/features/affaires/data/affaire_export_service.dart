import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import '../../gmao/equipements/download/download.dart';
import 'affaire_constants.dart';
import 'affaire_model.dart';

const List<String> _colonnesAffaires = [
  'Numéro de devis',
  'Client',
  'Site',
  'Désignation des prestations',
  'Email responsable contrat',
  'Date de commande client',
  'Référence commande client',
  'Nature',
];

class AffaireExportService {
  Future<void> exporter({required List<AffaireModel> affaires, required String nomFichier}) async {
    final excel = excel_pkg.Excel.createExcel();
    final nomFeuille = excel.getDefaultSheet()!;
    excel.rename(nomFeuille, 'AFFAIRES');

    excel.appendRow('AFFAIRES', _colonnesAffaires.map((c) => excel_pkg.TextCellValue(c)).toList());

    for (final a in affaires) {
      excel.appendRow('AFFAIRES', [
        excel_pkg.TextCellValue(a.numeroDevis),
        excel_pkg.TextCellValue(a.clientNom),
        excel_pkg.TextCellValue(a.site),
        excel_pkg.TextCellValue(a.designationPrestations),
        excel_pkg.TextCellValue(a.emailResponsableContrat),
        excel_pkg.TextCellValue(a.dateCommandeClient),
        excel_pkg.TextCellValue(a.numeroCommandeClient),
        excel_pkg.TextCellValue(a.nature.isEmpty ? '' : NatureAffaire.label(a.nature)),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final nomFichierPropre = nomFichier.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    downloadBytes(Uint8List.fromList(bytes), nomFichierPropre);
  }
}
