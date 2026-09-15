import 'package:web/web.dart' as web;

/// Recharge la page depuis le réseau (pas depuis le cache navigateur),
/// pour récupérer la dernière version déployée.
void rechargerPage() => web.window.location.reload();
