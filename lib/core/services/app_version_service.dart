import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Version et build actuellement chargés par l'app.
class AppVersionInfo {
  final String version;
  final String buildNumber;
  const AppVersionInfo({required this.version, required this.buildNumber});
}

/// Lit la version/build de l'app en cours d'exécution — sur web,
/// `package_info_plus` s'est révélé peu fiable (le FutureBuilder de
/// [AppVersionLabel] restait bloqué sur "Version…" indéfiniment, et le
/// bandeau anti-cache échouait silencieusement pour la même raison,
/// avalé par son catch-all). On lit directement web/version.json (déjà
/// utilisé par le bandeau anti-cache pour la version distante) plutôt
/// que de passer par le platform channel. Sur Android/iOS,
/// package_info_plus reste la source (déjà utilisé par ailleurs, par
/// ex. UpdateService, et fiable là-bas).
class AppVersionService {
  static Future<AppVersionInfo?> actuelle() async {
    if (kIsWeb) return _depuisVersionJson();
    try {
      final infos = await PackageInfo.fromPlatform();
      return AppVersionInfo(version: infos.version, buildNumber: infos.buildNumber);
    } catch (_) {
      return null;
    }
  }

  static Future<AppVersionInfo?> _depuisVersionJson() async {
    try {
      // Pas de paramètre anti-cache ici : on veut justement la version
      // que ce chargement de page a effectivement servie, pas la
      // dernière déployée (voir le bandeau anti-cache pour ça).
      final uri = Uri.base.resolve('version.json');
      final reponse = await http.get(uri).timeout(const Duration(seconds: 8));
      if (reponse.statusCode != 200) return null;
      final data = jsonDecode(reponse.body) as Map<String, dynamic>;
      final version = data['version']?.toString() ?? '';
      final build = data['build_number']?.toString() ?? '';
      if (version.isEmpty || build.isEmpty) return null;
      return AppVersionInfo(version: version, buildNumber: build);
    } catch (_) {
      return null;
    }
  }
}
