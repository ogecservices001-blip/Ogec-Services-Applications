import 'package:google_sign_in/google_sign_in.dart';

/// Gère la connexion Google réservée à l'administrateur (toi), distincte
/// de la connexion Firebase Auth utilisée par les techniciens.
class AdminAuthService {
  static const String adminEmail = 'ogecservices001@gmail.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/drive',
    ],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Lance la connexion Google et vérifie que le compte est bien celui
  /// de l'administrateur.
  ///
  /// Utilise disconnect() plutôt que signOut() : sur Android,
  /// google_sign_in peut réutiliser silencieusement une session mise en
  /// cache par Google Play Services même après un signOut(), ce qui
  /// laissait passer un compte non-admin. disconnect() révoque
  /// complètement l'accès et force une vraie ré-authentification.
  Future<GoogleSignInAccount> signInAsAdmin() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // disconnect() lève une exception s'il n'y avait aucune session
      // active — sans conséquence, on continue normalement.
    }

    final account = await _googleSignIn.signIn();

    if (account == null) {
      throw Exception('Connexion annulée.');
    }

    // ignore: avoid_print
    print('🔐 Compte Google sélectionné : ${account.email}');

    if (account.email.toLowerCase() != adminEmail) {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      throw Exception(
        'Ce compte (${account.email}) n\'a pas les droits administrateur.',
      );
    }

    return account;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
  }
}
