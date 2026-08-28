import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:googleapis/sheets/v4.dart' as sheets_api;
import 'package:googleapis_auth/auth_io.dart';
import '../models/equipement_model.dart';

class SheetsService {
  static const String spreadsheetId =
      '14CfsXEdB2wK_7N6w8gFSoM0Ch6FOpMdR9A0_IaqOFLg';
  static const String apiKey = 'AIzaSyBogtMlx5gPgkWS_pxZ1HUhJQY8MWho4ig';

  // === LECTURE (via clé API) ===
  Future<List<Equipement>> getEquipements() async {
    try {
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/Feuille1!A2:X?key=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rows = (data['values'] as List?) ?? [];
        final equipements = <Equipement>[];

        String cell(List row, int i) =>
            i < row.length ? row[i].toString().trim() : '';

        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          final nom = cell(row, 5);
          if (nom.isEmpty) continue;

          final sheetRowNumber = i + 2;

          equipements.add(
            Equipement(
              client: cell(row, 0),
              site: cell(row, 1),
              numeroClient: cell(row, 2),
              numeroSite: cell(row, 3),
              numeroChantier: cell(row, 4),
              nomEquipement: nom,
              marque: cell(row, 6),
              dateMES: cell(row, 7),
              reference: cell(row, 8),
              localisation: cell(row, 9),
              refrigerants: cell(row, 10),
              charge: cell(row, 11),
              adresse: cell(row, 12),
              complementAdresse: cell(row, 13),
              codePostal: cell(row, 14),
              commune: cell(row, 15),
              dateDernierControle: cell(row, 16),
              dateProchainControle: cell(row, 17),
              numeroDernierBordereau: cell(row, 18),
              lienRepertoireDrive: cell(row, 19),
              nomSignataireClient: cell(row, 20),
              qualiteSignataire: cell(row, 21),
              emailSignataireClient: cell(row, 22),
              operateur: cell(row, 23),
              rowIndex: sheetRowNumber,
            ),
          );
        }

        debugPrint(
          '✅ ${equipements.length} équipements chargés depuis Google Sheets',
        );
        return equipements;
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur de connexion : $e');
      debugPrint('📱 Utilisation des données mockées');
      return _getMockData();
    }
  }

  // === ÉCRITURE (via compte de service) ===
  // Met à jour la ligne du Sheet correspondant à l'équipement après
  // finalisation d'un CERFA (AVANT la génération du PDF).
  //
  // Colonnes Y à AB (déclaration annuelle des quantités de fluide) :
  // écrites uniquement si non vides, sans écraser une valeur existante
  // qui viendrait d'une intervention précédente d'un autre type — une
  // seule des deux colonnes "chargé" et une seule des deux colonnes
  // "récupéré" reçoit une valeur par finalisation (cf. logique côté
  // form_signature_screen.dart).
  Future<void> updateEquipementApresFinalisation({
    required int rowIndex,
    required String marque,
    required bool marqueEtaitVide,
    required String dateMES,
    required bool dateMESEtaitVide,
    required String reference,
    required bool referenceEtaitVide,
    required String localisation,
    required bool localisationEtaitVide,
    required String refrigerant,
    required bool refrigerantEtaitVide,
    required String charge,
    required bool chargeEtaitVide,
    required String dateDernierControle,
    required String dateProchainControle,
    required String numeroBordereau,
    required String nomSignataire,
    required String qualiteSignataire,
    required String emailSignataire,
    required String operateur,
    String qteChargeesNeufs = '',
    String qteChargeesMaintenance = '',
    String qteRecupMaintenance = '',
    String qteRecupHorsUsage = '',
  }) async {
    if (rowIndex < 2) {
      throw Exception('Numéro de ligne Sheet invalide ($rowIndex)');
    }

    final jsonString = await rootBundle.loadString(
      'assets/service_account.json',
    );
    final credentials = ServiceAccountCredentials.fromJson(jsonString);
    final scopes = [sheets_api.SheetsApi.spreadsheetsScope];

    final client = await clientViaServiceAccount(credentials, scopes);

    try {
      final api = sheets_api.SheetsApi(client);
      final data = <sheets_api.ValueRange>[];

      if (marqueEtaitVide && marque.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!G$rowIndex',
            values: [
              [marque],
            ],
          ),
        );
      }

      if (dateMESEtaitVide && dateMES.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!H$rowIndex',
            values: [
              [dateMES],
            ],
          ),
        );
      }

      if (referenceEtaitVide && reference.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!I$rowIndex',
            values: [
              [reference],
            ],
          ),
        );
      }

      if (localisationEtaitVide && localisation.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!J$rowIndex',
            values: [
              [localisation],
            ],
          ),
        );
      }

      if (refrigerantEtaitVide && refrigerant.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!K$rowIndex',
            values: [
              [refrigerant],
            ],
          ),
        );
      }

      if (chargeEtaitVide && charge.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!L$rowIndex',
            values: [
              [charge],
            ],
          ),
        );
      }

      data.addAll([
        sheets_api.ValueRange(
          range: 'Feuille1!Q$rowIndex',
          values: [
            [dateDernierControle],
          ],
        ),
        sheets_api.ValueRange(
          range: 'Feuille1!R$rowIndex',
          values: [
            [dateProchainControle],
          ],
        ),
        sheets_api.ValueRange(
          range: 'Feuille1!S$rowIndex',
          values: [
            [numeroBordereau],
          ],
        ),
        sheets_api.ValueRange(
          range: 'Feuille1!U$rowIndex',
          values: [
            [nomSignataire],
          ],
        ),
        sheets_api.ValueRange(
          range: 'Feuille1!V$rowIndex',
          values: [
            [qualiteSignataire],
          ],
        ),
        sheets_api.ValueRange(
          range: 'Feuille1!W$rowIndex',
          values: [
            [emailSignataire],
          ],
        ),
        sheets_api.ValueRange(
          range: 'Feuille1!X$rowIndex',
          values: [
            [operateur],
          ],
        ),
      ]);

      // --- Déclaration annuelle des quantités (colonnes Y à AB) ---
      if (qteChargeesNeufs.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!Y$rowIndex',
            values: [
              [qteChargeesNeufs],
            ],
          ),
        );
      }

      if (qteChargeesMaintenance.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!Z$rowIndex',
            values: [
              [qteChargeesMaintenance],
            ],
          ),
        );
      }

      if (qteRecupMaintenance.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!AA$rowIndex',
            values: [
              [qteRecupMaintenance],
            ],
          ),
        );
      }

      if (qteRecupHorsUsage.isNotEmpty) {
        data.add(
          sheets_api.ValueRange(
            range: 'Feuille1!AB$rowIndex',
            values: [
              [qteRecupHorsUsage],
            ],
          ),
        );
      }

      final request = sheets_api.BatchUpdateValuesRequest(
        valueInputOption: 'USER_ENTERED',
        data: data,
      );

      await api.spreadsheets.values.batchUpdate(request, spreadsheetId);
      debugPrint('✅ Sheet mis à jour (ligne $rowIndex)');
    } finally {
      client.close();
    }
  }

  // === AJOUT D'UN NOUVEL ÉQUIPEMENT ===
  // Ajoute une nouvelle ligne à la suite du Sheet (colonnes A à X) et
  // retourne le numéro de ligne réel qui lui a été attribué.
  Future<int> ajouterEquipement({
    required String client,
    required String site,
    required String numeroClient,
    required String numeroSite,
    String numeroChantier = '',
    required String nomEquipement,
    String marque = '',
    String dateMES = '',
    String reference = '',
    String localisation = '',
    String refrigerants = '',
    String charge = '',
    String adresse = '',
    String complementAdresse = '',
    String codePostal = '',
    String commune = '',
    required String lienRepertoireDrive,
    String nomSignataireClient = '',
    String qualiteSignataire = '',
    String emailSignataireClient = '',
  }) async {
    final jsonString = await rootBundle.loadString(
      'assets/service_account.json',
    );
    final credentials = ServiceAccountCredentials.fromJson(jsonString);
    final scopes = [sheets_api.SheetsApi.spreadsheetsScope];
    final httpClient = await clientViaServiceAccount(credentials, scopes);

    try {
      final api = sheets_api.SheetsApi(httpClient);

      final ligne = [
        client,
        site,
        numeroClient,
        numeroSite,
        numeroChantier,
        nomEquipement,
        marque,
        dateMES,
        reference,
        localisation,
        refrigerants,
        charge,
        adresse,
        complementAdresse,
        codePostal,
        commune,
        '', // Date dernier contrôle
        '', // Date prochain contrôle
        '', // N° dernier bordereau
        lienRepertoireDrive,
        nomSignataireClient,
        qualiteSignataire,
        emailSignataireClient,
        '', // Opérateur
      ];

      final response = await api.spreadsheets.values.append(
        sheets_api.ValueRange(values: [ligne]),
        spreadsheetId,
        'Feuille1!A:X',
        valueInputOption: 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
      );

      final plage = response.updates?.updatedRange ?? '';
      // Format attendu : "Feuille1!A15:X15" -> on extrait "15"
      final match = RegExp(r'![A-Z]+(\d+):').firstMatch(plage);
      if (match == null) {
        throw Exception('Impossible de déterminer la ligne créée ($plage)');
      }
      final rowIndex = int.parse(match.group(1)!);

      debugPrint('✅ Équipement ajouté au Sheet (ligne $rowIndex)');
      return rowIndex;
    } finally {
      httpClient.close();
    }
  }

  // === DONNÉES MOCKÉES (FALLBACK) ===
  List<Equipement> _getMockData() {
    debugPrint('📋 Utilisation des mockées');
    return [
      Equipement(
        client: 'Client Alpha',
        site: 'Site A1 - Nord',
        numeroClient: '051',
        numeroSite: '001',
        numeroChantier: 'C-2026-01',
        nomEquipement: 'Groupe-VRV 01',
        marque: 'Daikin',
        dateMES: '15/06/2020',
        reference: 'VRV-IV-S',
        localisation: 'Toiture',
        refrigerants: 'R-410A',
        charge: '12.5',
        adresse: '10 Rue des Filaos',
        complementAdresse: 'Bâtiment A',
        codePostal: '97400',
        commune: 'Saint-Denis',
        dateDernierControle: '10/01/2025',
        dateProchainControle: '10/01/2026',
        numeroDernierBordereau: '25-102-051-Finalisé',
        lienRepertoireDrive: '',
        nomSignataireClient: 'Jean Dupont',
        qualiteSignataire: 'Responsable technique',
        emailSignataireClient: 'jean.dupont@clientalpha.fr',
        operateur: '',
      ),
    ];
  }

  List<String> getClients(List<Equipement> equipements) {
    return equipements.map((e) => e.client).toSet().toList()..sort();
  }

  List<String> getSites(List<Equipement> equipements, String client) {
    return equipements
        .where((e) => e.client == client)
        .map((e) => e.site)
        .toSet()
        .toList()
      ..sort();
  }

  List<Equipement> getEquipementsBySite(
    List<Equipement> equipements,
    String site,
  ) {
    return equipements.where((e) => e.site == site).toList();
  }
}
