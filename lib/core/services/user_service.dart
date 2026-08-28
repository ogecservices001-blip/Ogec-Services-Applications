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
}
