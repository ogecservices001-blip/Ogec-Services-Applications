import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class CsvImportService {
  final DatabaseService _db = DatabaseService();

  /// Outil interne pour récupérer le texte brut d'un fichier CSV avec gestion d'encodage
  Future<String?> _pickAndReadCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // Nécessaire pour lire les bytes
      );

      if (result != null) {
        final fileBytes = result.files.first.bytes;

        // Si on est sur mobile, on lit le fichier via son chemin si les bytes sont nuls
        final Uint8List bytes =
            fileBytes ?? await File(result.files.first.path!).readAsBytes();

        if (bytes.isEmpty) return null;

        try {
          // 1ère tentative : UTF-8 (Standard)
          debugPrint("Tentative de décodage en UTF-8...");
          return utf8.decode(bytes);
        } catch (e) {
          // 2ème tentative : Latin1 / ISO-8859-1 (Standard Excel FR)
          debugPrint(
            "Échec UTF-8, tentative de décodage en Latin1 (Excel FR)...",
          );
          return latin1.decode(bytes);
        }
      }
    } catch (e) {
      debugPrint("Erreur critique lors de la lecture du fichier : $e");
    }
    return null;
  }

  /// Importation massive des Clients depuis le fichier Excel maître
  /// (.xlsx/.xlsm), feuille "SITES".
  Future<void> importClients() async {
    final rows = await _pickAndParseExcel(sheetName: 'SITES');
    if (rows != null && rows.isNotEmpty) {
      try {
        final result = await _db.importClientsFromExcelRows(rows);
        debugPrint(result);
      } catch (e) {
        debugPrint("Erreur importation Batch Clients : $e");
      }
    }
  }

  /// Importation massive des Fournisseurs via le texte brut
  Future<void> importSuppliers() async {
    final String? csvContent = await _pickAndReadCsv();
    if (csvContent != null && csvContent.isNotEmpty) {
      try {
        final result = await _db.importSuppliersFromCSV(csvContent);
        debugPrint(result);
      } catch (e) {
        debugPrint("Erreur importation Batch Fournisseurs : $e");
      }
    }
  }

  /// Outil interne pour récupérer les lignes d'un fichier Excel
  /// (.xlsx/.xlsm), chaque cellule convertie en texte brut. Si
  /// [sheetName] est fourni, utilise cette feuille précise (sinon la
  /// première du classeur).
  Future<List<List<String>>?> _pickAndParseExcel({String? sheetName}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm', 'xls'],
        withData: true,
      );

      if (result != null) {
        final fileBytes = result.files.first.bytes;
        final Uint8List bytes =
            fileBytes ?? await File(result.files.first.path!).readAsBytes();

        if (bytes.isEmpty) return null;

        final excelFile = excel_pkg.Excel.decodeBytes(bytes);
        if (excelFile.tables.isEmpty) return null;
        final sheet = sheetName != null
            ? excelFile.tables[sheetName]
            : excelFile.tables[excelFile.tables.keys.first];
        if (sheet == null) return null;

        return sheet.rows
            .map(
              (row) => row
                  .map((cell) => cell?.value?.toString().trim() ?? '')
                  .toList(),
            )
            .toList();
      }
    } catch (e) {
      debugPrint("Erreur critique lors de la lecture du fichier Excel : $e");
    }
    return null;
  }

  /// Importation massive des Collaborateurs via un fichier Excel
  /// (.xlsx/.xlsm) — colonnes attendues : Nom, Prénom, Portable, Email
  /// OGEC, Email perso, Commune d'habitation, Véhicule.
  Future<void> importCollaborateurs() async {
    final rows = await _pickAndParseExcel();
    if (rows != null && rows.isNotEmpty) {
      try {
        final result = await _db.importCollaborateursFromRows(rows);
        debugPrint(result);
      } catch (e) {
        debugPrint("Erreur importation Batch Collaborateurs : $e");
      }
    }
  }
}
