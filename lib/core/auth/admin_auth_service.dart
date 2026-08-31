import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';

/// Identifiants Google utilisés par les actions Drive/Gmail de l'admin,
/// indépendants du mécanisme de connexion sous-jacent : google_sign_in
/// sur mobile/desktop, popup Firebase Auth sur le web (voir
/// [AdminAuthService._signInWeb] pour le pourquoi).
class AdminGoogleCredential {
  final String email;
  final String accessToken;

  AdminGoogleCredential({required this.email, required this.accessToken});

  Future<Map<String, String>> get authHeaders async =>
      {'Authorization': 'Bearer $accessToken'};
}

/// Gère la connexion Google réservée à l'administrateur (toi), distincte
/// de la connexion Firebase Auth (email/mot de passe) utilisée pour
/// entrer dans l'app — voir LoginScreen.
class AdminAuthService {
  static const String adminEmail = 'ogecservices001@gmail.com';
  static const _scopes = [
    'email',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/drive',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  /// Lance la connexion Google et vérifie que le compte est bien celui
  /// de l'administrateur.
  Future<AdminGoogleCredential> signInAsAdmin() {
    return kIsWeb ? _signInWeb() : _signInNative();
  }

  /// Utilise disconnect() plutôt que signOut() : sur Android,
  /// google_sign_in peut réutiliser silencieusement une session mise en
  /// cache par Google Play Services même après un signOut(), ce qui
  /// laissait passer un compte non-admin. disconnect() révoque
  /// complètement l'accès et force une vraie ré-authentification.
  Future<AdminGoogleCredential> _signInNative() async {
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
    _verifierCompteAdmin(account.email);

    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null) {
      throw Exception('Impossible d\'obtenir le jeton d\'accès Google.');
    }
    return AdminGoogleCredential(email: account.email, accessToken: token);
  }

  /// Sur le web, google_sign_in ne supporte plus la connexion interactive
  /// (signIn() y lève une erreur — Google a retiré l'ancienne librairie JS
  /// sur laquelle il reposait). On passe donc par une popup Firebase Auth
  /// à la place, exécutée sur une app Firebase secondaire pour ne jamais
  /// perturber la session principale (connectée par email/mot de passe
  /// via AuthGate).
  Future<AdminGoogleCredential> _signInWeb() async {
    // Une app nommée et neuve à chaque tentative (pas une app mise en
    // cache et réutilisée) : sur le web, deux connexions successives via
    // signInWithPopup sur la même app secondaire pour un compte déjà
    // connecté auparavant entrent en conflit avec l'état persisté
    // (IndexedDB/localStorage, partagé via le même authDomain) et lèvent
    // invalid-credential. Supprimer l'app juste après usage élimine tout
    // état résiduel pour la prochaine tentative.
    final secondaryApp = await Firebase.initializeApp(
      name: 'adminGoogleAuth_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final auth = fb_auth.FirebaseAuth.instanceFor(app: secondaryApp);

    final provider = fb_auth.GoogleAuthProvider();
    for (final scope in _scopes) {
      provider.addScope(scope);
    }
    provider.setCustomParameters({
      'login_hint': adminEmail,
      'prompt': 'select_account',
    });

    String? token;
    String? email;
    try {
      final userCredential = await auth.signInWithPopup(provider);
      token = userCredential.credential?.accessToken;
      email = userCredential.user?.email;
    } finally {
      // Le jeton est déjà récupéré ; cette app secondaire ne sert plus à
      // rien et ne doit laisser aucune trace pour la prochaine tentative.
      await secondaryApp.delete();
    }

    if (token == null || email == null) {
      throw Exception('Impossible d\'obtenir le jeton d\'accès Google.');
    }
    _verifierCompteAdmin(email);
    return AdminGoogleCredential(email: email, accessToken: token);
  }

  void _verifierCompteAdmin(String email) {
    if (email.toLowerCase() != adminEmail) {
      throw Exception(
        'Ce compte ($email) n\'a pas les droits administrateur.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
  }
}
