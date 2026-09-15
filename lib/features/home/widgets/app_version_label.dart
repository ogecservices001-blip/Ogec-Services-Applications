import 'package:flutter/material.dart';
import '../../../core/app_build_info.dart';
import '../../../core/services/app_version_service.dart';

/// "vX.Y.Z (build) · JJ/MM/AAAA" — numéro de version lu à l'exécution
/// (voir AppVersionService — fiable web comme APK), date maintenue à la
/// main dans app_build_info.dart à chaque publication.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppVersionInfo?>(
      future: AppVersionService.actuelle(),
      builder: (context, snapshot) {
        final infos = snapshot.data;
        final texte = infos == null
            ? 'Version…'
            : 'v${infos.version} (${infos.buildNumber}) · $appBuildDate';
        return Text(
          texte,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? Colors.grey[700]),
        );
      },
    );
  }
}
