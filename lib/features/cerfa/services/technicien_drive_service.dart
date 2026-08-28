import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import '../models/equipement_model.dart';

class FichierCerfa {
  final String id;
  final String name;
  final DateTime? modifiedTime;

  FichierCerfa({required this.id, required this.name, this.modifiedTime});
}

/// Accès Drive en lecture seule pour les techniciens (via le compte de
/// service embarqué, sans connexion Google) — permet de consulter les
/// CERFA déjà finalisés sans droits d'administration.
class TechnicienDriveService {
  Future<drive.DriveApi> _getDriveApi() async {
    final jsonString = await rootBundle.loadString(
      'assets/service_account.json',
    );
    final credentials = ServiceAccountCredentials.fromJson(jsonString);
    final client = await clientViaServiceAccount(credentials, [
      drive.DriveApi.driveScope,
    ]);
    return drive.DriveApi(client);
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

  Future<List<FichierCerfa>> listerCerfaFinalises(Equipement equipement) async {
    final driveApi = await _getDriveApi();
    final folderId = _extraireIdDossier(equipement.lienRepertoireDrive);
    if (folderId == null) return [];

    final nomEchappe = equipement.nomEquipement.replaceAll("'", "\\'");
    final resultat = await driveApi.files.list(
      q:
          "'$folderId' in parents and trashed = false "
          "and name contains '$nomEchappe' and not name contains '_MODELE'",
      spaces: 'drive',
      orderBy: 'modifiedTime desc',
      $fields: 'files(id, name, modifiedTime)',
      supportsAllDrives: true,
      includeItemsFromAllDrives: true,
    );

    return (resultat.files ?? [])
        .map(
          (f) => FichierCerfa(
            id: f.id!,
            name: f.name!,
            modifiedTime: f.modifiedTime,
          ),
        )
        .toList();
  }

  Future<Uint8List> telechargerFichier(String fileId) async {
    final driveApi = await _getDriveApi();
    final media =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
              supportsAllDrives: true,
            )
            as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }
}
