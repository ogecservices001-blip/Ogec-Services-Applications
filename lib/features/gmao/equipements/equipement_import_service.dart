import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import '../../annuaire/clients/client_model.dart';
import '../types_equipement/type_equipement_model.dart';
import 'equipement_model.dart';

/// Correspondance entre l'en-tête d'une colonne du classeur "Sommaire"
/// (normalisée : espaces/retours à la ligne réduits à un espace, trim)
/// et la clé du champ équipement correspondant. Seules les colonnes
/// effectivement définies dans `champsEnTeteSupplementaires` de la
/// famille concernée sont reprises — reste générique pour toute
/// famille utilisant les mêmes clés que MOD SPLIT.
const Map<String, String> _colonneVersCle = {
  'type equipement 2': 'typeEquipement2',
  'type equipement 3': 'typeEquipement3',
  'marque': 'marque',
  'date m.e.s.': 'dateMES',
  'référence unité intérieure': 'referenceUInt',
  'référence unité extérieure': 'referenceUExt',
  'numéro série unité intérieure': 'numSerieUInt',
  'numéro série unité extérieure': 'numSerieUExt',
  'date interv prévue': 'dateIntervPrevue',
  'nom tech': 'nomTech',
  'type visite': 'typeVisite',
  'réfrigérant': 'typeRefrigerant',
  'charge réfrigérant kg': 'chargeRefrigerant',
  'tension alim.': 'tensionAlim',
  'puissance': 'puissance',
  'fréquence entretien annuelle': 'freqEntretienAnnuelle',
  'fréquence courante': 'freqCourante',
};

