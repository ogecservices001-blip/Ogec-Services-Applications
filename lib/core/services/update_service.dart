import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Vérifie s'il existe une version plus récente de l'appli (Android
/// uniquement — hors Play Store, pas de mise à jour automatique
/// possible, donc on la propose nous-mêmes). La dernière version
/// publiée est décrite dans le document Firestore `app_config/version`
/// (mis à jour manuellement à chaque publication d'un nouvel APK).
class MiseAJourDisponible {
  final String versionName;
  final String downloadUrl;
  MiseAJourDisponible({required this.versionName, required this.downloadUrl});
}

class UpdateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<MiseAJourDisponible?> verifier() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    try {
      final doc = await _db.collection('app_config').doc('version').get();
      if (!doc.exists) return null;
      final data = doc.data()!;

      final latestVersionCode = int.tryParse(
        data['versionCode']?.toString() ?? '',
      );
      final versionName = data['versionName']?.toString() ?? '';
      final downloadUrl = data['downloadUrl']?.toString() ?? '';
      if (latestVersionCode == null || downloadUrl.isEmpty) return null;

      final infos = await PackageInfo.fromPlatform();
      final versionCodeInstalle = int.tryParse(infos.buildNumber) ?? 0;

      if (latestVersionCode > versionCodeInstalle) {
        return MiseAJourDisponible(
          versionName: versionName,
          downloadUrl: downloadUrl,
        );
      }
    } catch (_) {
      // Pas de connexion ou document absent : on n'embête pas l'utilisateur.
    }
    return null;
  }

  /// Vérifie en tâche de fond et, si une nouvelle version existe,
  /// propose la mise à jour (Oui télécharge via le navigateur, Non
  /// ferme la popup). Silencieux si déjà à jour ou hors Android.
  Future<void> verifierEtProposer(BuildContext context) async {
    final maj = await verifier();
    if (maj == null || !context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mise à jour disponible'),
        content: Text(
          'Une nouvelle version (v${maj.versionName}) est disponible.\n\n'
          'Mettre à jour maintenant ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final uri = Uri.parse(maj.downloadUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }
}
