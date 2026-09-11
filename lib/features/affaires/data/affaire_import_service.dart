import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import '../../annuaire/clients/client_model.dart';

/// Une ligne de l'onglet AFFAIRES déjà résolue vers un client/site du
/// Répertoire.
class LigneAffaireImport {
  final String numeroDevis;
  final String designationPrestations;
  final ClientModel client;
  LigneAffaireImport({
    required this.numeroDevis,
    required this.designationPrestations,
    required this.client,
  });
}

class ResultatImportAffaires {
  final List<LigneAffaireImport> lignes;
  final List<String> avertissements;
  ResultatImportAffaires({required this.lignes, required this.avertissements});
}

/// Import depuis l'onglet AFFAIRES du fichier Excel "Base clients" —
/// colonnes fixes (B: numéro de devis, D: N° Client, E: N°Site, H:
/// désignation des prestations), lues par position plutôt que par nom
/// d'en-tête : ce fichier n'a pas un format générique réutilisable pour
/// d'autres imports, c'est un classeur précis avec ses propres
/// intitulés parfois ambigus (ex: "Client" contient en fait le numéro
/// de devis, pas le nom du client). Seuls les champs retenus avec
/// l'utilisateur sont repris — le reste des colonnes (N°Affaire séparé,
/// heures vendues, montant, débours matériel...) n'est pas importé.
class AffaireImportService {
  Future<ResultatImportAffaires?> pickParseEtResoudre(List<ClientModel> clients) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xlsm', 'xls'],
      withData: true,
    );
    if (result == null) return null;

    final fileBytes = result.files.first.bytes;
    final Uint8List bytes = fileBytes ?? await File(result.files.first.path!).readAsBytes();
    if (bytes.isEmpty) return null;

    final excelFile = excel_pkg.Excel.decodeBytes(bytes);
    if (excelFile.tables.isEmpty) return null;
    final sheet = excelFile.tables['AFFAIRES'] ?? excelFile.tables[excelFile.tables.keys.first];
    if (sheet == null || sheet.rows.isEmpty) return null;

    final clientParCle = <String, ClientModel>{};
    for (final c in clients) {
      final cle = _cleDepuisNAffaire(c.nAffaire);
      if (cle != null) clientParCle[cle] = c;
    }

    final lignes = <LigneAffaireImport>[];
    final avertissements = <String>[];

    for (final row in sheet.rows.skip(1)) {
      final numeroDevis = _texte(row, 1);
      final designation = _texte(row, 7);
      if (numeroDevis.isEmpty && designation.isEmpty) continue;

      final numClient = _entier(row, 3);
      final numSite = _entier(row, 4);
      final repere = numeroDevis.isNotEmpty ? numeroDevis : designation;
      if (numClient == null || numSite == null) {
        avertissements.add('N° Client/Site illisible pour "$repere" — ligne ignorée');
        continue;
      }
      final cle = '$numClient-$numSite';
      final client = clientParCle[cle];
      if (client == null) {
        avertissements.add('Client $cle introuvable dans le Répertoire pour "$repere" — ligne ignorée');
        continue;
      }
      lignes.add(
        LigneAffaireImport(numeroDevis: numeroDevis, designationPrestations: designation, client: client),
      );
    }

    return ResultatImportAffaires(lignes: lignes, avertissements: avertissements);
  }

  String? _cleDepuisNAffaire(String nAffaire) {
    final parts = nAffaire.split('-');
    if (parts.length != 2) return null;
    final c = int.tryParse(parts[0].trim());
    final s = int.tryParse(parts[1].trim());
    if (c == null || s == null) return null;
    return '$c-$s';
  }

  String _texte(List<excel_pkg.Data?> row, int index) {
    if (index >= row.length) return '';
    final v = row[index]?.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  int? _entier(List<excel_pkg.Data?> row, int index) {
    final s = _texte(row, index);
    if (s.isEmpty) return null;
    final sansDecimale = s.contains('.') ? s.split('.').first : s;
    return int.tryParse(sansDecimale);
  }
}
