import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- FIX : Récupération du rôle avec priorité à l'email maître ---
  Future<String> getCurrentUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      String email = user.email?.toLowerCase().trim() ?? "";

      // Sécurité absolue : l'email admin est toujours admin
      if (email == "admin@ogec.com") {
        return 'admin';
      }

      // Pour les autres, on vérifie dans Firestore
      try {
        DocumentSnapshot doc = await _db
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return data['role'] ?? 'technicien';
        }
      } catch (e) {
        debugPrint("Erreur lors de la récupération du rôle : $e");
      }
    }
    return 'technicien'; // Par défaut par sécurité
  }

  /// Point d'entrée unique pour vérifier si l'utilisateur connecté est
  /// admin (email maître OU rôle Firestore 'admin'). Tous les écrans
  /// doivent passer par ici plutôt que de dupliquer la logique.
  Future<bool> isCurrentUserAdmin() async {
    final role = await getCurrentUserRole();
    return role == 'admin';
  }

  // Récupérer tous les utilisateurs
  Stream<QuerySnapshot> getUsers() {
    return _db.collection('users').snapshots();
  }

  // Création d'un compte (Auth + Profil Firestore)
  Future<void> addUser({
    required String email,
    required String password,
    required String role,
    required String name,
    String portable = '',
    String emailPerso = '',
    String communeHabitation = '',
    String vehicule = '',
    String qualite = '',
  }) async {
    String appName = "SecondaryApp_${DateTime.now().millisecondsSinceEpoch}";
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );

    try {
      UserCredential userCredential = await FirebaseAuth.instanceFor(
        app: secondaryApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      String uid = userCredential.user!.uid;

      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'role': role,
        'name': name,
        'portable': portable,
        'emailPerso': emailPerso,
        'communeHabitation': communeHabitation,
        'vehicule': vehicule,
        'qualite': qualite,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint(">>> SUCCÈS : Utilisateur $email créé (UID technique: $uid)");
    } catch (e) {
      debugPrint(">>> ERREUR lors de la création : $e");
      rethrow;
    } finally {
      await secondaryApp.delete();
    }
  }

  /// Crée une fiche "en attente" (sans compte de connexion) : pour un
  /// collaborateur pas encore doté d'un accès à l'appli. Contrairement
  /// à [addUser], ne crée aucun compte Firebase Auth — l'identifiant
  /// est un slug généré à partir du nom, pas un UID.
  Future<void> addUserSansCompte({
    required String name,
    String portable = '',
    String emailPerso = '',
    String communeHabitation = '',
    String vehicule = '',
    String qualite = '',
  }) async {
    final id = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');
    await _db.collection('users').doc(id).set({
      'uid': id,
      'email': '',
      'role': 'en_attente',
      'name': name,
      'portable': portable,
      'emailPerso': emailPerso,
      'communeHabitation': communeHabitation,
      'vehicule': vehicule,
      'qualite': qualite,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Mise à jour via l'UID technique
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint(">>> ERREUR lors de la mise à jour : $e");
    }
  }

  // Suppression du profil Firestore
  Future<void> deleteUser(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint(">>> ERREUR lors de la suppression : $e");
    }
  }

  /// Migration ponctuelle : fusionne dans `users` les données jusqu'ici
  /// éparpillées entre `collaborateurs` (import Excel) et `techniciens`
  /// (qualité). Pour les 7 collaborateurs déjà dotés d'un compte,
  /// complète leur fiche `users` existante ; pour les 5 sans compte,
  /// crée une fiche "en attente". Écrase les champs à chaque exécution
  /// (idempotent), sans jamais créer de doublon.
  Future<String> migrerCollaborateursEtTechniciens() async {
    final collection = _db.collection('users');
    final existants = (await collection.get()).docs.map((d) => d.id).toSet();

    final batch = _db.batch();
    int maj = 0;
    int crees = 0;
    int ignores = 0;

    // uid -> compléments (collaborateurs déjà rattachés à un compte)
    const avecCompte = {
      '9HOgFVHrOQRL1FVazLMVSHpBZxj2': {
        // LAMY Fabrice
        'portable': '06.92.88.31.04',
        'emailPerso': 'fabricelamy594@gmail.com',
        'communeHabitation': 'Bellemene Saint Paul',
        'vehicule': 'DJ-457-HG',
      },
      'LSlpKYFlYChp0eko53KmNrQEibu2': {
        // MOUNICHY Julçay
        'portable': '06.93.39.94.36',
        'emailPerso': 'jul.mounichy@gmail.com',
        'communeHabitation': 'Saint Gilles Les Hauts',
        'vehicule': 'GC-123-VC',
      },
      'U0Ggh06Q2TRUtdECwQ3geWDxuD42': {
        // MAILLOT Jean Cyrille
        'portable': '06.93.91.25.59',
        'emailPerso': 'jean-cyrille.maillot@wanadoo.fr',
        'communeHabitation': 'Saint Denis Belle Pierre',
        'vehicule': 'EE-437-WC',
      },
      'aUmHOLYt1VdxPOF3bVMVmGShDm52': {
        // RAMSAMY Nicolas
        'portable': '06.92.66.70.86',
        'emailPerso': 'nicolas.rmy435@gmail.com',
        'communeHabitation': 'Saint Gilles Les Hauts',
        'vehicule': 'GL-827-AB',
      },
      'gLoEH9901oaj9TKEsbccFWMRWAH2': {
        // LIXIVEL Elino
        'portable': '06.92.64.39.36',
        'emailPerso': 'elino.lixivel@gmail.com',
        'communeHabitation': 'La Possession',
        'vehicule': 'HB-713-BQ',
      },
      'r84CLq1nRtbDpA5N5EDMyrg4mty2': {
        // ROBERT Ludovic
        'portable': '06.92.69.12.07',
        'emailPerso': 'mathismathilderobert@gmail.com',
        'communeHabitation': 'Saint André',
        'vehicule': 'GC-122-VC',
      },
      'xXaBAL0COxaf4HkC1Texhqkblg43': {
        // CORSET Olivier
        'portable': '06.92.68.64.86',
        'emailPerso': 'olivier.corset@orange.fr',
        'communeHabitation': 'La Possession',
        'vehicule': 'GC-123-VC',
      },
    };

    for (final entry in avecCompte.entries) {
      if (!existants.contains(entry.key)) {
        ignores++;
        continue;
      }
      batch.update(collection.doc(entry.key), entry.value);
      maj++;
    }

    // Collaborateurs sans compte : fiche "en attente"
    const sansCompte = [
      {
        'name': 'ROBERT Daniel',
        'portable': '06.93.91.25.59',
        'emailPerso': 'robert.daniel97440@gmail.com',
        'communeHabitation': 'Saint André',
        'vehicule': 'EE-437-WC',
      },
      {
        'name': 'CHAMCIRKAN Dimitri',
        'portable': '06.92.88.31.04',
        'communeHabitation': 'Bois De Nèfles Saint Paul',
        'vehicule': 'DJ-457-HG',
      },
      {
        'name': 'ROSSE Bryan',
        'portable': '06.92.69.12.07',
        'emailPerso': 'bryanrosse79@gmail.com',
        'communeHabitation': 'Saint André',
        'vehicule': 'GC-122-VC',
      },
      {
        'name': 'GRONDIN Guillaume',
        'emailPerso': 'grondinguillaumelog974@gmail.com',
        'communeHabitation': 'La Possession',
        'vehicule': 'CM-949-KS',
      },
      {
        'name': 'AMADY Toualali',
        'portable': '06.93.39.94.36',
        'vehicule': 'CM-949-KS',
      },
    ];

    for (final c in sansCompte) {
      final name = c['name']!;
      final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      batch.set(collection.doc(id), {
        'uid': id,
        'email': '',
        'role': 'en_attente',
        'name': name,
        'portable': c['portable'] ?? '',
        'emailPerso': c['emailPerso'] ?? '',
        'communeHabitation': c['communeHabitation'] ?? '',
        'vehicule': c['vehicule'] ?? '',
        'qualite': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      crees++;
    }

    await batch.commit();

    // Qualité, depuis l'ancienne collection "techniciens" (même UID) —
    // ignore les fiches "techniciens" orphelines (compte supprimé
    // depuis, ex: ancien compte Google recréé avec un nouvel UID).
    final techniciens = await _db.collection('techniciens').get();
    final batchQualite = _db.batch();
    int qualites = 0;
    for (final doc in techniciens.docs) {
      if (!existants.contains(doc.id)) {
        ignores++;
        continue;
      }
      final qualite = doc.data()['qualite'];
      if (qualite != null && qualite.toString().isNotEmpty) {
        batchQualite.update(collection.doc(doc.id), {'qualite': qualite});
        qualites++;
      }
    }
    if (qualites > 0) {
      await batchQualite.commit();
    }

    return 'Terminé : $maj compte(s) complété(s), $crees fiche(s) "en attente" créée(s), '
        '$qualites qualité(s) reprise(s), $ignores fiche(s) orpheline(s) ignorée(s).';
  }
}
