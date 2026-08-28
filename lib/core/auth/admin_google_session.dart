import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'admin_auth_service.dart';

/// Connexion Google admin à la demande : contrairement à l'ancien modèle
/// (Google Sign-In obligatoire pour entrer dans tout l'espace admin), le
/// rôle admin/technicien vient désormais de Firestore (voir AuthGate) et
/// cette connexion Google n'est déclenchée que juste avant une action qui
/// en a réellement besoin (créer/remplacer un modèle Drive, envoyer un
/// email) — le compte de service embarqué ne peut ni créer de fichiers
/// Drive ni envoyer d'email en tant que l'admin.
class AdminGoogleSession {
  AdminGoogleSession._();
  static final AdminGoogleSession instance = AdminGoogleSession._();

  final AdminAuthService _authService = AdminAuthService();
  GoogleSignInAccount? _cachedAccount;

  GoogleSignInAccount? get cachedAccount => _cachedAccount;

  /// Retourne un compte Google admin validé, en le mettant en cache pour
  /// le reste de la session. Si aucun compte n'est encore en cache,
  /// affiche d'abord une confirmation puis déclenche la connexion Google
  /// interactive (restreinte au compte administrateur autorisé).
  Future<GoogleSignInAccount> ensureSignedIn(BuildContext context) async {
    final cached = _cachedAccount;
    if (cached != null) return cached;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connexion Google requise'),
        content: const Text(
          'Cette action nécessite une connexion au compte Google '
          'administrateur pour accéder à Drive/Gmail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );

    if (proceed != true) {
      throw Exception('Connexion Google annulée.');
    }

    final account = await _authService.signInAsAdmin();
    _cachedAccount = account;
    return account;
  }

  void clear() {
    _cachedAccount = null;
    _authService.signOut();
  }
}