String _normaliser(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

String _deuxChiffres(int n) => n.toString().padLeft(2, '0');

/// Une ligne du classeur "Sommaire", déjà interprétée.
class LigneImport {
  final String nom;
  final String numeroEquipement;
  final String localisation;
  final String groupe;
  final String typeDeReleveBrut;
  final String? typeEquipementId;
  final Map<String, String> champsEnTete;

  /// Colonnes "Client"/"Site" du fichier (présentes seulement dans les
  /// exports multi-sites) — utilisées pour ranger automatiquement
  /// chaque ligne sur le bon site quand l'import porte sur plusieurs
  /// sites à la fois.
  final String clientBrut;
  final String siteBrut;

  LigneImport({
    required this.nom,
    required this.numeroEquipement,
    required this.localisation,
    required this.groupe,
    required this.typeDeReleveBrut,
    required this.typeEquipementId,
    required this.champsEnTete,
    this.clientBrut = '',
    this.siteBrut = '',
  });
}

class DiffChamp {
  final String label;
  final String ancienne;
  final String nouvelle;
  DiffChamp({required this.label, required this.ancienne, required this.nouvelle});
}

class DiffAjout {
  final LigneImport ligne;

  /// Id du site (document `clients`) où créer ce nouvel équipement —
  /// résolu par [EquipementImportService.calculerDiff] : le site unique
  /// fourni, ou celui déterminé via les colonnes Client/Site en import
  /// multi-sites.
  final String clientId;
  DiffAjout(this.ligne, {required this.clientId});
}

class DiffModification {
  final EquipementModel existant;
  final LigneImport ligne;
  final List<DiffChamp> champs;
  DiffModification({
    required this.existant,
    required this.ligne,
    required this.champs,
  });
}

class DiffSuppression {
  final EquipementModel existant;
  DiffSuppression(this.existant);
}

class ResultatDiff {
  final List<DiffAjout> ajouts;
  final List<DiffModification> modifications;
  final List<DiffSuppression> suppressions;
  final List<String> avertissements;
  ResultatDiff({
    required this.ajouts,
    required this.modifications,
    required this.suppressions,
    required this.avertissements,
  });

  bool get vide =>
      ajouts.isEmpty && modifications.isEmpty && suppressions.isEmpty;
}

class EquipementImportService {
  /// Ouvre un sélecteur de fichier et parse la feuille "Sommaire" (ou la
  /// première feuille du classeur) en lignes interprétées. Retourne null
  /// si l'utilisateur annule ou si le fichier est vide/invalide.
  Future<List<LigneImport>?> pickAndParseSommaire() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xlsm', 'xls'],
      withData: true,
    );
    if (result == null) return null;

    final fileBytes = result.files.first.bytes;
    final Uint8List bytes =
        fileBytes ?? await File(result.files.first.path!).readAsBytes();
    if (bytes.isEmpty) return null;

    final excelFile = excel_pkg.Excel.decodeBytes(bytes);
    if (excelFile.tables.isEmpty) return null;
    final sheet =
        excelFile.tables['Sommaire'] ??
        excelFile.tables[excelFile.tables.keys.first];
    if (sheet == null || sheet.rows.isEmpty) return null;

    final headerRow = sheet.rows.first;
    final indexParCle = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final texte = _normaliser(headerRow[i]?.value?.toString() ?? '');
      if (texte.isEmpty) continue;
      indexParCle[texte] = i;
    }

    String valeur(List<excel_pkg.Data?> row, String enteteNormalise) {
      final i = indexParCle[enteteNormalise];
      if (i == null || i >= row.length) return '';
      final cellValue = row[i]?.value;
      if (cellValue == null) return '';
      if (cellValue is excel_pkg.DateCellValue) {
        final d = cellValue.asDateTimeUtc();
        return '${_deuxChiffres(d.day)}/${_deuxChiffres(d.month)}/${d.year}';
      }
      if (cellValue is excel_pkg.DateTimeCellValue) {
        final d = cellValue.asDateTimeUtc();
        return '${_deuxChiffres(d.day)}/${_deuxChiffres(d.month)}/${d.year}';
      }
      return cellValue.toString().trim();
    }

    final lignes = <LigneImport>[];
    for (final row in sheet.rows.skip(1)) {
      final nom = valeur(row, 'nom equipements');
      if (nom.isEmpty) continue;

      final typeDeReleveBrut = valeur(row, 'type de relevé');
      final typeEquipementId = typeDeReleveBrut.isEmpty
          ? null
          : typeDeReleveBrut.trim().toLowerCase().replaceAll(
              RegExp(r'\s+'),
              '_',
            );

      final champs = <String, String>{};
      for (final entry in _colonneVersCle.entries) {
        final v = valeur(row, entry.key);
        if (v.isNotEmpty) champs[entry.value] = v;
      }

      lignes.add(
        LigneImport(
          nom: nom,
          numeroEquipement: valeur(row, 'numéro équipement'),
          localisation: valeur(row, 'localisation'),
          groupe: valeur(row, 'groupe'),
          typeDeReleveBrut: typeDeReleveBrut,
          typeEquipementId: typeEquipementId,
          champsEnTete: champs,
          clientBrut: valeur(row, 'client'),
          siteBrut: valeur(row, 'site'),
        ),
      );
    }

    return lignes;
  }

  /// Compare les lignes importées à l'existant Firestore pour un ou
  /// plusieurs sites et détermine ajouts / modifications / suppressions
  /// proposées. Un seul site fourni : toutes les lignes lui sont
  /// rattachées (comportement historique, colonnes Client/Site
  /// ignorées). Plusieurs sites : chaque ligne est rangée sur le bon
  /// site via ses colonnes Client/Site (nom exact, insensible à la
  /// casse/espaces) — une ligne sans correspondance est ignorée avec un
  /// avertissement plutôt que déclenchée à l'aveugle sur le mauvais
  /// site.
  ResultatDiff calculerDiff({
    required List<LigneImport> lignes,
    required List<ClientModel> sites,
    required Map<String, List<EquipementModel>> existantsParSite,
    required Map<String, TypeEquipementModel> typesById,
  }) {
    String normaliser(String s) => s.trim().toLowerCase();

    final lignesParSite = <String, List<LigneImport>>{};
    final avertissementsGlobaux = <String>[];

    if (sites.length == 1) {
      lignesParSite[sites.first.id] = lignes;
    } else {
      final siteParCle = <String, ClientModel>{
        for (final s in sites) '${normaliser(s.nom)}|${normaliser(s.site)}': s,
      };
      for (final ligne in lignes) {
        final cle = '${normaliser(ligne.clientBrut)}|${normaliser(ligne.siteBrut)}';
        final site = siteParCle[cle];
        if (site == null) {
          final repere = ligne.numeroEquipement.isNotEmpty
              ? ligne.numeroEquipement
              : ligne.nom;
          avertissementsGlobaux.add(
            'Client/Site "${ligne.clientBrut} / ${ligne.siteBrut}" '
            'introuvable pour "$repere" — ligne ignorée',
          );
          continue;
        }
        lignesParSite.putIfAbsent(site.id, () => []).add(ligne);
      }
    }

    final ajouts = <DiffAjout>[];
    final modifications = <DiffModification>[];
    final suppressions = <DiffSuppression>[];
    final avertissements = <String>[...avertissementsGlobaux];

    for (final site in sites) {
      final resultat = _calculerDiffPourUnSite(
        lignes: lignesParSite[site.id] ?? const [],
        existants: existantsParSite[site.id] ?? const [],
        typesById: typesById,
        clientId: site.id,
      );
      ajouts.addAll(resultat.ajouts);
      modifications.addAll(resultat.modifications);
      suppressions.addAll(resultat.suppressions);
      avertissements.addAll(resultat.avertissements);
    }

    return ResultatDiff(
      ajouts: ajouts,
      modifications: modifications,
      suppressions: suppressions,
      avertissements: avertissements,
    );
  }

  ResultatDiff _calculerDiffPourUnSite({
    required List<LigneImport> lignes,
    required List<EquipementModel> existants,
    required Map<String, TypeEquipementModel> typesById,
    required String clientId,
  }) {
    final avertissements = <String>[];
    final ajouts = <DiffAjout>[];
    final modifications = <DiffModification>[];

    final numerosVus = <String>{};
    final existantsParNumero = {
      for (final e in existants)
        if (e.numeroEquipement.trim().isNotEmpty)
          e.numeroEquipement.trim(): e,
    };

    for (final ligne in lignes) {
      final numero = ligne.numeroEquipement.trim();
      if (numero.isEmpty) {
        avertissements.add(
          'Numéro Équipement vide pour "${ligne.nom}" — ligne ignorée',
        );
        continue;
      }
      if (numerosVus.contains(numero)) {
        avertissements.add(
          'Numéro Équipement "$numero" en double dans le fichier — '
          'seule la première occurrence est prise en compte',
        );
        continue;
      }
      numerosVus.add(numero);

      if (ligne.typeEquipementId == null ||
          !typesById.containsKey(ligne.typeEquipementId)) {
        avertissements.add(
          'Famille inconnue "${ligne.typeDeReleveBrut}" pour "$numero" — '
          'ligne ignorée',
        );
        continue;
      }

      final type = typesById[ligne.typeEquipementId]!;
      // Type Equipement 1 est fixe par famille (ex: "Split Autonome" pour
      // MOD SPLIT) — jamais lu depuis le fichier, toujours celui du
      // référentiel, pour rester garanti cohérent avec le catalogue.
      if (type.typeEquipement1Fixe.isNotEmpty) {
        ligne.champsEnTete['typeEquipement1'] = type.typeEquipement1Fixe;
      }
      final existant = existantsParNumero[numero];

      if (existant == null) {
        ajouts.add(DiffAjout(ligne, clientId: clientId));
        continue;
      }

      final champsDiff = <DiffChamp>[];

      if (ligne.nom.isNotEmpty && ligne.nom != existant.nom) {
        champsDiff.add(
          DiffChamp(label: 'Nom', ancienne: existant.nom, nouvelle: ligne.nom),
        );
      }
      if (ligne.localisation.isNotEmpty &&
          ligne.localisation != existant.localisation) {
        champsDiff.add(
          DiffChamp(
            label: 'Localisation',
            ancienne: existant.localisation,
            nouvelle: ligne.localisation,
          ),
        );
      }
      if (ligne.groupe.isNotEmpty && ligne.groupe != existant.groupe) {
        champsDiff.add(
          DiffChamp(
            label: 'Groupe',
            ancienne: existant.groupe,
            nouvelle: ligne.groupe,
          ),
        );
      }

      final champsConnus = {
        for (final c in type.champsEnTeteSupplementaires) c.cle: c.label,
      };
      for (final entry in ligne.champsEnTete.entries) {
        if (entry.key == 'notesEquipement') continue;
        if (!champsConnus.containsKey(entry.key)) continue;
        final ancienne = existant.champsEnTete[entry.key]?.toString() ?? '';
        if (entry.value != ancienne) {
          champsDiff.add(
            DiffChamp(
              label: champsConnus[entry.key]!,
              ancienne: ancienne,
              nouvelle: entry.value,
            ),
          );
        }
      }

      if (champsDiff.isNotEmpty) {
        modifications.add(
          DiffModification(
            existant: existant,
            ligne: ligne,
            champs: champsDiff,
          ),
        );
      }
    }

    final suppressions = existantsParNumero.entries
        .where((e) => !numerosVus.contains(e.key))
        .map((e) => DiffSuppression(e.value))
        .toList();

    return ResultatDiff(
      ajouts: ajouts,
      modifications: modifications,
      suppressions: suppressions,
      avertissements: avertissements,
    );
  }
}
