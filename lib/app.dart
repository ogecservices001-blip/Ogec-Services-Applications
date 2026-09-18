import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/auth/auth_gate.dart';
import 'core/widgets/web_update_banner.dart';
import 'features/gmao/public/equipement_public_screen.dart';

/// Id d'équipement si l'URL chargée est `/equipement/{id}` (web
/// uniquement) — dans ce cas l'appli affiche la page publique sans
/// connexion au lieu de l'écran de connexion habituel. `null` sinon,
/// pour tout le reste du fonctionnement normal de l'appli.
String? _equipementPublicIdDepuisUrl() {
  if (!kIsWeb) return null;
  final segments = Uri.base.path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.length == 2 && segments[0] == 'equipement') {
    return segments[1];
  }
  return null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final equipementPublicId = _equipementPublicIdDepuisUrl();
    return MaterialApp(
      title: 'OGEC Services',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        textTheme: GoogleFonts.robotoTextTheme(),
      ),
      builder: (context, child) => WebUpdateBanner(child: child ?? const SizedBox.shrink()),
      home: equipementPublicId != null
          ? EquipementPublicScreen(equipementId: equipementPublicId)
          : const AuthGate(),
    );
  }
}
