import 'dart:convert';
import 'dart:io';
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

  /// Importation massive des Clients via le texte brut
  Future<void> importClients() async {
    final String? csvContent = await _pickAndReadCsv();
    if (csvContent != null && csvContent.isNotEmpty) {
      try {
        final result = await _db.importClientsFromCSV(csvContent);
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
}
