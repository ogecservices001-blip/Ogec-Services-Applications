import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/cerfa_data_model.dart';

class PdfService {
  Future<String> genererEtEnvoyerCerfa({
    required CerfaData data,
    required String cheminRepertoireUrl,
  }) async {
    final jsonString = await rootBundle.loadString(
      'assets/service_account.json',
    );
    final credentials = ServiceAccountCredentials.fromJson(jsonString);
    final scopes = [drive.DriveApi.driveScope];
    final client = await clientViaServiceAccount(credentials, scopes);

    try {
      final driveApi = drive.DriveApi(client);

      final folderId = _extraireIdDossier(cheminRepertoireUrl);
      if (folderId == null) {
        throw Exception(
          'Impossible d\'extraire l\'ID du dossier depuis : $cheminRepertoireUrl',
        );
      }

      final nomModele = _nomModeleAttendu(data.equipement);

      final recherche = await driveApi.files.list(
        q: "name = '$nomModele' and '$folderId' in parents and trashed = false",
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
        $fields: 'files(id, name)',
      );

      if (recherche.files == null || recherche.files!.isEmpty) {
        throw Exception(
          'Fichier "$nomModele" introuvable dans le dossier client.\n'
          'Relance le script de bootstrap Python si cet équipement a été '
          'ajouté après le dernier passage du script.',
        );
      }

      final fileId = recherche.files!.first.id!;

      final media =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
                supportsAllDrives: true,
              )
              as drive.Media;

      final bytesOriginaux = await _streamToBytes(media.stream);
      final bytesRemplis = _remplirFormulaire(bytesOriginaux, data);

      final media2 = drive.Media(
        Stream.value(bytesRemplis),
        bytesRemplis.length,
      );
      await driveApi.files.update(
        drive.File()..name = '${data.nomFichier}.pdf',
        fileId,
        uploadMedia: media2,
        supportsAllDrives: true,
      );

      debugPrint(
        '✅ PDF rempli et renommé sur Drive ($fileId → ${data.nomFichier}.pdf)',
      );
      return fileId;
    } finally {
      client.close();
    }
  }

  String _nomModeleAttendu(dynamic equipement) {
    final numeroClient = (equipement.numeroClient as String).padLeft(3, '0');
    final numeroSite = (equipement.numeroSite as String).padLeft(2, '0');
    final slug = _slugify(equipement.nomEquipement as String);
    return '$numeroClient-$numeroSite-${slug}_MODELE.pdf';
  }

  String _slugify(String texte) {
    final sansAccents = _retirerAccents(texte);
    final sansSpeciaux = sansAccents.replaceAll(RegExp(r'[^\w\s-]'), '');
    return sansSpeciaux.trim().replaceAll(RegExp(r'\s+'), '_');
  }

  String _retirerAccents(String input) {
    const avecAccents = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÌÍÎÏìíîïÙÚÛÜùúûüÇçÑñ';
    const sansAccentsCorresp =
        'AAAAAAaaaaaaOOOOOOoooooEEEEeeeeIIIIiiiiUUUUuuuuCcNn';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final idx = avecAccents.indexOf(char);
      buffer.write(idx >= 0 ? sansAccentsCorresp[idx] : char);
    }
    return buffer.toString();
  }

  String? _extraireIdDossier(String url) {
    final folderMatch = RegExp(r'/folders/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (folderMatch != null) return folderMatch.group(1);

    final fileMatch = RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (fileMatch != null) return fileMatch.group(1);

    if (RegExp(r'^[a-zA-Z0-9_-]{15,}$').hasMatch(url.trim())) {
      return url.trim();
    }

    return null;
  }

  Future<Uint8List> _streamToBytes(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  Uint8List _remplirFormulaire(Uint8List bytesTemplate, CerfaData data) {
    final document = PdfDocument(inputBytes: bytesTemplate);
    final form = document.form;

    final textValues = <String, String>{
      'Fiche_no': data.ficheNo,
      'Operateur': data.operateur,
      'Attestation_no': data.attestationNo,
      'Detenteur': data.detenteur,
      'Equipement_ID': data.equipementId,
      'Equipement_Fluide': data.equipementFluide,
      'Equipement_Charge': data.equipementCharge,
      'Equipement_teqCO2': data.equipementTeqCO2,
      'Autre': data.autreTexte,
      'Detecteur_ID': data.detecteurId,
      'Controle_Jour': data.controleJour,
      'Controle_Mois': data.controleMois,
      'Controle_Annee': data.controleAnnee,
      'Fuite_Loca_1': data.fuiteLoca1,
      'Fuite_Loca_2': data.fuiteLoca2,
      'Fuite_Loca_3': data.fuiteLoca3,
      '11_Quantite': data.quantite,
      '11_QA': data.qa,
      '11_Denom': data.denom,
      '11_QB': data.qb,
      '11_QC': data.qc,
      '11_QDE': data.qde,
      '11_QD': data.qd,
      '11_BSFF': data.bsff,
      '11_QE': data.qe,
      '11_Contenant_ID': data.contenantId,
      'Autre-FF-NON-inflammable': data.autreFFNonInflammable,
      'Autre-FF-inflammable': data.autreFFInflammable,
      '13_Instal': data.instal13,
      '14_Observations': data.observations,
      'Sign_Operateur_Nom': data.signOperateurNom,
      'Sign_Operateur_Qualite': data.signOperateurQualite,
      'Sign_Operateur_Date': data.signOperateurDate,
      'Sign_Detenteur_Nom': data.signDetenteurNom,
      'Sign_Detenteur_Qualite': data.signDetenteurQualite,
      'Sign_Detenteur_Date': data.signDetenteurDate,
    };

    final checkValues = <String, bool>{
      'Case_Assemblage': data.caseAssemblage,
      'Case_MiseService': data.caseMiseService,
      'Case_Modif': data.caseModif,
      'Case_Maintenance': data.caseMaintenance,
      'Case_CtrlPerio': data.caseCtrlPerio,
      'Case_CtrlNonPerio': data.caseCtrlNonPerio,
      'Case_Demantel': data.caseDemantel,
      'Case_Autre': data.caseAutre,
      'Case_HCFC_2': data.caseHcfc2,
      'Case_HCFC_30': data.caseHcfc30,
      'Case_HCFC_300': data.caseHcfc300,
      'Case_HFC_5': data.caseHfc5,
      'Case_HFO_1': data.caseHfo1,
      'Case_HFC_50': data.caseHfc50,
      'Case_HFO_10': data.caseHfo10,
      'Case_HFC_500': data.caseHfc500,
      'Case_HFO_100': data.caseHfo100,
      'Case_Sans_12m': data.caseSans12m,
      'Case_Sans_6m': data.caseSans6m,
      'Case_Sans_3m': data.caseSans3m,
      'Case_Avec_24m': data.caseAvec24m,
      'Case_Avec_12m': data.caseAvec12m,
      'Case_Avec_6m': data.caseAvec6m,
      'Case_Fuite_Oui': data.caseFuiteOui,
      'Case_Fuite_Non': data.caseFuiteNon,
      'Case_Rep_Fuite1_realisee': data.caseRepFuite1Realisee,
      'Case_Rep_Fuite1_AFaire': data.caseRepFuite1AFaire,
      'Case_Rep_Fuite2_realisee': data.caseRepFuite2Realisee,
      'Case_Rep_Fuite2_AFaire': data.caseRepFuite2AFaire,
      'Case_Rep_Fuite3_realisee': data.caseRepFuite3Realisee,
      'Case_Rep_Fuite3_AFaire': data.caseRepFuite3AFaire,
      'Case_12_UN1078': data.caseUN1078,
      'Case_12_Autre140601': data.caseUN1078Autre140601,
      'Case_12_UN3161': data.caseUN3161,
      'Case_12_Autre160504': data.caseUN3161Autre160504,
    };

    PdfField? champOperateurDate;
    PdfField? champDetenteurDate;

    for (int i = 0; i < form.fields.count; i++) {
      PdfField? field;
      try {
        field = form.fields[i];
      } catch (e) {
        debugPrint(
          '❌ Impossible d\'accéder au champ index $i (form.fields[$i]) : $e',
        );
        continue;
      }

      String? name;
      try {
        name = field.name;
      } catch (e) {
        debugPrint('❌ Champ index $i : impossible de lire .name : $e');
        continue;
      }

      if (name == null) continue;

      if (name == 'Sign_Operateur_Date') champOperateurDate = field;
      if (name == 'Sign_Detenteur_Date') champDetenteurDate = field;

      if (textValues.containsKey(name)) {
        try {
          if (field is PdfTextBoxField) {
            field.text = textValues[name]!;
            debugPrint('✏️ $name (texte) → "${textValues[name]}"');
          } else {
            debugPrint(
              '⚠️ $name attendu comme texte mais type réel = ${field.runtimeType}',
            );
          }
        } catch (e) {
          debugPrint('❌ $name : erreur en écrivant le texte : $e');
        }
      } else if (checkValues.containsKey(name)) {
        try {
          if (field is PdfCheckBoxField) {
            field.isChecked = checkValues[name]!;
            debugPrint('🔲 $name → réglé à ${checkValues[name]}');
          } else {
            debugPrint(
              '⚠️ $name attendu comme case à cocher mais type réel = ${field.runtimeType}',
            );
          }
        } catch (e) {
          debugPrint('❌ $name : erreur en réglant la case à cocher : $e');
        }
      }
    }

    if (data.signatureOperateurImage != null && champOperateurDate != null) {
      _tamponnerSignature(
        document: document,
        champDate: champOperateurDate,
        imageBytes: data.signatureOperateurImage!,
      );
    }

    if (data.signatureDetenteurImage != null && champDetenteurDate != null) {
      _tamponnerSignature(
        document: document,
        champDate: champDetenteurDate,
        imageBytes: data.signatureDetenteurImage!,
      );
    }

    final bytesFinaux = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytesFinaux);
  }

  void _tamponnerSignature({
    required PdfDocument document,
    required PdfField champDate,
    required Uint8List imageBytes,
  }) {
    PdfPage? page;
    for (int p = 0; p < document.pages.count; p++) {
      if (document.pages[p] == champDate.page) {
        page = document.pages[p];
        break;
      }
    }
    if (page == null) return;

    final bounds = champDate.bounds;
    const decalageDate = 60.0;
    const margeInterne = 2.0;

    final x = bounds.left + decalageDate;
    final y = bounds.top + margeInterne;
    final largeur = (bounds.width - decalageDate - margeInterne * 2).clamp(
      10.0,
      double.infinity,
    );
    final hauteur = (bounds.height - margeInterne * 2).clamp(
      10.0,
      double.infinity,
    );

    final image = PdfBitmap(imageBytes);
    page.graphics.drawImage(image, Rect.fromLTWH(x, y, largeur, hauteur));
  }
}
