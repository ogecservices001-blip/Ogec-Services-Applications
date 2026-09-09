import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/app_build_info.dart';

/// "vX.Y.Z (build) · JJ/MM/AAAA" — numéro de version lu à l'exécution
/// (package_info_plus, identique web/APK), date maintenue à la main dans
/// app_build_info.dart à chaque publication.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final infos = snapshot.data;
        final texte = infos == null
            ? ' '
            : 'v${infos.version} (${infos.buildNumber}) · $appBuildDate';
        return Text(
          texte,
          style: TextStyle(fontSize: 11, color: color ?? Colors.grey),
        );
      },
    );
  }
}
