import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import '../../annuaire/clients/client_model.dart';
import '../types_equipement/type_equipement_model.dart';
import 'equipement_model.dart';
import 'download/download.dart';

/// Colonnes du format "Sommaire" (même classeur que celui utilisé pour
/// l'import), dans l'ordre — pour que le fichier exporté puisse être
/// édité puis réimporté tel quel.
const List<String> _colonnesSommaire = [
  'Nom Equipements',
  'Fréquence entretien annulle',
  'Fréquence courante',
  'Type de Relevé',
  'Groupe',
  'Client',
  'Site',
  'Numéro Client',
  'Numéro Site',
  'Numéro Équipement',
  'Type Equipement',
  'Marque',
  'Date M.E.S.',
  'Référence unité intérieure',
  'Référence unité extérieure',
  'Numéro Série unité intérieure',
  'Numéro Série unité extérieure',
  'Localisation',
  'Date Interv prévue',
  'Nom Tech',
  'Type Visite',
  'Réfrigérant',
  'Charge Réfrigérant Kg',
  'Tension Alim.',
  'Puissance',
];

/// Un équipement à exporter, avec le site (document client) auquel il
/// appartient — pour un export multi-sites, chaque équipement peut
/// venir d'un site différent.
class EquipementAvecSite {
  final EquipementModel equipement;
  final ClientModel site;
  EquipementAvecSite(this.equipement, this.site);
}

class EquipementExportService {
  /// Génère un classeur "Sommaire" à partir d'une liste d'équipements
  /// (chacun avec son site d'origine) et déclenche son téléchargement.
  void exporter({
    required List<EquipementAvecSite> lignes,
    required Map<String, TypeEquipementModel> typesById,
    required String nomFichier,
  }) {
    final excel = excel_pkg.Excel.createExcel();
    final nomFeuille = excel.getDefaultSheet()!;
    excel.rename(nomFeuille, 'Sommaire');

    excel.appendRow(
      'Sommaire',
      _colonnesSommaire.map((c) => excel_pkg.TextCellValue(c)).toList(),
    );

    for (final ligne in lignes) {
      final eq = ligne.equipement;
      final site = ligne.site;
      final type = typesById[eq.typeEquipementId];
      final c = eq.champsEnTete;
      final row = <excel_pkg.CellValue>[
        excel_pkg.TextCellValue(eq.nom),
        _cellNumerique(c['freqEntretienAnnuelle']),
        _cellNumerique(c['freqCourante']),
        excel_pkg.TextCellValue(type?.code ?? eq.typeEquipementId),
        excel_pkg.TextCellValue(eq.groupe),
        excel_pkg.TextCellValue(site.nom),
        excel_pkg.TextCellValue(site.site),
        excel_pkg.TextCellValue(''),
        excel_pkg.TextCellValue(''),
        excel_pkg.TextCellValue(eq.numeroEquipement),
        excel_pkg.TextCellValue(c['typeEquipement']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['marque']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['dateMES']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['referenceUInt']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['referenceUExt']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['numSerieUInt']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['numSerieUExt']?.toString() ?? ''),
        excel_pkg.TextCellValue(eq.localisation),
        excel_pkg.TextCellValue(c['dateIntervPrevue']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['nomTech']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['typeVisite']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['typeRefrigerant']?.toString() ?? ''),
        _cellNumerique(c['chargeRefrigerant']),
        excel_pkg.TextCellValue(c['tensionAlim']?.toString() ?? ''),
        excel_pkg.TextCellValue(c['puissance']?.toString() ?? ''),
      ];
      excel.appendRow('Sommaire', row);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final nomFichierPropre = nomFichier.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    downloadBytes(Uint8List.fromList(bytes), nomFichierPropre);
  }

  /// Cellule numérique Excel à partir d'une valeur texte stockée dans
  /// `champsEnTete` (ex: "0.4", "2") — cellule texte vide si non
  /// convertible (champ vide ou valeur non numérique).
  excel_pkg.CellValue _cellNumerique(dynamic valeur) {
    final texte = valeur?.toString() ?? '';
    final nombre = double.tryParse(texte.replaceAll(',', '.'));
    if (nombre == null) return excel_pkg.TextCellValue('');
    return excel_pkg.DoubleCellValue(nombre);
  }
}
