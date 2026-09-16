import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import '../../annuaire/clients/client_model.dart';
import 'affaire_constants.dart';
import 'affaire_model.dart';

/// Une ligne de l'onglet AFFAIRES déjà résolue vers un client/site du
/// Répertoire.
class LigneAffaireImport {
  final String numeroDevis;
  final String designationPrestations;
  final String numeroCommandeClient;
  final String dateCommandeClient;

  /// Code [NatureAffaire] déjà résolu depuis le libellé du fichier —
  /// vide si la cellule est vide ou si le libellé n'est pas reconnu.
  final String nature;
  final ClientModel client;

  /// true si le fichier source ne précisait aucun site (N°Site "0" —
  /// devis au niveau client) et que la ligne a été rattachée au premier
  /// site connu du client faute de mieux, plutôt qu'ignorée.
  final bool siteApproximatif;

  /// Affaire déjà en base pour le même (n° devis, client) — non nulle
  /// quand cette ligne met à jour une affaire existante plutôt que d'en
  /// créer une nouvelle (évite les doublons à chaque ré-import du même
  /// fichier).
  final AffaireModel? existante;

  LigneAffaireImport({
    required this.numeroDevis,
    required this.designationPrestations,
    required this.numeroCommandeClient,
    required this.dateCommandeClient,
    required this.nature,
    required this.client,
    this.siteApproximatif = false,
    this.existante,
  });
}

class ResultatImportAffaires {
  final List<LigneAffaireImport> lignes;
  final List<String> avertissements;
  ResultatImportAffaires({required this.lignes, required this.avertissements});
}

/// Import depuis l'onglet AFFAIRES du fichier Excel "Base clients" —
/// colonnes fixes (B: numéro de devis, D: N° Client, E: N°Site, G:
/// référence commande client, H: date commande client, I: nature
/// travaux, K: désignation des prestations), lues par position plutôt
/// que par nom d'en-tête : ce fichier n'a pas un format générique
/// réutilisable pour d'autres imports, c'est un classeur précis avec
/// ses propres intitulés parfois ambigus (ex: "Client" contient en fait
/// le numéro de devis, pas le nom du client ; "Remarques Libres"
/// contient en fait la désignation des prestations). Seuls les champs
/// retenus avec l'utilisateur sont repris — le reste des colonnes
/// (N°Affaire séparé, heures vendues, montant, débours matériel...)
/// n'est pas importé.
class AffaireImportService {
  Future<ResultatImportAffaires?> pickParseEtResoudre(
    List<ClientModel> clients,
    List<AffaireModel> affairesExistantes,
  ) async {
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
    // Premier site connu (numéro le plus bas) de chaque client — utilisé en
    // repli quand le fichier source ne précise aucun site (N°Site "0" =
    // devis au niveau client, pas un vrai site à part entière).
    final premierSiteParNumero = <int, (int site, ClientModel client)>{};
    for (final c in clients) {
      final cle = _cleDepuisNAffaire(c.nAffaire);
      if (cle == null) continue;
      clientParCle[cle] = c;
      final parts = c.nAffaire.split('-');
      final num = int.tryParse(parts[0].trim());
      final site = int.tryParse(parts[1].trim());
      if (num == null || site == null) continue;
      final existant = premierSiteParNumero[num];
      if (existant == null || site < existant.$1) {
        premierSiteParNumero[num] = (site, c);
      }
    }

    // Clé (clientId + n° de devis) → affaire déjà en base, pour mettre à
    // jour plutôt que dupliquer à chaque ré-import du même fichier. Sans
    // n° de devis, pas de rapprochement fiable possible : toujours créée.
    final affaireParCle = <String, AffaireModel>{
      for (final a in affairesExistantes)
        if (a.numeroDevis.isNotEmpty) '${a.clientId}|||${a.numeroDevis}': a,
    };

    // Libellé (normalisé, sans accent) → code NatureAffaire, pour
    // résoudre la colonne "Nature travaux" du fichier.
    final natureParLibelle = <String, String>{
      for (final entry in NatureAffaire.all.entries) _normaliser(entry.value): entry.key,
    };

    final lignes = <LigneAffaireImport>[];
    final avertissements = <String>[];

    for (final row in sheet.rows.skip(1)) {
      final numeroDevis = _texte(row, 1);
      final numeroCommandeClient = _texte(row, 6);
      final dateCommandeClient = _texte(row, 7);
      final natureBrute = _texte(row, 8);
      final designation = _texte(row, 10);
      if (numeroDevis.isEmpty && designation.isEmpty) continue;

      final numClient = _entier(row, 3);
      final numSite = _entier(row, 4);
      final repere = numeroDevis.isNotEmpty ? numeroDevis : designation;
      if (numClient == null || numSite == null) {
        avertissements.add('N° Client/Site illisible pour "$repere" — ligne ignorée');
        continue;
      }
      final cle = '$numClient-$numSite';
      var client = clientParCle[cle];
      var siteApproximatif = false;
      if (client == null && numSite == 0) {
        final repli = premierSiteParNumero[numClient];
        if (repli != null) {
          client = repli.$2;
          siteApproximatif = true;
        }
      }
      if (client == null) {
        avertissements.add('Client $cle introuvable dans le Répertoire pour "$repere" — ligne ignorée');
        continue;
      }
      final existante = numeroDevis.isEmpty ? null : affaireParCle['${client.id}|||$numeroDevis'];
      // La colonne contient tantôt le code déjà (ex: "30"), tantôt le
      // libellé complet (ex: "Réparation d'un équipement") selon qui l'a
      // saisi dans le fichier — les deux formats sont acceptés.
      final nature = NatureAffaire.all.containsKey(natureBrute)
          ? natureBrute
          : (natureParLibelle[_normaliser(natureBrute)] ?? '');
      lignes.add(
        LigneAffaireImport(
          numeroDevis: numeroDevis,
          designationPrestations: designation,
          numeroCommandeClient: numeroCommandeClient,
          dateCommandeClient: dateCommandeClient,
          nature: nature,
          client: client,
          siteApproximatif: siteApproximatif,
          existante: existante,
        ),
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
    if (v is excel_pkg.DateCellValue) return _formaterDate(v.asDateTimeUtc());
    if (v is excel_pkg.DateTimeCellValue) return _formaterDate(v.asDateTimeUtc());
    return v.toString().trim();
  }

  String _formaterDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  int? _entier(List<excel_pkg.Data?> row, int index) {
    final s = _texte(row, index);
    if (s.isEmpty) return null;
    final sansDecimale = s.contains('.') ? s.split('.').first : s;
    return int.tryParse(sansDecimale);
  }

  /// Minuscules, accents retirés, espaces superflus effacés — pour
  /// rapprocher un libellé saisi à la main (ex: "Réparation") du code
  /// [NatureAffaire] correspondant sans dépendre de la casse/accents.
  String _normaliser(String s) {
    const avecAccents = 'àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ';
    const sansAccents = 'aaaeeeeiioouuucAAAEEEEIIOOUUUC';
    final buffer = StringBuffer();
    for (final rune in s.trim().toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final i = avecAccents.indexOf(char);
      buffer.write(i == -1 ? char : sansAccents[i]);
    }
    return buffer.toString();
  }
}
