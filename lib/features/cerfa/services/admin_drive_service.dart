import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../models/equipement_model.dart';

/// Client HTTP authentifié avec le compte Google de l'administrateur
/// (via google_sign_in), pour appeler l'API Drive avec son propre quota
/// personnel — contrairement au compte de service utilisé ailleurs dans
/// l'app, qui ne peut pas créer de nouveaux fichiers.
class GoogleAuthClient extends http.BaseClient {
  final GoogleSignInAccount account;
  final http.Client _inner = http.Client();

  GoogleAuthClient(this.account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await account.authHeaders;
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class ResultatCreationModeles {
  int crees = 0;
  int remplaces = 0;
  int erreurs = 0;
  final List<String> messages = [];
}

class DriveFileInfo {
  final String id;
  final String name;
  final DateTime? modifiedTime;

  DriveFileInfo({required this.id, required this.name, this.modifiedTime});
}

class VerificationDossier {
  final Equipement equipement;
  final List<String> problemes;

  VerificationDossier({required this.equipement, required this.problemes});

  bool get ok => problemes.isEmpty;
}

/// Interactions Drive effectuées avec le compte Google de l'admin :
/// dépôt de modèles vierges, recherche et téléchargement de CERFA
/// finalisés (équivalent des scripts Python, mais depuis l'app).
class AdminDriveService {
  static const String templateFileId = '1RJMEnQJEu1VHcDvM_hH26qxkLIVxKvuq';

  /// Dossier racine sous lequel sont créés les dossiers de site lors de
  /// l'ajout d'un nouvel équipement (à plat, pas de sous-dossiers).
  static const String dossierRacineClientsId =
      '16PWzgAJuDhn6W9QuA5PIEuMggADx8wRJ';

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

  String nomModeleAttendu(Equipement e) {
    final numeroClient = e.numeroClient.padLeft(3, '0');
    final numeroSite = e.numeroSite.padLeft(2, '0');
    final slug = _slugify(e.nomEquipement);
    return '$numeroClient-$numeroSite-${slug}_MODELE.pdf';
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

  /// Cherche un sous-dossier nommé [nomDossier] sous [parentId] ; le
  /// crée s'il n'existe pas encore. Retourne son ID.
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

  /// Crée (ou retrouve s'il existe déjà) le dossier directement sous
  /// [dossierRacineClientsId], nommé "NuméroChantier-Client-Site"
  /// (ex: "386-01-SCI CHONG-Super U Piton St Leu"), et retourne son
  /// lien Drive. Aucun sous-dossier n'est créé — tout reste à plat
  /// sous la racine.
  Future<String> obtenirOuCreerDossierSite({
    required GoogleSignInAccount adminAccount,
    required String numeroChantier,
    required String client,
    required String site,
  }) async {
    final nomDossier = '$numeroChantier-$client-$site';
    final authClient = GoogleAuthClient(adminAccount);
    final driveApi = drive.DriveApi(authClient);

    try {
      final dossierId = await _trouverOuCreerDossier(
        driveApi: driveApi,
        nomDossier: nomDossier,
        parentId: dossierRacineClientsId,
      );
      return 'https://drive.google.com/drive/folders/$dossierId';
    } finally {
      authClient.close();
    }
  }

  Future<void> _creerOuRemplacerModele({
    required drive.DriveApi driveApi,
    required Equipement equipement,
    required Uint8List bytesTemplate,
    required ResultatCreationModeles resultat,
  }) async {
    final folderId = _extraireIdDossier(equipement.lienRepertoireDrive);
    if (folderId == null) {
      resultat.erreurs++;
      resultat.messages.add(
        '⚠️ ${equipement.nomEquipement} : lien Drive invalide ou vide',
      );
      return;
    }

    final nomModele = nomModeleAttendu(equipement);

    try {
      final recherche = await driveApi.files.list(
        q: "name = '$nomModele' and '$folderId' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (recherche.files != null && recherche.files!.isNotEmpty) {
        final fileId = recherche.files!.first.id!;
        await driveApi.files.update(
          drive.File(),
          fileId,
          uploadMedia: drive.Media(
            Stream.value(bytesTemplate),
            bytesTemplate.length,
          ),
        );
        resultat.remplaces++;
        resultat.messages.add('🔄 Remplacé : $nomModele');
      } else {
        await driveApi.files.copy(
          drive.File()
            ..name = nomModele
            ..parents = [folderId],
          templateFileId,
        );
        resultat.crees++;
        resultat.messages.add('✅ Créé : $nomModele');
      }
    } catch (e) {
      resultat.erreurs++;
      resultat.messages.add('❌ ${equipement.nomEquipement} : $e');
    }
  }

  Future<ResultatCreationModeles> creerModelesPourEquipements({
    required GoogleSignInAccount adminAccount,
    required List<Equipement> equipements,
  }) async {
    final client = GoogleAuthClient(adminAccount);
    final driveApi = drive.DriveApi(client);
    final resultat = ResultatCreationModeles();

    try {
      final media =
          await driveApi.files.get(
                templateFileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;
      final bytesTemplate = await _streamToBytes(media.stream);

      for (final e in equipements) {
        await _creerOuRemplacerModele(
          driveApi: driveApi,
          equipement: e,
          bytesTemplate: bytesTemplate,
          resultat: resultat,
        );
      }
    } catch (e) {
      resultat.erreurs++;
      resultat.messages.add('❌ Erreur générale : $e');
    } finally {
      client.close();
    }

    return resultat;
  }

  /// Liste les CERFA déjà finalisés (donc PAS les modèles "_MODELE.pdf")
  /// présents dans le dossier Drive de l'équipement, triés du plus
  /// récent au plus ancien.
  Future<List<DriveFileInfo>> listerCerfaFinalises({
    required GoogleSignInAccount adminAccount,
    required Equipement equipement,
  }) async {
    final client = GoogleAuthClient(adminAccount);
    final driveApi = drive.DriveApi(client);

    try {
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
      );

      return (resultat.files ?? [])
          .map(
            (f) => DriveFileInfo(
              id: f.id!,
              name: f.name!,
              modifiedTime: f.modifiedTime,
            ),
          )
          .toList();
    } finally {
      client.close();
    }
  }

  Future<Uint8List> telechargerFichier({
    required GoogleSignInAccount adminAccount,
    required String fileId,
  }) async {
    final client = GoogleAuthClient(adminAccount);
    final driveApi = drive.DriveApi(client);

    try {
      final media =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;
      return await _streamToBytes(media.stream);
    } finally {
      client.close();
    }
  }

  /// Vérifie, pour chaque équipement : la présence/validité du lien
  /// Drive, l'accessibilité du dossier, la présence du modèle PDF, et
  /// les informations de signataire (nom/email).
  Future<List<VerificationDossier>> verifierDossiers({
    required GoogleSignInAccount adminAccount,
    required List<Equipement> equipements,
    void Function(int actuel, int total)? onProgress,
  }) async {
    final client = GoogleAuthClient(adminAccount);
    final driveApi = drive.DriveApi(client);
    final resultats = <VerificationDossier>[];

    try {
      for (var i = 0; i < equipements.length; i++) {
        final e = equipements[i];
        final problemes = <String>[];

        if (e.nomSignataireClient.trim().isEmpty) {
          problemes.add('Nom du signataire manquant');
        }
        if (e.emailSignataireClient.trim().isEmpty) {
          problemes.add('Email du signataire manquant');
        }

        final lien = e.lienRepertoireDrive.trim();
        String? folderId;
        if (lien.isEmpty) {
          problemes.add('Lien Drive manquant');
        } else {
          folderId = _extraireIdDossier(lien);
          if (folderId == null) {
            problemes.add('Lien Drive invalide');
          }
        }

        if (folderId != null) {
          try {
            await driveApi.files.get(folderId, $fields: 'id');
          } catch (_) {
            problemes.add('Dossier Drive inaccessible ou supprimé');
            folderId = null;
          }
        }

        if (folderId != null) {
          final nomModele = nomModeleAttendu(e);
          try {
            final recherche = await driveApi.files.list(
              q: "name = '$nomModele' and '$folderId' in parents and trashed = false",
              spaces: 'drive',
              $fields: 'files(id)',
            );
            if (recherche.files == null || recherche.files!.isEmpty) {
              problemes.add('Modèle PDF absent ($nomModele)');
            }
          } catch (err) {
            problemes.add('Erreur lors de la recherche du modèle : $err');
          }
        }

        resultats.add(VerificationDossier(equipement: e, problemes: problemes));
        onProgress?.call(i + 1, equipements.length);
      }
    } finally {
      client.close();
    }

    return resultats;
  }

  /// Variante service-account de [verifierDossiers], sans connexion Google
  /// interactive : ce flux est entièrement en lecture seule (files.get /
  /// files.list), donc authentifié via le compte de service embarqué —
  /// modelé sur TechnicienDriveService._getDriveApi().
  Future<drive.DriveApi> _getDriveApiServiceAccount() async {
    final jsonString = await rootBundle.loadString(
      'assets/service_account.json',
    );
    final credentials = ServiceAccountCredentials.fromJson(jsonString);
    final client = await clientViaServiceAccount(credentials, [
      drive.DriveApi.driveScope,
    ]);
    return drive.DriveApi(client);
  }

  /// Vérifie, pour chaque équipement : la présence/validité du lien
  /// Drive, l'accessibilité du dossier, la présence du modèle PDF, et
  /// les informations de signataire (nom/email) — via le compte de
  /// service, sans jamais déclencher la connexion Google admin.
  Future<List<VerificationDossier>> verifierDossiersServiceAccount({
    required List<Equipement> equipements,
    void Function(int actuel, int total)? onProgress,
  }) async {
    final driveApi = await _getDriveApiServiceAccount();
    final resultats = <VerificationDossier>[];

    for (var i = 0; i < equipements.length; i++) {
      final e = equipements[i];
      final problemes = <String>[];

      if (e.nomSignataireClient.trim().isEmpty) {
        problemes.add('Nom du signataire manquant');
      }
      if (e.emailSignataireClient.trim().isEmpty) {
        problemes.add('Email du signataire manquant');
      }

      final lien = e.lienRepertoireDrive.trim();
      String? folderId;
      if (lien.isEmpty) {
        problemes.add('Lien Drive manquant');
      } else {
        folderId = _extraireIdDossier(lien);
        if (folderId == null) {
          problemes.add('Lien Drive invalide');
        }
      }

      if (folderId != null) {
        try {
          await driveApi.files.get(folderId, $fields: 'id');
        } catch (_) {
          problemes.add('Dossier Drive inaccessible ou supprimé');
          folderId = null;
        }
      }

      if (folderId != null) {
        final nomModele = nomModeleAttendu(e);
        try {
          final recherche = await driveApi.files.list(
            q: "name = '$nomModele' and '$folderId' in parents and trashed = false",
            spaces: 'drive',
            $fields: 'files(id)',
          );
          if (recherche.files == null || recherche.files!.isEmpty) {
            problemes.add('Modèle PDF absent ($nomModele)');
          }
        } catch (err) {
          problemes.add('Erreur lors de la recherche du modèle : $err');
        }
      }

      resultats.add(VerificationDossier(equipement: e, problemes: problemes));
      onProgress?.call(i + 1, equipements.length);
    }

    return resultats;
  }
}
