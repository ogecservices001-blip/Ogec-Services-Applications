import 'dart:typed_data';

/// Implémentation par défaut (non-web) : pas encore de gestion de
/// téléchargement de fichier binaire sur mobile/desktop pour l'export
/// GMAO — seule la version web est prise en charge pour l'instant.
void downloadBytes(Uint8List bytes, String filename) {
  throw UnsupportedError(
    "Export disponible uniquement sur la version web pour l'instant",
  );
}
