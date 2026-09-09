import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../../core/auth/admin_auth_service.dart';
import '../../cerfa/services/admin_drive_service.dart' show GoogleAuthClient;
import '../data/bi_constants.dart';
import '../data/bi_format.dart';
import '../data/bi_model.dart';

class BiUploadResult {
  final String biFolderId;
  final String pdfLink;
  final String jsonLink;
  BiUploadResult({required this.biFolderId, required this.pdfLink, required this.jsonLink});
}

/// Archivage Drive des bons d'intervention — mêmes contraintes que le
/// module CERFA : le compte de service embarqué ne peut pas créer de
/// fichiers/dossiers, seul le compte Google personnel de l'admin le
/// peut (voir GoogleAuthClient dans admin_drive_service.dart). Porté
/// depuis re.ogec.bi/drive/DriveDocStore.kt : arborescence
/// [racine] / "Client — Site" / "Pôle - Libellé" / "Année" / "BI" / "N° du bon".
class BiDriveService {
  Future<String> _trouverOuCreerDossier({
    required drive.DriveApi driveApi,
    required String nomDossier,
    required String parentId,
  }) async {
    final nomEchappe = nomDossier.replaceAll("'", "\\'");
    final recherche = await driveApi.files.list(
      q:
          "name = '$nomEchappe' and '$parentId' in parents and trashed = false "
          "and mimeType = 'application/vnd.google-apps.folder'",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );
    if (recherche.files != null && recherche.files!.isNotEmpty) {
      return recherche.files!.first.id!;
    }
    final dossier = await driveApi.files.create(
      drive.File()
        ..name = nomDossier
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId],
    );
    return dossier.id!;
  }

  Future<String> _uploader({
    required drive.DriveApi driveApi,
    required String nom,
    required String mimeType,
    required Uint8List bytes,
    required String parentId,
  }) async {
    final cree = await driveApi.files.create(
      drive.File()
        ..name = nom
        ..parents = [parentId],
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length, contentType: mimeType),
      $fields: 'id, webViewLink',
    );
    return cree.webViewLink ?? 'https://drive.google.com/file/d/${cree.id}';
  }

  Future<BiUploadResult> archiverBI({
    required AdminGoogleCredential adminAccount,
    required BonIntervention bi,
    required Uint8List pdfBytes,
  }) async {
    final client = GoogleAuthClient(adminAccount);
    final driveApi = drive.DriveApi(client);
    try {
      final nomClient = bi.site.isNotEmpty ? '${bi.clientNom} — ${bi.site}' : bi.clientNom;
      final clientId = await _trouverOuCreerDossier(
        driveApi: driveApi,
        nomDossier: nomClient,
        parentId: biDriveRootFolderId,
      );
      final poleId = await _trouverOuCreerDossier(
        driveApi: driveApi,
        nomDossier: driveFolderNamePole(bi.pole),
        parentId: clientId,
      );
      final anneeId = await _trouverOuCreerDossier(
        driveApi: driveApi,
        nomDossier: BiFormat.currentYear().toString(),
        parentId: poleId,
      );
      final biRootId = await _trouverOuCreerDossier(driveApi: driveApi, nomDossier: 'BI', parentId: anneeId);
      final biFolderId = await _trouverOuCreerDossier(
        driveApi: driveApi,
        nomDossier: bi.numero,
        parentId: biRootId,
      );

      final pdfLink = await _uploader(
        driveApi: driveApi,
        nom: '${bi.numero}.pdf',
        mimeType: 'application/pdf',
        bytes: pdfBytes,
        parentId: biFolderId,
      );
      final jsonBytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert({'id': bi.id, ...bi.toMap()})),
      );
      final jsonLink = await _uploader(
        driveApi: driveApi,
        nom: 'donnees_${bi.numero}.json',
        mimeType: 'application/json',
        bytes: jsonBytes,
        parentId: biFolderId,
      );

      return BiUploadResult(biFolderId: biFolderId, pdfLink: pdfLink, jsonLink: jsonLink);
    } finally {
      client.close();
    }
  }
}
