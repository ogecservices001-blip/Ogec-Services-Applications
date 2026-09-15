import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../web_reload/reload.dart';

/// Bandeau global (web uniquement) qui détecte qu'une nouvelle version de
/// l'app est déjà déployée sur Firebase Hosting alors que cet onglet
/// tourne encore sur l'ancienne — le service worker Flutter ne sert la
/// nouvelle version qu'après un rechargement complet, jamais sur un
/// onglet resté ouvert. Compare le `build_number` de web/version.json
/// (régénéré à chaque build, requêté avec un paramètre anti-cache) à
/// celui de la version actuellement chargée. Vu une fois côté import
/// Excel qui créait des doublons avec un onglet resté ouvert après un
/// déploiement — ce bandeau couvre toute l'app, pas seulement l'import.
class WebUpdateBanner extends StatefulWidget {
  final Widget child;
  const WebUpdateBanner({super.key, required this.child});

  @override
  State<WebUpdateBanner> createState() => _WebUpdateBannerState();
}

class _WebUpdateBannerState extends State<WebUpdateBanner> {
  static const _intervalle = Duration(minutes: 5);
  Timer? _timer;
  bool _nouvelleVersionDisponible = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _verifier();
      _timer = Timer.periodic(_intervalle, (_) => _verifier());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verifier() async {
    try {
      final infos = await PackageInfo.fromPlatform();
      final horodatage = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.base.resolve('version.json?t=$horodatage');
      final reponse = await http.get(uri).timeout(const Duration(seconds: 8));
      if (reponse.statusCode != 200) return;
      final data = jsonDecode(reponse.body) as Map<String, dynamic>;
      final buildDistant = data['build_number']?.toString() ?? '';
      if (buildDistant.isNotEmpty && buildDistant != infos.buildNumber && mounted) {
        setState(() => _nouvelleVersionDisponible = true);
      }
    } catch (_) {
      // Pas de connexion, ou version.json indisponible : on ne dérange pas.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_nouvelleVersionDisponible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.amber[800],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.system_update_alt, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Nouvelle version disponible',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: rechargerPage,
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Recharger'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
